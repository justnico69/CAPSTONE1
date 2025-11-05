// lib/notification.dart
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

class NotificationService {
  static final _notifications = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    // Android initialization
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);

    await _notifications.initialize(initSettings);

    // ✅ Ask for notification permission (Android 13+)
    final status = await Permission.notification.request();
    if (status.isDenied) {
      print("⚠️ Notification permission denied by user.");
    } else {
      print("✅ Notification permission granted.");
    }
  }

  static Future<void> show({
    required String title,
    required String body,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'spotato_channel', // Channel ID
      'SPOTATO Notifications', // Channel name
      channelDescription: 'Notifications for SPOTATO analysis updates',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );

    const details = NotificationDetails(android: androidDetails);

    await _notifications.show(
      0, // Notification ID
      title,
      body,
      details,
    );
  }
}
