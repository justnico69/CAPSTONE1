import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:installed_apps/app_info.dart';
import 'package:installed_apps/installed_apps.dart';

import 'album_detail.dart';
import 'album_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String telloPackage = '';

  // ✅ Store albums here (no dummy albums)
  final List<Map<String, String>> _albums = [];

  // ✅ Selection mode variables
  Set<int> _selectedAlbums = {};
  bool _selectionMode = false;

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

  /// ✅ Toggle album selection
  void _toggleSelection(int index) {
    setState(() {
      if (_selectedAlbums.contains(index)) {
        _selectedAlbums.remove(index);
        if (_selectedAlbums.isEmpty) {
          _selectionMode = false; // exit if nothing is selected
        }
      } else {
        _selectedAlbums.add(index);
        _selectionMode = true;
      }
    });
  }

  /// ✅ Delete selected albums (with empty check)
  void _deleteSelectedAlbums() {
    if (_selectedAlbums.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "No albums selected to delete",
            style: GoogleFonts.poppins(fontSize: 12),
          ),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.only(bottom: 10, left: 20, right: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          backgroundColor: Colors.grey[700],
          duration: const Duration(seconds: 2),
        ),
      );
      return; // stop if nothing selected
    }

    setState(() {
      _albums.removeWhere(
        (album) => _selectedAlbums.contains(_albums.indexOf(album)),
      );
      _selectedAlbums.clear();
      _selectionMode = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          "Deleted selected albums",
          style: GoogleFonts.poppins(fontSize: 12),
        ),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(bottom: 10, left: 20, right: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: const Color(0xFF80440C),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// ✅ Add new album
  void _addNewAlbum() {
    Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (context) => const NewAlbumPage()),
    ).then((result) {
      if (result != null) {
        final name = result['name'] as String;
        final dateIso = result['date'] as String;
        final dateOnly = dateIso.split('T')[0];

        // Add album to list
        setState(() {
          _albums.add({"name": name, "date": dateOnly});
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Album "$name" created for $dateOnly')),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

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
                    ],
                  ),
                ),
              ),
            ),
          ),

          // CONTENT
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "Recent Albums",
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: const Color.fromARGB(255, 128, 68, 12),
                      ),
                    ),
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.add,
                        color: Color.fromARGB(255, 128, 68, 12),
                      ),
                      tooltip: "Add Album",
                      onPressed: _addNewAlbum,
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      tooltip: "Delete Selected",
                      onPressed: _deleteSelectedAlbums,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // small space between text & cards
          const SizedBox(height: 8),

          // ✅ Album list (fixed padding issue)
          _albums.isEmpty
              ? const Text(
                  "No albums yet. Create one!",
                  style: TextStyle(color: Colors.grey),
                )
              : Expanded(
                  child: ListView.builder(
                    padding: EdgeInsets.zero, // 👈 removes hidden top padding
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _albums.length > 5 ? 5 : _albums.length,
                    itemBuilder: (context, index) {
                      final album = _albums[index];
                      final isSelected = _selectedAlbums.contains(index);

                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 6,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        color: isSelected
                            ? Colors.brown.withOpacity(0.2)
                            : null,
                        child: ListTile(
                          leading: Icon(
                            isSelected ? Icons.check_circle : Icons.photo_album,
                            color: const Color(0xFF80440C),
                          ),
                          title: Text(album["name"] ?? ""),
                          subtitle: Text("Date: ${album["date"]}"),
                          onTap: () {
                            if (_selectionMode) {
                              _toggleSelection(index);
                            } else {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => AlbumDetail(
                                    albumName: album["name"]!,
                                    date: album["date"]!,
                                  ),
                                ),
                              );
                            }
                          },
                          onLongPress: () => _toggleSelection(index),
                        ),
                      );
                    },
                  ),
                ),

          const SizedBox(height: 30),
        ],
      ),
    );
  }
}
