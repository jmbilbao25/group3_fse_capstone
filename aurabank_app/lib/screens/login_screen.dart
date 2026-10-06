import 'package:flutter/material.dart';
import '../theme/aura_theme.dart';
import '../widgets/aura_logo.dart';
import 'app_shell.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _usernameController =
      TextEditingController(text: 'elijahriley.montefalco@gmail.com');
  final TextEditingController _passwordController =
      TextEditingController(text: '••••••••••••');
  bool _obscurePassword = true;
  bool _isLoading = false;

  static const Color brandViolet = AuraColors.primary;
  static const Color textDark = AuraColors.textPrimary;
  static const Color textGray = AuraColors.textMuted;
  static const Color cardBorder = AuraColors.cardBorder;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onSignIn() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 600));
    if (mounted) {
      setState(() => _isLoading = false);
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const AppShell()),
      );
    }
  }

  void _simulateBiometricAuth(String type) async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: brandViolet.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  type == 'Face ID' ? Icons.face_rounded : Icons.fingerprint_rounded,
                  color: brandViolet,
                  size: 38,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Aura $type Authentication',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: textDark),
              ),
              const SizedBox(height: 6),
              const Text(
                'Confirm your identity to sign in securely.',
                style: TextStyle(fontSize: 12, color: textGray),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: brandViolet,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(23)),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                    _onSignIn();
                  },
                  child: Text('Authenticate with $type',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Use password instead',
                    style: TextStyle(color: textGray, fontSize: 13, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 26.0),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height -
                  MediaQuery.of(context).padding.top -
                  MediaQuery.of(context).padding.bottom,
            ),
            child: IntrinsicHeight(
              child: Column(
                children: [
                  const SizedBox(height: 48),

                  // Redesigned Aura Logo
                  const AuraLogo(
                    size: 80,
                    style: AuraLogoStyle.violet,
                    borderRadius: 22,
                  ),

                  const SizedBox(height: 22),

                  const Text(
                    'Welcome Back!',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: textDark,
                      letterSpacing: -0.5,
                    ),
                  ),

                  const SizedBox(height: 6),

                  const Text(
                    'Please enter your email and password',
                    style: TextStyle(
                      fontSize: 13,
                      color: textGray,
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Username / Email input
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: cardBorder),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: _usernameController,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textDark),
                      decoration: const InputDecoration(
                        hintText: 'Username or Email',
                        hintStyle: TextStyle(fontSize: 13, color: textGray),
                        border: InputBorder.none,
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Password input
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: cardBorder),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textDark),
                      decoration: InputDecoration(
                        hintText: 'Password',
                        hintStyle: const TextStyle(fontSize: 13, color: textGray),
                        border: InputBorder.none,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            color: textGray,
                            size: 18,
                          ),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 26),

                  // Sign In button
                  Container(
                    width: double.infinity,
                    height: 48,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: AuraColors.buttonShadow,
                    ),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: brandViolet,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      ),
                      onPressed: _isLoading ? null : _onSignIn,
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Text(
                              'Sign in',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Biometric shortcuts
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: () => _simulateBiometricAuth('Fingerprint'),
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: AuraColors.bgLavender,
                            shape: BoxShape.circle,
                            border: Border.all(color: AuraColors.borderLavender),
                            boxShadow: [
                              BoxShadow(
                                color: AuraColors.primary.withValues(alpha: 0.05),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.fingerprint_rounded, color: brandViolet, size: 28),
                        ),
                      ),
                      const SizedBox(width: 24),
                      GestureDetector(
                        onTap: () => _simulateBiometricAuth('Face ID'),
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: AuraColors.bgLavender,
                            shape: BoxShape.circle,
                            border: Border.all(color: AuraColors.borderLavender),
                            boxShadow: [
                              BoxShadow(
                                color: AuraColors.primary.withValues(alpha: 0.05),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.face_rounded, color: brandViolet, size: 28),
                        ),
                      ),
                    ],
                  ),

                  const Spacer(),

                  // Bottom Links
                  Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Text('Forgot Passcode?', style: TextStyle(fontSize: 12, color: textGray)),
                        SizedBox(width: 8),
                        Text('•', style: TextStyle(color: textGray)),
                        SizedBox(width: 8),
                        Text('Switch Account', style: TextStyle(fontSize: 12, color: textDark, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}