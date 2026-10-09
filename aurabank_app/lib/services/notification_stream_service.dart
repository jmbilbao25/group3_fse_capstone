import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../main.dart' show rootNavigatorKey;
import '../screens/auth/login_screen.dart';
import '../widgets/security_dialog.dart';
import 'auth_api_service.dart' show AuthApiService, defaultBackendHost;

class SecurityAlertEvent {
  final String title;
  final String message;
  final String deviceName;
  final String deviceId;
  final String deviceType;
  final String clientIp;
  final String timestamp;
  final String targetDeviceId;
  final String notificationId;
  final String status;
  final bool isThirdDevice;
  final String replacedDeviceId;
  final String replacedDeviceName;

  SecurityAlertEvent({
    required this.title,
    required this.message,
    required this.deviceName,
    this.deviceId = '',
    this.deviceType = 'MOBILE',
    required this.clientIp,
    required this.timestamp,
    required this.targetDeviceId,
    required this.notificationId,
    this.status = 'PENDING_APPROVAL',
    this.isThirdDevice = false,
    this.replacedDeviceId = '',
    this.replacedDeviceName = '',
  });

  bool get isDesktopSession =>
      deviceType.toUpperCase() == 'WEB' ||
      title.toLowerCase().contains('desktop') ||
      message.toLowerCase().contains('desktop') ||
      deviceName.toLowerCase().contains('laptop') ||
      deviceName.toLowerCase().contains('chrome');

  factory SecurityAlertEvent.fromJson(Map<String, dynamic> json) {
    final rawType = json['device_type'] as String?;
    final titleStr = json['title'] as String? ?? 'Security Alert: New Device Login';
    final msgStr = json['message'] as String? ?? 'A new device logged into your account.';
    final devName = json['device_name'] as String? ?? 'Unknown Device';
    final isDesktop = rawType?.toUpperCase() == 'WEB' ||
        titleStr.toLowerCase().contains('desktop') ||
        msgStr.toLowerCase().contains('desktop') ||
        devName.toLowerCase().contains('laptop') ||
        devName.toLowerCase().contains('chrome');

    return SecurityAlertEvent(
      title: titleStr,
      message: msgStr,
      deviceName: devName,
      deviceId: json['device_id'] as String? ?? '',
      deviceType: isDesktop ? 'WEB' : (rawType ?? 'MOBILE'),
      clientIp: json['client_ip'] as String? ?? 'Unknown IP',
      timestamp: json['timestamp'] as String? ?? DateTime.now().toIso8601String(),
      targetDeviceId: json['target_device_id'] as String? ?? '',
      notificationId: json['notification_id'] as String? ?? '',
      status: json['status'] as String? ?? 'PENDING_APPROVAL',
      isThirdDevice: json['is_third_device'] == true ||
          (json['message']?.toString().toLowerCase().contains('3rd device') == true) ||
          (json['message']?.toString().toLowerCase().contains('3rd mobile') == true),
      replacedDeviceId: json['replaced_device_id'] as String? ?? '',
      replacedDeviceName: json['replaced_device_name'] as String? ?? '',
    );
  }
}

class NotificationStreamService {
  static final NotificationStreamService _instance = NotificationStreamService._internal();
  factory NotificationStreamService() => _instance;
  NotificationStreamService._internal();

  final _alertController = StreamController<SecurityAlertEvent>.broadcast();
  Stream<SecurityAlertEvent> get alertStream => _alertController.stream;

  final _deviceApprovalController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get deviceApprovalStream => _deviceApprovalController.stream;

  http.Client? _streamClient;
  http.Client? httpClient;
  Timer? _reconnectTimer;
  Timer? _pollFallbackTimer;
  String? _activeUserId;
  bool _isConnected = false;
  final Set<String> _seenNotificationIds = {};

  bool enablePollingFallback = true;
  bool enableAutoReconnect = true;

  bool get isConnected => _isConnected;

  String get notificationServiceUrl => 'http://$defaultBackendHost:8083';

  http.Client get _effectiveClient => httpClient ?? http.Client();

  DateTime? _sessionConnectedAt;

  /// Connects to real-time notification stream for specified user
  void connect(String userId) {
    if (_activeUserId == userId && _isConnected) return;
    disconnect();
    _activeUserId = userId;
    _sessionConnectedAt = DateTime.now();
    _seedExistingHistory(userId);
    _startSseStream(userId);
    if (enablePollingFallback) {
      _startPollFallback(userId);
    }
  }

  /// Mark all historical notifications as already seen so past alerts never pop up on new login
  Future<void> _seedExistingHistory(String userId) async {
    try {
      final client = _effectiveClient;
      final url = Uri.parse('$notificationServiceUrl/api/v1/notifications/history?userId=$userId');
      final res = await client.get(url).timeout(const Duration(seconds: 3));
      if (res.statusCode == 200) {
        final items = jsonDecode(res.body) as List<dynamic>;
        for (final item in items) {
          if (item is Map<String, dynamic>) {
            final id = item['notificationId'] as String? ?? item['notification_id'] as String? ?? '';
            if (id.isNotEmpty) {
              _seenNotificationIds.add(id);
            }
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _startSseStream(String userId) async {
    _streamClient = _effectiveClient;
    final url = Uri.parse('$notificationServiceUrl/api/v1/notifications/stream?userId=$userId');

    try {
      final request = http.Request('GET', url)
        ..headers['Accept'] = 'text/event-stream'
        ..headers['Cache-Control'] = 'no-cache';

      final response = await _streamClient!.send(request);
      if (response.statusCode == 200) {
        _isConnected = true;
        debugPrint('[NotificationStream] Connected to SSE stream for user $userId');

        String currentEvent = '';
        response.stream
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .listen(
          (line) {
            final trimmed = line.trim();
            if (trimmed.startsWith('event:')) {
              currentEvent = trimmed.substring(6).trim();
            } else if (trimmed.startsWith('data:')) {
              final dataStr = trimmed.substring(5).trim();
              if (dataStr.isNotEmpty) {
                try {
                  final data = jsonDecode(dataStr) as Map<String, dynamic>;
                  final type = data['type'] as String? ?? currentEvent;
                  if (type == 'SECURITY_ALERT') {
                    final alert = SecurityAlertEvent.fromJson(data);
                    _onSecurityAlertReceived(alert);
                  } else if (type == 'DEVICE_APPROVED' || type == 'DEVICE_REVOKED') {
                    _onDeviceApprovalEventReceived(data);
                  }
                } catch (e) {
                  debugPrint('[NotificationStream] Failed to parse alert data: $e');
                }
              }
              currentEvent = '';
            }
          },
          onError: (e) {
            debugPrint('[NotificationStream] SSE stream error: $e');
            _scheduleReconnect();
          },
          onDone: () {
            debugPrint('[NotificationStream] SSE stream closed by server.');
            _scheduleReconnect();
          },
          cancelOnError: true,
        );
      } else {
        _scheduleReconnect();
      }
    } catch (e) {
      debugPrint('[NotificationStream] Error establishing SSE connection: $e');
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    _isConnected = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    if (enableAutoReconnect && _activeUserId != null) {
      _reconnectTimer = Timer(const Duration(seconds: 4), () {
        if (_activeUserId != null) {
          _startSseStream(_activeUserId!);
        }
      });
    }
  }

  /// Auxiliary polling fallback to guarantee notification delivery for NEW alerts only
  void _startPollFallback(String userId) {
    _pollFallbackTimer?.cancel();
    _pollFallbackTimer = null;
    if (!enablePollingFallback) return;
    _pollFallbackTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (_activeUserId == null) return;
      try {
        final client = _effectiveClient;
        final url = Uri.parse('$notificationServiceUrl/api/v1/notifications/history?userId=$userId');
        final res = await client.get(url).timeout(const Duration(seconds: 3));
        if (res.statusCode == 200) {
          final items = jsonDecode(res.body) as List<dynamic>;
          for (final item in items) {
            if (item is Map<String, dynamic>) {
              final type = item['type'] as String?;
              final id = item['notificationId'] as String? ?? item['notification_id'] as String? ?? '';
              final sentAtStr = item['sentAt'] as String? ?? item['createdAt'] as String?;
              final sentAt = sentAtStr != null ? DateTime.tryParse(sentAtStr) : null;

              // Only dispatch if notification occurred after current session connection
              final isAfterSession = _sessionConnectedAt == null ||
                  (sentAt != null && sentAt.isAfter(_sessionConnectedAt!.subtract(const Duration(seconds: 2))));

              if (type == 'SECURITY_ALERT' && id.isNotEmpty && isAfterSession && _seenNotificationIds.add(id)) {
                final message = item['message'] as String? ?? '';
                String extractedDevice = 'Secondary Device';
                final match = RegExp(r'\((.*?)\)').firstMatch(message);
                if (match != null && match.group(1) != null) {
                  extractedDevice = match.group(1)!;
                }
                final alert = SecurityAlertEvent(
                  title: 'Security Alert: New Device Login',
                  message: message,
                  deviceName: extractedDevice,
                  clientIp: 'Remote IP',
                  timestamp: sentAtStr ?? DateTime.now().toIso8601String(),
                  targetDeviceId: '',
                  notificationId: id,
                );
                _onSecurityAlertReceived(alert);
              } else if ((type == 'DEVICE_REVOKED' || type == 'DEVICE_APPROVED') &&
                  id.isNotEmpty &&
                  isAfterSession &&
                  _seenNotificationIds.add(id)) {
                final message = item['message'] as String? ?? '';
                final parts = message.split(': ');
                final targetDevId = parts.length > 1 ? parts[1].trim() : '';
                _onDeviceApprovalEventReceived({
                  'type': type,
                  'user_id': userId,
                  'device_id': targetDevId,
                  'timestamp': sentAtStr ?? DateTime.now().toIso8601String(),
                });
              }
            }
          }
        }
      } catch (_) {}
    });
  }

  void _onSecurityAlertReceived(SecurityAlertEvent alert) {
    final notifId = alert.notificationId;
    if (notifId.isEmpty || _seenNotificationIds.add(notifId)) {
      _alertController.add(alert);
      debugPrint('[NotificationStream] Dispatched SECURITY_ALERT: ${alert.deviceName}');

      // If this device is the primary device, automatically trigger the security modal on the active route
      if (AuthApiService().isPrimaryDevice) {
        final context = rootNavigatorKey.currentContext;
        if (context != null) {
          SecurityApprovalDialog.show(context, alert);
        }
      }
    }
  }

  void _onDeviceApprovalEventReceived(Map<String, dynamic> data) {
    _deviceApprovalController.add(data);
    debugPrint('[NotificationStream] Dispatched ${data['type']} for device: ${data['device_id']}');

    final targetDevId = (data['device_id'] as String? ?? '').toLowerCase();
    final currentDevId = AuthApiService().currentDeviceId.toLowerCase();
    final currentDevName = AuthApiService().currentDeviceName.toLowerCase();
    final isForThisDevice = targetDevId.isEmpty ||
        targetDevId == currentDevId ||
        targetDevId == currentDevName ||
        (currentDevId.isNotEmpty && targetDevId.contains(currentDevId)) ||
        (currentDevName.isNotEmpty && targetDevId.contains(currentDevName)) ||
        (currentDevId.isNotEmpty && currentDevId.contains(targetDevId));

    if (isForThisDevice) {
      final type = data['type'] as String? ?? '';
      final context = rootNavigatorKey.currentContext;
      if (type == 'DEVICE_APPROVED') {
        AuthApiService().currentIsApproved = true;
        if (context != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✓ Device Approved! Your primary device authorized banking transactions.'),
              backgroundColor: Color(0xFF107C41),
              duration: Duration(seconds: 4),
            ),
          );
        }
      } else if (type == 'DEVICE_REVOKED') {
        AuthApiService().currentIsApproved = false;
        AuthApiService().logout();
        disconnect();
        if (context != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Access revoked. You have been logged out of this session.'),
              backgroundColor: Colors.redAccent,
              duration: Duration(seconds: 5),
            ),
          );
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
          );
        }
      }
    }
  }

  /// Manually inject alert (useful for test cases or instant demonstration)
  void injectAlert(SecurityAlertEvent alert) {
    _onSecurityAlertReceived(alert);
  }

  /// Manually inject device approval event (useful for test cases or instant demonstration)
  void injectDeviceApprovalEvent(Map<String, dynamic> data) {
    _onDeviceApprovalEventReceived(data);
  }

  void disconnect() {
    _isConnected = false;
    _activeUserId = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _pollFallbackTimer?.cancel();
    _pollFallbackTimer = null;
    _streamClient?.close();
    _streamClient = null;
  }
}
