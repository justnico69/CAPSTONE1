import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:installed_apps/app_info.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:spotato/image_handler.dart';
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
  bool _isFindingTelloApp = false;

  // 🔹 ADDED THIS: This "remembers" when the last import happened.
  late DateTime _lastImportTimestamp;

  @override
  void initState() {
    super.initState();
    _telloPackage = widget.telloPackage;
    NotificationService.init();

    // 🔹 ADDED THIS: Sets the initial timestamp to now.
    // Any files created *before* this page was opened will be ignored.
    _lastImportTimestamp = DateTime.now();

    _init();
  }

  /// This function now clears any leftover images from a
  /// previous session, ensuring you always start with a clean page.
  Future<void> _init() async {
    await _loadModel();

    // 1. Load any leftover results from the DB into the _results list
    await _loadImages();

    // 2. If we found any, clear them (files and DB) before the user sees them.
    if (_results.isNotEmpty) {
      debugPrint(
        "Clearing ${_results.length} leftover images from previous session.",
      );
      await _clearCurrentScan();
    }
  }

  Future<void> _checkTelloApp() async {
    if (_isFindingTelloApp) return;

    setState(() => _isFindingTelloApp = true);
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Finding Tello app...')));
    }

    try {
      List<AppInfo> apps = await InstalledApps.getInstalledApps(true, true);
      for (var app in apps) {
        if (app.packageName == "com.ryzerobotics.tello") {
          if (mounted) {
            setState(() => _telloPackage = app.packageName);
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('✅ Tello app found!')));
          }
          break;
        }
      }
    } catch (_) {
      // Handle error
    } finally {
      if (mounted) setState(() => _isFindingTelloApp = false);
    }
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

  Future<void> _launchTelloAndFetch() async {
    if (_isFindingTelloApp) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please wait, still finding Tello app...'),
        ),
      );
      return;
    }

    if (_telloPackage.isEmpty) {
      await _checkTelloApp();
      if (_telloPackage.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Tello app not found.')));
        return;
      }
    }

    var status = await Permission.manageExternalStorage.status;
    if (status.isDenied) {
      status = await Permission.manageExternalStorage.request();
    }

    if (status.isPermanentlyDenied) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'All Files Access is required. Please enable it in app settings.',
            ),
          ),
        );
      }
      await openAppSettings();
      return;
    }

    if (status.isGranted) {
      await InstalledApps.startApp(_telloPackage);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('📸 Open Tello, take pictures, then return here.'),
          ),
        );
      }

      await Future.delayed(const Duration(seconds: 8));

      // 🔹 UPDATED: We now "save" the time *before* we check.
      // This ensures any files created *while* importing are picked up next time.
      final importCheckTime = DateTime.now();
      await _importFromTelloFolder();

      // 🔹 UPDATED: We update our "memory" to the time the check started.
      _lastImportTimestamp = importCheckTime;
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Storage permission was not granted.')),
        );
      }
    }
  }

  Future<void> _importFromTelloFolder() async {
    // 🔹 UPDATED: Pass the "memory" timestamp to the image handler.
    final sourceFiles = await ImageHandler.importFromTello(
      _lastImportTimestamp,
    );

    if (sourceFiles.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No *new* Tello photos found.')),
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
        body: "$analyzedCount new Tello image(s) analyzed!",
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

  /// This function now clears all images (files and DB) for the "Current Scan".
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
