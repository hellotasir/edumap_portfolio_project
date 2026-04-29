// ignore_for_file: use_build_context_synchronously

import 'package:edumap_portfolio_project/features/app/views/widgets/others/network_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:edumap_portfolio_project/features/auth/repositories/auth_repository.dart';
import 'package:edumap_portfolio_project/features/auth/views/view_models/auth_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edumap_portfolio_project/core/routers/app_navigator.dart';
import 'package:edumap_portfolio_project/core/widgets/snackbar_widget.dart';

class MfaScreen extends ConsumerStatefulWidget {
  const MfaScreen({super.key});

  static void open(BuildContext context, AuthRepository authRepository) {
    AppNavigator(screen: const MfaScreen()).navigate(context);
  }

  @override
  ConsumerState<MfaScreen> createState() => _MfaScreenState();
}

class _MfaScreenState extends ConsumerState<MfaScreen> {
  final _codeController = TextEditingController();

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }


  void _showError(String message) {
    if (!mounted) return;
    SnackbarWidget(message: message).showSnackbar(context);
  }

  Future<bool?> _showConfirmDialog({
    required String title,
    required String body,
    required String confirmLabel,
    bool isDestructive = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: isDestructive
                ? TextButton.styleFrom(foregroundColor: Colors.red.shade600)
                : null,
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }


  Future<void> _startEnrollment() async {
    try {
      await ref.read(mfaNotifierProvider.notifier).startEnrollment();
    } catch (_) {
      _showError('Enrollment failed');
    }
  }

  Future<void> _verifyAndActivate() async {
    final code = _codeController.text.trim();
    if (code.length != 6) {
      _showError('Please enter the 6-digit code from your authenticator app.');
      return;
    }
    try {
      await ref.read(mfaNotifierProvider.notifier).verifyAndActivate(code);
      _codeController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Two-factor authentication enabled!')),
        );
      }
    } catch (_) {
      _showError('Verification failed. Please check the code and try again.');
    }
  }

  Future<void> _unenroll() async {
    final confirm = await _showConfirmDialog(
      title: 'Disable 2FA?',
      body:
          'This will remove two-factor authentication from your account. '
          'Are you sure?',
      confirmLabel: 'Disable',
      isDestructive: true,
    );
    if (confirm != true) return;

    try {
      await ref.read(mfaNotifierProvider.notifier).unenroll();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Two-factor authentication disabled.')),
        );
      }
    } catch (_) {
      _showError('Failed to disable 2FA.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(mfaNotifierProvider);

    return NetworkWidget(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Two-Factor Authentication'),
          leading: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.chevron_left_rounded),
          ),
        ),
        body: SafeArea(
            child: state.step == MfaStep.checking && state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildBody(state),
          ),
      ),
    );
  }

  Widget _buildBody(MfaState state) {
    return switch (state.step) {
      MfaStep.checking => const Center(child: CircularProgressIndicator()),
      MfaStep.intro => _buildIntroView(state),
      MfaStep.scan => _buildScanView(state),
      MfaStep.enabled => _buildEnabledView(state),
    };
  }


  Widget _buildIntroView(MfaState state) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.security_rounded,
              size: 32,
              color: colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Two-Factor Authentication',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Add an extra layer of security to your account. After enabling "
            "2FA, you'll need to enter a 6-digit code from your authenticator "
            "app when signing in.",
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.65),
            ),
          ),
          const SizedBox(height: 32),
          _BenefitTile(
            icon: Icons.shield_outlined,
            title: 'Stronger account security',
            subtitle:
                'Even if your password is compromised, your account stays safe.',
          ),
          const SizedBox(height: 12),
          _BenefitTile(
            icon: Icons.phonelink_lock_outlined,
            title: 'Authenticator app',
            subtitle:
                'Works with Google Authenticator, Authy, and any TOTP-compatible app.',
          ),
          const SizedBox(height: 12),
          _BenefitTile(
            icon: Icons.timer_outlined,
            title: 'Time-based codes',
            subtitle: 'Generates a new secure code every 30 seconds.',
          ),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: state.isLoading ? null : _startEnrollment,
              icon: state.isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add_rounded),
              label: Text(state.isLoading ? 'Setting up…' : 'Enable 2FA'),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Scan / verify
  // ---------------------------------------------------------------------------

  Widget _buildScanView(MfaState state) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Text(
            'Scan QR Code',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Open your authenticator app and scan the QR code below, or enter '
            'the secret key manually.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.65),
            ),
          ),
          const SizedBox(height: 28),
          Center(
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                border: Border.all(
                  color: colorScheme.outline.withValues(alpha: 0.3),
                ),
                borderRadius: BorderRadius.circular(12),
                color: colorScheme.surfaceContainerHighest,
              ),
              child: state.qrSvg != null
                  ? const Center(
                      child: Icon(Icons.qr_code_2_rounded, size: 120),
                    )
                  : const Center(child: CircularProgressIndicator()),
            ),
          ),
          const SizedBox(height: 20),
          if (state.totpSecret != null) ...[
            Text(
              'Manual entry key',
              style: theme.textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      state.totpSecret!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontFamily: 'monospace',
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: state.totpSecret!));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Secret key copied')),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
          ],
          Text(
            'Enter 6-digit code',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'After scanning, enter the 6-digit code shown in your authenticator '
            'app to confirm setup.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _codeController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(letterSpacing: 8),
            decoration: const InputDecoration(
              hintText: '••••••',
              counterText: '',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: state.isLoading ? null : _verifyAndActivate,
              icon: state.isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.verified_rounded),
              label: Text(state.isLoading ? 'Verifying…' : 'Verify & Enable'),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () =>
                  ref.read(mfaNotifierProvider.notifier).cancelScan(),
              child: const Text('Cancel'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnabledView(MfaState state) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 32),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.verified_user_rounded,
              size: 40,
              color: Colors.green.shade600,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '2FA is Active',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            "Your account is protected with two-factor authentication. "
            "You'll be asked for a code each time you sign in.",
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.65),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: state.isLoading ? null : _unenroll,
              icon: const Icon(Icons.remove_circle_outline_rounded),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red.shade600,
              ),
              label: Text(state.isLoading ? 'Disabling…' : 'Disable 2FA'),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _BenefitTile — internal to MFA screen
// ---------------------------------------------------------------------------

class _BenefitTile extends StatelessWidget {
  const _BenefitTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: colorScheme.secondaryContainer,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: colorScheme.onSecondaryContainer),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
