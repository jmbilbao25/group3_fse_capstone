import 'services/bank_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/auth/landing_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/app_shell.dart';
import 'screens/analytics/statement_screen.dart';
import 'screens/analytics/annual_report_screen.dart';
import 'screens/transfer/send_money_screen.dart';
import 'screens/cards/cards_screen.dart';
import 'screens/profile/settings_screen.dart';
import 'screens/auth/otp_verification_screen.dart';
import 'screens/profile/devices_sessions_screen.dart';
import 'screens/auth/security_gate_screen.dart';
import 'screens/profile/risk_showcase_screen.dart';
import 'theme/aura_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await BankService().initPreferences();
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
        '/login': (context) => const LoginScreen(),
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