//row_detail.dart
import 'package:flutter/material.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:installed_apps/app_info.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:spotato/image_handler.dart';

import 'analysis.dart';
import 'analysis_viewer_page.dart';
import 'config.dart';
import 'database_helper.dart';
import 'notification_service.dart';

const Color kDarkBrown = Color.fromARGB(255, 128, 68, 12);
const Color kOrange = Color(0xFFEAA944);

/// This page manages the "Current Scan" session.
/// It handles image import (gallery/drone), analysis, and saving to an album.
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

/// We mix in [WidgetsBindingObserver] to listen for app lifecycle changes.
/// This allows us to detect when the user returns to the app from the Tello app.
class _RowDetailPageState extends State<RowDetailPage>
    with WidgetsBindingObserver {
  List<DetectionResult> _results = [];
  String _telloPackage = "";
  late DateTime _lastImportTimestamp; // The "memory" of the last import time

  @override
  void initState() {
    super.initState();
    _telloPackage = widget.telloPackage;

    // Store the time in UTC to avoid timezone bugs with file timestamps
    _lastImportTimestamp = DateTime.now().toUtc();

    // Register this page as an "observer" of the app's lifecycle
    WidgetsBinding.instance.addObserver(this);

    // After the first frame, request notification permissions
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestNotificationPermission();
    });

    // Run the initial setup
    _init();
  }

  /// Clean up the observer when the page is closed to prevent memory leaks
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// This function is called every time the user leaves or returns to the app.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // When the user returns to the app (e.g., after using the Tello app)
    if (state == AppLifecycleState.resumed) {
      debugPrint("--- APP RESUMED --- Running Tello import check.");

      // Automatically run the import function
      _importFromTelloFolder();
    }
  }

  /// Asks for permission to send notifications
  Future<void> _requestNotificationPermission() async {
    await NotificationService.requestPermission();
  }

  /// Runs once on page load to prepare the session.
  /// This clears any leftover images from a previous, unsaved session.
  void _init() {
    _loadImages(); // Load any images from the 'Current Scan' in the DB

    if (_results.isNotEmpty) {
      debugPrint(
        "Clearing ${_results.length} leftover images from previous session.",
      );
      _clearCurrentScan(updateState: false);
    }

    if (_telloPackage.isEmpty) {
      _checkTelloApp();
    }
  }

  /// Scans the user's device for the Tello drone app package
  Future<void> _checkTelloApp() async {
    try {
      List<AppInfo> apps = await InstalledApps.getInstalledApps(true, true);
      for (var app in apps) {
        if (app.packageName == "com.ryzerobotics.tello") {
          if (mounted) setState(() => _telloPackage = app.packageName);
          break;
        }
      }
    } catch (_) {
      debugPrint("Could not check for installed apps.");
    }
  }

  /// Loads images from the database that are in the 'Current Scan' album
  Future<void> _loadImages() async {
    final loadedResults = await DatabaseHelper.instance.getAnalysesForAlbum(
      'Current Scan',
    );
    if (!mounted) return;
    setState(() => _results = loadedResults);
  }

  /// Prompts the user to pick an image from their phone's gallery
  Future<void> _pickFromGallery() async {
    try {
      // 1. Check and request photo permission
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

      // 2. Only proceed if permission is granted
      if (status.isGranted) {
        final sourceFile = await ImageHandler.pickFromGallery();
        if (sourceFile == null) return; // User cancelled

        // 3. Compress the image
        final compressedFile = await ImageHandler.compressImage(sourceFile);
        if (compressedFile == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to process image.')),
            );
          }
          return;
        }

        // 4. Create a result object and run analysis
        final newResult = DetectionResult(
          file: compressedFile,
          captureTime: await compressedFile.lastModified(),
        );

        await _runAnalysis(newResult);
        if (mounted) setState(() => _results.add(newResult));

        // 5. Send notification
        await NotificationService.show(
          title: "SPOTATO",
          body: "Analysis complete: ${newResult.label ?? 'Unknown'}",
        );
      } else {
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
    }
  }

  /// Launches the external Tello drone app
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

    // Show a helpful instruction message
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Fly your drone, take photos, then return here. New photos will be imported automatically.',
          ),
          duration: Duration(seconds: 6),
        ),
      );
    }
  }

  /// Automatically imports new photos from the Tello folder
  Future<void> _importFromTelloFolder() async {
    debugPrint("--- AUTO-IMPORT TELLO PHOTOS RUNNING ---");

    // 1. Check for "All Files Access" permission
    var status = await Permission.manageExternalStorage.status;
    debugPrint(
      "1. Checking 'Manage External Storage' permission. Status: ${status.name}",
    );

    if (status.isDenied) {
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

    // 2. Only proceed if permission is granted
    if (status.isGranted) {
      debugPrint("3. ✅ Permission is GRANTED.");

      // Get the current time in UTC *before* checking
      final importCheckTime = DateTime.now().toUtc();
      debugPrint(
        "4. Calling ImageHandler. Checking for files modified AFTER (UTC): ${_lastImportTimestamp.toIso8601String()}",
      );

      // 3. Call the ImageHandler to find new files
      final sourceFiles = await ImageHandler.importFromTello(
        _lastImportTimestamp, // Pass the "memory" of the last import
      );

      // 4. Update the "memory" to this new time
      _lastImportTimestamp = importCheckTime;
      debugPrint("5. Import finished. Found ${sourceFiles.length} new files.");

      if (sourceFiles.isEmpty) {
        debugPrint("No new Tello photos found.");
        return;
      }

      // 5. Loop through, compress, and analyze each new file
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

  /// Runs the AI model on a single image and saves the result to the DB
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

    await runModelAnalysis(res); // This function is in 'analysis.dart'
    res.rowTag = null; // The row tag is only added when saving the album

    // Save to the DB.
    await DatabaseHelper.instance.insertAnalysis(res, 'Current Scan');

    if (!mounted) return;
    setState(() => res.isLoading = false);
  }

  /// Shows the "Save Scan" dialog and assigns a Row Tag
  Future<void> _saveCurrentScan() async {
    if (_results.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No images to save.')));
      return;
    }
    final now = DateTime.now();

    // Create the user-friendly album name (e.g., "Scan_Nov-16-2025_7-40_PM")
    final String dateStr = DateFormat('MMM-d-y').format(now);
    final String timeStr = DateFormat('h-mm_a').format(now);
    final folderName = "Scan_${dateStr}_$timeStr";

    String? selectedRowTag = "Row 1";
    String otherRowTag = "";

    // Generate the list of "Row 1", "Row 2", ... "Row 10"
    List<String> rowOptions = List.generate(10, (i) => "Row ${i + 1}");
    rowOptions.add("Other"); // Add "Other" at the end

    // Show the pop-up dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        // Use a StatefulBuilder so the dropdown can update *inside* the dialog
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
                    // The scrollable dropdown menu
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
                    // The text field that appears if "Other" is selected
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
                    // Validation: Don't allow saving if "Other" is chosen but blank
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

    if (confirm != true) return; // User pressed "Cancel"

    // Get the final tag ("Other" or "Row X")
    final String finalRowTag = (selectedRowTag == "Other")
        ? otherRowTag.trim()
        : selectedRowTag ?? "N/A";

    // Save the new album name and row tag to the database
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
        setState(() => _results.clear()); // Clear the UI
      }
    } catch (e) {
      debugPrint('Save error: $e');
    }
  }

  /// Deletes all images (files and DB) from the "Current Scan"
  Future<void> _clearCurrentScan({bool updateState = true}) async {
    try {
      final resultsToClear = List<DetectionResult>.from(_results);
      // 1. Delete the physical files from the phone's storage
      for (var res in resultsToClear) {
        if (await res.file.exists()) {
          await res.file.delete();
        }
      }
      // 2. Delete the records from the database
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

  /// Handles the phone's back button press
  Future<bool> _onWillPop() async {
    if (_results.isNotEmpty) {
      // If there are unsaved images, show the "Unsaved Work" dialog
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
              onPressed: () => Navigator.of(context).pop(false), // Don't exit
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
                await _saveCurrentScan(); // Save the work
                if (mounted) Navigator.of(context).pop(false); // Don't exit
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
                _clearCurrentScan(updateState: false); // Clear the work
                Navigator.of(context).pop(true); // Exit the page
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
    return true; // No images, so allow the back press
  }

  /// Builds a single tile in the image grid
  Widget _buildImageTile(DetectionResult res) {
    final fileOk = res.file.existsSync();
    final color = (res.label == 'Healthy')
        ? Colors.green.shade800
        : (res.label == null)
        ? Colors.grey.shade700
        : Colors.red.shade800;

    return GestureDetector(
      onTap: () {
        // When tapped, open the detailed viewer page
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
            // The image itself
            fileOk
                ? Image.file(res.file, fit: BoxFit.cover)
                : Container(color: Colors.black),

            // The colored label bar at the bottom
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

  /// Builds the main AppBar for the page
  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      title: Text(
        widget.rowName, // "Current Scan"
        style: TextStyle(
          fontFamily: 'Poppins',
          color: kDarkBrown,
          fontWeight: FontWeight.bold,
        ),
      ),
      iconTheme: const IconThemeData(color: kDarkBrown),
      actions: [
        // The "Save" button
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
      onWillPop: _onWillPop, // Handle back button presses
      child: Scaffold(
        backgroundColor: const Color.fromARGB(243, 248, 248, 248),
        appBar: _buildAppBar(),
        body: GridView.builder(
          padding: const EdgeInsets.only(
            left: 8,
            right: 8,
            bottom: 200, // Padding at the bottom for the FAB
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

        // The Floating Action Button (FAB) with multiple options
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
