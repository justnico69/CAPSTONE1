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
          "SPOTato Manual", // --- CHANGED ---
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
            // --- WELCOME SECTION (MODIFIED) ---
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
                        "This is a quick setup guide to help you understand how to use SPOTato. Follow these quick steps to get started:", // Text from image
                        style: GoogleFonts.poppins(fontSize: 15, color: Colors.grey[700]),
                      ),
                    ],
                  ),
                )
              ],
            ),
            const SizedBox(height: 25),

            // --- STEP 1 (MODIFIED CALL) ---
            _buildStep(
              icon: Icons.search,
              title: "1. Detect Disease",
              // We use RichText here to allow for bolding
              description: TextSpan(
                // This is the default style for all text in this block
                style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[700], height: 1.4),
                children: [
                  const TextSpan(text: "Tap "),
                  TextSpan(
                    text: "'Detect Disease'",
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.green),
                  ),
                  const TextSpan(text: " on the Home screen to begin scanning potato leaves."),
                ],
              ),
            ),

            // --- STEP 2 (MODIFIED CALL) ---
            _buildStep(
              icon: Icons.camera_alt_outlined,
              title: "2. Add or Capture Images",
              description: TextSpan(
                style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[700], height: 1.4),
                children: [
                  const TextSpan(text: "Use the "),
                  TextSpan(
                    text: "'Tello drone'",
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.green),
                  ),
                  const TextSpan(text: " or "),
                  TextSpan(
                    text: "'Gallery'",
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.green),
                  ),
                  const TextSpan(text: " to upload potato leaf images. The AI checks if each leaf is healthy or infected."),
                ],
              ),
            ),

            // --- STEP 3 (MODIFIED CALL) ---
            _buildStep(
              icon: Icons.save_alt_outlined,
              title: "3. Save Results",
              description: TextSpan(
                style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[700], height: 1.4),
                children: [
                  const TextSpan(text: "After analysis, tap "),
                  TextSpan(
                    text: "'Save'",
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.green),
                  ),
                  const TextSpan(text: " to store your scan in "),
                  TextSpan(
                    text: "'Albums'",
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.green),
                  ),
                  const TextSpan(text: ". You can name the scan for easy tracking."),
                ],
              ),
            ),

            // --- STEP 4 (MODIFIED CALL) ---
            _buildStep(
              icon: Icons.photo_album_outlined,
              title: "4. View Saved Albums",
              description: TextSpan(
                style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[700], height: 1.4),
                children: [
                  const TextSpan(text: "Go to the "),
                  TextSpan(
                    text: "'Albums'",
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.green),
                  ),
                  const TextSpan(text: " tab to view your saved scans, including analyzed images and results."),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- _buildStep WIDGET (MODIFIED) ---
  Widget _buildStep({
    required IconData icon, // CHANGED
    required String title,
    required TextSpan description, // CHANGED
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
            radius: 24, // CHANGED - made bigger
            backgroundColor: kOrange,
            child: Icon( // CHANGED
              icon,
              color: Colors.white,
              size: 28, // CHANGED
            ),
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
                // Use RichText to render the TextSpan
                RichText( // CHANGED
                  text: description,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}