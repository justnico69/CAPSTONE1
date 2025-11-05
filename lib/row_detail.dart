import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:installed_apps/app_info.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:spotato/image_handler.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';

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

  Future<void> _importFromTelloFolder() async {
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
        await openAppSettings();
      }
      return;
    }

    if (status.isGranted) {
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
    final String dateStr = DateFormat('MMM-d-y').format(now);
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

  // --- Handles back button press ---
  Future<bool> _onWillPop() async {
    // Original logic for unsaved work
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

  // --- Builds the image tile with the new label style ---
  Widget _buildImageTile(DetectionResult res) {
    final fileOk = res.file.existsSync();
    final color = (res.label == 'Healthy')
        ? Colors.green.shade800 // Darker green for better contrast
        : (res.label == null)
            ? Colors.grey.shade700 // Darker grey
            : Colors.red.shade800; // Darker red

    return GestureDetector(
      onTap: () { // --- Original onTap functionality ---
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4.0),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // --- The Image ---
            fileOk
                ? Image.file(res.file, fit: BoxFit.cover)
                : Container(color: Colors.black),

            // --- Full Text Label at the Bottom ---
            if (res.label != null)
              Positioned(
                bottom: 0, // Position at the bottom
                left: 0,
                right: 0,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  color: color.withOpacity(0.8), // Semi-transparent colored background
                  child: Text(
                    res.label!, // Display the full label
                    textAlign: TextAlign.center,
                    maxLines: 1, // Ensure it stays on one line
                    overflow: TextOverflow.ellipsis, // Add '...' if it's too long
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 10, // Smaller font size for full text
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: const Color.fromARGB(243, 248, 248, 248),
        // --- Original AppBar ---
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
            // --- Delete button is removed ---
          ],
        ),
        body: GridView.builder(
          padding: const EdgeInsets.only(
            left: 8,
            right: 8,
            bottom: 200,
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

        // --- Floating Action Buttons ---
        floatingActionButton: Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: SpeedDial(
            icon: Icons.add,
            activeIcon: Icons.close,
            backgroundColor: kOrange,
            foregroundColor: Colors.white,
            visible: true, // --- Always visible ---
            curve: Curves.bounceIn,
            heroTag: 'fab-main',
            children: [
              SpeedDialChild(
                child: const Icon(Icons.airplanemode_active, color: Colors.white),
                backgroundColor: kDarkBrown,
                label: 'Launch Tello',
                labelStyle: GoogleFonts.poppins(),
                onTap: _launchTelloApp,
              ),
              SpeedDialChild(
                child: const Icon(Icons.download, color: Colors.white),
                backgroundColor: kDarkBrown.withOpacity(0.85),
                label: 'Import Tello Photos',
                labelStyle: GoogleFonts.poppins(),
                onTap: _importFromTelloFolder,
              ),
              SpeedDialChild(
                child: const Icon(Icons.photo_library, color: Colors.white),
                backgroundColor: kOrange,
                label: 'Add from Gallery',
                labelStyle: GoogleFonts.poppins(),
                onTap: _pickFromGallery,
              ),
            ],
          ),
        ),
      ),
    );
  }
}