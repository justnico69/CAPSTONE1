import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AlbumDetailPage extends StatelessWidget {
  final String name;
  final String date;

  const AlbumDetailPage({
    super.key,
    required this.name,
    required this.date,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(name, style: GoogleFonts.poppins()),
        backgroundColor: const Color(0xFFEAA944),
      ),
      body: Center(
        child: Text(
          'Album: $name\nDate: $date',
          style: GoogleFonts.poppins(fontSize: 18),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
