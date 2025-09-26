import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:installed_apps/app_info.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

// =========================================================================
// 3. DATA MODEL
// =========================================================================

class _DetectionResult {
  final File file;
  bool isLoading = false;
  String? label;
  double confidence = 0.0; // Initialize confidence to 0.0

  _DetectionResult({required this.file});
}

// =========================================================================
// 1. ALBUM DETAIL SCREEN (Manages Rows)
// =========================================================================

class AlbumDetail extends StatefulWidget {
  final String albumName; // e.g. "2025-09-30"
  final String date;
  const AlbumDetail({Key? key, required this.albumName, required this.date})
    : super(key: key);

  @override
  _AlbumDetailState createState() => _AlbumDetailState();
}

class _AlbumDetailState extends State<AlbumDetail> {
  List<String> _rows = [];
  String _telloPackage = ''; // State to hold the Tello package name

  @override
  void initState() {
    super.initState();
    _loadRows();
    _checkTelloApp(); // Check Tello app status on page load
  }

  // Method to check for Tello App
  Future<void> _checkTelloApp() async {
    List<AppInfo> apps = await InstalledApps.getInstalledApps(true, true);
    String packageName = '';

    for (var app in apps) {
      if (app.packageName == "com.ryzerobotics.tello") {
        packageName = app.packageName;
        break;
      }
    }

    if (mounted) {
      setState(() {
        _telloPackage = packageName;
      });
    }
  }

  Future<Directory> _getAlbumDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final albumDir = Directory("${dir.path}/SPOTATO/${widget.albumName}");
    if (!await albumDir.exists()) {
      await albumDir.create(recursive: true);
    }
    return albumDir;
  }

  Future<void> _loadRows() async {
    final albumDir = await _getAlbumDir();
    final subdirs = albumDir.listSync().whereType<Directory>();
    if (mounted) {
      setState(() {
        _rows = subdirs.map((d) => d.path.split("/").last).toList();
      });
    }
  }

  Future<void> _addRow() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Add Row/Column"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: "Enter name e.g. ROW1"),
        ),
        actions: [
          TextButton(
            child: const Text("Cancel"),
            onPressed: () => Navigator.pop(ctx),
          ),
          TextButton(
            child: const Text("Add"),
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
          ),
        ],
      ),
    );

    if (name != null && name.isNotEmpty) {
      final albumDir = await _getAlbumDir();
      final rowDir = Directory("${albumDir.path}/$name");
      if (!await rowDir.exists()) {
        await rowDir.create();
      }
      _loadRows();
    }
  }

  Future<void> _deleteRow(String rowName) async {
    final albumDir = await _getAlbumDir();
    final rowDir = Directory("${albumDir.path}/$rowName");
    if (await rowDir.exists()) {
      await rowDir.delete(recursive: true);
      _loadRows();
    }
  }

  void _openRow(String rowName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RowDetailPage(
          albumName: widget.albumName,
          rowName: rowName,
          telloPackage: _telloPackage, // Pass the discovered Tello package name
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.albumName),
        actions: [IconButton(icon: const Icon(Icons.add), onPressed: _addRow)],
      ),
      body: ListView.builder(
        itemCount: _rows.length,
        itemBuilder: (ctx, i) {
          final row = _rows[i];
          return ListTile(
            title: Text(row),
            trailing: IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _deleteRow(row),
            ),
            onTap: () => _openRow(row),
          );
        },
      ),
    );
  }
}

// =========================================================================
// 2. ROW DETAIL SCREEN (TFLite Integration)
// =========================================================================

class RowDetailPage extends StatefulWidget {
  final String albumName;
  final String rowName;
  final String telloPackage; // Now received from AlbumDetail

  const RowDetailPage({
    Key? key,
    required this.albumName,
    required this.rowName,
    required this.telloPackage, // Added to constructor
  }) : super(key: key);

  @override
  _RowDetailPageState createState() => _RowDetailPageState();
}

class _RowDetailPageState extends State<RowDetailPage> {
  final picker = ImagePicker();
  Interpreter? _interpreter;
  // NOTE: Assuming 300x300 for EfficientNetB3 as mentioned in your prompt
  final int _inputSize = 300;
  final List<String> _labels = ["Healthy", "Early Blight", "Late Blight"];
  // ⚠️ IMPORTANT: Update this if your file structure is different (e.g., 'assets/models/potato_model.tflite')
  final String _modelPath = 'assets/models/model.tflite';

  List<_DetectionResult> _results = [];

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    // 1. Load the model first and await its completion
    await _loadModel();
    // 2. Then, load the images and start analysis on any new ones
    _loadImages();
  }

  @override
  void dispose() {
    _interpreter?.close();
    super.dispose();
  }

  Future<void> _loadModel() async {
    debugPrint(
      "--- TFLITE: Attempting to load model from asset: $_modelPath ---",
    );
    try {
      _interpreter = await Interpreter.fromAsset(_modelPath);
      debugPrint("--- TFLITE: Model loaded successfully! ---");
    } catch (e) {
      debugPrint(
        "!!! TFLITE ERROR: Failed to load TFLite model from $_modelPath: $e !!!",
      );
    }
  }

  Future<Directory> _getRowDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final rowDir = Directory(
      "${dir.path}/SPOTATO/${widget.albumName}/${widget.rowName}",
    );
    if (!await rowDir.exists()) {
      await rowDir.create(recursive: true);
    }
    return rowDir;
  }

  Future<void> _loadImages() async {
    final rowDir = await _getRowDir();
    final files = rowDir.listSync().whereType<File>().toList();

    final existingResultsMap = Map.fromIterable(
      _results,
      key: (r) => r.file.path,
    );

    final newResults = files.map((f) {
      if (existingResultsMap.containsKey(f.path)) {
        return existingResultsMap[f.path] as _DetectionResult;
      }
      return _DetectionResult(file: f);
    }).toList();

    if (mounted) {
      setState(() {
        _results = newResults;
      });
    }

    // Run detection for any new images without a label
    for (var res in _results.where((r) => r.label == null)) {
      _runAnalysis(res);
    }
  }

  Future<void> _pickFromGallery() async {
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      final rowDir = await _getRowDir();
      final name = picked.path.split('/').last;
      final dest = File("${rowDir.path}/$name");

      await File(picked.path).copy(dest.path);

      final newRes = _DetectionResult(file: dest);

      if (mounted) {
        setState(() {
          _results.add(newRes);
        });
      }
      _runAnalysis(newRes);
    }
  }

  Future<void> launchTello() async {
    if (widget.telloPackage.isNotEmpty) {
      await InstalledApps.startApp(widget.telloPackage);
      await Future.delayed(const Duration(seconds: 5));
      _importFromTelloFolder();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Tello app not found")));
      }
    }
  }

  Future<void> _importFromTelloFolder() async {
    final dir = Directory("/storage/emulated/0/DCIM/Tello");
    if (await dir.exists()) {
      final rowDir = await _getRowDir();

      final telloFiles = dir.listSync().whereType<File>().toList();

      for (var f in telloFiles) {
        final dest = File("${rowDir.path}/${f.uri.pathSegments.last}");

        if (!await dest.exists()) {
          await f.copy(dest.path);

          final newRes = _DetectionResult(file: dest);

          if (mounted) {
            setState(() => _results.add(newRes));
          }
          _runAnalysis(newRes);
        }
      }
    }
    _loadImages();
  }

  // --- ANALYSIS METHOD WITH LOGGING ---
  Future<void> _runAnalysis(_DetectionResult res) async {
    final fileName = res.file.uri.pathSegments.last;

    // Safety check and logging for initialization failure
    if (!mounted) return;
    if (_interpreter == null) {
      debugPrint(
        "!!! ANALYSIS ABORTED: Interpreter is not loaded for $fileName !!!",
      );
      setState(() => res.isLoading = false);
      return;
    }

    debugPrint("--- ANALYSIS START: Running analysis for $fileName ---");
    setState(() => res.isLoading = true);

    try {
      final bytes = await res.file.readAsBytes();
      final image = img.decodeImage(bytes)!;

      final resized = img.copyResize(
        image,
        width: _inputSize,
        height: _inputSize,
      );

      final input = Float32List(_inputSize * _inputSize * 3);
      int idx = 0;
      final pixelBytes = resized.getBytes(order: img.ChannelOrder.rgb);

      for (final pixelValue in pixelBytes) {
        // Normalize to [-1, 1]: (pixelValue / 127.5) - 1.0
        input[idx++] = (pixelValue / 127.5) - 1.0;
      }

      final reshaped = input.reshape([1, _inputSize, _inputSize, 3]);

      final output = List.filled(
        _labels.length,
        0.0,
      ).reshape([1, _labels.length]);

      _interpreter!.run(reshaped, output);

      final scores = output[0] as List<double>;
      final maxScore = scores.reduce((a, b) => a > b ? a : b);
      final maxIdx = scores.indexOf(maxScore);
      final finalLabel = maxScore >= 0.7 ? _labels[maxIdx] : "Unknown";

      // Log the result to the terminal
      debugPrint(
        "--- ANALYSIS RESULT for $fileName: $finalLabel (${(maxScore * 100).toStringAsFixed(1)}%) ---",
      );

      if (!mounted) return;
      setState(() {
        res.label = finalLabel;
        res.confidence = maxScore;
      });
    } catch (e) {
      debugPrint("!!! ANALYSIS ERROR for $fileName: $e !!!");
      if (!mounted) return;
      setState(() {
        res.label = "Unknown";
        res.confidence = 0.0;
      });
    } finally {
      if (!mounted) return;
      setState(() => res.isLoading = false);
    }
  }

  // --- UI METHOD WITH PROGRESS INDICATOR ---
  Widget _buildImageTile(_DetectionResult res) {
    Color indicatorColor;

    // Check if the file is valid before attempting to draw
    final isFileValid = res.file.existsSync();

    // Determine the indicator color based on label
    if (res.label == "Healthy") {
      indicatorColor = Colors.green;
    } else if (res.label == "Unknown") {
      indicatorColor = Colors.yellow;
    } else {
      // Assumes "Early Blight" or "Late Blight"
      indicatorColor = Colors.red;
    }

    return GestureDetector(
      onTap: () {
        if (res.label != null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "${res.label} (${(res.confidence * 100).toStringAsFixed(1)}%)",
                style: GoogleFonts.poppins(color: Colors.white),
              ),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.black87,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      },
      child: Stack(
        children: [
          // Image/Error Container
          isFileValid
              ? Image.file(res.file, fit: BoxFit.cover)
              : Container(
                  color: Colors.black,
                  child: const Center(
                    child: Icon(Icons.error, color: Colors.white),
                  ),
                ),

          // ⭐️ ADDED: Loading Indicator (if loading)
          if (res.isLoading)
            Container(
              color: Colors.black.withOpacity(0.5), // Semi-transparent overlay
              child: const Center(
                child: SizedBox(
                  width: 30,
                  height: 30,
                  child: CircularProgressIndicator(
                    strokeWidth: 3.0,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
            )
          else
          // Result Indicator (if not loading and label exists)
          if (res.label != null)
            Positioned(
              right: 4,
              top: 4,
              child: CircleAvatar(
                radius: 12,
                backgroundColor: indicatorColor,
                child: res.label == "Unknown"
                    ? const Icon(
                        Icons.help_outline,
                        size: 14,
                        color: Colors.black,
                      )
                    : Text(
                        res.label![0],
                        style: TextStyle(
                          fontSize: 12,
                          color: indicatorColor == Colors.yellow
                              ? Colors.black
                              : Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("${widget.rowName} - ${widget.albumName}")),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.airplanemode_active),
                  label: const Text("Tello Drone"),
                  onPressed: launchTello,
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.photo),
                  label: const Text("Gallery"),
                  onPressed: _pickFromGallery,
                ),
              ],
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 4,
                mainAxisSpacing: 4,
              ),
              itemCount: _results.length,
              itemBuilder: (ctx, i) => _buildImageTile(_results[i]),
            ),
          ),
        ],
      ),
    );
  }
}
