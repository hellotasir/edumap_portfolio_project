import 'package:flutter/material.dart';
import 'package:edumap_portfolio_project/features/location/models/location_model.dart';

class EntryChip extends StatelessWidget {
  const EntryChip({super.key, required this.entry, required this.theme});

  final UserAddressEntry entry;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final isInstructor = entry.category == AddressCategory.instructor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: isInstructor
            ? theme.colorScheme.tertiaryContainer
            : theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            entry.type == AddressType.currentLocation
                ? Icons.my_location_rounded
                : Icons.location_on_rounded,
            size: 10,
            color: isInstructor
                ? theme.colorScheme.onTertiaryContainer
                : theme.colorScheme.onPrimaryContainer,
          ),
          const SizedBox(width: 3),
          Text(
            entry.title,
            style: theme.textTheme.labelSmall?.copyWith(
              fontSize: 9,
              color: isInstructor
                  ? theme.colorScheme.onTertiaryContainer
                  : theme.colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
