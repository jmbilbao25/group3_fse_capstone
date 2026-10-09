import 'package:flutter/material.dart';
import '../../services/bank_service.dart';
import '../../theme/aura_theme.dart';

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

  int _selectedNavSection = 0; // 0: General Profile, 1: Security & Auth, 2: Devices & Sessions, 3: Notifications

  // Form Controllers for interactive editing
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;

  bool _isSaving = false;

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
                // Top Header Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Column(
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
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF86EFAC)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.verified_user_rounded, color: accentGreen, size: 16),
                          SizedBox(width: 8),
                          Text(
                            'KYC Level 2 Verified',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF15803D),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
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
                            _buildSettingsNavItem(2, Icons.devices_rounded, 'Active Sessions'),
                            _buildSettingsNavItem(3, Icons.notifications_none_rounded, 'Notifications'),
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
      case 3:
        return _buildNotificationsSection();
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
          'Security & Biometric Multi-Factor Gates',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: textDark),
        ),
        const SizedBox(height: 4),
        const Text(
          'Control hardware authorization, cryptographic approval, and 2FA credentials.',
          style: TextStyle(fontSize: 13, color: textGray),
        ),
        const SizedBox(height: 28),

        _buildSecurityToggleTile(
          title: 'Biometric Face ID / Windows Hello',
          subtitle: 'Authorize high-value transactions using hardware facial or PIN scanning.',
          value: user.faceIdEnabled,
          onChanged: (val) {
            _bankService.setFaceIdEnabled(val);
          },
        ),
        const Divider(height: 24, color: cardBorder),

        _buildSecurityToggleTile(
          title: 'Fingerprint Sensor Authentication',
          subtitle: 'Use cryptographic fingerprint token for instant desktop sign-in.',
          value: user.fingerprintEnabled,
          onChanged: (val) {
            _bankService.setFingerprintEnabled(val);
          },
        ),
        const Divider(height: 24, color: cardBorder),

        _buildSecurityToggleTile(
          title: 'Real-Time Transaction Push Alerts',
          subtitle: 'Receive instant notifications on all outbound wires and debit authorizations.',
          value: user.pushAlertsEnabled,
          onChanged: (val) {
            _bankService.setPushAlertsEnabled(val);
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
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Connected Devices & Sessions',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: textDark),
                ),
                SizedBox(height: 4),
                Text(
                  'Devices currently authorized to access your Aura institutional accounts.',
                  style: TextStyle(fontSize: 13, color: textGray),
                ),
              ],
            ),
            OutlinedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('All other sessions terminated successfully')),
                );
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFDC2626),
                side: const BorderSide(color: Color(0xFFFCA5A5)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Revoke All Others', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        const SizedBox(height: 24),

        _buildSessionCard(
          device: 'Chrome on macOS (Current)',
          location: 'San Francisco, US • IP: 192.0.2.1',
          time: 'Active now',
          isCurrent: true,
        ),
        const SizedBox(height: 12),
        _buildSessionCard(
          device: 'Aura Mobile App on iPhone 15 Pro',
          location: 'San Francisco, US • iOS 17.5',
          time: 'Active 24 minutes ago',
          isCurrent: false,
        ),
        const SizedBox(height: 12),
        _buildSessionCard(
          device: 'Edge Browser on Windows 11',
          location: 'New York, US • IP: 198.51.100.4',
          time: 'Yesterday at 18:42',
          isCurrent: false,
        ),
      ],
    );
  }

  Widget _buildSessionCard({
    required String device,
    required String location,
    required String time,
    required bool isCurrent,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isCurrent ? brandViolet.withValues(alpha: 0.03) : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isCurrent ? brandViolet.withValues(alpha: 0.2) : cardBorder),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isCurrent ? brandViolet.withValues(alpha: 0.1) : Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isCurrent ? Icons.laptop_mac_rounded : Icons.phone_iphone_rounded,
              color: isCurrent ? brandViolet : textGray,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(device, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: textDark)),
                    if (isCurrent) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('CURRENT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: accentGreen)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(location, style: const TextStyle(fontSize: 12, color: textGray)),
              ],
            ),
          ),
          Text(time, style: const TextStyle(fontSize: 12, color: textGray, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildNotificationsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Notification Routing',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: textDark),
        ),
        const SizedBox(height: 4),
        const Text(
          'Select channels where transaction and security alerts should be delivered.',
          style: TextStyle(fontSize: 13, color: textGray),
        ),
        const SizedBox(height: 24),

        _buildSecurityToggleTile(
          title: 'Monthly Statement Dispatch via Email',
          subtitle: 'Receive audited PDF statement deliveries on the 1st of every month.',
          value: true,
          onChanged: (val) {},
        ),
        const Divider(height: 24, color: cardBorder),

        _buildSecurityToggleTile(
          title: 'High-Value Outflow Alerts (Over \$5,000)',
          subtitle: 'Immediate SMS verification for anomalous capital movements.',
          value: true,
          onChanged: (val) {},
        ),
      ],
    );
  }
}
