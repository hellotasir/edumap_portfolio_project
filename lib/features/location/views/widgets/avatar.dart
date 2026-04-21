import 'package:flutter/material.dart';

class Avatar extends StatelessWidget {
  const Avatar({
    super.key,
    required this.photoUrl,
    required this.role,
    required this.theme,
    this.radius = 22,
  });

  final String photoUrl;
  final String role;
  final ThemeData theme;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: theme.colorScheme.secondaryContainer,
      backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
      child: photoUrl.isEmpty
          ? Icon(
              role == 'instructor'
                  ? Icons.school_rounded
                  : Icons.person_rounded,
              color: theme.colorScheme.onSecondaryContainer,
              size: radius * 0.9,
            )
          : null,
    );
  }
}
