import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'main.dart'; // This imports your HomePage

class GetStartedPage extends StatefulWidget {
  const GetStartedPage({super.key});

  @override
  State<GetStartedPage> createState() => _GetStartedPageState();
}

class _GetStartedPageState extends State<GetStartedPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  // Create separate animation objects for the images and the button
  late Animation<Offset> _imageSlideAnimation;
  late Animation<double> _imageFadeAnimation;
  late Animation<Offset> _buttonSlideAnimation;
  late Animation<double> _buttonFadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2), // Total duration for the whole sequence
    );

    // Animation for the circle images
    _imageSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      // The images will animate in the first 70% of the duration
      curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
    ));
    _imageFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.0, 0.7, curve: Curves.easeOut)));

    // Delayed animation for the button
    _buttonSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      // The button will animate in the last 70% of the duration, creating an overlap
      curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
    ));
    _buttonFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.3, 1.0, curve: Curves.easeOut)));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 255, 255, 255),
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24.0, vertical: 40.0),
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
                    const SizedBox(height: 350),
                  ],
                ),
              ),
            ),
          ),

          // Apply the image animations to the circle images
          Positioned(
            bottom: -260,
            left: -90,
            right: -90,
            child: SlideTransition(
              position: _imageSlideAnimation,
              child: FadeTransition(
                opacity: _imageFadeAnimation,
                child: Image.asset(
                  'assets/images/circle.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -300,
            left: -95,
            right: -95,
            child: SlideTransition(
              position: _imageSlideAnimation,
              child: FadeTransition(
                opacity: _imageFadeAnimation,
                child: Image.asset(
                  'assets/images/circle2.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -260,
            left: -95,
            right: -95,
            child: SlideTransition(
              position: _imageSlideAnimation,
              child: FadeTransition(
                opacity: _imageFadeAnimation,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(1000.0),
                  child: Image.asset(
                    'assets/images/circle4.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),

          // Apply the delayed button animations to the button
          Positioned(
            bottom: 30,
            left: 40,
            right: 40,
            child: SlideTransition(
              position: _buttonSlideAnimation,
              child: FadeTransition(
                opacity: _buttonFadeAnimation,
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      foregroundColor: const Color.fromARGB(255, 255, 255, 255),
                      backgroundColor: const Color.fromARGB(255, 236, 185, 74),
                      padding: const EdgeInsets.symmetric(vertical: 23),
                      overlayColor: const Color.fromARGB(255, 82, 42, 4),
                      elevation: 90,
                      shadowColor: const Color.fromARGB(115, 0, 0, 0),
                      textStyle: GoogleFonts.poppins(
                          fontSize: 18, fontWeight: FontWeight.bold),
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
            ),
          ),
        ],
      ),
    );
  }
}