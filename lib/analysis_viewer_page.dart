import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// 🔹 REMOVED database_helper import, no longer needed here

import 'config.dart';

// Define the dark brown color for reuse
const Color kDarkBrown = Color.fromARGB(255, 128, 68, 12);
const Color kOrange = Color(0xFFEAA944);

// 🔹 --- CONVERTED BACK TO STATELESSWIDGET --- 🔹
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

  // Color based on result
  Color _getResultColor(String? label, double confidence) {
    if (label == null) return Colors.grey;
    if (label == 'Unknown') return Colors.yellow.shade800;
    if (label.toLowerCase().contains('healthy')) return Colors.green.shade600;
    return confidence > 0.8
        ? Colors.redAccent.shade700
        : Colors.orange.shade700;
  }

  // Status helper
  String _getStatusText(String? label) {
    if (label == null) {
      return "Analysis Pending (Data not saved or still loading)";
    }
    if (label == 'Unknown') {
      return "Analysis Complete: Result below confidence threshold";
    }
    return "Analysis Complete";
  }

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

  // 🔹 --- All editing logic and dialog functions are REMOVED --- 🔹

  @override
  Widget build(BuildContext context) {
    final File imageFile = detectionResult.file;
    final String? prediction = detectionResult.label;
    final double confidence = detectionResult.confidence;
    final bool fileOk = imageFile.existsSync();
    final Color resultColor = _getResultColor(prediction, confidence);
    final String statusText = _getStatusText(prediction);
    final double imageAreaHeight = MediaQuery.of(context).size.height * 0.45;

    // 🔹 Get the row tag from the object
    final String? rowTag = detectionResult.rowTag;

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
              // --- Status Banner
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

              //--- Image Display
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
                            child: Image.file(imageFile, fit: BoxFit.contain),
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

              // --- Prediction Result
              if (prediction != null)
                Center(
                  child: Text(
                    prediction,
                    style: GoogleFonts.poppins(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: resultColor,
                    ),
                  ),
                ),
              const SizedBox(height: 12),

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
                  children: [
                    Text(
                      "Analysis Details",
                      style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: kDarkBrown,
                      ),
                    ),
                    const Divider(),
                    _buildDetailRow(
                      "Confidence",
                      "${(confidence * 100).toStringAsFixed(1)}%",
                    ),
                    _buildDetailRow("Duration of analysis", durationText),
                    _buildDetailRow("Date Captured", dateCaptured),
                    _buildDetailRow("Time", timeCaptured),

                    // 🔹 --- UPDATED UI --- 🔹
                    const SizedBox(height: 10),
                    // Only show the Row Tag row if a tag exists
                    if (rowTag != null && rowTag.isNotEmpty)
                      _buildDetailRow(
                        "Row Tag",
                        rowTag, // Show the tag
                        isHighlighted: true,
                      ),
                    // 🔹 --- END OF UPDATED UI (Button is removed) --- 🔹
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
