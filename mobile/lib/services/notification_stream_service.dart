import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;
import 'auth_api_service.dart' show defaultBackendHost;

class SecurityAlertEvent {
  final String title;
  final String message;
  final String deviceName;
  final String deviceId;
  final String clientIp;
  final String timestamp;
  final String targetDeviceId;
  final String notificationId;
  final String status;

  SecurityAlertEvent({
    required this.title,
    required this.message,
    required this.deviceName,
    this.deviceId = '',
    required this.clientIp,
    required this.timestamp,
    required this.targetDeviceId,
    required this.notificationId,
    this.status = 'PENDING_APPROVAL',
  });

  factory SecurityAlertEvent.fromJson(Map<String, dynamic> json) {
    return SecurityAlertEvent(
      title: json['title'] as String? ?? 'Security Alert: New Device Login',
      message: json['message'] as String? ?? 'A new device logged into your account.',
      deviceName: json['device_name'] as String? ?? 'Unknown Device',
      deviceId: json['device_id'] as String? ?? '',
      clientIp: json['client_ip'] as String? ?? 'Unknown IP',
      timestamp: json['timestamp'] as String? ?? DateTime.now().toIso8601String(),
      targetDeviceId: json['target_device_id'] as String? ?? '',
      notificationId: json['notification_id'] as String? ?? '',
      status: json['status'] as String? ?? 'PENDING_APPROVAL',
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
                    final notifId = data['notification_id'] as String? ?? '';
                    if (notifId.isEmpty || _seenNotificationIds.add(notifId)) {
                      final alert = SecurityAlertEvent.fromJson(data);
                      _alertController.add(alert);
                      debugPrint('[NotificationStream] Dispatched SECURITY_ALERT: ${alert.deviceName}');
                    }
                  } else if (type == 'DEVICE_APPROVED' || type == 'DEVICE_REVOKED') {
                    _deviceApprovalController.add(data);
                    debugPrint('[NotificationStream] Dispatched $type for device: ${data['device_id']}');
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
                _alertController.add(alert);
              }
            }
          }
        }
      } catch (_) {}
    });
  }

  /// Manually inject alert (useful for test cases or instant demonstration)
  void injectAlert(SecurityAlertEvent alert) {
    _seenNotificationIds.add(alert.notificationId);
    _alertController.add(alert);
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
