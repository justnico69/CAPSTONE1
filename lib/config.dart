// config.dart

import 'dart:io';

import 'package:tflite_flutter/tflite_flutter.dart';

//
// CONFIG - change model asset path if needed
//
const String kModelAssetPath =
    'assets/models/model.tflite'; // <-- update to your .tflite (e.g. enb3puref.tflite)
const int kModelInputSize = 300;
const double kConfidenceThreshold =
    0.35; // adjust if you want fewer/more "Unknown"
const List<String> kModelLabels = ['Early_Blight', 'Healthy', 'Late_Blight'];

//
// Data Model for a single detection result
//
class DetectionResult {
  final File file;
  bool isLoading;
  String? label;
  double confidence;

  DetectionResult({
    required this.file,
    this.isLoading = false,
    this.label,
    this.confidence = 0.0,
  });

  Map<String, dynamic> toJson() => {
    'path': file.path.split('/').last,
    'label': label,
    'confidence': confidence,
  };

  static DetectionResult fromJson(File rowDir, Map<String, dynamic> json) {
    final name = json['path'] as String;
    final path = '${rowDir.path}/$name';
    final f = File(path);
    return DetectionResult(
      file: f,
      isLoading: false,
      label: json['label'] as String?,
      confidence: (json['confidence'] ?? 0.0).toDouble(),
    );
  }
}

// Global interpreter instance (will be loaded once in RowDetailPage)
Interpreter? globalInterpreter;
TensorType? globalInputType;
List<int>? globalInputShape;
