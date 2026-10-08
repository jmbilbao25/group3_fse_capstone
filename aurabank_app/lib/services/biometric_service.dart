import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

/// Service responsible for communicating with native iOS & Android
/// biometric authentication hardware (Face ID / Touch ID / BiometricPrompt).
class BiometricService {
  final LocalAuthentication _auth = LocalAuthentication();

  /// Check whether the device hardware supports biometrics and is ready.
  Future<bool> canAuthenticate() async {
    try {
      final bool canCheck = await _auth.canCheckBiometrics;
      final bool isDeviceSupported = await _auth.isDeviceSupported();
      return canCheck || isDeviceSupported;
    } on MissingPluginException {
      // Running inside widget test environment without mock method channel
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Returns the available biometric types on the current device (e.g. face, fingerprint).
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } on MissingPluginException {
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Triggers the actual native operating system Face ID / Biometrics prompt.
  /// Returns `true` if authentication succeeded, `false` otherwise.
  Future<bool> authenticate({required String reason}) async {
    try {
      final bool isSupported = await canAuthenticate();
      if (!isSupported) {
        return false;
      }

      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: true, // Only biometric sensors (Face ID / Fingerprint)
          stickyAuth: true,    // Stay active if OS switches context briefly
          useErrorDialogs: true,
        ),
      );
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    } catch (_) {
      return false;
    }
  }
}
