import 'package:flutter/material.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:installed_apps/app_info.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:intl/intl.dart';
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

    // 🔹 FIX: Store the timestamp in UTC format.
    _lastImportTimestamp = DateTime.now().toUtc();
    debugPrint("--- PAGE LOADED ---");
    debugPrint(
      "Initial timestamp set (UTC): ${_lastImportTimestamp.toIso8601String()}",
    );

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
    debugPrint("--- IMPORT TELLO PHOTOS TAPPED ---");

    var status = await Permission.manageExternalStorage.status;
    debugPrint(
      "1. Checking 'Manage External Storage' permission. Status: ${status.name}",
    );

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
      debugPrint("2. Permission requested. New status: ${status.name}");
    }

    if (status.isPermanentlyDenied) {
      debugPrint("3. ❌ Permission permanently denied.");
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
      debugPrint("3. ✅ Permission is GRANTED.");

      final importCheckTime = DateTime.now().toUtc();

      debugPrint(
        "4. Calling ImageHandler. Checking for files modified AFTER (UTC): ${_lastImportTimestamp.toIso8601String()}",
      );

      final sourceFiles = await ImageHandler.importFromTello(
        _lastImportTimestamp,
      );

      _lastImportTimestamp = importCheckTime;
      debugPrint("5. Import finished. Found ${sourceFiles.length} new files.");
      debugPrint(
        "6. Timestamp updated. Will now ignore files before (UTC): ${_lastImportTimestamp.toIso8601String()}",
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
    } else {
      debugPrint("3. ❌ Permission was DENIED.");
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
    // 🔹 MODIFIED: We only save the rowTag when saving the *whole album*
    // so we pass null for the rowTag here.
    res.rowTag = null;
    await DatabaseHelper.instance.insertAnalysis(res, 'Current Scan');
    if (!mounted) return;
    setState(() => res.isLoading = false);
  }

  // 🔹 --- THIS IS THE FULLY REBUILT "SAVE" FUNCTION --- 🔹
  Future<void> _saveCurrentScan() async {
    if (_results.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No images to save.')));
      return;
    }
    final now = DateTime.now();

    // Use the new readable format
    final String dateStr = DateFormat('MMM-d-y').format(now);
    final String timeStr = DateFormat('h-mm_a').format(now);
    final folderName = "Scan_${dateStr}_$timeStr";

    // --- This will hold the value from the dropdown ---
    String? selectedRowTag = "Row 1";
    String otherRowTag = ""; // For the "Other" text field

    // --- Generate our dropdown list ---
    List<String> rowOptions = List.generate(20, (i) => "Row ${i + 1}");
    rowOptions.add("Other"); // Add "Other" at the end

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        // We use a StatefulBuilder so the dialog can update its own state
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              title: Text(
                'Save Scan',
                style: GoogleFonts.poppins(
                  color: Colors.brown,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
              // Make the content scrollable
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'This will save ${_results.length} images to a new album:',
                      style: GoogleFonts.poppins(
                        color: Colors.black87,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // The album name
                    Text(
                      '"$folderName"',
                      style: GoogleFonts.poppins(
                        color: Colors.black,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Please select the Row/Location for this scan:',
                      style: GoogleFonts.poppins(
                        color: Colors.black87,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // The new Dropdown menu
                    DropdownButtonFormField<String>(
                      value: selectedRowTag,
                      items: rowOptions.map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                      onChanged: (newValue) {
                        setDialogState(() {
                          selectedRowTag = newValue;
                        });
                      },
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                    ),
                    // This text field only appears if "Other" is selected
                    if (selectedRowTag == "Other")
                      Padding(
                        padding: const EdgeInsets.only(top: 10.0),
                        child: TextField(
                          autofocus: true,
                          decoration: InputDecoration(
                            labelText: "Custom Location",
                            hintText: "e.g., North Field",
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onChanged: (value) {
                            otherRowTag = value;
                          },
                        ),
                      ),
                  ],
                ),
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
                  onPressed: () {
                    // Check if they chose "Other" but left it blank
                    if (selectedRowTag == "Other" &&
                        otherRowTag.trim().isEmpty) {
                      // Don't close, show an error (or just do nothing)
                      return;
                    }
                    Navigator.pop(context, true);
                  },
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
            );
          },
        );
      },
    );

    if (confirm != true) return; // User pressed "Cancel"

    // Determine the final tag
    final String finalRowTag = (selectedRowTag == "Other")
        ? otherRowTag.trim()
        : selectedRowTag ?? "N/A";

    try {
      // 🔹 MODIFIED: Call the new function to save both album name and tag
      await DatabaseHelper.instance.updateAlbumAndTag(
        'Current Scan',
        folderName,
        finalRowTag,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✓ Scan saved to album "$folderName" with tag "$finalRowTag"',
            ),
          ),
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
                // 🔹 MODIFIED: We must call the save function
                // but we can't pop(false) until it's done.
                await _saveCurrentScan();
                // If save was successful, _results will be empty,
                // and the dialog won't show again.
                // We pop(false) to just close the dialog.
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

  // 🔹 --- MODIFIED WIDGET (Removed row tag display from here) --- 🔹
  Widget _buildImageTile(DetectionResult res) {
    final fileOk = res.file.existsSync();
    final color = (res.label == 'Healthy')
        ? Colors.green.shade800
        : (res.label == null)
        ? Colors.grey.shade700
        : Colors.red.shade800;

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
          // We no longer need to .then() and refresh the state here,
          // as the tag is added during save, not in the viewer.
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
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                  color: color.withOpacity(0.8),
                  child: Text(
                    res.label!,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

            // The row tag is removed from here because these images
            // are in "Current Scan" and haven't been tagged yet.
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
              onPressed: _saveCurrentScan, // This now calls our new dialog
            ),
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

        // --- Floating Action Buttons (Unchanged) ---
        floatingActionButton: Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: SpeedDial(
            icon: Icons.add,
            activeIcon: Icons.close,
            backgroundColor: kOrange,
            foregroundColor: Colors.white,
            visible: true,
            curve: Curves.bounceIn,
            heroTag: 'fab-main',
            children: [
              SpeedDialChild(
                child: const Icon(
                  Icons.airplanemode_active,
                  color: Colors.white,
                ),
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
