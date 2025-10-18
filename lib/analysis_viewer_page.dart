// lib/analysis_viewer_page.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// FIX: Import the correct DetectionResult definition from config.dart
import 'config.dart';

// Define the dark brown color for reuse
const Color kDarkBrown = Color.fromARGB(255, 128, 68, 12);

// This MUST be StatelessWidget
class AnalysisViewerPage extends StatelessWidget {
  final DetectionResult detectionResult;
  // 🔥 Fields for Dynamic Duration, Date, and Time
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

  // Helper to determine the color based on the result label
  Color _getResultColor(String? label, double confidence) {
    if (label == null) return Colors.grey;
    if (label == 'Unknown') return Colors.yellow.shade800;
    if (label.toLowerCase().contains('healthy')) return Colors.green.shade600;

    // Default color for positive detections (e.g., diseased)
    return confidence > 0.8
        ? Colors.redAccent.shade700
        : Colors.orange.shade700;
  }

  // Helper to determine the status text
  String _getStatusText(String? label) {
    if (label == null) {
      return "Analysis Pending (Data not saved or still loading)";
    }
    if (label == 'Unknown') {
      return "Analysis Complete: Result below confidence threshold";
    }
    return "Analysis Complete";
  }

  // Helper widget to build the detail rows
  Widget _buildDetailRow(String label, String value,
      {bool isHighlighted = false}) {
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

  @override
  Widget build(BuildContext context) {
    final File imageFile = detectionResult.file;
    final String? prediction = detectionResult.label;
    final double confidence = detectionResult.confidence;
    final bool fileOk = imageFile.existsSync();

    final Color resultColor = _getResultColor(prediction, confidence);
    final String statusText = _getStatusText(prediction);

    // Fixed height for image display relative to screen size
    final double imageAreaHeight = MediaQuery.of(context).size.height * 0.45;

    return Scaffold(
      backgroundColor: Colors.grey[200],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: Text(
          'Analysis Viewer',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            color: kDarkBrown,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- Status Banner ---
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  statusText,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.lato(fontSize: 16, color: Colors.black54),
                ),
              ),
              const SizedBox(height: 16),

              // --- Image Display Area (Fixed Height) ---
              Center(
                child: Container(
                  height: imageAreaHeight,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Center(
                    child: fileOk
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              imageFile,
                              fit: BoxFit.contain,
                            ),
                          )
                        : Icon(
                            Icons.image_not_supported,
                            size: 80,
                            color: Colors.grey.shade300,
                          ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // --- Analysis Details ---
              Container(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "Analysis Result",
                      style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: kDarkBrown,
                      ),
                    ),
                    const Divider(),

                    // 🔥 Confidence (same format as other rows)
                    _buildDetailRow(
                      "Confidence",
                      "${(confidence * 100).toStringAsFixed(1)}%",
                    ),

                    // Dynamic Duration of Analysis
                    _buildDetailRow("Duration of analysis", durationText),

                    // Dynamic Date Captured
                    _buildDetailRow("Date Captured", dateCaptured),

                    // Dynamic Time
                    _buildDetailRow("Time", timeCaptured),
                  ],
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
