// analysis.dart
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

import 'config.dart'; // assumes sha256FromBytes is defined here

// ---------------- CONFIG FLAGS ----------------
// Toggle these to experiment without changing core code:
const bool kSwapRB = false; // if true, swap R and B channels (BGR)
const bool kNormalizeToMinusOneToOne =
    false; // if true -> (pixel/127.5)-1.0, else keep 0..255 (Colab)
const bool kUseNearest =
    true; // if true use nearest (Keras default), else use linear interpolation

// ---------------- HELPER: softmax ----------------
List<double> _softmax(List<double> logits) {
  final maxLogit = logits.reduce((a, b) => a > b ? a : b);
  final exps = logits.map((v) => math.exp(v - maxLogit)).toList();
  final sumExp = exps.reduce((a, b) => a + b);
  return exps.map((e) => e / sumExp).toList();
}

// ---------------- MAIN ANALYSIS ----------------
Future<void> runModelAnalysis(DetectionResult res) async {
  final fileName = res.file.uri.pathSegments.last;

  if (globalInterpreter == null) {
    debugPrint('Interpreter not ready - skipping analysis for $fileName');
    res.label = 'Unknown';
    res.confidence = 0.0;
    return;
  }

  res.isLoading = true;

  try {
    final startTime = DateTime.now();

    // Read file bytes and compute SHA256
    final Uint8List fileBytes = await res.file.readAsBytes();
    final imageHash = sha256FromBytes(fileBytes);
    debugPrint('Image SHA256: $imageHash');

    // Decode image and apply EXIF orientation
    var decoded = img.decodeImage(fileBytes);
    if (decoded == null) throw Exception('Could not decode image');
    decoded = img.bakeOrientation(decoded);

    // Resize (nearest or linear)
    final resized = img.copyResize(
      decoded,
      width: kModelInputSize,
      height: kModelInputSize,
      interpolation: kUseNearest
          ? img.Interpolation.nearest
          : img.Interpolation.linear,
    );

    // Get RGB bytes (row-major R,G,B,R,G,B,...)
    final Uint8List rgbBytes = resized.getBytes(order: img.ChannelOrder.rgb);
    final int expectedLen = kModelInputSize * kModelInputSize * 3;
    debugPrint(
      'Image: $fileName | decoded size: ${decoded.width}x${decoded.height} '
      '-> resized: ${resized.width}x${resized.height} | rgbBytes.length=${rgbBytes.length} expectedLen=$expectedLen',
    );

    // Raw pixel stats
    int minVal = 255, maxVal = 0, sum = 0;
    for (final v in rgbBytes) {
      if (v < minVal) minVal = v;
      if (v > maxVal) maxVal = v;
      sum += v;
    }
    final meanVal = rgbBytes.isNotEmpty ? sum / rgbBytes.length : 0.0;
    debugPrint(
      'Raw pixel stats -> min: $minVal, max: $maxVal, mean: ${meanVal.toStringAsFixed(2)}',
    );

    // Print first raw sample
    final rawSample = rgbBytes.sublist(0, math.min(27, rgbBytes.length));
    debugPrint('First raw bytes (R,G,B,...): $rawSample');

    // Print model hash once (avoid repeating)
    if (!_ModelHashTracker.printed) {
      try {
        final modelData = (await rootBundle.load(
          kModelAssetPath,
        )).buffer.asUint8List();
        final modelHash = sha256FromBytes(modelData);
        debugPrint('Model asset size: ${modelData.length} bytes');
        debugPrint('Model SHA256: $modelHash');
      } catch (e) {
        debugPrint('Model hash check failed: $e');
      }
      _ModelHashTracker.printed = true;
    }

    // Determine interpreter input type
    final inputType = globalInputType ?? TensorType.float32;
    debugPrint('Interpreter input type: $inputType');

    dynamic inputForInterpreter;
    final List<double> sampleNormalized = [];

    if (inputType == TensorType.float32) {
      // Build nested List [1][H][W][3] of doubles
      final input = List.generate(
        1,
        (_) => List.generate(
          kModelInputSize,
          (_) => List.generate(kModelInputSize, (_) => List.filled(3, 0.0)),
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

          // Decide channel order and normalization
          double
          v0,
          v1,
          v2; // final values for slots [0]=first channel, [1]=second, [2]=third

          // If normalization to [-1,1] desired:
          if (kNormalizeToMinusOneToOne) {
            final rn = (r / 127.5) - 1.0;
            final gn = (g / 127.5) - 1.0;
            final bn = (b / 127.5) - 1.0;

            if (kSwapRB) {
              v0 = bn;
              v1 = gn;
              v2 = rn;
            } else {
              v0 = rn;
              v1 = gn;
              v2 = bn;
            }
          } else {
            // Keep raw 0..255 as float32 (matches Colab img_to_array)
            final rn = r.toDouble();
            final gn = g.toDouble();
            final bn = b.toDouble();

            if (kSwapRB) {
              v0 = bn;
              v1 = gn;
              v2 = rn;
            } else {
              v0 = rn;
              v1 = gn;
              v2 = bn;
            }
          }

          input[0][y][x][0] = v0;
          input[0][y][x][1] = v1;
          input[0][y][x][2] = v2;

          // Collect a few for debug print
          if (sampleNormalized.length < 27) {
            sampleNormalized.addAll([v0, v1, v2]);
          }
        }
      }

      debugPrint(
        'First input sample (first 27 values): ${sampleNormalized.map((v) => v.toStringAsFixed(6)).toList()}',
      );
      inputForInterpreter = input;
    } else if (inputType == TensorType.uint8) {
      // For uint8 models: build nested List<int>
      final input = List.generate(
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

          if (kSwapRB) {
            input[0][y][x][0] = b;
            input[0][y][x][1] = g;
            input[0][y][x][2] = r;
            if (sampleNormalized.length < 27)
              sampleNormalized.addAll([
                b.toDouble(),
                g.toDouble(),
                r.toDouble(),
              ]);
          } else {
            input[0][y][x][0] = r;
            input[0][y][x][1] = g;
            input[0][y][x][2] = b;
            if (sampleNormalized.length < 27)
              sampleNormalized.addAll([
                r.toDouble(),
                g.toDouble(),
                b.toDouble(),
              ]);
          }
        }
      }

      debugPrint(
        'First raw pixels for uint8 model (first 27 ints): ${sampleNormalized.map((v) => v.toInt()).toList()}',
      );
      inputForInterpreter = input;
    } else {
      throw Exception('Unsupported TFLite input type: $inputType');
    }

    // Prepare output buffer and run interpreter
    final output = List.generate(
      1,
      (_) => List.filled(kModelLabels.length, 0.0),
    );
    final beforeInvoke = DateTime.now();
    debugPrint('Running inference for $fileName ...');
    globalInterpreter!.run(inputForInterpreter, output);
    final afterInvoke = DateTime.now();

    // Parse raw scores and probabilities
    final rawScores = output[0].map((e) => (e as num).toDouble()).toList();
    final sumRaw = rawScores.fold(0.0, (a, b) => a + b);
    final probs = (sumRaw > 0.99 && sumRaw < 1.01)
        ? rawScores
        : _softmax(rawScores);

    final maxProb = probs.reduce((a, b) => a > b ? a : b);
    final maxIdx = probs.indexOf(maxProb);

    final mappedLabelRaw = kModelLabels[maxIdx];
    final mappedLabelFriendly =
        kLabelFriendly[mappedLabelRaw] ?? mappedLabelRaw;
    final finalLabel = (maxProb >= kConfidenceThreshold)
        ? mappedLabelFriendly
        : 'Unknown';

    debugPrint(
      '--- ANALYSIS RESULT for $fileName: $finalLabel (${(maxProb * 100).toStringAsFixed(2)}%) ---',
    );
    debugPrint(
      'Predicted raw label: $mappedLabelRaw, friendly: $mappedLabelFriendly',
    );
    debugPrint(
      '--- Raw scores: ${rawScores.map((s) => s.toStringAsFixed(6)).toList()} -> probs: ${probs.map((s) => s.toStringAsFixed(6)).toList()}',
    );

    debugPrint(
      'Timing: preprocess ${(beforeInvoke.difference(startTime).inMilliseconds)} ms, inference ${(afterInvoke.difference(beforeInvoke).inMilliseconds)} ms, total ${(afterInvoke.difference(startTime).inMilliseconds)} ms',
    );

    // Update result object
    res.label = finalLabel;
    res.confidence = maxProb;
  } catch (e, st) {
    debugPrint('Analysis error for $fileName: $e');
    debugPrint('$st');
    res.label = 'Unknown';
    res.confidence = 0.0;
  } finally {
    res.isLoading = false;
  }
}

// ------------------------------------------------------
// Helper class to track model hash printing (only once)
// ------------------------------------------------------
class _ModelHashTracker {
  static bool printed = false;
}
