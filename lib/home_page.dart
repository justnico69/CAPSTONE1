import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:installed_apps/app_info.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:spotato/album_page.dart';
import 'package:spotato/analysis_viewer_page.dart';
import 'package:spotato/config.dart';
import 'package:spotato/database_helper.dart';
import 'package:spotato/row_detail.dart';
import 'package:spotato/tutorial_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String telloPackage = '';
  // 🔹 Changed: We now have TWO variables.
  // 1. The Future for the *initial* load.
  late Future<List<DetectionResult>> _initialLoadFuture;
  // 2. A List to hold the current data (for instant refreshes).
  List<DetectionResult>? _recentResults;

  @override
  void initState() {
    super.initState();
    checkInstalledApps();
    // ✅ Assign the future here ONCE for the initial load.
    _initialLoadFuture = DatabaseHelper.instance.getRecentAnalyses();
  }

  Future<void> checkInstalledApps() async {
    // ... (This function remains unchanged)
    try {
      List<AppInfo> apps = await InstalledApps.getInstalledApps(true, true);
      for (var app in apps) {
        if (app.packageName == "com.ryzerobotics.tello") {
          telloPackage = app.packageName;
          break;
        }
      }
    } catch (e) {
      debugPrint("Could not check for installed apps: $e");
    }
  }

  /// 🔹 Changed: This is now our "refresh" function.
  /// It fetches new data and uses setState to update the UI instantly.
  Future<void> _refreshRecentImages() async {
    final results = await DatabaseHelper.instance.getRecentAnalyses();
    if (mounted) {
      setState(() {
        _recentResults = results; // Update the list
      });
    }
  }

  /// 🔹 Changed: Now calls our new "refresh" function.
  void _navigateAndRefresh(BuildContext context, Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => page)).then(
      (_) {
        // Refresh the list when the user returns.
        _refreshRecentImages();
      },
    );
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
            _refreshRecentImages(); // Call the refresh function
          } else if (label == "Albums") {
            _navigateAndRefresh(context, const AlbumsPage());
          }
        },
        child: Column(
          // ... (rest of this widget is unchanged)
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
          // HEADER (Unchanged)
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
                  child: Row(
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
                            mainAxisAlignment: MainAxisAlignment.center,
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
                                        color: Color.fromARGB(255, 128, 68, 12),
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
                                  color: const Color.fromARGB(255, 160, 98, 45),
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
                        // 🔹 Changed: Use a simple push for the TutorialPage (no refresh needed)
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const TutorialPage(),
                          ),
                        ),
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

                  // ✅ Changed: The FutureBuilder now uses our initial-load-only future.
                  FutureBuilder<List<DetectionResult>>(
                    future: _initialLoadFuture,
                    builder: (context, snapshot) {
                      // 🔹 Changed: We check our state list FIRST, then the snapshot.
                      // This ensures refreshes are instant.
                      final recentResults = _recentResults ?? snapshot.data;

                      // 1. WHILE LOADING (INITIAL LOAD ONLY):
                      if (recentResults == null &&
                          snapshot.connectionState == ConnectionState.waiting) {
                        return Center(
                          child: Padding(
                            padding: EdgeInsets.all(40.0),
                            child: CircularProgressIndicator(
                              color: Color(0xFFEAA944),
                            ),
                          ),
                        );
                      }

                      // 2. ON ERROR (INITIAL LOAD ONLY):
                      if (snapshot.hasError && _recentResults == null) {
                        return const Center(
                          child: Text("Error loading recent images."),
                        );
                      }

                      final recentResultsList = recentResults ?? [];

                      // 3. IF EMPTY:
                      if (recentResultsList.isEmpty) {
                        return Container(
                          // ... (empty state UI remains the same)
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
                            children: [
                              Text(
                                "No recent images have been added yet.",
                                textAlign: TextAlign.center,
                                style: GoogleFonts.poppins(
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 20),
                              ElevatedButton(
                                onPressed: () => _navigateAndRefresh(
                                  context,
                                  const RowDetailPage(
                                    albumName: "New Detections",
                                    rowName: "Current Scan",
                                  ),
                                ),
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
                        );
                      }

                      // 4. IF DATA EXISTS:
                      return Column(
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
                            itemCount: recentResultsList.length,
                            itemBuilder: (_, i) {
                              final res = recentResultsList[i];
                              return GestureDetector(
                                onTap: () => _navigateAndRefresh(
                                  context,
                                  AnalysisViewerPage(
                                    detectionResult: res,
                                    durationText:
                                        res.analysisDuration?.inMilliseconds
                                            .toString() ??
                                        "N/A",
                                    dateCaptured:
                                        "${res.captureTime?.month}/${res.captureTime?.day}/${res.captureTime?.year}",
                                    timeCaptured:
                                        "${res.captureTime?.hour}:${res.captureTime?.minute.toString().padLeft(2, '0')}",
                                  ),
                                ),
                                child: Container(
                                  // ... (rest of this UI is unchanged)
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
                                      errorBuilder: (c, o, s) => const Center(
                                        child: Icon(Icons.broken_image),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 30),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () => _navigateAndRefresh(
                                context,
                                const RowDetailPage(
                                  albumName: "New Detections",
                                  rowName: "Current Scan",
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFEAA944),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(
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
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),

      // NAVIGATION BAR (Unchanged)
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
