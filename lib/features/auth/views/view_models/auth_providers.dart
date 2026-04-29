import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edumap_portfolio_project/features/auth/repositories/auth_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

final authStateProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(authRepositoryProvider).authChanges;
});

final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(authStateProvider).value?.session?.user;
});

final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(authRepositoryProvider).isAuthenticated;
});

enum MfaStep { checking, intro, scan, enabled }

@immutable
class MfaState {
  const MfaState({
    this.step = MfaStep.checking,
    this.isLoading = false,
    this.factorId,
    this.totpSecret,
    this.qrSvg,
    this.factors = const [],
  });

  final MfaStep step;
  final bool isLoading;
  final String? factorId;
  final String? totpSecret;
  final String? qrSvg;
  final List<Factor> factors;

  MfaState copyWith({
    MfaStep? step,
    bool? isLoading,
    String? factorId,
    String? totpSecret,
    String? qrSvg,
    List<Factor>? factors,
  }) => MfaState(
    step: step ?? this.step,
    isLoading: isLoading ?? this.isLoading,
    factorId: factorId ?? this.factorId,
    totpSecret: totpSecret ?? this.totpSecret,
    qrSvg: qrSvg ?? this.qrSvg,
    factors: factors ?? this.factors,
  );
}

class MfaNotifier extends Notifier<MfaState> {
  @override
  MfaState build() {
    Future.microtask(_checkStatus);
    return const MfaState();
  }

  AuthRepository get _repo => ref.read(authRepositoryProvider);

  Future<void> _checkStatus() async {
    state = state.copyWith(isLoading: true);
    try {
      final factors = await _repo.mfaListVerifiedFactors();
      state = state.copyWith(
        isLoading: false,
        factors: factors,
        step: factors.isNotEmpty ? MfaStep.enabled : MfaStep.intro,
      );
    } catch (_) {
      state = state.copyWith(isLoading: false, step: MfaStep.intro);
    }
  }

  Future<void> startEnrollment() async {
    state = state.copyWith(isLoading: true);
    try {
      final response = await _repo.mfaEnroll(issuer: 'EduApp');
      state = state.copyWith(
        isLoading: false,
        factorId: response.id,
        totpSecret: response.totp?.secret,
        qrSvg: response.totp?.qrCode,
        step: MfaStep.scan,
      );
    } catch (_) {
      state = state.copyWith(isLoading: false);
      rethrow;
    }
  }

  Future<void> verifyAndActivate(String code) async {
    state = state.copyWith(isLoading: true);
    try {
      await _repo.mfaVerifyEnrollment(factorId: state.factorId!, code: code);
      state = state.copyWith(isLoading: false, step: MfaStep.enabled);
    } catch (_) {
      state = state.copyWith(isLoading: false);
      rethrow;
    }
  }

  Future<void> unenroll() async {
    state = state.copyWith(isLoading: true);
    try {
      await _repo.mfaUnenroll(state.factors.first.id);
      state = state.copyWith(
        isLoading: false,
        factors: [],
        step: MfaStep.intro,
      );
    } catch (_) {
      state = state.copyWith(isLoading: false);
      rethrow;
    }
  }

  void cancelScan() => state = state.copyWith(step: MfaStep.intro);
}

final mfaNotifierProvider = NotifierProvider.autoDispose<MfaNotifier, MfaState>(
  MfaNotifier.new,
);
