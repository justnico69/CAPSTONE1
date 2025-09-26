import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:installed_apps/app_info.dart';
import 'package:installed_apps/installed_apps.dart';

import 'detector_page.dart';
import 'history_page.dart';
import 'album_detail.dart';
import 'album_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String telloPackage = '';

  // ✅ Store albums here
  final List<Map<String, String>> _albums = [];

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
              height: screenHeight * 0.195,
              color: Colors.white,
              child: SafeArea(
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
                                        color: Color.fromARGB(255, 128, 68, 12),
                                      ),
                                    ),
                                    TextSpan(
                                      text: 'ato',
                                      style: TextStyle(
                                        color: Color.fromARGB(255, 236, 185, 74),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                "at your service!",
                                style: GoogleFonts.poppins(
                                  color: Color.fromARGB(255, 160, 98, 45),
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
                ),
              ),
            ),
          ),

          // CONTENT
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: screenWidth * 0.07,
                vertical: screenWidth * 0.08,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 📌 Section: Create Album
                  Text(
                    "Create Album",
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: const Color.fromARGB(255, 128, 68, 12),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 3,
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Center(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.push<Map<String, dynamic>>(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const NewAlbumPage(),
                              ),
                            ).then((result) {
                              if (result != null) {
                                final name = result['name'] as String;
                                final dateIso = result['date'] as String;
                                final dateOnly = dateIso.split('T')[0];

                                // ✅ Add album to list
                                setState(() {
                                  _albums.add({
                                    "name": name,
                                    "date": dateOnly,
                                  });
                                });

                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Album "$name" created for $dateOnly',
                                    ),
                                  ),
                                );
                              }
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF80440C),
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
                            "Add New Album",
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),

                  // 📌 Section: Albums
                  Text(
                    "Albums",
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: const Color.fromARGB(255, 128, 68, 12),
                    ),
                  ),
                  const SizedBox(height: 10),

                  _albums.isEmpty
                      ? const Text(
                          "No albums yet. Create one!",
                          style: TextStyle(color: Colors.grey),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _albums.length,
                          itemBuilder: (context, index) {
                            final album = _albums[index];
                            return Card(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ListTile(
                                leading: const Icon(Icons.photo_album,
                                    color: Color(0xFF80440C)),
                                title: Text(album["name"] ?? ""),
                                subtitle: Text("Date: ${album["date"]}"),
                                onTap: () {
                                  // ✅ Open Album Detail page
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => AlbumDetailPage(
                                        name: album["name"]!,
                                        date: album["date"]!,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        ),

                  const SizedBox(height: 30),

                  // 📌 Section: Scan Potato
                  Center(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const DetectorPage(),
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
                        "Scan Potato",
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),

      // NAVIGATION BAR + FAB
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton(
        onPressed: launchTello,
        backgroundColor: const Color(0xFF522A04),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(50),
        ),
        child: const Icon(
          Icons.document_scanner_outlined,
          size: 28,
          color: Colors.white,
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        color: Colors.white,
        elevation: 10.0,
        height: screenHeight * 0.1,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: <Widget>[
            _buildBottomNavItem(
              icon: Icons.home_filled,
              label: "Home",
              isSelected: true,
              screenWidth: screenWidth,
            ),
            SizedBox(width: screenWidth * 0.05),
            InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const HistoryPage()),
                );
              },
              child: _buildBottomNavItem(
                icon: Icons.history,
                label: "History",
                isSelected: false,
                screenWidth: screenWidth,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavItem({
    required IconData icon,
    required String label,
    required bool isSelected,
    required double screenWidth,
  }) {
    final color =
        isSelected ? const Color.fromARGB(255, 82, 42, 4) : Colors.grey;

    return Column(
      mainAxisSize: MainAxisSize.min,
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
    );
  }
}
