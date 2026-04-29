import 'package:flutter/material.dart';
import 'package:edumap_portfolio_project/features/profile/models/profile_model.dart';
import 'package:edumap_portfolio_project/features/profile/views/widgets/contact_listview.dart';
import 'package:edumap_portfolio_project/features/profile/views/widgets/instructor_listview.dart';
import 'package:edumap_portfolio_project/features/profile/views/widgets/student_listview.dart';

class DetailsSection extends StatefulWidget {
  const DetailsSection({
    super.key,
    required this.profile,
    required this.capitalize,
  });
  final ProfileModel profile;
  final String Function(String) capitalize;

  @override
  State<DetailsSection> createState() => DetailsSectionState();
}

class DetailsSectionState extends State<DetailsSection>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _tab.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isInstructor = widget.profile.currentMode == 'instructor';

    return Column(
      children: [
        TabBar(
          controller: _tab,
          indicatorSize: TabBarIndicatorSize.tab,
          indicatorColor: cs.primary,
          labelColor: cs.onSurface,
          unselectedLabelColor: cs.onSurfaceVariant,
          dividerColor: cs.outlineVariant.withValues(alpha: 0.4),
          indicatorWeight: 2,
          tabs: [
            Tab(
              icon: Icon(
                isInstructor
                    ? Icons.school_outlined
                    : Icons.person_outline_rounded,
                size: 20,
              ),
              text: isInstructor ? 'Instructor' : 'Student',
            ),

            const Tab(
              icon: Icon(Icons.info_outline_rounded, size: 20),
              text: 'Details',
            ),
          ],
        ),
        IndexedStack(
          index: _tab.index,
          children: [
            isInstructor
                ? InstructorListView(
                    profile: widget.profile.instructorProfile,
                    capitalize: widget.capitalize,
                  )
                : StudentListView(
                    profile: widget.profile.studentProfile,
                    capitalize: widget.capitalize,
                  ),

            ContactListView(
              profile: widget.profile,
              info: widget.profile.profile,
            ),
          ],
        ),
      ],
    );
  }
}
