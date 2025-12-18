import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spotato/landing_page.dart';
import 'package:spotato/main.dart'; // For kDarkBrown constant if needed, or I'll redefine/import locally

class WalkthroughPage extends StatefulWidget {
  const WalkthroughPage({super.key});

  @override
  State<WalkthroughPage> createState() => _WalkthroughPageState();
}

class _WalkthroughPageState extends State<WalkthroughPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, dynamic>> _pages = [
    {
      "title": "Welcome to SPOTATO",
      "body": "Smart Potato Disease Detection powered by Drone Technology.",
      "image": "assets/images/spotato_logo.png", // Using the logo
      "icon": null,
    },
    {
      "title": "Drone Integration",
      "body": "Seamlessly connect with your Ryze Tello drone to capture field images automatically.",
      "image": null,
      "icon": Icons.flight_takeoff, // Drone icon
    },
    {
      "title": "Instant Analysis",
      "body": "Get real-time disease detection results offline, right on your device.",
      "image": null,
      "icon": Icons.analytics_outlined, // Analysis icon
    },
  ];

  Future<void> _finishWalkthrough() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('walkthrough_seen', true);

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const LandingPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (value) {
                  setState(() {
                    _currentPage = value;
                  });
                },
                itemCount: _pages.length,
                itemBuilder: (context, index) => _buildPageContent(
                  _pages[index],
                ),
              ),
            ),
            _buildBottomControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildPageContent(Map<String, dynamic> data) {
    return Padding(
      padding: const EdgeInsets.all(40.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (data['image'] != null)
            Image.asset(
              data['image'],
              height: 200,
            )
          else
            Icon(
              data['icon'],
              size: 150,
              color: const Color.fromARGB(255, 128, 68, 12), // kDarkBrown
            ),
          const SizedBox(height: 40),
          Text(
            data['title'],
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color.fromARGB(255, 128, 68, 12), // kDarkBrown
              fontFamily: 'Poppins',
            ),
          ),
          const SizedBox(height: 20),
          Text(
            data['body'],
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.grey,
              fontFamily: 'Poppins',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Skip Button
          TextButton(
            onPressed: _currentPage == _pages.length - 1 ? null : _finishWalkthrough,
            child: Text(
              _currentPage == _pages.length - 1 ? "" : "SKIP",
              style: const TextStyle(color: Colors.grey),
            ),
          ),

          // Page Indicators
          Row(
            children: List.generate(
              _pages.length,
              (index) => Container(
                margin: const EdgeInsets.only(right: 5),
                height: 8,
                width: _currentPage == index ? 20 : 8,
                decoration: BoxDecoration(
                  color: _currentPage == index
                      ? const Color.fromARGB(255, 128, 68, 12)
                      : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),

          // Next/Done Button
          TextButton(
            onPressed: () {
              if (_currentPage == _pages.length - 1) {
                _finishWalkthrough();
              } else {
                _pageController.nextPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.ease,
                );
              }
            },
            child: Text(
              _currentPage == _pages.length - 1 ? "DONE" : "NEXT",
              style: const TextStyle(
                color: Color.fromARGB(255, 128, 68, 12),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
