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
          "How to Use SPOTato",
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
            Text(
              "👋 Welcome to SPOTato!",
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: kDarkBrown,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              "This guide will help you understand how to use SPOTato to detect potato leaf diseases and manage your analysis results.",
              style: GoogleFonts.poppins(fontSize: 15, color: Colors.grey[700]),
            ),
            const SizedBox(height: 25),

            // Step 1
            _buildStep(
              stepNumber: "1",
              title: "Detect Disease",
              description:
                  "Tap the 'Detect Disease' button on the home screen. You will be redirected to the scanning page where you can add images of potato leaves.",
            ),

            // Step 2
            _buildStep(
              stepNumber: "2",
              title: "Add or Capture Images",
              description:
                  "You can either use the Tello drone (Connect to Tello's Wifi Hotspot first) to capture images or add them manually from your gallery. The AI will analyze each image and determine if the leaf is healthy or has blight.",
            ),

            // Step 3
            _buildStep(
              stepNumber: "3",
              title: "Save Your Results",
              description:
                  "After analysis, you can choose to save the current scan. Each saved session will be stored in the Albums page with its own folder name.",
            ),

            // Step 4
            _buildStep(
              stepNumber: "4",
              title: "View Saved Albums",
              description:
                  "Go to the 'Albums' tab at the bottom to view all your previous scans. You can open a folder to see analyzed images and their results.",
            ),

            const SizedBox(height: 30),
            Center(
              child: Text(
                "🌿 SPOTato — Detect, Analyze, and Manage with Ease!",
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: kOrange,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep({
    required String stepNumber,
    required String title,
    required String description,
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
            radius: 16,
            backgroundColor: kOrange,
            child: Text(
              stepNumber,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
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
                Text(
                  description,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
