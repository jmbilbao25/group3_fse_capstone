import 'package:flutter/material.dart';
import '../../services/bank_service.dart';
import '../../theme/aura_theme.dart';
import '../../widgets/aura_logo.dart';
import 'devices_sessions_screen.dart';
import '../auth/login_screen.dart';

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

            // Logout icon in soft red circle
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: Color(0xFFFEE2E2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.logout_rounded, color: Color(0xFFDC2626), size: 28),
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
                  backgroundColor: const Color(0xFFDC2626),
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
    final emailCtrl = TextEditingController();
    final currentEmail = _bankService.user.email;
    final quickDomains = ['@gmail.com', '@icloud.com', '@outlook.com', '@yahoo.com'];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final trimmed = emailCtrl.text.trim();
          final bool hasAtAndDot = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$').hasMatch(trimmed);
          final bool isSame = trimmed.toLowerCase() == currentEmail.toLowerCase();
          final bool isValid = hasAtAndDot && !isSame;

          void applyDomain(String domain) {
            final raw = emailCtrl.text.trim();
            if (raw.isEmpty) {
              emailCtrl.text = domain;
            } else if (raw.contains('@')) {
              final prefix = raw.split('@').first;
              emailCtrl.text = prefix.isEmpty ? domain : '$prefix$domain';
            } else {
              emailCtrl.text = '$raw$domain';
            }
            emailCtrl.selection = TextSelection.fromPosition(
              TextPosition(offset: emailCtrl.text.length),
            );
            setModalState(() {});
          }

          return Dialog(
            backgroundColor: Colors.white,
            elevation: 12,
            shadowColor: brandViolet.withValues(alpha: 0.18),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with Luxury Squircle Badge & Dismiss Button
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFFEDE9FE), Color(0xFFF5EEFF)],
                            ),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFDDD6FE), width: 1.0),
                            boxShadow: [
                              BoxShadow(
                                color: brandViolet.withValues(alpha: 0.08),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.alternate_email_rounded, color: brandViolet, size: 22),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Change Email',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: textDark,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Update primary account email',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: textGray,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Close (X) icon button
                        InkWell(
                          onTap: () => Navigator.of(ctx).pop(),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(Icons.close_rounded, size: 17, color: Color(0xFF64748B)),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    // Current Registered Email Inset Box with "Active" Status Badge
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE2E8F0).withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.lock_outline_rounded, size: 16, color: Color(0xFF64748B)),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'CURRENT EMAIL',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF64748B),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  currentEmail,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: textDark,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFECFDF5),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFA7F3D0), width: 1.0),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircleAvatar(radius: 3, backgroundColor: Color(0xFF059669)),
                                SizedBox(width: 4),
                                Text(
                                  'Active',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF059669),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // New Email Input Field Header & Validation State
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'NEW EMAIL ADDRESS',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        if (isSame)
                          const Text(
                            'Matches current email',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFD97706),
                            ),
                          )
                        else if (isValid)
                          const Row(
                            children: [
                              Icon(Icons.check_circle_rounded, size: 12, color: Color(0xFF059669)),
                              SizedBox(width: 3),
                              Text(
                                'Valid address',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF059669),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),

                    const SizedBox(height: 7),

                    // New Email Input Field
                    TextField(
                      controller: emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      enableSuggestions: false,
                      style: const TextStyle(fontSize: 14, color: textDark, fontWeight: FontWeight.w700),
                      onChanged: (_) => setModalState(() {}),
                      decoration: InputDecoration(
                        hintText: 'e.g. name@example.com',
                        hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w500),
                        prefixIcon: Icon(
                          Icons.mail_outline_rounded,
                          size: 20,
                          color: isValid ? brandViolet : const Color(0xFF94A3B8),
                        ),
                        suffixIcon: trimmed.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.cancel_rounded, size: 18, color: Color(0xFF94A3B8)),
                                onPressed: () {
                                  emailCtrl.clear();
                                  setModalState(() {});
                                },
                              )
                            : null,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: isSame
                                ? const Color(0xFFF59E0B)
                                : isValid
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFFE2E8F0),
                            width: isValid || isSame ? 1.5 : 1.0,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: brandViolet, width: 1.8),
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Fintech Domain Quick Chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: quickDomains.map((d) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: InkWell(
                              onTap: () => applyDomain(d),
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
                                ),
                                child: Text(
                                  d,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF475569),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Primary Elevated CTA Button (High-Emphasis Fintech CTA)
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isValid ? brandViolet : const Color(0xFFE2E8F0),
                          foregroundColor: isValid ? Colors.white : const Color(0xFF94A3B8),
                          elevation: isValid ? 3 : 0,
                          shadowColor: brandViolet.withValues(alpha: 0.35),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: isValid
                            ? () {
                                final newEmail = emailCtrl.text.trim();
                                _bankService.updateUserProfile(email: newEmail);
                                Navigator.of(ctx).pop();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Row(
                                      children: [
                                        const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text('Registered email updated to $newEmail'),
                                        ),
                                      ],
                                    ),
                                    backgroundColor: brandViolet,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                );
                              }
                            : null,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'Update Email',
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.2,
                              ),
                            ),
                            if (isValid) ...[
                              const SizedBox(width: 8),
                              const Icon(Icons.arrow_forward_rounded, size: 17),
                            ],
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 6),

                    // Secondary Cancel Option
                    SizedBox(
                      width: double.infinity,
                      height: 38,
                      child: TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showChangePasswordDialog() {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();

    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final newPass = newCtrl.text;
          final confirmPass = confirmCtrl.text;

          // Password Criteria Checks
          final hasMinLen = newPass.length >= 8;
          final hasNumber = RegExp(r'[0-9]').hasMatch(newPass);
          final hasSpecialOrCap = RegExp(r'[A-Z!@#\$%^&*(),.?":{}|<>]').hasMatch(newPass);

          int strengthScore = 0;
          if (newPass.isNotEmpty) {
            if (hasMinLen) strengthScore++;
            if (hasNumber) strengthScore++;
            if (hasSpecialOrCap) strengthScore++;
          }

          Color strengthColor = const Color(0xFFEF4444);
          String strengthLabel = 'Weak';
          if (strengthScore == 2) {
            strengthColor = const Color(0xFFF59E0B);
            strengthLabel = 'Moderate';
          } else if (strengthScore == 3) {
            strengthColor = const Color(0xFF10B981);
            strengthLabel = 'Strong';
          }

          final bool isMismatch = confirmPass.isNotEmpty && confirmPass != newPass;

          return Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5EEFF),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFEDE9FE), width: 1.0),
                          ),
                          child: const Icon(Icons.lock_reset_rounded, color: brandViolet, size: 24),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Change Password',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: textDark,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Enhance your banking security',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: textGray,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // 1. Current Password Field
                    _buildModalPasswordField(
                      controller: currentCtrl,
                      label: 'Current Password',
                      obscureText: obscureCurrent,
                      onToggleObscure: () => setModalState(() => obscureCurrent = !obscureCurrent),
                    ),

                    const SizedBox(height: 14),

                    // 2. New Password Field
                    _buildModalPasswordField(
                      controller: newCtrl,
                      label: 'New Password',
                      obscureText: obscureNew,
                      onChanged: (_) => setModalState(() {}),
                      onToggleObscure: () => setModalState(() => obscureNew = !obscureNew),
                    ),

                    // Password Strength Indicator (Dynamic)
                    if (newPass.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: strengthScore / 3,
                                minHeight: 4,
                                backgroundColor: const Color(0xFFE2E8F0),
                                valueColor: AlwaysStoppedAnimation<Color>(strengthColor),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            strengthLabel,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: strengthColor,
                            ),
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 10),

                    // Password Requirements Checklist Pills
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _buildRequirementChip('8+ Characters', hasMinLen),
                        _buildRequirementChip('1 Number', hasNumber),
                        _buildRequirementChip('Special / Caps', hasSpecialOrCap),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // 3. Confirm Password Field
                    _buildModalPasswordField(
                      controller: confirmCtrl,
                      label: 'Confirm New Password',
                      obscureText: obscureConfirm,
                      isError: isMismatch,
                      onChanged: (_) => setModalState(() {}),
                      onToggleObscure: () => setModalState(() => obscureConfirm = !obscureConfirm),
                    ),

                    if (isMismatch) ...[
                      const SizedBox(height: 6),
                      const Text(
                        'Passwords do not match',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFEF4444),
                        ),
                      ),
                    ],

                    const SizedBox(height: 22),

                    // Actions
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 46,
                            child: TextButton(
                              style: TextButton.styleFrom(
                                backgroundColor: const Color(0xFFF1F5F9),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SizedBox(
                            height: 46,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: brandViolet,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              onPressed: () {
                                if (currentCtrl.text.trim().isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Please enter current password.')),
                                  );
                                  return;
                                }
                                if (!hasMinLen || isMismatch) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Please satisfy all password requirements.')),
                                  );
                                  return;
                                }
                                Navigator.of(ctx).pop();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Security password changed successfully.'),
                                    backgroundColor: brandViolet,
                                  ),
                                );
                              },
                              child: const Text(
                                'Save Password',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildModalPasswordField({
    required TextEditingController controller,
    required String label,
    required bool obscureText,
    required VoidCallback onToggleObscure,
    ValueChanged<String>? onChanged,
    bool isError = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      onChanged: onChanged,
      style: const TextStyle(fontSize: 13.5, color: textDark, fontWeight: FontWeight.w700),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          fontSize: 12.5,
          color: isError ? const Color(0xFFEF4444) : textGray,
          fontWeight: FontWeight.w500,
        ),
        prefixIcon: Icon(
          Icons.lock_outline_rounded,
          size: 19,
          color: isError ? const Color(0xFFEF4444) : brandViolet,
        ),
        suffixIcon: IconButton(
          icon: Icon(
            obscureText ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            size: 19,
            color: textGray,
          ),
          onPressed: onToggleObscure,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: isError ? const Color(0xFFEF4444) : const Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: isError ? const Color(0xFFEF4444) : const Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: isError ? const Color(0xFFEF4444) : brandViolet, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildRequirementChip(String label, bool isMet) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isMet ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isMet ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            size: 12,
            color: isMet ? const Color(0xFF16A34A) : textGray,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: isMet ? const Color(0xFF15803D) : textGray,
            ),
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
                  // Bell Icon with indicator dot (Consistent 40x40 circle)
                  Stack(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 8,
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
                        right: 3,
                        top: 3,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFFEF4444),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // 2. User Identity Card (Monogram + Name + Phone + Edit + Registered Email)
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
                        // Monogram Avatar with Luxury Violet Gradient
                        Container(
                          width: 62,
                          height: 62,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: AuraColors.balanceHeroGradient,
                            boxShadow: [
                              BoxShadow(
                                color: brandViolet.withValues(alpha: 0.3),
                                blurRadius: 14,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            initials.isNotEmpty ? initials : 'EM',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),

                        const SizedBox(width: 14),

                        // Name & Phone
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user.name,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: textDark,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.phone_iphone_rounded, size: 13, color: textGray),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      user.phoneNumber,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        color: textGray,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // Edit Button (Fintech-grade pill)
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            backgroundColor: brandViolet.withValues(alpha: 0.08),
                            side: BorderSide(color: brandViolet.withValues(alpha: 0.2), width: 1.0),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                            minimumSize: Size.zero,
                          ),
                          icon: const Icon(Icons.edit_rounded, size: 13, color: brandViolet),
                          label: const Text(
                            'Edit',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: brandViolet,
                            ),
                          ),
                          onPressed: _showEditProfileDialog,
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    // Registered Email Pill (Interactive Instant Change Tile)
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _showChangeEmailDialog,
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: brandViolet.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.alternate_email_rounded, size: 18, color: brandViolet),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'REGISTERED EMAIL',
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF64748B),
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      user.email,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color: textDark,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Fast Action Change Pill
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: brandViolet.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: brandViolet.withValues(alpha: 0.15), width: 1.0),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Change',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w800,
                                        color: brandViolet,
                                      ),
                                    ),
                                    SizedBox(width: 2),
                                    Icon(Icons.chevron_right_rounded, size: 14, color: brandViolet),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
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
                    icon: Icons.face_retouching_natural_rounded,
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
                    subtitle: 'Update registered email address instantly',
                    icon: Icons.alternate_email_rounded,
                    onTap: _showChangeEmailDialog,
                  ),
                  const Divider(color: Color(0xFFF3F4F6), height: 1),
                  _buildNavigationTile(
                    title: 'Change Password',
                    subtitle: 'Update account security password',
                    icon: Icons.key_rounded,
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
                    icon: Icons.headset_mic_rounded,
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
                    icon: Icons.privacy_tip_rounded,
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

              // 6. LOGOUT ACTION
              // Log Out of This Device only (Multi-device logout is on Trusted Devices & Sessions page)
              Container(
                width: double.infinity,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFFEE2E2), width: 1.2),
                ),
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  ),
                  icon: const Icon(Icons.logout_rounded, size: 19, color: Color(0xFFDC2626)),
                  label: const Text(
                    'Log Out of This Device',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFDC2626),
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
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            color: Color(0xFF475569),
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionCard({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 16,
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
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFF5EEFF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFEDE9FE), width: 1.0),
              ),
              child: Icon(icon, size: 21, color: brandViolet),
            ),
            const SizedBox(width: 14),
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
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFF5EEFF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFEDE9FE), width: 1.0),
                ),
                child: Icon(icon, size: 21, color: brandViolet),
              ),
              const SizedBox(width: 14),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: textDark),
          ),
        ],
      ),
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
