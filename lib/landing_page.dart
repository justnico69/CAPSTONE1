import 'dart:async'; // Required for the Timer
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'get_started.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  @override
  void initState() {
    super.initState();
    // Start a timer that will run after 5 seconds
    Timer(const Duration(seconds: 5), () {
      // Navigate using a custom PageRouteBuilder for a fade transition
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => const GetStartedPage(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            // Use FadeTransition for the animation
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 800), // Adjust fade speed
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
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
                    Image.asset(
                      'assets/images/spotato_logo.png',
                      height: 120,
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'SPOT',
                          style: GoogleFonts.poppins(
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            color: const Color.fromARGB(255, 128, 68, 12),
                          ),
                        ),
                        Text(
                          'ato',
                          style: GoogleFonts.poppins(
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