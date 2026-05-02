import 'package:flutter/material.dart';
import 'package:edumap_portfolio_project/features/profile/models/profile_model.dart';

class HomeProfileAvatar extends StatelessWidget {
  const HomeProfileAvatar({
    super.key,
    required this.isLoading,
    required this.profile,
  });

  final bool isLoading;
  final ProfileModel? profile;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const SizedBox.square(
        dimension: 32,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    final photoUrl = _safePhotoUrl(profile);
    if (photoUrl != null) {
      return CircleAvatar(
        radius: 16,
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: ClipOval(
          child: Image.network(
            photoUrl,
            width: 32,
            height: 32,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _FallbackAvatar(profile: profile),
          ),
        ),
      );
    }

    return _FallbackAvatar(profile: profile);
  }

  String? _safePhotoUrl(ProfileModel? profile) {
    final uri = profile?.profile.profilePhoto;
    if (uri == null) return null;
    final url = uri.toString();
    return (url.startsWith('https://') || url.startsWith('http://'))
        ? url
        : null;
  }
}

class _FallbackAvatar extends StatelessWidget {
  const _FallbackAvatar({required this.profile});

  final ProfileModel? profile;

  @override
  Widget build(BuildContext context) {
    final initial = profile?.username.isNotEmpty == true
        ? profile!.username[0].toUpperCase()
        : null;

    return CircleAvatar(
      radius: 16,
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      child: initial != null
          ? Text(
              initial,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            )
          : Icon(
              Icons.person_rounded,
              size: 16,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
    );
  }
}
