import 'dart:io' show Directory, File, Platform, Socket, exit;
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show MethodChannel, SystemNavigator;

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

  /// Set to true in development/test if you want to simulate a compromised device
  static bool simulateCompromised = false;

  /// Performs full device security assessment.
  static Future<SecurityAssessment> assessDevice() async {
    if (simulateCompromised) {
      return const SecurityAssessment(
        isCompromised: true,
        threats: ['Simulated Tamper Alert: Root / Developer Options / Bootloader (TEST MODE)'],
      );
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
            if (nativeReport['isDevOptionsEnabled'] == true) {
              threats.add('Developer Options Enabled');
            }
            if (nativeReport['isAdbEnabled'] == true) {
              threats.add('USB Debugging (ADB) Active');
            }
            if (nativeReport['isBootloaderUnlocked'] == true) {
              threats.add('Unlocked Bootloader (AVB Compromised)');
            }
            if (nativeReport['isEmulator'] == true) {
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
}

/// Fallback blocking screen if device integrity fails
class SecurityLockoutScreen extends StatelessWidget {
  final String? reason;
  const SecurityLockoutScreen({super.key, this.reason});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: const Color(0xFF101215),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.red.withAlpha(30),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.redAccent.withAlpha(100), width: 2),
                    ),
                    child: const Icon(Icons.gpp_bad_rounded, size: 72, color: Colors.redAccent),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Security Violation Detected',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'AuraBank cannot run on compromised, rooted, or developer-mode Android devices to safeguard your funds and confidential financial data.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[400],
                      height: 1.5,
                    ),
                  ),
                  if (reason != null && reason!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E222B),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey[800]!),
                      ),
                      child: Text(
                        'Detected Threat: $reason',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12, color: Colors.redAccent),
                      ),
                    ),
                  ],
                  const SizedBox(height: 36),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.grey),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        if (Platform.isAndroid) {
                          SystemNavigator.pop();
                        } else {
                          exit(0);
                        }
                      },
                      child: const Text('Exit Application'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
