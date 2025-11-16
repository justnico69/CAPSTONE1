import 'package:flutter/material.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
// import 'package:google_fonts/google_fonts.dart'; // No longer needed
import 'package:installed_apps/app_info.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:spotato/image_handler.dart';

// import 'package:tflite_flutter/tflite_flutter.dart'; // No longer needed here

import 'analysis.dart';
import 'analysis_viewer_page.dart';
import 'config.dart'; // 👈 Import config
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

// 🔹 --- 1. ADD 'WidgetsBindingObserver' --- 🔹
// This lets us "watch" for when the app is paused or resumed.
class _RowDetailPageState extends State<RowDetailPage>
    with WidgetsBindingObserver {
  List<DetectionResult> _results = [];
  String _telloPackage = "";
  late DateTime _lastImportTimestamp;

  @override
  void initState() {
    super.initState();
    _telloPackage = widget.telloPackage;
    _lastImportTimestamp = DateTime.now().toUtc();

    // 🔹 --- 2. REGISTER THE OBSERVER --- 🔹
    // This tells Flutter we want to know about lifecycle changes.
    WidgetsBinding.instance.addObserver(this);

    // 1. Request permission (this is fast and safe to call)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestNotificationPermission();
    });

    // 2. Run the simple init tasks (this still only runs once)
    _init();
  }

  // 🔹 --- 3. ADD THE 'dispose' METHOD --- 🔹
  // This cleans up the observer when the page is closed.
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // 🔹 --- 4. ADD THE 'didChangeAppLifecycleState' METHOD --- 🔹
  // This is the magic! This function is called every time
  // the user leaves the app or comes back to it.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // Check if the state is "resumed"
    if (state == AppLifecycleState.resumed) {
      // The user just came back to the app (e.g., from the Tello app)
      debugPrint("--- APP RESUMED --- Running Tello import check.");

      // Automatically run the import function
      _importFromTelloFolder();
    }
  }

  // New, simple permission request function
  Future<void> _requestNotificationPermission() async {
    await NotificationService.requestPermission();
  }

  // 🔹 --- 5. MODIFIED _init() --- 🔹
  // We REMOVED the auto-import from here, because it will
  // now be handled by 'didChangeAppLifecycleState'
  void _init() {
    _loadImages(); // Just load the images from DB

    if (_results.isNotEmpty) {
      debugPrint(
        "Clearing ${_results.length} leftover images from previous session.",
      );
      _clearCurrentScan(updateState: false);
    }

    if (_telloPackage.isEmpty) {
      _checkTelloApp();
    }

    // The _importFromTelloFolder() call was removed from here.
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

  Future<void> _loadImages() async {
    final loadedResults = await DatabaseHelper.instance.getAnalysesForAlbum(
      'Current Scan',
    );
    if (!mounted) return;
    setState(() => _results = loadedResults);
  }

  Future<void> _pickFromGallery() async {
    try {
      debugPrint("Checking photos permission...");
      var status = await Permission.photos.status;

      if (status.isDenied) {
        debugPrint("Photos permission is denied. Requesting...");
        status = await Permission.photos.request();
      }

      if (status.isPermanentlyDenied) {
        debugPrint("Photos permission permanently denied.");
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
        debugPrint("Photos permission granted. Opening gallery.");
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

        await _runAnalysis(newResult);
        if (mounted) setState(() => _results.add(newResult));

        await NotificationService.show(
          title: "SPOTATO",
          body: "Analysis complete: ${newResult.label ?? 'Unknown'}",
        );
      } else {
        debugPrint("Photos permission was not granted.");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Photo access is required to add from gallery.'),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("Failed to pick image: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to get image. Check permissions.'),
          ),
        );
      }
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
            'Fly your drone, take photos, then return here. New photos will be imported automatically.', // 👈 Updated text
          ),
          duration: Duration(seconds: 6),
        ),
      );
    }
  }

  Future<void> _importFromTelloFolder() async {
    debugPrint("--- AUTO-IMPORT TELLO PHOTOS RUNNING ---");

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
          debugPrint("No new Tello photos found.");
        }
        return;
      }

      for (var file in sourceFiles) {
        final compressedFile = await ImageHandler.compressImage(file);
        if (compressedFile != null) {
          final newRes = DetectionResult(
            file: compressedFile,
            captureTime: await compressedFile.lastModified(),
          );

          await _runAnalysis(newRes);
          if (mounted) setState(() => _results.add(newRes));

          await NotificationService.show(
            title: "SPOTATO Analysis",
            body: "New Tello image analyzed: ${newRes.label ?? 'Unknown'}",
          );
        }
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
    if (globalInterpreter == null) {
      debugPrint("!!! [RUN ANALYSIS] Model not loaded, analysis skipped.");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: AI Model is not loaded.')),
        );
      }
      return;
    }

    if (!mounted) return;
    setState(() => res.isLoading = true);
    await runModelAnalysis(res);
    res.rowTag = null;

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

    String? selectedRowTag = "Row 1";
    String otherRowTag = "";

    List<String> rowOptions = List.generate(10, (i) => "Row ${i + 1}");
    rowOptions.add("Other");

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              title: Text(
                'Save Scan',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: Colors.brown,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'This will save ${_results.length} images to a new album:',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        color: Colors.black87,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '"$folderName"',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        color: Colors.black,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Please select the Row/Location for this scan:',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        color: Colors.black87,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
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
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      color: Colors.brown,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (selectedRowTag == "Other" &&
                        otherRowTag.trim().isEmpty) {
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
                    style: TextStyle(
                      fontFamily: 'Poppins',
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

    if (confirm != true) return;

    final String finalRowTag = (selectedRowTag == "Other")
        ? otherRowTag.trim()
        : selectedRowTag ?? "N/A";

    try {
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
        setState(() {
          _results.clear();
        });
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
            style: TextStyle(
              fontFamily: 'Poppins',
              color: Colors.brown,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
          content: Text(
            'You have unsaved images. Would you like to save before exiting?',
            style: TextStyle(
              fontFamily: 'Poppins',
              color: Colors.black87,
              fontSize: 14,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Cancel',
                style: TextStyle(
                  fontFamily: 'Poppins',
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
                style: TextStyle(
                  fontFamily: 'Poppins',
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
                style: TextStyle(
                  fontFamily: 'Poppins',
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
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4.0),
        child: Stack(
          fit: StackFit.expand,
          children: [
            fileOk
                ? Image.file(res.file, fit: BoxFit.cover)
                : Container(color: Colors.black),
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
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      color: Colors.white,
                      fontSize: 10,
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

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      title: Text(
        widget.rowName,
        style: TextStyle(
          fontFamily: 'Poppins',
          color: kDarkBrown,
          fontWeight: FontWeight.bold,
        ),
      ),
      iconTheme: const IconThemeData(color: kDarkBrown),
      actions: [
        IconButton(
          icon: const Icon(Icons.folder_open),
          tooltip: 'Save as Album',
          color: kDarkBrown,
          onPressed: _saveCurrentScan,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: const Color.fromARGB(243, 248, 248, 248),
        appBar: _buildAppBar(),
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

        // 🔹 --- 6. REMOVED THE BUTTON --- 🔹
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
                labelStyle: TextStyle(fontFamily: 'Poppins'),
                onTap: _launchTelloApp,
              ),
              //
              // 🔹 --- THIS BUTTON IS GONE --- 🔹
              //
              // SpeedDialChild(
              //   child: const Icon(Icons.download, color: Colors.white),
              //   backgroundColor: kDarkBrown.withOpacity(0.85),
              //   label: 'Import Tello Photos',
              //   labelStyle: TextStyle(fontFamily: 'Poppins'),
              //   onTap: _importFromTelloFolder,
              // ),
              //
              SpeedDialChild(
                child: const Icon(Icons.photo_library, color: Colors.white),
                backgroundColor: kOrange,
                label: 'Add from Gallery',
                labelStyle: TextStyle(fontFamily: 'Poppins'),
                onTap: _pickFromGallery,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
