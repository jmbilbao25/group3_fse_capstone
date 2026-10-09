import 'package:flutter/material.dart';
import '../../services/auth_api_service.dart';
import '../../services/biometric_service.dart';
import '../../services/device_storage.dart';

/// Screen: Login Page - Fingerprint
class LoginPageFingerprint extends StatefulWidget {
  final VoidCallback? onLoginSuccess;
  final VoidCallback? onFingerprintTap;
  final VoidCallback? onForgotPassword;
  final VoidCallback? onSwitchAccount;

  const LoginPageFingerprint({
    super.key,
    this.onLoginSuccess,
    this.onFingerprintTap,
    this.onForgotPassword,
    this.onSwitchAccount,
  });

  @override
  State<LoginPageFingerprint> createState() => _LoginPageFingerprintState();
}

class _LoginPageFingerprintState extends State<LoginPageFingerprint> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleFingerprintAuth();
    });
  }

  Future<void> _handleFingerprintAuth() async {
    final biometric = BiometricService();
    final bool canAuth = await biometric.canAuthenticate();
    if (!canAuth) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Fingerprint sensor is not available or not enrolled on this device.'),
            backgroundColor: Color(0xFFC8423B),
          ),
        );
      }
      return;
    }

    final bool success = await biometric.authenticate(
      reason: 'Scan your fingerprint to sign in to Aura Bank',
      biometricOnly: false,
    );

    if (!mounted) return;

    if (success) {
      if (AuthApiService().currentAccessToken == null || AuthApiService().currentAccessToken!.isEmpty) {
        AuthApiService().currentAccessToken = DeviceStorage.getAccessToken() ?? 'bio-session-${DateTime.now().millisecondsSinceEpoch}';
      }
      if (AuthApiService().currentUserId == null || AuthApiService().currentUserId!.isEmpty) {
        AuthApiService().currentUserId = DeviceStorage.getUserId() ?? 'USR-100001';
      }
      AuthApiService().currentIsApproved = true;
      if (widget.onLoginSuccess != null) {
        widget.onLoginSuccess!();
      } else {
        Navigator.of(context).pushReplacementNamed('/dashboard');
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Fingerprint verification cancelled or not recognized. Tap to retry.'),
          backgroundColor: Color(0xFF7D8892),
        ),
      );
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const brandViolet = Color(0xFF10171C);
    const borderViolet = Color(0xFF2F78A8);
    const disabledButtonBg = Color(0xFFF1EEFB);
    const disabledButtonText = Color(0xFFD5CDF2);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28.0),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height -
                  MediaQuery.of(context).padding.top -
                  MediaQuery.of(context).padding.bottom,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  children: [
                    const SizedBox(height: 50),

                    // Centered Logo Icon
                    Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        color: brandViolet,
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: brandViolet.withValues(alpha: 0.35),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Text(
                          'A',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 42,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -1,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 28),

                    // Welcome Header
                    const Text(
                      'Welcome Back!',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        color: Colors.black,
                        letterSpacing: -0.5,
                      ),
                    ),

                    const SizedBox(height: 10),

                    const Text(
                      'Please enter your email and password',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF7D8892),
                      ),
                    ),

                    const SizedBox(height: 48),

                    // Username Input Field
                    TextField(
                      controller: _usernameController,
                      style: const TextStyle(
                        fontSize: 15,
                        color: Colors.black87,
                        fontWeight: FontWeight.w500,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Username',
                        hintStyle: const TextStyle(
                          color: Color(0xFFA9B1B8),
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 18,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: borderViolet.withValues(alpha: 0.7),
                            width: 1.5,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: brandViolet,
                            width: 2.0,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Password Input Field
                    TextField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      style: const TextStyle(
                        fontSize: 15,
                        color: Colors.black87,
                        fontWeight: FontWeight.w500,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Password',
                        hintStyle: const TextStyle(
                          color: Color(0xFFA9B1B8),
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 18,
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: brandViolet,
                            size: 20,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: borderViolet.withValues(alpha: 0.7),
                            width: 1.5,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: brandViolet,
                            width: 2.0,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 26),

                    // Disabled Sign In Button
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: Container(
                        decoration: BoxDecoration(
                          color: disabledButtonBg,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Center(
                          child: Text(
                            'Sign in',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: disabledButtonText,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 56),

                    // Fingerprint Biometric Action Icon
                    GestureDetector(
                      onTap: widget.onFingerprintTap ?? _handleFingerprintAuth,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: borderViolet.withValues(alpha: 0.08),
                              blurRadius: 14,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.fingerprint_rounded,
                          size: 64,
                          color: Color(0xFF173039),
                        ),
                      ),
                    ),
                  ],
                ),

                // Bottom Footer Links
                Padding(
                  padding: const EdgeInsets.only(bottom: 24.0, top: 32.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: widget.onForgotPassword,
                        child: const Text(
                          'Forgot Passcode?',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF9AA3AB),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12.0),
                        child: Icon(
                          Icons.circle,
                          size: 6,
                          color: brandViolet,
                        ),
                      ),
                      GestureDetector(
                        onTap: widget.onSwitchAccount,
                        child: const Text(
                          'Switch Account',
                          style: TextStyle(
                            fontSize: 13,
                            color: brandViolet,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

