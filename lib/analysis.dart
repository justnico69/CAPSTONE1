// lib/analysis.dart
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:spotato/config.dart';

// ==========================================================
// Helper: Preprocessing to match the working Python script
// ==========================================================
Float32List _imageToTensor(img.Image image) {
  final img.Image resized = img.copyResize(
    image,
    width: kModelInputSize,
    height: kModelInputSize,
    interpolation: img.Interpolation.nearest,
  );

  final Float32List floatList = Float32List(
    1 * kModelInputSize * kModelInputSize * 3,
  );

  int bufferIndex = 0;
  for (int y = 0; y < resized.height; y++) {
    for (int x = 0; x < resized.width; x++) {
      final pixel = resized.getPixel(x, y);

      // 🔥 THE FIX: Remove normalization. Convert raw pixel values directly to float.
      // This now perfectly matches your working Python script.
      floatList[bufferIndex++] = pixel.r.toDouble();
      floatList[bufferIndex++] = pixel.g.toDouble();
      floatList[bufferIndex++] = pixel.b.toDouble();
    }
  }
  return floatList;
}

// ==========================================================
// Helper: Softmax
// ==========================================================
List<double> _softmax(List<double> logits) {
  final maxLogit = logits.reduce(math.max);
  final exps = logits.map((v) => math.exp(v - maxLogit)).toList();
  final sumExp = exps.reduce((a, b) => a + b);
  return exps.map((e) => e / sumExp).toList();
}

// ==========================================================
// Main Analysis Function (with Debug Logs)
// ==========================================================
Future<void> runModelAnalysis(DetectionResult res) async {
  final fileName = res.file.uri.pathSegments.last;

  debugPrint(
    '\n\n🎯========== DART (FLUTTER) DEBUG LOG FOR: $fileName ==========🎯',
  );

  if (globalInterpreter == null) {
    debugPrint('❌ Interpreter not initialized.');
    res.label = 'Unknown';
    res.confidence = 0.0;
    return;
  }

  res.isLoading = true;

  try {
    final Uint8List bytes = await res.file.readAsBytes();
    var decoded = img.decodeImage(bytes);
    if (decoded == null) throw Exception('Failed to decode image');
    decoded = img.bakeOrientation(decoded);

    final rawPixel = decoded.getPixel(0, 0);
    debugPrint(
      '📊 [BEFORE] Raw Pixel Values (top-left pixel R,G,B): [${rawPixel.r}, ${rawPixel.g}, ${rawPixel.b}]',
    );

    final Float32List tensorData = _imageToTensor(decoded);

    final sampleValues = [
      tensorData[0].toStringAsFixed(6),
      tensorData[1].toStringAsFixed(6),
      tensorData[2].toStringAsFixed(6),
    ];
    debugPrint(
      '🎯 [AFTER] Processed Tensor Values (top-left pixel R,G,B): $sampleValues',
    );

    final input = List.generate(
      1,
      (_) => List.generate(
        kModelInputSize,
        (y) => List.generate(
          kModelInputSize,
          (x) => [
            tensorData[(y * kModelInputSize + x) * 3 + 0],
            tensorData[(y * kModelInputSize + x) * 3 + 1],
            tensorData[(y * kModelInputSize + x) * 3 + 2],
          ],
        ),
      ),
    );

    final output = List.generate(
      1,
      (_) => List.filled(kModelLabels.length, 0.0),
    );

    final startTime = DateTime.now();
    globalInterpreter!.run(input, output);
    final duration = DateTime.now().difference(startTime);

    final List<double> logits = output[0].cast<double>();
    debugPrint(
      '🧠 [OUTPUT] Raw Model Logits: ${logits.map((e) => e.toStringAsFixed(6)).toList()}',
    );

    final probs = _softmax(logits);
    final maxProb = probs.reduce(math.max);
    final maxIdx = probs.indexOf(maxProb);
    final rawLabel = kModelLabels[maxIdx];
    final friendly = kLabelFriendly[rawLabel] ?? rawLabel;
    final finalLabel = (maxProb >= kConfidenceThreshold) ? friendly : 'Unknown';

    debugPrint('\n✅ [RESULT] Final Prediction Summary:');
    debugPrint('    Prediction: "$finalLabel"');
    debugPrint('    Confidence: ${(maxProb * 100).toStringAsFixed(2)}%');
    debugPrint('    Inference time: ${duration.inMilliseconds} ms');
    debugPrint(
      '====================================================================\n',
    );

    res.label = finalLabel;
    res.confidence = maxProb;
    res.analysisDuration = duration;
  } catch (e, st) {
    debugPrint('❌ Analysis error: $e\n$st');
    res.label = 'Unknown';
    res.confidence = 0.0;
  } finally {
    res.isLoading = false;
  }
}
