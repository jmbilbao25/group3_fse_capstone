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
  static const Color accentGreen = AuraColors.creditGreen;
  static const Color textDark = AuraColors.textPrimary;
  static const Color textGray = AuraColors.textMuted;
  static const Color cardBorder = Color(0xFFE5E7EB);

  // Security Toggles State
  bool _faceIdEnabled = true;
  bool _fingerprintEnabled = true;
  bool _pushAlertsEnabled = true;

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

  // Interactive Edit Profile Bottom Sheet
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

                _buildFormField(label: 'Full Name', controller: nameCtrl, icon: Icons.badge_rounded),
                const SizedBox(height: 12),
                _buildFormField(label: 'Phone Number', controller: phoneCtrl, icon: Icons.phone_iphone_rounded),
                const SizedBox(height: 12),
                _buildFormField(label: 'Email', controller: emailCtrl, icon: Icons.mark_email_read_rounded),
                const SizedBox(height: 12),
                _buildFormField(label: 'Date of Birth', controller: dobCtrl, icon: Icons.calendar_month_rounded),
                const SizedBox(height: 12),

                // Gender Selector
                const Text('Gender', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: textGray)),
                const SizedBox(height: 6),
                Row(
                  children: ['Male', 'Female', 'Other'].map((g) {
                    final isSel = selectedGender == g;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(g),
                        selected: isSel,
                        selectedColor: brandViolet,
                        labelStyle: TextStyle(
                          color: isSel ? Colors.white : textDark,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                        onSelected: (val) {
                          if (val) setModalState(() => selectedGender = g);
                        },
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),

                // Civil Status Selector
                const Text('Civil Status', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: textGray)),
                const SizedBox(height: 6),
                Row(
                  children: ['Single', 'Married', 'Separated'].map((c) {
                    final isSel = selectedCivil == c;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(c),
                        selected: isSel,
                        selectedColor: brandViolet,
                        labelStyle: TextStyle(
                          color: isSel ? Colors.white : textDark,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                        onSelected: (val) {
                          if (val) setModalState(() => selectedCivil = c);
                        },
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),

                _buildFormField(label: 'Address', controller: addressCtrl, icon: Icons.location_on_rounded),
                const SizedBox(height: 22),

                // Save Button
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
                      _bankService.updateUserProfile(
                        name: nameCtrl.text.trim(),
                        phoneNumber: phoneCtrl.text.trim(),
                        email: emailCtrl.text.trim(),
                        dob: dobCtrl.text.trim(),
                        gender: selectedGender,
                        civilStatus: selectedCivil,
                        address: addressCtrl.text.trim(),
                      );
                      Navigator.of(ctx).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Profile updated successfully.'),
                          backgroundColor: brandViolet,
                        ),
                      );
                    },
                    child: const Text('Save Changes', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Modal: Log out of this device?
  void _showLogoutThisDeviceBottomSheet() {
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

            // Logout icon in soft violet circle
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
              'Log out of this device?',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: textDark,
              ),
            ),

            const SizedBox(height: 8),

            const Text(
              'You will be signed out of this device. You can sign back in anytime using your password or biometrics.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                color: textGray,
                height: 1.4,
              ),
            ),

            const SizedBox(height: 24),

            // Primary action: Log Out of This Device
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
                      content: Text('You have been signed out of this device.'),
                      backgroundColor: brandViolet,
                    ),
                  );
                },
                child: const Text(
                  'Log Out of This Device',
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold),
                ),
              ),
            ),

            const SizedBox(height: 10),

            // Secondary action: Cancel
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

  void _showChangeEmailDialog() {
    final emailCtrl = TextEditingController(text: _bankService.user.email);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Change Email', style: TextStyle(fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter your new registered email. A confirmation link will be sent.',
              style: TextStyle(fontSize: 12.5, color: textGray),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: emailCtrl,
              decoration: InputDecoration(
                labelText: 'New Email Address',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: textGray)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: brandViolet,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: () {
              _bankService.updateUserProfile(email: emailCtrl.text.trim());
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Registered email updated.'), backgroundColor: brandViolet),
              );
            },
            child: const Text('Update Email', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Change Password', style: TextStyle(fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Update your account security password. Password must be at least 8 characters with numbers and symbols.',
              style: TextStyle(fontSize: 12.5, color: textGray),
            ),
            const SizedBox(height: 14),
            TextField(
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Current Password',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'New Password',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: textGray)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: brandViolet,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Security password changed.'), backgroundColor: brandViolet),
              );
            },
            child: const Text('Save Password', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _bankService.user;
    final initials = user.name.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join();

    return Scaffold(
      backgroundColor: AuraColors.canvas,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Header: Logo + App Name + Notification Bell (Matches executive neobanking design)
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
                        const SizedBox(width: 4),
                      ],
                      const AuraLogo(size: 38, style: AuraLogoStyle.violet, borderRadius: 10),
                      const SizedBox(width: 10),
                      const Text(
                        'Aura Bank',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: brandViolet,
                          letterSpacing: -0.4,
                        ),
                      ),
                    ],
                  ),
                  // Bell Icon with indicator dot
                  Stack(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFEDE9FE)),
                          boxShadow: [
                            BoxShadow(
                              color: brandViolet.withValues(alpha: 0.04),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.notifications_none_rounded, color: textDark, size: 20),
                          padding: EdgeInsets.zero,
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('No unread security alerts.'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                        ),
                      ),
                      Positioned(
                        right: 2,
                        top: 2,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFFDC2626),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // 2. User Identity Card (Monogram + Name + Privilege Badge + Phone + Edit + Client ID & Email Pills)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFEDE9FE), width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: brandViolet.withValues(alpha: 0.06),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        // Monogram Avatar with Aura Violet Gradient & Emerald Verified Badge
                        Stack(
                          children: [
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: AuraColors.balanceHeroGradient,
                                border: Border.all(color: const Color(0xFFDDD6FE), width: 2),
                                boxShadow: [
                                  BoxShadow(
                                    color: brandViolet.withValues(alpha: 0.35),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                initials.isNotEmpty ? initials : 'EM',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
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
                                  color: accentGreen,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2.2),
                                ),
                                child: const Icon(Icons.check, size: 11, color: Colors.white),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(width: 14),

                        // Name, Privilege Badge & Phone
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      user.name,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 16.5,
                                        fontWeight: FontWeight.w800,
                                        color: textDark,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF3E8FF),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'PRIVILEGE',
                                      style: TextStyle(
                                        fontSize: 8.5,
                                        fontWeight: FontWeight.w800,
                                        color: brandViolet,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                user.phoneNumber,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: textGray,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Edit Button
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            backgroundColor: const Color(0xFFF5EEFF),
                            side: const BorderSide(color: Color(0xFFDDD6FE), width: 1.0),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            minimumSize: Size.zero,
                          ),
                          icon: const Icon(Icons.edit_outlined, size: 13, color: brandViolet),
                          label: const Text(
                            'Edit',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: brandViolet,
                            ),
                          ),
                          onPressed: _showEditProfileDialog,
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    // Registered Email Pill
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAF7FF),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFEDE9FE), width: 1.0),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.mark_email_read_rounded, size: 16, color: brandViolet),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'REGISTERED EMAIL',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                    color: brandViolet,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  user.email,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w800,
                                    color: textDark,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),
                    const Divider(color: Color(0xFFF3F4F6), height: 1),
                    const SizedBox(height: 16),

                    // Two-Column Personal Details Grid
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _buildInfoColumn('Date of Birth', user.dob)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildInfoColumn('Gender', user.gender)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _buildInfoColumn('Civil Status', user.civilStatus)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildInfoColumn('Address', user.address)),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 22),

              // 3. SECURITY & AUTHENTICATION Section Header & List
              _buildSectionHeader('SECURITY & AUTHENTICATION'),
              const SizedBox(height: 10),

              _buildSectionCard(
                children: [
                  _buildSwitchTile(
                    title: 'Biometric Login (Face ID)',
                    subtitle: 'Unlock app instantly with Face ID',
                    icon: Icons.face_unlock_rounded,
                    value: _faceIdEnabled,
                    onChanged: (val) {
                      setState(() => _faceIdEnabled = val);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(val ? 'Face ID enabled.' : 'Face ID disabled.'),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    },
                  ),
                  const Divider(color: Color(0xFFF3F4F6), height: 1),
                  _buildSwitchTile(
                    title: 'Biometric Login (Fingerprint)',
                    subtitle: 'Authenticate with Touch ID / Fingerprint',
                    icon: Icons.fingerprint_rounded,
                    value: _fingerprintEnabled,
                    onChanged: (val) {
                      setState(() => _fingerprintEnabled = val);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(val ? 'Touch ID enabled.' : 'Touch ID disabled.'),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    },
                  ),
                  const Divider(color: Color(0xFFF3F4F6), height: 1),
                  _buildNavigationTile(
                    title: 'Trusted Devices & Sessions',
                    subtitle: 'Manage active logins and trusted hardware',
                    icon: Icons.phonelink_lock_rounded,
                    badgeText: '2 Active',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const DevicesSessionsScreen()),
                      );
                    },
                  ),
                  const Divider(color: Color(0xFFF3F4F6), height: 1),
                  _buildNavigationTile(
                    title: 'Change Email',
                    subtitle: 'Update registered email address',
                    icon: Icons.mark_email_read_rounded,
                    onTap: _showChangeEmailDialog,
                  ),
                  const Divider(color: Color(0xFFF3F4F6), height: 1),
                  _buildNavigationTile(
                    title: 'Change Password',
                    subtitle: 'Update account security password',
                    icon: Icons.password_rounded,
                    onTap: _showChangePasswordDialog,
                  ),
                ],
              ),

              const SizedBox(height: 22),

              // 4. PREFERENCES & ALERTS Section Header & List
              _buildSectionHeader('PREFERENCES & ALERTS'),
              const SizedBox(height: 10),

              _buildSectionCard(
                children: [
                  _buildSwitchTile(
                    title: 'Instant Push Alerts',
                    subtitle: 'Real-time alerts for all transfers',
                    icon: Icons.notifications_active_rounded,
                    value: _pushAlertsEnabled,
                    onChanged: (val) {
                      setState(() => _pushAlertsEnabled = val);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(val ? 'Push notifications activated.' : 'Push notifications silenced.'),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    },
                  ),
                ],
              ),

              const SizedBox(height: 22),

              // 5. HELP & LEGAL Section Header & List
              _buildSectionHeader('HELP & LEGAL'),
              const SizedBox(height: 10),

              _buildSectionCard(
                children: [
                  _buildNavigationTile(
                    title: 'Help & Contact Support',
                    subtitle: '24/7 Priority Aura Concierge',
                    icon: Icons.support_agent_rounded,
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          title: const Text('Aura Concierge Support', style: TextStyle(fontWeight: FontWeight.w800)),
                          content: const Text(
                            'Hotline: +63 (2) 8888-AURA\nEmail: support@aurabank.ph\nSecurity Desk: desk@aurabank.ph\nAvailable 24/7/365.',
                          ),
                          actions: [
                            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('OK')),
                          ],
                        ),
                      );
                    },
                  ),
                  const Divider(color: Color(0xFFF3F4F6), height: 1),
                  _buildNavigationTile(
                    title: 'Terms & Privacy Policy',
                    subtitle: 'Privacy notice & security terms',
                    icon: Icons.verified_user_rounded,
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          title: const Text('Terms & Privacy Policy', style: TextStyle(fontWeight: FontWeight.w800)),
                          content: const Text(
                            'Aura Bank employs end-to-end encryption, zero-trust device binding, and secure ledger controls to safeguard user account information and privacy.',
                          ),
                          actions: [
                            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Close')),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Version Note
              const Center(
                child: Text(
                  'Aura Core Banking Engine • v2.4.1 (Build 2026)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // 6. LOGOUT ACTION
              // Log Out of This Device only (Multi-device logout is on Trusted Devices & Sessions page)
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: const Color(0xFFFAF7FF),
                    side: const BorderSide(color: Color(0xFFEDE9FE), width: 1.4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.logout_rounded, size: 19, color: brandViolet),
                  label: const Text(
                    'Log Out of This Device',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: brandViolet,
                      letterSpacing: 0.2,
                    ),
                  ),
                  onPressed: _showLogoutThisDeviceBottomSheet,
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
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
          title,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: brandViolet,
            letterSpacing: 0.9,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionCard({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEDE9FE), width: 1.0),
        boxShadow: [
          BoxShadow(
            color: brandViolet.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    IconData? icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          if (icon != null) ...[
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFFF3E8FF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 20, color: brandViolet),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: textDark),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 11, color: textGray),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            activeTrackColor: brandViolet,
            activeThumbColor: Colors.white,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationTile({
    required String title,
    required String subtitle,
    IconData? icon,
    String? badgeText,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            if (icon != null) ...[
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3E8FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 20, color: brandViolet),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: textDark),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 11, color: textGray),
                  ),
                ],
              ),
            ),
            Row(
              children: [
                if (badgeText != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE9D5FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      badgeText,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: brandViolet,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF9CA3AF)),
              ],
            ),
          ],
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
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textGray),
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

  Widget _buildFormField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
  }) {
    return TextField(
      controller: controller,
      style: const TextStyle(fontSize: 13, color: textDark, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 12, color: textGray),
        prefixIcon: Icon(icon, size: 20, color: brandViolet),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: cardBorder)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: brandViolet, width: 1.5)),
      ),
    );
  }
}
