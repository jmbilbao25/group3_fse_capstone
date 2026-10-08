import 'package:flutter/material.dart';
import '../../theme/aura_theme.dart';
import '../auth/login_screen.dart';

class DevicesSessionsScreen extends StatefulWidget {
  const DevicesSessionsScreen({super.key});

  @override
  State<DevicesSessionsScreen> createState() => _DevicesSessionsScreenState();
}

class _DevicesSessionsScreenState extends State<DevicesSessionsScreen> {
  static const Color brandViolet = AuraColors.primary;
  static const Color textDark = AuraColors.textPrimary;
  static const Color textGray = AuraColors.textMuted;
  static const Color bgLavender = Color(0xFFFAF7FF);
  static const Color borderLavender = Color(0xFFEDE9FE);

  // Device list state
  final List<Map<String, dynamic>> _trustedDevices = [
    {
      'id': 'dev_1',
      'name': 'iPhone 15 Pro',
      'os': 'iOS 19 • Secure Enclave Key #0x7F2B',
      'location': 'Pasig, Metro Manila',
      'isPrimary': true,
      'status': 'Active Now',
      'isActive': true,
      'icon': Icons.phone_iphone_rounded,
    },
    {
      'id': 'dev_2',
      'name': 'iPad Air',
      'os': 'iPadOS 19 • Biometric Touch ID Binding',
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
      'icon': Icons.laptop_mac_rounded,
    },
    {
      'id': 'web_2',
      'browser': 'Safari • iPadOS Web',
      'details': 'Quezon City • Yesterday, 4:20 PM',
      'icon': Icons.devices_other_rounded,
    },
  ];

  void _revokeDevice(int index) {
    final dev = _trustedDevices[index];
    final isPrimary = dev['isPrimary'] == true;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: const BoxDecoration(
                color: Color(0xFFF3E8FF),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.phonelink_erase_rounded, color: brandViolet, size: 26),
            ),
            const SizedBox(height: 16),
            Text(
              isPrimary ? 'Revoke Primary Device?' : 'Revoke ${dev['name']}?',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: textDark),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              isPrimary
                  ? 'This hardware cryptographic trust key will be invalidated. Any biometric authorization from primary device (${dev['name']}) will be blocked until re-authenticated with OTP.'
                  : 'This hardware cryptographic trust key will be invalidated. Any biometric authorization from this device will be blocked until re-authenticated with OTP.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12.5, color: textGray, height: 1.4),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    style: TextButton.styleFrom(
                      backgroundColor: const Color(0xFFF3F4F6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Cancel', style: TextStyle(color: textDark, fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: brandViolet,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      setState(() {
                        _trustedDevices.removeAt(index);
                        // If primary was revoked and another device remains, promote it to primary
                        if (isPrimary && _trustedDevices.isNotEmpty) {
                          _trustedDevices[0]['isPrimary'] = true;
                          _trustedDevices[0]['status'] = 'Active Now';
                          _trustedDevices[0]['isActive'] = true;
                        }
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(isPrimary
                              ? '${dev['name']} primary hardware trust revoked.'
                              : '${dev['name']} hardware trust revoked.'),
                          backgroundColor: brandViolet,
                        ),
                      );
                    },
                    child: Text(
                      isPrimary ? 'Revoke Primary' : 'Revoke Device',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
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
        backgroundColor: brandViolet,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showLogoutAllSessionsModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: Color(0xFFF3E8FF),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.logout_rounded, color: brandViolet, size: 28),
            ),
            const SizedBox(height: 16),
            const Text(
              'Log out of all sessions?',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: textDark,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Sign out of all active browsers and sessions. Your trusted hardware binding and biometric credentials will remain secured.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                color: textGray,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: brandViolet,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                ),
                onPressed: () {
                  Navigator.of(ctx).pop();
                  setState(() {
                    _webSessions.clear();
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('All web sessions have been logged out.'),
                      backgroundColor: brandViolet,
                    ),
                  );
                },
                child: const Text(
                  'Log Out All Sessions',
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: TextButton(
                style: TextButton.styleFrom(
                  backgroundColor: const Color(0xFFF3F4F6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                ),
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text(
                  'Cancel',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: textDark,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLogoutAllDevicesModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: Color(0xFFF3E8FF),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.devices_other_rounded, color: brandViolet, size: 28),
            ),
            const SizedBox(height: 16),
            const Text(
              'Log out of all devices?',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: textDark,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'This will remove both registered devices from your account. You will need your password and an OTP to sign in again.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                color: textGray,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: bgLavender,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderLavender),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.phone_iphone_rounded, size: 18, color: brandViolet),
                          SizedBox(width: 8),
                          Text('iPhone 15 Pro', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: textDark)),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3E8FF),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFDDD6FE), width: 0.8),
                        ),
                        child: const Text(
                          'Primary',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: brandViolet),
                        ),
                      ),
                    ],
                  ),
                  const Divider(color: borderLavender, height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.tablet_mac_rounded, size: 18, color: brandViolet),
                          SizedBox(width: 8),
                          Text('iPad Air', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: textDark)),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3E8FF),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFDDD6FE), width: 0.8),
                        ),
                        child: const Text(
                          'Secondary',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: brandViolet),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: brandViolet,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                ),
                onPressed: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('All devices signed out everywhere.'),
                      backgroundColor: brandViolet,
                    ),
                  );
                },
                child: const Text(
                  'Log Out Everywhere',
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: TextButton(
                style: TextButton.styleFrom(
                  backgroundColor: const Color(0xFFF3F4F6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                ),
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text(
                  'Cancel',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: textDark,
                  ),
                ),
              ),
            ),
          ],
        ),
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
                      border: Border.all(color: borderLavender),
                      boxShadow: [
                        BoxShadow(
                          color: brandViolet.withValues(alpha: 0.04),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: textDark),
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
                          color: textDark,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 38), // Balance width for center alignment
                ],
              ),

              const SizedBox(height: 18),

              // Security Key Telemetry Banner
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: borderLavender, width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: brandViolet.withValues(alpha: 0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3E8FF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.verified_user_rounded, color: brandViolet, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Hardware Cryptographic Binding',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: textDark,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Zero-Trust Secure Enclave keys actively verify biometric authorization.',
                            style: TextStyle(
                              fontSize: 11,
                              color: textGray,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 22),

              // Section 1 Header: TRUSTED DEVICES (2/2)
              Row(
                children: [
                  Container(
                    width: 3.5,
                    height: 13,
                    decoration: BoxDecoration(
                      color: brandViolet,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'TRUSTED DEVICES (${_trustedDevices.length}/2)',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: brandViolet,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Trusted Devices Cards
              if (_trustedDevices.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: borderLavender),
                  ),
                  child: Column(
                    children: const [
                      Icon(Icons.phonelink_lock_rounded, size: 36, color: brandViolet),
                      SizedBox(height: 10),
                      Text(
                        'No Trusted Devices Enrolled',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: textDark),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Register a new hardware device using biometric enrollment.',
                        style: TextStyle(fontSize: 11.5, color: textGray),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              else
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
                            ? brandViolet.withValues(alpha: 0.25)
                            : borderLavender,
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: brandViolet.withValues(alpha: 0.05),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
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
                                color: const Color(0xFFF3E8FF),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0xFFDDD6FE)),
                              ),
                              child: Icon(
                                dev['icon'] as IconData,
                                color: brandViolet,
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
                                      color: textDark,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    dev['os'] as String,
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      color: textGray,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(Icons.location_on_outlined, size: 12, color: textGray),
                                      const SizedBox(width: 3),
                                      Text(
                                        dev['location'] as String,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: textGray,
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
                                    ? brandViolet
                                    : const Color(0xFFF3E8FF),
                                borderRadius: BorderRadius.circular(10),
                                border: dev['isPrimary'] == true
                                    ? null
                                    : Border.all(color: const Color(0xFFDDD6FE), width: 0.8),
                              ),
                              child: Text(
                                dev['isPrimary'] == true ? 'PRIMARY' : 'SECONDARY',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                  color: dev['isPrimary'] == true ? Colors.white : brandViolet,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        const Divider(color: Color(0xFFF3F4F6), height: 1),
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
                                  color: bgLavender,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: borderLavender, width: 1.0),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    Icon(Icons.link_off_rounded, size: 13, color: brandViolet),
                                    SizedBox(width: 4),
                                    Text(
                                      'Revoke',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        color: brandViolet,
                                      ),
                                    ),
                                  ],
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
              Row(
                children: [
                  Container(
                    width: 3.5,
                    height: 13,
                    decoration: BoxDecoration(
                      color: brandViolet,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'ACTIVE WEB SESSIONS',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: brandViolet,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Active Web Sessions Card
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: borderLavender),
                  boxShadow: [
                    BoxShadow(
                      color: brandViolet.withValues(alpha: 0.04),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    if (_webSessions.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(20.0),
                        child: Text(
                          'No active web sessions.',
                          style: TextStyle(fontSize: 13, color: textGray),
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
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF3E8FF),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: const Color(0xFFDDD6FE)),
                                    ),
                                    child: Icon(
                                      s['icon'] as IconData,
                                      color: brandViolet,
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
                                            color: textDark,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          s['details'] as String,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: textGray,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  OutlinedButton(
                                    onPressed: () => _endWebSession(idx),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: brandViolet,
                                      backgroundColor: bgLavender,
                                      side: const BorderSide(color: borderLavender, width: 1.0),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: const Text(
                                      'End',
                                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (!isLast) const Divider(color: Color(0xFFF3F4F6), height: 1),
                          ],
                        );
                      }),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // Bottom Actions
              // 1. Log Out All Sessions (Aura Brand Outlined)
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: borderLavender, width: 1.4),
                    backgroundColor: bgLavender,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                    elevation: 0,
                  ),
                  onPressed: _showLogoutAllSessionsModal,
                  icon: const Icon(Icons.logout_rounded, size: 19, color: brandViolet),
                  label: const Text(
                    'Log Out All Sessions',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: brandViolet,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // 2. Log Out of All Devices (Aura Violet Text Action)
              Center(
                child: TextButton(
                  onPressed: _showLogoutAllDevicesModal,
                  child: const Text(
                    'Log Out of All Devices',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF7C3AED),
                      letterSpacing: 0.2,
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
