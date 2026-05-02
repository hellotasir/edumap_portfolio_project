import 'package:flutter/material.dart';
import 'package:edumap_portfolio_project/features/profile/models/detail_item.dart';
import 'package:edumap_portfolio_project/features/profile/models/profile_model.dart';
import 'package:edumap_portfolio_project/features/profile/views/widgets/detail_listview.dart';

class StudentListView extends StatelessWidget {
  const StudentListView({
    super.key,
    required this.profile,
    required this.capitalize,
  });
  final StudentProfile profile;
  final String Function(String) capitalize;

  static const _levels = ['beginner', 'intermediate', 'advanced', 'expert'];

  @override
  Widget build(BuildContext context) {
    final idx = _levels.indexOf(profile.currentLevel.toJson().toLowerCase());
    final progress = idx < 0 ? 0.25 : (idx + 1) / _levels.length;

    final items = <DetailItem>[
      DetailItem(
        icon: Icons.bar_chart_rounded,
        title: 'Current Level',
        subtitle: capitalize(profile.currentLevel.toJson()),
        progress: progress,
      ),
      DetailItem(
        icon: Icons.toggle_on_outlined,
        title: 'Status',
        subtitle: profile.isActive ? 'Active' : 'Inactive',
      ),
      if (profile.interests.isNotEmpty)
        DetailItem(
          icon: Icons.interests_outlined,
          title: 'Interests',
          subtitle: profile.interests.map(capitalize).join(', '),
          isTags: true,
          tags: profile.interests,
        ),
    ];
    return DetailListView(items: items);
  }
}
