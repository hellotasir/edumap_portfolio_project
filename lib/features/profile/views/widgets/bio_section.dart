import 'package:flutter/material.dart';
import 'package:edumap_portfolio_project/features/profile/models/profile_model.dart';
import 'package:edumap_portfolio_project/features/profile/views/widgets/social_row.dart';

class BioSection extends StatelessWidget {
  const BioSection({
    super.key,
    required this.profile,
    required this.capitalize,
  });
  final ProfileModel profile;
  final String Function(String) capitalize;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final info = profile.profile;
    final name = info.fullName.isNotEmpty ? info.fullName : profile.username;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 3),
          Row(
            children: [
              Icon(
                profile.currentMode == 'instructor'
                    ? Icons.school_outlined
                    : Icons.person_outline_rounded,
                size: 13,
                color: cs.primary,
              ),
              const SizedBox(width: 4),
              Text(
                capitalize(profile.currentMode.toString()),
                style: tt.bodySmall?.copyWith(
                  color: cs.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (profile.isVerified) ...[
                const SizedBox(width: 8),
                Icon(Icons.verified_rounded, size: 13, color: cs.primary),
                const SizedBox(width: 2),
                Text(
                  'Verified',
                  style: tt.bodySmall?.copyWith(color: cs.primary),
                ),
              ],
            ],
          ),
          if (info.bio.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(info.bio, style: tt.bodyMedium?.copyWith(height: 1.5)),
          ],
          SizedBox(height: 5),
          if (info.location.city.isNotEmpty ||
              info.location.country.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  Icons.location_on_outlined,
                  size: 13,
                  color: cs.onSurfaceVariant,
                ),
                const SizedBox(width: 3),
                Text(
                  [
                    info.location.city,
                    info.location.country,
                  ].where((s) => s.isNotEmpty).join(', '),
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ],
          SizedBox(height: 12),
          if (_hasSocialLinks(info)) ...[
            const SizedBox(height: 10),
            SocialRow(info: info),
          ],
        ],
      ),
    );
  }

  static bool _hasSocialLinks(ProfileInfo info) =>
      info.socialLinks.linkedin != null ||
      info.socialLinks.github != null ||
      info.socialLinks.website != null;
}
