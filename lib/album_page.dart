import 'package:flutter/material.dart';

class NewAlbumPage extends StatefulWidget {
  const NewAlbumPage({super.key});

  @override
  State<NewAlbumPage> createState() => _NewAlbumPageState();
}

class _NewAlbumPageState extends State<NewAlbumPage> {
  final TextEditingController albumNameController = TextEditingController();
  DateTime? selectedDate;

  @override
  void dispose() {
    albumNameController.dispose();
    super.dispose();
  }

  Future<void> _pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() => selectedDate = picked);
    }
  }

  String _formatDate(DateTime d) {
    final y = d.year.toString();
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  void _saveAndReturn() {
    if (selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please pick a date')),
      );
      return;
    }

    final name = albumNameController.text.trim().isEmpty
        ? 'Untitled Album'
        : albumNameController.text.trim();

    // Return a Map with the album info to the caller
    Navigator.pop(context, {
      'name': name,
      'date': selectedDate!.toIso8601String(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Album'),
        backgroundColor: const Color(0xFF522A04),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: albumNameController,
              decoration: const InputDecoration(
                labelText: 'Album name (optional)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _pickDate(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEAA944),
                    ),
                    child: Text(
                      selectedDate == null
                          ? 'Pick Date'
                          : 'Date: ${_formatDate(selectedDate!)}',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saveAndReturn,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF522A04),
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 14,
                ),
              ),
              child: const Text('Save Album'),
            ),
          ],
        ),
      ),
    );
  }
}
