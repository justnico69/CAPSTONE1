import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:installed_apps/app_info.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'album_detail.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String telloPackage = '';

  // "name" and "date" keys.
  final List<Map<String, String>> _albums = [];

  // Selection mode variables
  Set<int> _selectedAlbums = {};
  bool _selectionMode = false;

  @override
  void initState() {
    super.initState();
    checkInstalledApps();
    _loadAlbums();
  }

  /// Load albums
  Future<void> _loadAlbums() async {
    final prefs = await SharedPreferences.getInstance();
    final String? albumsString = prefs.getString('albums');
    if (albumsString != null) {
      final List<dynamic> jsonList = jsonDecode(albumsString);
      setState(() {
        _albums.addAll(jsonList.map((item) => Map<String, String>.from(item)));
      });
      debugPrint("✅ Loaded ${_albums.length} albums.");
    }
  }

  /// Save current album list to SharedPreferences
  Future<void> _saveAlbums() async {
    final prefs = await SharedPreferences.getInstance();
    // Convert List<Map<String, String>> to a JSON string
    final String albumsString = jsonEncode(_albums);
    await prefs.setString('albums', albumsString);
    debugPrint("✅ Saved ${_albums.length} albums.");
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

  /// Toggle album selection
  void _toggleSelection(int index) {
    setState(() {
      if (_selectedAlbums.contains(index)) {
        _selectedAlbums.remove(index);
        if (_selectedAlbums.isEmpty) {
          _selectionMode = false;
        }
      } else {
        _selectedAlbums.add(index);
        _selectionMode = true;
      }
    });
  }

  /// Delete selected albums
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
      // Get the indices and sort them descending so removal doesn't shift the list
      final sortedIndices = _selectedAlbums.toList()..sort((a, b) => b.compareTo(a));

      // Remove items from the original list by index
      for (final index in sortedIndices) {
        _albums.removeAt(index);
      }

      _selectedAlbums.clear();
      _selectionMode = false;
    });

    _saveAlbums(); // Save after deletion

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

  /// Album creation via Dialog
  Future<void> _showCreateAlbumDialog() async {
    final albumNameController = TextEditingController();

    // The result map now expects 'name' and 'date'
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (BuildContext dialogContext) {
        String? albumNameError;

        return StatefulBuilder(
          builder: (context, setStateInDialog) {
            void saveAlbum() {
              setStateInDialog(() {
                albumNameError = null; // Reset error
              });

              final name = albumNameController.text.trim();

              // 1. Validation
              if (name.isEmpty) {
                setStateInDialog(() {
                  albumNameError = "Please enter an album name (e.g., Month Year)";
                });
                return;
              }

              final now = DateTime.now();
              // Format: DD/MM/YYYY 
              final dateCreated =
                  "${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}";

              Navigator.pop(dialogContext, {
                'name': name,
                'date': dateCreated,
              });
            }

            return AlertDialog(
              title: Text(
                'Create Album',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Enter the name of your new album:',
                    style: GoogleFonts.poppins(fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: albumNameController,
                    autofocus: true,
                    style: GoogleFonts.poppins(),
                    onChanged: (value) {
                      if (value.trim().isNotEmpty && albumNameError != null) {
                        setStateInDialog(() {
                          albumNameError = null;
                        });
                      }
                    },
                    onSubmitted: (_) => saveAlbum(),
                    decoration: InputDecoration(
                      labelText: '(e.g., Month & Year)',
                      labelStyle: GoogleFonts.poppins(),
                      border: const OutlineInputBorder(),
                      isDense: true,
                      errorText: albumNameError,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext), 
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.poppins(color: Colors.grey[700]),
                  ),
                ),
                ElevatedButton(
                  onPressed: saveAlbum,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF522A04),
                  ),
                  child: Text(
                    'Create',
                    style: GoogleFonts.poppins(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    // Handle the result from the dialog
    if (result != null) {
      final name = result['name']!;
      final date = result['date']!; // GRAB THE NEW DATE

      // Add album with both "name" and "date" keys
      setState(() {
        _albums.add({"name": name, "date": date}); 
      });

      _saveAlbums();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Album "$name" created.')),
      );
    }
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
                                      color: const Color.fromARGB(
                                          255, 160, 98, 45),
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
                      onPressed: _showCreateAlbumDialog,
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete,
                          color: Color.fromARGB(255, 255, 0, 0)),
                      tooltip: "Delete Selected",
                      onPressed: _deleteSelectedAlbums,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Album list
          _albums.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
                    child: Text.rich(
                      textAlign: TextAlign.center,
                      TextSpan(
                        style: GoogleFonts.poppins(fontSize: 14),
                        children: const <TextSpan>[
                          TextSpan(
                            text: "No albums yet.\n",
                            style: TextStyle(color: Colors.grey),
                          ),
                          TextSpan(
                            text: "Click the + to Create one!\n",
                            style: TextStyle(color: Colors.grey),
                          ),
                          TextSpan(
                            text: "Long press to delete an album.",
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              : Expanded(
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    physics: const AlwaysScrollableScrollPhysics(), 
                    itemCount: _albums.length, 
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
                            : const Color(0xFFFFFFFF),
                        child: ListTile(
                          leading: Icon(
                            isSelected
                                ? Icons.check_circle
                                : Icons.photo_album,
                            color: const Color(0xFF80440C),
                          ),
                          // ALBUM TITLE (Name)
                          title: Text(
                            album["name"] ?? "",
                            style: GoogleFonts.poppins(
                              color: const Color(0xFF80440C), 
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          // ALBUM SUBTITLE (Date Created)
                          subtitle: Text(
                            album["date"] != null
                                ? "Date Created: ${album["date"]!}"
                                : "Date Created: N/A", // Fallback for old albums
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: Color.fromARGB(255, 236, 185, 74),
                            ),
                          ),
                          onTap: () {
                            if (_selectionMode) {
                              _toggleSelection(index);
                            } else {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => AlbumDetail(
                                    albumName: album["name"]!,
                                    // Pass the date, or an empty string if not found
                                    date: album["date"] ?? '', 
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