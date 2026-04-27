import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_education_app/core/consts/api_keys.dart';
import 'package:flutter_education_app/features/location/models/location_model.dart';
import 'package:flutter_education_app/features/location/repositories/location_repository.dart';
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
  static String get _baseUrl => openStreetMapApiUrl;
  static const Map<String, String> _headers = {
    'User-Agent': 'FlutterEducationApp/1.0 (demo@email.com)',
    'Accept-Language': 'en',
  };

  Future<Map<String, dynamic>> reverseGeocode(double lat, double lng) async {
    final url = Uri.parse('$_baseUrl/reverse?format=jsonv2&lat=$lat&lon=$lng');
    final response = await http.get(url, headers: _headers);
    if (response.statusCode != 200) {
      throw GeocodingException('Reverse geocode failed: ${response.statusCode}');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> forwardGeocode(String address) async {
    final encoded = Uri.encodeComponent(address);
    final url = Uri.parse('$_baseUrl/search?format=jsonv2&q=$encoded&limit=1');
    final response = await http.get(url, headers: _headers);
    if (response.statusCode != 200) {
      throw GeocodingException('Forward geocode failed: ${response.statusCode}');
    }
    return (jsonDecode(response.body) as List<dynamic>).cast<Map<String, dynamic>>();
  }
}

class UserLocationService {
  UserLocationService({UserLocationRepository? repository})
    : _repo = repository ?? UserLocationRepository(),
      _nominatim = _NominatimClient();

  final UserLocationRepository _repo;
  final _NominatimClient _nominatim;

  Future<Position> _getDevicePosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationServiceDisabledException('Location services are disabled.');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw const LocationPermissionException('Location permission was denied.');
      }
    }
    if (permission == LocationPermission.deniedForever) {
      throw const LocationPermissionException('Location permission is permanently denied.');
    }
    return Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
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
        state: addr['state'] as String? ?? '',
        country: addr['country'] as String? ?? '',
        postalCode: addr['postcode'] as String? ?? '',
        formattedAddress: json['display_name'] as String? ?? '$lat, $lng',
      );
    } on GeocodingException {
      rethrow;
    } catch (e) {
      throw GeocodingException(e.toString());
    }
  }

  Future<({double lat, double lng})> _coordsFromAddress(String rawAddress) async {
    final results = await _nominatim.forwardGeocode(rawAddress);
    if (results.isEmpty) throw const GeocodingException('Address not found.');
    final first = results.first;
    return (
      lat: double.parse(first['lat'] as String),
      lng: double.parse(first['lon'] as String),
    );
  }

  Future<UserAddressEntry> shareCurrentLocation({
    required String userId,
    required String title,
    required AddressCategory category,
    bool isVisible = true,
  }) async {
    final position = await _getDevicePosition();
    final address = await _buildAddressFrom(position.latitude, position.longitude);
    final now = DateTime.now();

    final entryId = await _repo.upsertCurrentLocation(
      userId: userId,
      title: title,
      category: category,
      coordinates: LatLng(latitude: position.latitude, longitude: position.longitude),
      address: address,
      isVisible: isVisible,
      accuracy: position.accuracy,
    );

    return UserAddressEntry(
      entryId: entryId,
      title: title,
      category: category,
      type: AddressType.currentLocation,
      coordinates: LatLng(latitude: position.latitude, longitude: position.longitude),
      address: address,
      isVisible: isVisible,
      createdAt: now,
      updatedAt: now,
      accuracy: position.accuracy,
    );
  }

  Future<UserAddressEntry> addSavedAddress({
    required String userId,
    required String title,
    required AddressCategory category,
    required String rawAddress,
    bool isVisible = true,
  }) async {
    final coords = await _coordsFromAddress(rawAddress);
    final address = await _buildAddressFrom(coords.lat, coords.lng);
    final now = DateTime.now();

    final entryId = await _repo.addSavedAddress(
      userId: userId,
      title: title,
      category: category,
      coordinates: LatLng(latitude: coords.lat, longitude: coords.lng),
      address: address,
      isVisible: isVisible,
    );

    return UserAddressEntry(
      entryId: entryId,
      title: title,
      category: category,
      type: AddressType.saved,
      coordinates: LatLng(latitude: coords.lat, longitude: coords.lng),
      address: address,
      isVisible: isVisible,
      createdAt: now,
      updatedAt: now,
    );
  }

  Future<void> toggleVisibility({
    required String userId,
    required String entryId,
    required bool isVisible,
  }) => _repo.updateEntryVisibility(
    userId: userId,
    entryId: entryId,
    isVisible: isVisible,
  );

  Future<void> updateTitle({
    required String userId,
    required String entryId,
    required String title,
  }) => _repo.updateEntryTitle(userId: userId, entryId: entryId, title: title);

  Future<void> deleteEntry({
    required String userId,
    required String entryId,
  }) => _repo.deleteEntry(userId: userId, entryId: entryId);

  Stream<UserLocationDoc> watchMyLocations(String userId) =>
      _repo.watchDoc(userId);

  Future<UserLocationDoc?> getUserLocations(String userId) =>
      _repo.getDocForUser(userId);

  double haversineKm(LatLng a, LatLng b) {
    const r = 6371.0;
    final dLat = _rad(b.latitude - a.latitude);
    final dLon = _rad(b.longitude - a.longitude);
    final h =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_rad(a.latitude)) *
            math.cos(_rad(b.latitude)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return 2 * r * math.asin(math.sqrt(h.clamp(0.0, 1.0)));
  }

  double _rad(double deg) => deg * math.pi / 180;
}