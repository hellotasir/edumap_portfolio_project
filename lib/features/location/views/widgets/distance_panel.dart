import 'package:flutter/material.dart';
import 'package:edumap_portfolio_project/features/location/models/location_model.dart';
import 'package:edumap_portfolio_project/features/location/views/widgets/add_row.dart';
import 'package:edumap_portfolio_project/features/location/views/widgets/warn_row.dart';

class DistancePanel extends StatelessWidget {
  const DistancePanel({
    super.key,
    required this.friend,
    required this.theirEntry,
    required this.myEntry,
    required this.distanceKm,
    required this.theme,
  });

  final FriendLocationData friend;
  final UserAddressEntry? theirEntry;
  final UserAddressEntry? myEntry;
  final double? distanceKm;
  final ThemeData theme;

  String _fmt(double km) {
    if (km < 1.0) return '${(km * 1000).round()} m';
    return '${km.toStringAsFixed(1)} km';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withOpacity(0.2),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          20 + MediaQuery.of(context).padding.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: theme.colorScheme.secondaryContainer,
                  backgroundImage: friend.profilePhoto.isNotEmpty
                      ? NetworkImage(friend.profilePhoto)
                      : null,
                  child: friend.profilePhoto.isEmpty
                      ? Icon(
                          friend.role == 'instructor'
                              ? Icons.school_rounded
                              : Icons.person_rounded,
                          color: theme.colorScheme.onSecondaryContainer,
                          size: 20,
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        friend.displayName,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (theirEntry != null)
                        Text(
                          '${theirEntry!.title}  ·  ${theirEntry!.category.label}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                if (distanceKm != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Text(
                          _fmt(distanceKm!),
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'away',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer
                                .withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Divider(color: theme.colorScheme.outlineVariant),
            const SizedBox(height: 10),
            if (myEntry != null)
              AddrRow(
                icon: Icons.my_location_rounded,
                label: 'Your location  ·  ${myEntry!.title}',
                address: myEntry!.address.formattedAddress,
                isPrimary: true,
                theme: theme,
              ),
            if (myEntry != null && theirEntry != null)
              const SizedBox(height: 8),
            if (theirEntry != null)
              AddrRow(
                icon: theirEntry!.category == AddressCategory.instructor
                    ? Icons.school_rounded
                    : Icons.person_rounded,
                label: "${friend.username}'s ${theirEntry!.title}",
                address: theirEntry!.address.formattedAddress,
                isPrimary: false,
                theme: theme,
              ),
            if (myEntry == null)
              WarnRow(
                message: 'Your location not found. Tap refresh above.',
                theme: theme,
              ),
            if (theirEntry == null)
              WarnRow(
                message:
                    '${friend.username} has no visible location for this category.',
                theme: theme,
              ),
          ],
        ),
      ),
    );
  }
}
