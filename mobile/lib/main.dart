import 'package:flutter/material.dart';
import 'models/user_persona.dart';
import 'screens/dashboard_screen.dart';
import 'screens/login_screen.dart';
import 'services/auth_api_service.dart';
import 'services/device_storage.dart';
import 'services/notification_stream_service.dart';
import 'services/security_service.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await DeviceStorage.init();

  final assessment = await SecurityService.assessDevice();
  if (assessment.isCompromised) {
    runApp(SecurityLockoutScreen(reason: assessment.summary));
    return;
  }

  runApp(const AuraBankApp());
}

class AuraBankApp extends StatefulWidget {
  const AuraBankApp({super.key});

  @override
  State<AuraBankApp> createState() => _AuraBankAppState();
}

class _AuraBankAppState extends State<AuraBankApp> with WidgetsBindingObserver {
  ThemeMode _themeMode = ThemeMode.light;
  UserPersona? _currentUser;
  bool _isLockedOut = false;
  String _lockoutReason = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _recheckSecurity();
    }
  }

  Future<void> _recheckSecurity() async {
    final assessment = await SecurityService.assessDevice();
    if (assessment.isCompromised && mounted) {
      setState(() {
        _isLockedOut = true;
        _lockoutReason = assessment.summary;
      });
    }
  }

  void _toggleTheme() {
    setState(() {
      _themeMode =
          _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    });
  }

  void _onLoginSuccess(UserPersona user) {
    setState(() {
      _currentUser = user;
    });
    // Globally initiate real-time notification stream for authenticated user
    final uid = AuthApiService().currentUserId ?? 'USR-100001';
    NotificationStreamService().connect(uid);
  }

  void _onLogout() {
    NotificationStreamService().disconnect();
    AuthApiService().logout();
    setState(() {
      _currentUser = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLockedOut) {
      return SecurityLockoutScreen(reason: _lockoutReason);
    }
    // Custom Brand Colors
    const primaryColor = Color(0xFF3A4CD6);
    const lightCanvas = Color(0xFFF4F5F7);
    const darkCanvas = Color(0xFF101215);

    final lightTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        primary: primaryColor,
        surface: Colors.white,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: lightCanvas,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE4E6EA)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE4E6EA)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
      ),
    );

    final darkTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        primary: primaryColor,
        surface: const Color(0xFF1A1D21),
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: darkCanvas,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1A1D21),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF2C323D)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF2C323D)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF6B7FFF), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
      ),
    );

    return MaterialApp(
      navigatorKey: rootNavigatorKey,
      title: 'AuraBank Mobile',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: lightTheme,
      darkTheme: darkTheme,
      home: _currentUser == null
          ? LoginScreen(
              onLoginSuccess: _onLoginSuccess,
              onToggleTheme: _toggleTheme,
              isDarkMode: _themeMode == ThemeMode.dark,
            )
          : DashboardScreen(
              user: _currentUser!,
              onLogout: _onLogout,
            ),
    );
  }
}
