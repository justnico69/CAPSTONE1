import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:tflite_flutter/tflite_flutter.dart' as tfl;

class DetectorPage extends StatefulWidget {
  const DetectorPage({super.key});

  @override
  State<DetectorPage> createState() => _DetectorPageState();
}

class _DetectorPageState extends State<DetectorPage> {
  File? _latestImage;
  String _status = "Initializing...";
  String _prediction = "---";
  double _confidence = 0.0;
  String _analysisTime = "";
  Duration? _analysisDuration;
  DateTime? _dateCaptured;
  Timer? _timer;
  bool _isPaused = false;

  tfl.Interpreter? _interpreter;
  List<String> _labels = [];

  // Model parameters
  final int _inputSize = 224;
  final double _confidenceThreshold = 0.8; // 80% confidence needed

  @override
  void initState() {
    super.initState();
    _loadModelAndLabels().then((_) {
      _startMonitoring();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _interpreter?.close();
    super.dispose();
  }

  Future<void> _loadModelAndLabels() async {
    setState(() {
      _status = "Loading model...";
    });
    try {
      _interpreter = await tfl.Interpreter.fromAsset(
        'assets/models/model.tflite',
      );
      final labelsData = await rootBundle.loadString(
        'assets/models/labels.txt',
      );
      _labels = labelsData
          .split('\n')
          .where((label) => label.trim().isNotEmpty)
          .toList();
      setState(() {
        _status = "Model loaded successfully.";
      });
    } catch (e) {
      setState(() {
        _status = "Failed to load model. Error: $e";
      });
      print("Error loading model: $e");
    }
  }

  Future<void> _runAnalysis(File image) async {
    if (_interpreter == null || _labels.isEmpty) {
      setState(() {
        _status = "Model or labels not loaded.";
      });
      return;
    }

    setState(() {
      _latestImage = image;
      _status = "Analyzing image...";
      _prediction = "Analyzing...";
      _confidence = 0.0;
      _analysisDuration = null;
      _analysisTime = "";
      _dateCaptured = null;
    });

    try {
      final stat = await image.stat();
      _dateCaptured = stat.modified.toLocal();
    } catch (e) {
      _dateCaptured = DateTime.now().toLocal();
    }

    final start = DateTime.now();

    final imageBytes = await image.readAsBytes();
    final imageInput = img.decodeImage(imageBytes);
    if (imageInput == null) {
      setState(() {
        _status = "Failed to decode image.";
      });
      return;
    }

    final resizedImage = img.copyResize(
      imageInput,
      width: _inputSize,
      height: _inputSize,
    );

    final Uint8List imageBytesResized = resizedImage.getBytes(
      order: img.ChannelOrder.rgb,
    );

    final int expectedLen = _inputSize * _inputSize * 3;
    if (imageBytesResized.length != expectedLen) {
      setState(() {
        _status = "Unexpected image byte length: ${imageBytesResized.length}";
      });
      return;
    }

    final List<double> normalized = List<double>.generate(
      imageBytesResized.length,
      (i) => imageBytesResized[i] / 255.0,
    );

    final input = List.generate(
      1,
      (_) => List.generate(
        _inputSize,
        (y) => List.generate(
          _inputSize,
          (x) =>
              List.generate(3, (c) => normalized[(y * _inputSize + x) * 3 + c]),
        ),
      ),
    );

    final output = List.generate(1, (_) => List.filled(_labels.length, 0.0));

    try {
      _interpreter!.run(input, output);
    } catch (e) {
      setState(() {
        _status = "Inference error: $e";
      });
      print("TFLite run error: $e");
      return;
    }

    final end = DateTime.now();
    final probabilities = output[0] as List<double>;

    double maxScore = 0.0;
    int bestIndex = -1;
    for (int i = 0; i < probabilities.length; i++) {
      if (probabilities[i] > maxScore) {
        maxScore = probabilities[i];
        bestIndex = i;
      }
    }

    String finalPrediction;

    if (maxScore < _confidenceThreshold) {
      finalPrediction = "Unknown";
    } else {
      String predictedLabel = _labels[bestIndex].trim();

      if (predictedLabel.toLowerCase() == 'healthy') {
        finalPrediction = "Healthy";
      } else {
        finalPrediction = "Blight Detected";
      }
    }

    setState(() {
      _status = "Analysis Complete";
      _analysisTime = end.toLocal().toIso8601String();
      _analysisDuration = end.difference(start);
      _confidence = maxScore;
      _prediction = finalPrediction;
    });
  }

  Future<void> _startMonitoring() async {
    if (_interpreter == null) return;
    setState(() {
      _status = "Scanning for new images...";
    });
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!_isPaused) {
        _scanForNewImage();
      }
    });
  }

  void _togglePause() {
    setState(() {
      _isPaused = !_isPaused;
      if (_isPaused) {
        _timer?.cancel();
        _status = "Scanning Paused";
      } else {
        _startMonitoring();
      }
    });
  }

  Future<void> _pickImage() async {
    if (_timer?.isActive ?? false) {
      _timer?.cancel();
      setState(() {
        _isPaused = true;
      });
    }
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      _runAnalysis(File(pickedFile.path));
    }
  }

  Future<void> _scanForNewImage() async {
    var status = await Permission.photos.request();
    if (!status.isGranted) return;
    try {
      final Directory? externalDir = await getExternalStorageDirectory();
      if (externalDir == null) return;
      final String rootPath = externalDir.path.split('/Android')[0];
      final String imagePath = '$rootPath/DCIM/Camera';
      final Directory imageDir = Directory(imagePath);

      if (await imageDir.exists()) {
        final List<FileSystemEntity> files = imageDir.listSync()
          ..sort(
            (a, b) => b.statSync().modified.compareTo(a.statSync().modified),
          );
        final imageFiles = files
            .where(
              (file) =>
                  file.path.toLowerCase().endsWith('.jpg') ||
                  file.path.toLowerCase().endsWith('.png'),
            )
            .toList();
        if (imageFiles.isEmpty) return;
        File newImage = File(imageFiles.first.path);
        if (_latestImage?.path != newImage.path) {
          _runAnalysis(newImage);
        }
      }
    } catch (e) {
      print("Error scanning for image: $e");
    }
  }

  // --- Formatting Helpers ---
  String _formatConfidence(double v) {
    final pct = (v * 100).round();
    return "$pct%";
  }

  String _formatDuration(Duration? d) {
    if (d == null) return "--";
    // Updated to show integer seconds
    return "${d.inSeconds.toString().padLeft(2, '0')} secs";
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return "--/--/----";
    final dd = dt.day.toString().padLeft(2, '0');
    final mm = dt.month.toString().padLeft(2, '0');
    final yyyy = dt.year.toString();
    return "$dd/$mm/$yyyy";
  }

  String _formatTimeShort(DateTime? dt) {
    if (dt == null) return "--:--";
    final hour = dt.hour;
    final minute = dt.minute.toString().padLeft(2, '0');
    final ampm = hour >= 12 ? 'pm' : 'am';
    final hour12 = (hour % 12 == 0) ? 12 : hour % 12;
    return "$hour12:$minute$ampm";
  }

  @override
  Widget build(BuildContext context) {
    final confidenceText = _formatConfidence(_confidence);
    final durationText = _formatDuration(_analysisDuration);
    final dateText = _formatDate(_dateCaptured);
    final timeText = _formatTimeShort(_dateCaptured);

    Color getPredictionColor() {
      switch (_prediction) {
        case "Blight Detected":
          return Colors.redAccent;
        case "Healthy":
          return Colors.green;
        case "Unknown":
          return Colors.orange.shade800;
        default:
          return Colors.black87;
      }
    }

    TextStyle labelStyle = GoogleFonts.lato(
      fontSize: 14,
      color: Colors.grey[700],
    );
    TextStyle valueStyle = GoogleFonts.poppins(
      fontSize: 15,
      fontWeight: FontWeight.bold,
      color: const Color(0xFFB8860B), // Brown/Gold color from image
    );

    return Scaffold(
      backgroundColor: Colors.grey[200],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color:Color.fromARGB(255, 128, 68, 12)),

        title: Text(
          'Detector',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color.fromARGB(255, 128, 68, 12),
          ),
        ),
        actions: [
          IconButton(
            onPressed: _togglePause,
            icon: Icon(
              _isPaused ? Icons.play_arrow : Icons.pause_circle_filled,
              color: Colors.red,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
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
                
                child: Center(
                  child: _latestImage != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(11),
                          child: Image.file(
                            _latestImage!,
                            fit: BoxFit.cover,
                            width: 300,
                          ),
                        )
                      : Icon(
                          Icons.image_search,
                          size: 80,
                          color: Colors.grey.shade300,
                        ),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                flex: 3,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Center(
                    child: _latestImage != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(11),
                            child: Image.file(
                              _latestImage!,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                            ),
                          )
                        : Icon(
                            Icons.image_search,
                            size: 80,
                            color: Colors.grey.shade300,
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // --- REVISED CLASSIFICATION CARD ---
              Expanded(
                flex: 2,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 20,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Classification Result",
                          style: GoogleFonts.poppins(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Divider(),
                        const SizedBox(height: 4),
                        Text(
                          _prediction,
                          style: GoogleFonts.poppins(
                            fontSize: 28,
                            fontWeight: FontWeight.w600,
                            color: getPredictionColor(),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // --- NEW UI LAYOUT AS PER IMAGE ---
                        Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  "Confidence level",
                                  style: labelStyle,
                                ),
                              ),
                              Text(confidenceText, style: valueStyle),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 4,
                            horizontal: 12,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  "Duration of analysis",
                                  style: labelStyle,
                                ),
                              ),
                              Text(durationText, style: valueStyle),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text("Date Captured", style: labelStyle),
                              ),
                              Text(dateText, style: valueStyle),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 4,
                            horizontal: 12,
                          ),
                          child: Row(
                            children: [
                              Expanded(child: Text("Time", style: labelStyle)),
                              Text(timeText, style: valueStyle),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // --- END OF NEW UI LAYOUT ---
                        Align(
                          alignment: Alignment.centerRight,
                          child: ElevatedButton.icon(
                            onPressed: _pickImage,
                            icon: const Icon(Icons.photo_library),
                            label: const Text("Select Manually"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}