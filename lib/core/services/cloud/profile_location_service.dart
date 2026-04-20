import 'package:flutter_education_app/core/services/cloud/location_service.dart';
import 'package:flutter_education_app/features/location/models/local_model.dart';
import 'package:flutter_education_app/features/location/repositories/profile_location_repository.dart';

class ProfileLocationService {
  ProfileLocationService({
    required LocationService locationService,
    ProfileLocationRepository? profileLocationRepository,
  }) : _locationService = locationService,
       _profileRepo = profileLocationRepository ?? ProfileLocationRepository();

  final LocationService _locationService;
  final ProfileLocationRepository _profileRepo;

  Stream<LocationModel?> watchCurrentLocation(String userId, String role) =>
      _locationService.watchCurrentLocation(userId, role);

  Stream<List<LocationModel>> watchAllLocations(String userId, String role) =>
      _locationService.watchAllLocations(userId, role);

  Future<LocationModel?> getDefaultLocation(String userId, String role) =>
      _locationService.getDefaultLocation(userId, role);

  Future<void> setDefaultLocation({
    required String userId,
    required String role,
    required String locationId,
  }) => _locationService.setDefaultLocation(
    userId: userId,
    role: role,
    locationId: locationId,
  );

  Future<void> deleteCustomLocation(String locationId) =>
      _locationService.deleteCustomLocation(locationId);

  Future<LocationModel> saveCurrentLocation({
    required String userId,
    required String role,
  }) async {
    final model = await _locationService.saveCurrentLocation(
      userId: userId,
      role: role,
    );
    _syncToProfile(userId, model);
    return model;
  }

  Future<void> saveCustomLocation({
    required String userId,
    required String role,
    required String rawAddress,
    String? label,
    bool isVisible = true,
  }) async {
    await _locationService.saveCustomLocation(
      userId: userId,
      role: role,
      rawAddress: rawAddress,
      label: label,
      isVisible: isVisible,
    );
    _syncDefaultToProfile(userId, role);
  }

  Future<ProfileLocationSnapshot?> getProfileLocation(String userId) =>
      _profileRepo.getProfileLocation(userId);

  Stream<ProfileLocationSnapshot?> watchProfileLocation(String userId) =>
      _profileRepo.watchProfileLocation(userId);

  Future<void> revokeProfileLocation(String userId) =>
      _profileRepo.clearLocationFromProfile(userId);

  void _syncToProfile(String userId, LocationModel model) {
    _profileRepo
        .syncLocationToProfile(userId: userId, location: model)
        .catchError((_) => null);
  }

  Future<void> _syncDefaultToProfile(String userId, String role) async {
    try {
      final defaultLocation = await _locationService.getDefaultLocation(
        userId,
        role,
      );
      if (defaultLocation != null) {
        await _profileRepo.syncLocationToProfile(
          userId: userId,
          location: defaultLocation,
        );
      }
    } catch (_) {}
  }
}
