import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:tflite_flutter/tflite_flutter.dart' as tfl;

import 'detection_result.dart';
import 'history_page.dart'; // Import the history page
import 'history_storage.dart';

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
  Timer? _timer;
  bool _isPaused = false;

  tfl.Interpreter? _interpreter;
  List<String> _labels = [];

  Duration? _analysisDuration;
  DateTime? _analysisTimestamp;

  // Model parameters
  final int _inputSize = 224;
  final double _confidenceThreshold = 0.8;

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
      print("Model loaded successfully.");
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
      print("Error: Interpreter or labels not loaded.");
      return;
    }

    final startTime = DateTime.now();

    setState(() {
      _latestImage = image;
      _status = "Analyzing image...";
      _prediction = "Analyzing...";
      _confidence = 0.0;
      _analysisDuration = null;
      _analysisTimestamp = null;
    });

    try {
      final imageBytes = await image.readAsBytes();
      final imageInput = img.decodeImage(imageBytes);
      if (imageInput == null) {
        setState(() {
          _status = "Failed to decode image.";
        });
        print("Failed to decode image at path: ${image.path}");
        return;
      }

      final resizedImage = img.copyResize(
        imageInput,
        width: _inputSize,
        height: _inputSize,
      );
      final imageBytesResized = resizedImage.getBytes(
        order: img.ChannelOrder.rgb,
      );
      final imageBuffer = Uint8List.fromList(imageBytesResized);

      final input = imageBuffer.reshape([1, _inputSize, _inputSize, 3]);
      final output = List.generate(1, (_) => List.filled(_labels.length, 0.0));

      _interpreter!.run(input, output);

      final endTime = DateTime.now();
      final probabilities = output[0] as List<double>;

      double maxScore = 0.0;
      int bestIndex = -1;
      for (int i = 0; i < probabilities.length; i++) {
        if (probabilities[i] > maxScore) {
          maxScore = probabilities[i];
          bestIndex = i;
        }
      }

      // --- DEBUGGING STATEMENTS ---
      print("\n--- Analysis Results ---");
      print("Analysis Started: ${DateFormat('h:mm:ss a').format(startTime)}");
      print("Best Index: $bestIndex");
      print("Max Confidence: ${maxScore.toStringAsFixed(4)}");
      if (bestIndex != -1) {
        print("Predicted Label: ${_labels[bestIndex]}");
      } else {
        print("Predicted Label: Unknown");
      }
      print("--------------------------\n");

      setState(() {
        _status = "Analysis Complete";
        _analysisDuration = endTime.difference(startTime);
        _analysisTimestamp = endTime;
        if (bestIndex != -1 && maxScore > _confidenceThreshold) {
          _prediction = _labels[bestIndex];
          _confidence = maxScore;
        } else {
          _prediction = "Unknown";
          _confidence = maxScore;
        }
      });
    } catch (e) {
      setState(() {
        _status = "Analysis error: $e";
      });
      print("Error during analysis: $e");
    }
  }

  Future<void> _startMonitoring() async {
    if (_interpreter == null) return;
    setState(() {
      _status = "Scanning for new images...";
    });
    print("Starting periodic scan for new images...");
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
        print("Scanning paused.");
      } else {
        _startMonitoring();
        print("Scanning resumed.");
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
      print("User picked an image: ${pickedFile.path}");
      await _runAnalysis(File(pickedFile.path));
      if (_prediction != '---' && _confidence > _confidenceThreshold) {
        print("Prediction meets threshold. Saving to history...");
        HistoryStorage().addResult(
          DetectionResult(
            image: _latestImage!,
            prediction: _prediction,
            confidence: _confidence,
            dateCaptured: _analysisTimestamp ?? DateTime.now(),
          ),
        );
        print("Data saved.");
      } else {
        print("Prediction does not meet threshold. Not saving.");
      }
    } else {
      print("No image was picked from the gallery.");
    }
  }

  Future<void> _scanForNewImage() async {
    var status = await Permission.photos.request();
    if (!status.isGranted) {
      print("Permission to access photos not granted.");
      return;
    }

    try {
      final Directory? externalDir = await getExternalStorageDirectory();
      if (externalDir == null) {
        print("Could not get external storage directory.");
        return;
      }

      final String rootPath = externalDir.path.split('/Android')[0];
      final String imagePath = '$rootPath/DCIM/Camera';
      final Directory imageDir = Directory(imagePath);

      print("Scanning directory: $imagePath");

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

        if (imageFiles.isEmpty) {
          print("No image files found in DCIM/Camera.");
          return;
        }

        File newImage = File(imageFiles.first.path);

        // This is a crucial check. It prevents re-analyzing the same image.
        if (_latestImage?.path != newImage.path) {
          print("New image found: ${newImage.path}. Analyzing...");
          _latestImage = newImage;
          await _runAnalysis(newImage);

          // Check if a valid prediction was made and confidence is high enough.
          if (_prediction != '---' &&
              _prediction != "Unknown" &&
              _confidence > _confidenceThreshold) {
            print("Prediction meets threshold. Saving to history...");
            HistoryStorage().addResult(
              DetectionResult(
                image: _latestImage!,
                prediction: _prediction,
                confidence: _confidence,
                dateCaptured: _analysisTimestamp ?? DateTime.now(),
              ),
            );
            print("Data saved.");
          } else {
            print(
              "Prediction does not meet threshold or is invalid. Not saving.",
            );
          }
        } else {
          print("No new image found since last scan.");
        }
      } else {
        print("DCIM/Camera directory does not exist.");
      }
    } catch (e) {
      print("Error scanning for image: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.grey[200],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Color.fromARGB(255, 128, 68, 12)),
        title: Text(
          'Detector',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: const Color.fromARGB(255, 128, 68, 12),
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
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const HistoryPage()),
              );
            },
            icon: const Icon(Icons.history),
            tooltip: 'View History',
          ),
        ],
      ),
      // --- BODY IS NOW A STACK TO POSITION THE BUTTON ---
      body: Stack(
        children: [
          // This SingleChildScrollView contains all of your page content
          SingleChildScrollView(
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
                    child: Text(
                      _status,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.lato(
                        fontSize: 16,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    height: screenHeight * 0.4,
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
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(20),
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
                            color: const Color.fromARGB(255, 128, 68, 12),
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Divider(height: 24),
                        _buildDetailRow(
                          icon: Icons.biotech,
                          label: "Prediction",
                          value: _prediction,
                          valueColor: _confidence > 0.9
                              ? Colors.redAccent
                              : Colors.green,
                        ),
                        const SizedBox(height: 16),
                        _buildDetailRow(
                          icon: Icons.insights,
                          label: "Confidence",
                          value: "${(_confidence * 100).toStringAsFixed(2)}%",
                          valueColor: const Color.fromARGB(255, 128, 68, 12),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 8.0,
                            horizontal: 8.0,
                          ),
                          child: LinearProgressIndicator(
                            value: _confidence,
                            backgroundColor: Colors.grey.shade300,
                            color: _confidence > 0.9
                                ? Colors.redAccent
                                : Colors.green,
                            minHeight: 8,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildDetailRow(
                          icon: Icons.timer,
                          label: "Analysis Duration",
                          value: _analysisDuration != null
                              ? "${_analysisDuration?.inMilliseconds} ms"
                              : "---",
                          valueColor: const Color.fromARGB(255, 128, 68, 12),
                        ),
                        const SizedBox(height: 16),
                        _buildDetailRow(
                          icon: Icons.calendar_today,
                          label: "Date Captured",
                          value: _analysisTimestamp != null
                              ? DateFormat(
                                  'MMMM d, yyyy',
                                ).format(_analysisTimestamp!)
                              : "---",
                          valueColor: const Color.fromARGB(255, 128, 68, 12),
                        ),
                        const SizedBox(height: 16),
                        _buildDetailRow(
                          icon: Icons.access_time_filled,
                          label: "Time Captured",
                          value: _analysisTimestamp != null
                              ? DateFormat('h:mm a').format(_analysisTimestamp!)
                              : "---",
                          valueColor: const Color.fromARGB(255, 128, 68, 12),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(
                    height: 10,
                  ), // Space so the FAB doesn't cover content
                ],
              ),
            ),
          ),
          // This is the FloatingActionButton, positioned within the Stack
          Positioned(
            bottom: 30, // Adjust this value to move it higher or lower
            right: 24, // Adjust this for padding from the right edge
            child: FloatingActionButton(
              onPressed: _pickImage,
              backgroundColor: const Color(0xFFEAA944),
              foregroundColor: Colors.white,
              splashColor: const Color(0xFFEAA944),
              tooltip: 'Select Image',
              child: const Icon(Icons.photo_library),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Row(
      children: [
        Icon(icon, color: Colors.grey[600], size: 20),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: GoogleFonts.lato(color: Colors.grey, fontSize: 12),
            ),
            Text(
              value,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: valueColor ?? Colors.black87,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
