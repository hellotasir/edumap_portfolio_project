import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:edumap_portfolio_project/features/chat/models/friend_request_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'notification_service.dart';

class FirestoreListenerService {
  FirestoreListenerService._();
  static final FirestoreListenerService instance = FirestoreListenerService._();

  StreamSubscription<QuerySnapshot>? _subscription;
  static const String _seenIdsKey = 'seen_friend_request_ids';
  static const String _inAppKey = 'notif_in_app_enabled';

  void startListening(String myUserId) {
    if (_subscription != null) return;

    _subscription = FirebaseFirestore.instance
        .collection('friend_requests')
        .where('to_user_id', isEqualTo: myUserId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen(
          _onSnapshot,
          onError: (e) => debugPrint('[Firestore] Error: $e'),
        );
  }

  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
  }

  Future<void> _onSnapshot(QuerySnapshot snapshot) async {
    final prefs = await SharedPreferences.getInstance();

    final inAppEnabled = prefs.getBool(_inAppKey) ?? true;
    if (!inAppEnabled) return;

    final seenIds = (prefs.getStringList(_seenIdsKey) ?? []).toSet();
    bool changed = false;

    for (final change in snapshot.docChanges) {
      if (change.type != DocumentChangeType.added) continue;

      final req = FriendRequestModel.fromSnapshot(
        change.doc as DocumentSnapshot<Map<String, dynamic>>,
      );

      if (seenIds.contains(req.id)) continue;

      await NotificationService.instance.showFriendRequestNotification(
        docId: req.id ?? '',
        fromFullName: req.fromFullName,
        fromUsername: req.fromUsername,
        fromProfilePhoto: req.fromProfilePhoto,
      );

      seenIds.add(req.id ?? '');
      changed = true;
    }

    if (changed) {
      await prefs.setStringList(_seenIdsKey, seenIds.toList());
    }
  }
}
