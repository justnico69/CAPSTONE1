import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'analysis_viewer_page.dart';
import 'config.dart';
import 'database_helper.dart';

const Color kDarkBrown = Color.fromARGB(255, 128, 68, 12);
const Color kOrange = Color(0xFFEAA944);

class AlbumDetail extends StatefulWidget {
  final String albumName;

  // 🔹 Change: The 'date' parameter is no longer needed,
  // as all data is fetched using the albumName.
  const AlbumDetail({Key? key, required this.albumName}) : super(key: key);

  @override
  State<AlbumDetail> createState() => _AlbumDetailState();
}

class _AlbumDetailState extends State<AlbumDetail> {
  List<DetectionResult> _results = [];
  bool _isLoading = true; // Added for better user experience

  @override
  void initState() {
    super.initState();
    _loadAlbumDetails();
  }

  /// 🔹 Change: This function now loads all analysis results for this album
  /// from the database with a single, efficient query.
  Future<void> _loadAlbumDetails() async {
    // Set loading state
    if (mounted) setState(() => _isLoading = true);

    final resultsFromDb = await DatabaseHelper.instance.getAnalysesForAlbum(
      widget.albumName,
    );

    if (mounted) {
      setState(() {
        _results = resultsFromDb;
        _isLoading = false; // Done loading
      });
    }
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
                  "${res.captureTime?.hour}:${res.captureTime?.minute.toString().padLeft(2, '0')}",
            ),
          ),
        );
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          exists
              ? Image.file(res.file, fit: BoxFit.cover)
              : Container(
                  color: Colors.black12,
                  child: const Center(
                    child: Icon(
                      Icons.broken_image,
                      color: Colors.grey,
                      size: 40,
                    ),
                  ),
                ),
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _results.isEmpty
          ? Center(
              child: Text(
                "No images found in this album.",
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
