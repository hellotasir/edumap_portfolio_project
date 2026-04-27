// ignore_for_file: avoid_print

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum BackendType { firebase, supabase }

class DeleteResult {
  const DeleteResult({
    required this.totalDeleted,
    required this.results,
    required this.errors,
  });

  final int totalDeleted;
  final Map<String, int> results;
  final Map<String, String> errors;

  bool get hasErrors => errors.isNotEmpty;
  bool get isSuccess => !hasErrors && totalDeleted > 0;

  DeleteResult merge(DeleteResult other) => DeleteResult(
    totalDeleted: totalDeleted + other.totalDeleted,
    results: {...results, ...other.results},
    errors: {...errors, ...other.errors},
  );

  @override
  String toString() =>
      'DeleteResult(total: $totalDeleted, errors: ${errors.keys.join(', ')})';
}

class AppConfig {
  static const List<String> firebaseUserIdCollections = [
    'locations',
    'feedback',
  ];

  static const List<String> supabaseUserIdCollections = [
    'user_fcm_tokens',
    'payments',
  ];

  static const Map<String, List<String>> storageBucketPrefixes = {
    'user-media': ['avatars', 'covers'],
    'chat-media': ['images', 'videos', 'audio', 'files', 'groups'],
  };

  static List<String> get standardUserIdCollections => [
    ...firebaseUserIdCollections,
    ...supabaseUserIdCollections,
  ];
}

abstract class DeleteService {
  Future<DeleteResult> deleteByUserId({
    required List<String> collections,
    required String userId,
    bool showLogs = true,
  });

  Future<DeleteResult> deleteByField({
    required String collection,
    required String field,
    required String userId,
    bool showLogs = true,
  });

  Future<DeleteResult> deleteDocById({
    required String collection,
    required String docId,
    bool showLogs = true,
  });

  Future<DeleteResult> deleteProfileByUserIdAndEmail({
    required String userId,
    required String email,
    bool showLogs = true,
  });

  Future<DeleteResult> deleteStorageForUser(
    String userId, {
    bool showLogs = true,
  });

  factory DeleteService(BackendType type) {
    switch (type) {
      case BackendType.firebase:
        return _FirebaseDeleteService();
      case BackendType.supabase:
        return _SupabaseDeleteService();
    }
  }
}

class _FirebaseDeleteService implements DeleteService {
  final _db = FirebaseFirestore.instance;
  static const int _batchSize = 400;

  Future<int> _deleteQuery(Query query) async {
    int total = 0;
    while (true) {
      final snap = await query.limit(_batchSize).get();
      if (snap.docs.isEmpty) break;
      final batch = _db.batch();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      total += snap.docs.length;
      if (snap.docs.length < _batchSize) break;
    }
    return total;
  }

  Future<int> _deleteWhere(String col, String field, String userId) =>
      _deleteQuery(_db.collection(col).where(field, isEqualTo: userId));

  @override
  Future<DeleteResult> deleteByField({
    required String collection,
    required String field,
    required String userId,
    bool showLogs = true,
  }) async {
    final errors = <String, String>{};
    int deleted = 0;
    try {
      deleted = await _deleteWhere(collection, field, userId);
      if (showLogs) print('✅ $collection[$field=$userId]: $deleted deleted');
    } catch (e) {
      errors['$collection[$field]'] = e.toString();
      if (showLogs) print('❌ $collection[$field=$userId]: $e');
    }
    return DeleteResult(
      totalDeleted: deleted,
      results: {collection: deleted},
      errors: errors,
    );
  }

  @override
  Future<DeleteResult> deleteByUserId({
    required List<String> collections,
    required String userId,
    bool showLogs = true,
  }) async {
    final results = <String, int>{};
    int total = 0;
    final errors = <String, String>{};
    for (final col in collections) {
      try {
        final deleted = await _deleteWhere(col, 'user_id', userId);
        results[col] = deleted;
        total += deleted;
        if (showLogs) print('✅ $col[user_id=$userId]: $deleted deleted');
      } catch (e) {
        errors[col] = e.toString();
        if (showLogs) print('❌ $col[user_id=$userId]: $e');
      }
    }
    return DeleteResult(totalDeleted: total, results: results, errors: errors);
  }

  @override
  Future<DeleteResult> deleteProfileByUserIdAndEmail({
    required String userId,
    required String email,
    bool showLogs = true,
  }) async {
    final errors = <String, String>{};
    int deleted = 0;
    try {
      final snap = await _db
          .collection('profiles')
          .where('user_id', isEqualTo: userId)
          .where('email', isEqualTo: email)
          .get();

      if (snap.docs.isNotEmpty) {
        final batch = _db.batch();
        for (final doc in snap.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
        deleted = snap.docs.length;
        if (showLogs)
          print('✅ profiles[user_id=$userId, email=$email]: $deleted deleted');
      } else {
        if (showLogs)
          print('ℹ️  profiles[user_id=$userId, email=$email]: 0 found');
      }
    } catch (e) {
      errors['profiles'] = e.toString();
      if (showLogs) print('❌ profiles[user_id=$userId, email=$email]: $e');
    }
    return DeleteResult(
      totalDeleted: deleted,
      results: {'profiles': deleted},
      errors: errors,
    );
  }

  @override
  Future<DeleteResult> deleteDocById({
    required String collection,
    required String docId,
    bool showLogs = true,
  }) async {
    final errors = <String, String>{};
    int deleted = 0;
    try {
      await _db.collection(collection).doc(docId).delete();
      deleted = 1;
      if (showLogs) print('✅ $collection/$docId: deleted');
    } catch (e) {
      errors['$collection/$docId'] = e.toString();
      if (showLogs) print('❌ $collection/$docId: $e');
    }
    return DeleteResult(
      totalDeleted: deleted,
      results: {'$collection/$docId': deleted},
      errors: errors,
    );
  }

  @override
  Future<DeleteResult> deleteStorageForUser(
    String userId, {
    bool showLogs = true,
  }) async {
    if (showLogs) print('ℹ️  Firebase Storage: skipped (no-op)');
    return const DeleteResult(totalDeleted: 0, results: {}, errors: {});
  }
}

class _SupabaseDeleteService implements DeleteService {
  final _supabase = Supabase.instance.client;

  Future<int> _deleteWhere(String table, String field, String userId) async {
    final countRes = await _supabase
        .from(table)
        .select()
        .eq(field, userId)
        .count(CountOption.exact);
    final count = countRes.count;
    if (count == 0) return 0;
    await _supabase.from(table).delete().eq(field, userId);
    return count;
  }

  @override
  Future<DeleteResult> deleteByField({
    required String collection,
    required String field,
    required String userId,
    bool showLogs = true,
  }) async {
    final errors = <String, String>{};
    int deleted = 0;
    try {
      deleted = await _deleteWhere(collection, field, userId);
      if (showLogs) print('✅ $collection[$field=$userId]: $deleted deleted');
    } catch (e) {
      errors['$collection[$field]'] = e.toString();
      if (showLogs) print('❌ $collection[$field=$userId]: $e');
    }
    return DeleteResult(
      totalDeleted: deleted,
      results: {collection: deleted},
      errors: errors,
    );
  }

  @override
  Future<DeleteResult> deleteByUserId({
    required List<String> collections,
    required String userId,
    bool showLogs = true,
  }) async {
    final results = <String, int>{};
    int total = 0;
    final errors = <String, String>{};
    for (final table in collections) {
      try {
        final deleted = await _deleteWhere(table, 'user_id', userId);
        results[table] = deleted;
        total += deleted;
        if (showLogs) print('✅ $table[user_id=$userId]: $deleted deleted');
      } catch (e) {
        errors[table] = e.toString();
        if (showLogs) print('❌ $table[user_id=$userId]: $e');
      }
    }
    return DeleteResult(totalDeleted: total, results: results, errors: errors);
  }

  @override
  Future<DeleteResult> deleteProfileByUserIdAndEmail({
    required String userId,
    required String email,
    bool showLogs = true,
  }) async {
    return const DeleteResult(totalDeleted: 0, results: {}, errors: {});
  }

  @override
  Future<DeleteResult> deleteDocById({
    required String collection,
    required String docId,
    bool showLogs = true,
  }) async {
    final errors = <String, String>{};
    int deleted = 0;
    try {
      await _supabase.from(collection).delete().eq('id', docId);
      deleted = 1;
      if (showLogs) print('✅ $collection/$docId: deleted');
    } catch (e) {
      errors['$collection/$docId'] = e.toString();
      if (showLogs) print('❌ $collection/$docId: $e');
    }
    return DeleteResult(
      totalDeleted: deleted,
      results: {'$collection/$docId': deleted},
      errors: errors,
    );
  }

  @override
  Future<DeleteResult> deleteStorageForUser(
    String userId, {
    bool showLogs = true,
  }) async {
    final results = <String, int>{};
    int total = 0;
    final errors = <String, String>{};

    for (final entry in AppConfig.storageBucketPrefixes.entries) {
      final bucket = entry.key;
      final prefixes = entry.value;

      for (final prefix in prefixes) {
        final userFolder = '$prefix/$userId';
        final resultKey = '$bucket/$userFolder';

        try {
          final paths = await _collectAllPaths(bucket, userFolder);

          if (paths.isEmpty) {
            if (showLogs) {
              print('ℹ️  $resultKey/: nothing found, skipping');
            }
            results[resultKey] = 0;
            continue;
          }

          if (showLogs) {
            print('🗑  $resultKey/: found ${paths.length} file(s) → deleting…');
            for (final p in paths) {
              print('     • $p');
            }
          }

          await _supabase.storage.from(bucket).remove(paths);

          results[resultKey] = paths.length;
          total += paths.length;
          if (showLogs) {
            print('✅ $resultKey/: ${paths.length} file(s) deleted');
          }
        } catch (e) {
          errors[resultKey] = e.toString();
          if (showLogs) print('❌ $resultKey/: $e');
        }
      }
    }

    return DeleteResult(totalDeleted: total, results: results, errors: errors);
  }

  Future<List<String>> _collectAllPaths(
    String bucket,
    String folderPath,
  ) async {
    final allFilePaths = <String>[];
    await _recurse(bucket, folderPath, allFilePaths);
    return allFilePaths;
  }

  Future<void> _recurse(
    String bucket,
    String folderPath,
    List<String> collector,
  ) async {
    const pageSize = 1000;
    int offset = 0;

    while (true) {
      List<FileObject> items;
      try {
        items = await _supabase.storage
            .from(bucket)
            .list(
              path: folderPath,
              searchOptions: SearchOptions(limit: pageSize, offset: offset),
            );
      } catch (_) {
        break;
      }

      if (items.isEmpty) break;

      for (final item in items) {
        final fullPath = '$folderPath/${item.name}';

        if (item.id == null) {
          await _recurse(bucket, fullPath, collector);
        } else {
          collector.add(fullPath);
        }
      }

      if (items.length < pageSize) break;
      offset += pageSize;
    }
  }
}
