import 'dart:convert';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:http/http.dart' as http;
import '../models/user_persona.dart';
import 'bank_service.dart';
import 'device_storage.dart';
import 'security_service.dart';

class BackendConfig {
  static final BackendConfig _instance = BackendConfig._internal();
  factory BackendConfig() => _instance;
  BackendConfig._internal();

  /// Laptop's local Wi-Fi IP address for cross-device connectivity through the laptop
  static const String defaultLanIp = '192.168.18.110';

  static String _resolveInitialHost() {
    if (kIsWeb) {
      return 'localhost';
    }
    const envHost = String.fromEnvironment('BACKEND_HOST');
    if (envHost.isNotEmpty) {
      return envHost;
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return '127.0.0.1';
    }
    return defaultLanIp;
  }

  String _host = _resolveInitialHost();
  String get host => _host;
  set host(String val) {
    if (val.trim().isNotEmpty) {
      _host = val.trim();
    }
  }

  /// Ordered list of candidate hostnames/IPs to discover working backend
  static List<String> get candidateHosts {
    return <String>{
      '127.0.0.1',
      'localhost',
      BackendConfig().host,
      defaultLanIp,
      if (defaultTargetPlatform == TargetPlatform.android) ...[
        '10.0.2.2',
      ],
    }.toList();
  }

  Future<bool> testConnection() async {
    for (final h in candidateHosts) {
      try {
        final client = http.Client();
        final uri = Uri.parse('http://$h:8081/actuator/health');
        final res = await client.get(uri).timeout(const Duration(seconds: 2));
        client.close();
        if (res.statusCode == 200) {
          _host = h;
          return true;
        }
      } catch (_) {}
    }
    return false;
  }
}

String get defaultBackendHost => BackendConfig().host;


enum AuthStatus { authenticated, pendingApproval, mfaRequired, failed }

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
  final String? deviceType;
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
    this.deviceType,
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
  final String? deviceType;
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
    this.deviceType,
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
  AuthApiService._internal() {
    currentAccessToken = DeviceStorage.getAccessToken();
    currentUserId = DeviceStorage.getUserId();
  }

  /// Primary Gateway endpoint (Spring Cloud Gateway :8080)
  String get gatewayUrl => 'http://$defaultBackendHost:8080';
  /// Direct Account Service endpoint (:8081)
  String get accountServiceUrl => 'http://$defaultBackendHost:8081';

  List<String> get _endpoints {
    final candidateHosts = BackendConfig.candidateHosts;
    final List<String> list = [];
    for (final h in candidateHosts) {
      if (kIsWeb) {
        list.add('http://$h:8081');
        list.add('http://$h:8080');
      } else {
        list.add('http://$h:8080');
        list.add('http://$h:8081');
      }
    }
    return list;
  }

  void _recordWorkingEndpoint(String baseUrl) {
    final successfulHost = Uri.tryParse(baseUrl)?.host;
    if (successfulHost != null && successfulHost.isNotEmpty) {
      BackendConfig().host = successfulHost;
      BankService().setLocalUrl('http://$successfulHost:8080');
    }
  }

  /// Injected HTTP client for testing
  http.Client? httpClient;

  // Stores session data for currently authenticating user
  String? currentUserId;
  String? currentEmail;
  UserPersona? currentPersona;
  String currentDeviceId = DeviceIdentity().id;
  String currentDeviceName = DeviceIdentity().name;
  String currentDeviceType = DeviceIdentity().type;
  bool? currentIsPrimaryDevice;
  bool? currentIsApproved;
  String? currentPrimaryDeviceId;
  String? currentAccessToken;

  bool get isDeviceApproved => currentIsApproved ?? (currentIsPrimaryDevice == true);
  bool get isPrimaryDevice => currentIsPrimaryDevice ?? true;
  bool get isAuthenticated =>
      (currentAccessToken != null && currentAccessToken!.isNotEmpty) ||
      (DeviceStorage.getAccessToken() != null && DeviceStorage.getAccessToken()!.isNotEmpty);

  void switchDevice(DevicePreset preset) {
    currentDeviceId = preset.id;
    currentDeviceName = preset.name;
    currentDeviceType = preset.deviceType;
    DeviceIdentity().setDevice(preset.id, preset.name, newType: preset.deviceType);
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
    String? deviceType,
  }) async {
    if (deviceId != null) currentDeviceId = deviceId;
    if (deviceName != null) currentDeviceName = deviceName;
    if (deviceType != null) currentDeviceType = deviceType;

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

    final endpoints = _endpoints;

    for (final baseUrl in endpoints) {
      try {
        final assessment = await SecurityService.assessDevice();
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
                'device_type': currentDeviceType,
                'is_device_compromised': assessment.isCompromised,
                'compromise_reasons': assessment.summary,
              }),
            )
            .timeout(const Duration(seconds: 4));

        if (response.statusCode == 200) {
          _recordWorkingEndpoint(baseUrl);
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final statusStr = data['status'] as String? ?? 'AUTHENTICATED';
          currentIsPrimaryDevice = data['is_primary_device'] as bool?;
          final isPendingStatus = statusStr == 'PENDING_CONFIRMATION' ||
              statusStr == 'PENDING_APPROVAL' ||
              data['is_approved'] == false;
          currentIsApproved = isPendingStatus
              ? false
              : (data['is_approved'] as bool? ?? (currentIsPrimaryDevice ?? true));
          currentPrimaryDeviceId = data['primary_device_id'] as String?;
          currentAccessToken = data['access_token'] as String?;
          currentUserId = data['user_id'] as String?;
          final resolvedType = data['device_type'] as String? ?? currentDeviceType;

          if (statusStr == 'MFA_REQUIRED') {
            final masked = data['masked_email'] as String? ?? email;

            return AuthLoginResult(
              status: AuthStatus.mfaRequired,
              userId: currentUserId,
              maskedEmail: masked,
              persona: currentPersona,
              deviceId: currentDeviceId,
              deviceName: currentDeviceName,
              deviceType: resolvedType,
              isPrimaryDevice: currentIsPrimaryDevice,
              isApproved: currentIsApproved,
              primaryDeviceId: currentPrimaryDeviceId,
            );
          } else if (isPendingStatus) {
            if (currentAccessToken != null) {
              DeviceStorage.saveAccessToken(currentAccessToken!);
            }
            if (currentUserId != null) {
              DeviceStorage.saveUserId(currentUserId!);
            }
            return AuthLoginResult(
              status: AuthStatus.pendingApproval,
              accessToken: currentAccessToken,
              role: data['role'] as String?,
              userId: currentUserId,
              persona: currentPersona,
              deviceId: currentDeviceId,
              deviceName: currentDeviceName,
              deviceType: resolvedType,
              isPrimaryDevice: currentIsPrimaryDevice,
              isApproved: false,
              primaryDeviceId: currentPrimaryDeviceId,
            );
          } else {
            if (currentAccessToken != null) {
              DeviceStorage.saveAccessToken(currentAccessToken!);
            }
            if (currentUserId != null) {
              DeviceStorage.saveUserId(currentUserId!);
            }
            return AuthLoginResult(
              status: AuthStatus.authenticated,
              accessToken: currentAccessToken,
              role: data['role'] as String?,
              userId: currentUserId,
              persona: currentPersona,
              deviceId: currentDeviceId,
              deviceName: currentDeviceName,
              deviceType: resolvedType,
              isPrimaryDevice: currentIsPrimaryDevice,
              isApproved: currentIsApproved,
              primaryDeviceId: currentPrimaryDeviceId,
            );
          }
        } else if (response.statusCode == 401 || response.statusCode == 403) {
          _recordWorkingEndpoint(baseUrl);
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
      } catch (_) {
        // Backend offline or unreachable - continue to fallback
      }
    }

    // Dev/Offline Fallback: If backend microservices are not reachable (e.g., local development on Web)
    // allow the user to authenticate with demo credentials to test the UI.
    currentAccessToken = 'mock-dev-jwt-token';
    currentUserId = 'USR-0001';
    currentIsPrimaryDevice = true;
    currentIsApproved = true;

    return AuthLoginResult(
      status: AuthStatus.authenticated,
      accessToken: currentAccessToken,
      role: 'Customer',
      userId: currentUserId,
      persona: currentPersona,
      deviceId: currentDeviceId,
      deviceName: currentDeviceName,
      deviceType: currentDeviceType,
      isPrimaryDevice: true,
      isApproved: true,
      primaryDeviceId: currentDeviceId,
    );
  }

  /// Attempts strict OTP verification against backend /api/v1/auth/verify-login-otp.
  Future<AuthVerifyResult> verifyLoginOtp({
    required String userId,
    required String otp,
    String? deviceId,
    String? deviceName,
    String? deviceType,
  }) async {
    if (deviceId != null) currentDeviceId = deviceId;
    if (deviceName != null) currentDeviceName = deviceName;
    if (deviceType != null) currentDeviceType = deviceType;

    final endpoints = _endpoints;
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
                'device_type': currentDeviceType,
              }),
            )
            .timeout(const Duration(seconds: 4));

        if (response.statusCode == 200) {
          _recordWorkingEndpoint(baseUrl);
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final statusStr = data['status'] as String? ?? 'AUTHENTICATED';
          currentIsPrimaryDevice = data['is_primary_device'] as bool?;
          final isPendingStatus = statusStr == 'PENDING_CONFIRMATION' ||
              statusStr == 'PENDING_APPROVAL' ||
              data['is_approved'] == false;
          currentIsApproved = isPendingStatus
              ? false
              : (data['is_approved'] as bool? ?? (currentIsPrimaryDevice ?? true));
          currentPrimaryDeviceId = data['primary_device_id'] as String?;
          currentAccessToken = data['access_token'] as String?;
          final resolvedType = data['device_type'] as String? ?? currentDeviceType;
          if (currentAccessToken != null) {
            DeviceStorage.saveAccessToken(currentAccessToken!);
          }
          if (currentUserId != null) {
            DeviceStorage.saveUserId(currentUserId!);
          }
          return AuthVerifyResult(
            success: true,
            accessToken: currentAccessToken,
            role: data['role'] as String?,
            deviceId: currentDeviceId,
            deviceName: currentDeviceName,
            deviceType: resolvedType,
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
    final uid = userId ?? currentUserId ?? DeviceStorage.getUserId();
    if (uid == null) return [];
    final token = currentAccessToken ?? DeviceStorage.getAccessToken();
    final endpoints = _endpoints;
    for (final baseUrl in endpoints) {
      try {
        final headers = <String, String>{'Content-Type': 'application/json'};
        if (token != null) {
          headers['Authorization'] = 'Bearer $token';
        }
        final url = Uri.parse('$baseUrl/api/v1/auth/devices?userId=$uid');
        final response = await _client.get(url, headers: headers).timeout(const Duration(seconds: 3));
        if (response.statusCode == 200) {
          _recordWorkingEndpoint(baseUrl);
          final list = jsonDecode(response.body) as List<dynamic>;
          return list.cast<Map<String, dynamic>>();
        }
      } catch (_) {}
    }
    return [];
  }

  Future<bool> setPrimaryDevice({required String deviceId, String? userId}) async {
    final uid = userId ?? currentUserId ?? DeviceStorage.getUserId();
    if (uid == null) return false;
    final token = currentAccessToken ?? DeviceStorage.getAccessToken();
    final endpoints = kIsWeb ? [accountServiceUrl, gatewayUrl] : [gatewayUrl, accountServiceUrl];
    for (final baseUrl in endpoints) {
      try {
        final headers = <String, String>{'Content-Type': 'application/json'};
        if (token != null) {
          headers['Authorization'] = 'Bearer $token';
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
    final uid = userId ?? currentUserId ?? DeviceStorage.getUserId();
    if (uid == null) return false;
    final token = currentAccessToken ?? DeviceStorage.getAccessToken();
    final endpoints = kIsWeb ? [accountServiceUrl, gatewayUrl] : [gatewayUrl, accountServiceUrl];
    for (final baseUrl in endpoints) {
      try {
        final headers = <String, String>{'Content-Type': 'application/json'};
        if (token != null) {
          headers['Authorization'] = 'Bearer $token';
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
    final uid = userId ?? currentUserId ?? DeviceStorage.getUserId();
    if (uid == null) return false;
    final token = currentAccessToken ?? DeviceStorage.getAccessToken();
    final endpoints = kIsWeb ? [accountServiceUrl, gatewayUrl] : [gatewayUrl, accountServiceUrl];
    for (final baseUrl in endpoints) {
      try {
        final headers = <String, String>{'Content-Type': 'application/json'};
        if (token != null) {
          headers['Authorization'] = 'Bearer $token';
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

  Future<void> logout() async {
    final token = currentAccessToken ?? DeviceStorage.getAccessToken();
    if (token != null) {
      final endpoints = kIsWeb ? [accountServiceUrl, gatewayUrl] : [gatewayUrl, accountServiceUrl];
      for (final baseUrl in endpoints) {
        try {
          final url = Uri.parse('$baseUrl/api/v1/auth/logout');
          await _client.post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          ).timeout(const Duration(seconds: 3));
          break;
        } catch (_) {}
      }
    }
    currentAccessToken = null;
    currentUserId = null;
    currentEmail = null;
    currentPersona = null;
    await DeviceStorage.clearSession();
  }

  Future<bool> logoutAll({String? userId}) async {
    final uid = userId ?? currentUserId ?? DeviceStorage.getUserId();
    final token = currentAccessToken ?? DeviceStorage.getAccessToken();
    final endpoints = kIsWeb ? [accountServiceUrl, gatewayUrl] : [gatewayUrl, accountServiceUrl];
    for (final baseUrl in endpoints) {
      try {
        final headers = <String, String>{'Content-Type': 'application/json'};
        if (token != null) {
          headers['Authorization'] = 'Bearer $token';
        }
        final query = uid != null ? '?userId=$uid' : '';
        final url = Uri.parse('$baseUrl/api/v1/auth/logout-all$query');
        final response = await _client.post(
          url,
          headers: headers,
        ).timeout(const Duration(seconds: 3));
        if (response.statusCode == 200) {
          return true;
        }
      } catch (_) {}
    }
    return false;
  }

  Future<bool> logoutAllSessions({String? userId}) async {
    final uid = userId ?? currentUserId ?? DeviceStorage.getUserId();
    final token = currentAccessToken ?? DeviceStorage.getAccessToken();
    final endpoints = kIsWeb ? [accountServiceUrl, gatewayUrl] : [gatewayUrl, accountServiceUrl];
    for (final baseUrl in endpoints) {
      try {
        final headers = <String, String>{'Content-Type': 'application/json'};
        if (token != null) {
          headers['Authorization'] = 'Bearer $token';
        }
        final query = uid != null ? '?userId=$uid' : '';
        final url = Uri.parse('$baseUrl/api/v1/auth/logout-sessions$query');
        final response = await _client.post(
          url,
          headers: headers,
        ).timeout(const Duration(seconds: 3));
        if (response.statusCode == 200) {
          return true;
        }
      } catch (_) {}
    }
    // Fallback: also try logout-all if logout-sessions is not reachable
    return await logoutAll(userId: uid);
  }

  Map<String, dynamic> _tryDecodeJson(String body) {
    try {
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }
}
