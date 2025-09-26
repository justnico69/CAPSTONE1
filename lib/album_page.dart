import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class NewAlbumPage extends StatefulWidget {
  const NewAlbumPage({super.key});

  @override
  State<NewAlbumPage> createState() => _NewAlbumPageState();
}

class _NewAlbumPageState extends State<NewAlbumPage> {
  final TextEditingController albumNameController = TextEditingController();
  final TextEditingController dateController = TextEditingController();
  DateTime? selectedDate;

  String? albumNameError; // 👈 for validation

  @override
  void dispose() {
    albumNameController.dispose();
    dateController.dispose();
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
      setState(() {
        selectedDate = picked;
        dateController.text = _formatDate(picked); // Show chosen date
      });
    }
  }

  String _formatDate(DateTime d) {
    final y = d.year.toString();
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  void _saveAndReturn() {
    setState(() {
      albumNameError = null; // reset error
    });

    // ✅ Album name validation
    if (albumNameController.text.trim().isEmpty) {
      setState(() {
        albumNameError = "Please enter an album name";
      });
      return;
    }

    // ✅ Date validation
    if (selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please enter the date',
            style: GoogleFonts.poppins(),
          ),
        ),
      );
      return;
    }

    final name = albumNameController.text.trim();

    Navigator.pop(context, {
      'name': name,
      'date': selectedDate!.toIso8601String(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Create Album',
          style: GoogleFonts.poppins(
            color: const Color.fromARGB(255, 128, 68, 12),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color.fromARGB(255, 236, 185, 74),
        iconTheme: const IconThemeData(
          color: Color.fromARGB(255, 128, 68, 12),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: albumNameController,
              style: GoogleFonts.poppins(),
              onChanged: (value) {
                if (value.trim().isNotEmpty && albumNameError != null) {
                  setState(() {
                    albumNameError = null; // 👈 Clear error while typing
                  });
                }
              },
              decoration: InputDecoration(
                labelText: 'Album name (e.g Column 1)',
                labelStyle: GoogleFonts.poppins(),
                border: const OutlineInputBorder(),
                isDense: true,
                errorText: albumNameError, // 👈 show error message
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: dateController,
              readOnly: true, // Prevent typing
              style: GoogleFonts.poppins(),
              decoration: InputDecoration(
                labelText: 'Album date',
                labelStyle: GoogleFonts.poppins(),
                border: const OutlineInputBorder(),
                isDense: true,
                suffixIcon: IconButton(
                  icon: const Icon(Icons.calendar_today),
                  onPressed: () => _pickDate(context),
                ),
              ),
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
              child: Text(
                'Save Album',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
