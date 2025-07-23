import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'get_started.dart';

class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 241, 240, 219),
      body: Stack(
        // Use a Stack to layer widgets
        children: [
          // Your main content (logo and text)
          GestureDetector(
            onTap: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => const GetStartedPage()),
              );
            },
            child: SafeArea(
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
                              fontWeight: FontWeight.bold,
                              color: const Color.fromARGB(255, 128, 68, 12),
                            ),
                          ),
                          Text(
                            'ato',
                            style: GoogleFonts.poppins(
                              fontSize: 30,
                              fontWeight: FontWeight.bold,
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