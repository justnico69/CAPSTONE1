import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:tflite_flutter/tflite_flutter.dart' as tfl; // Import TFLite

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

  tfl.Interpreter? _interpreter; // Variable to hold the TFLite model

  @override
  void initState() {
    super.initState();
    // Load the model and then start monitoring for images
    _loadModel().then((_) {
      _startMonitoring();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _interpreter?.close(); // Close the interpreter when the page is disposed
    super.dispose();
  }

  // --- MODEL AND SCANNING LOGIC ---

  Future<void> _loadModel() async {
    setState(() {
      _status = "Loading model...";
    });
    try {
      // Load the model from the assets folder
      _interpreter = await tfl.Interpreter.fromAsset(
        'assets/models/model.tflite',
      );
      setState(() {
        _status = "Model loaded successfully. Waiting for images...";
      });
    } catch (e) {
      setState(() {
        _status = "Failed to load model. Error: $e";
      });
      print("Error loading model: $e");
    }
  }

  Future<void> _startMonitoring() async {
    // Only start if the model was loaded successfully
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

  void _runAnalysis(File image) {
    if (_interpreter == null) {
      setState(() {
        _status = "Model is not loaded.";
      });
      return;
    }

    setState(() {
      _latestImage = image;
      _status = "Analyzing image...";
      _prediction = "Analyzing...";
      _confidence = 0.0;
    });

    // --- Placeholder for your AI prediction logic ---
    // 1. Pre-process the image (resize, normalize) to match your model's input.
    // 2. Create input and output tensors.
    // 3. Run inference: _interpreter.run(input, output);
    // 4. Decode the output to get the prediction and confidence.
    // ----------------------------------------------------

    // We'll use a placeholder delay to simulate analysis
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() {
        _status = "Analysis Complete";
        _prediction = "Late Blight"; // Placeholder result
        _confidence = 0.97; // Placeholder confidence
      });
    });
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
                  file.path.endsWith('.jpg') || file.path.endsWith('.png'),
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

  // --- UI BUILD METHOD ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: Text(
          'SPOTATO Detector',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.black87,
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
      body: Padding(
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
                style: GoogleFonts.lato(fontSize: 16, color: Colors.black54),
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
            Expanded(
              flex: 2,
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Analysis Result",
                          style: GoogleFonts.poppins(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Divider(),
                        Text(
                          _prediction,
                          style: GoogleFonts.poppins(
                            fontSize: 28,
                            fontWeight: FontWeight.w600,
                            color: _confidence > 0.9
                                ? Colors.redAccent
                                : Colors.green,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          "CONFIDENCE",
                          style: GoogleFonts.lato(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                        LinearProgressIndicator(
                          value: _confidence,
                          backgroundColor: Colors.grey.shade300,
                          color: _confidence > 0.9
                              ? Colors.redAccent
                              : Colors.green,
                          minHeight: 8,
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                    Positioned(
                      bottom: 8,
                      right: 0,
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
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
