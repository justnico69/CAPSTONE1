import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';

import 'album_detail.dart';

const Color kDarkBrown = Color.fromARGB(255, 128, 68, 12);
const Color kOrange = Color(0xFFEAA944);

class AlbumsPage extends StatefulWidget {
  const AlbumsPage({Key? key}) : super(key: key);

  @override
  State<AlbumsPage> createState() => _AlbumsPageState();
}

class _AlbumsPageState extends State<AlbumsPage> {
  List<Directory> _albums = [];
  Set<String> _selectedAlbums = {}; // ✅ holds selected folders
  bool _selectionMode = false; // ✅ whether selection is active

  @override
  void initState() {
    super.initState();
    _loadAlbums();
  }

  /// ✅ Load all saved folders (albums)
  Future<void> _loadAlbums() async {
    final dir = await getApplicationDocumentsDirectory();
    final basePath = Directory('${dir.path}/SPOTATO/New Detections');

    if (!await basePath.exists()) {
      await basePath.create(recursive: true);
    }

    final allFolders = basePath.listSync().whereType<Directory>().toList()
      ..sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));

    setState(() {
      _albums = allFolders;
    });
  }

  /// ✅ Delete selected albums
  Future<void> _deleteSelected() async {
    if (_selectedAlbums.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Albums'),
        content: Text(
          'Are you sure you want to delete ${_selectedAlbums.length} album(s)? This action cannot be undone.',
          style: const TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    for (var path in _selectedAlbums) {
      final dir = Directory(path);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    }

    setState(() {
      _selectionMode = false;
      _selectedAlbums.clear();
    });

    await _loadAlbums();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('🗑 Deleted ${_selectedAlbums.length} album(s)')),
    );
  }

  String _formatFolderName(String folderName) {
    if (folderName.startsWith("Scan_")) {
      return folderName.replaceFirst("Scan_", "").replaceAll("_", " ");
    }
    return folderName;
  }

  String _formatDate(DateTime date) {
    return "${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}/${date.year}";
  }

  void _toggleSelection(String path) {
    setState(() {
      if (_selectedAlbums.contains(path)) {
        _selectedAlbums.remove(path);
      } else {
        _selectedAlbums.add(path);
      }
    });
  }

  void _exitSelection() {
    setState(() {
      _selectionMode = false;
      _selectedAlbums.clear();
    });
  }

  void _selectAll() {
    setState(() {
      _selectedAlbums = _albums.map((a) => a.path).toSet();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(243, 248, 248, 248),
      appBar: AppBar(
        backgroundColor: Colors.white,
        leading: _selectionMode
            ? IconButton(
                icon: const Icon(Icons.close, color: kDarkBrown),
                onPressed: _exitSelection,
              )
            : null,
        title: Text(
          _selectionMode
              ? "${_selectedAlbums.length} selected"
              : "Saved Albums",
          style: GoogleFonts.poppins(
            color: kDarkBrown,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          if (_selectionMode && _albums.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.select_all, color: kDarkBrown),
              tooltip: "Select All",
              onPressed: _selectAll,
            ),
          if (_selectionMode && _selectedAlbums.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              tooltip: "Delete Selected",
              onPressed: _deleteSelected,
            ),
        ],
      ),
      body: _albums.isEmpty
          ? Center(
              child: Text(
                "No saved albums yet.",
                style: GoogleFonts.poppins(
                  color: Colors.grey[600],
                  fontSize: 16,
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: _albums.length,
              itemBuilder: (context, index) {
                final album = _albums[index];
                final folderName = album.path.split('/').last;
                final formatted = _formatFolderName(folderName);
                final modified = album.statSync().modified;
                final isSelected = _selectedAlbums.contains(album.path);

                return GestureDetector(
                  onLongPress: () {
                    setState(() {
                      _selectionMode = true;
                      _selectedAlbums.add(album.path);
                    });
                  },
                  onTap: () {
                    if (_selectionMode) {
                      _toggleSelection(album.path);
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AlbumDetail(
                            albumName: folderName,
                            date: _formatDate(modified),
                          ),
                        ),
                      );
                    }
                  },
                  child: Card(
                    elevation: 4,
                    color: isSelected ? const Color(0xFFFFF3E0) : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: Stack(
                        alignment: Alignment.center,
                        children: [
                          const Icon(Icons.folder, color: kOrange, size: 40),
                          if (isSelected)
                            const Positioned(
                              right: 0,
                              top: 0,
                              child: Icon(
                                Icons.check_circle,
                                color: Colors.green,
                                size: 20,
                              ),
                            ),
                        ],
                      ),
                      title: Text(
                        formatted,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          color: kDarkBrown,
                        ),
                      ),
                      subtitle: Text(
                        "Created: ${_formatDate(modified)}",
                        style: GoogleFonts.poppins(fontSize: 13),
                      ),
                      trailing: _selectionMode
                          ? Checkbox(
                              value: isSelected,
                              onChanged: (_) => _toggleSelection(album.path),
                              activeColor: kOrange,
                            )
                          : const Icon(Icons.arrow_forward_ios, size: 18),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
