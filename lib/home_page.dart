import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:installed_apps/app_info.dart';
import 'package:installed_apps/installed_apps.dart';

import 'album_page.dart';
// Import the new page
import 'row_detail.dart';

// Assuming DayFolder is now defined/removed as needed for other files.
// Placeholder for DayFolder is REMOVED from this file.

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String telloPackage = '';

  @override
  void initState() {
    super.initState();
    checkInstalledApps();
  }

  /// Check if Tello app is installed
  Future<void> checkInstalledApps() async {
    List<AppInfo> apps = await InstalledApps.getInstalledApps(true, true);

    bool found = false;
    for (var app in apps) {
      if (app.packageName == "com.ryzerobotics.tello") {
        debugPrint("✅ Found Tello: ${app.name} -> ${app.packageName}");
        telloPackage = app.packageName;
        found = true;
        break;
      }
    }

    if (!found) {
      debugPrint("❌ Tello app not found on this device.");
    }
  }

  /// Launch Tello if found
  Future<void> launchTello() async {
    if (telloPackage.isNotEmpty) {
      await InstalledApps.startApp(telloPackage);
    } else {
      debugPrint("Tello package not found. Cannot launch.");
    }
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
      // Wrap with Expanded for equal spacing
      child: InkWell(
        // Use InkWell to make the whole area tapable
        onTap: () {
          // Add navigation logic here if you had other pages
          if (label == "Home") {
            // Do nothing, already on Home
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
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Image.asset(
                                'assets/images/spotato_logo.png',
                                height: screenHeight * 0.05,
                              ),
                              const SizedBox(width: 10),
                              Column(
                                mainAxisSize: MainAxisSize.min,
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
                              Icons.notifications,
                              color: Color.fromARGB(255, 128, 68, 12),
                              size: 28,
                            ),
                            onPressed: () {},
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // The main content area
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
                  AspectRatio(
                    aspectRatio: 4 / 3,
                    child: Container(
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
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16.0,
                            ),
                            child: Text(
                              "No images yet. Tap Button to scan.",
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                color: Colors.grey[600],
                              ),
                            ),
                          ),
                          const SizedBox(height: 50),
                          ElevatedButton(
                            onPressed: () {
                              // FIX: Passing the two required arguments, 'dayFolder' removed.
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
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 30),
        ],
      ),
      // --- NAVIGATION BAR ---
      floatingActionButton: null, // Removed FAB
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        color: Colors.white,
        elevation: 10.0,
        height: screenHeight * 0.09,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: <Widget>[
            // Item 1: Home
            _buildBottomNavItem(
              icon: Icons.home_filled,
              label: "Home",
              isSelected: true,
              screenWidth: screenWidth,
            ),
            // Item 2: Albums (Now navigates placeholder since albums aren't managed here)
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
