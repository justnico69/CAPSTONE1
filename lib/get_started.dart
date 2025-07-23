import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'main.dart'; // This imports your HomePage

class GetStartedPage extends StatelessWidget {
  const GetStartedPage({super.key});

@override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: const Color.fromRGBO(241, 239, 210, 1),
    body: SafeArea(
      // 1. Wrap the Padding with SingleChildScrollView
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Image.asset(
                        'assets/images/spotato_logo.png',
                        height: 60,
                      ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'SPOT',
                            style: GoogleFonts.poppins(
                              fontSize: 30,
                              fontWeight: FontWeight.bold,
                              color: const Color.fromARGB(255, 128, 68, 12),
                            ),
                          ),
                        ],
              ),
              const SizedBox(height: 40),
              _buildStep(
                icon: Icons.flight,
                title: '1. Fly & Capture',
                description:
                    'Use the official DJI Tello app to fly your drone and take photos of your plants.',
              ),
              const SizedBox(height: 30),
              _buildStep(
                icon: Icons.find_in_page_rounded,
                title: '2. Auto-Detect',
                description:
                    'Our app automatically detects the new photos on your phone as soon as they are saved.',
              ),
              const SizedBox(height: 30),
              _buildStep(
                icon: Icons.shield_outlined,
                title: '3. Analyze & Diagnose',
                description:
                    'Get an instant AI diagnosis of your plant\'s health, completely offline.',
              ),
              const SizedBox(height: 40), // Added space before the button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle:
                        const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (context) => const HomePage()),
                    );
                  },
                  child: const Text('Get Started'),
                ),
              ),
              // 2. The Spacer widget was removed from here
            ],
          ),
        ),
      ),
    ),
  );
}
  // Helper widget to build each step consistently
  Widget _buildStep(
      {required IconData icon,
      required String title,
      required String description}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 40, color: const Color.fromARGB(255, 128, 68, 12)),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: const Color.fromARGB(255, 128, 68, 12),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: GoogleFonts.lato(
                  fontSize: 16,
                  color: Colors.black54,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}