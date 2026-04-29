import 'package:flutter/material.dart';
import 'package:edumap_portfolio_project/core/consts/app_details.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutSheet extends StatelessWidget {
  AboutSheet._();

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => AboutSheet._(),
    );
  }

  final Uri _githubUrl = Uri.parse('https://github.com/hellotasir');
  final Uri _portfolioUrl = Uri.parse('https://tasirrahman-portfolio.web.app');

  Future<void> _launchGithubUrl() async {
    if (!await launchUrl(_githubUrl)) {
      throw Exception('Could not launch $_githubUrl');
    }
  }

  Future<void> _launchPortfolioUrl() async {
    if (!await launchUrl(_portfolioUrl)) {
      throw Exception('Could not launch $_portfolioUrl');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            Text(
              'About',
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),

            const SizedBox(height: 6),

            Text(
              'App information and legal links.',
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),

            const SizedBox(height: 24),

         
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Image.asset(
                isDark
                    ? 'assets/edumap-transparent-icon.png'
                    : 'assets/edumap-black-transparent-icon.png',

                height: 60,
                width: 60,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              appName,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              inc,
              textAlign: TextAlign.center,
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),

            const SizedBox(height: 20),
            const Divider(height: 1),
            const SizedBox(height: 8),

            _AboutTile(
              icon: Icons.circle,
              label: 'Github Repository',
              onTap: _launchGithubUrl,
            ),
            _AboutTile(
              icon: Icons.circle,
              label: 'Portfolio Website',
              onTap: _launchPortfolioUrl,
            ),

            const SizedBox(height: 16),

            Center(
              child: Text(
                'An Education Portfolio App, Created and Maintained by Tasir Rahman.',
                textAlign: TextAlign.center,
                style: textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.4),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AboutTile extends StatelessWidget {
  const _AboutTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, size: 20),
      title: Text(label),
      trailing: const Icon(Icons.open_in_new_rounded, size: 16),
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
    );
  }
}
