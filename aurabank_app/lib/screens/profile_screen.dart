import 'package:flutter/material.dart';
import '../services/bank_service.dart';
import '../theme/aura_theme.dart';
import '../widgets/aura_logo.dart';
import 'devices_sessions_screen.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  final VoidCallback? onBack;

  const ProfileScreen({super.key, this.onBack});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final BankService _bankService = BankService();

  static const Color brandViolet = AuraColors.primary;
  static const Color textDark = AuraColors.textPrimary;
  static const Color textGray = AuraColors.textMuted;
  static const Color cardBorder = Color(0xFFE5E7EB);

  @override
  void initState() {
    super.initState();
    _bankService.addListener(_onServiceUpdate);
  }

  @override
  void dispose() {
    _bankService.removeListener(_onServiceUpdate);
    super.dispose();
  }

  void _onServiceUpdate() {
    if (mounted) setState(() {});
  }

  // Interactive Edit Profile Dialog
  void _showEditProfileDialog() {
    final user = _bankService.user;
    final nameCtrl = TextEditingController(text: user.name);
    final phoneCtrl = TextEditingController(text: user.phoneNumber);
    final emailCtrl = TextEditingController(text: user.email);
    final dobCtrl = TextEditingController(text: user.dob);
    final addressCtrl = TextEditingController(text: user.address);
    String selectedGender = user.gender;
    String selectedCivil = user.civilStatus;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            left: 24,
            right: 24,
            top: 20,
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
                      color: const Color(0xFFD1D5DB),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Edit Profile',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: textDark),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: textGray),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                _buildFormField(label: 'Full Name', controller: nameCtrl, icon: Icons.person_outline_rounded),
                const SizedBox(height: 12),
                _buildFormField(label: 'Phone Number', controller: phoneCtrl, icon: Icons.phone_outlined),
                const SizedBox(height: 12),
                _buildFormField(label: 'Email Address', controller: emailCtrl, icon: Icons.email_outlined),
                const SizedBox(height: 12),
                _buildFormField(label: 'Date of Birth', controller: dobCtrl, icon: Icons.cake_outlined),
                const SizedBox(height: 12),
                _buildFormField(label: 'Address', controller: addressCtrl, icon: Icons.location_on_outlined),
                const SizedBox(height: 12),

                // Gender & Civil Status Row
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Gender', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: textGray)),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: cardBorder),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: selectedGender,
                                isExpanded: true,
                                items: const [
                                  DropdownMenuItem(value: 'Male', child: Text('Male')),
                                  DropdownMenuItem(value: 'Female', child: Text('Female')),
                                  DropdownMenuItem(value: 'Other', child: Text('Other')),
                                ],
                                onChanged: (val) {
                                  if (val != null) setModalState(() => selectedGender = val);
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Civil Status', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: textGray)),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: cardBorder),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: selectedCivil,
                                isExpanded: true,
                                items: const [
                                  DropdownMenuItem(value: 'Married', child: Text('Married')),
                                  DropdownMenuItem(value: 'Single', child: Text('Single')),
                                  DropdownMenuItem(value: 'Separated', child: Text('Separated')),
                                ],
                                onChanged: (val) {
                                  if (val != null) setModalState(() => selectedCivil = val);
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Save Changes Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: brandViolet,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                    ),
                    onPressed: () {
                      _bankService.updateUserProfile(
                        name: nameCtrl.text.trim(),
                        phoneNumber: phoneCtrl.text.trim(),
                        email: emailCtrl.text.trim(),
                        dob: dobCtrl.text.trim(),
                        address: addressCtrl.text.trim(),
                        gender: selectedGender,
                        civilStatus: selectedCivil,
                      );
                      setState(() {});
                      Navigator.of(ctx).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Profile details updated successfully.'),
                          backgroundColor: AuraColors.creditGreen,
                        ),
                      );
                    },
                    child: const Text('Save Changes', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: textGray)),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, size: 18, color: AuraColors.accent),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: cardBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: cardBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: brandViolet, width: 1.5),
            ),
          ),
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textDark),
        ),
      ],
    );
  }

  // Logout Confirmation Modal
  void _confirmLogoutSession() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Logout of Session?', style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text(
          'Are you sure you want to log out of your current session on this device?',
          style: TextStyle(fontSize: 13, color: textGray, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: textGray)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: brandViolet,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                (route) => false,
              );
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  // Log Out All Devices Modal
  void _confirmLogoutAllDevices() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: AuraColors.debitRed, size: 24),
            SizedBox(width: 8),
            Text('Log Out All Devices?', style: TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
        content: const Text(
          'This will revoke all active trusted devices (iPhone, iPad) and terminate all web sessions. You will need to log in again with full authentication.',
          style: TextStyle(fontSize: 13, color: textGray, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: textGray)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AuraColors.debitRed,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                (route) => false,
              );
            },
            child: const Text('Log Out All Devices'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _bankService.user;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Aura Bank with Underline (matching page_12.png)
              Row(
                children: [
                  if (widget.onBack != null) ...[
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: textDark),
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
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.4,
                      color: textDark,
                      decoration: TextDecoration.underline,
                      decorationColor: textDark,
                      decorationThickness: 1.5,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // 1. Personal Information Card (matching page_12.png)
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: cardBorder),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar, Name, Phone & Edit Button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF8B5CF6),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.person, color: Colors.white, size: 28),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      user.name,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: textDark,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      user.phoneNumber,
                                      style: const TextStyle(fontSize: 12, color: textGray),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        InkWell(
                          onTap: _showEditProfileDialog,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: const [
                                Icon(Icons.edit_outlined, size: 13, color: textDark),
                                SizedBox(width: 4),
                                Text(
                                  'Edit',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: textDark,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    // Grid details
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _buildInfoColumn('Date of Birth', user.dob)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildInfoColumn('Gender', user.gender)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 3, child: _buildInfoColumn('Email', user.email)),
                        const SizedBox(width: 12),
                        Expanded(flex: 2, child: _buildInfoColumn('Civil Status', user.civilStatus)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _buildInfoColumn('Address', user.address),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // 2. Security & Authentication Card
              _buildSectionCard(
                title: 'Security & Authentication',
                children: [
                  _buildSwitchTile(
                    title: 'Biometric Login (Face ID)',
                    subtitle: 'Unlock app instantly with Face ID',
                    value: user.faceIdEnabled,
                    onChanged: (val) => setState(() => user.faceIdEnabled = val),
                  ),
                  const Divider(color: cardBorder, height: 1),
                  _buildSwitchTile(
                    title: 'Biometric Login (Fingerprint)',
                    subtitle: 'Authenticate with Touch ID/Fingerprint',
                    value: user.fingerprintEnabled,
                    onChanged: (val) => setState(() => user.fingerprintEnabled = val),
                  ),
                  const Divider(color: cardBorder, height: 1),
                  _buildNavTile(
                    title: 'Trusted Devices & Sessions',
                    subtitle: 'Manage authorized hardware and active logins',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (context) => const DevicesSessionsScreen()),
                      );
                    },
                  ),
                  const Divider(color: cardBorder, height: 1),
                  _buildNavTile(
                    title: 'Change Email',
                    subtitle: 'Update registered email address',
                    onTap: () {},
                  ),
                  const Divider(color: cardBorder, height: 1),
                  _buildNavTile(
                    title: 'Change Password',
                    subtitle: 'Update account security password',
                    onTap: () {},
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // 3. Preference & Alerts Card
              _buildSectionCard(
                title: 'Preference & Alerts',
                children: [
                  _buildSwitchTile(
                    title: 'Instant Push Alerts',
                    subtitle: 'Real-time alerts for all transfers',
                    value: user.pushAlertsEnabled,
                    onChanged: (val) => setState(() => user.pushAlertsEnabled = val),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // 4. Help and Legal Card
              _buildSectionCard(
                title: 'Help and Legal',
                children: [
                  _buildNavTile(title: 'Help & Contact Support', subtitle: '', onTap: () {}),
                  const Divider(color: cardBorder, height: 1),
                  _buildNavTile(title: 'Terms & Privacy Policy', subtitle: '', onTap: () {}),
                ],
              ),

              const SizedBox(height: 24),

              // LOGOUT ACTIONS (Making complete sense: Session Logout + Device Logout)
              // 1. Primary Action: Logout of Session (matching page_12.png)
              Container(
                width: double.infinity,
                height: 52,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: AuraColors.buttonShadow,
                ),
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: brandViolet,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                  ),
                  icon: const Icon(Icons.logout_rounded, color: Colors.white, size: 20),
                  label: const Text(
                    'Logout of Session',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  onPressed: _confirmLogoutSession,
                ),
              ),

              const SizedBox(height: 12),

              // 2. Destructive Action: Log Out of All Devices
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFFCA5A5), width: 1.2),
                    backgroundColor: const Color(0xFFFEF2F2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                  ),
                  icon: const Icon(Icons.phonelink_erase_rounded, size: 18, color: Color(0xFFDC2626)),
                  label: const Text(
                    'Log Out of All Devices',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFDC2626),
                    ),
                  ),
                  onPressed: _confirmLogoutAllDevices,
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoColumn(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: textGray),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: textDark),
        ),
      ],
    );
  }

  Widget _buildSectionCard({required String title, required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Text(
              title,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: textGray),
            ),
          ),
          ...children,
        ],
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
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: textDark),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(fontSize: 11, color: textGray)),
                ],
              ],
            ),
          ),
          Switch(
            value: value,
            activeTrackColor: AuraColors.tintPurple,
            thumbColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.selected)
                  ? brandViolet
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
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: textDark),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(subtitle, style: const TextStyle(fontSize: 11, color: textGray)),
                  ],
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: textGray),
          ],
        ),
      ),
    );
  }
}
