import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import '../models/user_persona.dart';

class BackendConfig {
  static final BackendConfig _instance = BackendConfig._internal();
  factory BackendConfig() => _instance;
  BackendConfig._internal();

  /// Laptop's local Wi-Fi IP address for cross-device testing
  static const String defaultLanIp = '172.20.10.2';

  static String _resolveInitialHost() {
    if (kIsWeb) {
      final baseHost = Uri.base.host;
      if (baseHost.isNotEmpty && baseHost != 'localhost' && baseHost != '127.0.0.1') {
        return baseHost;
      }
      return 'localhost';
    }
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        return defaultLanIp;
      }
    } catch (_) {}
    return 'localhost';
  }

  String _host = _resolveInitialHost();
  String get host => _host;
  set host(String val) {
    if (val.trim().isNotEmpty) {
      _host = val.trim();
    }
  }

  Future<bool> testConnection() async {
    try {
      final client = http.Client();
      final uri = Uri.parse('http://$_host:8081/actuator/health');
      final res = await client.get(uri).timeout(const Duration(seconds: 3));
      client.close();
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}

String get defaultBackendHost => BackendConfig().host;


enum AuthStatus { authenticated, mfaRequired, failed }

class AuthLoginResult {
  final AuthStatus status;
  final String? accessToken;
  final String? role;
  final String? userId;
  final String? maskedEmail;
  final String? errorMessage;
  final UserPersona? persona;
  final String? deviceId;
  final String? deviceName;
  final bool? isPrimaryDevice;
  final bool? isApproved;
  final String? primaryDeviceId;

  AuthLoginResult({
    required this.status,
    this.accessToken,
    this.role,
    this.userId,
    this.maskedEmail,
    this.errorMessage,
    this.persona,
    this.deviceId,
    this.deviceName,
    this.isPrimaryDevice,
    this.isApproved,
    this.primaryDeviceId,
  });
}

class AuthVerifyResult {
  final bool success;
  final String? accessToken;
  final String? role;
  final String? errorMessage;
  final String? deviceId;
  final String? deviceName;
  final bool? isPrimaryDevice;
  final bool? isApproved;
  final String? primaryDeviceId;

  AuthVerifyResult({
    required this.success,
    this.accessToken,
    this.role,
    this.errorMessage,
    this.deviceId,
    this.deviceName,
    this.isPrimaryDevice,
    this.isApproved,
    this.primaryDeviceId,
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
  String get gatewayUrl => 'http://$defaultBackendHost:8080';
  /// Direct Account Service endpoint (:8081)
  String get accountServiceUrl => 'http://$defaultBackendHost:8081';

  /// Injected HTTP client for testing
  http.Client? httpClient;

  // Stores session data for currently authenticating user
  String? currentUserId;
  String? currentEmail;
  UserPersona? currentPersona;
  String currentDeviceId = DeviceIdentity().id;
  String currentDeviceName = DeviceIdentity().name;
  bool? currentIsPrimaryDevice;
  bool? currentIsApproved;
  String? currentPrimaryDeviceId;
  String? currentAccessToken;

  void switchDevice(DevicePreset preset) {
    currentDeviceId = preset.id;
    currentDeviceName = preset.name;
    DeviceIdentity().setDevice(preset.id, preset.name);
  }

  http.Client get _client => httpClient ?? http.Client();

  /// Attempts strict login against backend /api/v1/auth/login.
  /// Checks Gateway (:8080), falls back to direct Account Service (:8081).
  /// If backend is offline, fails immediately with an explicit connection error.
  Future<AuthLoginResult> login({
    required String email,
    required String password,
    String? deviceId,
    String? deviceName,
  }) async {
    if (deviceId != null) currentDeviceId = deviceId;
    if (deviceName != null) currentDeviceName = deviceName;

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
                'device_id': currentDeviceId,
                'device_name': currentDeviceName,
              }),
            )
            .timeout(const Duration(seconds: 4));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final statusStr = data['status'] as String? ?? 'AUTHENTICATED';
          currentIsPrimaryDevice = data['is_primary_device'] as bool?;
          currentIsApproved = data['is_approved'] as bool? ?? (currentIsPrimaryDevice == true);
          currentPrimaryDeviceId = data['primary_device_id'] as String?;
          currentAccessToken = data['access_token'] as String?;
          currentUserId = data['user_id'] as String?;

          if (statusStr == 'MFA_REQUIRED') {
            final masked = data['masked_email'] as String? ?? email;

            return AuthLoginResult(
              status: AuthStatus.mfaRequired,
              userId: currentUserId,
              maskedEmail: masked,
              persona: currentPersona,
              deviceId: currentDeviceId,
              deviceName: currentDeviceName,
              isPrimaryDevice: currentIsPrimaryDevice,
              isApproved: currentIsApproved,
              primaryDeviceId: currentPrimaryDeviceId,
            );
          } else {
            return AuthLoginResult(
              status: AuthStatus.authenticated,
              accessToken: currentAccessToken,
              role: data['role'] as String?,
              userId: currentUserId,
              persona: currentPersona,
              deviceId: currentDeviceId,
              deviceName: currentDeviceName,
              isPrimaryDevice: currentIsPrimaryDevice,
              isApproved: currentIsApproved,
              primaryDeviceId: currentPrimaryDeviceId,
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
    String? deviceId,
    String? deviceName,
  }) async {
    if (deviceId != null) currentDeviceId = deviceId;
    if (deviceName != null) currentDeviceName = deviceName;

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
                'device_id': currentDeviceId,
                'device_name': currentDeviceName,
              }),
            )
            .timeout(const Duration(seconds: 4));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          currentIsPrimaryDevice = data['is_primary_device'] as bool?;
          currentIsApproved = data['is_approved'] as bool? ?? (currentIsPrimaryDevice == true);
          currentPrimaryDeviceId = data['primary_device_id'] as String?;
          currentAccessToken = data['access_token'] as String?;
          return AuthVerifyResult(
            success: true,
            accessToken: currentAccessToken,
            role: data['role'] as String?,
            deviceId: currentDeviceId,
            deviceName: currentDeviceName,
            isPrimaryDevice: currentIsPrimaryDevice,
            isApproved: currentIsApproved,
            primaryDeviceId: currentPrimaryDeviceId,
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

  Future<List<Map<String, dynamic>>> getRegisteredDevices({String? userId}) async {
    final uid = userId ?? currentUserId;
    if (uid == null) return [];
    final endpoints = kIsWeb ? [accountServiceUrl, gatewayUrl] : [gatewayUrl, accountServiceUrl];
    for (final baseUrl in endpoints) {
      try {
        final headers = <String, String>{'Content-Type': 'application/json'};
        if (currentAccessToken != null) {
          headers['Authorization'] = 'Bearer $currentAccessToken';
        }
        final url = Uri.parse('$baseUrl/api/v1/auth/devices?userId=$uid');
        final response = await _client.get(url, headers: headers).timeout(const Duration(seconds: 3));
        if (response.statusCode == 200) {
          final list = jsonDecode(response.body) as List<dynamic>;
          return list.cast<Map<String, dynamic>>();
        }
      } catch (_) {}
    }
    return [];
  }

  Future<bool> setPrimaryDevice({required String deviceId, String? userId}) async {
    final uid = userId ?? currentUserId;
    if (uid == null) return false;
    final endpoints = kIsWeb ? [accountServiceUrl, gatewayUrl] : [gatewayUrl, accountServiceUrl];
    for (final baseUrl in endpoints) {
      try {
        final headers = <String, String>{'Content-Type': 'application/json'};
        if (currentAccessToken != null) {
          headers['Authorization'] = 'Bearer $currentAccessToken';
        }
        final url = Uri.parse('$baseUrl/api/v1/auth/devices/primary');
        final response = await _client
            .post(
              url,
              headers: headers,
              body: jsonEncode({'user_id': uid, 'device_id': deviceId}),
            )
            .timeout(const Duration(seconds: 3));
        if (response.statusCode == 200) {
          currentPrimaryDeviceId = deviceId;
          currentIsPrimaryDevice = (currentDeviceId == deviceId);
          return true;
        }
      } catch (_) {}
    }
    return false;
  }

  Future<bool> approveDevice({required String deviceId, String? userId}) async {
    final uid = userId ?? currentUserId;
    if (uid == null) return false;
    final endpoints = kIsWeb ? [accountServiceUrl, gatewayUrl] : [gatewayUrl, accountServiceUrl];
    for (final baseUrl in endpoints) {
      try {
        final headers = <String, String>{'Content-Type': 'application/json'};
        if (currentAccessToken != null) {
          headers['Authorization'] = 'Bearer $currentAccessToken';
        }
        final url = Uri.parse('$baseUrl/api/v1/auth/devices/approve');
        final response = await _client
            .post(
              url,
              headers: headers,
              body: jsonEncode({'user_id': uid, 'device_id': deviceId}),
            )
            .timeout(const Duration(seconds: 3));
        if (response.statusCode == 200) {
          return true;
        }
      } catch (_) {}
    }
    return false;
  }

  Future<bool> revokeDevice({required String deviceId, String? userId}) async {
    final uid = userId ?? currentUserId;
    if (uid == null) return false;
    final endpoints = kIsWeb ? [accountServiceUrl, gatewayUrl] : [gatewayUrl, accountServiceUrl];
    for (final baseUrl in endpoints) {
      try {
        final headers = <String, String>{'Content-Type': 'application/json'};
        if (currentAccessToken != null) {
          headers['Authorization'] = 'Bearer $currentAccessToken';
        }
        final url = Uri.parse('$baseUrl/api/v1/auth/devices/revoke');
        final response = await _client
            .post(
              url,
              headers: headers,
              body: jsonEncode({'user_id': uid, 'device_id': deviceId}),
            )
            .timeout(const Duration(seconds: 3));
        if (response.statusCode == 200) {
          return true;
        }
      } catch (_) {}
    }
    return false;
  }

  Map<String, dynamic> _tryDecodeJson(String body) {
    try {
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }
}
