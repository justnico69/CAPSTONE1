// album_detail.dart

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:installed_apps/app_info.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:path_provider/path_provider.dart';

// TODO: Replace the import path below with the actual location of RowDetailPage
import 'row_detail.dart';

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
        title: const Text('Add Row/Column'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'e.g. ROW1'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Add'),
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
      appBar: AppBar(
        title: Text(widget.albumName),
        actions: [IconButton(icon: const Icon(Icons.add), onPressed: _addRow)],
      ),
      body: ListView.builder(
        itemCount: _rows.length,
        itemBuilder: (ctx, i) {
          final row = _rows[i];
          return ListTile(
            title: Text(row),
            trailing: IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _deleteRow(row),
            ),
            onTap: () => _openRow(row),
          );
        },
      ),
    );
  }
}
