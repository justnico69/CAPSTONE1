import 'dart:async'; // Required for Future.delayed

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart'; // <-- ADDED

import 'get_started.dart';
import 'home_page.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  @override
  void initState() {
    super.initState();
    // Replaced the old Timer with this new check
    _checkIfFirstTime();
  }

  /// Checks SharedPreferences to see if the user has already seen the
  /// GetStartedPage.
  Future<void> _checkIfFirstTime() async {
    // 1. Get the SharedPreferences instance
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    // 2. Read the flag. If it doesn't exist, '?? false' makes it false.
    final bool hasSeenOnboarding = prefs.getBool('hasSeenOnboarding') ?? false;

    // 3. We still want the splash screen to show for a bit.
    //    Let's wait 3 seconds before navigating.
    await Future.delayed(const Duration(seconds: 3));

    // 4. Safety check: make sure the widget is still on screen
    if (!mounted) return;

    // 5. Navigate to the correct page
    if (hasSeenOnboarding) {
      // Not the first time: Go directly to HomePage
      _navigateTo(const HomePage());
    } else {
      // This IS the first time: Go to GetStartedPage
      _navigateTo(const GetStartedPage());
    }
  }

  /// Reusable navigation function to preserve your fade transition
  void _navigateTo(Widget page) {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        // The 'page' argument determines the destination
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          // Use FadeTransition for the animation
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(
          milliseconds: 800,
        ), // Your original speed
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // This entire build method is unchanged.
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 255, 255, 255),
      body: Stack(
        children: [
          // Main content area (no GestureDetector needed anymore)
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Image.asset('assets/images/spotato_logo.png', height: 120),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'SPOT',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            color: const Color.fromARGB(255, 128, 68, 12),
                          ),
                        ),
                        Text(
                          'ato',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            color: const Color.fromARGB(255, 236, 185, 74),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // The bottom brown wave image
          Positioned(
            bottom: -60,
            left: -30,
            right: -30,
            child: Image.asset(
              'assets/images/bottom_wave.png', // The new image asset
              fit: BoxFit.cover, // Ensures it stretches across the screen
            ),
          ),
        ],
      ),
    );
  }
}
