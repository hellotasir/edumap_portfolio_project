import 'package:flutter/material.dart';

class MapButton extends StatelessWidget {
  const MapButton({super.key, required this.onTap, required this.child});

  final VoidCallback? onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          shape: BoxShape.circle,
          border: Border.all(color: theme.colorScheme.outlineVariant),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.shadow.withOpacity(0.1),
              blurRadius: 8,
            ),
          ],
        ),
        child: IconTheme(
          data: IconThemeData(color: theme.colorScheme.onSurface, size: 18),
          child: child,
        ),
      ),
    );
  }
}
