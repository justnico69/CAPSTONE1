import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
// Changed back to the original package as requested
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
  Timer? _timer;
  bool _isPaused = false;

  tfl.Interpreter? _interpreter;
  List<String> _labels = [];

  // Define model parameters
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
          .where((label) => label.isNotEmpty)
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
    });

    final imageBytes = await image.readAsBytes();
    final imageInput = img.decodeImage(imageBytes);
    if (imageInput == null) return;

    final resizedImage = img.copyResize(
      imageInput,
      width: _inputSize,
      height: _inputSize,
    );
    final imageBytesResized = resizedImage.getBytes(
      order: img.ChannelOrder.rgb,
    );
    final imageBuffer = Uint8List.fromList(imageBytesResized);
    final inputTensor = imageBuffer.reshape([1, _inputSize, _inputSize, 3]);
    final outputTensor = List.filled(
      1 * _labels.length,
      0.0,
    ).reshape([1, _labels.length]);

    _interpreter!.run(inputTensor, outputTensor);

    final probabilities = outputTensor[0] as List<double>;

    double maxScore = 0;
    int bestIndex = -1;
    for (int i = 0; i < probabilities.length; i++) {
      if (probabilities[i] > maxScore) {
        maxScore = probabilities[i];
        bestIndex = i;
      }
    }

    setState(() {
      _status = "Analysis Complete";
      if (bestIndex != -1 && maxScore > _confidenceThreshold) {
        _prediction = _labels[bestIndex];
        _confidence = maxScore;
      } else {
        _prediction = "Unknown";
        _confidence = maxScore;
      }
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

  @override
  Widget build(BuildContext context) {
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