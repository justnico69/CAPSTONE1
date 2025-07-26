import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

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
  final ImagePicker _picker = ImagePicker();
  bool _isScanning = true;

  Interpreter? _interpreter;
  List<String>? _labels;

  @override
  void initState() {
    super.initState();
    _loadModel();
    _startMonitoring();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _interpreter?.close();
    super.dispose();
  }

  Future<void> _loadModel() async {
    try {
      final interpreter = await Interpreter.fromAsset(
        'assets/models/spotato_model.tflite',
      );
      final labelsData = await rootBundle.loadString(
        'assets/models/labels.txt',
      );
      final labels = labelsData.split('\n');

      setState(() {
        _interpreter = interpreter;
        _labels = labels;
        _status = "Model loaded. Waiting for images...";
      });
    } catch (e) {
      setState(() {
        _status = "Failed to load model.";
      });
    }
  }

  Future<void> _analyzeImage(File image) async {
    if (_interpreter == null || _labels == null) {
      print("Error: Model not loaded.");
      return;
    }

    setState(() {
      _latestImage = image;
      _status = "New image found! Analyzing...";
      _prediction = "Analyzing...";
      _confidence = 0.0;
    });

    // 1. Preprocess the image
    final imageBytes = await image.readAsBytes();
    img.Image? originalImage = img.decodeImage(imageBytes);
    img.Image resizedImage = img.copyResize(
      originalImage!,
      width: 224,
      height: 224,
      interpolation: img.Interpolation.nearest,
    );

    var inputTensor = Float32List(1 * 224 * 224 * 3);
    var bufferIndex = 0;
    for (var y = 0; y < 224; y++) {
      for (var x = 0; x < 224; x++) {
        var pixel = resizedImage.getPixel(x, y);
        inputTensor[bufferIndex++] = (pixel.r - 127.5) / 127.5;
        inputTensor[bufferIndex++] = (pixel.g - 127.5) / 127.5;
        inputTensor[bufferIndex++] = (pixel.b - 127.5) / 127.5;
      }
    }
    var reshapedInput = inputTensor.reshape([1, 224, 224, 3]);

    // --- DEBUGGING STEP 1: PRINT INPUT TENSOR ---
    print('--- PREPROCESSING ---');
    print('First 5 values of input tensor: ${inputTensor.sublist(0, 5)}');

    // 2. Define the output tensor
    var outputTensor = List.filled(
      1 * _labels!.length,
      0.0,
    ).reshape([1, _labels!.length]);

    // 3. Run inference
    _interpreter!.run(reshapedInput, outputTensor);

    // --- DEBUGGING STEP 2: PRINT OUTPUT TENSOR ---
    print('--- INFERENCE ---');
    print('Raw output tensor: $outputTensor');

    // 4. Process the output
    List<double> output = outputTensor[0];
    double maxConfidence = 0;
    int maxIndex = -1;
    for (int i = 0; i < output.length; i++) {
      if (output[i] > maxConfidence) {
        maxConfidence = output[i];
        maxIndex = i;
      }
    }

    String rawPrediction = _labels![maxIndex];
    String displayPrediction;

    if (rawPrediction.contains("Fungi") ||
        rawPrediction.contains("Phytopthora") ||
        rawPrediction.contains("Blight")) {
      displayPrediction = "Blight Detected";
    } else if (rawPrediction.contains("Healthy")) {
      displayPrediction = "Healthy";
    } else {
      displayPrediction = rawPrediction.replaceAll('_', ' ');
    }

    // --- DEBUGGING STEP 3: PRINT FINAL RESULT ---
    print('--- RESULT ---');
    print('Predicted raw label: $rawPrediction');
    print('Final display prediction: $displayPrediction');

    // 5. Update the UI
    setState(() {
      _status = "Analysis Complete";
      _prediction = displayPrediction;
      _confidence = maxConfidence;
    });
  }

  Future<void> _pickImageFromGallery() async {
    setState(() {
      _isScanning = false;
      _status = "Manual selection: Paused scanning";
    });
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
    );
    if (pickedFile != null) {
      await _analyzeImage(File(pickedFile.path));
    }
  }

  void _startMonitoring() {
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_isScanning) {
        _scanForNewImage();
      }
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
        final files =
            imageDir
                .listSync()
                .where(
                  (item) =>
                      item.path.endsWith(".jpg") || item.path.endsWith(".png"),
                )
                .toList()
              ..sort(
                (a, b) =>
                    b.statSync().modified.compareTo(a.statSync().modified),
              );
        if (files.isEmpty) return;
        final newImageFile = File(files.first.path);
        final modifiedTime = await newImageFile.lastModified();
        final timeDifference = DateTime.now().difference(modifiedTime);

        if (timeDifference.inSeconds < 15 &&
            _latestImage?.path != newImageFile.path) {
          await _analyzeImage(newImageFile);
        }
      }
    } catch (e) {
      // Handle exceptions
    }
  }

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
            icon: Icon(
              _isScanning
                  ? Icons.pause_circle_filled
                  : Icons.play_circle_filled,
            ),
            color: _isScanning ? Colors.redAccent : Colors.green,
            onPressed: () {
              setState(() {
                _isScanning = !_isScanning;
                _status = _isScanning
                    ? "Automatic scanning active..."
                    : "Automatic scanning paused.";
              });
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _pickImageFromGallery,
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.photo_library),
        label: Text("Select Manually", style: GoogleFonts.poppins()),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.05),
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
                          child: Image.file(_latestImage!, fit: BoxFit.cover),
                        )
                      : const Icon(
                          Icons.image_search,
                          size: 80,
                          color: Colors.black12,
                        ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              flex: 2,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
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
                        color: _prediction.contains("Blight")
                            ? Colors.redAccent
                            : Colors.green,
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
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
                          color: _prediction.contains("Blight")
                              ? Colors.redAccent
                              : Colors.green,
                          minHeight: 8,
                        ),
                      ],
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
