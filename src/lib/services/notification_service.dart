import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Handles both FCM push notifications and local foreground notifications.
/// Call [NotificationService.init] once at app startup.
class NotificationService {
  NotificationService._();

  static final _fcm   = FirebaseMessaging.instance;
  static final _local = FlutterLocalNotificationsPlugin();

  static const _channelId   = 'sg_alerts';
  static const _channelName = 'SmartGuardian Alerts';

  // ── Initialise ─────────────────────────────────────────────────────────────
  static Future<void> init() async {
    // 1. Request permission
    await _fcm.requestPermission(alert: true, badge: true, sound: true);

    // 2. Configure local notifications
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios     = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _local.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );

    // 3. Create Android notification channel
    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: 'Health and safety alerts from SmartGuardian',
      importance: Importance.max,
    );
    await _local
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // 4. Save FCM token to Firestore so the guardian's device can be targeted
    await _saveFcmToken();

    // 5. Handle foreground FCM messages → show local notification
    FirebaseMessaging.onMessage.listen((msg) {
      final n = msg.notification;
      if (n != null) showLocal(n.title ?? 'Alert', n.body ?? '');
    });

    // 6. Refresh token listener
    _fcm.onTokenRefresh.listen((_) => _saveFcmToken());
  }

  // ── Save FCM token ──────────────────────────────────────────────────────────
  static Future<void> _saveFcmToken() async {
    final uid   = FirebaseAuth.instance.currentUser?.uid;
    final token = await _fcm.getToken();
    if (uid == null || token == null) return;
    await FirebaseFirestore.instance
        .collection('guardians')
        .doc(uid)
        .set({'fcmToken': token, 'updatedAt': FieldValue.serverTimestamp()},
            SetOptions(merge: true));
  }

  // ── Show a local notification ───────────────────────────────────────────────
  static Future<void> showLocal(String title, String body) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId, _channelName,
        importance: Importance.max,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
    await _local.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title, body, details,
    );
  }

  // ── Convenience: alert helpers ──────────────────────────────────────────────
  static Future<void> notifyFall(String name) =>
      showLocal('🚨 Fall Detected', '$name may have fallen — check immediately');

  static Future<void> notifyGeofence(String name) =>
      showLocal('📍 Geofence Alert', '$name has left the safe zone');

  static Future<void> notifyHeartRate(String name, int hr) =>
      showLocal('❤️ Heart Rate Alert',
          '$name\'s heart rate is $hr bpm — outside normal range');

  static Future<void> notifyTemperature(String name, double temp) =>
      showLocal('🌡️ Temperature Alert',
          '$name\'s temperature is ${temp.toStringAsFixed(1)}°C');
}
