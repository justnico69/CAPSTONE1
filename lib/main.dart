import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'landing_page.dart';

void main() {
  runApp(const SPOTATOApp());
}

class SPOTATOApp extends StatelessWidget {
  const SPOTATOApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SPOTATO',
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.green,
        scaffoldBackgroundColor: const Color(0xFF1c1c1e),
        appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF2c2c2e)),
      ),
      home: const LandingPage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  File? _latestImage;
  String _status = "Initializing...";
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
    var status = await Permission.photos.request();
    if (status.isGranted) {
      setState(() {
        _status = "Scanning for Tello images...";
      });
      _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
        _scanForNewImage();
      });
    } else {
      setState(() {
        _status = "Storage permission denied. Please enable it in settings.";
      });
    }
  }

  Future<void> _scanForNewImage() async {
    try {
      final Directory? externalDir = await getExternalStorageDirectory();
      if (externalDir == null) {
        setState(() {
          _status = "Could not access external storage.";
        });
        return;
      }

      // --- THIS IS THE UPDATED PART ---
      // Pointing to the Tello folder from your screenshot
      final String rootPath = externalDir.path.split('/Android')[0];
      final String telloPath = '$rootPath/DCIM/Camera';
      final Directory imageDir = Directory(telloPath);
      // --- END OF UPDATE ---

      if (await imageDir.exists()) {
        final List<FileSystemEntity> files = imageDir.listSync();
        if (files.isEmpty) {
          setState(() {
            _status = "Tello folder is empty. Capture an image.";
          });
          return;
        }

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

        File latest = File(imageFiles.first.path);

        if (_latestImage?.path != latest.path) {
          setState(() {
            _latestImage = latest;
            _status = "New Tello image detected!";
          });
        }
      } else {
        setState(() {
          _status = "Tello directory not found.\nExpected at: $telloPath";
        });
      }
    } catch (e) {
      setState(() {
        _status = "An error occurred: $e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("SPOTATO - Image Detector")),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                _status,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: Colors.white70),
              ),
              const SizedBox(height: 20),
              _latestImage != null
                  ? Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.green, width: 2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.file(
                            _latestImage!,
                            fit: BoxFit.contain,
                            key: ValueKey(_latestImage!.path),
                          ),
                        ),
                      ),
                    )
                  : const Expanded(
                      child: Center(
                        child: Icon(
                          Icons.image_search,
                          size: 100,
                          color: Colors.white24,
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