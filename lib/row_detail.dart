// row_detail.dart

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:installed_apps/app_info.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

import 'analysis.dart'; // Import the standalone analysis function with prefix
import 'config.dart'; // Import config for constants and model

// =================== RowDetailPage (detection) ===================
class RowDetailPage extends StatefulWidget {
  final String albumName;
  final String rowName;
  final String telloPackage;

  const RowDetailPage({
    Key? key,
    required this.albumName,
    required this.rowName,
    this.telloPackage = '',
  }) : super(key: key);

  @override
  _RowDetailPageState createState() => _RowDetailPageState();
}

class _RowDetailPageState extends State<RowDetailPage> {
  final ImagePicker _picker = ImagePicker();
  List<DetectionResult> _results = [];
  String _telloPackage = '';
  bool _modelLoaded = false;

  @override
  void initState() {
    super.initState();
    _telloPackage = widget.telloPackage;
    _init();
  }

  Future<void> _init() async {
    await _loadModel();
    await _loadImagesAndResults();
    if (_telloPackage.isEmpty) _checkTelloApp();
  }

  @override
  void dispose() {
    globalInterpreter?.close();
    super.dispose();
  }

  Future<void> _checkTelloApp() async {
    try {
      List<AppInfo> apps = await InstalledApps.getInstalledApps(true, true);
      for (var app in apps) {
        if (app.packageName == "com.ryzerobotics.tello") {
          setState(() => _telloPackage = app.packageName);
          break;
        }
      }
    } catch (_) {}
  }

  Future<void> _loadModel() async {
    if (_modelLoaded) return;
    try {
      globalInterpreter = await Interpreter.fromAsset(kModelAssetPath);

      // Cache input/output tensor metadata globally
      final inT = globalInterpreter!.getInputTensor(0);
      final outT = globalInterpreter!.getOutputTensor(0);
      globalInputType = inT.type;
      globalInputShape = inT.shape;

      setState(() => _modelLoaded = true);
      debugPrint('✅ TFLite model loaded from $kModelAssetPath');
      debugPrint(
        'Model input shape=${globalInputShape} type=${globalInputType}',
      );
    } catch (e) {
      debugPrint('❌ Failed to load TFLite model ($kModelAssetPath): $e');
      setState(() => _modelLoaded = false);
    }
  }

  Future<Directory> _getRowDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final rowDir = Directory(
      '${dir.path}/SPOTATO/${widget.albumName}/${widget.rowName}',
    );
    if (!await rowDir.exists()) await rowDir.create(recursive: true);
    return rowDir;
  }

  File _resultsJsonFile(Directory rowDir) =>
      File('${rowDir.path}/results.json');

  Future<void> _saveResultsJson(Directory rowDir) async {
    final list = _results.map((r) => r.toJson()).toList();
    await _resultsJsonFile(rowDir).writeAsString(jsonEncode(list));
  }

  Future<void> _loadImagesAndResults() async {
    final rowDir = await _getRowDir();
    final files = rowDir.listSync().whereType<File>().toList();

    List<Map<String, dynamic>> cached = [];
    final jsonFile = _resultsJsonFile(rowDir);
    if (await jsonFile.exists()) {
      try {
        final txt = await jsonFile.readAsString();
        final parsed = jsonDecode(txt);
        if (parsed is List) cached = List<Map<String, dynamic>>.from(parsed);
      } catch (_) {
        cached = [];
      }
    }

    final Map<String, Map<String, dynamic>> cacheMap = {};
    for (var e in cached) {
      final name = e['path'] as String? ?? '';
      if (name.isNotEmpty) cacheMap[name] = e;
    }

    final List<DetectionResult> list = [];
    for (var f in files) {
      final name = f.path.split('/').last;
      if (cacheMap.containsKey(name)) {
        final cachedObj = cacheMap[name]!;
        final r = DetectionResult(
          file: f,
          label: cachedObj['label'] as String?,
          confidence: (cachedObj['confidence'] ?? 0.0).toDouble(),
        );
        list.add(r);
      } else {
        list.add(DetectionResult(file: f));
      }
    }

    setState(() => _results = list);

    // Run detection for those without label
    for (var r in _results.where((x) => x.label == null)) {
      _runAnalysis(r);
    }
  }

  Future<void> _pickFromGallery() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    final rowDir = await _getRowDir();
    final name = picked.path.split('/').last;
    final dest = File('${rowDir.path}/$name');

    await File(picked.path).copy(dest.path);

    final newRes = DetectionResult(file: dest);
    setState(() => _results.add(newRes));
    await _runAnalysis(newRes);
    await _saveResultsJson(rowDir);
  }

  Future<void> launchTello() async {
    if (_telloPackage.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Tello app not found')));
      return;
    }
    await InstalledApps.startApp(_telloPackage);
    await Future.delayed(const Duration(seconds: 4));
    await _importFromTelloFolder();
    await _saveResultsJson(await _getRowDir());
  }

  Future<void> _importFromTelloFolder() async {
    final dir = Directory('/storage/emulated/0/DCIM/Tello');
    if (!await dir.exists()) return;
    final rowDir = await _getRowDir();
    final telloFiles = dir.listSync().whereType<File>().toList();
    for (var f in telloFiles) {
      final name = f.uri.pathSegments.last;
      final dest = File('${rowDir.path}/$name');
      if (!await dest.exists()) {
        try {
          await f.copy(dest.path);
          final newRes = DetectionResult(file: dest);
          setState(() => _results.add(newRes));
          await _runAnalysis(newRes);
        } catch (e) {
          debugPrint('Failed to copy tello file $name: $e');
        }
      }
    }
  }

  // Wrapper for the external analysis function
  Future<void> _runAnalysis(DetectionResult res) async {
    // 1. Set loading state locally (on the UI)
    setState(() => res.isLoading = true);

    // 2. Run the external analysis (modifies 'res' object internally)
    await runModelAnalysis(res);

    // 3. Update UI after analysis finishes
    if (!mounted) return;
    setState(() {
      // The analysis function updates res.label, res.confidence, and res.isLoading=false
    });

    // 4. Save results (if successful)
    if (res.label != null && res.label != 'Unknown') {
      try {
        final rowDir = await _getRowDir();
        await _saveResultsJson(rowDir);
      } catch (e) {
        debugPrint('Failed saving results.json: $e');
      }
    }
  }

  Future<void> _reAnalyzeAll() async {
    for (var r in _results) {
      r.label = null;
      r.confidence = 0.0;
    }
    setState(() {});
    for (var r in _results) {
      await _runAnalysis(r);
    }
    await _saveResultsJson(await _getRowDir());
  }

  // ---------------- UI & helpers ----------------
  Widget _buildImageTile(DetectionResult res) {
    final bool fileOk = res.file.existsSync();
    final Color indicator;
    if (res.label == null) {
      indicator = Colors.grey;
    } else if (res.label == 'Unknown') {
      indicator = Colors.yellow;
    } else if (res.label == 'Healthy') {
      indicator = Colors.green;
    } else {
      indicator = Colors.red;
    }

    return GestureDetector(
      onTap: () {
        if (!fileOk) return;
        final label = res.label ?? 'Pending';
        final conf = (res.confidence * 100).toStringAsFixed(1);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '$label ($conf%)',
              style: GoogleFonts.poppins(color: Colors.white),
            ),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.black87,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          fileOk
              ? Image.file(res.file, fit: BoxFit.cover)
              : Container(
                  color: Colors.black,
                  child: const Center(
                    child: Icon(Icons.error, color: Colors.white),
                  ),
                ),
          if (res.isLoading)
            Container(
              color: Colors.black.withOpacity(0.45),
              child: const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
          if (res.label != null)
            Positioned(
              right: 6,
              top: 6,
              child: CircleAvatar(
                radius: 12,
                backgroundColor: indicator,
                child: res.label == 'Unknown'
                    ? const Icon(
                        Icons.help_outline,
                        size: 14,
                        color: Colors.black,
                      )
                    : Text(
                        res.label![0],
                        style: TextStyle(
                          fontSize: 12,
                          color: (indicator == Colors.yellow)
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
      appBar: AppBar(
        title: Text('${widget.rowName} — ${widget.albumName}'),
        actions: [
          // NOTE: The crop toggle logic was removed as it makes the analysis
          // function overly complicated to make standalone. I recommend sticking
          // to a single resizing method unless a model requires center-crop.
          // I replaced it with a simple refresh button.
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Re-run analysis',
            onPressed: () async {
              await _reAnalyzeAll();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.airplanemode_active),
                label: const Text('Tello Drone'),
                onPressed: launchTello,
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.photo),
                label: const Text('Gallery'),
                onPressed: _pickFromGallery,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 6,
                mainAxisSpacing: 6,
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
