import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:edumap_portfolio_project/features/auth/repositories/auth_repository.dart';
import 'package:edumap_portfolio_project/features/app/repositories/database_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DatabaseService<T> {
  DatabaseService(this._repository, {FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final DatabaseRepository<T> _repository;
  final FirebaseFirestore _firestore;
  final AuthRepository _authRepository = AuthRepository();

  String? get currentUserId => _authRepository.currentUser?.id;
  User? get currentUser => _authRepository.currentUser;
  Stream<AuthState> get authStateChanges => _authRepository.authChanges;

  CollectionReference<Map<String, dynamic>> get _collection {
    final path = _repository.collectionPath;

    if (path.isEmpty) throw ArgumentError('collectionPath must not be empty.');
    if (path.length % 2 == 0) {
      throw ArgumentError(
        'collectionPath must have an odd number of segments. Got: $path',
      );
    }

    CollectionReference<Map<String, dynamic>> ref = _firestore.collection(
      path[0],
    );

    for (var i = 1; i < path.length; i += 2) {
      ref = ref.doc(path[i]).collection(path[i + 1]);
    }

    return ref;
  }

  DocumentReference<Map<String, dynamic>> _doc(String docId) =>
      _collection.doc(docId);

  Future<String> add(T model) async {
    final docRef = await _collection.add(_repository.toMap(model));
    return docRef.id;
  }

  Future<void> set(String docId, T model) =>
      _doc(docId).set(_repository.toMap(model));

  Future<T?> getById(String docId) async {
    final snap = await _doc(docId).get();
    if (!snap.exists || snap.data() == null) return null;
    return _repository.fromSnapshot(snap);
  }

  Stream<T?> watchById(String docId) => _doc(docId).snapshots().map((snap) {
    if (!snap.exists || snap.data() == null) return null;
    return _repository.fromSnapshot(snap);
  });

  Future<List<T>> getAll({
    Query<Map<String, dynamic>> Function(
      CollectionReference<Map<String, dynamic>>,
    )?
    query,
  }) async {
    final ref = query != null ? query(_collection) : _collection;
    final snap = await ref.get();
    return snap.docs.map((d) => _repository.fromSnapshot(d)).toList();
  }

  Stream<List<T>> watchAll({
    Query<Map<String, dynamic>> Function(
      CollectionReference<Map<String, dynamic>>,
    )?
    query,
  }) {
    final ref = query != null ? query(_collection) : _collection;
    return ref.snapshots().map(
      (snap) => snap.docs.map((d) => _repository.fromSnapshot(d)).toList(),
    );
  }

  Future<void> update(String docId, Map<String, dynamic> fields) =>
      _doc(docId).update(fields);

  Future<void> replace(String docId, T model) =>
      _doc(docId).set(_repository.toMap(model));

  Future<bool> exists(String docId) async {
    final snap = await _doc(docId).get();
    return snap.exists;
  }

  Future<void> deleteByDocId(String docId) => _doc(docId).delete();

  Future<void> deleteCollection({int batchSize = 100}) async {
    QuerySnapshot<Map<String, dynamic>> snapshot;
    do {
      snapshot = await _collection.limit(batchSize).get();
      if (snapshot.docs.isEmpty) break;
      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } while (snapshot.docs.length == batchSize);
  }

  Future<void> deleteMany(List<String> docIds) async {
    if (docIds.isEmpty) return;
    const limit = 500;
    for (var i = 0; i < docIds.length; i += limit) {
      final chunk = docIds.sublist(i, (i + limit).clamp(0, docIds.length));
      final batch = _firestore.batch();
      for (final id in chunk) {
        batch.delete(_doc(id));
      }
      await batch.commit();
    }
  }
}
