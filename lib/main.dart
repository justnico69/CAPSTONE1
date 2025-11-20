import 'package:flutter/material.dart';
import 'package:spotato/config.dart';
import 'package:spotato/landing_page.dart';
import 'package:spotato/notification_service.dart';

/// Global color used throughout the SPOTATO application.
/// Adjust this to match your visual theme.
const Color kDarkBrown = Color.fromARGB(255, 128, 68, 12);

/// Entry point of the SPOTATO app.
///
/// Performs essential asynchronous initialization before
/// the UI renders, including:
/// - Ensuring Flutter binding is initialized
/// - Initializing notifications
/// - Loading the TFLite model
void main() async {
  /// Ensures Flutter's engine and plugin services are ready.
  WidgetsFlutterBinding.ensureInitialized();

  /// Initializes notification channels at startup.
  debugPrint("--- [MAIN] Initializing Notifications...");
  await NotificationService.init();

  /// Loads the global TFLite model used across the app.
  debugPrint("--- [MAIN] Loading TFLite Model...");
  await loadGlobalModel();

  debugPrint("--- [MAIN] All init complete. Running app.");

  /// Launches the root widget.
  runApp(const SPOTATOApp());
}

/// Root widget of the SPOTATO application.
///
/// Defines:
/// - Global app theme
/// - App title
/// - Starting screen (LandingPage)
class SPOTATOApp extends StatelessWidget {
  const SPOTATOApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      /// Title used in task manager and Android app switcher.
      title: 'SPOTATO',

      /// Removes the debug banner in debug mode.
      debugShowCheckedModeBanner: false,

      /// Defines the global theme of the application.
      theme: ThemeData(
        primaryColor: kDarkBrown,
        fontFamily: 'Poppins',
        useMaterial3: true,
      ),

      /// Starting point of the app after initialization.
      home: const LandingPage(),
    );
  }
}
