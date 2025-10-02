import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart'; // <-- optional for Android 13+

import 'landing_page.dart';
import 'notification_service.dart'; // <-- new import

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize notifications
  await NotificationService.init();

  // (Optional) Request notification permission on Android 13+
  if (await Permission.notification.isDenied) {
    await Permission.notification.request();
  }

  runApp(const SPOTATOApp());
}

class SPOTATOApp extends StatelessWidget {
  const SPOTATOApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SPOTATO',
      theme: ThemeData(primarySwatch: Colors.green, useMaterial3: true),
      home: const LandingPage(), // This is the starting point of your app
    );
  }
}
