import 'package:cloud_firestore/cloud_firestore.dart';

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
  final String currentMode;
  final List<String> availableModes;
  final bool isVerified;
  final String status;
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
    String? currentMode,
    List<String>? availableModes,
    bool? isVerified,
    String? status,
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
  final String profilePhoto;
  final String coverPhoto;
  final String bio;
  final DateTime? dateOfBirth;
  final String gender;
  final Location location;
  final List<String> languages;
  final SocialLinks socialLinks;

  ProfileInfo copyWith({
    String? fullName,
    String? profilePhoto,
    String? coverPhoto,
    String? bio,
    DateTime? dateOfBirth,
    String? gender,
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
    required this.linkedin,
    required this.github,
    required this.website,
  });

  final String linkedin;
  final String github;
  final String website;
}

class StudentProfile {
  const StudentProfile({
    required this.isActive,
    required this.interests,
    required this.currentLevel,
  });

  final bool isActive;
  final List<String> interests;
  final String currentLevel;
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

  final String url;
  final String path;
  final String bucket;
  final String mimeType;
  final int size;
  final DateTime uploadedAt;

  factory MediaModel.fromMap(Map<String, dynamic> map) => MediaModel(
        url: map['url'] ?? '',
        path: map['path'] ?? '',
        bucket: map['bucket'] ?? '',
        mimeType: map['mime_type'] ?? '',
        size: (map['size'] ?? 0) as int,
        uploadedAt:
            (map['uploaded_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      );

  Map<String, dynamic> toMap() => {
        'url': url,
        'path': path,
        'bucket': bucket,
        'mime_type': mimeType,
        'size': size,
        'uploaded_at': Timestamp.fromDate(uploadedAt),
      };
}