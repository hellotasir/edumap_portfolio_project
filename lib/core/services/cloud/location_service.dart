import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_education_app/features/location/repositories/location_repository.dart';
import 'package:flutter_education_app/features/location/models/local_model.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class LocationPermissionException implements Exception {
  final String message;
  const LocationPermissionException(this.message);
}

class LocationServiceDisabledException implements Exception {
  final String message;
  const LocationServiceDisabledException(this.message);
}

class GeocodingException implements Exception {
  final String message;
  const GeocodingException(this.message);
}

class _NominatimClient {
  static final String _baseUrl = dotenv.env['OPEN_STREET_API_URL']!;
  static const Map<String, String> _headers = {
    'User-Agent': 'FlutterEducationApp/1.0 (demo@email.com)',
    'Accept-Language': 'en',
  };

  Future<Map<String, dynamic>> reverseGeocode(double lat, double lng) async {
    final url = Uri.parse('$_baseUrl/reverse?format=jsonv2&lat=$lat&lon=$lng');
    final response = await http.get(url, headers: _headers);
    if (response.statusCode != 200) {
      throw GeocodingException(
        'Reverse geocode failed: ${response.statusCode}',
      );
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> forwardGeocode(String address) async {
    final encoded = Uri.encodeComponent(address);
    final url = Uri.parse('$_baseUrl/search?format=jsonv2&q=$encoded&limit=1');
    final response = await http.get(url, headers: _headers);
    if (response.statusCode != 200) {
      throw GeocodingException(
        'Forward geocode failed: ${response.statusCode}',
      );
    }
    return (jsonDecode(response.body) as List<dynamic>)
        .cast<Map<String, dynamic>>();
  }
}

class LocationService {
  LocationService({LocationRepository? repository})
    : _repo = repository ?? LocationRepository(),
      _nominatim = _NominatimClient();

  final LocationRepository _repo;
  final _NominatimClient _nominatim;

  Future<Position> _getDevicePosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationServiceDisabledException(
        'Location services are disabled.',
      );
    }

    var permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw const LocationPermissionException(
          'Location permission was denied.',
        );
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw const LocationPermissionException(
        'Location permission is permanently denied.',
      );
    }

    return Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  Future<AddressComponents> _buildAddressFrom(double lat, double lng) async {
    try {
      final json = await _nominatim.reverseGeocode(lat, lng);
      final addr = (json['address'] as Map<String, dynamic>?) ?? {};

      final street = [
        addr['house_number'] as String?,
        addr['road'] as String?,
      ].where((p) => p != null && p.isNotEmpty).join(' ');

      final city =
          (addr['city'] as String?) ??
          (addr['town'] as String?) ??
          (addr['village'] as String?) ??
          '';

      return AddressComponents(
        street: street,
        city: city,
        state: (addr['state'] as String?) ?? '',
        country: (addr['country'] as String?) ?? '',
        postalCode: (addr['postcode'] as String?) ?? '',
        formattedAddress: (json['display_name'] as String?) ?? '$lat, $lng',
      );
    } on GeocodingException {
      rethrow;
    } catch (e) {
      throw GeocodingException(e.toString());
    }
  }

  Future<({double lat, double lng})> _coordsFromAddress(
    String rawAddress,
  ) async {
    final results = await _nominatim.forwardGeocode(rawAddress);
    if (results.isEmpty) throw const GeocodingException('Address not found.');
    final first = results.first;
    return (
      lat: double.parse(first['lat'] as String),
      lng: double.parse(first['lon'] as String),
    );
  }

  Future<LocationModel> saveCurrentLocation({
    required String userId,
    required String role,
    bool isVisible = true,
  }) async {
    final position = await _getDevicePosition();
    final address = await _buildAddressFrom(
      position.latitude,
      position.longitude,
    );
    final now = DateTime.now();

    final existing = await _repo.getCurrentLocation(userId, role);

    final location = LocationModel(
      id: existing?.id,
      userId: userId,
      role: role,
      type: LocationType.currentLocation,
      coordinates: LatLng(
        latitude: position.latitude,
        longitude: position.longitude,
      ),
      address: address,
      isDefault: false,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
      accuracy: position.accuracy,
      isVisible: isVisible,
    );

    await _repo.upsertCurrentLocation(location);
    return location;
  }

  Future<LocationModel> saveCustomLocation({
    required String userId,
    required String role,
    required String rawAddress,
    String? label,
    bool isDefault = false,
    bool isVisible = true,
  }) async {
    final coords = await _coordsFromAddress(rawAddress);
    final address = await _buildAddressFrom(coords.lat, coords.lng);
    final now = DateTime.now();

    final location = LocationModel(
      userId: userId,
      role: role,
      type: LocationType.customAddress,
      coordinates: LatLng(latitude: coords.lat, longitude: coords.lng),
      address: address,
      label: label,
      isDefault: isDefault,
      createdAt: now,
      updatedAt: now,
      isVisible: isVisible,
    );

    final docId = await _repo.addCustomLocation(location);
    return location.copyWith(id: docId);
  }

  Future<void> deleteCustomLocation(String docId) =>
      _repo.deleteCustomLocation(docId);

  Future<void> setDefaultLocation({
    required String userId,
    required String role,
    required String locationId,
  }) => _repo.setDefaultLocation(userId, role, locationId);

  Stream<LocationModel?> watchCurrentLocation(String userId, String role) =>
      _repo.watchCurrentLocation(userId, role);

  Stream<List<LocationModel>> watchAllLocations(String userId, String role) =>
      _repo.watchAllLocations(userId, role);

  Future<LocationModel?> getDefaultLocation(String userId, String role) =>
      _repo.getDefaultLocation(userId, role);

  Future<LocationModel?> getCurrentLocation(String userId, String role) =>
      _repo.getCurrentLocation(userId, role);

  Future<List<LocationModel>> getAllLocationsForUser(String userId) =>
      _repo.getAllLocationsForUser(userId);

  Future<double?> distanceBetween({
    required String userIdA,
    required String roleA,
    required String userIdB,
    required String roleB,
  }) async {
    final locationA = await _repo.getCurrentLocation(userIdA, roleA);
    final locationB = await _repo.getDefaultLocation(userIdB, roleB);
    if (locationA == null || locationB == null) return null;
    return _haversineDistanceKm(locationA.coordinates, locationB.coordinates);
  }

  double _haversineDistanceKm(LatLng a, LatLng b) {
    const earthRadiusKm = 6371.0;
    final deltaLat = _toRadians(b.latitude - a.latitude);
    final deltaLng = _toRadians(b.longitude - a.longitude);
    final h =
        math.sin(deltaLat / 2) * math.sin(deltaLat / 2) +
        math.cos(_toRadians(a.latitude)) *
            math.cos(_toRadians(b.latitude)) *
            math.sin(deltaLng / 2) *
            math.sin(deltaLng / 2);
    return 2 * earthRadiusKm * math.asin(math.sqrt(h));
  }

  double _toRadians(double degrees) => degrees * math.pi / 180;
}
