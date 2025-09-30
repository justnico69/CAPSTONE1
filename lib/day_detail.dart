// day_detail.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';

import 'config.dart';
import 'row_detail.dart';

const Color kDarkBrown = Color(0xFF522A04);

class DayDetailPage extends StatefulWidget {
  final String albumName;
  final DayFolder dayFolder;
  final String telloPackage;

  const DayDetailPage({
    Key? key,
    required this.albumName,
    required this.dayFolder,
    this.telloPackage = '',
  }) : super(key: key);

  @override
  State<DayDetailPage> createState() => _DayDetailPageState();
}

class _DayDetailPageState extends State<DayDetailPage> {
  List<String> _rows = [];

  @override
  void initState() {
    super.initState();
    _loadRows();
  }

  Future<Directory> _getDayDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final dayDir = Directory(
      "${dir.path}/SPOTATO/${widget.albumName}/${widget.dayFolder.title}",
    );
    if (!await dayDir.exists()) await dayDir.create(recursive: true);
    return dayDir;
  }

  Future<void> _loadRows() async {
    final dayDir = await _getDayDir();
    final subdirs = dayDir.listSync().whereType<Directory>();
    setState(() => _rows = subdirs.map((d) => d.path.split('/').last).toList());
  }

  Future<void> _addRow() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Add Row/Section',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: kDarkBrown,
          ),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'e.g. Row1 or Section A',
            hintStyle: GoogleFonts.poppins(),
          ),
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
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text('Add', style: GoogleFonts.poppins(color: kDarkBrown)),
          ),
        ],
      ),
    );

    if (name != null && name.isNotEmpty) {
      final dayDir = await _getDayDir();
      final rowDir = Directory('${dayDir.path}/$name');
      if (!await rowDir.exists()) await rowDir.create(recursive: true);
      await _loadRows();
    }
  }

  Future<void> _deleteRow(String rowName) async {
    final dayDir = await _getDayDir();
    final rowDir = Directory('${dayDir.path}/$rowName');
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
          dayFolder: widget.dayFolder,
          rowName: rowName,
          telloPackage: widget.telloPackage,
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
          widget.dayFolder.title,
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
            onPressed: _addRow,
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.only(top: 10),
        itemCount: _rows.length,
        itemBuilder: (ctx, i) {
          final row = _rows[i];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 2.0,
            child: ListTile(
              leading: Icon(
                Icons.view_list,
                color: kDarkBrown.withOpacity(0.8),
              ),
              title: Text(
                row,
                style: GoogleFonts.poppins(
                  color: kDarkBrown,
                  fontWeight: FontWeight.w600,
                ),
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
      floatingActionButton: FloatingActionButton(
        backgroundColor: kDarkBrown,
        child: const Icon(Icons.add),
        onPressed: _addRow,
      ),
    );
  }
}
