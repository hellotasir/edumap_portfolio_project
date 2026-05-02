import 'package:cloud_firestore/cloud_firestore.dart';

enum ProfileMode {
  student,
  instructor;

  String get label => '${name[0].toUpperCase()}${name.substring(1)}';

  String toJson() => name;

  static ProfileMode fromJson(String? value) => values.firstWhere(
        (e) => e.name == value,
        orElse: () => ProfileMode.student,
      );
}

enum ProfileStatus {
  active,
  inactive,
  suspended;

  String toJson() => name;

  static ProfileStatus fromJson(String? value) => values.firstWhere(
        (e) => e.name == value,
        orElse: () => ProfileStatus.active,
      );
}

enum Gender {
  male,
  female,
  preferNotToSay;

  static const Map<Gender, String> _labels = {
    Gender.male: 'Male',
    Gender.female: 'Female',
    Gender.preferNotToSay: 'Prefer not to say',
  };

  String get label => _labels[this]!;

  String toJson() => label;

  static Gender fromJson(String? value) => values.firstWhere(
        (e) => e.label == value,
        orElse: () => Gender.preferNotToSay,
      );
}

enum StudentLevel {
  beginner,
  intermediate,
  advanced;

  String get label => '${name[0].toUpperCase()}${name.substring(1)}';

  String toJson() => name;

  static StudentLevel fromJson(String? value) => values.firstWhere(
        (e) => e.name == value,
        orElse: () => StudentLevel.beginner,
      );
}

class ProfileModel {
  const ProfileModel({
    this.id,
    required this.userId,
    required this.username,
    required this.email,
    required this.phone,
    required this.passwordHash,
    required this.currentMode,
    required this.availableModes,
    required this.isVerified,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.lastLogin,
    required this.profile,
    required this.studentProfile,
    required this.instructorProfile,
    required this.system,
  });

  final String? id;
  final String userId;
  final String username;
  final String email;
  final String phone;
  final String passwordHash;
  final ProfileMode currentMode;
  final List<ProfileMode> availableModes;
  final bool isVerified;
  final ProfileStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime lastLogin;
  final ProfileInfo profile;
  final StudentProfile studentProfile;
  final InstructorProfile instructorProfile;
  final SystemInfo system;

  ProfileModel copyWith({
    String? id,
    String? userId,
    String? username,
    String? email,
    String? phone,
    String? passwordHash,
    ProfileMode? currentMode,
    List<ProfileMode>? availableModes,
    bool? isVerified,
    ProfileStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastLogin,
    ProfileInfo? profile,
    StudentProfile? studentProfile,
    InstructorProfile? instructorProfile,
    SystemInfo? system,
  }) =>
      ProfileModel(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        username: username ?? this.username,
        email: email ?? this.email,
        phone: phone ?? this.phone,
        passwordHash: passwordHash ?? this.passwordHash,
        currentMode: currentMode ?? this.currentMode,
        availableModes: availableModes ?? this.availableModes,
        isVerified: isVerified ?? this.isVerified,
        status: status ?? this.status,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        lastLogin: lastLogin ?? this.lastLogin,
        profile: profile ?? this.profile,
        studentProfile: studentProfile ?? this.studentProfile,
        instructorProfile: instructorProfile ?? this.instructorProfile,
        system: system ?? this.system,
      );
}

class ProfileInfo {
  const ProfileInfo({
    required this.fullName,
    required this.profilePhoto,
    required this.coverPhoto,
    required this.bio,
    required this.dateOfBirth,
    required this.gender,
    required this.location,
    required this.languages,
    required this.socialLinks,
  });

  final String fullName;
  final Uri? profilePhoto;
  final Uri? coverPhoto;
  final String bio;
  final DateTime? dateOfBirth;
  final Gender gender;
  final Location location;
  final List<String> languages;
  final SocialLinks socialLinks;

  ProfileInfo copyWith({
    String? fullName,
    Uri? profilePhoto,
    Uri? coverPhoto,
    String? bio,
    DateTime? dateOfBirth,
    Gender? gender,
    Location? location,
    List<String>? languages,
    SocialLinks? socialLinks,
  }) =>
      ProfileInfo(
        fullName: fullName ?? this.fullName,
        profilePhoto: profilePhoto ?? this.profilePhoto,
        coverPhoto: coverPhoto ?? this.coverPhoto,
        bio: bio ?? this.bio,
        dateOfBirth: dateOfBirth ?? this.dateOfBirth,
        gender: gender ?? this.gender,
        location: location ?? this.location,
        languages: languages ?? this.languages,
        socialLinks: socialLinks ?? this.socialLinks,
      );
}

class Location {
  const Location({
    required this.country,
    required this.city,
    required this.timezone,
  });

  final String country;
  final String city;
  final String timezone;
}

class SocialLinks {
  const SocialLinks({
    this.linkedin,
    this.github,
    this.website,
  });

  final Uri? linkedin;
  final Uri? github;
  final Uri? website;
}

class StudentProfile {
  const StudentProfile({
    required this.isActive,
    required this.interests,
    required this.currentLevel,
  });

  final bool isActive;
  final List<String> interests;
  final StudentLevel currentLevel;
}

class InstructorProfile {
  const InstructorProfile({
    required this.isActive,
    required this.headline,
    required this.expertise,
    required this.yearsOfExperience,
  });

  final bool isActive;
  final String headline;
  final List<String> expertise;
  final int yearsOfExperience;
}

class SystemInfo {
  const SystemInfo({
    required this.isBanned,
    required this.isFeaturedInstructor,
  });

  final bool isBanned;
  final bool isFeaturedInstructor;
}

class MediaModel {
  const MediaModel({
    required this.url,
    required this.path,
    required this.bucket,
    required this.mimeType,
    required this.size,
    required this.uploadedAt,
  });

  final Uri url;
  final String path;
  final String bucket;
  final String mimeType;
  final int size;
  final DateTime uploadedAt;

  factory MediaModel.fromMap(Map<String, dynamic> map) => MediaModel(
        url: Uri.parse(map['url'] as String? ?? ''),
        path: map['path'] as String? ?? '',
        bucket: map['bucket'] as String? ?? '',
        mimeType: map['mime_type'] as String? ?? '',
        size: map['size'] as int? ?? 0,
        uploadedAt:
            (map['uploaded_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      );

  Map<String, dynamic> toMap() => {
        'url': url.toString(),
        'path': path,
        'bucket': bucket,
        'mime_type': mimeType,
        'size': size,
        'uploaded_at': Timestamp.fromDate(uploadedAt),
      };
}