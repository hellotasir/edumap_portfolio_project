import 'package:flutter/material.dart';
import 'package:flutter_education_app/features/location/models/location_model.dart';

class SharedEntryTile extends StatelessWidget {
  const SharedEntryTile({super.key, 
    required this.entry,
    required this.theme,
    required this.onTap,
  });

  final UserAddressEntry entry;
  final ThemeData theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isInstructor = entry.category == AddressCategory.instructor;
    final color = isInstructor
        ? theme.colorScheme.tertiary
        : theme.colorScheme.primary;
    final bgColor = isInstructor
        ? theme.colorScheme.tertiaryContainer
        : theme.colorScheme.primaryContainer;
    final fgColor = isInstructor
        ? theme.colorScheme.onTertiaryContainer
        : theme.colorScheme.onPrimaryContainer;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(
                entry.type == AddressType.currentLocation
                    ? Icons.my_location_rounded
                    : Icons.location_on_rounded,
                color: color,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    entry.address.city.isNotEmpty
                        ? entry.address.city
                        : entry.address.formattedAddress,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                entry.category.label.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: fgColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 9,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.map_rounded,
              size: 16,
              color: theme.colorScheme.primary,
            ),
          ],
        ),
      ),
    );
  }
}


