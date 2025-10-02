// lib/row_detail.dart

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:installed_apps/app_info.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

// NOTE: DetectionResult is defined in 'config.dart'

import 'analysis.dart'; // Import the standalone analysis function (e.g., runModelAnalysis)
import 'config.dart'; // Import config for constants, model, and DetectionResult
import 'analysis_viewer_page.dart'; // Import the detailed viewer page (now only exports the widget)

// Define the dark brown color for reuse (Keeping your specified color)
const Color kDarkBrown = Color.fromARGB(255, 128, 68, 12);
const Color kOrange = Color(0xFFEAA944); // Color used for FABs

// =================== RowDetailPage (detection) ===================
class RowDetailPage extends StatefulWidget {
  final String albumName; // album container name (e.g. "Recent Detections")
  final String rowName; // row name (e.g. "Current Scan")
  final String telloPackage; // optional package name for Tello

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
  
  // 🔥 CODE ADDED: State for selection/editing mode
  bool _isSelectionMode = false;
  final Set<DetectionResult> _selectedResults = {};

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
      // Assumes globalInterpreter, kModelAssetPath, globalInputType, 
      // and globalInputShape are defined in 'config.dart'
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

  /// Creates a directory path using albumName and rowName for storage.
  Future<Directory> _getDayDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final dayDir = Directory(
      '${dir.path}/SPOTATO/${widget.albumName}/${widget.rowName}',
    );
    if (!await dayDir.exists()) await dayDir.create(recursive: true);
    return dayDir;
  }

  File _resultsJsonFile(Directory dayDir) =>
      File('${dayDir.path}/results.json');

  Future<void> _saveResultsJson(Directory dayDir) async {
    // Only save results for files that still exist
    final existingResults = _results.where((r) => r.file.existsSync()).toList();
    final list = existingResults.map((r) => r.toJson()).toList();
    await _resultsJsonFile(dayDir).writeAsString(jsonEncode(list));
  }

  Future<void> _loadImagesAndResults() async {
    final dayDir = await _getDayDir();
    final files = dayDir.listSync().whereType<File>().toList();

    List<Map<String, dynamic>> cached = [];
    final jsonFile = _resultsJsonFile(dayDir);
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
    final dayDir = await _getDayDir();
    final name = picked.path.split('/').last;
    final dest = File('${dayDir.path}/$name');

    await File(picked.path).copy(dest.path);

    final newRes = DetectionResult(file: dest);
    setState(() => _results.add(newRes));
    await _runAnalysis(newRes);
    await _saveResultsJson(dayDir);
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
    await _saveResultsJson(await _getDayDir());
  }

  Future<void> _importFromTelloFolder() async {
    final dir = Directory('/storage/emulated/0/DCIM/Tello');
    if (!await dir.exists()) return;
    final dayDir = await _getDayDir();
    final telloFiles = dir.listSync().whereType<File>().toList();
    for (var f in telloFiles) {
      final name = f.uri.pathSegments.last;
      final dest = File('${dayDir.path}/$name');
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

  // Wrapper for the external analysis function (defined in analysis.dart)
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
        final dayDir = await _getDayDir();
        await _saveResultsJson(dayDir);
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
    await _saveResultsJson(await _getDayDir());
  }
  
  // 🔥 CODE ADDED: Selection mode management logic
  void _toggleSelectionMode(DetectionResult res) {
    setState(() {
      if (!_isSelectionMode) {
        // Enter selection mode on long press
        _isSelectionMode = true;
        _selectedResults.add(res);
      } else {
        // Toggle selection status
        _toggleSelection(res);
      }
    });
  }

  void _toggleSelection(DetectionResult res) {
    setState(() {
      if (_selectedResults.contains(res)) {
        _selectedResults.remove(res);
      } else {
        _selectedResults.add(res);
      }
      
      // Exit selection mode if no items are selected
      if (_selectedResults.isEmpty) {
        _isSelectionMode = false;
      }
    });
  }
  
  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedResults.clear();
    });
  }

  // 🔥 CODE ADDED: Delete selected results
  Future<void> _deleteSelected() async {
    if (_selectedResults.isEmpty) return;

    final resultsToDelete = _selectedResults.toList();
    
    // 1. Delete files from disk
    for (var res in resultsToDelete) {
      try {
        if (await res.file.exists()) {
          await res.file.delete();
        }
      } catch (e) {
        debugPrint('Failed to delete file: ${res.file.path} - $e');
      }
    }

    // 2. Update local state
    setState(() {
      _results.removeWhere((r) => _selectedResults.contains(r));
      _selectedResults.clear();
      _isSelectionMode = false;
    });

    // 3. Update persistent JSON
    await _saveResultsJson(await _getDayDir());

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${resultsToDelete.length} images deleted.')),
    );
  }

  // 🔥 CODE ADDED: Move selected results (Placeholder/Notifies completion)
  void _moveSelected() {
    if (_selectedResults.isEmpty) return;
    
    // TODO: Implement logic to open album selector and move files
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Move functionality pending for ${_selectedResults.length} items.')),
    );
    _exitSelectionMode();
  }


  // ---------------- UI & helpers ----------------
  Widget _buildImageTile(DetectionResult res) {
    final bool fileOk = res.file.existsSync();
    // 🔥 CODE ADDED: Check selection status
    final bool isSelected = _selectedResults.contains(res);
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
      // 🔥 CODE ADDED: LongPress to enter selection mode
      onLongPress: () => _toggleSelectionMode(res),
      
      onTap: () {
        // 🔥 CODE ADDED: If in selection mode, tap toggles selection
        if (_isSelectionMode) {
          _toggleSelection(res);
        } else {
          // Navigate to viewer page only if not in selection mode
          if (!fileOk) return;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AnalysisViewerPage(
                // Pass the full DetectionResult object
                detectionResult: res, 
              ),
            ),
          );
        }
      },
      // ======================================================
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

          // 🔥 CODE ADDED: Selection Overlay
          if (_isSelectionMode)
            Container(
              color: isSelected
                  ? Colors.blue.withOpacity(0.4) // Blue tint for selected
                  : Colors.black.withOpacity(0.3), // Dark tint for unselected in mode
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

          // 🔥 CODE ADDED: Selection Checkmark
          if (_isSelectionMode)
            Positioned(
              right: 6,
              top: 6,
              child: CircleAvatar(
                radius: 12,
                backgroundColor: isSelected ? Colors.blue : Colors.grey,
                child: isSelected
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : null,
              ),
            )
          // Analysis Indicator (Only show if not in selection mode)
          else if (res.label != null)
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

  // Widget that displays the import buttons fixed to the bottom right
  Widget _buildImportButtons() {
    // 🔥 CODE ADDED: Hide import buttons while in selection mode
    if (_isSelectionMode) return const SizedBox.shrink();

    return Positioned(
      right: 16.0,
      bottom: 16.0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 1. Gallery Button
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: FloatingActionButton.extended(
              heroTag: 'galleryBtn',
              onPressed: _pickFromGallery, 
              label: Text('Gallery', style: GoogleFonts.poppins()),
              icon: const Icon(Icons.photo_library),
              backgroundColor: kOrange,
              foregroundColor: Colors.white,
            ),
          ),
          // 2. Tello Button
          // Only show if Tello package is detected
          if (_telloPackage.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 40.0), // Keeping your padding
              child: FloatingActionButton.extended(
                heroTag: 'telloBtn',
                onPressed: launchTello, 
                label: Text('Tello Drone', style: GoogleFonts.poppins()),
                // Keeping your specified icon
                icon: const Icon(Icons.airplanemode_active), 
                backgroundColor: kOrange,
                foregroundColor: Colors.white,
              ),
            )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color kLightBackground = Colors.white;

    return Scaffold(
      backgroundColor: const Color.fromARGB(243, 248, 248, 248),
      appBar: AppBar(
        backgroundColor: kLightBackground,
        title: Text(
          // 🔥 CODE ADDED: Change title in selection mode
          _isSelectionMode 
              ? '${_selectedResults.length} Selected'
              : widget.rowName, 
          style: GoogleFonts.poppins(
            color: kDarkBrown,
            fontWeight: FontWeight.bold,
          ),
        ),
        // 🔥 CODE ADDED: Close button in selection mode
        leading: _isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                color: kDarkBrown,
                onPressed: _exitSelectionMode,
              )
            : null, // Use default back button when not in selection mode
        
        iconTheme: const IconThemeData(color: kDarkBrown),
        actions: _isSelectionMode
            ? [
                // 🔥 CODE ADDED: Delete button
                IconButton(
                  icon: const Icon(Icons.delete),
                  tooltip: 'Delete Selected',
                  color: Colors.red, // Use red for deletion
                  onPressed: _deleteSelected,
                ),
                // 🔥 CODE ADDED: Folder/Move button
                IconButton(
                  icon: const Icon(Icons.folder_open), // Icon for moving to another folder/album
                  tooltip: 'Move to Album',
                  color: kDarkBrown,
                  onPressed: _moveSelected,
                ),
              ]
            : [
                // Original actions for normal mode
                // Re-run analysis button
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Re-run analysis',
                  color: kDarkBrown,
                  onPressed: _reAnalyzeAll, 
                ),
                // Folder button to go back to Album Detail
                IconButton(
                  icon: const Icon(Icons.folder_open),
                  tooltip: 'Back to Album',
                  color: kDarkBrown,
                  onPressed: () {
                    // Navigates back to the previous screen (Album Detail)
                    Navigator.pop(context); 
                  },
                ),
              ],
      ),
      body: Padding(
        padding: const EdgeInsets.only(top: 10.0),
        child: Stack(
          children: [
            // GridView of detection results
            GridView.builder(
              padding: EdgeInsets.only(
                left: 8, 
                right: 8, 
                top: 8, 
                // 🔥 CODE ADDED: Adjust bottom padding based on button visibility
                bottom: _isSelectionMode ? 8 : 100, 
              ),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 6,
                mainAxisSpacing: 6,
              ),
              itemCount: _results.length,
              itemBuilder: (ctx, i) => _buildImageTile(_results[i]),
            ),
            // Import buttons positioned at the bottom right
            _buildImportButtons(),
          ],
        ),
      ),
    );
  }
}