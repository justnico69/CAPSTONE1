// lib/analysis_viewer_page.dart

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Import for SystemUiOverlayStyle
import 'package:google_fonts/google_fonts.dart';

import 'config.dart';

// Define the dark brown color for reuse
const Color kDarkBrown = Color.fromARGB(255, 128, 68, 12);

/// Helper class to hold styling for the warning card
class _WarningStyle {
  final Color boxColor;
  final Color titleColor;
  final String title;
  final String subtitle;
  final IconData icon;

  _WarningStyle({
    required this.boxColor,
    required this.titleColor,
    required this.title,
    required this.subtitle,
    required this.icon,
  });
}

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

  /// Determines the style of the warning card based on the prediction
  _WarningStyle _getWarningStyle(String? label, double confidence) {
    if (label == null) {
      return _WarningStyle(
        boxColor: Colors.grey.shade300,
        titleColor: Colors.black54,
        title: "Status",
        subtitle: "Analysis Pending",
        icon: Icons.hourglass_empty,
      );
    }
    if (label == 'Unknown') {
      return _WarningStyle(
        boxColor: Colors.yellow.shade200,
        titleColor: Colors.yellow.shade900,
        title: "Notice",
        subtitle: "Result Uncertain",
        icon: Icons.help_outline,
      );
    }
    if (label.toLowerCase().contains('healthy')) {
      return _WarningStyle(
        boxColor: Colors.green.shade100,
        titleColor: Colors.green.shade800,
        title: "Status",
        subtitle: "Healthy",
        icon: Icons.check_circle_outline,
      );
    }

    // Default case: Disease detected (matches the image)
    return _WarningStyle(
      boxColor: Colors.orange.shade100,
      titleColor: Colors.red.shade800,
      title: "Warning!",
      subtitle: label,
      icon: Icons.warning_amber_rounded,
    );
  }

  // Detail row builder (simplified)
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.lato(
              fontSize: 16,
              color: Colors.black54,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.lato(
              fontSize: 16,
              color: kDarkBrown,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the "AI Conf: X%" chip
  Widget _buildConfidenceChip(double confidence) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        "AI Confidence: ${(confidence * 100).toStringAsFixed(0)}%",
        style: GoogleFonts.lato(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }

  /// Builds the "Warning! Early Blight" card
  Widget _buildWarningCard(String? prediction, double confidence) {
    final style = _getWarningStyle(prediction, confidence);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: style.boxColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(style.icon, color: style.titleColor, size: 30),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  style.title,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: style.titleColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  style.subtitle,
                  style: GoogleFonts.lato(
                    fontSize: 20,
                    color: kDarkBrown,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
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

    final double imageAreaHeight = MediaQuery.of(context).size.height * 0.45;

    return Scaffold(
      backgroundColor: Colors.grey[200],
      // This allows the AppBar to float over the body
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        // Sets status bar icons to be light (for dark backgrounds)
        systemOverlayStyle: SystemUiOverlayStyle.light,
        title: Text(
          'Analysis Viewer',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- Image Header ---
            Stack(
              children: [
                Container(
                  height: imageAreaHeight,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                  ),
                  child: fileOk
                      ? Image.file(
                          imageFile,
                          fit: BoxFit.cover,
                          width: double.infinity,
                        )
                      : Icon(
                          Icons.image_not_supported,
                          size: 80,
                          color: Colors.grey.shade300,
                        ),
                ),
                // --- Scrim (for text readability) ---
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.black.withOpacity(0.6),
                          Colors.transparent,
                          Colors.black.withOpacity(0.4),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0.0, 0.5, 1.0],
                      ),
                    ),
                  ),
                ),
                // --- Confidence Chip ---
                Positioned(
                  bottom: 16,
                  right: 16,
                  child: _buildConfidenceChip(confidence),
                ),
              ],
            ),

            // --- Content Area ---
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // --- Warning Card ---
                  if (prediction != null)
                    _buildWarningCard(prediction, confidence),
                  
                  const SizedBox(height: 16),

                  // --- Analysis Details Card ---
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
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
                        const Divider(thickness: 1, height: 24),
                        _buildDetailRow("Duration of analysis", durationText),
                        _buildDetailRow("Date Captured", dateCaptured),
                        _buildDetailRow("Time", timeCaptured),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}