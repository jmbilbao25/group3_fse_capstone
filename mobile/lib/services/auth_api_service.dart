import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import '../models/user_persona.dart';

String get defaultBackendHost {
  if (!kIsWeb) {
    try {
      if (Platform.isAndroid) return '10.0.2.2';
    } catch (_) {}
  }
  return 'localhost';
}

enum AuthStatus { authenticated, mfaRequired, failed }

class AuthLoginResult {
  final AuthStatus status;
  final String? accessToken;
  final String? role;
  final String? userId;
  final String? maskedEmail;
  final String? errorMessage;
  final UserPersona? persona;

  AuthLoginResult({
    required this.status,
    this.accessToken,
    this.role,
    this.userId,
    this.maskedEmail,
    this.errorMessage,
    this.persona,
  });
}

class AuthVerifyResult {
  final bool success;
  final String? accessToken;
  final String? role;
  final String? errorMessage;

  AuthVerifyResult({
    required this.success,
    this.accessToken,
    this.role,
    this.errorMessage,
  });
}

/// Strict backend authentication client.
/// Directly communicates with Spring Cloud Gateway (:8080) or Account Service (:8081).
/// All mock / demo fallback shortcuts have been removed.
class AuthApiService {
  static final AuthApiService _instance = AuthApiService._internal();
  factory AuthApiService() => _instance;
  AuthApiService._internal();

  /// Primary Gateway endpoint (Spring Cloud Gateway :8080)
  String gatewayUrl = 'http://$defaultBackendHost:8080';
  /// Direct Account Service endpoint (:8081)
  String accountServiceUrl = 'http://$defaultBackendHost:8081';

  /// Injected HTTP client for testing
  http.Client? httpClient;

  // Stores session data for currently authenticating user
  String? currentUserId;
  String? currentEmail;
  UserPersona? currentPersona;

  http.Client get _client => httpClient ?? http.Client();

  /// Attempts strict login against backend /api/v1/auth/login.
  /// Checks Gateway (:8080), falls back to direct Account Service (:8081).
  /// If backend is offline, fails immediately with an explicit connection error.
  Future<AuthLoginResult> login({
    required String email,
    required String password,
  }) async {
    currentEmail = email;
    currentPersona = UserPersona.demoPersonas.firstWhere(
      (p) => p.email.toLowerCase() == email.trim().toLowerCase(),
      orElse: () => UserPersona(
        name: email.split('@').first.replaceAll('.', ' ').toUpperCase(),
        role: 'Customer',
        email: email,
        password: password,
        accountId: '1000-4491-0023',
        balance: 250000.00,
      ),
    );

    final endpoints = kIsWeb
        ? [accountServiceUrl, gatewayUrl]
        : [gatewayUrl, accountServiceUrl];
    String lastError = 'No backend service available';

    for (final baseUrl in endpoints) {
      try {
        final url = Uri.parse('$baseUrl/api/v1/auth/login');
        final response = await _client
            .post(
              url,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'email': email.trim(),
                'password': password,
              }),
            )
            .timeout(const Duration(seconds: 4));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final statusStr = data['status'] as String? ?? 'AUTHENTICATED';

          if (statusStr == 'MFA_REQUIRED') {
            currentUserId = data['user_id'] as String?;
            final masked = data['masked_email'] as String? ?? email;

            return AuthLoginResult(
              status: AuthStatus.mfaRequired,
              userId: currentUserId,
              maskedEmail: masked,
              persona: currentPersona,
            );
          } else {
            return AuthLoginResult(
              status: AuthStatus.authenticated,
              accessToken: data['access_token'] as String?,
              role: data['role'] as String?,
              userId: data['user_id'] as String?,
              persona: currentPersona,
            );
          }
        } else if (response.statusCode == 401 || response.statusCode == 403) {
          final data = _tryDecodeJson(response.body);
          return AuthLoginResult(
            status: AuthStatus.failed,
            errorMessage: data['detail'] as String? ?? 'Invalid email or password credentials.',
          );
        } else {
          final data = _tryDecodeJson(response.body);
          return AuthLoginResult(
            status: AuthStatus.failed,
            errorMessage: data['detail'] as String? ??
                'Authentication rejected (${response.statusCode}): ${response.reasonPhrase}',
          );
        }
      } catch (e) {
        lastError = 'Connection to $baseUrl failed ($e)';
      }
    }

    // STRICT: Return explicit connection failure error. NO demo fallback.
    return AuthLoginResult(
      status: AuthStatus.failed,
      errorMessage:
          'Backend connection failed: Unable to connect to Gateway (:8080) or Account Service (:8081). Please ensure backend services are running. ($lastError)',
    );
  }

  /// Attempts strict OTP verification against backend /api/v1/auth/verify-login-otp.
  Future<AuthVerifyResult> verifyLoginOtp({
    required String userId,
    required String otp,
  }) async {
    final endpoints = kIsWeb
        ? [accountServiceUrl, gatewayUrl]
        : [gatewayUrl, accountServiceUrl];
    String lastError = 'No backend service available';

    for (final baseUrl in endpoints) {
      try {
        final url = Uri.parse('$baseUrl/api/v1/auth/verify-login-otp');
        final response = await _client
            .post(
              url,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'user_id': userId,
                'otp': otp.trim(),
              }),
            )
            .timeout(const Duration(seconds: 4));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          return AuthVerifyResult(
            success: true,
            accessToken: data['access_token'] as String?,
            role: data['role'] as String?,
          );
        } else {
          final data = _tryDecodeJson(response.body);
          return AuthVerifyResult(
            success: false,
            errorMessage: data['detail'] as String? ?? 'Invalid or expired verification code.',
          );
        }
      } catch (e) {
        lastError = 'Connection to $baseUrl failed ($e)';
      }
    }

    // STRICT: Return explicit connection error. NO demo fallback.
    return AuthVerifyResult(
      success: false,
      errorMessage:
          'Backend connection failed: Unable to connect to backend for OTP verification. ($lastError)',
    );
  }

  Map<String, dynamic> _tryDecodeJson(String body) {
    try {
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }
}
