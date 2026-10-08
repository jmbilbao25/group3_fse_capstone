import 'package:flutter/material.dart';
import '../../services/bank_service.dart';
import '../../theme/aura_theme.dart';
import '../../widgets/aura_logo.dart';
import 'devices_sessions_screen.dart';
import 'risk_showcase_screen.dart';
import '../auth/security_gate_screen.dart';
import '../auth/otp_verification_screen.dart';
import '../auth/login_screen.dart';

class SettingsScreen extends StatefulWidget {
  final VoidCallback? onBack;

  const SettingsScreen({super.key, this.onBack});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final BankService _bankService = BankService();

  @override
  Widget build(BuildContext context) {
    final user = _bankService.user;

    return Scaffold(
      backgroundColor: const Color(0xFFFBFBFD),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      if (widget.onBack != null) ...[
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                          onPressed: widget.onBack,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        ),
                        const SizedBox(width: 8),
                      ],
                      const AuraLogo(size: 34, style: AuraLogoStyle.violet, borderRadius: 8),
                      const SizedBox(width: 10),
                      const Text(
                        'Aura Bank',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                          color: AuraColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  Stack(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: AuraColors.cardBorder),
                        ),
                        child: const Icon(
                          Icons.notifications_none_rounded,
                          color: AuraColors.textPrimary,
                          size: 20,
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AuraColors.accent,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // Profile Card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: AuraColors.cardBorder),
                  boxShadow: AuraColors.cardShadow,
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        // Avatar with verified badge
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width: 54,
                              height: 54,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFF260057),
                                    Color(0xFF4B0FAF),
                                  ],
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                user.name.split(' ').where((n) => n.isNotEmpty).map((n) => n[0]).take(2).join(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                width: 18,
                                height: 18,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                ),
                                child: const Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  size: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user.name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: AuraColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                user.phoneNumber,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AuraColors.textMuted,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        InkWell(
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Edit profile modal')),
                            );
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: const [
                                Icon(Icons.edit_outlined, size: 13, color: AuraColors.textPrimary),
                                SizedBox(width: 4),
                                Text(
                                  'Edit',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AuraColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Registered Email Pill
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                      decoration: BoxDecoration(
                        color: AuraColors.bgLavender,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AuraColors.borderLavender),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.mark_email_read_rounded, size: 16, color: AuraColors.primary),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'REGISTERED EMAIL',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: AuraColors.textMuted,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  user.email,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AuraColors.textPrimary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 22),

              // Section: SECURITY & AUTHENTICATION
              const Text(
                'SECURITY & AUTHENTICATION',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AuraColors.textMuted,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AuraColors.cardBorder),
                  boxShadow: AuraColors.cardShadow,
                ),
                child: Column(
                  children: [
                    _buildSwitchTile(
                      title: 'Biometric Login (Face ID)',
                      subtitle: 'Unlock app instantly with Face ID',
                      value: user.faceIdEnabled,
                      onChanged: (val) {
                        setState(() => user.faceIdEnabled = val);
                        _bankService.setFaceIdEnabled(val);
                      },
                    ),
                    const Divider(color: AuraColors.divider, height: 1),
                    _buildSwitchTile(
                      title: 'Biometric Login (Fingerprint)',
                      subtitle: 'Authenticate with Touch ID / Fingerprint',
                      value: user.fingerprintEnabled,
                      onChanged: (val) {
                        setState(() => user.fingerprintEnabled = val);
                        _bankService.setFingerprintEnabled(val);
                      },
                    ),
                    const Divider(color: AuraColors.divider, height: 1),
                    _buildNavTile(
                      title: 'Trusted Hardware & Sessions',
                      subtitle: 'iPhone 15 Pro (Primary) & active logins',
                      badgeText: '2 Devices',
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (context) => const DevicesSessionsScreen()),
                        );
                      },
                    ),
                    const Divider(color: AuraColors.divider, height: 1),
                    _buildNavTile(
                      title: 'Change Email',
                      subtitle: 'Update registered email address',
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const OtpVerificationScreen(email: 'juan.delacruz@email.ph'),
                          ),
                        );
                      },
                    ),
                    const Divider(color: AuraColors.divider, height: 1),
                    _buildNavTile(
                      title: 'Change Password',
                      subtitle: 'Update account security password',
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Password change verification initiated.')),
                        );
                      },
                    ),
                    const Divider(color: AuraColors.divider, height: 1),
                    _buildNavTile(
                      title: 'Security Risk & Shield Gates',
                      subtitle: 'Device security, scam prevention & fraud checks',
                      badgeText: 'Live Shield',
                      isPurpleBadge: true,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (context) => const SecurityGateScreen()),
                        );
                      },
                    ),
                    const Divider(color: AuraColors.divider, height: 1),
                    _buildNavTile(
                      title: 'Risk Engine Showcase',
                      subtitle: 'Interactive Security Architecture Simulator',
                      badgeText: 'Architecture',
                      isPurpleBadge: true,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (context) => const RiskEngineShowcaseScreen()),
                        );
                      },
                    ),
                    const Divider(color: AuraColors.divider, height: 1),
                    _buildNavTile(
                      title: 'Backend & Cloud Routing',
                      subtitle: _bankService.environment == AppEnvironment.prod
                          ? 'Azure Cloud Prod (${_bankService.cloudUrl})'
                          : 'Local Docker PC (${_bankService.localUrl})',
                      badgeText: _bankService.environment == AppEnvironment.prod ? 'Cloud Prod' : 'Local Dev',
                      isPurpleBadge: _bankService.environment == AppEnvironment.prod,
                      onTap: _showCloudEnvironmentModal,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 22),

              // Section: PREFERENCES & ALERTS
              const Text(
                'PREFERENCES & ALERTS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AuraColors.textMuted,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AuraColors.cardBorder),
                  boxShadow: AuraColors.cardShadow,
                ),
                child: _buildSwitchTile(
                  title: 'Instant Push Alerts',
                  subtitle: 'Real-time alerts for all transfers',
                  value: user.pushAlertsEnabled,
                  onChanged: (val) => setState(() => user.pushAlertsEnabled = val),
                ),
              ),

              const SizedBox(height: 22),

              // Section: HELP & LEGAL
              const Text(
                'HELP & LEGAL',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AuraColors.textMuted,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AuraColors.cardBorder),
                  boxShadow: AuraColors.cardShadow,
                ),
                child: Column(
                  children: [
                    _buildNavTile(
                      title: 'Help & Contact Support',
                      subtitle: '',
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Contacting Aura Priority Support Concierge...')),
                        );
                      },
                    ),
                    const Divider(color: AuraColors.divider, height: 1),
                    _buildNavTile(
                      title: 'Terms & Privacy Policy',
                      subtitle: '',
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Opening Aura Terms & Privacy Policy...')),
                        );
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Engine Version
              const Center(
                child: Text(
                  'Aura Core Banking Engine • v2.4.1 (Build 2026)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AuraColors.textMuted,
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // Bottom Actions
              // 1. Log Out of This Device
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
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (context) => const LoginScreen()),
                      (route) => false,
                    );
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.logout_rounded, size: 18, color: Color(0xFF991B1B)),
                      SizedBox(width: 8),
                      Text(
                        'Log Out of This Device',
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

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AuraColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 11, color: AuraColors.textMuted),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            activeTrackColor: AuraColors.tintPurple,
            thumbColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.selected)
                  ? AuraColors.primary
                  : Colors.white,
            ),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildNavTile({
    required String title,
    required String subtitle,
    String? badgeText,
    bool isPurpleBadge = false,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AuraColors.textPrimary,
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 11, color: AuraColors.textMuted),
                    ),
                  ],
                ],
              ),
            ),
            if (badgeText != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isPurpleBadge
                      ? AuraColors.tintPurple
                      : const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  badgeText,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isPurpleBadge
                        ? AuraColors.primary
                        : const Color(0xFFDC2626),
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AuraColors.textMuted),
          ],
        ),
      ),
    );
  }

  void _showCloudEnvironmentModal() {
    final cloudUrlController = TextEditingController(text: _bankService.cloudUrl);
    bool isTesting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final isProd = _bankService.environment == AppEnvironment.prod;

          return Container(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 24,
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.black12,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Backend & Cloud Environment',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AuraColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Toggle between local Docker development and live Azure Cloud production endpoints.',
                    style: TextStyle(fontSize: 12, color: AuraColors.textMuted, height: 1.4),
                  ),
                  const SizedBox(height: 18),

                  // Option 1: Local Docker PC
                  InkWell(
                    onTap: () {
                      setState(() => _bankService.setEnvironment(AppEnvironment.local));
                      setModalState(() {});
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: !isProd ? const Color(0xFFEDE9FE) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: !isProd ? AuraColors.primary : AuraColors.cardBorder,
                          width: !isProd ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            !isProd ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                            color: !isProd ? AuraColors.primary : AuraColors.textMuted,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Local Docker PC (Development)',
                                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AuraColors.textPrimary),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _bankService.localUrl,
                                  style: const TextStyle(fontSize: 11, color: AuraColors.textMuted),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: !isProd ? AuraColors.primary : Colors.transparent,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'DEFAULT',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: !isProd ? Colors.white : Colors.transparent,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Option 2: Azure Cloud Prod
                  InkWell(
                    onTap: () {
                      setState(() => _bankService.setEnvironment(AppEnvironment.prod));
                      setModalState(() {});
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isProd ? const Color(0xFFEDE9FE) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isProd ? AuraColors.primary : AuraColors.cardBorder,
                          width: isProd ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isProd ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                            color: isProd ? AuraColors.primary : AuraColors.textMuted,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Azure Cloud (Production AKS)',
                                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AuraColors.textPrimary),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _bankService.cloudUrl,
                                  style: const TextStyle(fontSize: 11, color: AuraColors.textMuted),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isProd ? const Color(0xFF10B981) : Colors.transparent,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'AZURE',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: isProd ? Colors.white : Colors.transparent,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Cloud Gateway Input Field
                  if (isProd) ...[
                    const Text(
                      'Azure Cloud Gateway URL',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AuraColors.textPrimary),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: cloudUrlController,
                      decoration: InputDecoration(
                        hintText: 'https://gateway.banking.azure.com or IP',
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AuraColors.cardBorder),
                        ),
                        isDense: true,
                      ),
                      onChanged: (val) {
                        if (val.trim().isNotEmpty) {
                          _bankService.setCloudUrl(val.trim());
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Auto-Fallback Switch
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Auto-Fallback to Local Docker',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AuraColors.textPrimary),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'If cloud is offline or sleeping, fall back to local Docker PC seamlessly.',
                              style: TextStyle(fontSize: 11, color: AuraColors.textMuted),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _bankService.autoFallbackToLocal,
                        activeThumbColor: AuraColors.primary,
                        onChanged: (val) {
                          setState(() => _bankService.setAutoFallback(val));
                          setModalState(() {});
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Test Connection & Status
                  if (_bankService.lastConnectionStatus != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: _bankService.lastPingLatencyMs != null
                            ? const Color(0xFFECFDF5)
                            : const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _bankService.lastPingLatencyMs != null
                              ? const Color(0xFF10B981).withValues(alpha: 0.3)
                              : const Color(0xFFEF4444).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _bankService.lastPingLatencyMs != null ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                            size: 16,
                            color: _bankService.lastPingLatencyMs != null ? const Color(0xFF059669) : const Color(0xFFDC2626),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Status: ${_bankService.lastConnectionStatus}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: _bankService.lastPingLatencyMs != null ? const Color(0xFF059669) : const Color(0xFFDC2626),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AuraColors.cardBorder),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: isTesting
                              ? null
                              : () async {
                                  setModalState(() => isTesting = true);
                                  await _bankService.testConnection();
                                  setModalState(() => isTesting = false);
                                  setState(() {});
                                },
                          child: isTesting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: AuraColors.primary),
                                )
                              : const Text(
                                  'Test Ping',
                                  style: TextStyle(fontWeight: FontWeight.w700, color: AuraColors.textPrimary),
                                ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AuraColors.primary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: const Text(
                            'Save & Close',
                            style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

