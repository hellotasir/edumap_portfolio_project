import 'package:flutter/material.dart';
import 'package:edumap_portfolio_project/features/profile/models/detail_item.dart';
import 'package:edumap_portfolio_project/features/profile/models/profile_model.dart';
import 'package:edumap_portfolio_project/features/profile/views/widgets/detail_listview.dart';

class ContactListView extends StatelessWidget {
  const ContactListView({super.key, required this.profile, required this.info});
  final ProfileModel profile;
  final ProfileInfo info;

  @override
  Widget build(BuildContext context) {
    final items = <DetailItem>[
      if (profile.email.isNotEmpty)
        DetailItem(
          icon: Icons.mail_outline_rounded,
          title: 'Email',
          subtitle: profile.email,
        ),
      if (profile.phone.isNotEmpty)
        DetailItem(
          icon: Icons.phone_outlined,
          title: 'Phone',
          subtitle: profile.phone,
        ),
      if (info.gender.isNotEmpty && info.gender != 'Prefer not to say')
        DetailItem(
          icon: Icons.person_outline_rounded,
          title: 'Gender',
          subtitle: info.gender,
        ),
      if (info.dateOfBirth != null)
        DetailItem(
          icon: Icons.cake_outlined,
          title: 'Birth Year',
          subtitle: '${info.dateOfBirth!.year}',
        ),
      if (info.location.timezone.isNotEmpty)
        DetailItem(
          icon: Icons.schedule_outlined,
          title: 'Timezone',
          subtitle: info.location.timezone,
        ),
      if (info.languages.isNotEmpty)
        DetailItem(
          icon: Icons.translate_rounded,
          title: 'Languages',
          subtitle: info.languages.join(', '),
        ),
      if (info.socialLinks.linkedin.isNotEmpty)
        DetailItem(
          icon: Icons.work_outline_rounded,
          title: 'LinkedIn',
          subtitle: info.socialLinks.linkedin,
          isLink: true,
        ),
      if (info.socialLinks.github.isNotEmpty)
        DetailItem(
          icon: Icons.code_rounded,
          title: 'GitHub',
          subtitle: info.socialLinks.github,
          isLink: true,
        ),
      if (info.socialLinks.website.isNotEmpty)
        DetailItem(
          icon: Icons.language_rounded,
          title: 'Website',
          subtitle: info.socialLinks.website,
          isLink: true,
        ),
    ];
    return DetailListView(items: items);
  }
}
