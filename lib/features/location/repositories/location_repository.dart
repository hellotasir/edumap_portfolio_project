import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:edumap_portfolio_project/features/location/models/location_model.dart';
import 'package:uuid/uuid.dart';

class UserLocationRepository {
  UserLocationRepository({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  static const _collection = 'locations';
  static const _uuid = Uuid();

  DocumentReference<Map<String, dynamic>> _docRef(String userId) =>
      _db.collection(_collection).doc(userId);

  Future<UserLocationDoc> getDoc(String userId) async {
    final snap = await _docRef(userId).get();
    if (!snap.exists) return UserLocationDoc.empty(userId);
    return UserLocationDoc.fromSnapshot(snap);
  }

  Stream<UserLocationDoc> watchDoc(String userId) =>
      _docRef(userId).snapshots().map((snap) {
        if (!snap.exists) return UserLocationDoc.empty(userId);
        return UserLocationDoc.fromSnapshot(snap);
      });

  Future<void> _saveDoc(String userId, Map<String, dynamic> entriesMap) async {
    await _docRef(userId).set({
      'user_id': userId,
      'entries': entriesMap,
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<String> upsertCurrentLocation({
    required String userId,
    required String title,
    required AddressCategory category,
    required LatLng coordinates,
    required AddressComponents address,
    required bool isVisible,
    double? accuracy,
  }) async {
    final doc = await getDoc(userId);
    final existing = doc.currentLocation;
    final now = DateTime.now();
    final entryId = existing?.entryId ?? _uuid.v4();

    final entry = UserAddressEntry(
      entryId: entryId,
      title: title,
      category: category,
      type: AddressType.currentLocation,
      coordinates: coordinates,
      address: address,
      isVisible: isVisible,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
      accuracy: accuracy,
    );

    final updatedEntries = {for (final e in doc.entries) e.entryId: e.toMap()};
    updatedEntries[entryId] = entry.toMap();

    await _saveDoc(userId, updatedEntries);
    return entryId;
  }

  Future<String> addSavedAddress({
    required String userId,
    required String title,
    required AddressCategory category,
    required LatLng coordinates,
    required AddressComponents address,
    required bool isVisible,
  }) async {
    final doc = await getDoc(userId);
    final now = DateTime.now();
    final entryId = _uuid.v4();

    final entry = UserAddressEntry(
      entryId: entryId,
      title: title,
      category: category,
      type: AddressType.saved,
      coordinates: coordinates,
      address: address,
      isVisible: isVisible,
      createdAt: now,
      updatedAt: now,
    );

    final updatedEntries = {for (final e in doc.entries) e.entryId: e.toMap()};
    updatedEntries[entryId] = entry.toMap();

    await _saveDoc(userId, updatedEntries);
    return entryId;
  }

  Future<void> updateEntryVisibility({
    required String userId,
    required String entryId,
    required bool isVisible,
  }) async {
    await _docRef(userId).update({
      'entries.$entryId.is_visible': isVisible,
      'entries.$entryId.updated_at': Timestamp.fromDate(DateTime.now()),
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateEntryTitle({
    required String userId,
    required String entryId,
    required String title,
  }) async {
    await _docRef(userId).update({
      'entries.$entryId.title': title,
      'entries.$entryId.updated_at': Timestamp.fromDate(DateTime.now()),
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteEntry({
    required String userId,
    required String entryId,
  }) async {
    await _docRef(userId).update({
      'entries.$entryId': FieldValue.delete(),
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  Future<UserLocationDoc?> getDocForUser(String userId) async {
    final snap = await _docRef(userId).get();
    if (!snap.exists) return null;
    return UserLocationDoc.fromSnapshot(snap);
  }
}
