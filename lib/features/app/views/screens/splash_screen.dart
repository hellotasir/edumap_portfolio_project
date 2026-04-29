// ignore_for_file: unrelated_type_equality_checks

import 'package:flutter/material.dart';
import 'package:edumap_portfolio_project/core/consts/messages.dart';
import 'package:edumap_portfolio_project/features/auth/views/screens/auth_screen.dart';
import 'package:edumap_portfolio_project/core/routers/app_navigator.dart';
import 'package:edumap_portfolio_project/core/widgets/snackbar_widget.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigate();
  }

  Future<void> _navigate() async {
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    try {
      AppNavigator(screen: AuthScreen()).navigate(context);
    } catch (e) {
      SnackbarWidget(message: errorMessage).showSnackbar(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness != Brightness.dark;
    return Scaffold(
      body: Center(
        child: Image.asset(
          isDark
              ? 'assets/edumap-transparent-icon.png'
              : 'assets/edumap-black-transparent-icon.png',
          height: 200,
        ),
      ),
    );
  }
}
