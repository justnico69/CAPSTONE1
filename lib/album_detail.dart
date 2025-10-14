import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';

import 'analysis_viewer_page.dart';
// Import DetectionResult from config.dart
import 'config.dart';

const Color kDarkBrown = Color.fromARGB(255, 128, 68, 12);
const Color kOrange = Color(0xFFEAA944);

class AlbumDetail extends StatefulWidget {
  final String albumName;
  final String date;

  const AlbumDetail({Key? key, required this.albumName, required this.date})
    : super(key: key);

  @override
  State<AlbumDetail> createState() => _AlbumDetailState();
}

class _AlbumDetailState extends State<AlbumDetail> {
  List<DetectionResult> _results = [];

  @override
  void initState() {
    super.initState();
    _loadSavedImages();
  }

  Future<void> _loadSavedImages() async {
    final dir = await getApplicationDocumentsDirectory();
    final folder = Directory(
      '${dir.path}/SPOTATO/New Detections/${widget.albumName}',
    );
    if (!await folder.exists()) return;

    final files = folder.listSync().whereType<File>().toList();
    final jsonFile = File('${folder.path}/results.json');
    Map<String, String> labelMap = {};

    if (await jsonFile.exists()) {
      final content = await jsonFile.readAsString();
      final entries = content
          .replaceAll(RegExp(r'^\[|\]$'), '')
          .split('},')
          .map((e) => e.replaceAll(RegExp(r'[\[\]\{\}]'), '').trim())
          .where((e) => e.isNotEmpty);

      for (var entry in entries) {
        final parts = entry.split(',');
        String? filename;
        String? label;
        for (var part in parts) {
          final kv = part.split(':');
          if (kv.length == 2) {
            final key = kv[0].trim().replaceAll("'", '');
            final value = kv[1].trim().replaceAll("'", '');
            if (key == 'filename') filename = value;
            if (key == 'label') label = value;
          }
        }
        if (filename != null && label != null) {
          labelMap[filename] = label;
        }
      }
    }

    final loaded = files
        .where((f) => f.path.endsWith('.jpg') || f.path.endsWith('.png'))
        .map(
          (f) => DetectionResult(
            file: f,
            label: labelMap[f.uri.pathSegments.last] ?? 'Unknown',
            captureTime: f.lastModifiedSync(),
          ),
        )
        .toList();

    setState(() => _results = loaded);
  }

  /// Extracts label from filename (if available)
  String? _extractLabel(String path) {
    final name = path.split('/').last.toLowerCase();
    if (name.contains('healthy')) return 'Healthy';
    if (name.contains('blight')) return 'Blight';
    if (name.contains('early')) return 'Early Blight';
    if (name.contains('late')) return 'Late Blight';
    return 'Unknown';
  }

  Color _getLabelColor(String? label) {
    switch (label) {
      case 'Healthy':
        return Colors.green;
      case 'Blight':
      case 'Late Blight':
      case 'Early Blight':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _buildImageTile(DetectionResult res) {
    final exists = res.file.existsSync();
    final color = _getLabelColor(res.label);

    return GestureDetector(
      onTap: () {
        if (!exists) return;
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
          exists
              ? Image.file(res.file, fit: BoxFit.cover)
              : Container(color: Colors.black12),
          Positioned(
            bottom: 6,
            left: 6,
            right: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.8),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                res.label ?? 'Unknown',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
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
      backgroundColor: const Color.fromARGB(243, 248, 248, 248),
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text(
          widget.albumName.replaceFirst("Scan_", "").replaceAll("_", " "),
          style: GoogleFonts.poppins(
            color: kDarkBrown,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: kDarkBrown),
      ),
      body: _results.isEmpty
          ? Center(
              child: Text(
                "No images found in this folder.",
                style: GoogleFonts.poppins(
                  color: Colors.grey[600],
                  fontSize: 16,
                ),
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(10),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
              ),
              itemCount: _results.length,
              itemBuilder: (_, i) => _buildImageTile(_results[i]),
            ),
    );
  }
}
