import 'package:flutter/material.dart';
import 'package:spotato/config.dart'; // 👈 Import config
import 'package:spotato/landing_page.dart'; // 👈 Your app's landing page
import 'package:spotato/notification_service.dart'; // 👈 Import notification service

// 🔹 --- NEW: ADD YOUR GLOBAL COLORS --- 🔹
const Color kDarkBrown = Color.fromARGB(255, 128, 68, 12);
// (Add kOrange if you use it in your theme)

void main() async {
  // 🔹 --- THIS IS THE NEW SETUP --- 🔹
  // 1. Ensure Flutter is ready before running async code
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Run one-time initializations (this happens during splash screen)
  debugPrint("--- [MAIN] Initializing Notifications...");
  await NotificationService.init(); // Creates the channel

  debugPrint("--- [MAIN] Loading TFLite Model...");
  await loadGlobalModel(); // Loads the model

  debugPrint("--- [MAIN] All init complete. Running app.");
  // 3. Run your app (this line is from your old file)
  runApp(const SPOTATOApp());
  // 🔹 --- END OF NEW SETUP --- 🔹
}

class SPOTATOApp extends StatelessWidget {
  const SPOTATOApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SPOTATO',
      debugShowCheckedModeBanner: false, // 👈 Added this to hide the banner
      // 🔹 --- MODIFIED THEME --- 🔹
      theme: ThemeData(
        primaryColor: kDarkBrown, // Use your app's color
        fontFamily: 'Poppins', // Use your local Poppins font
        useMaterial3: true,
      ),

      // 🔹 --- END OF MODIFICATION --- 🔹
      home: const LandingPage(), // This is the starting point of the app
    );
  }
}
