import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/landing_screen.dart';
import 'screens/app_shell.dart';
import 'screens/statement_screen.dart';
import 'screens/annual_report_screen.dart';
import 'screens/send_money_screen.dart';
import 'screens/cards_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/otp_verification_screen.dart';
import 'screens/devices_sessions_screen.dart';
import 'screens/security_gate_screen.dart';
import 'screens/risk_showcase_screen.dart';
import 'theme/aura_theme.dart';
import 'screens/biometric_router_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const AuraBankApp());
}

class AuraBankApp extends StatelessWidget {
  const AuraBankApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: AuraColors.textPrimary,
          elevation: 0,
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const LandingScreen(),
        '/login': (context) => const BiometricRouterScreen(),
        '/dashboard': (context) => const AppShell(initialIndex: 0),
        '/cards': (context) => const CardsScreen(),
        '/analytics': (context) => const AppShell(initialIndex: 3),
        '/settings': (context) => const SettingsScreen(),
        '/statement': (context) => const StatementScreen(),
        '/annual_report': (context) => const AnnualReportScreen(),
        '/transfer': (context) => const SendMoneyScreen(),
        '/otp': (context) => const OtpVerificationScreen(),
        '/devices': (context) => const DevicesSessionsScreen(),
        '/security_gate': (context) => const SecurityGateScreen(),
        '/risk_showcase': (context) => const RiskEngineShowcaseScreen(),
      },
    );
  }
}