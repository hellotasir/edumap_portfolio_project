import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_badge_plus/app_badge_plus.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const String _channelId = 'friend_requests';
  static const String _channelName = 'Friend Requests';
  static const String _channelDesc =
      'Notifications for incoming friend requests';
  static const String _badgeCountKey = 'notification_badge_count';

  Future<void> initialize() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),

      onDidReceiveBackgroundNotificationResponse: _onBackgroundNotificationTap,
    );

    await _createAndroidChannel();
    await _requestAndroidPermissions();

    FirebaseMessaging.onMessage.listen(_onForegroundFcmMessage);
  }

  Future<void> _onForegroundFcmMessage(RemoteMessage message) async {
    final prefs = await SharedPreferences.getInstance();
    final inAppEnabled = prefs.getBool('notif_in_app_enabled') ?? true;
    if (!inAppEnabled) return;

    final data = message.data;
    await showFriendRequestNotification(
      docId: data['doc_id'] ?? '',
      fromFullName: data['from_full_name'] ?? '',
      fromUsername: data['from_username'] ?? '',
      fromProfilePhoto: data['from_profile_photo'] ?? '',
    );
  }

  Future<String?> getFcmToken() async {
    try {
      return await FirebaseMessaging.instance.getToken();
    } catch (e) {
      debugPrint('[NotificationService] Failed to get FCM token: $e');
      return null;
    }
  }

  Stream<String> get onTokenRefresh =>
      FirebaseMessaging.instance.onTokenRefresh;

  Future<void> _createAndroidChannel() async {
    if (!Platform.isAndroid) return;
    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDesc,
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);
  }

  Future<void> _requestAndroidPermissions() async {
    if (!Platform.isAndroid) return;
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
  }

  Future<void> showFriendRequestNotification({
    required String docId,
    required String fromFullName,
    required String fromUsername,
    required String fromProfilePhoto,
  }) async {
    final id = docId.hashCode.abs() % 100000;

    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      largeIcon: fromProfilePhoto.isNotEmpty
          ? FilePathAndroidBitmap(fromProfilePhoto)
          : null,
      styleInformation: BigTextStyleInformation(
        '$fromUsername sent you a friend request. Tap to respond.',
        summaryText: 'Friend Request',
      ),
      ticker: 'New friend request from $fromUsername',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    await _plugin.show(
      id: id,
      title: '👋 New Friend Request',
      body: '$fromFullName (@$fromUsername) wants to connect with you.',
      notificationDetails: NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      ),
      payload: docId,
    );

    await incrementBadge();
  }

  Future<void> incrementBadge() async {
    final prefs = await SharedPreferences.getInstance();
    final next = (prefs.getInt(_badgeCountKey) ?? 0) + 1;
    await prefs.setInt(_badgeCountKey, next);
    if (await AppBadgePlus.isSupported()) {
      await AppBadgePlus.updateBadge(next);
    }
  }

  Future<void> decrementBadge() async {
    final prefs = await SharedPreferences.getInstance();
    final next = ((prefs.getInt(_badgeCountKey) ?? 0) - 1).clamp(0, 999);
    await prefs.setInt(_badgeCountKey, next);
    if (await AppBadgePlus.isSupported()) {
      await AppBadgePlus.updateBadge(next);
    }
  }

  Future<void> clearBadge() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_badgeCountKey, 0);
    if (await AppBadgePlus.isSupported()) {
      await AppBadgePlus.updateBadge(0);
    }
  }

  Future<int> getBadgeCount() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_badgeCountKey) ?? 0;
  }

  Future<void> cancelNotification(String docId) async {
    final id = docId.hashCode.abs() % 100000;
    await _plugin.cancel(id: id);
  }

  Future<void> cancelAllNotifications() async {
    await _plugin.cancelAll();
    await clearBadge();
  }
}

@pragma('vm:entry-point')
void _onBackgroundNotificationTap(NotificationResponse response) {
  debugPrint('[NotificationService] Background tap: ${response.payload}');
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await NotificationService.instance.incrementBadge();
  debugPrint('[FCM Background] ${message.data}');
}
