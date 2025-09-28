// analysis.dart

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

import 'config.dart'; // Import config for constants and global interpreter

// ---------------- HELPER: softmax ----------------
List<double> _softmax(List<double> logits) {
  final maxLogit = logits.reduce((a, b) => a > b ? a : b);
  final exps = logits.map((v) => math.exp(v - maxLogit)).toList();
  final sumExp = exps.reduce((a, b) => a + b);
  return exps.map((e) => e / sumExp).toList();
}

// ---------------- STANDALONE ANALYSIS FUNCTION ----------------
Future<void> runModelAnalysis(DetectionResult res) async {
  final fileName = res.file.uri.pathSegments.last;

  if (globalInterpreter == null) {
    debugPrint('Interpreter not ready - skipping analysis for $fileName');
    res.label = 'Unknown';
    res.confidence = 0.0;
    return;
  }

  res.isLoading = true; // State update is handled by caller (RowDetailPage)

  try {
    final bytes = await res.file.readAsBytes();
    var decoded = img.decodeImage(bytes);
    if (decoded == null) throw Exception('Could not decode image');

    // Apply EXIF orientation bake
    decoded = img.bakeOrientation(decoded);

    // Resize to model input size (linear interpolation)
    final resized = img.copyResize(
      decoded,
      width: kModelInputSize,
      height: kModelInputSize,
      interpolation: img.Interpolation.linear,
    );

    // Get raw RGB bytes, row-major order (R,G,B,R,G,B,...)
    final Uint8List rgbBytes = resized.getBytes(order: img.ChannelOrder.rgb);
    final int expectedLen = kModelInputSize * kModelInputSize * 3;

    // --- Input tensor construction ---
    dynamic inputForInterpreter;

    // Determine the input type (assuming globalInputType is set after loading model)
    final inputType = globalInputType ?? TensorType.float32;

    // EfficientNet preprocessing: (pixel/127.5) - 1.0
    if (inputType == TensorType.float32) {
      final input = Float32List(expectedLen);
      for (int i = 0; i < expectedLen; i++) {
        final double channelValue = (i < rgbBytes.length)
            ? rgbBytes[i].toDouble()
            : 0.0;
        // Apply normalization: (Value / 127.5) - 1.0
        input[i] = (channelValue / 127.5) - 1.0;
      }

      // Reshape to [1, H, W, 3]
      inputForInterpreter = input.reshape([
        1,
        kModelInputSize,
        kModelInputSize,
        3,
      ]);
    } else if (inputType == TensorType.uint8) {
      // UINT8 input: No normalization needed, just raw bytes
      // Build nested 4D List<int> [1][H][W][3]
      inputForInterpreter = List.generate(
        1,
        (_) => List.generate(
          kModelInputSize,
          (_) => List.generate(
            kModelInputSize,
            (_) => List.filled(3, 0),
            growable: false,
          ),
          growable: false,
        ),
        growable: false,
      );
      int p = 0;
      for (int y = 0; y < kModelInputSize; y++) {
        for (int x = 0; x < kModelInputSize; x++) {
          final int r = (p < rgbBytes.length) ? rgbBytes[p++] : 0;
          final int g = (p < rgbBytes.length) ? rgbBytes[p++] : 0;
          final int b = (p < rgbBytes.length) ? rgbBytes[p++] : 0;
          inputForInterpreter[0][y][x][0] = r;
          inputForInterpreter[0][y][x][1] = g;
          inputForInterpreter[0][y][x][2] = b;
        }
      }
    } else {
      throw Exception('Unsupported TFLite input type: $inputType');
    }

    // Prepare output container: 1 x num_classes
    final output = List.generate(
      1,
      (_) => List.filled(kModelLabels.length, 0.0),
    );

    // Run inference
    globalInterpreter!.run(inputForInterpreter, output);

    // Parse output to List<double>
    final List<double> rawScores = output[0]
        .map((e) => (e as num).toDouble())
        .toList();

    // Determine if softmax is needed
    List<double> probs;
    final double sumRaw = rawScores.fold(0.0, (a, b) => a + b);
    if (sumRaw > 0.99 && sumRaw < 1.01) {
      // Already probabilities (sum ≈ 1)
      probs = rawScores;
    } else {
      // Must be logits, apply softmax
      probs = _softmax(rawScores);
    }

    final double maxProb = probs.reduce((a, b) => a > b ? a : b);
    final int maxIdx = probs.indexOf(maxProb);
    final String mappedLabel = kModelLabels[maxIdx];
    final String finalLabel = (maxProb >= kConfidenceThreshold)
        ? mappedLabel
        : 'Unknown';

    debugPrint(
      '--- ANALYSIS RESULT for $fileName: $finalLabel (${(maxProb * 100).toStringAsFixed(1)}%) ---',
    );
    debugPrint(
      '--- Raw scores: ${rawScores.map((s) => s.toStringAsFixed(4)).toList()} -> probs: ${probs.map((s) => s.toStringAsFixed(4)).toList()}',
    );

    // Update the result object fields
    res.label = finalLabel;
    res.confidence = maxProb;
  } catch (e, st) {
    debugPrint('Analysis error for $fileName: $e');
    debugPrint('$st');
    res.label = 'Unknown';
    res.confidence = 0.0;
  } finally {
    res.isLoading = false; // State update is handled by caller
  }
}
