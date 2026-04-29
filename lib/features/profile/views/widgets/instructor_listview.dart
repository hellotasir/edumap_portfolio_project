import 'package:flutter/material.dart';
import 'package:edumap_portfolio_project/features/profile/models/detail_item.dart';
import 'package:edumap_portfolio_project/features/profile/models/profile_model.dart';
import 'package:edumap_portfolio_project/features/profile/views/widgets/detail_listview.dart';

class InstructorListView extends StatelessWidget {
  const InstructorListView({
    super.key,
    required this.profile,
    required this.capitalize,
  });
  final InstructorProfile profile;
  final String Function(String) capitalize;

  @override
  Widget build(BuildContext context) {
    final items = <DetailItem>[
      if (profile.headline.isNotEmpty)
        DetailItem(
          icon: Icons.format_quote_rounded,
          title: 'Headline',
          subtitle: profile.headline,
        ),
      DetailItem(
        icon: Icons.workspace_premium_outlined,
        title: 'Experience',
        subtitle: '${profile.yearsOfExperience} years',
      ),
      DetailItem(
        icon: Icons.toggle_on_outlined,
        title: 'Status',
        subtitle: profile.isActive ? 'Active' : 'Inactive',
      ),
      if (profile.expertise.isNotEmpty)
        DetailItem(
          icon: Icons.star_outline_rounded,
          title: 'Expertise',
          subtitle: profile.expertise.map(capitalize).join(', '),
          isTags: true,
          tags: profile.expertise,
        ),
    ];
    return DetailListView(items: items);
  }
}
