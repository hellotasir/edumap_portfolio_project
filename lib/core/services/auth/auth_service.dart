import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _client = Supabase.instance.client;

  User? get currentUser => _client.auth.currentUser;
  Session? get currentSession => _client.auth.currentSession;
  Stream<AuthState> get authChanges => _client.auth.onAuthStateChange;
  bool get isAuthenticated => currentUser != null;

  Future<AuthResponse> signInWithPassword({
    required String email,
    required String password,
  }) async {
    return await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    Map<String, dynamic>? data,
    String? emailRedirectTo,
  }) async {
    return await _client.auth.signUp(
      email: email,
      password: password,
      data: data,
      emailRedirectTo: emailRedirectTo,
    );
  }

  Future<UserResponse> updatePassword(String newPassword) async {
    return await _client.auth.updateUser(UserAttributes(password: newPassword));
  }

  Future<AuthResponse> signInWithIdToken({
    required OAuthProvider provider,
    required String idToken,
    String? accessToken,
    String? nonce,
  }) async {
    return await _client.auth.signInWithIdToken(
      provider: provider,
      idToken: idToken,
      accessToken: accessToken,
      nonce: nonce,
    );
  }

  Future<void> sendPasswordResetEmail({
    required String email,
    String? redirectTo,
  }) async {
    await _client.auth.resetPasswordForEmail(email, redirectTo: redirectTo);
  }

  Future<UserResponse> updateUser({
    String? email,
    String? phone,
    String? password,
    Map<String, dynamic>? data,
  }) async {
    return await _client.auth.updateUser(
      UserAttributes(
        email: email,
        phone: phone,
        password: password,
        data: data,
      ),
    );
  }

  Future<ResendResponse> resendEmailVerification({
    required String email,
  }) async {
    return await _client.auth.resend(type: OtpType.signup, email: email);
  }

  Future<AuthResponse> refreshSession() async {
    return await _client.auth.refreshSession();
  }

  Future<AuthSessionUrlResponse> exchangeCodeForSession(String authCode) async {
    return await _client.auth.exchangeCodeForSession(authCode);
  }

  Future<AuthResponse> setSession(String refreshToken) async {
    return await _client.auth.setSession(refreshToken);
  }

  Future<void> signOut({SignOutScope scope = SignOutScope.local}) async {
    await _client.auth.signOut(scope: scope);
  }

  Future<AuthMFAListFactorsResponse> mfaListFactors() async {
    return await _client.auth.mfa.listFactors();
  }

  Future<AuthMFAEnrollResponse> mfaEnroll({
    required String issuer,
    FactorType factorType = FactorType.totp,
  }) async {
    return await _client.auth.mfa.enroll(
      issuer: issuer,
      factorType: factorType,
    );
  }

  Future<AuthMFAChallengeResponse> mfaChallenge({
    required String factorId,
  }) async {
    return await _client.auth.mfa.challenge(factorId: factorId);
  }

  Future<AuthMFAVerifyResponse> mfaVerify({
    required String factorId,
    required String challengeId,
    required String code,
  }) async {
    return await _client.auth.mfa.verify(
      factorId: factorId,
      challengeId: challengeId,
      code: code,
    );
  }

  Future<AuthMFAUnenrollResponse> mfaUnenroll({
    required String factorId,
  }) async {
    return await _client.auth.mfa.unenroll(factorId);
  }

  Future<AuthMFAGetAuthenticatorAssuranceLevelResponse>
  mfaGetAuthenticatorAssuranceLevel() async {
    return _client.auth.mfa.getAuthenticatorAssuranceLevel();
  }

  Future<void> deleteAccount() async {
    if (_client.auth.currentSession == null) {
      throw Exception('No active session');
    }

    final response = await _client.functions.invoke('delete-user');

    if (response.status != 200) {
      throw Exception(
        'Account deletion failed (${response.status}): ${response.data}',
      );
    }

    try {
      await _client.auth.signOut(scope: SignOutScope.local);
    } catch (_) {}
  }
}
