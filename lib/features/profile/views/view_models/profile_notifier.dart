import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_education_app/core/services/cloud/database_service.dart';
import 'package:flutter_education_app/features/app/repositories/storage_repository.dart';
import 'package:flutter_education_app/features/auth/repositories/auth_repository.dart';
import 'package:flutter_education_app/features/profile/models/profile_model.dart';
import 'package:flutter_education_app/features/profile/views/view_models/profile_provider.dart';
import 'package:flutter_education_app/features/profile/views/view_models/profile_state.dart';
import 'package:flutter_education_app/features/profile/views/widgets/image_source_sheet.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:image_picker/image_picker.dart';

class ProfileNotifier extends StateNotifier<ProfileState> {
  ProfileNotifier({required this.ref, required this.viewUserId})
    : super(const ProfileState()) {
    _init();
  }

  final Ref ref;
  final String? viewUserId;

  AuthRepository get _authRepo => ref.read(authRepositoryProvider);
  DatabaseService<ProfileModel> get _service =>
      ref.read(firestoreServiceProvider);
  StorageRepository get _storage => ref.read(storageServiceProvider);
  ImagePicker get _picker => ref.read(imagePickerProvider);

  String? get _currentUserId => _authRepo.currentUser?.id;
  String? get _targetUserId => viewUserId ?? _currentUserId;
  bool get isOwnProfile => viewUserId == null || viewUserId == _currentUserId;

  void _init() => loadProfile();

  Future<void> loadProfile() async {
    state = state.copyWith(loading: true, clearError: true);

    final uid = _targetUserId;
    if (uid == null) {
      state = state.copyWith(loading: false, errorMessage: 'Not logged in.');
      return;
    }

    try {
      final results = await _service.getAll(
        query: (col) => col.where('user_id', isEqualTo: uid).limit(1),
      );

      if (results.isNotEmpty) {
        state = state.copyWith(profile: results.first, loading: false);
      } else if (isOwnProfile) {
        await _createDefaultProfile(uid);
      } else {
        state = state.copyWith(
          loading: false,
          errorMessage: 'Profile not found.',
        );
      }
    } catch (e, st) {
      debugPrint('[ProfileNotifier] error: $e\n$st');
      state = state.copyWith(loading: false, errorMessage: e.toString());
    }
  }

  Future<void> _createDefaultProfile(String uid) async {
    final user = _authRepo.currentUser!;
    final meta = user.userMetadata ?? {};
    final String rawName = (meta['full_name'] as String? ?? '').trim();
    final String emailPrefix = (user.email ?? '')
        .split('@')
        .first
        .replaceAll('.', '_');
    final String username = rawName.isNotEmpty
        ? rawName.replaceAll(' ', '_').toLowerCase()
        : emailPrefix;
    final now = DateTime.now();

    final defaultProfile = ProfileModel(
      userId: uid,
      username: username,
      email: user.email ?? '',
      phone: user.phone ?? '',
      passwordHash: '',
      currentMode: 'student',
      availableModes: const ['student'],
      isVerified: false,
      status: 'active',
      createdAt: now,
      updatedAt: now,
      lastLogin: now,
      profile: ProfileInfo(
        fullName: rawName,
        profilePhoto: meta['avatar_url'] as String? ?? '',
        coverPhoto: '',
        bio: '',
        dateOfBirth: null,
        gender: '',
        location: const Location(country: '', city: '', timezone: ''),
        languages: const [],
        socialLinks: const SocialLinks(linkedin: '', github: '', website: ''),
      ),
      studentProfile: const StudentProfile(
        isActive: true,
        interests: [],
        currentLevel: 'beginner',
      ),
      instructorProfile: const InstructorProfile(
        isActive: false,
        headline: '',
        expertise: [],
        yearsOfExperience: 0,
      ),
      system: const SystemInfo(isBanned: false, isFeaturedInstructor: false),
    );

    final newDocId = await _service.add(defaultProfile);
    state = state.copyWith(
      profile: defaultProfile.copyWith(id: newDocId),
      loading: false,
    );
  }

  Future<File?> pickImage(BuildContext context) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const ImageSourceSheet(),
    );
    if (source == null) return null;
    final xfile = await _picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1024,
    );
    return xfile == null ? null : File(xfile.path);
  }

  Future<void> changeAvatar(BuildContext context) async {
    if (!isOwnProfile || state.uploadingAvatar) return;
    final file = await pickImage(context);
    if (file == null || state.profile?.id == null) return;

    state = state.copyWith(uploadingAvatar: true);
    try {
      final profile = state.profile!;
      final result = await _storage.uploadAvatar(
        userId: profile.userId,
        roleLabel: profile.currentMode,
        file: file,
      );

      if (result.isFailure) throw Exception(result.error);

      final rawUrl = result.data!;
      final oldUrl = profile.profile.profilePhoto;
      if (oldUrl.isNotEmpty) await NetworkImage(oldUrl).evict();
      final freshUrl = _cacheBust(rawUrl);
      await _service.update(profile.id!, {'profile.profile_photo': freshUrl});
      state = state.copyWith(
        profile: _rebuildProfileInfo(profile, profilePhoto: freshUrl),
        uploadingAvatar: false,
      );
    } catch (e) {
      state = state.copyWith(uploadingAvatar: false);
      rethrow;
    }
  }

  Future<void> changeCover(BuildContext context) async {
    if (!isOwnProfile || state.uploadingCover) return;
    final file = await pickImage(context);
    if (file == null || state.profile?.id == null) return;

    state = state.copyWith(uploadingCover: true);
    try {
      final profile = state.profile!;
      // Fixed: use named parameters to match StorageRepository signature
      final result = await _storage.uploadCoverPhoto(
        userId: profile.userId,
        file: file,
      );

      if (result.isFailure) throw Exception(result.error);

      final rawUrl = result.data!;
      final oldUrl = profile.profile.coverPhoto;
      if (oldUrl.isNotEmpty) await NetworkImage(oldUrl).evict();
      final freshUrl = _cacheBust(rawUrl);
      await _service.update(profile.id!, {'profile.cover_photo': freshUrl});
      state = state.copyWith(
        profile: _rebuildProfileInfo(profile, coverPhoto: freshUrl),
        uploadingCover: false,
      );
    } catch (e) {
      state = state.copyWith(uploadingCover: false);
      rethrow;
    }
  }

  static String _cacheBust(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return url;
    return uri
        .replace(
          queryParameters: {
            ...uri.queryParameters,
            '_cb': '${DateTime.now().millisecondsSinceEpoch}',
          },
        )
        .toString();
  }

  static ProfileModel _rebuildProfileInfo(
    ProfileModel p, {
    String? profilePhoto,
    String? coverPhoto,
  }) {
    final o = p.profile;
    return ProfileModel(
      id: p.id,
      userId: p.userId,
      username: p.username,
      email: p.email,
      phone: p.phone,
      passwordHash: p.passwordHash,
      currentMode: p.currentMode,
      availableModes: p.availableModes,
      isVerified: p.isVerified,
      status: p.status,
      createdAt: p.createdAt,
      updatedAt: p.updatedAt,
      lastLogin: p.lastLogin,
      profile: ProfileInfo(
        fullName: o.fullName,
        profilePhoto: profilePhoto ?? o.profilePhoto,
        coverPhoto: coverPhoto ?? o.coverPhoto,
        bio: o.bio,
        dateOfBirth: o.dateOfBirth,
        gender: o.gender,
        location: o.location,
        languages: o.languages,
        socialLinks: o.socialLinks,
      ),
      studentProfile: p.studentProfile,
      instructorProfile: p.instructorProfile,
      system: p.system,
    );
  }
}
