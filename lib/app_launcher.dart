// app_launcher.dart
import 'package:device_apps/device_apps.dart';
import 'package:flutter/material.dart';

class AppLauncher {
  /// Launches the app by package name if installed
  static Future<void> launch(String packageName) async {
    bool isInstalled = await DeviceApps.isAppInstalled(packageName);
    if (isInstalled) {
      await DeviceApps.openApp(packageName);
      debugPrint("✅ Launched $packageName");
    } else {
      debugPrint("❌ App $packageName is not installed.");
    }
  }
}
