import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'main.dart'; // This imports your HomePage

class GetStartedPage extends StatelessWidget {
  const GetStartedPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 255, 255, 255),
      body: SafeArea(
        child: Column(
          children: [
            // This Expanded widget makes the content fill all available space, pushing the button down
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 5.0, top: 20.0),
                        child: Image.asset(
                          'assets/images/spotato_logo.png',
                          height: 70,
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Text(
                            'SPOT',
                            style: GoogleFonts.poppins(
                              fontSize: 40,
                              fontWeight: FontWeight.w800,
                              color: const Color.fromARGB(255, 128, 68, 12),
                            ),
                          ),
                          Text(
                            'ato',
                            style: GoogleFonts.poppins(
                              fontSize: 40,
                              fontWeight: FontWeight.w800,
                              color: const Color.fromARGB(255, 236, 185, 74),
                            ),
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.only(right: 10.0, top: 10.0),
                        child: Text(
                          'Hello, farmer! SPOTato is ready to guard your potatoes with smart drone-powered detection.',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w400,
                            color: const Color.fromARGB(255, 128, 68, 12),
                          ),
                        ),
                      ),
                      // The button is no longer here
                    ],
                  ),
                ),
              ),
            ),
            // The button is now outside the scroll view, at the bottom of the main Column
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24), // Add padding around the button
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    foregroundColor: const Color.fromARGB(255, 255, 255, 255), // This sets the text color
                    backgroundColor: const Color.fromARGB(255, 236, 185, 74),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                          builder: (context) => const HomePage()),
                    );
                  },
                  child: const Text('Get Started'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}