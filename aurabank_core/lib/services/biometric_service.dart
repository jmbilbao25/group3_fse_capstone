import 'package:flutter/foundation.dart';
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
      // Running inside test environment without mock method channel
      return false;
    } catch (e) {
      debugPrint('[BiometricService] canAuthenticate error: $e');
      return false;
    }
  }

  /// Check whether the user currently has biometrics enrolled in device settings.
  Future<bool> hasEnrolledBiometrics() async {
    try {
      final List<BiometricType> available = await _auth.getAvailableBiometrics();
      return available.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Returns the available biometric types on the current device (e.g. face, fingerprint, weak, strong).
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } on MissingPluginException {
      return [];
    } catch (e) {
      debugPrint('[BiometricService] getAvailableBiometrics error: $e');
      return [];
    }
  }

  /// Triggers the actual native operating system Face ID / Biometrics prompt.
  /// Returns `true` if authentication succeeded, `false` otherwise.
  Future<bool> authenticate({
    required String reason,
    bool biometricOnly = false,
  }) async {
    try {
      final bool isSupported = await canAuthenticate();
      if (!isSupported) {
        debugPrint('[BiometricService] Biometrics not supported on this device.');
        return false;
      }

      try {
        final bool didAuthenticate = await _auth.authenticate(
          localizedReason: reason,
          options: AuthenticationOptions(
            biometricOnly: biometricOnly,
            stickyAuth: true,
            useErrorDialogs: true,
            sensitiveTransaction: true,
          ),
        );
        debugPrint('[BiometricService] Authenticate result: $didAuthenticate');
        return didAuthenticate;
      } on PlatformException catch (e) {
        debugPrint('[BiometricService] PlatformException: ${e.code} (${e.message})');
        // If biometricOnly: true failed (e.g., Android Class 2 Face Unlock is classified as weak/convenience),
        // fallback to biometricOnly: false so the OS BiometricPrompt dialog can appear.
        if (biometricOnly) {
          try {
            debugPrint('[BiometricService] Retrying with biometricOnly: false fallback...');
            final bool fallbackResult = await _auth.authenticate(
              localizedReason: reason,
              options: const AuthenticationOptions(
                biometricOnly: false,
                stickyAuth: true,
                useErrorDialogs: true,
                sensitiveTransaction: true,
              ),
            );
            return fallbackResult;
          } catch (retryError) {
            debugPrint('[BiometricService] Fallback authentication failed: $retryError');
            return false;
          }
        }
        return false;
      }
    } on MissingPluginException {
      debugPrint('[BiometricService] MissingPluginException');
      return false;
    } catch (e) {
      debugPrint('[BiometricService] Unexpected error: $e');
      return false;
    }
  }
}
