// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_education_app/features/auth/repositories/auth_repository.dart';
import 'package:flutter_education_app/features/auth/views/view_models/auth_providers.dart';
import 'package:flutter_education_app/features/auth/views/widgets/auth_filled_loading_button.dart';
import 'package:flutter_education_app/features/auth/views/widgets/auth_form_header.dart';
import 'package:flutter_education_app/features/auth/views/widgets/auth_success_view.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_education_app/core/routers/app_navigator.dart';
import 'package:flutter_education_app/core/widgets/material_widget.dart';
import 'package:flutter_education_app/core/widgets/snackbar_widget.dart';
import 'package:flutter_education_app/features/app/views/widgets/others/mfa_widget.dart';

class UpdateEmailScreen extends ConsumerStatefulWidget {
  const UpdateEmailScreen({super.key});

  static void open(BuildContext context, AuthRepository authRepository) {
    AppNavigator(screen: const UpdateEmailScreen()).navigate(context);
  }

  @override
  ConsumerState<UpdateEmailScreen> createState() => _UpdateEmailScreenState();
}

class _UpdateEmailScreenState extends ConsumerState<UpdateEmailScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  bool _isLoading = false;
  bool _emailUpdated = false;

  late final String _currentEmail;

  @override
  void initState() {
    super.initState();
    _currentEmail = ref.read(currentUserProvider)?.email ?? '';
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }


  Future<void> _updateEmail() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await ref
          .read(authRepositoryProvider)
          .updateUser(email: _emailController.text.trim());
      if (mounted) setState(() => _emailUpdated = true);
    } catch (_) {
      if (mounted) {
        SnackbarWidget(
          message: 'Failed to update email. Please try again.',
        ).showSnackbar(context);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    return MaterialWidget(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Update Email'),
          leading: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.chevron_left_rounded),
          ),
        ),
        body: MfaWidget(
          authRepository: ref.read(authRepositoryProvider),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: _emailUpdated ? _buildSuccessView() : _buildFormView(),
            ),
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
            icon: Icons.email_outlined,
            title: 'Change your email',
            subtitle: 'A confirmation link will be sent to your new address.',
          ),
          TextFormField(
            initialValue: _currentEmail,
            readOnly: true,
            decoration: const InputDecoration(
              labelText: 'Current email',
              prefixIcon: Icon(Icons.email_outlined),
              border: OutlineInputBorder(),
              filled: true,
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _updateEmail(),
            decoration: const InputDecoration(
              labelText: 'New email address',
              prefixIcon: Icon(Icons.alternate_email_rounded),
              border: OutlineInputBorder(),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return 'New email is required';
              }
              if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v.trim())) {
                return 'Enter a valid email address';
              }
              if (v.trim() == _currentEmail) {
                return 'New email must be different from your current email';
              }
              return null;
            },
          ),
          const SizedBox(height: 32),
          AuthFilledLoadingButton(
            label: 'Update Email',
            loadingLabel: 'Updating…',
            isLoading: _isLoading,
            onPressed: _updateEmail,
            icon: Icons.email_outlined,
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessView() => AuthSuccessView(
    icon: Icons.mark_email_read_outlined,
    title: 'Confirmation sent',
    body:
        'Check your new inbox and click the confirmation link to complete the change.',
    buttonLabel: 'Back to Settings',
    onPressed: () => Navigator.pop(context),
  );
}
