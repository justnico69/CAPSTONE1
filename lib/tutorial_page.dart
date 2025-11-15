import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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
          style: GoogleFonts.poppins(
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
            // --- WELCOME SECTION (Unchanged) ---
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
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: kDarkBrown,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "This is a quick setup guide to help you understand how to use SPOTato. Follow these quick steps to get started:",
                        style: GoogleFonts.poppins(
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

            // --- STEP 1 (Unchanged) ---
            _buildStep(
              icon: Icons.search,
              title: "1. Detect Disease",
              description: TextSpan(
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[700],
                  height: 1.4,
                ),
                children: [
                  const TextSpan(text: "Tap "),
                  TextSpan(
                    text: "'Detect Disease'",
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      color: Colors.green, // Color from your original code
                    ),
                  ),
                  const TextSpan(
                    text:
                        " on the Home screen to begin scanning potato leaves.",
                  ),
                ],
              ),
            ),

            // --- STEP 2 (MODIFIED WITH NEW INFO) ---
            _buildStep(
              icon: Icons.camera_alt_outlined,
              title: "2. Add or Capture Images",
              description: TextSpan(
                // Default style for this text block
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[700],
                  height: 1.5, // Added space between lines
                ),
                children: [
                  const TextSpan(
                    text: "Use the (+) button options:\n\n",
                  ), // Added newline
                  // Launch Tello
                  TextSpan(
                    text: "• 'Launch Tello':",
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  const TextSpan(
                    text: " Opens the drone app to fly and take photos.\n",
                  ),

                  // Import Tello Photos
                  TextSpan(
                    text: "• 'Import Tello Photos':",
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  const TextSpan(
                    text:
                        " Pulls the new photos from the drone's folder into this app for analysis.\n",
                  ),

                  // Gallery
                  TextSpan(
                    text: "• 'Gallery':",
                    style: GoogleFonts.poppins(
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

            // --- 🔹 NEW STEP 3 (From Image) 🔹 ---
            _buildStep(
              icon: Icons.checklist_rtl_outlined, // Icon to match image
              title: "3. Review Analysis",
              description: TextSpan(
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[700],
                  height: 1.4,
                ),
                children: [
                  const TextSpan(text: "After the analysis, the results are "),
                  TextSpan(
                    text: "'now displayed'",
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  const TextSpan(text: ". You can also tap the "),
                  TextSpan(
                    text: "'image'",
                    style: GoogleFonts.poppins(
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

            // --- 🔹 STEP 4 (MODIFIED from old STEP 3) 🔹 ---
            _buildStep(
              icon: Icons.save_alt_outlined, // Kept your original icon
              title: "4. Save Results & Row Selection", // Updated Title
              description: TextSpan(
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[700],
                  height: 1.4,
                ),
                children: [
                  const TextSpan(text: "After analysis, tap "),
                  TextSpan(
                    text: "'Save'",
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  const TextSpan(text: " to store your scan in "),
                  TextSpan(
                    text: "'Albums'",
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  const TextSpan(text: ". You also need to "),
                  TextSpan(
                    text: "'select a row number'", // New text
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  const TextSpan(
                    text: " for easy location tracking.", // Updated text
                  ),
                ],
              ),
            ),

            // --- 🔹 STEP 5 (MODIFIED from old STEP 4) 🔹 ---
            _buildStep(
              icon: Icons.photo_album_outlined, // Kept your original icon
              title: "5. View Saved Albums", // Updated Title
              description: TextSpan(
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[700],
                  height: 1.4,
                ),
                children: [
                  const TextSpan(text: "Go to the "),
                  TextSpan(
                    text: "'Albums'",
                    style: GoogleFonts.poppins(
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
                  style: GoogleFonts.poppins(
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
