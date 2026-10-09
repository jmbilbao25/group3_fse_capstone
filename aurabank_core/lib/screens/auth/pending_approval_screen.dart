import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/user_persona.dart';
import '../../services/auth_api_service.dart';
import '../../services/notification_stream_service.dart';
import '../../widgets/aura_logo.dart';
import '../../widgets/security_dialog.dart';

class PendingApprovalScreen extends StatefulWidget {
  final UserPersona user;
  final VoidCallback onApproved;
  final VoidCallback onCancel;
  final VoidCallback? onToggleTheme;
  final bool isDarkMode;

  const PendingApprovalScreen({
    super.key,
    required this.user,
    required this.onApproved,
    required this.onCancel,
    this.onToggleTheme,
    this.isDarkMode = false,
  });

  @override
  State<PendingApprovalScreen> createState() => _PendingApprovalScreenState();
}

class _PendingApprovalScreenState extends State<PendingApprovalScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  StreamSubscription<Map<String, dynamic>>? _approvalSubscription;
  Timer? _pollingTimer;

  bool _isChecking = false;
  bool _isApproved = false;
  String _statusMessage = 'Awaiting authorization from your Primary Device...';

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOut),
    );

    // Ensure notification stream is active for this user
    final uid = AuthApiService().currentUserId ?? 'USR-100001';
    NotificationStreamService().connect(uid);

    final currentDevId = AuthApiService().currentDeviceId;
    final currentDevName = AuthApiService().currentDeviceName;

    // 1. Real-time SSE stream listener
    _approvalSubscription =
        NotificationStreamService().deviceApprovalStream.listen((event) {
      if (!mounted) return;
      final targetDevId = (event['device_id'] as String? ?? '').toLowerCase().trim();
      final isForThisDevice = targetDevId.isNotEmpty &&
          (targetDevId == currentDevId.toLowerCase() ||
           targetDevId == currentDevName.toLowerCase());

      if (isForThisDevice) {
        if (event['type'] == 'DEVICE_APPROVED') {
          _handleApprovalSuccess();
        } else if (event['type'] == 'DEVICE_REVOKED') {
          _handleRevoked();
        }
      }
    });

    // 2. Periodic background poll every 3 seconds as resilient fallback
    if (NotificationStreamService().enablePollingFallback) {
      _pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) {
        _pollBackendStatus();
      });
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _approvalSubscription?.cancel();
    _pollingTimer?.cancel();
    super.dispose();
  }

  void _handleApprovalSuccess() {
    if (_isApproved) return;
    _pollingTimer?.cancel();
    _approvalSubscription?.cancel();

    setState(() {
      _isApproved = true;
      _statusMessage = '✓ Access Confirmed! Unlocking account...';
    });

    AuthApiService().currentIsApproved = true;

    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        widget.onApproved();
      }
    });
  }

  void _handleRevoked() {
    _pollingTimer?.cancel();
    _approvalSubscription?.cancel();

    if (mounted) {
      DeviceRevokedWarningDialog.show(
        context,
        deviceName: AuthApiService().currentDeviceName,
        reason: 'revoked',
        onDismissed: () {
          widget.onCancel();
        },
      );
    } else {
      widget.onCancel();
    }
  }

  Future<void> _pollBackendStatus() async {
    try {
      final devices = await AuthApiService().getRegisteredDevices();
      if (!mounted) return;

      final currentDevId = AuthApiService().currentDeviceId.toLowerCase();
      final currentDevName = AuthApiService().currentDeviceName.toLowerCase();

      final current = devices.firstWhere(
        (d) {
          final id = (d['device_id'] as String? ?? '').toLowerCase();
          final name = (d['device_name'] as String? ?? '').toLowerCase();
          return id == currentDevId ||
              name == currentDevName ||
              (currentDevId.isNotEmpty && id.contains(currentDevId)) ||
              (currentDevName.isNotEmpty && name.contains(currentDevName)) ||
              (currentDevId.isNotEmpty && currentDevId.contains(id));
        },
        orElse: () => <String, dynamic>{},
      );

      if (current.isNotEmpty && current['is_approved'] == true) {
        _handleApprovalSuccess();
      } else if (devices.isNotEmpty && (current.isEmpty || current['status'] == 'REVOKED')) {
        _handleRevoked();
      }
    } catch (_) {}
  }

  Future<void> _manualCheckStatus() async {
    setState(() => _isChecking = true);
    await _pollBackendStatus();
    if (!mounted) return;
    setState(() => _isChecking = false);

    if (!_isApproved) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Still pending approval. Please confirm on your primary mobile device.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final devName = AuthApiService().currentDeviceName;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Sign Out',
          onPressed: widget.onCancel,
        ),
        actions: [
          if (widget.onToggleTheme != null)
            IconButton(
              tooltip: widget.isDarkMode
                  ? 'Switch to Light mode'
                  : 'Switch to Dark mode',
              icon: Icon(
                widget.isDarkMode
                    ? Icons.light_mode_outlined
                    : Icons.dark_mode_outlined,
              ),
              onPressed: widget.onToggleTheme,
            ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const AuraWordmark(size: 44),
                  const SizedBox(height: 28),

                  // Animated Pending Icon
                  Center(
                    child: ScaleTransition(
                      scale: _pulseAnimation,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: _isApproved
                              ? const Color(0xFF107C41).withAlpha(30)
                              : const Color(0xFFD97706).withAlpha(28),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _isApproved
                                ? const Color(0xFF107C41).withAlpha(120)
                                : const Color(0xFFD97706).withAlpha(120),
                            width: 2.5,
                          ),
                        ),
                        child: Icon(
                          _isApproved
                              ? Icons.verified_rounded
                              : Icons.hourglass_top_rounded,
                          size: 40,
                          color: _isApproved
                              ? const Color(0xFF107C41)
                              : const Color(0xFFD97706),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Title & Subtitle
                  Text(
                    _isApproved
                        ? 'Access Confirmed!'
                        : 'Account Access Pending',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isApproved
                        ? 'Device authorization complete. Entering dashboard...'
                        : 'Access to this account is pending confirmation from your Primary Device.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Device Details Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF1B2028)
                          : const Color(0xFFF7F8FA),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFF2C323D)
                            : const Color(0xFFE2E6EF),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.devices_rounded,
                              size: 18,
                              color: isDark
                                  ? const Color(0xFF6B7FFF)
                                  : const Color(0xFF2F78A8),
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Device Identity',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: _isApproved
                                    ? const Color(0xFF107C41).withAlpha(30)
                                    : const Color(0xFFD97706).withAlpha(25),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                _isApproved
                                    ? 'APPROVED'
                                    : 'PENDING',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: _isApproved
                                      ? const Color(0xFF107C41)
                                      : const Color(0xFFD97706),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Device Name:',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey[500])),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(devName,
                                  textAlign: TextAlign.end,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 12, fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Account Holder:',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey[500])),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(widget.user.name,
                                  textAlign: TextAlign.end,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 12, fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Multi-Device Policy:',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey[500])),
                            const SizedBox(width: 8),
                            const Flexible(
                              child: Text('1 Primary + 1 Secondary',
                                  textAlign: TextAlign.end,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 12, fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Policy Notice Box
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD97706).withAlpha(16),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFD97706).withAlpha(60),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          size: 18,
                          color: Color(0xFFD97706),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'When this 3rd device logged in, any previous 2nd device account was automatically logged out. To protect your funds, access remains pending until confirmed on your primary device.',
                            style: TextStyle(
                              fontSize: 11.5,
                              color:
                                  isDark ? Colors.orange[200] : Colors.orange[900],
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Real-time listener pulse banner
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF14171D)
                          : const Color(0xFFEFF3FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.radar_rounded,
                          size: 16,
                          color: isDark
                              ? const Color(0xFF6B7FFF)
                              : const Color(0xFF2F78A8),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _statusMessage,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                              color: isDark
                                  ? const Color(0xFFA5B4FC)
                                  : const Color(0xFF1E3A8A),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Check Status Button
                  SizedBox(
                    height: 48,
                    child: FilledButton.icon(
                      key: const Key('btn_check_pending_status'),
                      onPressed: _isChecking ? null : _manualCheckStatus,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF2F78A8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: _isChecking
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.refresh_rounded, size: 18),
                      label: Text(
                        _isChecking
                            ? 'Checking Status...'
                            : 'Check Authorization Status',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Cancel / Sign Out Button
                  SizedBox(
                    height: 44,
                    child: OutlinedButton(
                      key: const Key('btn_cancel_pending_access'),
                      onPressed: widget.onCancel,
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Cancel & Sign Out'),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Footer security disclaimer
                  Center(
                    child: Text(
                      'Secured by Aura Multi-Device Hardware Attestation Policy',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? Colors.grey[500]
                            : const Color(0xFF6E7787),
                      ),
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
