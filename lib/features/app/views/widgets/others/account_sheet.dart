import 'package:flutter/material.dart';
import 'package:edumap_portfolio_project/features/app/views/screens/settings_screen.dart';
import 'package:edumap_portfolio_project/features/auth/repositories/auth_repository.dart';
import 'package:edumap_portfolio_project/features/auth/views/screens/account_details_screen.dart';
import 'package:edumap_portfolio_project/features/auth/views/screens/delete_account_screen.dart';
import 'package:edumap_portfolio_project/features/auth/views/screens/mfa_screen.dart';
import 'package:edumap_portfolio_project/features/auth/views/screens/reset_password_screen.dart';
import 'package:edumap_portfolio_project/features/auth/views/screens/update_email_screen.dart';

void openFullSheet(BuildContext context, Widget child) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => DraggableScrollableSheet(
      initialChildSize: 1.0,
      minChildSize: 0.5,
      maxChildSize: 1.0,
      expand: false,
      builder: (_, scrollController) => child,
    ),
  );
}

class AccountSheet extends StatelessWidget {
  const AccountSheet({super.key, required this.authRepository});

  final AuthRepository authRepository;

  static void show(BuildContext context, AuthRepository authRepository) =>
      openFullSheet(context, AccountSheet(authRepository: authRepository));

  @override
  Widget build(BuildContext context) {
    return SheetScaffold(
      title: 'Account Settings',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          const SubSectionHeader(label: 'Account'),
          SettingsTile(
            icon: Icons.info_outline_rounded,
            label: 'Account Details',
            onTap: () {
              Navigator.pop(context);
              AccountDetailsScreen.open(context, authRepository);
            },
          ),
          const SubSectionHeader(label: 'Security'),
          SettingsTile(
            icon: Icons.alternate_email_rounded,
            label: 'Update Email',
            onTap: () {
              Navigator.pop(context);
              UpdateEmailScreen.open(context, authRepository);
            },
          ),
          SettingsTile(
            icon: Icons.security_rounded,
            label: 'Two-Factor Authentication',
            onTap: () {
              Navigator.pop(context);
              MfaScreen.open(context, authRepository);
            },
          ),
          SettingsTile(
            icon: Icons.lock_reset_rounded,
            label: 'Reset Password',
            onTap: () {
              Navigator.pop(context);
              ResetPasswordScreen.open(context, authRepository);
            },
          ),

          const SubSectionHeader(label: 'Danger Zone'),
          SettingsTile(
            icon: Icons.delete_forever_rounded,
            label: 'Delete Account',
            color: Colors.red.shade600,
            onTap: () {
              Navigator.pop(context);
              DeleteAccountScreen.open(context, authRepository);
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
