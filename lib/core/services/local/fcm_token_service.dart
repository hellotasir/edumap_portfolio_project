import 'package:supabase_flutter/supabase_flutter.dart';
import '../notification/notification_service.dart';

class FcmTokenService {
  FcmTokenService._();
  static final FcmTokenService instance = FcmTokenService._();

  static const _table = 'user_fcm_tokens';

  SupabaseClient get _client => Supabase.instance.client;

  Future<void> saveToken(String userId) async {
    if (userId.trim().isEmpty) return;

    final token = await NotificationService.instance.getFcmToken();
    if (token == null) return;

    await _upsertToken(userId, token);

    NotificationService.instance.onTokenRefresh.listen((refreshedToken) async {
      if (refreshedToken.trim().isEmpty) return;
      await _upsertToken(userId, refreshedToken);
    });
  }

  Future<void> removeToken(String userId) async {
    if (userId.trim().isEmpty) return;

    await _client.from(_table).delete().eq('user_id', userId);
  }

  Future<void> _upsertToken(String userId, String token) async {
    await _client.from(_table).upsert({
      'user_id': userId,
      'fcm_token': token,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'user_id');
  }
}