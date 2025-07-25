import 'package:flutter/material.dart';

import 'landing_page.dart';

void main() {
  runApp(const SPOTATOApp());
}

class SPOTATOApp extends StatelessWidget {
  const SPOTATOApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SPOTATO',
      theme: ThemeData(primarySwatch: Colors.green, useMaterial3: true),
      home: const LandingPage(), // This is the starting point of your app
    );
  }
}
