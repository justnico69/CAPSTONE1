import 'package:flutter/material.dart';
import 'package:installed_apps/app_info.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spotato/album_page.dart';
import 'package:spotato/analysis_viewer_page.dart';
import 'package:spotato/config.dart';
import 'package:spotato/database_helper.dart';
import 'package:spotato/row_detail.dart';
import 'package:spotato/tutorial_page.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

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

  // Tutorial Keys
  final GlobalKey _detectButtonKey = GlobalKey();
  final GlobalKey _albumsTabKey = GlobalKey();
  final GlobalKey _helpButtonKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    checkInstalledApps();
    // ✅ Assign the future here ONCE for the initial load.
    _initialLoadFuture = DatabaseHelper.instance.getRecentAnalyses();

    // Trigger tutorial after frame build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndShowTutorial();
    });
  }

  Future<void> _checkAndShowTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    final bool hasSeenTutorial = prefs.getBool('hasSeenHomeTutorial') ?? false;

    if (!hasSeenTutorial) {
      // Use a slight delay to ensure UI is ready
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) _showTutorial();
      });
    }
  }

  void _showTutorial() {
    TutorialCoachMark(
      targets: _createTargets(),
      colorShadow: Colors.white, // 🔹 Changed to White
      textSkip: "SKIP",
      textStyleSkip: const TextStyle(
        color: Color.fromARGB(255, 128, 68, 12), // 🔹 Dark Brown Skip
        fontWeight: FontWeight.bold,
      ),
      paddingFocus: 10,
      opacityShadow: 0.9, // 🔹 High opacity to hide clutter
      onFinish: () {
        _markTutorialSeen();
      },
      onSkip: () {
        _markTutorialSeen();
        return true;
      },
      onClickTarget: (target) {
        if (target.identify == "detectButton") {
          // 🔹 Interactive! Go to the next page.
          _navigateAndRefresh(
            context,
            const RowDetailPage(
              albumName: "New Detections",
              rowName: "Current Scan",
            ),
          );
        }
      },
    ).show(context: context);
  }

  Future<void> _markTutorialSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSeenHomeTutorial', true);
  }

  List<TargetFocus> _createTargets() {
    List<TargetFocus> targets = [];
    const kTextColor = Color.fromARGB(255, 128, 68, 12); // 🔹 Dark Brown Text

    // Target 1: Albums Tab
    targets.add(
      TargetFocus(
        identify: "albumsTab",
        keyTarget: _albumsTabKey,
        alignSkip: Alignment.topRight,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const <Widget>[
                  Text(
                    "View History",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: kTextColor, // 🔹 Dark Brown Text
                      fontSize: 20.0,
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.only(top: 10.0),
                    child: Text(
                      "Access your saved albums and past detection results here.",
                      style: TextStyle(color: kTextColor),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );

     // Target 2: Help Button
    targets.add(
      TargetFocus(
        identify: "helpButton",
        keyTarget: _helpButtonKey,
        alignSkip: Alignment.bottomLeft,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: const <Widget>[
                  Text(
                    "Need Help?",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: kTextColor, // 🔹 Dark Brown Text
                      fontSize: 20.0,
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.only(top: 10.0),
                    child: Text(
                      "Tap here to view the tutorial and guide again at any time.",
                      style: TextStyle(color: kTextColor),
                      textAlign: TextAlign.end,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );

    // Target 3: Detect Disease Button (Last Step -> Action)
    targets.add(
      TargetFocus(
        identify: "detectButton",
        keyTarget: _detectButtonKey,
        alignSkip: Alignment.topRight,
        shape: ShapeLightFocus.RRect,
        radius: 12, // Match button radius
        contents: [
          TargetContent(
            align: ContentAlign.bottom, // 🔹 Moved text BELOW the button
            builder: (context, controller) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const <Widget>[
                  Text(
                    "Start Detection",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: kTextColor, // 🔹 Dark Brown Text
                      fontSize: 20.0,
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.only(top: 10.0),
                    child: Text(
                      "Tap this button to start a new session.\nThis will take you to the scanning page.",
                      style: TextStyle(color: kTextColor),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );

    return targets;
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
    Key? key, // Add Key parameter
  }) {
    final color = isSelected
        ? const Color.fromARGB(255, 82, 42, 4)
        : Colors.grey;
    return Expanded(
      child: InkWell(
        key: key, // Assign the key to InkWell
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
              style: TextStyle(
                fontFamily: 'Poppins',
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
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
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
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  color: const Color.fromARGB(255, 160, 98, 45),
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      IconButton(
                        key: _helpButtonKey, // ✅ Key assigned
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
                    style: TextStyle(
                      fontFamily: 'Poppins',
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
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 20),
                              ElevatedButton(
                                key: _detectButtonKey, // ✅ Key assigned (Empty State)
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
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
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
                              key: _detectButtonKey, // ✅ Key assigned (Data State)
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
                                style: TextStyle(
                                  fontFamily: 'Poppins',
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
              key: _albumsTabKey, // ✅ Key assigned
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
