import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:installed_apps/app_info.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

import 'analysis.dart';
import 'analysis_viewer_page.dart';
import 'config.dart';
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
  final ImagePicker _picker = ImagePicker();
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

  @override
  void dispose() {
    globalInterpreter?.close();
    super.dispose();
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
    if (_modelLoaded) return;
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

  Future<Directory> _getCurrentScanDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = Directory('${dir.path}/SPOTATO/New Detections/Current Scan');
    if (!await path.exists()) {
      await path.create(recursive: true); // ✅ Recreate folder
    }
    return path;
  }

  Future<void> _loadImages() async {
    final folder = await _getCurrentScanDir();
    final files = folder.listSync().whereType<File>().toList();
    final loaded = files
        .map((f) => DetectionResult(file: f, captureTime: f.lastModifiedSync()))
        .toList();

    if (!mounted) return;
    setState(() => _results = loaded);

    for (var r in _results.where((x) => x.label == null)) {
      _runAnalysis(r);
    }
  }

  Future<void> _pickFromGallery() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    final folder = await _getCurrentScanDir();
    final dest = File('${folder.path}/${picked.name}');
    await File(picked.path).copy(dest.path);
    final newResult = DetectionResult(
      file: dest,
      captureTime: dest.lastModifiedSync(),
    );
    if (mounted) setState(() => _results.add(newResult));
    await _runAnalysis(newResult);

    await NotificationService.show(
      title: "SPOTATO",
      body: "Gallery image analysis completed!",
    );
  }

  Future<void> _launchTelloAndFetch() async {
    if (_telloPackage.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Tello app not found.')));
      return;
    }

    await InstalledApps.startApp(_telloPackage);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('📸 Open Tello, take pictures, then return here.'),
      ),
    );

    await Future.delayed(const Duration(seconds: 8));
    await _importFromTelloFolder();
  }

  Future<void> _importFromTelloFolder() async {
    final telloDir = Directory('/storage/emulated/0/Pictures/TelloPhoto');
    if (!await telloDir.exists()) return;

    final now = DateTime.now();
    final files = telloDir.listSync().whereType<File>().where((f) {
      final mod = f.lastModifiedSync();
      return now.difference(mod).inMinutes <= 10;
    }).toList();

    if (files.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No recent Tello photos found.')),
      );
      return;
    }

    final scanDir = await _getCurrentScanDir();
    int analyzed = 0;

    for (var f in files) {
      final name = f.uri.pathSegments.last;
      final dest = File('${scanDir.path}/$name');
      if (!await dest.exists()) {
        await f.copy(dest.path);
        final newRes = DetectionResult(
          file: dest,
          captureTime: dest.lastModifiedSync(),
        );
        if (mounted) setState(() => _results.add(newRes));
        await _runAnalysis(newRes);
        analyzed++;
      }
    }

    await NotificationService.show(
      title: "SPOTATO Analysis Complete",
      body: "$analyzed Tello image(s) analyzed successfully!",
    );
  }

  Future<void> _runAnalysis(DetectionResult res) async {
    if (!mounted) return;
    setState(() => res.isLoading = true);
    await runModelAnalysis(res);
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
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
    contentPadding: const EdgeInsets.all(20),
    insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 30),

    title: Text(
      'Save Scan',
      style: GoogleFonts.poppins(
        color: Colors.brown,
        fontWeight: FontWeight.w800,
        fontSize: 18,
      ),
    ),
    content: Text(
      'You will be saving these images into a folder "$folderName".\n\nProceed?',
      style: GoogleFonts.poppins(
        color: Colors.black87,
        fontSize: 14,
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
      final base = await getApplicationDocumentsDirectory();
      final destDir = Directory(
        '${base.path}/SPOTATO/New Detections/$folderName',
      );
      await destDir.create(recursive: true);

      for (var res in _results) {
        final imgName = res.file.uri.pathSegments.last;
        final imgPath = '${destDir.path}/$imgName';
        await res.file.copy(imgPath);

        // 📝 Save metadata in a text file beside the image
        final metaFile = File('$imgPath.txt');
        await metaFile.writeAsString('''
        Label: ${res.label ?? 'Unknown'}
        Duration: ${res.analysisDuration?.inMilliseconds ?? 0}ms
        Captured: ${res.captureTime?.toIso8601String() ?? ''}
        ''');
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('✅ Scan saved to "$folderName"')));

      await _clearCurrentScan();
    } catch (e) {
      debugPrint('❌ Save error: $e');
    }
  }

  Future<void> _clearCurrentScan() async {
    try {
      final dir = await _getCurrentScanDir();
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
      if (mounted) setState(() => _results.clear());
    } catch (e) {
      debugPrint('⚠️ Failed to clear: $e');
    }
  }

  Future<bool> _onWillPop() async {
    final bool isScanning = _results.any((r) => r.isLoading);
    final bool hasUnsavedData = _results.isNotEmpty;

    if (isScanning) {
      final shouldExit = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Analysis in Progress'),
          content: const Text(
              'Some images are still being analyzed. Are you sure you want to exit?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Stay'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Exit', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
 return shouldExit ?? false;
    } else if (hasUnsavedData) {
      final shouldExit = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          contentPadding: const EdgeInsets.all(20),
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 40, vertical: 30), // screen margin

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
            style: GoogleFonts.poppins(
              color: Colors.black87,
              fontSize: 14,
            ),
          ),
          actionsPadding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                Navigator.of(context).pop(false);
                await _saveCurrentScan();
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
              onPressed: () => Navigator.of(context).pop(true),
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
        : (res.label == 'Unknown')
            ? Colors.yellow
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
                  "${res.captureTime?.hour}:${res.captureTime?.minute}",
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
    const kLightBackground = Colors.white;

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: const Color.fromARGB(243, 248, 248, 248),
        appBar: AppBar(
          backgroundColor: kLightBackground,
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
                  r.label = null;
                  r.isLoading = false;
                }
                setState(() {});
                for (var r in _results) {
                  await _runAnalysis(r);
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.folder_open),
              tooltip: 'Save as Folder',
              color: kDarkBrown,
              onPressed: _saveCurrentScan,
            ),
          ],
        ),
        body: GridView.builder(
          padding:
              const EdgeInsets.only(left: 8, right: 8, bottom: 100, top: 10),
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
              icon:
                  const Icon(Icons.airplanemode_active, color: Colors.white),
              label: const Text('Use Tello',
                  style: TextStyle(color: Colors.white)),
            ),
            const SizedBox(height: 10),
            FloatingActionButton.extended(
              onPressed: _pickFromGallery,
              backgroundColor: kOrange,
              icon: const Icon(Icons.photo_library, color: Colors.white),
              label: const Text('Add Image',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
