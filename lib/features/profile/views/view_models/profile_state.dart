
import 'package:flutter_education_app/features/profile/models/profile_model.dart';

class ProfileState {
  final ProfileModel? profile;
  final bool loading;
  final String? errorMessage;
  final bool uploadingAvatar;
  final bool uploadingCover;

  const ProfileState({
    this.profile,
    this.loading = true,
    this.errorMessage,
    this.uploadingAvatar = false,
    this.uploadingCover = false,
  });

  ProfileState copyWith({
    ProfileModel? profile,
    bool? loading,
    String? errorMessage,
    bool? uploadingAvatar,
    bool? uploadingCover,
    bool clearError = false,
  }) {
    return ProfileState(
      profile: profile ?? this.profile,
      loading: loading ?? this.loading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      uploadingAvatar: uploadingAvatar ?? this.uploadingAvatar,
      uploadingCover: uploadingCover ?? this.uploadingCover,
    );
  }
}

