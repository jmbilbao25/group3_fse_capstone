import 'package:aurabank_core/navigation/root_navigator.dart';
import 'package:aurabank_core/screens/auth/landing_screen.dart';
import 'package:aurabank_core/screens/auth/login_screen.dart';
import 'package:aurabank_core/screens/auth/otp_verification_screen.dart';
import 'package:aurabank_core/screens/auth/security_gate_screen.dart';
import 'package:aurabank_core/services/bank_service.dart';
import 'package:aurabank_core/services/device_storage.dart';
import 'package:aurabank_core/theme/aura_theme.dart';
import 'package:flutter/material.dart';

import 'web_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DeviceStorage.init();
  await BankService().initPreferences();
  runApp(const AuraBankWeb());
}

class AuraBankWeb extends StatelessWidget {
  const AuraBankWeb({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: rootNavigatorKey,
      title: 'Aura Bank',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AuraColors.primary,
          primary: AuraColors.primary,
          surface: Colors.white,
        ),
        fontFamily: 'Inter',
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const LandingScreen(),
        '/login': (context) => const LoginScreen(),
        '/dashboard': (context) => const WebShell(),
        '/otp': (context) => const OtpVerificationScreen(),
        '/security_gate': (context) => const SecurityGateScreen(),
      },
    );
  }
}
