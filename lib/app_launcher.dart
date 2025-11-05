// app_launcher.dart
import 'package:device_apps_plus/device_apps_plus.dart';
import 'package:flutter/material.dart';

class AppLauncher {
  static final DeviceAppsPlus _deviceApps = DeviceAppsPlus();

  /// Launches the app by package name if installed
  static Future<void> launch(String packageName) async {
    try {
      bool isInstalled = await _deviceApps.isAppInstalled(packageName);

      if (isInstalled) {
        await _deviceApps.openApp(packageName);
        debugPrint("✅ Launched $packageName");
      } else {
        debugPrint("❌ App $packageName is not installed.");
      }
    } catch (e) {
      debugPrint("⚠️ Error launching $packageName: $e");
    }
  }
}
