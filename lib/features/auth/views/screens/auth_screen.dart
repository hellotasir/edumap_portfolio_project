// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:edumap_portfolio_project/core/routers/app_navigator.dart';
import 'package:edumap_portfolio_project/core/services/local/fcm_token_service.dart';
import 'package:edumap_portfolio_project/core/services/notification/firestore_listener_service.dart';
import 'package:edumap_portfolio_project/features/auth/views/view_models/auth_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edumap_portfolio_project/features/app/views/screens/home_screen.dart';
import 'package:edumap_portfolio_project/features/auth/views/screens/login_screen.dart';
import 'package:edumap_portfolio_project/features/app/views/screens/error_screen.dart';
import 'package:edumap_portfolio_project/core/widgets/loading_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  String? _lastUserId;

  Future<void> _syncServices(AuthState authState) async {
    final userId = authState.session?.user.id;

    if (userId == _lastUserId) return;

    if (_lastUserId != null) {
      final oldId = _lastUserId!;
      _lastUserId = null;

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('background_service_user_id');

      FirestoreListenerService.instance.stopListening();
      await FcmTokenService.instance.removeToken(oldId);
    }

    if (userId != null) {
      _lastUserId = userId;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('background_service_user_id', userId);

      FirestoreListenerService.instance.startListening(userId);
      await FcmTokenService.instance.saveToken(userId);
    }
}

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<AuthState>>(authStateProvider, (_, next) {
      next.whenData(_syncServices);
    });

    final authState = ref.watch(authStateProvider);

    return authState.when(
      loading: () => const Scaffold(body: Center(child: LoadingIndicator())),
      error: (err, _) => ErrorScreen(
        errorType: ErrorType.server,
        message: err.toString(),
        onRetry: () =>
            AppNavigator(screen: const AuthScreen()).navigate(context),
      ),
      data: (state) {
        if (state.session != null) return const HomeScreen();
        return const LoginScreen();
      },
    );
  }
}