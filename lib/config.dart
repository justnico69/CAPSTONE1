// config.dart
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/services.dart' show rootBundle;
import 'package:tflite_flutter/tflite_flutter.dart';

// ------------------------------------------------------
// CONFIG
// ------------------------------------------------------
const String kModelAssetPath = 'assets/models/model.tflite';
const int kModelInputSize = 300; // must match training input size
const double kConfidenceThreshold = 0.35;

// IMPORTANT: must match the training generator index order exactly.
// Training folders used (Kaggle notebook):
// ['Potato___Early_blight', 'Potato___Late_blight', 'Potato___healthy']
// => index 0 = Early, 1 = Late, 2 = Healthy
const List<String> kModelLabels = [
  'Potato___Early_blight',
  'Potato___Late_blight',
  'Potato___healthy',
];

// Friendly names for UI
const Map<String, String> kLabelFriendly = {
  'Potato___Early_blight': 'Early Blight',
  'Potato___Late_blight': 'Late Blight',
  'Potato___healthy': 'Healthy',
};

// ------------------------------------------------------
// Data Model for a single detection result
// ------------------------------------------------------
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

// ------------------------------------------------------
// Globals for the interpreter and tensor info
// ------------------------------------------------------
Interpreter? globalInterpreter;
TensorType? globalInputType;
List<int>? globalInputShape;

// ------------------------------------------------------
// SHA256 Helper
// ------------------------------------------------------
String sha256FromBytes(Uint8List bytes) {
  return crypto.sha256.convert(bytes).toString();
}

// ------------------------------------------------------
// Load model + print SHA256
// ------------------------------------------------------
Future<void> loadModelFromAsset() async {
  try {
    globalInterpreter = await Interpreter.fromAsset(kModelAssetPath);
    globalInputType = globalInterpreter!.getInputTensors()[0].type;
    globalInputShape = globalInterpreter!.getInputTensors()[0].shape;

    // Print interpreter info
    print('TFLite model loaded from $kModelAssetPath');
    print('Input type: $globalInputType');
    print('Input shape: $globalInputShape');

    // Print model size + SHA256
    final modelData = (await rootBundle.load(
      kModelAssetPath,
    )).buffer.asUint8List();
    final modelHash = sha256FromBytes(modelData);
    print('Model asset size: ${modelData.length} bytes');
    print('Model SHA256: $modelHash');
  } catch (e) {
    print('Error loading TFLite model: $e');
  }
}
