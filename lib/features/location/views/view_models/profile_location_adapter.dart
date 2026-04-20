import 'package:flutter_education_app/core/services/cloud/location_service.dart';
import 'package:flutter_education_app/core/services/cloud/profile_location_service.dart';
import 'package:flutter_education_app/features/location/models/local_model.dart';

class ProfileLocationAdapter implements LocationService {
  ProfileLocationAdapter({
    required ProfileLocationService profileLocationService,
    required LocationService locationService,
  }) : _service = profileLocationService,
       _locationService = locationService;

  final ProfileLocationService _service;
  final LocationService _locationService;

  @override
  Future<LocationModel> saveCurrentLocation({
    required String userId,
    required String role,
    bool isVisible = true,
  }) => _service.saveCurrentLocation(userId: userId, role: role);

  @override
  Future<LocationModel> saveCustomLocation({
    required String userId,
    required String role,
    required String rawAddress,
    String? label,
    bool isDefault = false,
    bool isVisible = true,
  }) async {
    await _service.saveCustomLocation(
      userId: userId,
      role: role,
      rawAddress: rawAddress,
      label: label,
      isVisible: isVisible,
    );

    final saved =
        await _locationService.getDefaultLocation(userId, role) ??
        await _locationService.getCurrentLocation(userId, role);

    if (saved == null) {
      throw StateError(
        'saveCustomLocation succeeded but no location found for $userId/$role.',
      );
    }

    return saved;
  }

  @override
  Future<void> setDefaultLocation({
    required String userId,
    required String role,
    required String locationId,
  }) => _service.setDefaultLocation(
    userId: userId,
    role: role,
    locationId: locationId,
  );

  @override
  Future<void> deleteCustomLocation(String locationId) =>
      _service.deleteCustomLocation(locationId);

  @override
  Stream<LocationModel?> watchCurrentLocation(String userId, String role) =>
      _service.watchCurrentLocation(userId, role);

  @override
  Stream<List<LocationModel>> watchAllLocations(String userId, String role) =>
      _service.watchAllLocations(userId, role);

  @override
  Future<LocationModel?> getDefaultLocation(String userId, String role) =>
      _service.getDefaultLocation(userId, role);

  @override
  Future<LocationModel?> getCurrentLocation(String userId, String role) =>
      _locationService.getCurrentLocation(userId, role);

  @override
  Future<double?> distanceBetween({
    required String userIdA,
    required String roleA,
    required String userIdB,
    required String roleB,
  }) => _locationService.distanceBetween(
    userIdA: userIdA,
    roleA: roleA,
    userIdB: userIdB,
    roleB: roleB,
  );

  Future<List<LocationModel>> getAllLocationsForUser(String userId) =>
      _locationService.getAllLocationsForUser(userId);
}
