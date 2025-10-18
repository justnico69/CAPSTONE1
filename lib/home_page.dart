import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:installed_apps/app_info.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:path_provider/path_provider.dart';
import 'package:spotato/album_page.dart';
import 'package:spotato/analysis_viewer_page.dart'; // Make sure this exists
import 'package:spotato/config.dart'; // For DetectionResult
import 'package:spotato/row_detail.dart';
import 'package:spotato/tutorial_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String telloPackage = '';
  List<DetectionResult> _recentResults = [];

  @override
  void initState() {
    super.initState();
    checkInstalledApps();
    _loadRecentImages().then((res) {
      if (mounted) setState(() => _recentResults = res);
    });
  }

  /// Check if Tello app is installed
  Future<void> checkInstalledApps() async {
    List<AppInfo> apps = await InstalledApps.getInstalledApps(true, true);
    for (var app in apps) {
      if (app.packageName == "com.ryzerobotics.tello") {
        telloPackage = app.packageName;
        break;
      }
    }
  }

  /// Launch Tello if found
  Future<void> launchTello() async {
    if (telloPackage.isNotEmpty) {
      await InstalledApps.startApp(telloPackage);
    } else {
      debugPrint("Tello package not found.");
    }
  }

  /// Load 4 most recent analyzed images from Saved Albums
  Future<List<DetectionResult>> _loadRecentImages() async {
    final dir = await getApplicationDocumentsDirectory();
    final root = Directory('${dir.path}/SPOTATO/New Detections');
    if (!await root.exists()) return [];

    final folders = root
        .listSync()
        .whereType<Directory>()
        .where((d) => d.path.contains('Scan_'))
        .toList();

    List<DetectionResult> all = [];
    for (var folder in folders) {
      final files = folder
          .listSync()
          .whereType<File>()
          .where(
            (f) =>
                f.path.toLowerCase().endsWith('.jpg') ||
                f.path.toLowerCase().endsWith('.png'),
          )
          .toList();

      for (var f in files) {
        all.add(DetectionResult(file: f, captureTime: f.lastModifiedSync()));
      }
    }

    all.sort((a, b) => b.captureTime!.compareTo(a.captureTime!));
    return all.take(4).toList();
  }

  // --- BOTTOM NAV ITEM WIDGET ---
  Widget _buildBottomNavItem({
    required IconData icon,
    required String label,
    required bool isSelected,
    required double screenWidth,
  }) {
    final color = isSelected
        ? const Color.fromARGB(255, 82, 42, 4)
        : Colors.grey;

    return Expanded(
      child: InkWell(
        onTap: () {
          if (label == "Home") {
          } else if (label == "Albums") {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AlbumsPage()),
            );
          }
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: screenWidth * 0.06),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.poppins(
                color: color,
                fontSize: screenWidth * 0.03,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: const Color.fromARGB(243, 248, 248, 248),
      body: Column(
        children: [
          // HEADER
          ClipRRect(
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(70),
              bottomRight: Radius.circular(70),
            ),
            child: Container(
              height: screenHeight * 0.18,
              color: Colors.white,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(30, 0, 30, 0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Image.asset(
                                'assets/images/spotato_logo.png',
                                height: screenHeight * 0.05,
                              ),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  RichText(
                                    text: TextSpan(
                                      style: GoogleFonts.poppins(
                                        fontSize: 25,
                                        fontWeight: FontWeight.w800,
                                      ),
                                      children: const [
                                        TextSpan(
                                          text: 'SPOT',
                                          style: TextStyle(
                                            color: Color.fromARGB(
                                              255,
                                              128,
                                              68,
                                              12,
                                            ),
                                          ),
                                        ),
                                        TextSpan(
                                          text: 'ato',
                                          style: TextStyle(
                                            color: Color.fromARGB(
                                              255,
                                              236,
                                              185,
                                              74,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    "at your service!",
                                    style: GoogleFonts.poppins(
                                      color: const Color.fromARGB(
                                        255,
                                        160,
                                        98,
                                        45,
                                      ),
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.help_outline,
                              color: Color.fromARGB(255, 128, 68, 12),
                              size: 28,
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const TutorialPage(),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // MAIN CONTENT
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: screenWidth * 0.07,
                vertical: screenWidth * 0.08,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Recent Picture",
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: const Color.fromARGB(255, 128, 68, 12),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // IF EMPTY
                  _recentResults.isEmpty
                      ? Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(20),
                                blurRadius: 10,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "No recent images yet. Tap Button to scan.",
                                textAlign: TextAlign.center,
                                style: GoogleFonts.poppins(
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 50),
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const RowDetailPage(
                                        albumName: "New Detections",
                                        rowName: "Current Scan",
                                      ),
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFEAA944),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 40,
                                    vertical: 16,
                                  ),
                                ),
                                child: Text(
                                  "Detect Disease",
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      // IF THERE ARE IMAGES
                      : Column(
                          children: [
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    crossAxisSpacing: 10,
                                    mainAxisSpacing: 10,
                                  ),
                              itemCount: _recentResults.length,
                              itemBuilder: (_, i) {
                                final res = _recentResults[i];
                                return GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => AnalysisViewerPage(
                                          detectionResult: res,
                                          durationText:
                                              "N/A", // or replace with duration if you have it
                                          dateCaptured: res.captureTime != null
                                              ? "${res.captureTime!.month}-${res.captureTime!.day}-${res.captureTime!.year}"
                                              : "Unknown Date",
                                          timeCaptured: res.captureTime != null
                                              ? "${res.captureTime!.hour}:${res.captureTime!.minute.toString().padLeft(2, '0')}"
                                              : "Unknown Time",
                                        ),
                                      ),
                                    );
                                  },
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(10),
                                      color: Colors.white,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black12,
                                          blurRadius: 5,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: Image.file(
                                        res.file,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 30),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const RowDetailPage(
                                      albumName: "New Detections",
                                      rowName: "Current Scan",
                                    ),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFEAA944),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 40,
                                  vertical: 16,
                                ),
                              ),
                              child: Text(
                                "Detect Disease",
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 30),
        ],
      ),

      // NAVIGATION BAR
      bottomNavigationBar: BottomAppBar(
        color: Colors.white,
        elevation: 10.0,
        height: screenHeight * 0.09,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: <Widget>[
            _buildBottomNavItem(
              icon: Icons.home_filled,
              label: "Home",
              isSelected: true,
              screenWidth: screenWidth,
            ),
            _buildBottomNavItem(
              icon: Icons.photo_album,
              label: "Albums",
              isSelected: false,
              screenWidth: screenWidth,
            ),
          ],
        ),
      ),
    );
  }
}
