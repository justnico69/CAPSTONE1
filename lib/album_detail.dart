// album_detail.dart

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:installed_apps/app_info.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:path_provider/path_provider.dart';
import 'package:google_fonts/google_fonts.dart'; 

import 'row_detail.dart'; 

// Define the dark brown color for reuse
const Color kDarkBrown = Color(0xFF522A04);
// Define a light background color for the Card/Container
const Color kLightBrownBackground = Color.fromARGB(255, 255, 251, 245); 

// =================== AlbumDetail (rows) ===================
class AlbumDetail extends StatefulWidget {
  final String albumName;
  final String date;
  final String telloPackage;

  const AlbumDetail({
    Key? key,
    required this.albumName,
    required this.date,
    this.telloPackage = '',
  }) : super(key: key);

  @override
  _AlbumDetailState createState() => _AlbumDetailState();
}

class _AlbumDetailState extends State<AlbumDetail> {
  List<String> _rows = [];
  String _telloPackage = '';

  @override
  void initState() {
    super.initState();
    _telloPackage = widget.telloPackage;
    _loadRows();
    if (_telloPackage.isEmpty) _checkTelloApp();
  }

  Future<void> _checkTelloApp() async {
    try {
      List<AppInfo> apps = await InstalledApps.getInstalledApps(true, true);
      for (var app in apps) {
        if (app.packageName == "com.ryzerobotics.tello") {
          setState(() => _telloPackage = app.packageName);
          break;
        }
      }
    } catch (_) {}
  }

  Future<Directory> _getAlbumDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final albumDir = Directory("${dir.path}/SPOTATO/${widget.albumName}");
    if (!await albumDir.exists()) await albumDir.create(recursive: true);
    return albumDir;
  }

  Future<void> _loadRows() async {
    final albumDir = await _getAlbumDir();
    final subdirs = albumDir.listSync().whereType<Directory>();
    setState(() {
      _rows = subdirs.map((d) => d.path.split('/').last).toList();
    });
  }

  Future<void> _addRow() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Add Row/Column',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: kDarkBrown),
        ),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: 'e.g. ROW1',
            hintStyle: GoogleFonts.poppins(),
          ),
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.grey[700])),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text('Add', style: GoogleFonts.poppins(color: kDarkBrown)),
          ),
        ],
      ),
    );

    if (name != null && name.isNotEmpty) {
      final albumDir = await _getAlbumDir();
      final rowDir = Directory('${albumDir.path}/$name');
      if (!await rowDir.exists()) await rowDir.create();
      await _loadRows();
    }
  }

  Future<void> _deleteRow(String rowName) async {
    final albumDir = await _getAlbumDir();
    final rowDir = Directory('${albumDir.path}/$rowName');
    if (await rowDir.exists()) {
      await rowDir.delete(recursive: true);
      await _loadRows();
    }
  }

  void _openRow(String rowName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RowDetailPage(
          albumName: widget.albumName,
          rowName: rowName,
          telloPackage: _telloPackage,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(243, 248, 248, 248),
      appBar: AppBar(
        title: Text(
          widget.albumName,
          style: GoogleFonts.poppins(color: kDarkBrown, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white, 
        iconTheme: const IconThemeData(color: kDarkBrown), 
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: kDarkBrown), 
            onPressed: _addRow,
          ),
        ],
      ),
      body: ListView.builder(
        // Re-add '+ 1' to the item count to make space for the SizedBox
        itemCount: _rows.length + 1, 
        itemBuilder: (ctx, i) {
          // If this is the first index, return the SizedBox for spacing
          if (i == 0) {
            return const SizedBox(height: 10.0); // Adjust height for desired space
          }

          // For all subsequent items, fetch the row data using the adjusted index
          final row = _rows[i - 1]; 
          
          return Card( 
            color: const Color(0xFFFFFFFF), 
            // Margin is kept for spacing between cards
            margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 2.0, // Slight shadow
            child: ListTile(
              // Add a leading icon for visual appeal
              leading: Icon(
                Icons.local_florist,
                color: kDarkBrown.withOpacity(0.8),
              ),
              title: Text(
                row,
                style: GoogleFonts.poppins(color: kDarkBrown, fontWeight: FontWeight.w600),
              ),
              // Subtitle for the list item
              subtitle: Text(
                'Date: ${widget.date}', // Display the album's date
                style: GoogleFonts.poppins(fontSize: 11, color: Color.fromARGB(255, 236, 185, 74)),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () => _deleteRow(row),
              ),
              onTap: () => _openRow(row),
            ),
          );
        },
      ),
    );
  }
}