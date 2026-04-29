import 'package:flutter/material.dart';
import 'package:edumap_portfolio_project/features/profile/models/profile_model.dart';

class SocialRow extends StatelessWidget {
  const SocialRow({super.key, required this.info});
  final ProfileInfo info;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        if (info.socialLinks.linkedin.isNotEmpty)
          ActionChip(
            avatar: Icon(
              Icons.work_outline_rounded,
              size: 14,
              color: cs.primary,
            ),
            label: const Text('LinkedIn'),
            onPressed: () {},
            side: BorderSide(color: cs.outlineVariant),
            backgroundColor: Colors.transparent,
            shape: const StadiumBorder(),
            visualDensity: VisualDensity.compact,
          ),
        if (info.socialLinks.github.isNotEmpty)
          ActionChip(
            avatar: Icon(Icons.code_rounded, size: 14, color: cs.primary),
            label: const Text('GitHub'),
            onPressed: () {},
            side: BorderSide(color: cs.outlineVariant),
            backgroundColor: Colors.transparent,
            shape: const StadiumBorder(),
            visualDensity: VisualDensity.compact,
          ),
        if (info.socialLinks.website.isNotEmpty)
          ActionChip(
            avatar: Icon(Icons.language_rounded, size: 14, color: cs.primary),
            label: const Text('Website'),
            onPressed: () {},
            side: BorderSide(color: cs.outlineVariant),
            backgroundColor: Colors.transparent,
            shape: const StadiumBorder(),
            visualDensity: VisualDensity.compact,
          ),
      ],
    );
  }
}
