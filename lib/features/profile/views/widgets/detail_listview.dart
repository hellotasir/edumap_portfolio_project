import 'package:flutter/material.dart';
import 'package:edumap_portfolio_project/features/profile/models/detail_item.dart';
import 'package:edumap_portfolio_project/features/profile/views/widgets/detail_card.dart';

class DetailListView extends StatelessWidget {
  const DetailListView({super.key, required this.items});
  final List<DetailItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Text(
            'No details yet',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) => DetailCard(item: items[i]),
    );
  }
}
