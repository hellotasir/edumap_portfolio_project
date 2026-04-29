// ignore_for_file: avoid_print

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:edumap_portfolio_project/core/services/cloud/delete_service.dart';

class DeleteRepository {
  DeleteRepository({
    DeleteService? firebaseService,
    DeleteService? supabaseService,
    FirebaseFirestore? firestore,
  }) : _firebaseService =
           firebaseService ?? DeleteService(BackendType.firebase),
       _supabaseService =
           supabaseService ?? DeleteService(BackendType.supabase),
       _db = firestore ?? FirebaseFirestore.instance;

  final DeleteService _firebaseService;
  final DeleteService _supabaseService;
  final FirebaseFirestore _db;

  static const int _batchSize = 400;

  CollectionReference<Map<String, dynamic>> _col(String name) =>
      _db.collection(name);

  CollectionReference<Map<String, dynamic>> _messages(String conversationId) =>
      _col('conversations').doc(conversationId).collection('messages');

  Future<Map<String, int>> previewUserDataCounts(String userId) async {
    final counts = <String, int>{};

    for (final col in AppConfig.firebaseUserIdCollections) {
      counts[col] = await _safeCount(
        _col(col).where('user_id', isEqualTo: userId),
      );
    }

    counts['profiles'] = await _safeCount(
      _col('profiles').where('user_id', isEqualTo: userId),
    );

    counts['presence'] = await _docExists('presence', userId) ? 1 : 0;

    counts['friend_requests'] =
        await _safeCount(
          _col('friend_requests').where('from_user_id', isEqualTo: userId),
        ) +
        await _safeCount(
          _col('friend_requests').where('to_user_id', isEqualTo: userId),
        );

    counts['friends'] =
        await _safeCount(
          _col('friends').where('user_id_1', isEqualTo: userId),
        ) +
        await _safeCount(_col('friends').where('user_id_2', isEqualTo: userId));

    counts['conversations'] = await _safeCount(
      _col('conversations').where('created_by', isEqualTo: userId),
    );

    counts['conversations/messages'] = await _countAllMessagesForUser(userId);

    return counts;
  }

  Future<DeleteResult> deleteAllUserData(
    String userId,
    String email, {
    bool strict = true,
    bool showLogs = true,
  }) async {
    DeleteResult combined = const DeleteResult(
      totalDeleted: 0,
      results: {},
      errors: {},
    );

    void log(String msg) {
      if (showLogs) print(msg);
    }

    log('── Step 1: deleting messages…');
    try {
      final msgCount = await _deleteAllMessagesForUser(
        userId,
        showLogs: showLogs,
      );
      combined = combined.merge(
        DeleteResult(
          totalDeleted: msgCount,
          results: {'conversations/messages': msgCount},
          errors: {},
        ),
      );
    } catch (e) {
      log('❌ Step 1 (messages): $e');
      combined = combined.merge(
        DeleteResult(
          totalDeleted: 0,
          results: {},
          errors: {'conversations/messages': e.toString()},
        ),
      );
    }

    log('── Step 2: deleting conversations…');
    combined = combined.merge(
      await _firebaseService.deleteByField(
        collection: 'conversations',
        field: 'created_by',
        userId: userId,
        showLogs: showLogs,
      ),
    );

    log('── Step 3: deleting friend_requests…');
    combined = combined
        .merge(
          await _firebaseService.deleteByField(
            collection: 'friend_requests',
            field: 'from_user_id',
            userId: userId,
            showLogs: showLogs,
          ),
        )
        .merge(
          await _firebaseService.deleteByField(
            collection: 'friend_requests',
            field: 'to_user_id',
            userId: userId,
            showLogs: showLogs,
          ),
        );

    log('── Step 4: deleting friends…');
    combined = combined
        .merge(
          await _firebaseService.deleteByField(
            collection: 'friends',
            field: 'user_id_1',
            userId: userId,
            showLogs: showLogs,
          ),
        )
        .merge(
          await _firebaseService.deleteByField(
            collection: 'friends',
            field: 'user_id_2',
            userId: userId,
            showLogs: showLogs,
          ),
        );

    log('── Step 5: deleting presence…');
    combined = combined.merge(
      await _firebaseService.deleteDocById(
        collection: 'presence',
        docId: userId,
        showLogs: showLogs,
      ),
    );

    log('── Step 6: deleting standard Firebase collections…');
    combined = combined.merge(
      await _firebaseService.deleteByUserId(
        collections: AppConfig.firebaseUserIdCollections,
        userId: userId,
        showLogs: showLogs,
      ),
    );

    log('── Step 7: deleting profile by user_id and email…');
    combined = combined.merge(
      await _firebaseService.deleteProfileByUserIdAndEmail(
        userId: userId,
        email: email,
        showLogs: showLogs,
      ),
    );

    log('── Step 8: deleting Supabase DB rows…');
    combined = combined.merge(
      await _supabaseService.deleteByUserId(
        collections: AppConfig.supabaseUserIdCollections,
        userId: userId,
        showLogs: showLogs,
      ),
    );

    log('── Step 9: deleting Supabase Storage files…');
    combined = combined.merge(
      await _supabaseService.deleteStorageForUser(userId, showLogs: showLogs),
    );

    if (strict && combined.hasErrors) {
      throw DeleteRepositoryException(
        'deleteAllUserData failed for: ${combined.errors.keys.join(', ')}',
        errors: combined.errors,
      );
    }

    log(
      '✅ deleteAllUserData complete — total deleted: ${combined.totalDeleted}',
    );
    return combined;
  }

  Future<DeleteResult?> deleteWithConfirmation({
    required String userId,
    required String email,
    required Future<bool> Function(Map<String, int> counts) onConfirm,
    bool strict = true,
    bool showLogs = true,
  }) async {
    final counts = await previewUserDataCounts(userId);
    final confirmed = await onConfirm(counts);
    if (!confirmed) return null;
    return deleteAllUserData(userId, email, strict: strict, showLogs: showLogs);
  }

  Future<DeleteResult> deleteFirebaseCollections(
    List<String> collections,
    String userId, {
    bool showLogs = true,
  }) => _firebaseService.deleteByUserId(
    collections: collections,
    userId: userId,
    showLogs: showLogs,
  );

  Future<DeleteResult> deleteSupabaseCollections(
    List<String> collections,
    String userId, {
    bool showLogs = true,
  }) => _supabaseService.deleteByUserId(
    collections: collections,
    userId: userId,
    showLogs: showLogs,
  );

  Future<int> _safeCount(Query query) async {
    try {
      final snap = await query.count().get();
      return snap.count ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<bool> _docExists(String collection, String docId) async {
    try {
      final snap = await _col(collection).doc(docId).get();
      return snap.exists;
    } catch (_) {
      return false;
    }
  }

  Future<int> _countAllMessagesForUser(String userId) async {
    try {
      final convSnap = await _col(
        'conversations',
      ).where('participant_ids', arrayContains: userId).get();

      if (convSnap.docs.isEmpty) return 0;

      final counts = await Future.wait(
        convSnap.docs.map((d) async {
          final snap = await _messages(d.id).count().get();
          return snap.count ?? 0;
        }),
      );

      return counts.fold<int>(0, (a, b) => a + b);
    } catch (_) {
      return 0;
    }
  }

  Future<int> _deleteAllMessagesForUser(
    String userId, {
    bool showLogs = true,
  }) async {
    final convSnap = await _col(
      'conversations',
    ).where('participant_ids', arrayContains: userId).get();

    if (convSnap.docs.isEmpty) {
      if (showLogs) {
        print('✅ conversations/messages: 0 (no conversations found)');
      }
      return 0;
    }

    int totalMessages = 0;

    for (final convDoc in convSnap.docs) {
      final convId = convDoc.id;
      int convMessages = 0;

      while (true) {
        final msgSnap = await _messages(convId).limit(_batchSize).get();
        if (msgSnap.docs.isEmpty) break;

        final batch = _db.batch();
        for (final msg in msgSnap.docs) {
          batch.delete(msg.reference);
        }
        await batch.commit();

        convMessages += msgSnap.docs.length;
        totalMessages += msgSnap.docs.length;

        if (msgSnap.docs.length < _batchSize) break;
      }

      if (showLogs && convMessages > 0) {
        print('  ✅ conversations/$convId/messages: $convMessages deleted');
      }
    }

    if (showLogs) print('✅ conversations/messages total: $totalMessages');
    return totalMessages;
  }
}

class DeleteRepositoryException implements Exception {
  const DeleteRepositoryException(this.message, {this.errors = const {}});

  final String message;
  final Map<String, String> errors;

  @override
  String toString() =>
      'DeleteRepositoryException: $message\n'
      '${errors.entries.map((e) => '  ${e.key}: ${e.value}').join('\n')}';
}