import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

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

  @override
  void initState() {
    super.initState();
    _startMonitoring();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _startMonitoring() async {
    setState(() {
      _status = "Waiting for new images...";
    });

    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _scanForNewImage();
    });
  }

  Future<void> _scanForNewImage() async {
    var status = await Permission.photos.request();
    if (!status.isGranted) {
      setState(() {
        _status = "Permission denied. Please enable in settings.";
      });
      return;
    }

    try {
      final Directory? externalDir = await getExternalStorageDirectory();
      if (externalDir == null) {
        setState(() {
          _status = "Could not access storage.";
        });
        return;
      }

      final String rootPath = externalDir.path.split('/Android')[0];
      final String imagePath = '$rootPath/DCIM/Camera';
      final Directory imageDir = Directory(imagePath);

      if (await imageDir.exists()) {
        final List<FileSystemEntity> files = imageDir.listSync();
        if (files.isEmpty) return;

        files.sort(
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
          setState(() {
            _latestImage = newImage;
            _status = "New image found! Analyzing...";
            _prediction = "Analyzing...";
            _confidence = 0.0;
          });
          // --- AI ANALYSIS WOULD GO HERE ---
          Future.delayed(const Duration(seconds: 2), () {
            setState(() {
              _status = "Analysis Complete";
              _prediction = "Late Blight"; // Placeholder result
              _confidence = 0.97; // Placeholder confidence
            });
          });
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
                        color: _confidence > 0.9
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
                          color: _confidence > 0.9
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
