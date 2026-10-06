import 'package:flutter/material.dart';
import '../theme/aura_theme.dart';
import 'login_screen.dart';

class DevicesSessionsScreen extends StatefulWidget {
  const DevicesSessionsScreen({super.key});

  @override
  State<DevicesSessionsScreen> createState() => _DevicesSessionsScreenState();
}

class _DevicesSessionsScreenState extends State<DevicesSessionsScreen> {
  // Device list state
  final List<Map<String, dynamic>> _trustedDevices = [
    {
      'id': 'dev_1',
      'name': 'iPhone 15 Pro',
      'os': 'iOS 19',
      'location': 'Pasig, Metro Manila',
      'isPrimary': true,
      'status': 'Active Now',
      'isActive': true,
      'icon': Icons.phone_iphone_rounded,
    },
    {
      'id': 'dev_2',
      'name': 'iPad Air',
      'os': 'iPadOS 19',
      'location': 'Quezon City • Active 2h ago',
      'isPrimary': false,
      'status': 'Idle',
      'isActive': false,
      'icon': Icons.tablet_mac_rounded,
    },
  ];

  final List<Map<String, dynamic>> _webSessions = [
    {
      'id': 'web_1',
      'browser': 'Chrome • macOS',
      'details': 'Makati City • Active 15m ago',
      'icon': Icons.language_rounded,
    },
    {
      'id': 'web_2',
      'browser': 'Safari • iPadOS Web',
      'details': 'Quezon City • Yesterday, 4:20 PM',
      'icon': Icons.explore_outlined,
    },
  ];

  void _revokeDevice(int index) {
    final dev = _trustedDevices[index];
    if (dev['isPrimary'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot revoke primary device while logged in. Demote or switch device first.'),
          backgroundColor: AuraColors.amberWarning,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Revoke ${dev['name']}?'),
        content: const Text(
          'This hardware cryptographic trust key will be invalidated. Any biometric authorization from this device will be blocked.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: AuraColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AuraColors.debitRed,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              setState(() {
                _trustedDevices.removeAt(index);
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${dev['name']} hardware trust revoked.'),
                  backgroundColor: AuraColors.primary,
                ),
              );
            },
            child: const Text('Revoke Device'),
          ),
        ],
      ),
    );
  }

  void _endWebSession(int index) {
    final session = _webSessions[index];
    setState(() {
      _webSessions.removeAt(index);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Terminated session for ${session['browser']}'),
        backgroundColor: AuraColors.primary,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showLogoutAllDevicesModal() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: AuraColors.debitRed, size: 26),
            SizedBox(width: 8),
            Text(
              'Log Out All Devices?',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
          ],
        ),
        content: const Text(
          'You will be immediately signed out across all mobile phones, tablets, and desktop browsers. You will need your password and Email OTP to sign back in.',
          style: TextStyle(fontSize: 13, height: 1.45, color: AuraColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: AuraColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AuraColors.debitRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                (route) => false,
              );
            },
            child: const Text('Yes, Log Out All', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBFBFD),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: AuraColors.cardBorder),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: AuraColors.textPrimary),
                      onPressed: () => Navigator.of(context).maybePop(),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                  const Expanded(
                    child: Center(
                      child: Text(
                        'Devices & Sessions',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                          color: AuraColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 38), // Balance width for center alignment
                ],
              ),

              const SizedBox(height: 24),

              // Section 1 Header: TRUSTED DEVICES (2/2)
              Text(
                'TRUSTED DEVICES (${_trustedDevices.length}/2)',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AuraColors.textMuted,
                  letterSpacing: 0.8,
                ),
              ),

              const SizedBox(height: 12),

              // Trusted Devices Cards
              ..._trustedDevices.asMap().entries.map((entry) {
                final index = entry.key;
                final dev = entry.value;

                return Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: dev['isPrimary'] == true
                          ? AuraColors.primary.withValues(alpha: 0.22)
                          : AuraColors.cardBorder,
                      width: 1.2,
                    ),
                    boxShadow: AuraColors.cardShadow,
                  ),
                  child: Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: AuraColors.bgLavender,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AuraColors.borderLavender),
                            ),
                            child: Icon(
                              dev['icon'] as IconData,
                              color: AuraColors.primary,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  dev['name'] as String,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: AuraColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  dev['os'] as String,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AuraColors.textMuted,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Row(
                                  children: [
                                    const Icon(Icons.location_on_outlined, size: 12, color: AuraColors.textMuted),
                                    const SizedBox(width: 3),
                                    Text(
                                      dev['location'] as String,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AuraColors.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: dev['isPrimary'] == true
                                  ? AuraColors.primary
                                  : const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              dev['isPrimary'] == true ? 'PRIMARY' : 'SECONDARY',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                                color: dev['isPrimary'] == true ? Colors.white : const Color(0xFF4B5563),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      const Divider(color: AuraColors.divider, height: 1),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.circle,
                                size: 8,
                                color: dev['isActive'] == true
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFF9CA3AF),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                dev['status'] as String,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: dev['isActive'] == true
                                      ? const Color(0xFF059669)
                                      : const Color(0xFF6B7280),
                                ),
                              ),
                            ],
                          ),
                          InkWell(
                            onTap: () => _revokeDevice(index),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEE2E2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'Revoke',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFDC2626),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),

              const SizedBox(height: 18),

              // Section 2 Header: ACTIVE WEB SESSIONS
              const Text(
                'ACTIVE WEB SESSIONS',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AuraColors.textMuted,
                  letterSpacing: 0.8,
                ),
              ),

              const SizedBox(height: 12),

              // Active Web Sessions Card
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AuraColors.cardBorder),
                  boxShadow: AuraColors.cardShadow,
                ),
                child: Column(
                  children: [
                    if (_webSessions.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(20.0),
                        child: Text(
                          'No active web sessions.',
                          style: TextStyle(fontSize: 13, color: AuraColors.textMuted),
                        ),
                      )
                    else
                      ..._webSessions.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final s = entry.value;
                        final isLast = idx == _webSessions.length - 1;

                        return Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
                              child: Row(
                                children: [
                                  Container(
                                    width: 38,
                                    height: 38,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF3F4F6),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      s['icon'] as IconData,
                                      color: AuraColors.textPrimary,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          s['browser'] as String,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: AuraColors.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          s['details'] as String,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: AuraColors.textMuted,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () => _endWebSession(idx),
                                    style: TextButton.styleFrom(
                                      foregroundColor: const Color(0xFFDC2626),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    child: const Text(
                                      'End',
                                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (!isLast) const Divider(color: AuraColors.divider, height: 1),
                          ],
                        );
                      }),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Bottom Actions
              // 1. Log Out All Sessions (Outlined)
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFFEE2E2), width: 1.2),
                    backgroundColor: const Color(0xFFFEF2F2).withValues(alpha: 0.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                  ),
                  onPressed: () {
                    setState(() {
                      _webSessions.clear();
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('All active web sessions terminated successfully.'),
                        backgroundColor: AuraColors.primary,
                      ),
                    );
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.logout_rounded, size: 18, color: Color(0xFF991B1B)),
                      SizedBox(width: 8),
                      Text(
                        'Log Out All Sessions',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF991B1B),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // 2. Log Out of All Devices (Red text button)
              Center(
                child: TextButton(
                  onPressed: _showLogoutAllDevicesModal,
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFDC2626),
                  ),
                  child: const Text(
                    'Log Out of All Devices',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
