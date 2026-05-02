import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:edumap_portfolio_project/features/profile/models/profile_model.dart';
import 'package:edumap_portfolio_project/features/app/repositories/database_repository.dart';

class ProfileRepository implements DatabaseRepository<ProfileModel> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  List<String> get collectionPath => ['profiles'];

  @override
  ProfileModel fromSnapshot(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data()!;
    return ProfileModel(
      id: snapshot.id,
      userId: data['user_id'] as String? ?? '',
      username: data['username'] as String? ?? '',
      email: data['email'] as String? ?? '',
      phone: data['phone'] as String? ?? '',
      passwordHash: data['password_hash'] as String? ?? '',
      currentMode: ProfileMode.fromJson(data['current_mode'] as String?),
      availableModes: (data['available_modes'] as List<dynamic>?)
              ?.map((e) => ProfileMode.fromJson(e.toString()))
              .toList() ??
          [],
      isVerified: data['is_verified'] as bool? ?? false,
      status: ProfileStatus.fromJson(data['status'] as String?),
      createdAt:
          (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt:
          (data['updated_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastLogin:
          (data['last_login'] as Timestamp?)?.toDate() ?? DateTime.now(),
      profile: _parseProfile(data['profile'] as Map<String, dynamic>?),
      studentProfile:
          _parseStudent(data['student_profile'] as Map<String, dynamic>?),
      instructorProfile:
          _parseInstructor(data['instructor_profile'] as Map<String, dynamic>?),
      system: _parseSystem(data['system'] as Map<String, dynamic>?),
    );
  }

  @override
  Map<String, dynamic> toMap(ProfileModel model) => {
        'user_id': model.userId,
        'username': model.username,
        'email': model.email,
        'phone': model.phone,
        'password_hash': model.passwordHash,
        'current_mode': model.currentMode.toJson(),
        'available_modes':
            model.availableModes.map((e) => e.toJson()).toList(),
        'is_verified': model.isVerified,
        'status': model.status.toJson(),
        'created_at': Timestamp.fromDate(model.createdAt),
        'updated_at': Timestamp.fromDate(model.updatedAt),
        'last_login': Timestamp.fromDate(model.lastLogin),
        'profile': _profileToMap(model.profile),
        'student_profile': _studentToMap(model.studentProfile),
        'instructor_profile': _instructorToMap(model.instructorProfile),
        'system': _systemToMap(model.system),
      };

  Future<void> update(String documentId, ProfileModel model) async {
    final results = await Future.wait([
      _firestore
          .collection('friend_requests')
          .where('from_user_id', isEqualTo: model.userId)
          .limit(1)
          .get(),
      _firestore
          .collection('friend_requests')
          .where('to_user_id', isEqualTo: model.userId)
          .limit(1)
          .get(),
    ]);

    final hasAnyFriendRequest =
        results[0].docs.isNotEmpty || results[1].docs.isNotEmpty;

    final Map<String, dynamic> updateData;

    if (hasAnyFriendRequest) {
      updateData = {
        'user_id': model.userId,
        'email': model.email,
        'phone': model.phone,
        'password_hash': model.passwordHash,
        'current_mode': model.currentMode.toJson(),
        'available_modes':
            model.availableModes.map((e) => e.toJson()).toList(),
        'is_verified': model.isVerified,
        'status': model.status.toJson(),
        'created_at': Timestamp.fromDate(model.createdAt),
        'updated_at': Timestamp.fromDate(model.updatedAt),
        'last_login': Timestamp.fromDate(model.lastLogin),
        'profile': _profileToMap(model.profile),
        'student_profile': _studentToMap(model.studentProfile),
        'instructor_profile': _instructorToMap(model.instructorProfile),
        'system': _systemToMap(model.system),
      };
    } else {
      updateData = toMap(model);
    }

    await _firestore.collection('profiles').doc(documentId).update(updateData);
  }

  ProfileInfo _parseProfile(Map<String, dynamic>? data) {
    data ??= {};
    final locationData = data['location'] as Map<String, dynamic>? ?? {};
    final socialData = data['social_links'] as Map<String, dynamic>? ?? {};
    final profilePhotoStr = data['profile_photo'] as String? ?? '';
    final coverPhotoStr = data['cover_photo'] as String? ?? '';
    final linkedinStr = socialData['linkedin'] as String? ?? '';
    final githubStr = socialData['github'] as String? ?? '';
    final websiteStr = socialData['website'] as String? ?? '';

    return ProfileInfo(
      fullName: data['full_name'] as String? ?? '',
      profilePhoto:
          profilePhotoStr.isNotEmpty ? Uri.tryParse(profilePhotoStr) : null,
      coverPhoto:
          coverPhotoStr.isNotEmpty ? Uri.tryParse(coverPhotoStr) : null,
      bio: data['bio'] as String? ?? '',
      dateOfBirth: null,
      gender: Gender.fromJson(data['gender'] as String?),
      location: Location(
        country: locationData['country'] as String? ?? '',
        city: locationData['city'] as String? ?? '',
        timezone: locationData['timezone'] as String? ?? '',
      ),
      languages: (data['languages'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      socialLinks: SocialLinks(
        linkedin: linkedinStr.isNotEmpty ? Uri.tryParse(linkedinStr) : null,
        github: githubStr.isNotEmpty ? Uri.tryParse(githubStr) : null,
        website: websiteStr.isNotEmpty ? Uri.tryParse(websiteStr) : null,
      ),
    );
  }

  StudentProfile _parseStudent(Map<String, dynamic>? data) {
    data ??= {};
    return StudentProfile(
      isActive: data['is_active'] as bool? ?? false,
      interests: (data['interests'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      currentLevel: StudentLevel.fromJson(data['current_level'] as String?),
    );
  }

  InstructorProfile _parseInstructor(Map<String, dynamic>? data) {
    data ??= {};
    return InstructorProfile(
      isActive: data['is_active'] as bool? ?? false,
      headline: data['headline'] as String? ?? '',
      expertise: (data['expertise'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      yearsOfExperience: data['years_of_experience'] as int? ?? 0,
    );
  }

  SystemInfo _parseSystem(Map<String, dynamic>? data) {
    data ??= {};
    final flags = data['flags'] as Map<String, dynamic>? ?? {};
    return SystemInfo(
      isBanned: flags['is_banned'] as bool? ?? false,
      isFeaturedInstructor: flags['is_featured_instructor'] as bool? ?? false,
    );
  }

  Map<String, dynamic> _profileToMap(ProfileInfo p) => {
        'full_name': p.fullName,
        'profile_photo': p.profilePhoto?.toString() ?? '',
        'cover_photo': p.coverPhoto?.toString() ?? '',
        'bio': p.bio,
        'gender': p.gender.toJson(),
        'location': {
          'country': p.location.country,
          'city': p.location.city,
          'timezone': p.location.timezone,
        },
        'languages': p.languages,
        'social_links': {
          'linkedin': p.socialLinks.linkedin?.toString() ?? '',
          'github': p.socialLinks.github?.toString() ?? '',
          'website': p.socialLinks.website?.toString() ?? '',
        },
      };

  Map<String, dynamic> _studentToMap(StudentProfile s) => {
        'is_active': s.isActive,
        'interests': s.interests,
        'current_level': s.currentLevel.toJson(),
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