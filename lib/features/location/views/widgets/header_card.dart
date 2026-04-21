import 'package:flutter/material.dart';

import 'error_banner.dart';

class HeaderCard extends StatelessWidget {
  const HeaderCard({
    super.key,
    required this.theme,
    required this.loadingGps,
    required this.gpsError,
    required this.hasCurrent,
    required this.onShareGps,
    required this.onTrackDistance,
    required this.onAddAddress,
  });

  final ThemeData theme;
  final bool loadingGps;
  final String? gpsError;
  final bool hasCurrent;
  final VoidCallback onShareGps;
  final VoidCallback onTrackDistance;
  final VoidCallback onAddAddress;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.location_on_rounded,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'My Locations',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Manage what others can see',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (gpsError != null) ...[
              const SizedBox(height: 12),
              ErrorBanner(message: gpsError!, theme: theme),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: loadingGps ? null : onShareGps,
                    icon: loadingGps
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.gps_fixed_rounded, size: 18),
                    label: Text(hasCurrent ? 'Refresh GPS' : 'Share GPS'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onAddAddress,
                    icon: const Icon(Icons.add_location_alt_rounded, size: 18),
                    label: const Text('Add Address'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onTrackDistance,
                icon: const Icon(Icons.people_alt_rounded, size: 18),
                label: const Text('Track Distance with Friends'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
