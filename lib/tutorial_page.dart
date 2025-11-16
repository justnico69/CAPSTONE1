import 'package:flutter/material.dart';

const Color kDarkBrown = Color.fromARGB(255, 128, 68, 12);
const Color kOrange = Color(0xFFEAA944);

class TutorialPage extends StatelessWidget {
  const TutorialPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(243, 248, 248, 248),
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text(
          "SPOTato Manual",
          style: TextStyle(
            fontFamily: 'Poppins',
            color: kDarkBrown,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: kDarkBrown),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(
          children: [
            // --- WELCOME SECTION ---
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Image.asset(
                  'assets/images/spotato_logo.png',
                  width: 36,
                  height: 36,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Welcome to SPOTato",
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: kDarkBrown,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "This is a quick setup guide to help you understand how to use SPOTato. Follow these quick steps to get started:",
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 15,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 25),

            // --- 🔹 NEW STEP 1 🔹 ---
            _buildStep(
              icon: Icons.wifi, // Icon for Wi-Fi/Connection
              title: "1. Prepare Your Drone",
              description: TextSpan(
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  color: Colors.grey[700],
                  height: 1.5,
                ),
                children: [
                  const TextSpan(text: "Turn on your "),
                  // This is the highlighted part
                  TextSpan(
                    text: " 'Tello drone' ",
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  const TextSpan(
                    text:
                        " and connect your phone to its Wi-Fi hotspot before proceeding.",
                  ),
                ],
              ),
            ),

            // --- STEP 2 (Old Step 1) ---
            _buildStep(
              icon: Icons.search,
              title: "2. Detect Disease", // Renumbered
              description: TextSpan(
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  color: Colors.grey[700],
                  height: 1.4,
                ),
                children: [
                  const TextSpan(text: "Tap "),
                  TextSpan(
                    text: "'Detect Disease'",
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  const TextSpan(
                    text:
                        " on the Home screen to begin scanning potato leaves.",
                  ),
                ],
              ),
            ),

            // --- STEP 3 (Old Step 2, modified) ---
            _buildStep(
              icon: Icons.camera_alt_outlined,
              title: "3. Add or Capture Images", // Renumbered
              description: TextSpan(
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  color: Colors.grey[700],
                  height: 1.5,
                ),
                children: [
                  const TextSpan(text: "Use the (+) button options:\n\n"),
                  // Launch Tello
                  TextSpan(
                    text: "• 'Launch Tello':",
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  const TextSpan(
                    text:
                        " Opens the drone app to fly and take photos. When you return to SPOTato, your new photos will be imported and analyzed automatically.\n",
                  ),
                  // Gallery
                  TextSpan(
                    text: "• 'Gallery':",
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  const TextSpan(
                    text: " Adds any existing images from your phone.",
                  ),
                ],
              ),
            ),

            // --- STEP 4 (Old Step 3) ---
            _buildStep(
              icon: Icons.checklist_rtl_outlined,
              title: "4. Review Analysis", // Renumbered
              description: TextSpan(
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  color: Colors.grey[700],
                  height: 1.4,
                ),
                children: [
                  const TextSpan(text: "After the analysis, the results are "),
                  TextSpan(
                    text: "'now displayed'",
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  const TextSpan(text: ". You can also tap the "),
                  TextSpan(
                    text: "'image'",
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  const TextSpan(
                    text:
                        " to open the Analysis Viewer for a detailed information.",
                  ),
                ],
              ),
            ),

            // --- STEP 5 (Old Step 4) ---
            _buildStep(
              icon: Icons.save_alt_outlined,
              title: "5. Save Results & Row Selection", // Renumbered
              description: TextSpan(
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  color: Colors.grey[700],
                  height: 1.4,
                ),
                children: [
                  const TextSpan(text: "After analysis, tap "),
                  TextSpan(
                    text: "'Save'",
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  const TextSpan(text: " to store your scan in "),
                  TextSpan(
                    text: "'Albums'",
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  const TextSpan(text: ". You also need to "),
                  TextSpan(
                    text: "'select a row number'",
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  const TextSpan(text: " for easy location tracking."),
                ],
              ),
            ),

            // --- STEP 6 (Old Step 5) ---
            _buildStep(
              icon: Icons.photo_album_outlined,
              title: "6. View Saved Albums", // Renumbered
              description: TextSpan(
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  color: Colors.grey[700],
                  height: 1.4,
                ),
                children: [
                  const TextSpan(text: "Go to the "),
                  TextSpan(
                    text: "'Albums'",
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  const TextSpan(
                    text:
                        " tab to view your saved scans, including analyzed images and results.",
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep({
    required IconData icon,
    required String title,
    required TextSpan description,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(20),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: kOrange,
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: kDarkBrown,
                  ),
                ),
                const SizedBox(height: 4),
                RichText(text: description),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
