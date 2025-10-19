import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:installed_apps/app_info.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:spotato/image_handler.dart'; // ✅ Added: Import the new handler
import 'package:tflite_flutter/tflite_flutter.dart';

import 'analysis.dart';
import 'analysis_viewer_page.dart';
import 'config.dart';
import 'database_helper.dart';
import 'notification_service.dart';

const Color kDarkBrown = Color.fromARGB(255, 128, 68, 12);
const Color kOrange = Color(0xFFEAA944);

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
  List<DetectionResult> _results = [];
  String _telloPackage = '';
  bool _modelLoaded = false;

  @override
  void initState() {
    super.initState();
    _telloPackage = widget.telloPackage;
    NotificationService.init();
    _init();
  }

  Future<void> _init() async {
    await _loadModel();
    await _loadImages();
    if (_telloPackage.isEmpty) _checkTelloApp();
  }

  Future<void> _checkTelloApp() async {
    try {
      List<AppInfo> apps = await InstalledApps.getInstalledApps(true, true);
      for (var app in apps) {
        if (app.packageName == "com.ryzerobotics.tello") {
          if (mounted) setState(() => _telloPackage = app.packageName);
          break;
        }
      }
    } catch (_) {}
  }

  Future<void> _loadModel() async {
    if (_modelLoaded || globalInterpreter != null) {
      setState(() => _modelLoaded = true);
      return;
    }
    try {
      globalInterpreter = await Interpreter.fromAsset(kModelAssetPath);
      final inT = globalInterpreter!.getInputTensor(0);
      globalInputType = inT.type;
      globalInputShape = inT.shape;
      if (mounted) setState(() => _modelLoaded = true);
    } catch (e) {
      debugPrint('❌ Model load error: $e');
    }
  }

  Future<void> _loadImages() async {
    final loadedResults = await DatabaseHelper.instance.getAnalysesForAlbum(
      'Current Scan',
    );
    if (!mounted) return;
    setState(() => _results = loadedResults);
  }

  /// 🔹 Refactored: Now uses the ImageHandler to pick and compress.
  Future<void> _pickFromGallery() async {
    final sourceFile = await ImageHandler.pickFromGallery();
    if (sourceFile == null) return;

    final compressedFile = await ImageHandler.compressImage(sourceFile);
    if (compressedFile == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to process image.')),
        );
      }
      return;
    }

    final newResult = DetectionResult(
      file: compressedFile,
      captureTime: await compressedFile.lastModified(),
    );

    if (mounted) setState(() => _results.add(newResult));
    await _runAnalysis(newResult);

    await NotificationService.show(
      title: "SPOTATO",
      body: "Gallery image analysis completed!",
    );
  }

  /// 🔹 Refactored: Logic is simpler, just manages the UI flow.
  Future<void> _launchTelloAndFetch() async {
    if (_telloPackage.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Tello app not found.')));
      return;
    }

    await InstalledApps.startApp(_telloPackage);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('📸 Open Tello, take pictures, then return here.'),
        ),
      );
    }

    await Future.delayed(const Duration(seconds: 8));
    await _importFromTelloFolder();
  }

  /// 🔹 Refactored: Now uses the ImageHandler to import and compress.
  Future<void> _importFromTelloFolder() async {
    final sourceFiles = await ImageHandler.importFromTello();
    if (sourceFiles.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No recent Tello photos found.')),
        );
      }
      return;
    }

    int analyzedCount = 0;
    for (var file in sourceFiles) {
      final compressedFile = await ImageHandler.compressImage(file);
      if (compressedFile != null) {
        final newRes = DetectionResult(
          file: compressedFile,
          captureTime: await compressedFile.lastModified(),
        );
        if (mounted) setState(() => _results.add(newRes));
        await _runAnalysis(newRes);
        analyzedCount++;
      }
    }

    if (analyzedCount > 0) {
      await NotificationService.show(
        title: "SPOTATO Analysis Complete",
        body: "$analyzedCount Tello image(s) analyzed successfully!",
      );
    }
  }

  Future<void> _runAnalysis(DetectionResult res) async {
    if (!mounted) return;
    setState(() => res.isLoading = true);
    await runModelAnalysis(res);
    await DatabaseHelper.instance.insertAnalysis(res, 'Current Scan');
    if (!mounted) return;
    setState(() => res.isLoading = false);
  }

  Future<void> _saveCurrentScan() async {
    if (_results.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No images to save.')));
      return;
    }
    final now = DateTime.now();
    final folderName =
        "Scan_${now.month}-${now.day}-${now.year}_${now.hour}-${now.minute}";

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          'Save Scan',
          style: GoogleFonts.poppins(
            color: Colors.brown,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        content: Text(
          'You will be saving these images into an album named "$folderName".\n\nProceed?',
          style: GoogleFonts.poppins(color: Colors.black87, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(
                color: Colors.brown,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: kOrange,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Save',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await DatabaseHelper.instance.updateAlbumName('Current Scan', folderName);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ Scan saved to album "$folderName"')),
        );
        setState(() => _results.clear());
      }
    } catch (e) {
      debugPrint('❌ Save error: $e');
    }
  }

  /// 🔹 Changed: Now deletes the temporary physical files before clearing the DB.
  Future<void> _clearCurrentScan() async {
    try {
      // First, delete the compressed image files from the temporary folder.
      for (var res in _results) {
        if (await res.file.exists()) {
          await res.file.delete();
        }
      }

      // Then, delete the records from the database.
      await DatabaseHelper.instance.deleteAlbum('Current Scan');

      if (mounted) setState(() => _results.clear());
    } catch (e) {
      debugPrint('⚠️ Failed to clear scan: $e');
    }
  }

  Future<bool> _onWillPop() async {
    if (_results.isNotEmpty) {
      final shouldExit = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: Text(
            'Unsaved Work',
            style: GoogleFonts.poppins(
              color: Colors.brown,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
          content: Text(
            'You have unsaved images. Would you like to save before exiting?',
            style: GoogleFonts.poppins(color: Colors.black87, fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Cancel',
                style: GoogleFonts.poppins(
                  color: Colors.brown,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                await _saveCurrentScan();
                if (mounted) Navigator.of(context).pop(false);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: kOrange,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Save First',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                _clearCurrentScan();
                Navigator.of(context).pop(true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Exit Anyway',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
      return shouldExit ?? false;
    }
    return true;
  }

  Widget _buildImageTile(DetectionResult res) {
    final fileOk = res.file.existsSync();
    final color = (res.label == 'Healthy')
        ? Colors.green
        : (res.label == null)
        ? Colors.grey
        : Colors.red;
    return GestureDetector(
      onTap: () {
        if (!fileOk) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AnalysisViewerPage(
              detectionResult: res,
              durationText:
                  res.analysisDuration?.inMilliseconds.toString() ?? "N/A",
              dateCaptured:
                  "${res.captureTime?.month}/${res.captureTime?.day}/${res.captureTime?.year}",
              timeCaptured:
                  "${res.captureTime?.hour}:${res.captureTime?.minute.toString().padLeft(2, '0')}",
            ),
          ),
        );
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          fileOk
              ? Image.file(res.file, fit: BoxFit.cover)
              : Container(color: Colors.black),
          if (res.label != null)
            Positioned(
              top: 6,
              right: 6,
              child: CircleAvatar(
                radius: 12,
                backgroundColor: color,
                child: Text(
                  res.label![0],
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white,
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
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: const Color.fromARGB(243, 248, 248, 248),
        appBar: AppBar(
          backgroundColor: Colors.white,
          title: Text(
            widget.rowName,
            style: GoogleFonts.poppins(
              color: kDarkBrown,
              fontWeight: FontWeight.bold,
            ),
          ),
          iconTheme: const IconThemeData(color: kDarkBrown),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Re-run analysis',
              color: kDarkBrown,
              onPressed: () async {
                for (var r in _results) {
                  await _runAnalysis(r);
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.folder_open),
              tooltip: 'Save as Album',
              color: kDarkBrown,
              onPressed: _saveCurrentScan,
            ),
          ],
        ),
        body: GridView.builder(
          padding: const EdgeInsets.only(
            left: 8,
            right: 8,
            bottom: 100,
            top: 10,
          ),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 6,
            mainAxisSpacing: 6,
          ),
          itemCount: _results.length,
          itemBuilder: (_, i) => _buildImageTile(_results[i]),
        ),
        floatingActionButton: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FloatingActionButton.extended(
              onPressed: _launchTelloAndFetch,
              backgroundColor: kDarkBrown,
              icon: const Icon(Icons.airplanemode_active, color: Colors.white),
              label: const Text(
                'Use Tello',
                style: TextStyle(color: Colors.white),
              ),
            ),
            const SizedBox(height: 10),
            FloatingActionButton.extended(
              onPressed: _pickFromGallery,
              backgroundColor: kOrange,
              icon: const Icon(Icons.photo_library, color: Colors.white),
              label: const Text(
                'Add Image',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
