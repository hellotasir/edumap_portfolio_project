import 'package:cloud_firestore/cloud_firestore.dart';

class LatLng {
  const LatLng({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;

  factory LatLng.fromMap(Map<String, dynamic> map) => LatLng(
    latitude: (map['latitude'] as num).toDouble(),
    longitude: (map['longitude'] as num).toDouble(),
  );

  Map<String, dynamic> toMap() => {
    'latitude': latitude,
    'longitude': longitude,
  };

  factory LatLng.fromGeoPoint(GeoPoint geoPoint) =>
      LatLng(latitude: geoPoint.latitude, longitude: geoPoint.longitude);

  GeoPoint toGeoPoint() => GeoPoint(latitude, longitude);

  @override
  String toString() => 'LatLng($latitude, $longitude)';
}

class AddressComponents {
  const AddressComponents({
    required this.street,
    required this.city,
    required this.state,
    required this.country,
    required this.postalCode,
    required this.formattedAddress,
  });

  final String street;
  final String city;
  final String state;
  final String country;
  final String postalCode;
  final String formattedAddress;

  factory AddressComponents.fromMap(Map<String, dynamic> map) =>
      AddressComponents(
        street: map['street'] as String? ?? '',
        city: map['city'] as String? ?? '',
        state: map['state'] as String? ?? '',
        country: map['country'] as String? ?? '',
        postalCode: map['postal_code'] as String? ?? '',
        formattedAddress: map['formatted_address'] as String? ?? '',
      );

  Map<String, dynamic> toMap() => {
    'street': street,
    'city': city,
    'state': state,
    'country': country,
    'postal_code': postalCode,
    'formatted_address': formattedAddress,
  };

  AddressComponents copyWith({
    String? street,
    String? city,
    String? state,
    String? country,
    String? postalCode,
    String? formattedAddress,
  }) => AddressComponents(
    street: street ?? this.street,
    city: city ?? this.city,
    state: state ?? this.state,
    country: country ?? this.country,
    postalCode: postalCode ?? this.postalCode,
    formattedAddress: formattedAddress ?? this.formattedAddress,
  );
}

enum AddressCategory { instructor, student }

extension AddressCategoryX on AddressCategory {
  String get value => switch (this) {
    AddressCategory.instructor => 'instructor',
    AddressCategory.student => 'student',
  };

  String get label => switch (this) {
    AddressCategory.instructor => 'Tutor',
    AddressCategory.student => 'Student',
  };

  static AddressCategory fromString(String v) => switch (v) {
    'instructor' => AddressCategory.instructor,
    'student' => AddressCategory.student,
    _ => AddressCategory.student,
  };
}

enum AddressType { currentLocation, saved }

extension AddressTypeX on AddressType {
  String get value => switch (this) {
    AddressType.currentLocation => 'current_location',
    AddressType.saved => 'saved',
  };

  static AddressType fromString(String v) => switch (v) {
    'current_location' => AddressType.currentLocation,
    'saved' => AddressType.saved,
    _ => AddressType.saved,
  };
}

class UserAddressEntry {
  const UserAddressEntry({
    required this.entryId,
    required this.title,
    required this.category,
    required this.type,
    required this.coordinates,
    required this.address,
    required this.isVisible,
    required this.createdAt,
    required this.updatedAt,
    this.accuracy,
  });

  final String entryId;
  final String title;
  final AddressCategory category;
  final AddressType type;
  final LatLng coordinates;
  final AddressComponents address;
  final bool isVisible;
  final DateTime createdAt;
  final DateTime updatedAt;
  final double? accuracy;

  factory UserAddressEntry.fromMap(String id, Map<String, dynamic> map) {
    final coordRaw = map['coordinates'];
    final LatLng coords;
    if (coordRaw is GeoPoint) {
      coords = LatLng.fromGeoPoint(coordRaw);
    } else if (coordRaw is Map<String, dynamic>) {
      coords = LatLng.fromMap(coordRaw);
    } else {
      coords = const LatLng(latitude: 0, longitude: 0);
    }

    return UserAddressEntry(
      entryId: id,
      title: map['title'] as String? ?? '',
      category: AddressCategoryX.fromString(map['category'] as String? ?? ''),
      type: AddressTypeX.fromString(map['type'] as String? ?? ''),
      coordinates: coords,
      address: AddressComponents.fromMap(
        (map['address'] as Map<String, dynamic>?) ?? {},
      ),
      isVisible: map['is_visible'] as bool? ?? false,
      createdAt: (map['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updated_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      accuracy: (map['accuracy'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toMap() => {
    'title': title,
    'category': category.value,
    'type': type.value,
    'coordinates': coordinates.toGeoPoint(),
    'address': address.toMap(),
    'is_visible': isVisible,
    'created_at': Timestamp.fromDate(createdAt),
    'updated_at': Timestamp.fromDate(updatedAt),
    if (accuracy != null) 'accuracy': accuracy,
  };

  UserAddressEntry copyWith({
    String? entryId,
    String? title,
    AddressCategory? category,
    AddressType? type,
    LatLng? coordinates,
    AddressComponents? address,
    bool? isVisible,
    DateTime? createdAt,
    DateTime? updatedAt,
    double? accuracy,
  }) => UserAddressEntry(
    entryId: entryId ?? this.entryId,
    title: title ?? this.title,
    category: category ?? this.category,
    type: type ?? this.type,
    coordinates: coordinates ?? this.coordinates,
    address: address ?? this.address,
    isVisible: isVisible ?? this.isVisible,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    accuracy: accuracy ?? this.accuracy,
  );
}

class UserLocationDoc {
  const UserLocationDoc({
    required this.userId,
    required this.entries,
    required this.updatedAt,
  });

  final String userId;
  final List<UserAddressEntry> entries;
  final DateTime updatedAt;

  factory UserLocationDoc.empty(String userId) => UserLocationDoc(
    userId: userId,
    entries: const [],
    updatedAt: DateTime.now(),
  );

  factory UserLocationDoc.fromSnapshot(DocumentSnapshot doc) {
    final map = doc.data() as Map<String, dynamic>? ?? {};
    final rawEntries = map['entries'] as Map<String, dynamic>? ?? {};
    final entries = rawEntries.entries
        .map((e) => UserAddressEntry.fromMap(e.key, e.value as Map<String, dynamic>))
        .toList()
      ..sort((a, b) {
        if (a.type == AddressType.currentLocation) return -1;
        if (b.type == AddressType.currentLocation) return 1;
        return b.updatedAt.compareTo(a.updatedAt);
      });

    return UserLocationDoc(
      userId: doc.id,
      entries: entries,
      updatedAt: (map['updated_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestoreEntriesMap() {
    final map = <String, dynamic>{};
    for (final e in entries) {
      map[e.entryId] = e.toMap();
    }
    return map;
  }

  List<UserAddressEntry> get visibleEntries =>
      entries.where((e) => e.isVisible).toList();

  List<UserAddressEntry> visibleForCategory(AddressCategory cat) =>
      entries.where((e) => e.isVisible && e.category == cat).toList();

  UserAddressEntry? get currentLocation => entries.firstWhereOrNull(
    (e) => e.type == AddressType.currentLocation,
  );
}

extension _FirstOrNull<T> on List<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    for (final e in this) {
      if (test(e)) return e;
    }
    return null;
  }
}