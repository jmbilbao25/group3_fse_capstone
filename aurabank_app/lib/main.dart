import 'package:flutter/material.dart';
import 'screens/landing_screen.dart';

void main() {
  runApp(const AuraBankApp());
}

class AuraBankApp extends StatelessWidget {
  const AuraBankApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: SplashScreen(),
    );
  }
}