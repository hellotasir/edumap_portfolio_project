import 'package:flutter/material.dart';
import 'package:edumap_portfolio_project/features/app/views/screens/settings_screen.dart';
import 'package:edumap_portfolio_project/features/profile/models/profile_model.dart';
import 'package:edumap_portfolio_project/features/profile/views/widgets/conver_photo.dart';
import 'package:edumap_portfolio_project/core/routers/app_navigator.dart';

class ProfileAppBar extends StatelessWidget {
  const ProfileAppBar({
    super.key,
    required this.profile,
    required this.isOwnProfile,
    required this.uploadingCover,
    required this.onChangeCover,
    required this.onOpenSettings,
    required this.onBack,
  });

  final ProfileModel profile;
  final bool isOwnProfile;
  final bool uploadingCover;
  final VoidCallback onChangeCover;
  final VoidCallback onOpenSettings;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final info = profile.profile;

    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      stretch: true,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      backgroundColor: cs.surface,
      automaticallyImplyLeading: false,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '@${profile.username}',
            style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          if (profile.isVerified) ...[
            const SizedBox(width: 4),
            Icon(Icons.verified_rounded, size: 15, color: cs.primary),
          ],
        ],
      ),
      leading: IconButton(
        onPressed: onBack,
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
      ),
      actions: [
        if (isOwnProfile)
          IconButton(
            onPressed: () {
              AppNavigator(
                screen: SettingsScreen(profile: profile),
              ).navigate(context);
            },
            icon: const Icon(Icons.settings_outlined, size: 22),
          ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [
          StretchMode.zoomBackground,
          StretchMode.blurBackground,
        ],
        background: CoverPhoto(
          info: info,
          isOwnProfile: isOwnProfile,
          uploading: uploadingCover,
          onTap: onChangeCover,
        ),
      ),
    );
  }
}
