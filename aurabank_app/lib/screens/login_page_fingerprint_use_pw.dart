import 'package:flutter/material.dart';

/// Screen: Login Page - Fingerprint-use pw instead
class LoginPageFingerprintUsePw extends StatefulWidget {
  final VoidCallback? onFingerprintTap;
  final VoidCallback? onUsePasswordInstead;
  final VoidCallback? onForgotPassword;
  final VoidCallback? onSwitchAccount;

  const LoginPageFingerprintUsePw({
    super.key,
    this.onFingerprintTap,
    this.onUsePasswordInstead,
    this.onForgotPassword,
    this.onSwitchAccount,
  });

  @override
  State<LoginPageFingerprintUsePw> createState() =>
      _LoginPageFingerprintUsePwState();
}

class _LoginPageFingerprintUsePwState extends State<LoginPageFingerprintUsePw> {
  @override
  Widget build(BuildContext context) {
    const brandViolet = Color(0xFF3A0088);
    const fingerprintColor = Color(0xFF4A10B4);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Top Brand & Welcome Header
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
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),

              // Centered Fingerprint Biometric Scanner
              GestureDetector(
                onTap: widget.onFingerprintTap,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                  child: const Icon(
                    Icons.fingerprint_rounded,
                    size: 110,
                    color: fingerprintColor,
                  ),
                ),
              ),

              // Bottom Actions: Button & Footer Links
              Column(
                children: [
                  // "Use password instead" Primary CTA Button
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: () {
                        widget.onUsePasswordInstead?.call();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: brandViolet,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'Use password instead',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
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
                              color: Color(0xFF9CA3AF),
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
            ],
          ),
        ),
      ),
    );
  }
}

