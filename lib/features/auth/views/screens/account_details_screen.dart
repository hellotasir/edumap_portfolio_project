import 'package:flutter/material.dart';
import 'package:flutter_education_app/features/auth/repositories/auth_repository.dart';
import 'package:flutter_education_app/features/auth/views/view_models/auth_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_education_app/core/routers/app_navigator.dart';
import 'package:flutter_education_app/core/widgets/material_widget.dart';

class AccountDetailsScreen extends ConsumerWidget {
  const AccountDetailsScreen({super.key});

  static void open(BuildContext context, AuthRepository authRepository) {
    AppNavigator(screen: const AccountDetailsScreen()).navigate(context);
  }

  String _formatDate(String isoDate) {
    try {
      final dt = DateTime.parse(isoDate).toLocal();
      return '${dt.year}-${_pad(dt.month)}-${_pad(dt.day)}  '
          '${_pad(dt.hour)}:${_pad(dt.minute)}';
    } catch (_) {
      return isoDate;
    }
  }

  String _pad(int n) => n.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final repo = ref.watch(authRepositoryProvider);
    final session = repo.currentSession;
    final isAuthenticated = ref.watch(isAuthenticatedProvider);

    return MaterialWidget(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Account Details'),
          leading: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.chevron_left_rounded),
          ),
        ),
        body: SafeArea(
          child: user == null
              ? const Center(child: Text('No user logged in.'))
              : ListView(
                  children: [
                    const _SectionLabel(label: 'Account'),
                    _DetailTile(
                      icon: Icons.email_outlined,
                      label: 'Email',
                      value: user.email ?? 'N/A',
                    ),
                    const _DetailDivider(),
                    _StatusTile(
                      icon: Icons.mark_email_read_outlined,
                      label: 'Email Confirmed',
                      status: user.emailConfirmedAt != null,
                      subtitle: user.emailConfirmedAt != null
                          ? _formatDate(user.emailConfirmedAt!)
                          : 'Not confirmed',
                    ),
                    const _SectionLabel(label: 'Activity'),
                    _DetailTile(
                      icon: Icons.calendar_today_outlined,
                      label: 'Created At',
                      value: user.createdAt.isNotEmpty
                          ? _formatDate(user.createdAt)
                          : 'N/A',
                    ),
                    const _DetailDivider(),
                    _DetailTile(
                      icon: Icons.login_outlined,
                      label: 'Last Sign In',
                      value: user.lastSignInAt != null
                          ? _formatDate(user.lastSignInAt!)
                          : 'N/A',
                    ),
                    const _DetailDivider(),
                    _DetailTile(
                      icon: Icons.update_outlined,
                      label: 'Updated At',
                      value: user.updatedAt != null
                          ? _formatDate(user.updatedAt!)
                          : 'N/A',
                    ),
                    if (session != null) ...[
                      const _SectionLabel(label: 'Session'),
                      _StatusTile(
                        icon: Icons.power_outlined,
                        label: 'Session Active',
                        status: isAuthenticated,
                        subtitle: isAuthenticated ? 'Active' : 'Inactive',
                      ),
                      const _DetailDivider(),
                      _DetailTile(
                        icon: Icons.timer_outlined,
                        label: 'Session Expires At',
                        value: session.expiresAt != null
                            ? _formatDate(
                                DateTime.fromMillisecondsSinceEpoch(
                                  session.expiresAt! * 1000,
                                ).toIso8601String(),
                              )
                            : 'N/A',
                      ),
                    ],
                    const SizedBox(height: 24),
                  ],
                ),
        ),
      ),
    );
  }
}


class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 6),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _DetailDivider extends StatelessWidget {
  const _DetailDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      indent: 56,
      color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.15),
    );
  }
}

class _DetailTile extends StatelessWidget {
  const _DetailTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 20,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
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

class _StatusTile extends StatelessWidget {
  const _StatusTile({
    required this.icon,
    required this.label,
    required this.status,
    required this.subtitle,
  });

  final IconData icon;
  final String label;
  final bool status;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = status ? Colors.green : Colors.red;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  status ? Icons.check_circle_rounded : Icons.cancel_rounded,
                  size: 14,
                  color: color,
                ),
                const SizedBox(width: 4),
                Text(
                  status ? 'Yes' : 'No',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color,
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
