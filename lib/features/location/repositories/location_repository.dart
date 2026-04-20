import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_education_app/features/location/models/local_model.dart';

class LocationRepository {
  LocationRepository({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  static const String _collection = 'locations';

  CollectionReference<Map<String, dynamic>> get _ref =>
      _db.collection(_collection);

  LocationModel _fromSnapshot(DocumentSnapshot doc) =>
      LocationModel.fromSnapshot(doc);

  Future<void> upsertCurrentLocation(LocationModel location) async {
    if (location.id != null) {
      await _ref
          .doc(location.id)
          .set(
            location.toMap()..['updated_at'] = FieldValue.serverTimestamp(),
            SetOptions(merge: true),
          );
      debugPrint('upserted current location [${location.id}]');
      return;
    }

    final existing = await _ref
        .where('user_id', isEqualTo: location.userId)
        .where('role', isEqualTo: location.role)
        .where('type', isEqualTo: 'current_location')
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      final docId = existing.docs.first.id;
      await _ref
          .doc(docId)
          .set(
            location.toMap()..['updated_at'] = FieldValue.serverTimestamp(),
            SetOptions(merge: true),
          );
      debugPrint('upserted current location [$docId]');
    } else {
      final docRef = await _ref.add(
        location.toMap()
          ..['created_at'] = FieldValue.serverTimestamp()
          ..['updated_at'] = FieldValue.serverTimestamp(),
      );
      debugPrint('created current location [${docRef.id}]');
    }
  }

  Future<String> addCustomLocation(LocationModel location) async {
    if (location.isDefault) {
      await _clearDefaults(location.userId, location.role);
    }
    final docRef = await _ref.add(
      location.toMap()
        ..['created_at'] = FieldValue.serverTimestamp()
        ..['updated_at'] = FieldValue.serverTimestamp(),
    );
    return docRef.id;
  }

  Future<void> updateCustomLocation(LocationModel location) async {
    if (location.id == null) return;
    if (location.isDefault) {
      await _clearDefaults(location.userId, location.role);
    }
    await _ref
        .doc(location.id)
        .update(
          location.toMap()..['updated_at'] = FieldValue.serverTimestamp(),
        );
  }

  Future<void> deleteCustomLocation(String docId) => _ref.doc(docId).delete();

  Future<void> setDefaultLocation(
    String userId,
    String role,
    String docId,
  ) async {
    final batch = _db.batch();

    final existing = await _ref
        .where('user_id', isEqualTo: userId)
        .where('role', isEqualTo: role)
        .where('is_default', isEqualTo: true)
        .get();

    for (final doc in existing.docs) {
      batch.update(doc.reference, {'is_default': false});
    }

    batch.update(_ref.doc(docId), {
      'is_default': true,
      'updated_at': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  Future<LocationModel?> getCurrentLocation(String userId, String role) async {
    final snap = await _ref
        .where('user_id', isEqualTo: userId)
        .where('role', isEqualTo: role)
        .where('type', isEqualTo: 'current_location')
        .limit(1)
        .get();
    return snap.docs.isNotEmpty ? _fromSnapshot(snap.docs.first) : null;
  }

  Future<LocationModel?> getDefaultLocation(String userId, String role) async {
    final snap = await _ref
        .where('user_id', isEqualTo: userId)
        .where('role', isEqualTo: role)
        .where('is_visible', isEqualTo: true)
        .get();

    if (snap.docs.isEmpty) return null;

    final locations = snap.docs.map(_fromSnapshot).toList();

    return locations.firstWhereOrNull(
          (l) => l.type == LocationType.customAddress && l.isDefault,
        ) ??
        locations.firstWhereOrNull(
          (l) => l.type == LocationType.currentLocation,
        ) ??
        locations.first;
  }

  Stream<LocationModel?> watchCurrentLocation(String userId, String role) =>
      _ref
          .where('user_id', isEqualTo: userId)
          .where('role', isEqualTo: role)
          .where('type', isEqualTo: 'current_location')
          .limit(1)
          .snapshots()
          .map(
            (snap) =>
                snap.docs.isNotEmpty ? _fromSnapshot(snap.docs.first) : null,
          );

  Stream<List<LocationModel>> watchAllLocations(String userId, String role) =>
      _ref
          .where('user_id', isEqualTo: userId)
          .where('role', isEqualTo: role)
          .snapshots()
          .map(
            (snap) => (snap.docs.map(_fromSnapshot).toList()
              ..sort((a, b) {
                if (a.type == LocationType.currentLocation) return -1;
                if (b.type == LocationType.currentLocation) return 1;
                if (a.isDefault) return -1;
                if (b.isDefault) return 1;
                return 0;
              })),
          );

  Future<List<LocationModel>> getAllLocationsForUser(String userId) async {
    final snap = await _ref.where('user_id', isEqualTo: userId).get();
    return snap.docs.map(_fromSnapshot).toList();
  }

  Future<void> _clearDefaults(String userId, String role) async {
    final batch = _db.batch();
    final snap = await _ref
        .where('user_id', isEqualTo: userId)
        .where('role', isEqualTo: role)
        .where('is_default', isEqualTo: true)
        .get();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'is_default': false});
    }
    await batch.commit();
  }
}

extension _FirstWhereOrNull<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    for (final e in this) {
      if (test(e)) return e;
    }
    return null;
  }
}
