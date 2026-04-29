import 'package:edumap_portfolio_project/features/chat/models/friend_request_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FriendRequestNotificationService {
  FriendRequestNotificationService._();
  static final FriendRequestNotificationService instance =
      FriendRequestNotificationService._();

  Future<void> notify(FriendRequestModel request) async {
    if (request.id == null) return;

    try {
      await Supabase.instance.client.functions.invoke(
        'send-friend-request-notification',
        body: {
          'doc_id': request.id,
          'from_user_id': request.fromUserId,
          'from_username': request.fromUsername,
          'from_full_name': request.fromFullName,
          'from_profile_photo': request.fromProfilePhoto,
          'to_user_id': request.toUserId,
        },
      );
    } catch (_) {}
  }
}
