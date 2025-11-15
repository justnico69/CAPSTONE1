import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'config.dart'; // Make sure this file is correctly imported

// Define the dark brown color for reuse
const Color kDarkBrown = Color.fromARGB(255, 128, 68, 12);
const Color kOrange = Color(0xFFEAA944);

class AnalysisViewerPage extends StatelessWidget {
  final DetectionResult detectionResult;
  final String durationText;
  final String dateCaptured;
  final String timeCaptured;

  const AnalysisViewerPage({
    super.key,
    required this.detectionResult,
    required this.durationText,
    required this.dateCaptured,
    required this.timeCaptured,
  });

  // 🔹 --- HELPER CLASS FOR STATUS CARD --- 🔹
  _PredictionStatus _getPredictionStatus(String? label) {
    if (label == null) {
      return _PredictionStatus(
        "Analysis Pending",
        "Data not saved or still loading",
        Colors.grey.shade600,
      );
    }
    if (label == 'Unknown') {
      return _PredictionStatus(
        "Unknown",
        "Result below confidence threshold",
        Colors.yellow.shade800,
      );
    }
    if (label.toLowerCase().contains('healthy')) {
      return _PredictionStatus(
        "Status: Healthy",
        "No disease detected.",
        Colors.green.shade700,
      );
    }
    // It's blight
    return _PredictionStatus(
      "Status: Blight",
      "$label Detected",
      Colors.red.shade700,
    );
  }
  // 🔹 --- END OF HELPER CLASS --- 🔹

  // Detail row builder
  Widget _buildDetailRow(
    String label,
    String value, {
    bool isHighlighted = false,
  }) {
    return Container(
      padding: isHighlighted
          ? const EdgeInsets.symmetric(horizontal: 10, vertical: 8)
          : const EdgeInsets.symmetric(vertical: 8),
      decoration: isHighlighted
          ? BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            )
          : null,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.lato(
              fontSize: 16,
              color: isHighlighted ? kDarkBrown : Colors.black87,
              fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: GoogleFonts.lato(
                fontSize: 16,
                color: kDarkBrown,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final File imageFile = detectionResult.file;
    final String? prediction = detectionResult.label;
    final double confidence = detectionResult.confidence;
    final bool fileOk = imageFile.existsSync();
    final String? rowTag = detectionResult.rowTag;

    final status = _getPredictionStatus(prediction);

    final double imageAreaHeight = MediaQuery.of(context).size.height * 0.45;

    return Scaffold(
      backgroundColor: Colors.grey[200], // Page background
      body: Stack(
        children: [
          // --- 1. The Image (at the bottom of the Stack) ---
          SizedBox(
            height: imageAreaHeight,
            width: double.infinity,
            child: fileOk
                ? Image.file(
                    imageFile,
                    fit: BoxFit.cover,
                    // Error builder in case the file gets deleted
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.grey[300],
                        child: Icon(
                          Icons.image_not_supported,
                          size: 80,
                          color: Colors.grey.shade600,
                        ),
                      );
                    },
                  )
                : Container(
                    color: Colors.grey[300],
                    child: Icon(
                      Icons.image_not_supported,
                      size: 80,
                      color: Colors.grey.shade600,
                    ),
                  ),
          ),

          // --- 2. Gradient overlay (for AppBar readability) ---
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 120,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black.withOpacity(0.6), Colors.transparent],
                ),
              ),
            ),
          ),

          // --- 3. The new "floating" AppBar ---
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: AppBar(
              backgroundColor: Colors.transparent, // Make it see-through
              elevation: 0, // No shadow
              iconTheme: const IconThemeData(
                color: Colors.white, // White back arrow
                shadows: [Shadow(blurRadius: 2, color: Colors.black)],
              ),
              title: Text(
                'Analysis Viewer',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  shadows: const [Shadow(blurRadius: 2, color: Colors.black)],
                ),
              ),
            ),
          ),

          // --- 4. The Main Content (scrollable) ---
          DraggableScrollableSheet(
            // 🔹 --- THIS IS THE FIX (PART 1) --- 🔹
            // The image is 45% (0.45) high.
            // We set the sheet to start at 55% (0.55) of the screen height.
            // This leaves 1.0 - 0.55 = 0.45 for the image, making the sheet
            // start EXACTLY where the image ends.
            initialChildSize: 0.55,
            minChildSize: 0.55,

            // 🔹 --- END OF FIX (PART 1) --- 🔹
            maxChildSize: 0.9, // Can be dragged up to 90%
            builder: (BuildContext context, ScrollController scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: Colors.grey[200], // The body background
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: ListView(
                  controller: scrollController,

                  // 🔹 --- THIS IS THE FIX (PART 2) --- 🔹
                  // We remove the default `all(16.0)` padding
                  // and only add padding to the sides. We will
                  // control the top/bottom gaps ourselves.
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),

                  // 🔹 --- END OF FIX (PART 2) --- 🔹
                  children: [
                    // 🔹 --- THIS IS THE FIX (PART 3) --- 🔹
                    // This creates the large, 24px gap between
                    // the top of the sheet and the first card.
                    const SizedBox(height: 24.0),
                    // 🔹 --- END OF FIX (PART 3) --- 🔹

                    // --- 5. The New Status Card ---
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: status.color.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: status.color, width: 2),
                      ),
                      child: Column(
                        children: [
                          Text(
                            status.title,
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: status.color,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            status.subtitle,
                            style: GoogleFonts.lato(
                              fontSize: 15,
                              color: status.color.withOpacity(0.9),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // This is the SMALLER, 16px gap between the two cards.
                    const SizedBox(height: 16),

                    // --- 6. Analysis Details Card (with Row Tag) ---
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Analysis Details",
                            style: GoogleFonts.poppins(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: kDarkBrown,
                            ),
                          ),
                          const Divider(height: 20),

                          _buildDetailRow(
                            "Confidence",
                            "${(confidence * 100).toStringAsFixed(1)}%",
                          ),

                          _buildDetailRow(
                            "Duration of analysis",
                            "$durationText ms",
                          ),
                          _buildDetailRow("Date Captured", dateCaptured),
                          _buildDetailRow("Time", timeCaptured),

                          // The Row Tag (only appears if it exists)
                          if (rowTag != null && rowTag.isNotEmpty)
                            _buildDetailRow(
                              "Row Tag",
                              rowTag,
                              isHighlighted: true,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40), // Extra space at bottom
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// 🔹 --- A simple helper class to hold the status info --- 🔹
class _PredictionStatus {
  final String title;
  final String subtitle;
  final Color color;
  _PredictionStatus(this.title, this.subtitle, this.color);
}
