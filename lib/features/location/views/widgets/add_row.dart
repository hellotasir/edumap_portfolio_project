import 'package:flutter/material.dart';

class AddrRow extends StatelessWidget {
  const AddrRow({
    super.key,
    required this.icon,
    required this.label,
    required this.address,
    required this.isPrimary,
    required this.theme,
  });

  final IconData icon;
  final String label;
  final String address;
  final bool isPrimary;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final color = isPrimary
        ? theme.colorScheme.primary
        : theme.colorScheme.tertiary;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withOpacity(0.12),
          ),
          child: Icon(icon, color: color, size: 14),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                address,
                style: theme.textTheme.bodySmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
