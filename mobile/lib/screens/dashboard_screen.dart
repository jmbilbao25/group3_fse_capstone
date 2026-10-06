import 'dart:async';
import 'package:flutter/material.dart';
import '../models/user_persona.dart';
import '../services/auth_api_service.dart';
import '../services/notification_stream_service.dart';
import '../widgets/brand_logo.dart';

class DashboardScreen extends StatefulWidget {
  final UserPersona user;
  final VoidCallback onLogout;

  const DashboardScreen({
    super.key,
    required this.user,
    required this.onLogout,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  StreamSubscription<SecurityAlertEvent>? _alertSubscription;
  StreamSubscription<Map<String, dynamic>>? _approvalSubscription;
  Timer? _approvalPollTimer;
  bool _isPrimary = true;
  bool _isApproved = true;
  String _currentDeviceName = 'iPhone 15 Pro';
  String _currentDeviceId = 'dev-iphone-primary';
  List<Map<String, dynamic>> _registeredDevices = [];
  bool _isLoadingDevices = false;

  @override
  void initState() {
    super.initState();
    final authApi = AuthApiService();
    _currentDeviceId = authApi.currentDeviceId;
    _currentDeviceName = authApi.currentDeviceName;
    _isPrimary = authApi.currentIsPrimaryDevice ?? true;
    _isApproved = authApi.currentIsApproved ?? (_isPrimary == true);

    final userId = authApi.currentUserId ?? 'USR-100001';
    NotificationStreamService().connect(userId);

    // CRITICAL: Only the PRIMARY device displays the Security Push Alert modal!
    _alertSubscription = NotificationStreamService().alertStream.listen((alert) {
      if (mounted && _isPrimary) {
        _showSecurityAlertDialog(alert);
      }
    });

    // Listen for real-time approval/revocation events from primary device
    _approvalSubscription = NotificationStreamService().deviceApprovalStream.listen((event) {
      if (!mounted) return;
      final targetDevId = event['device_id'] as String? ?? '';
      final isForThisDevice = targetDevId == _currentDeviceId || targetDevId == _currentDeviceName;

      if (event['type'] == 'DEVICE_APPROVED' && isForThisDevice) {
        setState(() {
          _isApproved = true;
        });
        _approvalPollTimer?.cancel();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Device Approved! Your primary device has authorized banking transactions.'),
            backgroundColor: Color(0xFF107C41),
            duration: Duration(seconds: 4),
          ),
        );
      } else if (event['type'] == 'DEVICE_REVOKED' && isForThisDevice) {
        _approvalPollTimer?.cancel();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Access Revoked: Your session was terminated by your primary device.'),
            backgroundColor: Colors.redAccent,
            duration: Duration(seconds: 4),
          ),
        );
        _handleLogout();
      }
    });

    _loadDevices();

    // If secondary and not yet approved, poll every 3 seconds to catch approval
    if (!_isPrimary && !_isApproved) {
      _approvalPollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
        if (!_isApproved) {
          _loadDevices();
        } else {
          _approvalPollTimer?.cancel();
        }
      });
    }
  }

  @override
  void dispose() {
    _alertSubscription?.cancel();
    _approvalSubscription?.cancel();
    _approvalPollTimer?.cancel();
    NotificationStreamService().disconnect();
    super.dispose();
  }

  Future<void> _loadDevices() async {
    setState(() => _isLoadingDevices = true);
    final devices = await AuthApiService().getRegisteredDevices();
    if (mounted) {
      setState(() {
        _registeredDevices = devices;
        _isLoadingDevices = false;
        if (devices.isNotEmpty) {
          final current = devices.firstWhere(
            (d) => d['device_id'] == _currentDeviceId,
            orElse: () => <String, dynamic>{},
          );
          if (current.isNotEmpty) {
            if (current.containsKey('is_primary')) {
              _isPrimary = current['is_primary'] == true;
            }
            if (current.containsKey('is_approved')) {
              final backendApproved = current['is_approved'] == true;
              if (backendApproved && !_isApproved) {
                _isApproved = true;
                _approvalPollTimer?.cancel();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✓ Device Approved! Banking transactions are now enabled.'),
                    backgroundColor: Color(0xFF107C41),
                    duration: Duration(seconds: 4),
                  ),
                );
              } else if (_isPrimary) {
                _isApproved = true;
              }
            }
          }
        }
      });
    }
  }

  void _handleLogout() {
    _approvalPollTimer?.cancel();
    NotificationStreamService().disconnect();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Logged out successfully'),
        duration: Duration(seconds: 2),
      ),
    );
    widget.onLogout();
  }

  void _executeProtectedAction(VoidCallback action, {String actionName = 'This action'}) {
    if (!_isPrimary && !_isApproved) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          icon: const Icon(Icons.lock_rounded, color: Color(0xFFD97706), size: 40),
          title: const Text('Banking Transactions Locked', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'This secondary device is awaiting authorization from your primary device.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withAlpha(25),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber.withAlpha(80)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.shield_outlined, color: Color(0xFFD97706), size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'To prevent unauthorized transfers, please tap "Approve Access" on your primary device first.',
                        style: TextStyle(fontSize: 12, color: Colors.amber[900]),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF3A4CD6)),
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Understood'),
            ),
          ],
        ),
      );
      return;
    }
    action();
  }

  void _showSecurityAlertDialog(SecurityAlertEvent alert) {
    if (!_isPrimary) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: isDark ? const Color(0xFF1E222B) : Colors.white,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.withAlpha(40),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.amber,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Security Push Alert',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'A new device just logged into your AuraBank account from another location.',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.grey[300] : Colors.grey[800],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF282E3A) : const Color(0xFFF3F5F9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? const Color(0xFF384050) : const Color(0xFFE2E6EF),
                  ),
                ),
                child: Column(
                  children: [
                    _buildAlertDetailRow('Device', alert.deviceName, Icons.phone_android_rounded),
                    const SizedBox(height: 8),
                    _buildAlertDetailRow('IP Address', alert.clientIp, Icons.wifi_rounded),
                    const SizedBox(height: 8),
                    _buildAlertDetailRow('Status', 'Pending Your Approval', Icons.lock_clock_rounded),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Banking transactions are currently locked on this secondary device until you approve it.',
                style: TextStyle(fontSize: 12, color: Color(0xFFD97706), fontWeight: FontWeight.w500),
              ),
            ],
          ),
          actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          actions: [
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.redAccent,
                side: const BorderSide(color: Colors.redAccent),
              ),
              onPressed: () async {
                Navigator.of(ctx).pop();
                final devId = alert.deviceId.isNotEmpty ? alert.deviceId : alert.deviceName;
                await AuthApiService().revokeDevice(deviceId: devId);
                await _loadDevices();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Remote session revoked. Access blocked.'),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }
              },
              child: const Text('Revoke Access'),
            ),
            FilledButton.icon(
              icon: const Icon(Icons.check_circle_rounded, size: 16),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF107C41),
              ),
              onPressed: () async {
                Navigator.of(ctx).pop();
                final devId = alert.deviceId.isNotEmpty ? alert.deviceId : alert.deviceName;
                await AuthApiService().approveDevice(deviceId: devId);
                await _loadDevices();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Approved! ${alert.deviceName} authorized for transactions.'),
                      backgroundColor: const Color(0xFF107C41),
                    ),
                  );
                }
              },
              label: const Text('Approve Access'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAlertDetailRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF3A4CD6)),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 12),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  void _showDevicesSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.devices_rounded, color: Color(0xFF3A4CD6)),
                      const SizedBox(width: 10),
                      const Text(
                        'Registered Account Devices',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_isLoadingDevices)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (_registeredDevices.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        'Current device: $_currentDeviceName (${_isPrimary ? "Primary" : "Secondary"})',
                        style: const TextStyle(fontSize: 13),
                      ),
                    )
                  else
                    ..._registeredDevices.map((d) {
                      final isPrim = d['is_primary'] == true;
                      final isAppr = d['is_approved'] == true;
                      final devId = d['device_id'] as String? ?? '';
                      final isCurrent = devId == _currentDeviceId;
                      return ListTile(
                        leading: Icon(
                          devId.contains('iphone') ? Icons.phone_iphone_rounded : Icons.tablet_mac_rounded,
                          color: const Color(0xFF3A4CD6),
                        ),
                        title: Text('${d['device_name'] ?? 'Device'} ${isCurrent ? "(This Device)" : ""}'),
                        subtitle: Text(
                          'ID: $devId • ${isPrim ? "Primary Device" : (isAppr ? "Secondary (Approved)" : "Secondary (Pending Approval)")}',
                        ),
                        trailing: isPrim
                            ? const Chip(
                                label: Text('PRIMARY', style: TextStyle(fontSize: 10, color: Colors.white)),
                                backgroundColor: Color(0xFF107C41),
                              )
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (_isPrimary && !isAppr)
                                    Padding(
                                      padding: const EdgeInsets.only(right: 6),
                                      child: FilledButton.tonal(
                                        style: FilledButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                                          backgroundColor: const Color(0xFFE8F7F0),
                                        ),
                                        onPressed: () async {
                                          await AuthApiService().approveDevice(deviceId: devId);
                                          await _loadDevices();
                                          setSheetState(() {});
                                          setState(() {});
                                        },
                                        child: const Text('Approve', style: TextStyle(fontSize: 11, color: Color(0xFF107C41))),
                                      ),
                                    ),
                                  OutlinedButton(
                                    onPressed: () async {
                                      final ok = await AuthApiService().setPrimaryDevice(deviceId: devId);
                                      if (ok) {
                                        await _loadDevices();
                                        setSheetState(() {});
                                        setState(() {});
                                      }
                                    },
                                    child: const Text('Make Primary', style: TextStyle(fontSize: 11)),
                                  ),
                                ],
                              ),
                      );
                    }),
                  if (_isPrimary)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: TextButton.icon(
                          icon: const Icon(Icons.notification_important_rounded, size: 16),
                          label: const Text('Simulate Secondary Alert (Test)', style: TextStyle(fontSize: 12)),
                          onPressed: () {
                            Navigator.of(ctx).pop();
                            _triggerTestAlert();
                          },
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _triggerTestAlert() {
    NotificationStreamService().injectAlert(
      SecurityAlertEvent(
        title: 'Security Alert: New Device Login',
        message: 'A new device (iPad Air) just logged in from IP 192.168.1.55.',
        deviceName: 'iPad Air (Secondary)',
        clientIp: '192.168.1.55',
        timestamp: DateTime.now().toIso8601String(),
        targetDeviceId: _currentDeviceId,
        notificationId: 'TEST-${DateTime.now().millisecondsSinceEpoch}',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const BrandMark(size: 28),
            const SizedBox(width: 10),
            Text(
              'AuraBank',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Devices',
            icon: const Icon(Icons.devices_rounded),
            onPressed: _showDevicesSheet,
          ),
          IconButton(
            tooltip: 'Log out',
            icon: const Icon(Icons.logout_rounded),
            onPressed: _handleLogout,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Device Trust Status Card
                Card(
                  elevation: 0,
                  color: _isPrimary
                      ? (isDark ? const Color(0xFF142921) : const Color(0xFFE8F7F0))
                      : (_isApproved
                          ? (isDark ? const Color(0xFF142921) : const Color(0xFFE8F7F0))
                          : (isDark ? const Color(0xFF332005) : const Color(0xFFFFF7E6))),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: _isPrimary
                          ? (isDark ? const Color(0xFF1F4D3C) : const Color(0xFFBCE7D3))
                          : (_isApproved
                              ? (isDark ? const Color(0xFF1F4D3C) : const Color(0xFFBCE7D3))
                              : const Color(0xFFF59E0B)),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Icon(
                          _isPrimary
                              ? Icons.verified_user_rounded
                              : (_isApproved ? Icons.verified_user_rounded : Icons.lock_clock_rounded),
                          color: _isPrimary
                              ? const Color(0xFF107C41)
                              : (_isApproved ? const Color(0xFF107C41) : const Color(0xFFD97706)),
                          size: 26,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _isPrimary
                                    ? 'Primary Device Protected'
                                    : (_isApproved ? 'Secondary Device Authorized' : 'Awaiting Primary Device Approval'),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: _isPrimary
                                      ? const Color(0xFF107C41)
                                      : (_isApproved ? const Color(0xFF107C41) : const Color(0xFFD97706)),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _isPrimary
                                    ? '$_currentDeviceName is receiving real-time security alerts when secondary devices log in.'
                                    : (_isApproved
                                        ? '$_currentDeviceName is authorized. Banking transactions are enabled.'
                                        : '$_currentDeviceName is restricted. Banking transactions and transfers are locked until approved on your primary device.'),
                                style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // User welcome card
                Card(
                  elevation: 0,
                  color: isDark ? const Color(0xFF1E2229) : const Color(0xFFEFF3FF),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: isDark ? const Color(0xFF2C323D) : const Color(0xFFC3D0FC),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: const Color(0xFF3A4CD6),
                          child: Text(
                            widget.user.name.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.user.name,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${widget.user.role} • ${widget.user.email}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: isDark ? Colors.grey[400] : const Color(0xFF545A63),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF3A4CD6).withAlpha(30),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'Active',
                            style: TextStyle(
                              color: Color(0xFF3A4CD6),
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Account balance card
                Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF233194), Color(0xFF3A4CD6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF3A4CD6).withAlpha(80),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Expanded(
                            child: Text(
                              'Primary Savings Account',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(40),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              widget.user.accountId,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontFamily: 'monospace',
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Available Balance',
                        style: TextStyle(
                          color: Colors.white60,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '₱${widget.user.balance.toStringAsFixed(2).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.5,
                            ),
                          ),
                          if (!_isPrimary && !_isApproved)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.amber.withAlpha(60),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.amberAccent.withAlpha(140)),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.lock_rounded, size: 11, color: Colors.amberAccent),
                                  SizedBox(width: 4),
                                  Text(
                                    'RESTRICTED',
                                    style: TextStyle(
                                      color: Colors.amberAccent,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          const Icon(Icons.shield_outlined, color: Colors.white70, size: 16),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              !_isPrimary && !_isApproved
                                  ? '🔒 Financial operations locked until approved by primary device'
                                  : 'Protected by AuraBank Perimeter Defense',
                              style: TextStyle(
                                color: Colors.white.withAlpha(200),
                                fontSize: 11,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Quick actions
                Text(
                  'Quick Actions',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildActionItem(
                      context,
                      Icons.devices_rounded,
                      'Devices',
                      onTap: _showDevicesSheet,
                    ),
                    _buildActionItem(
                      context,
                      Icons.send_rounded,
                      'Transfer',
                      onTap: () => _executeProtectedAction(() {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Fund transfer initiated (Active)'), duration: Duration(seconds: 1)),
                        );
                      }, actionName: 'Fund Transfer'),
                    ),
                    _buildActionItem(
                      context,
                      Icons.credit_card_rounded,
                      'Cards',
                      onTap: () => _executeProtectedAction(() {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Cards feature (Active)'), duration: Duration(seconds: 1)),
                        );
                      }, actionName: 'Card Management'),
                    ),
                    _buildActionItem(
                      context,
                      Icons.history_rounded,
                      'History',
                      onTap: () => _executeProtectedAction(() {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Transaction History (Active)'), duration: Duration(seconds: 1)),
                        );
                      }, actionName: 'Transaction History'),
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // Return to login test button
                OutlinedButton.icon(
                  onPressed: _handleLogout,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.arrow_back_rounded, size: 18),
                  label: const Text('Back to Login Screen'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionItem(
    BuildContext context,
    IconData icon,
    String label, {
    VoidCallback? onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap ??
          () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('$label feature (Mock Preview)'),
                duration: const Duration(seconds: 1),
              ),
            );
          },
      borderRadius: BorderRadius.circular(16),
      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E2229) : const Color(0xFFF1F3F6),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? const Color(0xFF2C323D) : const Color(0xFFE4E6EA),
              ),
            ),
            child: Icon(icon, color: const Color(0xFF3A4CD6), size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
