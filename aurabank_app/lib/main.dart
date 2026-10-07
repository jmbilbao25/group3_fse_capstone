import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
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
      builder: (context, child) {
        return LayoutBuilder(
          builder: (context, constraints) {
            // When viewed on wide screens (desktop/web browser), wrap in a sleek mobile frame
            if (constraints.maxWidth > 500) {
              return Container(
                color: const Color(0xFF0B0F19),
                alignment: Alignment.center,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 430),
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(44),
                    border: Border.all(color: const Color(0xFF1E293B), width: 8),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x66000000),
                        blurRadius: 40,
                        offset: Offset(0, 18),
                      ),
                    ],
                  ),
                  child: child ?? const SizedBox(),
                ),
              );
            }
            return child ?? const SizedBox();
          },
        );
      },
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
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