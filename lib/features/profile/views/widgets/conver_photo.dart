import 'package:flutter/material.dart';
import 'package:edumap_portfolio_project/features/profile/models/profile_model.dart';

class CoverPhoto extends StatelessWidget {
  const CoverPhoto({
    super.key,
    required this.info,
    required this.isOwnProfile,
    required this.uploading,
    required this.onTap,
  });

  final ProfileInfo info;
  final bool isOwnProfile;
  final bool uploading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(
          child: info.coverPhoto.isNotEmpty
              ? Image.network(
                  info.coverPhoto,
                  fit: BoxFit.cover,
                  key: ValueKey(info.coverPhoto),
                  errorBuilder: (_, _, _) =>
                      ColoredBox(color: cs.secondaryContainer),
                )
              : DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [cs.primaryContainer, cs.secondaryContainer],
                    ),
                  ),
                ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, cs.scrim.withValues(alpha: 0.45)],
            ),
          ),
        ),
        if (uploading)
          ColoredBox(
            color: cs.scrim.withValues(alpha: 0.4),
            child: const Center(child: CircularProgressIndicator()),
          ),
        if (isOwnProfile)
          Positioned(
            right: 16,
            bottom: 16,
            child: _EditCoverButton(uploading: uploading, onTap: onTap),
          ),
      ],
    );
  }
}

class _EditCoverButton extends StatelessWidget {
  const _EditCoverButton({required this.uploading, required this.onTap});
  final bool uploading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      onPressed: onTap,
      avatar: uploading
          ? const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: Colors.white,
              ),
            )
          : const Icon(
              Icons.camera_alt_outlined,
              size: 14,
              color: Colors.white,
            ),
      label: const Text(
        'Edit cover',
        style: TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
      backgroundColor: Colors.black.withValues(alpha: 0.4),
      side: BorderSide(color: Colors.white.withValues(alpha: 0.2), width: 0.5),
      shape: const StadiumBorder(),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
    );
  }
}
