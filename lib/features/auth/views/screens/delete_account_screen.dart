// ignore_for_file: use_build_context_synchronously

import 'package:edumap_portfolio_project/features/app/views/widgets/others/network_widget.dart';
import 'package:flutter/material.dart';
import 'package:edumap_portfolio_project/features/app/repositories/delete_user_data_repository.dart';
import 'package:edumap_portfolio_project/features/auth/repositories/auth_repository.dart';
import 'package:edumap_portfolio_project/features/auth/views/view_models/auth_providers.dart';
import 'package:edumap_portfolio_project/features/auth/views/widgets/auth_filled_loading_button.dart';
import 'package:edumap_portfolio_project/features/auth/views/widgets/auth_password_form_field.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edumap_portfolio_project/core/routers/app_navigator.dart';
import 'package:edumap_portfolio_project/core/widgets/snackbar_widget.dart';
import 'package:edumap_portfolio_project/features/auth/views/screens/login_screen.dart';

enum _DeleteStep { confirm, deleted }

class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key});

  static void open(BuildContext context, AuthRepository authRepository) {
    AppNavigator(screen: const DeleteAccountScreen()).navigate(context);
  }

  @override
  ConsumerState<DeleteAccountScreen> createState() =>
      _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen>
    with SingleTickerProviderStateMixin {
  _DeleteStep _step = _DeleteStep.confirm;
  bool _isLoading = false;
  bool _passwordVisible = false;
  bool _checkedUnderstood = false;

  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  late final AnimationController _animController;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
        );
  }

  @override
  void dispose() {
    _animController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    if (!mounted) return;
    SnackbarWidget(message: message).showSnackbar(context);
  }

  Future<bool?> _showFinalConfirmDialog() => showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      icon: Icon(
        Icons.warning_amber_rounded,
        color: Colors.red.shade600,
        size: 40,
      ),
      title: const Text('Final confirmation'),
      content: const Text(
        'This will permanently delete your account and all associated data. '
        'This cannot be undone.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.red.shade600),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Delete my account'),
        ),
      ],
    ),
  );

  Future<void> _submitDeletionRequest() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_checkedUnderstood) {
      _showError(
        'Please confirm that you understand this action is irreversible.',
      );
      return;
    }

    final confirmed = await _showFinalConfirmDialog();
    if (confirmed != true || !mounted) return;

    setState(() => _isLoading = true);

    try {
      final authRepo = ref.read(authRepositoryProvider);

      final currentUser = authRepo.currentUser;
      if (currentUser == null) {
        _showError('No authenticated user found. Please log in again.');
        return;
      }

      final userId = currentUser.id;

      final deleteRepo = DeleteRepository();
      await deleteRepo.deleteAllUserData(
        userId,
        currentUser.email ?? '',
        strict: true,
        showLogs: true,
      );

      await authRepo.deleteAccount(_passwordController.text.trim());

      try {
        await authRepo.logout();
      } catch (_) {}

      if (mounted) {
        setState(() => _step = _DeleteStep.deleted);
        await Future.delayed(const Duration(milliseconds: 800));
        if (mounted) {
          AppNavigator(screen: const LoginScreen()).navigate(context);
        }
      }
    } on DeleteRepositoryException catch (e) {
      if (mounted) {
        _showError(
          'Some data could not be deleted:\n${e.errors.keys.join(', ')}\n'
          'Please contact support.',
        );
      }
    } on Exception catch (e) {
      if (mounted) {
        _showError('Account deletion failed: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return NetworkWidget(
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Delete Account'),
            leading: IconButton(
              onPressed: _isLoading ? null : () => Navigator.pop(context),
              icon: const Icon(Icons.chevron_left_rounded),
            ),
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: switch (_step) {
                    _DeleteStep.confirm => _buildConfirmView(),
                    _DeleteStep.deleted => _buildDeletedView(),
                  },
                ),
              ),
            ),
          ),
        ),
      );
  }

  Widget _buildConfirmView() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          _WarningBanner(theme: theme),
          const SizedBox(height: 28),
          Text(
            'Confirm your password',
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            'Enter your current password to verify your identity before '
            'deleting your account.',
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 16),
          AuthPasswordFormField(
            controller: _passwordController,
            label: 'Current password',
            visible: _passwordVisible,
            onToggle: () =>
                setState(() => _passwordVisible = !_passwordVisible),
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) =>
                _isLoading ? null : _submitDeletionRequest(),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Password is required';
              if (v.trim().length < 6) {
                return 'Password must be at least 6 characters';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),
          InkWell(
            onTap: _isLoading
                ? null
                : () =>
                      setState(() => _checkedUnderstood = !_checkedUnderstood),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(
                    value: _checkedUnderstood,
                    activeColor: Colors.red.shade600,
                    onChanged: _isLoading
                        ? null
                        : (v) =>
                              setState(() => _checkedUnderstood = v ?? false),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        'I understand that deleting my account is permanent '
                        'and cannot be undone.',
                        style: textTheme.bodyMedium,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          AuthFilledLoadingButton(
            label: 'Delete My Account',
            loadingLabel: 'Deleting…',
            isLoading: _isLoading,
            onPressed: _submitDeletionRequest,
            icon: Icons.delete_forever_rounded,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              minimumSize: const Size(double.infinity, 50),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton(
              onPressed: _isLoading ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildDeletedView() {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 56),
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.delete_forever_rounded,
            size: 44,
            color: Colors.red.shade600,
          ),
        ),
        const SizedBox(height: 28),
        Text(
          'Account Deleted',
          style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          'Your account and all associated data have been permanently deleted. '
          'You have been signed out of all devices.',
          style: textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 52),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: FilledButton(
            onPressed: () =>
                AppNavigator(screen: const LoginScreen()).navigate(context),
            child: const Text('Go to Login'),
          ),
        ),
      ],
    );
  }
}

class _WarningBanner extends StatelessWidget {
  const _WarningBanner({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.red.shade600),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'This action is permanent',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: Colors.red.shade700,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Deleting your account will permanently remove all your data, '
                  'progress, and subscriptions.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.red.shade700,
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
