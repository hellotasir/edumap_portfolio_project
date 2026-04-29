// ignore_for_file: use_build_context_synchronously

import 'package:edumap_portfolio_project/features/app/views/widgets/others/network_widget.dart';
import 'package:flutter/material.dart';
import 'package:edumap_portfolio_project/core/routers/app_navigator.dart';
import 'package:edumap_portfolio_project/features/auth/views/screens/login_screen.dart';
import 'package:edumap_portfolio_project/features/auth/views/view_models/auth_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edumap_portfolio_project/core/widgets/snackbar_widget.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _loading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  late final AnimationController _animController;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
        );
  }

  @override
  void dispose() {
    _animController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _showSnackbar(String message) =>
      SnackbarWidget(message: message).showSnackbar(context);

  Future<void> _signup() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirm = _confirmPasswordController.text.trim();

    if (email.isEmpty || password.isEmpty || confirm.isEmpty) {
      _showSnackbar('Please fill in all fields');
      return;
    }
    if (password != confirm) {
      _showSnackbar('Passwords do not match');
      return;
    }

    setState(() => _loading = true);
    try {
      await ref.read(authRepositoryProvider).signup(email, password);
      if (mounted) {
        AppNavigator(screen: LoginScreen()).navigate(context);
      }
    } catch (e) {
      if (mounted) _showSnackbar(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required bool obscure,
    required VoidCallback onToggle,
    required TextInputAction textInputAction,
    VoidCallback? onSubmitted,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted != null ? (_) => onSubmitted() : null,
      decoration: InputDecoration(
        hintText: '••••••••',
        suffixIcon: IconButton(
          icon: Icon(
            obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
          ),
          onPressed: onToggle,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return NetworkWidget(
      child: Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 60),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(Icons.arrow_back, size: 26),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'Create\naccount.',
                      style: textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                        letterSpacing: -1.2,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Start your learning journey today.',
                      style: textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 48),
                    Text('Email', style: textTheme.labelMedium),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        hintText: 'you@example.com',
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text('Password', style: textTheme.labelMedium),
                    const SizedBox(height: 8),
                    _buildPasswordField(
                      controller: _passwordController,
                      obscure: _obscurePassword,
                      textInputAction: TextInputAction.next,
                      onToggle: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    const SizedBox(height: 20),
                    Text('Confirm Password', style: textTheme.labelMedium),
                    const SizedBox(height: 8),
                    _buildPasswordField(
                      controller: _confirmPasswordController,
                      obscure: _obscureConfirm,
                      textInputAction: TextInputAction.done,
                      onToggle: () =>
                          setState(() => _obscureConfirm = !_obscureConfirm),
                      onSubmitted: _loading ? null : _signup,
                    ),
                    const SizedBox(height: 36),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _signup,
                        child: _loading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                ),
                              )
                            : const Text('Create Account'),
                      ),
                    ),
                    const SizedBox(height: 40),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Already have an account? ',
                          style: textTheme.bodyMedium,
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Sign In'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
