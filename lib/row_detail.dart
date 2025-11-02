import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:installed_apps/app_info.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:intl/intl.dart';
// 🔹 --- ADD THIS IMPORT --- 🔹
import 'package:permission_handler/permission_handler.dart';
import 'package:spotato/image_handler.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

// 🔹 ------------------------- 🔹

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
    this.telloPackage = "",
  }) : super(key: key);

  @override
  _RowDetailPageState createState() => _RowDetailPageState();
}

class _RowDetailPageState extends State<RowDetailPage> {
  List<DetectionResult> _results = [];
  String _telloPackage = "";
  bool _modelLoaded = false;
  late DateTime _lastImportTimestamp;

  @override
  void initState() {
    super.initState();
    _telloPackage = widget.telloPackage;
    NotificationService.init();
    _lastImportTimestamp = DateTime.now();
    _init();
  }

  Future<void> _init() async {
    await _loadModel();
    await _loadImages();

    if (_results.isNotEmpty) {
      debugPrint(
        "Clearing ${_results.length} leftover images from previous session.",
      );
      await _clearCurrentScan(updateState: false);
    }

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
      debugPrint('Model load error: $e');
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
    // We can use Permission.photos for the gallery, that is fine.
    var status = await Permission.photos.status;
    if (status.isDenied) {
      status = await Permission.photos.request();
    }

    if (status.isPermanentlyDenied) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Photo access denied. Please enable in settings.'),
          ),
        );
        await openAppSettings();
      }
      return;
    }

    if (status.isGranted) {
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
  }

  /// 🔹 --- NEW FUNCTION (Replaces _launchTelloAndFetch) --- 🔹
  /// Safely launches the Tello app and instructs the user.
  Future<void> _launchTelloApp() async {
    if (_telloPackage.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Finding Tello app...')));
      }
      await _checkTelloApp();
    }

    if (_telloPackage.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Tello app not found.')));
      }
      return;
    }

    await InstalledApps.startApp(_telloPackage);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Fly your drone, take photos, then return here and tap "Import Tello Photos".',
          ),
          duration: Duration(seconds: 6),
        ),
      );
    }
  }

  /// 🔹 --- UPDATED FUNCTION --- 🔹
  /// Imports and compresses Tello photos after checking for the
  /// CORRECT "All Files Access" permission.
  Future<void> _importFromTelloFolder() async {
    // 1. THIS IS THE CORRECT PERMISSION CHECK
    var status = await Permission.manageExternalStorage.status;
    if (status.isDenied) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Requesting "All Files Access" to read Tello folder...',
            ),
          ),
        );
      }
      // 2. This will open the phone's settings page for the user to grant.
      status = await Permission.manageExternalStorage.request();
    }

    if (status.isPermanentlyDenied) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '"All Files Access" denied. Please enable it in app settings to import photos.',
            ),
          ),
        );
        await openAppSettings(); // Opens the app's settings
      }
      return;
    }
    // 🔹 ----------------------------------------------- 🔹

    // 3. Only proceed if the permission is granted
    if (status.isGranted) {
      // 4. This is the correct timer-less logic from before
      final importCheckTime = DateTime.now();

      final sourceFiles = await ImageHandler.importFromTello(
        _lastImportTimestamp,
      );

      _lastImportTimestamp = importCheckTime;

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
    } else {
      // If permissions are still denied after asking
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '"All Files Access" is required to import Tello photos.',
            ),
          ),
        );
      }
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
    final String dateStr = DateFormat(
      'MMM-d-y',
    ).format(now); // <-- CHANGED THIS LINE
    final String timeStr = DateFormat('h-mm_a').format(now);

    final folderName = "Scan_${dateStr}_$timeStr";
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
          SnackBar(content: Text('✓ Scan saved to album "$folderName"')),
        );
        setState(() => _results.clear());
      }
    } catch (e) {
      debugPrint('Save error: $e');
    }
  }

  /// Changed: Now deletes the temporary physical files before clearing the DB.
  Future<void> _clearCurrentScan({bool updateState = true}) async {
    try {
      final resultsToClear = List<DetectionResult>.from(_results);
      for (var res in resultsToClear) {
        if (await res.file.exists()) {
          await res.file.delete();
        }
      }
      await DatabaseHelper.instance.deleteAlbum('Current Scan');

      if (mounted && updateState) {
        setState(() => _results.clear());
      } else if (!updateState) {
        _results.clear();
      }
    } catch (e) {
      debugPrint('! Failed to clear scan: $e');
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
                _clearCurrentScan(updateState: false);
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
            builder: (context) => AnalysisViewerPage(
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
            bottom: 200, // Increased padding for 3 buttons
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

        // --- 🔹 UPDATED FLOATING ACTION BUTTONS 🔹 ---
        floatingActionButton: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment:
              CrossAxisAlignment.end, // Aligns buttons to the right
          children: [
            // BUTTON 1: LAUNCH TELLO
            FloatingActionButton.extended(
              onPressed: _launchTelloApp, // Calls our NEW, simple function
              backgroundColor: kDarkBrown,
              icon: const Icon(Icons.airplanemode_active, color: Colors.white),
              label: const Text(
                '1. Launch Tello',
                style: TextStyle(color: Colors.white),
              ),
              heroTag: 'fab-tello-launch',
            ),
            const SizedBox(height: 10),

            // BUTTON 2: IMPORT TELLO
            FloatingActionButton.extended(
              onPressed:
                  _importFromTelloFolder, // Calls your EXISTING import function
              backgroundColor: kDarkBrown.withOpacity(
                0.85,
              ), // Slightly different color
              icon: const Icon(Icons.download, color: Colors.white),
              label: const Text(
                '2. Import Tello Photos',
                style: TextStyle(color: Colors.white),
              ),
              heroTag: 'fab-tello-import',
            ),
            const SizedBox(height: 10),

            // BUTTON 3: ADD FROM GALLERY
            FloatingActionButton.extended(
              onPressed: _pickFromGallery,
              backgroundColor: kOrange,
              icon: const Icon(Icons.photo_library, color: Colors.white),
              label: const Text(
                'Add from Gallery',
                style: TextStyle(color: Colors.white),
              ),
              heroTag: 'fab-gallery',
            ),
          ],
        ),
      ),
    );
  }
}
