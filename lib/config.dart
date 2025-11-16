import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/material.dart'; // 👈 Added for debugPrint
import 'package:flutter/services.dart' show rootBundle;
import 'package:tflite_flutter/tflite_flutter.dart';

// ========================
// MODEL CONFIGURATION
// ========================
const String kModelAssetPath = 'assets/models/model.tflite';
const int kModelInputSize = 300;
const double kConfidenceThreshold = 0.35;

// Labels must match training order exactly
const List<String> kModelLabels = [
  'Potato___Early_blight', // Index 0
  'Potato___Late_blight', // Index 1
  'Potato___healthy', // Index 2
];

const Map<String, String> kLabelFriendly = {
  'Potato___Early_blight': 'Early Blight',
  'Potato___Late_blight': 'Late Blight',
  'Potato___healthy': 'Healthy',
};

// ========================
// DETECTION RESULT CLASS
// ========================
class DetectionResult {
  final File file;
  final int? id; // 👈 This is important for database operations
  bool isLoading;
  String? label;
  double confidence;
  Duration? analysisDuration;
  DateTime? captureTime;
  String? rowTag; // Holds the user-defined row (e.g., "Row 5")

  DetectionResult({
    required this.file,
    this.id, // 👈 Added
    this.isLoading = false,
    this.label,
    this.confidence = 0.0,
    this.analysisDuration,
    this.captureTime,
    this.rowTag,
  });

  Map<String, dynamic> toJson() => {
    'path': file.path.split('/').last,
    'label': label,
    'confidence': confidence,
  };

  static DetectionResult fromJson(File dir, Map<String, dynamic> json) {
    final f = File('${dir.path}/${json['path']}');
    return DetectionResult(
      file: f,
      label: json['label'] as String?,
      confidence: (json['confidence'] ?? 0.0).toDouble(),
    );
  }
}

// ========================
// GLOBALS
// ========================
Interpreter? globalInterpreter;
TensorType?
globalInputType; // 👈 Corrected to match Interpreter.getInputTensor(0).type
List<int>? globalInputShape;

// ========================
// HELPERS
// ========================
String sha256FromBytes(Uint8List bytes) =>
    crypto.sha256.convert(bytes).toString();

// 🔹 --- RENAMED & UPDATED THIS FUNCTION --- 🔹
// This is now called by main.dart on app startup
Future<void> loadGlobalModel() async {
  if (globalInterpreter != null) {
    debugPrint("--- [GLOBAL LOAD] Model already loaded.");
    return;
  }

  debugPrint("--- [GLOBAL LOAD] Attempting to load TFLite model...");
  try {
    globalInterpreter = await Interpreter.fromAsset(kModelAssetPath);
    final inTensor = globalInterpreter!.getInputTensor(0);
    globalInputType = inTensor.type;
    globalInputShape = inTensor.shape;

    debugPrint('--- [GLOBAL LOAD] ✅ Model loaded: $kModelAssetPath');
    debugPrint(
      '--- [GLOBAL LOAD] Input shape: $globalInputShape | type: $globalInputType',
    );

    final modelData = (await rootBundle.load(
      kModelAssetPath,
    )).buffer.asUint8List();
    final modelHash = sha256FromBytes(modelData);
    debugPrint('--- [GLOBAL LOAD] Model SHA256: $modelHash');
  } catch (e) {
    debugPrint('--- [GLOBAL LOAD] ❌ Error loading model: $e');
    rethrow; // Let main.dart know something went wrong if we want to handle it
  }
}

void closeModel() {
  try {
    globalInterpreter?.close();
  } catch (__) {}
  globalInterpreter = null;
  globalInputShape = null;
  globalInputType = null;
}
