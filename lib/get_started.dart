import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'home_page.dart';

class GetStartedPage extends StatefulWidget {
  const GetStartedPage({super.key});

  @override
  State<GetStartedPage> createState() => _GetStartedPageState();
}

class _GetStartedPageState extends State<GetStartedPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _imageSlideAnimation;
  late Animation<double> _imageFadeAnimation;
  late Animation<Offset> _buttonSlideAnimation;
  late Animation<double> _buttonFadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    // Animation for the circle images
    _imageSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
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
    final screenWidth = MediaQuery.of(context).size.width;
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 255, 255, 255),
      body: Stack(
        children: [
          // --- Decorative circles remain in the background ---
          Positioned(
            bottom: -160,
            left: -100,
            right: -100,
            child: SlideTransition(
              position: _imageSlideAnimation,
              child: FadeTransition(
                opacity: _imageFadeAnimation,
                child: Image.asset('assets/images/circle2.png', fit: BoxFit.contain),
              ),
            ),
          ),
          Positioned(
            bottom: -190,
            left: -100,
            right: -100,
            child: SlideTransition(
              position: _imageSlideAnimation,
              child: FadeTransition(
                opacity: _imageFadeAnimation,
                child: Image.asset('assets/images/circle.png', fit: BoxFit.contain),
              ),
            ),
          ),
          Positioned(
            bottom: -220,
            left: -100,
            right: -100,
            child: SlideTransition(
              position: _imageSlideAnimation,
              child: FadeTransition(
                opacity: _imageFadeAnimation,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(1000.0),
                  child: Image.asset('assets/images/circle3.png', fit: BoxFit.contain),
                ),
              ),
            ),
          ),

          // --- Main content now uses a Column with a Spacer ---
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- Top section (Logo and Text) ---
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
                        fontSize: 20,
                        fontWeight: FontWeight.w400,
                        color: const Color.fromARGB(255, 128, 68, 12),
                      ),
                    ),
                  ),

                  // --- Spacer for flexible space ---
                  const Spacer(),

                  // --- button at the bottom of the Column ---
                  Center(
                      child: SlideTransition(
                      position: _buttonSlideAnimation,
                      child: FadeTransition(
                        opacity: _buttonFadeAnimation,
                        child: SizedBox(
                            width: screenWidth * 0.7,
                            child: ElevatedButton(
                            style: ButtonStyle(
                              foregroundColor: WidgetStateProperty.all<Color>( 
                                const Color.fromARGB(255, 255, 255, 255),
                              ),
                              backgroundColor: WidgetStateProperty.all<Color>( 
                                const Color.fromARGB(255, 236, 185, 74),
                              ),
                              padding: WidgetStateProperty.all<EdgeInsets>(
                                const EdgeInsets.symmetric(vertical: 22),
                              ),
                              elevation: WidgetStateProperty.all<double>(90), 
                              shadowColor: WidgetStateProperty.all<Color>( 
                                const Color.fromARGB(115, 0, 0, 0),
                              ),
                              textStyle: WidgetStateProperty.all<TextStyle>( 
                                GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold),
                              ),
                              
                              // Updated this block for the press color
                              overlayColor: WidgetStateProperty.resolveWith<Color?>( 
                                (Set<WidgetState> states) { 
                                  if (states.contains(WidgetState.pressed)) { 
                                    return const Color.fromARGB(255, 243, 181, 48); 
                                  }
                                  return null; 
                                },
                              ),
                            ),

                            onPressed: () {
                              Navigator.of(context).pushReplacement(
                                MaterialPageRoute(builder: (context) => const HomePage()),
                              );
                            },
                            child: const Text('Get Started'),
                          ),
                        ),
                      ),
                    ),
                  ),
                    const SizedBox(height: 20),//padding at the very buttom 
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}