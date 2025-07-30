import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'detector_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    // Get screen dimensions for responsive layout
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: const Color.fromARGB(243, 248, 248, 248),
      body: Column(
        children: [

          // -- HEADER --
          ClipRRect(
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(70),
              bottomRight: Radius.circular(70),
            ),
            child: Container(
              height: screenHeight * 0.195,
              color: Colors.white,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(30, 0, 30, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Image.asset(
                            'assets/images/spotato_logo.png',
                            height: screenHeight * 0.05,
                          ),
                          const SizedBox(width: 10),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              RichText(
                                text: TextSpan(
                                  style: GoogleFonts.poppins(
                                    fontSize: 25,
                                    fontWeight: FontWeight.w800,
                                  ),
                                  children: const <TextSpan>[
                                    TextSpan(
                                      text: 'SPOT',
                                      style: TextStyle(
                                          color: Color.fromARGB(255, 128, 68, 12)),
                                    ),
                                    TextSpan(
                                      text: 'ato',
                                      style: TextStyle(
                                          color: Color.fromARGB(255, 236, 185, 74)),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                "at your service!",
                                style: GoogleFonts.poppins(
                                  color: const Color.fromARGB(255, 160, 98, 45),
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.notifications,
                            color: Color.fromARGB(255, 128, 68, 12), size: 28),
                        onPressed: () {},
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // -- RESULTS CONTENT --
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: screenWidth * 0.07,
                vertical: screenWidth * 0.08,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Results Card
                  Text(
                    "Results",
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: const Color.fromARGB(255, 128, 68, 12),
                    ),
                  ),
                  const SizedBox(height: 10),
                  AspectRatio(
                    aspectRatio: 4 / 3,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(20),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ]),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16.0),
                            child: Text(
                              "No images yet. Tap Button to scan.",
                              textAlign: TextAlign.center,
                              style:
                                  GoogleFonts.poppins(color: Colors.grey[600]),
                            ),
                          ),
                          const SizedBox(height: 50),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) =>
                                        const DetectorPage()),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFEAA944),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 40, vertical: 16),
                            ),
                            child: Text("Detect Disease",
                                style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // -- IMAGES CONTENT --
                  const SizedBox(height: 30),
                  Text(
                    "Images",
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: const Color.fromARGB(255, 128, 68, 12),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    height: screenHeight * 0.25,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(20),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Text(
                      "Folder is empty.\nImages are not imported yet.",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(color: Colors.grey[600]),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),

      // --- NAVIGATION BAR ---
    floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    floatingActionButton: FloatingActionButton(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const DetectorPage()),
        );
      },
      backgroundColor: const Color.fromARGB(255, 82, 42, 4),
      shape: const CircleBorder(),
      child: const Icon(Icons.document_scanner_outlined, color: Colors.white),
    ),
    bottomNavigationBar: BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 8.0,
      color: Colors.white,
      elevation: 10.0,
      height: screenHeight * 0.09, // <-- RESPONSIVE CHANGE (e.g., 8.5% of screen height)
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: <Widget>[
          _buildBottomNavItem(
            icon: Icons.home_filled,
            label: "Home",
            isSelected: true,
            screenWidth: screenWidth, // Pass screenWidth to the helper
          ),
          // 2. Make the spacing proportional to the screen width
          SizedBox(width: screenWidth * 0.05), // <-- RESPONSIVE CHANGE
          _buildBottomNavItem(
            icon: Icons.history,
            label: "History",
            isSelected: false,
            screenWidth: screenWidth, // Pass screenWidth to the helper
          ),
        ],
      ),
    ),
    );
    }

    // --- UPDATED HELPER WIDGET FOR RESPONSIVE NAV ITEMS ---
    Widget _buildBottomNavItem({
      required IconData icon,
      required String label,
      required bool isSelected,
      required double screenWidth, // 3. Accept screenWidth
    }) {
      final color = isSelected ? const Color.fromARGB(255, 82, 42, 4) : Colors.grey;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 4. Make the icon size proportional
          Icon(icon, color: color, size: screenWidth * 0.06), // <-- RESPONSIVE CHANGE
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.poppins(
              color: color,
              // 5. Make the font size proportional
              fontSize: screenWidth * 0.03, // <-- RESPONSIVE CHANGE
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      );
    }
}