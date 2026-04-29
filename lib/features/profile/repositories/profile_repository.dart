import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:edumap_portfolio_project/features/profile/models/profile_model.dart';
import 'package:edumap_portfolio_project/features/app/repositories/database_repository.dart';

class ProfileRepository implements DatabaseRepository<ProfileModel> {
  @override
  List<String> get collectionPath => ['profiles'];

  @override
  ProfileModel fromSnapshot(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data()!;
    return ProfileModel(
      id: snapshot.id,
      userId: data['user_id'] ?? '',
      username: data['username'] ?? '',
      email: data['email'] ?? '',
      phone: data['phone'] ?? '',
      passwordHash: data['password_hash'] ?? '',
      currentMode: data['current_mode'] ?? 'student',
      availableModes:
          (data['available_modes'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      isVerified: data['is_verified'] ?? false,
      status: data['status'] ?? 'active',
      createdAt:
          (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt:
          (data['updated_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastLogin:
          (data['last_login'] as Timestamp?)?.toDate() ?? DateTime.now(),
      profile: _parseProfile(data['profile']),
      studentProfile: _parseStudent(data['student_profile']),
      instructorProfile: _parseInstructor(data['instructor_profile']),
      system: _parseSystem(data['system']),
    );
  }

  @override
  Map<String, dynamic> toMap(ProfileModel model) => {
        'user_id': model.userId,
        'username': model.username,
        'email': model.email,
        'phone': model.phone,
        'password_hash': model.passwordHash,
        'current_mode': model.currentMode,
        'available_modes': model.availableModes,
        'is_verified': model.isVerified,
        'status': model.status,
        'created_at': Timestamp.fromDate(model.createdAt),
        'updated_at': Timestamp.fromDate(model.updatedAt),
        'last_login': Timestamp.fromDate(model.lastLogin),
        'profile': _profileToMap(model.profile),
        'student_profile': _studentToMap(model.studentProfile),
        'instructor_profile': _instructorToMap(model.instructorProfile),
        'system': _systemToMap(model.system),
      };

  ProfileInfo _parseProfile(Map<String, dynamic>? data) {
    data ??= {};
    return ProfileInfo(
      fullName: data['full_name'] ?? '',
      profilePhoto: data['profile_photo'] ?? '',
      coverPhoto: data['cover_photo'] ?? '',
      bio: data['bio'] ?? '',
      dateOfBirth: null,
      gender: data['gender'] ?? '',
      location: Location(
        country: data['location']?['country'] ?? '',
        city: data['location']?['city'] ?? '',
        timezone: data['location']?['timezone'] ?? '',
      ),
      languages:
          (data['languages'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      socialLinks: SocialLinks(
        linkedin: data['social_links']?['linkedin'] ?? '',
        github: data['social_links']?['github'] ?? '',
        website: data['social_links']?['website'] ?? '',
      ),
    );
  }

  StudentProfile _parseStudent(Map<String, dynamic>? data) {
    data ??= {};
    return StudentProfile(
      isActive: data['is_active'] ?? false,
      interests:
          (data['interests'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      currentLevel: data['current_level'] ?? 'beginner',
    );
  }

  InstructorProfile _parseInstructor(Map<String, dynamic>? data) {
    data ??= {};
    return InstructorProfile(
      isActive: data['is_active'] ?? false,
      headline: data['headline'] ?? '',
      expertise:
          (data['expertise'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      yearsOfExperience: (data['years_of_experience'] ?? 0) as int,
    );
  }

  SystemInfo _parseSystem(Map<String, dynamic>? data) {
    data ??= {};
    return SystemInfo(
      isBanned: data['flags']?['is_banned'] ?? false,
      isFeaturedInstructor:
          data['flags']?['is_featured_instructor'] ?? false,
    );
  }

  Map<String, dynamic> _profileToMap(ProfileInfo p) => {
        'full_name': p.fullName,
        'profile_photo': p.profilePhoto,
        'cover_photo': p.coverPhoto,
        'bio': p.bio,
        'gender': p.gender,
        'location': {
          'country': p.location.country,
          'city': p.location.city,
          'timezone': p.location.timezone,
        },
        'languages': p.languages,
        'social_links': {
          'linkedin': p.socialLinks.linkedin,
          'github': p.socialLinks.github,
          'website': p.socialLinks.website,
        },
      };

  Map<String, dynamic> _studentToMap(StudentProfile s) => {
        'is_active': s.isActive,
        'interests': s.interests,
        'current_level': s.currentLevel,
      };

  Map<String, dynamic> _instructorToMap(InstructorProfile i) => {
        'is_active': i.isActive,
        'headline': i.headline,
        'expertise': i.expertise,
        'years_of_experience': i.yearsOfExperience,
      };

  Map<String, dynamic> _systemToMap(SystemInfo s) => {
        'flags': {
          'is_banned': s.isBanned,
          'is_featured_instructor': s.isFeaturedInstructor,
        },
      };
}