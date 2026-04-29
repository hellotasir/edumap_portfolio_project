import 'package:flutter/material.dart';
import 'package:edumap_portfolio_project/features/profile/models/detail_item.dart';

class DetailCard extends StatelessWidget {
  const DetailCard({super.key, required this.item});
  final DetailItem item;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: item.isTags || item.progress != null
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(item.icon, size: 18, color: cs.onSurfaceVariant),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: tt.labelSmall?.copyWith(
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 3),
                if (item.isTags) ...[
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: item.tags
                        .map(
                          (t) => Chip(
                            backgroundColor: Colors.black,
                            label: Text(
                              t,
                              style: tt.labelSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ] else if (item.progress != null) ...[
                  Text(
                    item.subtitle,
                    style: TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: item.progress,
                      minHeight: 6,
                      backgroundColor: cs.surface,
                      valueColor: AlwaysStoppedAnimation(Colors.grey),
                    ),
                  ),
                ] else
                  Text(
                    item.subtitle,
                    style: tt.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
