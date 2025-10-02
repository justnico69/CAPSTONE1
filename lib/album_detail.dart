// lib/album_detail.dart

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // for FilteringTextInputFormatter
import 'package:google_fonts/google_fonts.dart';
import 'package:installed_apps/app_info.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:path_provider/path_provider.dart';

// Removed: import 'config.dart'; // for DayFolder
// Removed: import 'day_detail.dart';
import 'row_detail.dart'; // NEW: Import RowDetailPage

// Define the dark brown color for reuse
const Color kDarkBrown = Color(0xFF522A04);
// Define a light background color for the Card/Container
const Color kLightBrownBackground = Color.fromARGB(255, 255, 251, 245);

// =================== AlbumDetail (rows / days) ===================
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
      _rows.sort((a, b) {
        // try to keep Day 1, Day 2 ordering if names follow "Day N"
        final aNum = _extractDayNumber(a);
        final bNum = _extractDayNumber(b);
        if (aNum != null && bNum != null) return aNum.compareTo(bNum);
        return a.compareTo(b);
      });
    });
  }

  int? _extractDayNumber(String name) {
    // Attempts to parse "Day N" and return N. Otherwise null.
    final lower = name.toLowerCase().trim();
    if (lower.startsWith('day')) {
      final rest = lower.replaceFirst('day', '').trim();
      final num = int.tryParse(rest);
      return num;
    }
    return null;
  }

  Future<void> _addDay() async {
    // Compute suggested next day number
    int nextNumber = 1;
    final numbers = _rows.map((r) => _extractDayNumber(r)).whereType<int>();
    if (numbers.isNotEmpty) {
      nextNumber = (numbers.reduce((a, b) => a > b ? a : b)) + 1;
    }

    final controller = TextEditingController(text: nextNumber.toString());

    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          // Text changed from "Day folder" to "Row folder" since you're using 'row' concept
          'Create Row folder',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: kDarkBrown,
          ),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            hintText: 'Enter row number (e.g. 1)',
            hintStyle: GoogleFonts.poppins(fontSize: 13),
          ),
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: Colors.grey[700]),
            ),
          ),
          TextButton(
            onPressed: () {
              final text = controller.text.trim();
              Navigator.pop(ctx, text.isEmpty ? null : text);
            },
            child: Text(
              'Create',
              style: GoogleFonts.poppins(color: kDarkBrown),
            ),
          ),
        ],
      ),
    );

    // If user cancelled, name==null -> do nothing
    if (name == null) return;

    // Parse number or fallback to nextNumber
    final num = int.tryParse(name) ?? nextNumber;
    // NOTE: Keeping the folder naming convention as 'Day N' for now, 
    // but the concept is now a "Row" or general sub-folder.
    final dayName = 'Day $num'; 

    // If day already exists, show snackbar
    if (_rows.contains(dayName)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$dayName already exists',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Create the directory and refresh list
    final albumDir = await _getAlbumDir();
    final rowDir = Directory('${albumDir.path}/$dayName');
    if (!await rowDir.exists()) {
      await rowDir.create(recursive: true);
    }
    await _loadRows();

    // Optionally open created day immediately:
    _openRow(dayName);

    // Notify success
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Created $dayName', style: GoogleFonts.poppins()),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _deleteRow(String rowName) async {
    final albumDir = await _getAlbumDir();
    final rowDir = Directory('${albumDir.path}/$rowName');
    if (await rowDir.exists()) {
      await rowDir.delete(recursive: true);
      await _loadRows();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Deleted $rowName', style: GoogleFonts.poppins()),
        ),
      );
    }
  }

  // UPDATED: Navigates directly to RowDetailPage
  void _openRow(String rowName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RowDetailPage( // Navigate to RowDetailPage
          albumName: widget.albumName,
          rowName: rowName, // Pass the folder name as the rowName
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
          style: GoogleFonts.poppins(
            color: kDarkBrown,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: kDarkBrown),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: kDarkBrown),
            onPressed: _addDay,
            tooltip: 'Add Row folder',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadRows,
        child: ListView.builder(
          padding: const EdgeInsets.only(top: 10),
          itemCount: _rows.length + 1,
          itemBuilder: (ctx, i) {
            if (i == 0) {
              return const SizedBox(height: 8.0);
            }
            final row = _rows[i - 1];
            return Card(
              color: const Color(0xFFFFFFFF),
              margin: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2.0,
              child: ListTile(
                leading: Icon(
                  Icons.calendar_today,
                  color: kDarkBrown.withOpacity(0.9),
                ),
                title: Text(
                  row,
                  style: GoogleFonts.poppins(
                    color: kDarkBrown,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  'Date: ${widget.date}',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: Color.fromARGB(255, 236, 185, 74),
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deleteRow(row),
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
                onTap: () => _openRow(row),
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: kDarkBrown,
        child: const Icon(Icons.add),
        onPressed: _addDay,
        tooltip: 'Add Row',
      ),
    );
  }
}