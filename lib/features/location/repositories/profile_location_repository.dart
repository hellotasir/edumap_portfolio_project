import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_education_app/features/location/models/local_model.dart';

class ProfileLocationSnapshot {
  const ProfileLocationSnapshot({
    required this.latitude,
    required this.longitude,
    required this.city,
    required this.country,
    required this.formattedAddress,
    this.accuracy,
    this.sharedAt,
  });

  final double latitude;
  final double longitude;
  final String city;
  final String country;
  final String formattedAddress;
  final double? accuracy;
  final DateTime? sharedAt;

  factory ProfileLocationSnapshot.fromModel(LocationModel model) =>
      ProfileLocationSnapshot(
        latitude: model.coordinates.latitude,
        longitude: model.coordinates.longitude,
        city: model.address.city,
        country: model.address.country,
        formattedAddress: model.address.formattedAddress,
        accuracy: model.accuracy,
        sharedAt: model.updatedAt,
      );

  @override
  String toString() =>
      'ProfileLocationSnapshot($city, $country @ $latitude, $longitude)';
}

class ProfileLocationRepository {
  ProfileLocationRepository({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  static const _collection = 'locations';

  CollectionReference<Map<String, dynamic>> get _ref =>
      _db.collection(_collection);

  Future<void> syncLocationToProfile({
    required String userId,
    required LocationModel location,
  }) async {
    if (location.id == null) return;
    await _ref.doc(location.id).update({
      'is_visible': true,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> clearLocationFromProfile(String userId) async {
    final snap = await _ref.where('user_id', isEqualTo: userId).get();
    if (snap.docs.isEmpty) return;
    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'is_visible': false});
    }
    await batch.commit();
  }

  Future<ProfileLocationSnapshot?> getProfileLocation(String userId) async {
    final snap = await _ref
        .where('user_id', isEqualTo: userId)
        .where('is_visible', isEqualTo: true)
        .get();

    if (snap.docs.isEmpty) return null;

    final locations = snap.docs
        .map((d) => LocationModel.fromSnapshot(d))
        .toList();

    final best = _pickBestLocation(locations);
    return best != null ? ProfileLocationSnapshot.fromModel(best) : null;
  }

  Stream<ProfileLocationSnapshot?> watchProfileLocation(String userId) => _ref
      .where('user_id', isEqualTo: userId)
      .where('is_visible', isEqualTo: true)
      .snapshots()
      .map((snap) {
        if (snap.docs.isEmpty) return null;
        final locations = snap.docs
            .map((d) => LocationModel.fromSnapshot(d))
            .toList();
        final best = _pickBestLocation(locations);
        return best != null ? ProfileLocationSnapshot.fromModel(best) : null;
      });

  LocationModel? _pickBestLocation(List<LocationModel> locations) {
    for (final loc in locations) {
      if (loc.type == LocationType.customAddress && loc.isDefault) return loc;
    }
    for (final loc in locations) {
      if (loc.type == LocationType.currentLocation) return loc;
    }
    return locations.isNotEmpty ? locations.first : null;
  }
}
