// lib/notification_service.dart
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

// ... (your const AndroidNotificationChannel 'channel' code is correct) ...
const AndroidNotificationChannel channel = AndroidNotificationChannel(
  'spotato_channel', // id
  'SPOTATO Notifications', // name
  description: 'Notifications for SPOTATO analysis updates', // description
  importance: Importance.max,
  playSound: true,
  enableVibration: true,
);

class NotificationService {
  static final _notifications = FlutterLocalNotificationsPlugin();

  // 🔹 --- THIS FUNCTION IS UPDATED --- 🔹
  static Future<void> init() async {
    // 🔹 --- THIS IS THE FIX --- 🔹
    // Instead of the default '@mipmap/ic_launcher', we will use the
    // notification icon that we know exists in the 'drawable' folder.
    const androidInit = AndroidInitializationSettings(
      '@drawable/ic_stat_spotato',
    );
    // 🔹 --- END OF FIX --- 🔹

    const initSettings = InitializationSettings(android: androidInit);

    try {
      await _notifications.initialize(initSettings);
    } catch (e) {
      debugPrint("!!! FAILED to initialize notifications: $e");
    }

    // This tells Android to register our channel.
    final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);
  }

  // This is the function that main.dart calls
  static Future<void> requestPermission() async {
    final status = await Permission.notification.request();
    if (status.isDenied) {
      debugPrint("⚠️ Notification permission denied by user.");
    } else {
      debugPrint("✅ Notification permission granted.");
    }
  }

  static Future<void> show({
    required String title,
    required String body,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      channel.id,
      channel.name,
      channelDescription: channel.description,
      importance: channel.importance,
      priority: Priority.high,
      playSound: channel.playSound,
      enableVibration: channel.enableVibration,
      icon: 'ic_stat_spotato', // This is the small icon in the status bar
    );

    final details = NotificationDetails(android: androidDetails);

    await _notifications.show(
      0, // Notification ID
      title,
      body,
      details,
    );
  }
}
