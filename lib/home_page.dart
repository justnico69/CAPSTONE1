import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'detector_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    // Get screen dimensions for responsive layout
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: const Color.fromARGB(243, 248, 248, 248),
      body: Column(
        children: [
          ClipRRect(
            // This creates the rounded bottom corners
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(70), // Adjust radius as needed
              bottomRight: Radius.circular(70), // Adjust radius as needed
            ),
            child: Container(
              height: screenHeight * 0.2,
              color: Colors.white,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(30, 0, 30, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Image.asset(
                            'assets/images/spotato_logo.png',
                            height: screenHeight * 0.05,
                          ),
                          const SizedBox(width: 10),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              RichText(
                                text: TextSpan(
                                  style: GoogleFonts.poppins(
                                    fontSize: 25,
                                    fontWeight: FontWeight.w800,
                                  ),
                                  children: const <TextSpan>[
                                    TextSpan(
                                      text: 'SPOT',
                                      style: TextStyle(color: Color.fromARGB(255, 128, 68, 12)),
                                    ),
                                    TextSpan(
                                      text: 'ato',
                                      style: TextStyle(color: Color.fromARGB(255, 236, 185, 74)),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                "at your service!",
                                style: GoogleFonts.poppins(
                                  color: const Color.fromARGB(255, 160, 98, 45),
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.notifications,
                            color: Color.fromARGB(255, 128, 68, 12), size: 28),
                        onPressed: () {},
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Main body content (no changes here)
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.shield_outlined,
                    size: screenWidth * 0.25,
                    color: const Color.fromARGB(255, 128, 68, 12),
                  ),
                  SizedBox(height: screenHeight * 0.025),
                  Text(
                    'Welcome to SPOTATO',
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: const Color.fromARGB(255, 128, 68, 12),
                    ),
                  ),
                  SizedBox(height: screenHeight * 0.05),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Open Disease Detector'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                      textStyle: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const DetectorPage()),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- CHANGE #2: The HeaderClipper class is no longer needed and can be deleted. ---