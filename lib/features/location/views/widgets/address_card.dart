import 'package:flutter/material.dart';
import 'package:edumap_portfolio_project/features/location/models/location_model.dart';

class AddressCard extends StatelessWidget {
  const AddressCard({
    super.key,
    required this.entry,
    required this.theme,
    required this.onToggleVisibility,
    this.onDelete,
  });

  final UserAddressEntry entry;
  final ThemeData theme;
  final VoidCallback onToggleVisibility;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final isCurrent = entry.type == AddressType.currentLocation;
    final catColor = entry.category == AddressCategory.instructor
        ? theme.colorScheme.tertiary
        : theme.colorScheme.primary;
    final catBg = entry.category == AddressCategory.instructor
        ? theme.colorScheme.tertiaryContainer
        : theme.colorScheme.primaryContainer;
    final catFg = entry.category == AddressCategory.instructor
        ? theme.colorScheme.onTertiaryContainer
        : theme.colorScheme.onPrimaryContainer;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: catColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isCurrent
                        ? Icons.my_location_rounded
                        : Icons.location_on_rounded,
                    color: catColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              entry.title,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (isCurrent)
                            Container(
                              margin: const EdgeInsets.only(left: 6),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.secondaryContainer,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'GPS',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSecondaryContainer,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: catBg,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          entry.category.label.toUpperCase(),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: catFg,
                            fontWeight: FontWeight.w800,
                            fontSize: 9,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: entry.isVisible,
                  onChanged: (_) => onToggleVisibility(),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.place_outlined,
                  size: 14,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    entry.address.formattedAddress,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (entry.accuracy != null && isCurrent) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.radar_rounded,
                    size: 12,
                    color: theme.colorScheme.outline,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '±${entry.accuracy!.toStringAsFixed(0)} m accuracy',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ],
            Row(
              children: [
                const Spacer(),
                Text(
                  entry.isVisible ? 'Visible to friends' : 'Hidden',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: entry.isVisible
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (onDelete != null) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      size: 18,
                      color: theme.colorScheme.error,
                    ),
                    onPressed: onDelete,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
