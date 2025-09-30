// day_screen.dart
import 'package:flutter/material.dart';

import 'config.dart';
import 'row_detail.dart';

class DayScreen extends StatefulWidget {
  final Album album;
  const DayScreen({Key? key, required this.album}) : super(key: key);

  @override
  State<DayScreen> createState() => _DayScreenState();
}

class _DayScreenState extends State<DayScreen> {
  void _addDay() {
    final nextDayNumber = widget.album.days.length + 1;
    setState(() {
      widget.album.days.add(DayFolder(title: "Day $nextDayNumber"));
    });
  }

  void _renameDay(int index) async {
    final current = widget.album.days[index].title;
    final controller = TextEditingController(text: current);
    final result = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename day'),
        content: TextField(controller: controller),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (result != null && result.trim().isNotEmpty) {
      setState(() {
        widget.album.days[index].title = result.trim();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.album.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: widget.album.days.isEmpty
          ? const Center(
              child: Text("No days yet. Tap + to add your first day."),
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: widget.album.days.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final day = widget.album.days[index];
                return ListTile(
                  title: Text(day.title),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, size: 20),
                        onPressed: () => _renameDay(index),
                      ),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RowDetailPage(
                          dayFolder: day,
                          albumName: widget.album.name,
                          rowName: day
                              .title, // Provide the required rowName argument
                        ),
                      ),
                    );
                  },
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addDay,
        child: const Icon(Icons.add),
      ),
    );
  }
}
