import 'package:edumap_portfolio_project/features/app/views/widgets/others/network_widget.dart';
import 'package:flutter/material.dart';
import 'package:edumap_portfolio_project/core/services/local/fcm_token_service.dart';
import 'package:edumap_portfolio_project/core/services/notification/firestore_listener_service.dart';
import 'package:edumap_portfolio_project/features/app/views/screens/notification_settings_screen.dart';
import 'package:edumap_portfolio_project/features/subscription/views/screens/subscription_screen.dart';
import 'package:edumap_portfolio_project/features/profile/models/profile_model.dart';
import 'package:edumap_portfolio_project/features/auth/repositories/auth_repository.dart';
import 'package:edumap_portfolio_project/features/app/views/widgets/others/account_sheet.dart';
import 'package:edumap_portfolio_project/core/routers/app_navigator.dart';
import 'package:edumap_portfolio_project/features/auth/views/screens/login_screen.dart';
import 'package:edumap_portfolio_project/features/feedback/views/screens/feedback_screen.dart';
import 'package:edumap_portfolio_project/features/profile/views/screens/profile_settings_screen.dart';
import 'package:edumap_portfolio_project/core/widgets/snackbar_widget.dart';
import 'package:edumap_portfolio_project/features/app/views/widgets/others/appearance_sheet.dart';
import 'package:edumap_portfolio_project/features/app/views/widgets/others/about_app_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.profile});

  final ProfileModel profile;

  static void open(BuildContext context, ProfileModel profile) {
    AppNavigator(screen: SettingsScreen(profile: profile)).navigate(context);
  }

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AuthRepository _authRepository = AuthRepository();
  bool _isSigningOut = false;

  Future<void> _handleSignOut() async {
    if (_isSigningOut) return;

    setState(() => _isSigningOut = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      final userId = user?.id;
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('background_service_user_id');
      FirestoreListenerService.instance.stopListening();
      if (userId != null) {
        await FcmTokenService.instance.removeToken(userId);
      }
      await _authRepository.logout();
      if (mounted) {
        AppNavigator(screen: LoginScreen()).navigate(context);
      }
    } catch (e) {
      if (mounted) {
        SnackbarWidget(message: 'Logout failed').showSnackbar(context);
        setState(() => _isSigningOut = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return NetworkWidget(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Settings'),
          leading: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.chevron_left_rounded),
          ),
        ),
        body: ListView(
          children: [
            const SectionHeader(label: 'Profile'),
            SettingsTile(
              icon: Icons.person,
              label: 'Profile Settings',
              onTap: () => AppNavigator(
                screen: ProfileSettingsScreen(profile: widget.profile),
              ).navigate(context),
            ),
            const SectionHeader(label: 'Account'),
            SettingsTile(
              icon: Icons.payment,
              label: 'Subscription',
              onTap: () =>
                  AppNavigator(screen: SubscriptionScreen()).navigate(context),
            ),
            SettingsTile(
              icon: Icons.manage_accounts_outlined,
              label: 'Account Settings',
              onTap: () => AccountSheet.show(context, _authRepository),
            ),
            const SectionHeader(label: 'Preferences'),
            SettingsTile(
              icon: Icons.dark_mode_outlined,
              label: 'Appearance',
              onTap: () => AppearanceSheet.show(context),
            ),
            SettingsTile(
              icon: Icons.notifications_outlined,
              label: 'Notifications',
              onTap: () => NotificationSettingsScreen.open(context),
            ),
            const SectionHeader(label: 'Support'),
            SettingsTile(
              icon: Icons.feedback_outlined,
              label: 'Send Feedback',
              onTap: () => FeedbackScreen.open(context, _authRepository),
            ),
            SettingsTile(
              icon: Icons.info_outlined,
              label: 'About',
              onTap: () => AboutSheet.show(context),
            ),
            const SectionHeader(label: 'Session'),
            SettingsTile(
              icon: Icons.logout_rounded,
              label: 'Sign Out',
              color: Colors.red.shade600,
              onTap: _handleSignOut,
              trailing: _isSigningOut
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.red.shade600,
                      ),
                    )
                  : null,
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

Future<T?> openFullSheet<T>(
  BuildContext context,
  Widget child, {
  bool isDismissible = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    isDismissible: isDismissible,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (ctx, scrollController) =>
          SingleChildScrollView(controller: scrollController, child: child),
    ),
  );
}

class SheetScaffold extends StatelessWidget {
  const SheetScaffold({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
  });

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.outline.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 20,
            ).copyWith(top: 8, bottom: 4),
            child: Row(
              children: [
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                ?trailing,
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          child,
        ],
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 6),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(
            context,
          ).colorScheme.onSurface.withValues(alpha: 0.45),
          fontWeight: FontWeight.w700,
          letterSpacing: 0.9,
        ),
      ),
    );
  }
}

class SubSectionHeader extends StatelessWidget {
  const SubSectionHeader({super.key, required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: Theme.of(
            context,
          ).colorScheme.onSurface.withValues(alpha: 0.45),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class SettingsTile extends StatelessWidget {
  const SettingsTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? Theme.of(context).colorScheme.onSurface;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      color: colorScheme.surface,
      child: Column(
        children: [
          ListTile(
            leading: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: (color ?? colorScheme.primary).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 20, color: effectiveColor),
            ),
            title: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: effectiveColor,
                fontWeight: FontWeight.w500,
              ),
            ),
            trailing:
                trailing ??
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: colorScheme.onSurface.withValues(alpha: 0.3),
                ),
            onTap: onTap,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 2,
            ),
          ),
          Divider(
            height: 1,
            indent: 72,
            color: colorScheme.outline.withValues(alpha: 0.12),
          ),
        ],
      ),
    );
  }
}

class SwitchTile extends StatelessWidget {
  const SwitchTile({
    super.key,
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SwitchListTile(
      secondary: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: colorScheme.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 20, color: colorScheme.primary),
      ),
      title: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        subtitle,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurface.withValues(alpha: 0.55),
        ),
      ),
      value: value,
      onChanged: onChanged,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
    );
  }
}
