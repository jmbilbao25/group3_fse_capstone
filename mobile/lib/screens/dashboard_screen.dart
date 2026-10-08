import 'dart:async';
import 'package:flutter/material.dart';
import '../models/user_persona.dart';
import '../services/auth_api_service.dart';
import '../services/notification_stream_service.dart';
import '../services/security_service.dart';
import '../widgets/brand_logo.dart';
import '../widgets/screen_sharing_warning_sheet.dart';

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
    _isPrimary = authApi.isPrimaryDevice;
    _isApproved = authApi.isDeviceApproved;

    // Listen for approval state changes to update dashboard UI reactively
    _approvalSubscription = NotificationStreamService().deviceApprovalStream.listen((event) {
      if (!mounted) return;
      final targetDevId = event['device_id'] as String? ?? '';
      final isForThisDevice = targetDevId == _currentDeviceId || targetDevId == _currentDeviceName;

      if (isForThisDevice) {
        if (event['type'] == 'DEVICE_APPROVED') {
          setState(() {
            _isApproved = true;
          });
          _approvalPollTimer?.cancel();
          _loadDevices();
        } else if (event['type'] == 'DEVICE_REVOKED') {
          _approvalPollTimer?.cancel();
          _handleLogout();
        }
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
    _approvalSubscription?.cancel();
    _approvalPollTimer?.cancel();
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

  void _showDevicesSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: SingleChildScrollView(
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
                  Container(
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3A4CD6).withAlpha(15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF3A4CD6).withAlpha(40)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.shield_outlined, size: 18, color: Color(0xFF3A4CD6)),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Policy: 1 Web session + 2 Mobiles allowed (1 Primary, 1 Secondary). 1st mobile login is permanently Primary. Desktop logins alert your primary phone.',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
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
                        'Current device: $_currentDeviceName (${_isPrimary ? "Primary Mobile" : "Secondary Mobile"})',
                        style: const TextStyle(fontSize: 13),
                      ),
                    )
                  else
                    ..._registeredDevices.map((d) {
                      final isPrim = d['is_primary'] == true;
                      final isAppr = d['is_approved'] == true;
                      final devId = d['device_id'] as String? ?? '';
                      final type = (d['device_type'] as String? ?? '').toUpperCase();
                      final isWeb = type == 'WEB' || devId.contains('laptop') || devId.contains('web') || devId.contains('chrome');
                      final isCurrent = devId == _currentDeviceId;

                      IconData devIcon = Icons.smartphone_rounded;
                      if (isWeb) {
                        devIcon = Icons.laptop_mac_rounded;
                      } else if (devId.contains('iphone')) {
                        devIcon = Icons.phone_iphone_rounded;
                      } else if (devId.contains('ipad') || devId.contains('tablet') || devId.contains('tab')) {
                        devIcon = Icons.tablet_mac_rounded;
                      }

                      String subtitleText;
                      if (isWeb) {
                        subtitleText = 'ID: $devId • Web Session (1 Allowed • Active)';
                      } else if (isPrim) {
                        subtitleText = 'ID: $devId • Primary Mobile (Permanent Authenticator)';
                      } else {
                        subtitleText = 'ID: $devId • ${isAppr ? "Secondary Mobile (Approved)" : "Secondary Mobile (Pending Approval)"}';
                      }

                      return ListTile(
                        leading: Icon(
                          devIcon,
                          color: isWeb ? const Color(0xFF3A4CD6) : (isPrim ? const Color(0xFF107C41) : Colors.orange),
                        ),
                        title: Text('${d['device_name'] ?? (isWeb ? 'Desktop Session' : 'Mobile Device')} ${isCurrent ? "(This Device)" : ""}'),
                        subtitle: Text(subtitleText),
                        trailing: isPrim
                            ? const Chip(
                                avatar: Icon(Icons.lock_rounded, size: 12, color: Colors.white),
                                label: Text('PRIMARY MOBILE', style: TextStyle(fontSize: 10, color: Colors.white)),
                                backgroundColor: Color(0xFF107C41),
                              )
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isWeb)
                                    const Padding(
                                      padding: EdgeInsets.only(right: 6),
                                      child: Chip(
                                        avatar: Icon(Icons.laptop_chromebook_rounded, size: 12, color: Colors.white),
                                        label: Text('WEB (1 ALLOWED)', style: TextStyle(fontSize: 10, color: Colors.white)),
                                        backgroundColor: Color(0xFF3A4CD6),
                                      ),
                                    ),
                                  if (!isWeb && _isPrimary && !isAppr)
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
                                  if (_isPrimary && !isCurrent)
                                    OutlinedButton(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.redAccent,
                                        side: const BorderSide(color: Colors.redAccent),
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                                      ),
                                      onPressed: () async {
                                        final confirmed = await showDialog<bool>(
                                          context: context,
                                          builder: (c) => AlertDialog(
                                            title: Text(isWeb ? 'Terminate Desktop Session?' : 'Deregister Device?'),
                                            content: Text('Are you sure you want to deregister ${d['device_name'] ?? "this device"}? It will lose access.'),
                                            actions: [
                                              TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                                              FilledButton(
                                                style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
                                                onPressed: () => Navigator.pop(c, true),
                                                child: Text(isWeb ? 'Log out' : 'Deregister'),
                                              ),
                                            ],
                                          ),
                                        );
                                        if (confirmed == true) {
                                          await AuthApiService().revokeDevice(deviceId: devId);
                                          await _loadDevices();
                                          setSheetState(() {});
                                          setState(() {});
                                        }
                                      },
                                      child: Text(isWeb ? 'Log out' : 'Deregister', style: const TextStyle(fontSize: 11)),
                                    ),
                                ],
                              ),
                      );
                    }),
                  if (_isPrimary)
                    Column(
                      children: [
                        const Divider(),
                        Wrap(
                          spacing: 8,
                          alignment: WrapAlignment.center,
                          children: [
                            TextButton.icon(
                              key: const Key('simulate_screen_sharing_btn'),
                              icon: const Icon(Icons.screen_share_rounded, size: 16, color: Color(0xFFD97706)),
                              label: const Text('Simulate Screen Sharing Alert', style: TextStyle(fontSize: 11, color: Color(0xFFD97706))),
                              onPressed: () {
                                Navigator.of(ctx).pop();
                                _triggerScreenSharingAlert();
                              },
                            ),
                            TextButton.icon(
                              icon: const Icon(Icons.laptop_mac_rounded, size: 16, color: Color(0xFF3A4CD6)),
                              label: const Text('Simulate Desktop Alert', style: TextStyle(fontSize: 11, color: Color(0xFF3A4CD6))),
                              onPressed: () {
                                Navigator.of(ctx).pop();
                                _triggerDesktopSessionAlert();
                              },
                            ),
                            TextButton.icon(
                              icon: const Icon(Icons.notification_important_rounded, size: 16),
                              label: const Text('Simulate 2nd Mobile Alert', style: TextStyle(fontSize: 11)),
                              onPressed: () {
                                Navigator.of(ctx).pop();
                                _triggerTestAlert();
                              },
                            ),
                            TextButton.icon(
                              icon: const Icon(Icons.swap_horizontal_circle_outlined, size: 16, color: Colors.orange),
                              label: const Text('Simulate 3rd Mobile Alert', style: TextStyle(fontSize: 11, color: Colors.orange)),
                              onPressed: () {
                                Navigator.of(ctx).pop();
                                _triggerThirdDeviceAlert();
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

  void _triggerDesktopSessionAlert() {
    NotificationStreamService().injectAlert(
      SecurityAlertEvent(
        title: 'Security Alert: Desktop Session Login',
        message: 'A desktop/web session (MacBook Pro Chrome) just logged into your account from IP 192.168.1.102. (Policy: 1 Web session permitted).',
        deviceName: 'MacBook Pro (Chrome)',
        deviceId: 'dev-laptop-web',
        deviceType: 'WEB',
        clientIp: '192.168.1.102',
        timestamp: DateTime.now().toIso8601String(),
        targetDeviceId: _currentDeviceId,
        notificationId: 'TEST-DESK-${DateTime.now().millisecondsSinceEpoch}',
        status: 'ACTIVE_SESSION',
      ),
    );
  }

  void _triggerTestAlert() {
    NotificationStreamService().injectAlert(
      SecurityAlertEvent(
        title: 'Security Alert: New Mobile Device Login',
        message: 'A new mobile device (iPad Air) just logged in from IP 192.168.1.55.',
        deviceName: 'iPad Air (Secondary)',
        clientIp: '192.168.1.55',
        timestamp: DateTime.now().toIso8601String(),
        targetDeviceId: _currentDeviceId,
        notificationId: 'TEST-${DateTime.now().millisecondsSinceEpoch}',
      ),
    );
  }

  void _triggerThirdDeviceAlert() {
    NotificationStreamService().injectAlert(
      SecurityAlertEvent(
        title: '3rd Mobile Device Login Request',
        message: 'A 3rd mobile device (Samsung Galaxy Tab) is requesting access. Since AuraBank only allows 2 mobiles (1 Primary, 1 Secondary), confirming will deregister iPad Air.',
        deviceName: 'Samsung Galaxy Tab (3rd Device)',
        deviceId: 'dev-galaxy-third',
        clientIp: '192.168.1.120',
        timestamp: DateTime.now().toIso8601String(),
        targetDeviceId: _currentDeviceId,
        notificationId: 'TEST-3RD-${DateTime.now().millisecondsSinceEpoch}',
        isThirdDevice: true,
        replacedDeviceId: 'dev-ipad-secondary',
        replacedDeviceName: 'iPad Air (Secondary)',
      ),
    );
  }

  void _triggerScreenSharingAlert() async {
    final action = await ScreenSharingWarningSheet.show(context);
    if (!mounted || action == null) return;
    switch (action) {
      case ScreenSharingUserAction.cancelTransaction:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✕ Transaction Cancelled safely. AuraBank protected your account against screen viewing.'),
            backgroundColor: Color(0xFFB91C1C),
            duration: Duration(seconds: 4),
          ),
        );
        break;
      case ScreenSharingUserAction.pauseFor10Minutes:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⏸ Transaction paused for 10 minutes. Transfers placed on temporary security hold.'),
            backgroundColor: Color(0xFFD97706),
            duration: Duration(seconds: 4),
          ),
        );
        break;
      case ScreenSharingUserAction.continueAnyway:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Screen sharing acknowledged. Transaction proceeding with enhanced monitoring.'),
            backgroundColor: Color(0xFF107C41),
            duration: Duration(seconds: 3),
          ),
        );
        break;
    }
  }

  void _handleTransferTap() {
    _executeProtectedAction(() {
      _showTransferFlow();
    }, actionName: 'Fund Transfer');
  }

  void _showTransferFlow() async {
    // 1. If screen sharing is actively running, prompt immediately
    final isSharing = await SecurityService.isScreenSharingActive();
    if (isSharing && mounted) {
      final action = await ScreenSharingWarningSheet.show(context);
      if (!mounted || action == null) return;
      if (action == ScreenSharingUserAction.cancelTransaction) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✕ Transfer Cancelled safely. Screen sharing protection activated.'),
            backgroundColor: Color(0xFFB91C1C),
            duration: Duration(seconds: 4),
          ),
        );
        return;
      } else if (action == ScreenSharingUserAction.pauseFor10Minutes) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⏸ Transfer paused for 10 minutes. Account placed on temporary security hold.'),
            backgroundColor: Color(0xFFD97706),
            duration: Duration(seconds: 4),
          ),
        );
        return;
      }
    }

    if (!mounted) return;

    bool simulateScreenShareInModal = false;
    final amountController = TextEditingController(text: '10,000.00');
    final recipientController = TextEditingController(text: 'Maria Santos (ACC-883921)');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.send_rounded, color: Color(0xFF3A4CD6), size: 22),
                          SizedBox(width: 8),
                          Text(
                            'Send Money / Transfer',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: recipientController,
                    decoration: const InputDecoration(
                      labelText: 'Recipient',
                      prefixIcon: Icon(Icons.person_outline_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Amount (PHP)',
                      prefixText: '₱ ',
                      prefixIcon: Icon(Icons.attach_money_rounded),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    decoration: BoxDecoration(
                      color: simulateScreenShareInModal
                          ? Colors.amber.withAlpha(25)
                          : (isDark ? const Color(0xFF232730) : const Color(0xFFF8FAFC)),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: simulateScreenShareInModal
                            ? Colors.amber
                            : (isDark ? const Color(0xFF333A48) : const Color(0xFFE2E8F0)),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: SwitchListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      secondary: Icon(
                        Icons.screen_share_rounded,
                        color: simulateScreenShareInModal ? const Color(0xFFD97706) : Colors.grey,
                      ),
                      title: const Text(
                        'Simulate Screen Sharing Active',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                      ),
                      subtitle: const Text(
                        'Tests remote access defense popup on transfer submission',
                        style: TextStyle(fontSize: 11),
                      ),
                      value: simulateScreenShareInModal,
                      onChanged: (val) {
                        setSheetState(() {
                          simulateScreenShareInModal = val;
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    key: const Key('submit_transfer_btn'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF32007D),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () async {
                      Navigator.of(ctx).pop();
                      final messenger = ScaffoldMessenger.of(context);
                      final transferAmt = amountController.text;
                      if (simulateScreenShareInModal) {
                        final action = await ScreenSharingWarningSheet.show(context);
                        if (!mounted || action == null) return;
                        if (action == ScreenSharingUserAction.cancelTransaction) {
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text('✕ Transfer Cancelled. Screen sharing threat blocked.'),
                              backgroundColor: Color(0xFFB91C1C),
                              duration: Duration(seconds: 4),
                            ),
                          );
                          return;
                        } else if (action == ScreenSharingUserAction.pauseFor10Minutes) {
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text('⏸ Transfer paused for 10 minutes. Placed on safety hold.'),
                              backgroundColor: Color(0xFFD97706),
                              duration: Duration(seconds: 4),
                            ),
                          );
                          return;
                        }
                      }
                      if (!mounted) return;
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text('✓ Transfer of ₱$transferAmt sent successfully!'),
                          backgroundColor: const Color(0xFF107C41),
                          duration: const Duration(seconds: 3),
                        ),
                      );
                    },
                    child: const Text('Confirm Transfer', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                ],
              ),
            );
          },
        );
      },
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
                      onTap: _handleTransferTap,
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
