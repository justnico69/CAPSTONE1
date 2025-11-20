import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:tflite_flutter/tflite_flutter.dart';

/// Path to the TensorFlow Lite model used for inference.
const String kModelAssetPath = 'assets/models/model.tflite';

/// Expected square input size of the model (e.g., 300x300).
const int kModelInputSize = 300;

/// Minimum confidence threshold required to accept a prediction.
const double kConfidenceThreshold = 0.35;

/// Labels corresponding to the model output indices.
const List<String> kModelLabels = [
  'Potato___Early_blight', // Index 0
  'Potato___Late_blight', // Index 1
  'Potato___healthy', // Index 2
];

/// Human-friendly label mappings for UI display.
const Map<String, String> kLabelFriendly = {
  'Potato___Early_blight': 'Early Blight',
  'Potato___Late_blight': 'Late Blight',
  'Potato___healthy': 'Healthy',
};

/// Represents the result of processing a single image through the AI model.
/// Holds file metadata, model predictions, confidence scores, analysis time,
/// and database identifiers used for persistence.
class DetectionResult {
  /// The actual image file.
  final File file;

  /// Database ID associated with this detection result.
  final int? id;

  /// Whether the detection is currently being processed.
  bool isLoading;

  /// The model-predicted label.
  String? label;

  /// Confidence score associated with the prediction.
  double confidence;

  /// Time taken to perform the analysis.
  Duration? analysisDuration;

  /// When the image was captured (if available).
  DateTime? captureTime;

  /// Optional user-assigned row tag (e.g., "Row 5").
  String? rowTag;

  DetectionResult({
    required this.file,
    this.id,
    this.isLoading = false,
    this.label,
    this.confidence = 0.0,
    this.analysisDuration,
    this.captureTime,
    this.rowTag,
  });

  /// Converts the detection result into JSON format for local storage.
  Map<String, dynamic> toJson() => {
    'path': file.path.split('/').last,
    'label': label,
    'confidence': confidence,
  };

  /// Reconstructs a [DetectionResult] from stored JSON metadata.
  static DetectionResult fromJson(File dir, Map<String, dynamic> json) {
    final f = File('${dir.path}/${json['path']}');
    return DetectionResult(
      file: f,
      label: json['label'] as String?,
      confidence: (json['confidence'] ?? 0.0).toDouble(),
    );
  }
}

/// ========================
/// GLOBALS
/// ========================

/// Shared global TensorFlow Lite interpreter instance.
Interpreter? globalInterpreter;

/// The input tensor type of the loaded model.
TensorType? globalInputType;

/// The input tensor shape of the loaded model.
List<int>? globalInputShape;

/// ========================
/// HELPERS
/// ========================

/// Computes a SHA-256 checksum from raw byte data.
String sha256FromBytes(Uint8List bytes) =>
    crypto.sha256.convert(bytes).toString();

/// Loads the global TensorFlow Lite model at app startup.
///
/// This initializes:
/// - [globalInterpreter]
/// - [globalInputType]
/// - [globalInputShape]
///
/// If the model is already loaded, the function returns immediately.
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
    rethrow;
  }
}

/// Closes the global model interpreter and clears its cached metadata.
void closeModel() {
  try {
    globalInterpreter?.close();
  } catch (__) {}

  globalInterpreter = null;
  globalInputShape = null;
  globalInputType = null;
}
