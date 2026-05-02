// ignore_for_file: avoid_print

import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:edumap_portfolio_project/core/services/cloud/delete_service.dart';

const int _kMaxRetries = 3;
const Duration _kRetryBase = Duration(milliseconds: 400);

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

    counts['conversations'] =
        await _safeCount(
          _col('conversations').where('created_by', isEqualTo: userId),
        ) +
        await _safeCount(
          _col('conversations').where('participant_ids', arrayContains: userId),
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

    log('── Step 1: deleting messages (all conversations)…');
    combined = combined.merge(
      await _retried(
        label: 'conversations/messages',
        action: () async {
          final count = await _deleteAllMessagesForUser(
            userId,
            showLogs: showLogs,
          );
          return DeleteResult(
            totalDeleted: count,
            results: {'conversations/messages': count},
            errors: {},
          );
        },
        showLogs: showLogs,
      ),
    );

    log('── Step 2: deleting conversations…');
    combined = combined.merge(
      await _retried(
        label: 'conversations',
        action: () => _firebaseService.deleteByField(
          collection: 'conversations',
          field: 'created_by',
          userId: userId,
          showLogs: showLogs,
        ),
        showLogs: showLogs,
      ),
    );

    log('── Step 3: deleting friend_requests…');
    for (final field in ['from_user_id', 'to_user_id']) {
      combined = combined.merge(
        await _retried(
          label: 'friend_requests[$field]',
          action: () => _firebaseService.deleteByField(
            collection: 'friend_requests',
            field: field,
            userId: userId,
            showLogs: showLogs,
          ),
          showLogs: showLogs,
        ),
      );
    }

    log('── Step 4: deleting friends…');
    for (final field in ['user_id_1', 'user_id_2']) {
      combined = combined.merge(
        await _retried(
          label: 'friends[$field]',
          action: () => _firebaseService.deleteByField(
            collection: 'friends',
            field: field,
            userId: userId,
            showLogs: showLogs,
          ),
          showLogs: showLogs,
        ),
      );
    }

    log('── Step 5: deleting presence…');
    combined = combined.merge(
      await _retried(
        label: 'presence',
        action: () => _firebaseService.deleteDocById(
          collection: 'presence',
          docId: userId,
          showLogs: showLogs,
        ),
        showLogs: showLogs,
      ),
    );

    log('── Step 6: deleting standard Firebase collections…');
    combined = combined.merge(
      await _retried(
        label: 'firebase_collections',
        action: () => _firebaseService.deleteByUserId(
          collections: AppConfig.firebaseUserIdCollections,
          userId: userId,
          showLogs: showLogs,
        ),
        showLogs: showLogs,
      ),
    );

    log('── Step 7: deleting profile…');
    combined = combined.merge(
      await _retried(
        label: 'profiles',
        action: () => _deleteProfileWithFallback(
          userId: userId,
          email: email,
          showLogs: showLogs,
        ),
        showLogs: showLogs,
      ),
    );

    log('── Step 8: deleting Supabase DB rows…');
    combined = combined.merge(
      await _retried(
        label: 'supabase_db',
        action: () => _supabaseService.deleteByUserId(
          collections: AppConfig.supabaseUserIdCollections,
          userId: userId,
          showLogs: showLogs,
        ),
        showLogs: showLogs,
      ),
    );

    log('── Step 9: deleting Supabase Storage files…');
    combined = combined.merge(
      await _retried(
        label: 'supabase_storage',
        action: () =>
            _supabaseService.deleteStorageForUser(userId, showLogs: showLogs),
        showLogs: showLogs,
      ),
    );

    log('── Step 10: verifying — re-counting remaining data…');
    final remaining = await previewUserDataCounts(userId);
    final leaked = remaining.entries.where((e) => e.value > 0).toList();

    if (leaked.isNotEmpty) {
      log('⚠️  Data still found after initial sweep. Running cleanup pass…');
      final cleanupResult = await _cleanupLeaked(
        leaked,
        userId,
        email,
        showLogs: showLogs,
      );
      combined = combined.merge(cleanupResult);

      final afterCleanup = await previewUserDataCounts(userId);
      final stillLeaked = afterCleanup.entries
          .where((e) => e.value > 0)
          .toList();

      if (stillLeaked.isNotEmpty) {
        final leakSummary = stillLeaked
            .map((e) => '${e.key}=${e.value}')
            .join(', ');
        log('❌ Still remaining after cleanup: $leakSummary');
        combined = combined.merge(
          DeleteResult(
            totalDeleted: 0,
            results: {},
            errors: {
              'verification': 'Undeleted data after cleanup: $leakSummary',
            },
          ),
        );
      } else {
        log('✅ Verification cleanup successful — no data remains.');
      }
    } else {
      log('✅ Verification passed — no data remains.');
    }

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

  Future<DeleteResult> _cleanupLeaked(
    List<MapEntry<String, int>> leaked,
    String userId,
    String email, {
    required bool showLogs,
  }) async {
    DeleteResult result = const DeleteResult(
      totalDeleted: 0,
      results: {},
      errors: {},
    );

    void log(String msg) {
      if (showLogs) print(msg);
    }

    for (final entry in leaked) {
      final key = entry.key;
      log('  ↩️  Cleanup: $key (${entry.value} remaining)');

      switch (key) {
        case 'conversations/messages':
          result = result.merge(
            await _retried(
              label: 'cleanup:conversations/messages',
              action: () async {
                final count = await _deleteAllMessagesForUser(
                  userId,
                  showLogs: showLogs,
                );
                return DeleteResult(
                  totalDeleted: count,
                  results: {'cleanup:conversations/messages': count},
                  errors: {},
                );
              },
              showLogs: showLogs,
            ),
          );

        case 'conversations':
          result = result.merge(
            await _retried(
              label: 'cleanup:conversations',
              action: () => _firebaseService.deleteByField(
                collection: 'conversations',
                field: 'created_by',
                userId: userId,
                showLogs: showLogs,
              ),
              showLogs: showLogs,
            ),
          );

        case 'friend_requests':
          for (final field in ['from_user_id', 'to_user_id']) {
            result = result.merge(
              await _retried(
                label: 'cleanup:friend_requests[$field]',
                action: () => _firebaseService.deleteByField(
                  collection: 'friend_requests',
                  field: field,
                  userId: userId,
                  showLogs: showLogs,
                ),
                showLogs: showLogs,
              ),
            );
          }

        case 'friends':
          for (final field in ['user_id_1', 'user_id_2']) {
            result = result.merge(
              await _retried(
                label: 'cleanup:friends[$field]',
                action: () => _firebaseService.deleteByField(
                  collection: 'friends',
                  field: field,
                  userId: userId,
                  showLogs: showLogs,
                ),
                showLogs: showLogs,
              ),
            );
          }

        case 'presence':
          result = result.merge(
            await _retried(
              label: 'cleanup:presence',
              action: () => _firebaseService.deleteDocById(
                collection: 'presence',
                docId: userId,
                showLogs: showLogs,
              ),
              showLogs: showLogs,
            ),
          );

        case 'profiles':
          result = result.merge(
            await _retried(
              label: 'cleanup:profiles',
              action: () => _deleteProfileWithFallback(
                userId: userId,
                email: email,
                showLogs: showLogs,
              ),
              showLogs: showLogs,
            ),
          );

        default:
          if (AppConfig.firebaseUserIdCollections.contains(key)) {
            result = result.merge(
              await _retried(
                label: 'cleanup:$key',
                action: () => _firebaseService.deleteByUserId(
                  collections: [key],
                  userId: userId,
                  showLogs: showLogs,
                ),
                showLogs: showLogs,
              ),
            );
          } else if (AppConfig.supabaseUserIdCollections.contains(key)) {
            result = result.merge(
              await _retried(
                label: 'cleanup:$key',
                action: () => _supabaseService.deleteByUserId(
                  collections: [key],
                  userId: userId,
                  showLogs: showLogs,
                ),
                showLogs: showLogs,
              ),
            );
          }
      }
    }

    return result;
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

  Future<DeleteResult> _deleteProfileWithFallback({
    required String userId,
    required String email,
    bool showLogs = true,
  }) async {
    void log(String msg) {
      if (showLogs) print(msg);
    }

    final primaryResult = await _firebaseService.deleteProfileByUserIdAndEmail(
      userId: userId,
      email: email,
      showLogs: showLogs,
    );

    if (primaryResult.totalDeleted > 0) return primaryResult;

    log(
      '⚠️  profiles: email lookup found nothing — falling back to user_id only',
    );

    final snap = await _col(
      'profiles',
    ).where('user_id', isEqualTo: userId).get();

    if (snap.docs.isEmpty) {
      log('✅ profiles: 0 found by user_id either — nothing to delete');
      return const DeleteResult(totalDeleted: 0, results: {}, errors: {});
    }

    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();

    log('✅ profiles: ${snap.docs.length} deleted by user_id fallback');
    return DeleteResult(
      totalDeleted: snap.docs.length,
      results: {'profiles': snap.docs.length},
      errors: {},
    );
  }

  Future<DeleteResult> _retried({
    required String label,
    required Future<DeleteResult> Function() action,
    bool showLogs = true,
  }) async {
    for (int attempt = 1; attempt <= _kMaxRetries; attempt++) {
      try {
        return await action();
      } catch (e) {
        final isLast = attempt == _kMaxRetries;
        if (showLogs) {
          print(
            isLast
                ? '❌ $label failed after $attempt attempt(s): $e'
                : '⚠️  $label attempt $attempt failed, retrying in ${_kRetryBase.inMilliseconds * pow(2, attempt - 1).toInt()}ms… ($e)',
          );
        }
        if (isLast) {
          return DeleteResult(
            totalDeleted: 0,
            results: {},
            errors: {label: e.toString()},
          );
        }
        await Future<void>.delayed(_kRetryBase * pow(2, attempt - 1).toInt());
      }
    }
    return DeleteResult(
      totalDeleted: 0,
      results: {},
      errors: {label: 'Unknown error after $_kMaxRetries retries'},
    );
  }

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
    final participantSnap = await _col(
      'conversations',
    ).where('participant_ids', arrayContains: userId).get();

    final createdSnap = await _col(
      'conversations',
    ).where('created_by', isEqualTo: userId).get();

    final seen = <String>{};
    final allDocs = [
      ...participantSnap.docs,
      ...createdSnap.docs,
    ].where((d) => seen.add(d.id)).toList();

    if (allDocs.isEmpty) {
      if (showLogs) {
        print('✅ conversations/messages: 0 (no conversations found)');
      }
      return 0;
    }

    int totalMessages = 0;

    for (final convDoc in allDocs) {
      final convId = convDoc.id;
      int convMessages = 0;

      while (true) {
        final msgSnap = await _messages(convId).limit(_batchSize).get();
        if (msgSnap.docs.isEmpty) break;

        try {
          final batch = _db.batch();
          for (final msg in msgSnap.docs) {
            batch.delete(msg.reference);
          }
          await batch.commit();
          convMessages += msgSnap.docs.length;
          totalMessages += msgSnap.docs.length;
        } catch (e) {
          if (showLogs) {
            print(
              '  ⚠️  batch commit failed for $convId: $e — will retry on verification pass',
            );
          }
          break;
        }

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