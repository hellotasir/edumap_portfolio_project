import 'package:flutter/material.dart';
import 'package:edumap_portfolio_project/features/profile/models/profile_model.dart';
import 'package:edumap_portfolio_project/features/profile/views/widgets/state_card.dart';

class AvatarRow extends StatelessWidget {
  const AvatarRow({
    super.key,
    required this.profile,
    required this.isOwnProfile,
    required this.uploadingAvatar,
    required this.onChangeAvatar,
    required this.initials,
  });

  final ProfileModel profile;
  final bool isOwnProfile;
  final bool uploadingAvatar;
  final VoidCallback onChangeAvatar;
  final String Function(String) initials;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final info = profile.profile;
    final name = info.fullName.isNotEmpty ? info.fullName : profile.username;
    final isInstructor = profile.currentMode == 'instructor';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: isOwnProfile ? onChangeAvatar : null,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: cs.surface, width: 3),
                  ),
                  child: CircleAvatar(
                    radius: 44,
                    backgroundColor: cs.primaryContainer,
                    key: ValueKey(info.profilePhoto),
                    backgroundImage: info.profilePhoto != null
                        ? NetworkImage(info.profilePhoto.toString())
                        : null,
                    child: uploadingAvatar
                        ? CircularProgressIndicator(
                            strokeWidth: 2,
                            color: cs.onPrimaryContainer,
                          )
                        : info.profilePhoto == null
                        ? Text(
                            initials(name),
                            style: tt.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: cs.onPrimaryContainer,
                            ),
                          )
                        : null,
                  ),
                ),
                if (isOwnProfile)
                  Positioned(
                    bottom: 2,
                    right: 2,
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: cs.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: cs.surface, width: 2),
                      ),
                      child: Icon(
                        Icons.camera_alt_rounded,
                        size: 11,
                        color: cs.onPrimary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                StatCard(
                  value: isInstructor
                      ? '${profile.instructorProfile.yearsOfExperience}yr'
                      : profile.studentProfile.currentLevel
                            .toJson()
                            .substring(0, 3)
                            .toUpperCase(),
                  label: isInstructor ? 'Experience' : 'Level',
                ),
                StatCard(
                  value: isInstructor
                      ? '${profile.instructorProfile.expertise.length}'
                      : '${profile.studentProfile.interests.length}',
                  label: isInstructor ? 'Expertise' : 'Interests',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
