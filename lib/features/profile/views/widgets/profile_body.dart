import 'package:flutter/material.dart';
import 'package:edumap_portfolio_project/features/profile/models/profile_model.dart';
import 'package:edumap_portfolio_project/features/profile/views/widgets/action_row.dart';
import 'package:edumap_portfolio_project/features/profile/views/widgets/avatar_row.dart';
import 'package:edumap_portfolio_project/features/profile/views/widgets/bio_section.dart';
import 'package:edumap_portfolio_project/features/profile/views/widgets/details_section.dart';
import 'package:edumap_portfolio_project/features/profile/views/widgets/profile_appbar.dart';

class ProfileBody extends StatelessWidget {
  const ProfileBody({
    super.key,
    required this.profile,
    required this.isOwnProfile,
    required this.uploadingAvatar,
    required this.uploadingCover,
    required this.onChangeAvatar,
    required this.onChangeCover,
    required this.onOpenSettings,
    required this.initials,
    required this.capitalize,
    required this.onBack,
  });

  final ProfileModel profile;
  final bool isOwnProfile;
  final bool uploadingAvatar;
  final bool uploadingCover;
  final VoidCallback onChangeAvatar;
  final VoidCallback onChangeCover;
  final VoidCallback onOpenSettings;
  final String Function(String) initials;
  final String Function(String) capitalize;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        ProfileAppBar(
          profile: profile,
          isOwnProfile: isOwnProfile,
          uploadingCover: uploadingCover,
          onChangeCover: onChangeCover,
          onOpenSettings: onOpenSettings,
          onBack: onBack,
        ),
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AvatarRow(
                profile: profile,
                isOwnProfile: isOwnProfile,
                uploadingAvatar: uploadingAvatar,
                onChangeAvatar: onChangeAvatar,
                initials: initials,
              ),
              BioSection(profile: profile, capitalize: capitalize),
              ActionRow(isOwnProfile: isOwnProfile, onEdit: onOpenSettings),
              const SizedBox(height: 22),
              Divider(
                height: 1,
                color: Theme.of(
                  context,
                ).colorScheme.outlineVariant.withValues(alpha: 0.4),
              ),
              const SizedBox(height: 8),
              DetailsSection(
                profile: profile,
                capitalize: capitalize,
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ],
    );
  }
}
