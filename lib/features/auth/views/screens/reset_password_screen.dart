// ignore_for_file: use_build_context_synchronously

import 'package:edumap_portfolio_project/features/app/views/widgets/others/network_widget.dart';
import 'package:flutter/material.dart';
import 'package:edumap_portfolio_project/features/auth/repositories/auth_repository.dart';
import 'package:edumap_portfolio_project/features/auth/views/view_models/auth_providers.dart';
import 'package:edumap_portfolio_project/features/auth/views/widgets/auth_filled_loading_button.dart';
import 'package:edumap_portfolio_project/features/auth/views/widgets/auth_form_header.dart';
import 'package:edumap_portfolio_project/features/auth/views/widgets/auth_password_form_field.dart';
import 'package:edumap_portfolio_project/features/auth/views/widgets/auth_success_view.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edumap_portfolio_project/core/routers/app_navigator.dart';

class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key});

  static void open(BuildContext context, [AuthRepository? authRepository]) {
    AppNavigator(screen: const ResetPasswordScreen()).navigate(context);
  }

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _newPasswordVisible = false;
  bool _confirmPasswordVisible = false;
  bool _passwordChanged = false;

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }


  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await ref
          .read(authRepositoryProvider)
          .updatePassword(_newPasswordController.text);
      if (mounted) setState(() => _passwordChanged = true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to change password. Please try again.'),
            backgroundColor: Colors.red.shade600,
          ),
        );
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
          title: const Text('Reset Password'),
          leading: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.chevron_left_rounded),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: _passwordChanged ? _buildSuccessView() : _buildFormView(),
          ),
        ),
      ),
    );
  }

  Widget _buildFormView() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AuthFormHeader(
            icon: Icons.lock_reset_rounded,
            title: 'Change your password',
            subtitle: 'Choose a new password for your account.',
          ),
          AuthPasswordFormField(
            controller: _newPasswordController,
            label: 'New password',
            visible: _newPasswordVisible,
            onToggle: () =>
                setState(() => _newPasswordVisible = !_newPasswordVisible),
            validator: (v) {
              if (v == null || v.isEmpty) return 'New password is required';
              if (v.length < 8) return 'Password must be at least 8 characters';
              return null;
            },
          ),
          const SizedBox(height: 16),
          AuthPasswordFormField(
            controller: _confirmPasswordController,
            label: 'Confirm new password',
            visible: _confirmPasswordVisible,
            onToggle: () => setState(
              () => _confirmPasswordVisible = !_confirmPasswordVisible,
            ),
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _changePassword(),
            validator: (v) {
              if (v == null || v.isEmpty) {
                return 'Please confirm your new password';
              }
              if (v != _newPasswordController.text) {
                return 'Passwords do not match';
              }
              return null;
            },
          ),
          const SizedBox(height: 32),
          AuthFilledLoadingButton(
            label: 'Update Password',
            loadingLabel: 'Updating…',
            isLoading: _isLoading,
            onPressed: _changePassword,
            icon: Icons.lock_outline_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessView() => AuthSuccessView(
    icon: Icons.lock_open_rounded,
    title: 'Password updated',
    body: 'Your password has been changed successfully.',
    buttonLabel: 'Back to Settings',
    onPressed: () => Navigator.pop(context),
  );
}
