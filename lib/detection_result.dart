import 'dart:io';

class DetectionResult {
  final File image;
  final String prediction;
  final double confidence;
  final DateTime dateCaptured;

  DetectionResult({
    required this.image,
    required this.prediction,
    required this.confidence,
    required this.dateCaptured,
  });

  // Convert a DetectionResult object to a JSON-like map
  Map<String, dynamic> toJson() {
    return {
      'imagePath': image.path,
      'prediction': prediction,
      'confidence': confidence,
      'dateCaptured': dateCaptured.toIso8601String(),
    };
  }

  // Create a DetectionResult object from a JSON-like map
  factory DetectionResult.fromJson(Map<String, dynamic> json) {
    return DetectionResult(
      image: File(json['imagePath'] as String),
      prediction: json['prediction'] as String,
      confidence: json['confidence'] as double,
      dateCaptured: DateTime.parse(json['dateCaptured'] as String),
    );
  }
}
