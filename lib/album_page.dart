import 'package:flutter/material.dart';

import 'album_detail.dart';
import 'database_helper.dart';

const Color kDarkBrown = Color.fromARGB(255, 128, 68, 12);
const Color kOrange = Color(0xFFEAA944);

class AlbumsPage extends StatefulWidget {
  const AlbumsPage({Key? key}) : super(key: key);

  @override
  State<AlbumsPage> createState() => _AlbumsPageState();
}

class _AlbumsPageState extends State<AlbumsPage> {
  late Future<List<Map<String, dynamic>>> _albumsFuture;
  Set<String> _selectedAlbums = {};
  bool _selectionMode = false;

  // 🔹 Filter State
  DateTime? _startDate;
  DateTime? _endDate;
  String _filterStatus = 'All'; // 'All', 'Has Disease', 'Healthy'

  @override
  void initState() {
    super.initState();
    _loadAlbums();
  }

  void _loadAlbums() {
    setState(() {
      _albumsFuture = DatabaseHelper.instance.getAllAlbums(
        startDate: _startDate,
        endDate: _endDate,
        filterType: _filterStatus,
      );
    });
  }

  // 🔹 Filter UI Logic
  void _showFilterDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        // Temp state for the dialog
        DateTime? tempStart = _startDate;
        DateTime? tempEnd = _endDate;
        String tempFilter = _filterStatus;

        return StatefulBuilder(
          builder: (context, setModalState) {
            final dateText = (tempStart == null || tempEnd == null)
                ? "Select Date Range"
                : "${tempStart!.month}/${tempStart!.day} - ${tempEnd!.month}/${tempEnd!.day}";

            return Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                   const Text(
                    "Filter Albums",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: kDarkBrown,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),

                  // 1. Date Picker
                  ElevatedButton.icon(
                    onPressed: () async {
                      final picked = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(2023),
                        lastDate: DateTime.now(),
                        initialDateRange: (tempStart != null && tempEnd != null)
                            ? DateTimeRange(start: tempStart!, end: tempEnd!)
                            : null,
                        builder: (context, child) {
                          return Theme(
                            data: ThemeData.light().copyWith(
                              primaryColor: kDarkBrown,
                              colorScheme: const ColorScheme.light(
                                primary: kDarkBrown,
                                onPrimary: Colors.white,
                                onSurface: kDarkBrown,
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (picked != null) {
                        setModalState(() {
                          tempStart = picked.start;
                          tempEnd = picked.end;
                        });
                      }
                    },
                    icon: const Icon(Icons.calendar_today),
                    label: Text(dateText),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: kDarkBrown,
                      side: const BorderSide(color: kDarkBrown),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 2. Health Status
                  const Text("Contents:",
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    children: [
                      _buildFilterChip('All', tempFilter, (val) {
                        setModalState(() => tempFilter = val);
                      }),
                      _buildFilterChip('Has Disease', tempFilter, (val) {
                        setModalState(() => tempFilter = val);
                      }),
                      _buildFilterChip('Healthy', tempFilter, (val) {
                        setModalState(() => tempFilter = val);
                      }),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // 3. Actions
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () {
                            // Reset
                            setState(() {
                              _startDate = null;
                              _endDate = null;
                              _filterStatus = 'All';
                              _loadAlbums();
                            });
                            Navigator.pop(context);
                          },
                          child: const Text("Reset",
                              style: TextStyle(color: Colors.grey)),
                        ),
                      ),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            // Apply
                            setState(() {
                              _startDate = tempStart;
                              _endDate = tempEnd;
                              _filterStatus = tempFilter;
                              _loadAlbums();
                            });
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                              backgroundColor: kOrange),
                          child: const Text("Apply Filters"),
                        ),
                      ),
                    ],
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFilterChip(
      String label, String currentSelection, Function(String) onSelect) {
    final isSelected = label == currentSelection;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: kOrange,
      labelStyle: TextStyle(
          color: isSelected ? Colors.white : Colors.black,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
      onSelected: (_) => onSelect(label),
    );
  }

  Future<void> _deleteSelected(List<String> albumNames) async {
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

    for (var albumName in _selectedAlbums) {
      await DatabaseHelper.instance.deleteAlbum(albumName);
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Deleted ${_selectedAlbums.length} album(s)')),
    );

    setState(() {
      _selectionMode = false;
      _selectedAlbums.clear();
      _loadAlbums(); // Refresh the list
    });
  }

  String _formatDate(String isoDate) {
    final date = DateTime.parse(isoDate);
    return "${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}/${date.year}";
  }

  void _toggleSelection(String albumName) {
    setState(() {
      if (_selectedAlbums.contains(albumName)) {
        _selectedAlbums.remove(albumName);
      } else {
        _selectedAlbums.add(albumName);
      }
    });
  }

  void _exitSelection() {
    setState(() {
      _selectionMode = false;
      _selectedAlbums.clear();
    });
  }

  void _selectAll(List<String> allAlbumNames) {
    setState(() {
      _selectedAlbums = allAlbumNames.toSet();
    });
  }

  // 🔹 --- THIS IS THE CORRECTED BUILD METHOD --- 🔹
  @override
  Widget build(BuildContext context) {
    // 1. The FutureBuilder is the ROOT widget.
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _albumsFuture,
      builder: (context, snapshot) {
        // 2. Get the data from the snapshot.
        final allAlbums = snapshot.data ?? [];
        final allAlbumNames = allAlbums
            .map((a) => a['albumName'] as String)
            .toList();

        final bool isFilterActive = _filterStatus != 'All' || _startDate != null;

        // 3. NOW we build the Scaffold, so the AppBar can use the data.
        return Scaffold(
          // 4. This is the SINGLE background color.
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
              style: TextStyle(
                fontFamily: 'Poppins',
                color: kDarkBrown,
                fontWeight: FontWeight.bold,
              ),
            ),
            // 5. The actions are now built correctly with the data.
            actions: [
              if (!_selectionMode)
                Stack(
                  alignment: Alignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.tune, color: kDarkBrown), // Fader/Filter icon
                      onPressed: _showFilterDialog,
                      tooltip: "Filter Albums",
                    ),
                    if (isFilterActive)
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
              if (_selectionMode && allAlbums.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.select_all, color: kDarkBrown),
                  tooltip: "Select All",
                  onPressed: () => _selectAll(allAlbumNames),
                ),
              if (_selectionMode && _selectedAlbums.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  tooltip: "Delete Selected",
                  onPressed: () => _deleteSelected(allAlbumNames),
                ),
            ],
          ),

          // 6. The body is built using the snapshot state.
          body: () {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: kOrange),
              );
            }

            if (snapshot.hasError) {
              return const Center(child: Text("Error loading albums."));
            }

            if (allAlbums.isEmpty) {
              if (isFilterActive) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                       Icon(Icons.filter_list_off, size: 60, color: Colors.grey[400]),
                       const SizedBox(height: 10),
                       Text(
                        "No albums match your filter.",
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          color: Colors.grey[600],
                          fontSize: 16,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _startDate = null;
                            _endDate = null;
                            _filterStatus = 'All';
                            _loadAlbums();
                          });
                        },
                        child: const Text("Clear Filters", style: TextStyle(color: kOrange)),
                      )
                    ],
                  ),
                );
              }

              return Center(
                child: Text(
                  "No saved albums. Go take some photos!",
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    color: Colors.grey[600],
                    fontSize: 16,
                  ),
                ),
              );
            }

            // 7. This is the main content (the list)
            return ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: allAlbums.length,
              itemBuilder: (context, index) {
                final album = allAlbums[index];
                final albumName = album['albumName'] as String;
                final imageCount = album['imageCount'] as int;
                final latestDate = album['latestImageTime'] as String;
                final isSelected = _selectedAlbums.contains(albumName);

                final rowTag = album[DatabaseHelper.columnRowTag] as String?;

                final String subtitleText = [
                  if (rowTag != null && rowTag.isNotEmpty) rowTag,
                  "$imageCount image(s)",
                  "Last added: ${_formatDate(latestDate)}",
                ].join(" • ");

                return GestureDetector(
                  onLongPress: () {
                    setState(() {
                      _selectionMode = true;
                      _selectedAlbums.add(albumName);
                    });
                  },
                  onTap: () {
                    if (_selectionMode) {
                      _toggleSelection(albumName);
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              AlbumDetail(albumName: albumName),
                        ),
                      ).then(
                        (_) => _loadAlbums(),
                      ); // Refresh list when returning
                    }
                  },
                  child: Card(
                    elevation: 4,
                    color: isSelected
                        ? Colors.grey[300] // Using the grey highlight
                        : Colors.white,
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
                        albumName
                            .replaceFirst("Scan_", "")
                            .replaceAll("_", " "),
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.bold,
                          color: kDarkBrown,
                        ),
                      ),
                      subtitle: Text(
                        subtitleText,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 13,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      trailing: _selectionMode
                          ? Checkbox(
                              value: isSelected,
                              onChanged: (_) => _toggleSelection(albumName),
                              activeColor: kOrange,
                            )
                          : const Icon(Icons.arrow_forward_ios, size: 18),
                    ),
                  ),
                );
              },
            );
          }(),
        );
      },
    );
  }
}
