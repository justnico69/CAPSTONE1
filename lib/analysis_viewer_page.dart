// lib/analysis_viewer_page.dart (Ensure it is StatelessWidget)

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

  const AnalysisViewerPage({super.key, required this.detectionResult});

  // Helper to determine the color based on the result label
  Color _getResultColor(String? label, double confidence) {
    if (label == null) return Colors.grey;
    if (label == 'Unknown') return Colors.yellow.shade800;
    if (label.toLowerCase().contains('healthy')) return Colors.green.shade600;
    
    // Default color for positive detections (e.g., diseased)
    return confidence > 0.8 ? Colors.redAccent.shade700 : Colors.orange.shade700;
  }

  // Helper to determine the status text
  String _getStatusText(String? label) {
    if (label == null) return "Analysis Pending (Data not saved or still loading)";
    if (label == 'Unknown') return "Analysis Complete: Result below confidence threshold";
    return "Analysis Complete";
  }

  @override
  Widget build(BuildContext context) {
    final File imageFile = detectionResult.file;
    final String? prediction = detectionResult.label;
    final double confidence = detectionResult.confidence;
    final bool fileOk = imageFile.existsSync();
    
    final Color resultColor = _getResultColor(prediction, confidence);
    final String predictionText = prediction ?? "Not Analyzed";
    final String statusText = _getStatusText(prediction);
    
    // 🔥 NEW: Calculate maximum available height for the image section
    // We'll constrain the image size but allow it to size itself based on the image's aspect ratio.
    final mediaQuery = MediaQuery.of(context);
    final double maxImageHeight = mediaQuery.size.height * 0.5; // Example constraint: max 50% of screen height

    return Scaffold(
      backgroundColor: Colors.grey[200],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: Text(
          'Analysis Viewer',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: kDarkBrown,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
            
            // 🔥 MODIFIED: Replaced Expanded with flexible Center/ConstrainedBox
            // This section is now flexible based on the image size
            Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  // Max width is the screen width minus padding
                  maxWidth: mediaQuery.size.width - 32, 
                  maxHeight: maxImageHeight,
                ),
                child: Container(
                  // Set padding inside the container
                  padding: const EdgeInsets.all(4), 
                  // Removed 'flex: 3' as it's no longer Expanded

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
                              // Use contain to respect aspect ratio and fit within constraints
                              fit: BoxFit.contain, 
                              // Removed width: double.infinity to allow sizing by aspect ratio
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
            ),
            
            const SizedBox(height: 16),
            
            // 🔥 MODIFIED: Added Expanded back to the bottom container
            // This ensures the analysis details take up the remaining space
            Expanded( 
              flex: 2, // Retaining the flex ratio for the remaining height
              child: Container(
                padding: const EdgeInsets.fromLTRB(30, 30, 30, 0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Analysis Result",
                      style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Divider(),
                    Text(
                      predictionText,
                      style: GoogleFonts.poppins(
                        fontSize: 28,
                        fontWeight: FontWeight.w600,
                        color: resultColor,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      "CONFIDENCE: ${(confidence * 100).toStringAsFixed(1)}%",
                      style: GoogleFonts.lato(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                    LinearProgressIndicator(
                      value: confidence,
                      backgroundColor: Colors.grey.shade300,
                      color: resultColor,
                      minHeight: 8,
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}