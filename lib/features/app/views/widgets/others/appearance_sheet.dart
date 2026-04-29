import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edumap_portfolio_project/features/app/views/view_models/app_theme_provider.dart';

class AppearanceSheet extends ConsumerStatefulWidget {
  const AppearanceSheet._({required this.messenger});

  final ScaffoldMessengerState messenger;

  static void show(BuildContext context) {
    
    final messenger = ScaffoldMessenger.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => AppearanceSheet._(messenger: messenger),
    );
  }

  @override
  ConsumerState<AppearanceSheet> createState() => _AppearanceSheetState();
}

class _AppearanceSheetState extends ConsumerState<AppearanceSheet> {
  late String _theme;

  @override
  void initState() {
    super.initState();
    _theme = ref.read(themeProvider.notifier).themeName;
  }

  @override
  Widget build(BuildContext context) {
    final options = [
      (
        'system',
        Icons.brightness_auto_outlined,
        'System Default',
        'Follows your device setting',
      ),
      ('light', Icons.light_mode_outlined, 'Light', 'Always use light theme'),
      ('dark', Icons.dark_mode_outlined, 'Dark', 'Always use dark theme'),
    ];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              'Appearance',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'Choose how the app looks on your device.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 20),
            RadioGroup<String>(
              groupValue: _theme,
              onChanged: (value) => setState(() => _theme = value!),
              child: Column(
                children: options.map((opt) {
                  final (value, icon, label, subtitle) = opt;
                  return RadioListTile<String>(
                    value: value,
                    secondary: Icon(icon),
                    title: Text(label),
                    subtitle: Text(subtitle),
                    contentPadding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () async {
                await ref.read(themeProvider.notifier).setTheme(_theme);

                if (!context.mounted) return;

                Navigator.pop(context);

                // Use the pre-captured messenger from the parent Scaffold
                widget.messenger.showSnackBar(
                  SnackBar(
                    content: Text('Appearance set to $_theme'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }
}
