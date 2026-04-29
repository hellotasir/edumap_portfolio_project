import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:edumap_portfolio_project/core/services/auth/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthRepository {
  final AuthService _service = AuthService(Supabase.instance.client);

  User? get currentUser => _service.currentUser;
  Session? get currentSession => _service.currentSession;
  Stream<AuthState> get authChanges => _service.authChanges;
  bool get isAuthenticated => _service.isAuthenticated;

  Future<void> login(String email, String password) async {
    final response = await _service.signInWithPassword(
      email: email,
      password: password,
    );
    if (response.user == null) throw Exception('Login failed');
  }

  Future<void> signup(
    String email,
    String password, {
    Map<String, dynamic>? data,
  }) async {
    final response = await _service.signUp(
      email: email,
      password: password,
      data: data,
    );
    
    if (response.user == null) throw Exception('Signup failed');
  }

  

  Future<void> signInWithIdToken({
    required OAuthProvider provider,
    required String idToken,
    String? accessToken,
    String? nonce,
  }) async {
    final response = await _service.signInWithIdToken(
      provider: provider,
      idToken: idToken,
      accessToken: accessToken,
      nonce: nonce,
    );
    if (response.user == null) throw Exception('ID token sign-in failed');
  }

  Future<void> sendPasswordResetEmail(
    String email, {
    String? redirectTo,
  }) async {
    await _service.sendPasswordResetEmail(email: email, redirectTo: redirectTo);
  }

  Future<void> updatePassword(String newPassword) async {
    await _service.updatePassword(newPassword);
  }

  Future<void> updateUser({
    String? email,
    String? phone,
    String? password,
    Map<String, dynamic>? data,
  }) async {
    await _service.updateUser(
      email: email,
      phone: phone,
      password: password,
      data: data,
    );
  }

  Future<void> resendEmailVerification(String email) async {
    await _service.resendEmailVerification(email: email);
  }

  Future<void> refreshSession() async {
    final response = await _service.refreshSession();
    if (response.session == null) throw Exception('Session refresh failed');
  }

  Future<AuthSessionUrlResponse> exchangeCodeForSession(String authCode) async {
    return await _service.exchangeCodeForSession(authCode);
  }

  Future<void> setSession(String refreshToken) async {
    final response = await _service.setSession(refreshToken);
    if (response.session == null) throw Exception('Set session failed');
  }

  Future<void> logout({SignOutScope scope = SignOutScope.local}) async {
    await _service.signOut(scope: scope);
  }

  Future<void> deleteAccount(String password) async {
    final usersRef = FirebaseFirestore.instance.collection('profiles');

    final query = await usersRef
        .where('user_id', isEqualTo: currentUser?.id)
        .get();

    for (final doc in query.docs) {
      await doc.reference.delete();
    }

    final email = currentUser?.email;
    if (email == null) throw Exception('No authenticated user found');
    await login(email, password);
    await _service.deleteAccount();
  }

  Future<bool> mfaIsEnabled() async {
    final response = await _service.mfaListFactors();
    return response.totp.any((f) => f.status == FactorStatus.verified);
  }

  Future<List<Factor>> mfaListVerifiedFactors() async {
    final response = await _service.mfaListFactors();
    return response.totp
        .where((f) => f.status == FactorStatus.verified)
        .toList();
  }

  Future<AuthMFAEnrollResponse> mfaEnroll({String issuer = 'App'}) async {
    return await _service.mfaEnroll(issuer: issuer);
  }

  Future<void> mfaVerifyEnrollment({
    required String factorId,
    required String code,
  }) async {
    final challenge = await _service.mfaChallenge(factorId: factorId);
    await _service.mfaVerify(
      factorId: factorId,
      challengeId: challenge.id,
      code: code,
    );
  }

  Future<String> mfaCreateChallenge(String factorId) async {
    final response = await _service.mfaChallenge(factorId: factorId);
    return response.id;
  }

  Future<void> mfaVerifyChallenge({
    required String factorId,
    required String challengeId,
    required String code,
  }) async {
    await _service.mfaVerify(
      factorId: factorId,
      challengeId: challengeId,
      code: code,
    );
  }

  Future<void> mfaChallengeAndVerify({
    required String factorId,
    required String code,
  }) async {
    final challenge = await _service.mfaChallenge(factorId: factorId);
    await _service.mfaVerify(
      factorId: factorId,
      challengeId: challenge.id,
      code: code,
    );
  }

  Future<void> mfaUnenroll(String factorId) async {
    final response = await _service.mfaUnenroll(factorId: factorId);
    if (response.id.isEmpty) throw Exception('MFA unenroll failed');
  }

  Future<bool> mfaIsFullyAssured() async {
    final response = await _service.mfaGetAuthenticatorAssuranceLevel();
    return response.currentLevel == AuthenticatorAssuranceLevels.aal2;
  }
}
