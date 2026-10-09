import 'package:flutter/material.dart';
import 'package:aurabank_core/services/bank_service.dart';
import 'package:aurabank_core/theme/aura_theme.dart';

class WebProfileScreen extends StatefulWidget {
  final VoidCallback? onBack;

  const WebProfileScreen({super.key, this.onBack});

  @override
  State<WebProfileScreen> createState() => _WebProfileScreenState();
}

class _WebProfileScreenState extends State<WebProfileScreen> {
  final BankService _bankService = BankService();

  static const Color brandViolet = AuraColors.primary;
  static const Color textDark = AuraColors.textPrimary;
  static const Color textGray = AuraColors.textMuted;
  static const Color bgSurface = Color(0xFFF9FAFB);
  static const Color cardBorder = Color(0xFFE5E7EB);
  static const Color accentGreen = Color(0xFF16A34A);

  int _selectedNavSection = 0; // 0: Personal Information, 1: Security & 2FA, 2: Active Sessions

  // Form Controllers for interactive editing
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;

  bool _isSaving = false;

  final List<_PortalDevice> _devices = [
    _PortalDevice(
      name: 'Aura Mobile App on iPhone 15 Pro',
      detail: 'San Francisco, US • iOS 17.5',
      badge: 'MAIN',
      isThisBrowser: false,
      icon: Icons.phone_iphone_rounded,
    ),
  ];

  final List<_PortalDevice> _sessions = [
    _PortalDevice(
      name: 'Chrome on macOS',
      detail: 'San Francisco, US • IP: 192.0.2.1',
      badge: 'THIS SESSION',
      isThisBrowser: true,
      icon: Icons.laptop_mac_rounded,
    ),
    _PortalDevice(
      name: 'Edge Browser on Windows 11',
      detail: 'New York, US • IP: 198.51.100.4',
      badge: '',
      isThisBrowser: false,
      icon: Icons.laptop_windows_rounded,
    ),
  ];

  @override
  void initState() {
    super.initState();
    final user = _bankService.user;
    _nameController = TextEditingController(text: user.name);
    _emailController = TextEditingController(text: user.email);
    _phoneController = TextEditingController(text: user.phoneNumber);
    _addressController = TextEditingController(text: user.address);
    _bankService.addListener(_onServiceUpdate);
  }

  @override
  void dispose() {
    _bankService.removeListener(_onServiceUpdate);
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _onServiceUpdate() {
    if (mounted) setState(() {});
  }

  Future<void> _handleSaveProfile() async {
    setState(() => _isSaving = true);
    await Future.delayed(const Duration(milliseconds: 500));
    _bankService.updateUserProfile(
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      phoneNumber: _phoneController.text.trim(),
      address: _addressController.text.trim(),
    );
    if (mounted) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Account profile updated successfully'),
          backgroundColor: accentGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _bankService.user;

    return Container(
      color: bgSurface,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Account & Security Management',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: textDark,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Manage institutional profile settings, Multi-Factor Authentication, and active desktop sessions.',
                  style: TextStyle(
                    fontSize: 14,
                    color: textGray.withValues(alpha: 0.9),
                  ),
                ),

                const SizedBox(height: 32),

                // Settings Rail and Content Area
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // LEFT COLUMN: Settings Navigation Rail (280px)
                    SizedBox(
                      width: 280,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: cardBorder),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Compact Identity Header
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 24,
                                    backgroundColor: brandViolet.withValues(alpha: 0.1),
                                    child: const Text(
                                      'RA',
                                      style: TextStyle(
                                        color: brandViolet,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          user.name,
                                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: textDark),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          _bankService.savingsAccountNumber,
                                          style: const TextStyle(fontSize: 11, color: textGray, fontFamily: 'monospace'),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Divider(height: 24, color: cardBorder),

                            _buildSettingsNavItem(0, Icons.person_outline_rounded, 'Personal Information'),
                            _buildSettingsNavItem(1, Icons.shield_outlined, 'Security & 2FA'),
                            _buildSettingsNavItem(2, Icons.devices_rounded, 'Devices & Sessions'),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(width: 24),

                    // RIGHT COLUMN: Selected Section Detail
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: cardBorder),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.02),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: _buildSelectedSectionContent(),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsNavItem(int index, IconData icon, String title) {
    final isSelected = _selectedNavSection == index;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: InkWell(
        onTap: () => setState(() => _selectedNavSection = index),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? brandViolet.withValues(alpha: 0.08) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: isSelected ? brandViolet : textGray),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? brandViolet : textDark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedSectionContent() {
    switch (_selectedNavSection) {
      case 0:
        return _buildPersonalInfoSection();
      case 1:
        return _buildSecuritySection();
      case 2:
        return _buildActiveSessionsSection();
      default:
        return _buildPersonalInfoSection();
    }
  }

  Widget _buildPersonalInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Personal Details',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: textDark),
        ),
        const SizedBox(height: 4),
        const Text(
          'Update your personal information and verified contact channels.',
          style: TextStyle(fontSize: 13, color: textGray),
        ),
        const SizedBox(height: 28),

        Row(
          children: [
            Expanded(
              child: _buildInputField('Full Legal Name', _nameController, Icons.person_outline),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildInputField('Email Address', _emailController, Icons.mail_outline),
            ),
          ],
        ),
        const SizedBox(height: 20),

        Row(
          children: [
            Expanded(
              child: _buildInputField('Phone Number', _phoneController, Icons.phone_outlined),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildInputField('Billing Address', _addressController, Icons.location_on_outlined),
            ),
          ],
        ),
        const SizedBox(height: 32),

        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            SizedBox(
              height: 44,
              child: OutlinedButton(
                onPressed: () {
                  final user = _bankService.user;
                  _nameController.text = user.name;
                  _emailController.text = user.email;
                  _phoneController.text = user.phoneNumber;
                  _addressController.text = user.address;
                },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: cardBorder),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Reset', style: TextStyle(color: textGray, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              height: 44,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _handleSaveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: brandViolet,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: _isSaving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInputField(String label, TextEditingController controller, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: textDark),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          style: const TextStyle(fontSize: 14, color: textDark),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, size: 18, color: textGray),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: cardBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: cardBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: brandViolet, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildSecuritySection() {
    final user = _bankService.user;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Security',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: textDark),
        ),
        const SizedBox(height: 4),
        const Text(
          'Manage sign-in, transfer approval, and alerts.',
          style: TextStyle(fontSize: 13, color: textGray),
        ),
        const SizedBox(height: 28),

        _buildSecurityToggleTile(
          title: 'Face ID',
          subtitle: 'Sign in and authorize transfers with Face ID.',
          value: user.faceIdEnabled,
          onChanged: (val) {
            _bankService.setFaceIdEnabled(val);
            setState(() {});
          },
        ),
        const Divider(height: 24, color: cardBorder),

        _buildSecurityToggleTile(
          title: 'Fingerprint',
          subtitle: 'Sign in and authorize transfers with your fingerprint.',
          value: user.fingerprintEnabled,
          onChanged: (val) {
            _bankService.setFingerprintEnabled(val);
            setState(() {});
          },
        ),
        const Divider(height: 24, color: cardBorder),

        _buildSecurityToggleTile(
          title: 'Notifications',
          subtitle: 'Receive alerts for account activity.',
          value: user.pushAlertsEnabled,
          onChanged: (val) {
            _bankService.setPushAlertsEnabled(val);
            setState(() {});
          },
        ),
      ],
    );
  }

  Widget _buildSecurityToggleTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: textDark)),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(fontSize: 12.5, color: textGray)),
            ],
          ),
        ),
        Switch.adaptive(
          value: value,
          activeTrackColor: brandViolet,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildActiveSessionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Connected Devices & Sessions',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: textDark),
        ),
        const SizedBox(height: 4),
        const Text(
          'Registered devices and sign-ins that are open right now.',
          style: TextStyle(fontSize: 13, color: textGray),
        ),
        const SizedBox(height: 28),
        _buildEntryGroup(
          title: 'Devices',
          subtitle: 'Phones and computers registered to this account. Up to two: main and secondary.',
          entries: _devices,
          emptyLabel: 'No registered devices.',
        ),
        const SizedBox(height: 28),
        _buildEntryGroup(
          title: 'Sessions',
          subtitle: 'Sign-ins that are open right now.',
          entries: _sessions,
          emptyLabel: 'No open sessions.',
        ),
      ],
    );
  }

  Widget _buildEntryGroup({
    required String title,
    required String subtitle,
    required List<_PortalDevice> entries,
    required String emptyLabel,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: textDark)),
        const SizedBox(height: 2),
        Text(subtitle, style: const TextStyle(fontSize: 12.5, color: textGray)),
        const SizedBox(height: 12),
        if (entries.isEmpty)
          Text(emptyLabel, style: const TextStyle(fontSize: 13, color: textGray))
        else
          for (var i = 0; i < entries.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            _buildSessionCard(entries[i], entries),
          ],
      ],
    );
  }

  Future<void> _confirmRevoke(_PortalDevice entry, List<_PortalDevice> entries) async {
    final isSession = identical(entries, _sessions);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          isSession ? 'Revoke this session?' : 'Revoke this device?',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: textDark),
        ),
        content: Text(
          isSession
              ? '${entry.name} will be signed out.'
              : '${entry.name} will be removed from this account.',
          style: const TextStyle(fontSize: 13.5, color: textGray),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: textDark, fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Revoke', style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    if (entry.isThisBrowser) {
      Navigator.of(context).pushReplacementNamed('/login');
      return;
    }
    setState(() {
      entries.remove(entry);
      if (!isSession && entries.isNotEmpty && !entries.any((item) => item.badge == 'MAIN')) {
        entries.first.badge = 'MAIN';
      }
    });
  }

  Widget _buildSessionCard(_PortalDevice entry, List<_PortalDevice> entries) {
    final highlighted = entry.badge == 'MAIN' || entry.isThisBrowser;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: highlighted ? brandViolet.withValues(alpha: 0.03) : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: highlighted ? brandViolet.withValues(alpha: 0.2) : cardBorder),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: highlighted ? brandViolet.withValues(alpha: 0.1) : Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(entry.icon, color: highlighted ? brandViolet : textGray, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        entry.name,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: textDark),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (entry.badge.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: entry.badge == 'MAIN' || entry.isThisBrowser
                              ? const Color(0xFFDCFCE7)
                              : const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          entry.badge,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: entry.badge == 'MAIN' || entry.isThisBrowser ? accentGreen : textGray,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(entry.detail, style: const TextStyle(fontSize: 12, color: textGray)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          TextButton(
            onPressed: () => _confirmRevoke(entry, entries),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFDC2626),
              backgroundColor: const Color(0xFFFEF2F2),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Revoke', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

}

class _PortalDevice {
  _PortalDevice({
    required this.name,
    required this.detail,
    required this.badge,
    required this.isThisBrowser,
    required this.icon,
  });

  final String name;
  final String detail;
  String badge;
  final bool isThisBrowser;
  final IconData icon;
}
