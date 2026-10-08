import 'dart:async' show Timer;
import 'dart:io' show Directory, File, Platform, Socket, exit;
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show MethodChannel, SystemNavigator;
import '../widgets/screen_sharing_warning_sheet.dart';

class SecurityAssessment {
  final bool isCompromised;
  final List<String> threats;

  const SecurityAssessment({
    required this.isCompromised,
    this.threats = const [],
  });

  String get summary => threats.isEmpty ? 'Device Secure' : threats.join(', ');
}

/// Standalone device integrity & security service.
/// Detects rooted Android environments, unlocked bootloaders, developer options,
/// emulators, runtime hooks, jailbroken iOS devices, and tampering.
class SecurityService {
  static const MethodChannel _channel = MethodChannel('com.bank.app/device_security');

  /// Known root binaries and directories on Android
  static const List<String> _androidRootPaths = [
    '/system/app/Superuser.apk',
    '/sbin/su',
    '/system/bin/su',
    '/system/xbin/su',
    '/data/local/xbin/su',
    '/data/local/bin/su',
    '/system/sd/xbin/su',
    '/system/bin/failsafe/su',
    '/data/local/su',
    '/su/bin/su',
    '/system/xbin/daemonsu',
    '/system/etc/init.d/99SuperSUDaemon',
    '/dev/com.koushikdutta.superuser.daemon/',
    '/system/app/Magisk.apk',
  ];

  /// Known jailbreak indicators on iOS
  static const List<String> _iosJailbreakPaths = [
    '/Applications/Cydia.app',
    '/Library/MobileSubstrate/MobileSubstrate.dylib',
    '/bin/bash',
    '/usr/sbin/sshd',
    '/etc/apt',
    '/private/var/lib/apt/',
    '/Applications/Sileo.app',
    '/Applications/Zebra.app',
  ];

  /// Compile-time / launch-time environment variable support (zero code edits):
  /// e.g. flutter run --dart-define=SECURITY_THREAT=rooted
  ///      flutter run --dart-define=SECURITY_THREAT=dev_options
  ///      flutter run --dart-define=SECURITY_THREAT=bootloader
  ///      flutter run --dart-define=SECURITY_THREAT=emulator
  ///      flutter run --dart-define=SIMULATE_COMPROMISED=true
  ///      flutter run --dart-define=SIMULATE_SCREEN_SHARING=true
  static const String _envThreat = String.fromEnvironment('SECURITY_THREAT', defaultValue: '');
  static const bool _envSimulate = bool.fromEnvironment('SIMULATE_COMPROMISED', defaultValue: false);
  static const bool _envSimulateScreenSharing = bool.fromEnvironment('SIMULATE_SCREEN_SHARING', defaultValue: false);

  /// Set to true in development/test if you want to simulate a compromised device in code
  static bool simulateCompromised = false;

  /// Set to true in development/test if you want to simulate active screen sharing in code
  static bool simulateScreenSharing = false;

  /// Toggle to enable or disable emulator detection.
  /// Set to false to allow testing on Android/iOS emulators and virtual environments.
  static bool enableEmulatorDetection = false;

  /// Toggle to enable or disable ADB and Developer Mode detection.
  /// Set to false during local development/testing so emulators and tethered devices can run.
  static bool enableAdbDetection = false;
  static bool enableDevOptionsDetection = false;

  /// Performs full device security assessment.
  static Future<SecurityAssessment> assessDevice() async {
    // 1. Check environment variable override (--dart-define) or in-memory flag
    if (simulateCompromised || _envSimulate || _envThreat.isNotEmpty) {
      String threat = 'Simulated Tamper Alert: Root / Developer Options / Bootloader (TEST MODE)';
      final lower = _envThreat.toLowerCase().trim();
      if (lower == 'rooted' || lower == 'root') {
        threat = 'Root binary detected: /system/bin/su';
      } else if (lower == 'dev_options' || lower == 'adb' || lower == 'developer') {
        threat = 'Developer Options Enabled, USB Debugging (ADB) Active';
      } else if (lower == 'bootloader') {
        threat = 'Unlocked Bootloader (AVB Compromised)';
      } else if (lower == 'emulator') {
        threat = 'Android Emulator / Virtual Environment Detected';
      } else if (lower == 'frida' || lower == 'hooking') {
        threat = 'Frida Dynamic Instrumentation Server Detected';
      } else if (_envThreat.isNotEmpty) {
        threat = _envThreat;
      }
      return SecurityAssessment(
        isCompromised: true,
        threats: [threat],
      );
    }

    // 2. Check external runtime file trigger (allows zero-code runtime testing while app is running)
    if (!kIsWeb) {
      try {
        final tempFile = File('${Directory.systemTemp.path}/.bank_security_tamper');
        if (tempFile.existsSync()) {
          final customReason = tempFile.readAsStringSync().trim();
          return SecurityAssessment(
            isCompromised: true,
            threats: [
              customReason.isNotEmpty
                  ? customReason
                  : 'Hardware tamper signal detected: /system/bin/su (Security Alert)',
            ],
          );
        }
      } catch (_) {}
    }

    if (kIsWeb) {
      // Browsers do not have root/jailbreak file systems
      return const SecurityAssessment(isCompromised: false);
    }

    final threats = <String>[];

    try {
      if (Platform.isAndroid) {
        // 1. Check for common root binaries
        for (final path in _androidRootPaths) {
          if (File(path).existsSync() || Directory(path).existsSync()) {
            threats.add('Root binary or directory detected: $path');
            break;
          }
        }

        // 2. Check for build tags indicating custom / test-keys ROM
        final buildTags = Platform.environment['BUILD_TAGS'] ?? '';
        if (buildTags.contains('test-keys')) {
          threats.add('Custom ROM detected (test-keys build)');
        }

        // 3. Query native Kotlin layer for Android-specific hardware/OS integrity
        try {
          final Map<dynamic, dynamic>? nativeReport =
              await _channel.invokeMethod('getAndroidSecurityReport');

          if (nativeReport != null) {
            if (enableDevOptionsDetection && nativeReport['isDevOptionsEnabled'] == true) {
              threats.add('Developer Options Enabled');
            }
            if (enableAdbDetection && nativeReport['isAdbEnabled'] == true) {
              threats.add('USB Debugging (ADB) Active');
            }
            if (nativeReport['isBootloaderUnlocked'] == true) {
              threats.add('Unlocked Bootloader (AVB Compromised)');
            }
            if (enableEmulatorDetection && nativeReport['isEmulator'] == true) {
              threats.add('Android Emulator / Virtual Environment Detected');
            }
            if (nativeReport['isDebuggerAttached'] == true) {
              threats.add('Live Debugger Attached');
            }
          }
        } catch (nativeErr) {
          debugPrint('[SecurityService] Native channel query error: $nativeErr');
        }

        // 4. Probe for Frida default listening port (27042)
        try {
          final socket = await Socket.connect('127.0.0.1', 27042, timeout: const Duration(milliseconds: 150));
          socket.destroy();
          threats.add('Frida Dynamic Instrumentation Server Detected');
        } catch (_) {
          // Normal: port is closed
        }
      } else if (Platform.isIOS) {
        // 1. Check for jailbreak paths
        for (final path in _iosJailbreakPaths) {
          if (File(path).existsSync() || Directory(path).existsSync()) {
            threats.add('Jailbreak artifact detected: $path');
            break;
          }
        }

        // 2. Check for sandbox escape via writing outside sandbox
        try {
          final testFile = File('/private/jailbreak_test.txt');
          testFile.writeAsStringSync('jailbreak_test');
          if (testFile.existsSync()) {
            testFile.deleteSync();
            threats.add('iOS Sandbox escape detected (unrestricted write)');
          }
        } catch (_) {
          // Expected on normal unjailbroken devices
        }
      }
    } catch (e) {
      debugPrint('[SecurityService] Integrity check caught exception: $e');
    }

    return SecurityAssessment(
      isCompromised: threats.isNotEmpty,
      threats: threats,
    );
  }

  /// Convenience boolean check
  static Future<bool> isCompromised() async {
    final result = await assessDevice();
    return result.isCompromised;
  }

  /// Flag to allow test harnesses to verify auto-close behavior without terminating the test runner.
  static bool enableAutoExit = true;

  /// Automatically terminates the mobile application cleanly across platforms.
  static void exitApp() {
    if (!enableAutoExit) {
      debugPrint('[SecurityService] exitApp() called (suppressed for test environment)');
      return;
    }
    if (kIsWeb) {
      debugPrint('[SecurityService] exitApp() called in web browser environment.');
      return;
    }
    try {
      if (Platform.isAndroid) {
        SystemNavigator.pop();
      } else {
        exit(0);
      }
    } catch (e) {
      debugPrint('[SecurityService] System exit exception: $e');
    }
    // Safety fallback: ensure process termination if SystemNavigator.pop() is delayed
    Future.delayed(const Duration(milliseconds: 300), () {
      try {
        exit(0);
      } catch (_) {}
    });
  }

  /// Displays the security warning dialog and automatically closes the application after the delay.
  static Future<void> showWarningDialogAndExit(
    BuildContext context, {
    required String reason,
    int delaySeconds = 2,
    VoidCallback? onExit,
  }) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => SecurityWarningDialog(
        reason: reason,
        autoClose: true,
        delaySeconds: delaySeconds,
        onExit: onExit,
      ),
    );
  }

  /// Evaluates whether an app or display service is currently recording or sharing the screen.
  static Future<bool> isScreenSharingActive() async {
    // 1. Check in-memory simulation flag or compile-time dart-define
    if (simulateScreenSharing ||
        _envSimulateScreenSharing ||
        _envThreat.toLowerCase().contains('screen_share') ||
        _envThreat.toLowerCase().contains('screenshare')) {
      return true;
    }

    // 2. Check external runtime file trigger (allows zero-code testing on live devices/emulators)
    if (!kIsWeb) {
      try {
        final tempFile = File('${Directory.systemTemp.path}/.bank_security_screen_sharing');
        if (tempFile.existsSync()) {
          return true;
        }
      } catch (_) {}
    }

    // 3. Query native Android layer for active virtual displays, MediaProjection, or presentation displays
    if (!kIsWeb) {
      try {
        if (Platform.isAndroid) {
          final dynamic nativeResult = await _channel.invokeMethod('isScreenSharingActive');
          if (nativeResult == true) {
            return true;
          }
        }
      } catch (e) {
        debugPrint('[SecurityService] Native isScreenSharingActive query error: $e');
      }
    }

    return false;
  }

  /// Displays the screen sharing warning bottom sheet modal.
  /// Returns the action chosen by the user (cancel, pause, or continue).
  static Future<ScreenSharingUserAction?> showScreenSharingWarning(
    BuildContext context, {
    VoidCallback? onCancel,
    VoidCallback? onPause,
    VoidCallback? onContinue,
  }) async {
    return ScreenSharingWarningSheet.show(
      context,
      onCancel: onCancel,
      onPause: onPause,
      onContinue: onContinue,
    );
  }
}

/// Interactive Warning Dialog displaying detected threats and automatically closing after a delay.
class SecurityWarningDialog extends StatefulWidget {
  final String reason;
  final bool autoClose;
  final int delaySeconds;
  final VoidCallback? onExit;

  const SecurityWarningDialog({
    super.key,
    required this.reason,
    this.autoClose = true,
    this.delaySeconds = 2,
    this.onExit,
  });

  @override
  State<SecurityWarningDialog> createState() => _SecurityWarningDialogState();
}

class _SecurityWarningDialogState extends State<SecurityWarningDialog> {
  late int _remainingSeconds;
  Timer? _countdownTimer;
  Timer? _safetyCloseTimer;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.delaySeconds;
    if (widget.autoClose) {
      _startCountdown();
    }
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_remainingSeconds > 1) {
        setState(() {
          _remainingSeconds--;
        });
      } else {
        setState(() {
          _remainingSeconds = 0;
        });
        timer.cancel();
        _triggerExit();
      }
    });

    // Safety timer guaranteeing close exactly at delaySeconds
    _safetyCloseTimer = Timer(Duration(seconds: widget.delaySeconds), () {
      _countdownTimer?.cancel();
      _triggerExit();
    });
  }

  void _triggerExit() {
    if (widget.onExit != null) {
      widget.onExit!();
    } else {
      SecurityService.exitApp();
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _safetyCloseTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: false,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: isDark ? const Color(0xFF1E222B) : Colors.white,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.redAccent.withAlpha(30),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.redAccent.withAlpha(80), width: 1.5),
              ),
              child: const Icon(
                Icons.gpp_bad_rounded,
                color: Colors.redAccent,
                size: 28,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Security Warning',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.redAccent,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'AuraBank detected an untrusted environment. To safeguard customer accounts and financial integrity, this application cannot run on compromised devices.',
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: isDark ? Colors.grey[300] : Colors.grey[800],
              ),
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF15181E) : const Color(0xFFFFF1F2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark ? Colors.redAccent.withAlpha(70) : Colors.red.withAlpha(80),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, size: 14, color: Colors.redAccent),
                      const SizedBox(width: 6),
                      Text(
                        'SECURITY ALERT',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                          color: isDark ? Colors.redAccent : Colors.red[800],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Suspicious activity or unsupported environment detected on device',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.grey[200] : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF262C36) : const Color(0xFFF1F3F7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.redAccent,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.autoClose
                          ? 'Automatically closing in $_remainingSeconds second${_remainingSeconds == 1 ? '' : 's'}...'
                          : 'Application is terminating...',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.grey[300] : Colors.grey[700],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        actions: [
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              icon: const Icon(Icons.exit_to_app_rounded, size: 16),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _triggerExit,
              label: const Text('Close App Now', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Fallback full-screen barrier displayed on launch if device integrity fails.
/// Centered on a hardened backdrop, displaying the SecurityWarningDialog and auto-closing in 2 seconds.
class SecurityLockoutScreen extends StatelessWidget {
  final String? reason;
  final bool autoClose;
  final int delaySeconds;
  final VoidCallback? onExit;

  const SecurityLockoutScreen({
    super.key,
    this.reason,
    this.autoClose = true,
    this.delaySeconds = 2,
    this.onExit,
  });

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark().copyWith(
          scaffoldBackgroundColor: const Color(0xFF101215),
        ),
        home: Scaffold(
          backgroundColor: const Color(0xFF101215),
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: SecurityWarningDialog(
                  reason: reason ?? 'Device integrity compromised',
                  autoClose: autoClose,
                  delaySeconds: delaySeconds,
                  onExit: onExit,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

