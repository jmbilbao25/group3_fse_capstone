import 'package:flutter/material.dart';
import '../../services/bank_service.dart';
import '../../widgets/aura_logo.dart';
import '../app_shell.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final BankService _bankService = BankService();
  final TextEditingController _usernameController =
      TextEditingController(text: 'elijahriley.montefalco@gmail.com');
  final TextEditingController _passwordController =
      TextEditingController(text: 'Montefalco@2026');
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _showPasswordFields = false; // For biometric-first mode

  static const Color brandViolet = Color(0xFF3A0088);
  static const Color borderViolet = Color(0xFF5E17EB);
  static const Color disabledButtonBg = Color(0xFFF1EEFB);
  static const Color disabledButtonText = Color(0xFFD5CDF2);

  bool get _hasFingerprint => _bankService.user.fingerprintEnabled;
  bool get _hasFaceId => _bankService.user.faceIdEnabled;
  bool get _hasAnyBiometric => _hasFingerprint || _hasFaceId;

  @override
  void initState() {
    super.initState();
    _bankService.addListener(_onServiceUpdate);
    _loadPreferences();
  }

  void _loadPreferences() async {
    await _bankService.initPreferences();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _bankService.removeListener(_onServiceUpdate);
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onServiceUpdate() {
    if (mounted) setState(() {});
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

  void _authenticateWithFingerprint() {
    _showBiometricAuthSheet(
      title: 'Fingerprint Authentication',
      subtitle: 'Touch the fingerprint sensor to unlock Aura Bank',
      icon: const Icon(Icons.fingerprint_rounded, size: 70, color: brandViolet),
      authType: 'Fingerprint',
    );
  }

  void _authenticateWithFaceId() {
    _showBiometricAuthSheet(
      title: 'Face ID Verification',
      subtitle: 'Position your face in front of the camera',
      icon: SizedBox(
        width: 70,
        height: 70,
        child: CustomPaint(
          painter: _FaceIdIconPainter(color: brandViolet),
        ),
      ),
      authType: 'Face ID',
    );
  }

  void _showBiometricAuthSheet({
    required String title,
    required String subtitle,
    required Widget icon,
    required String authType,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _BiometricAuthModal(
        title: title,
        subtitle: subtitle,
        icon: icon,
        authType: authType,
        onSuccess: () {
          Navigator.of(context).pop();
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const AppShell()),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    children: [
                      const SizedBox(height: 38),

                      // Aura Bank Signature Monogram Logo
                      const AuraLogo(
                        size: 84,
                        style: AuraLogoStyle.violet,
                        borderRadius: 22,
                      ),

                      const SizedBox(height: 20),

                      const Text(
                        "Welcome Back!",
                        style: TextStyle(
                          fontSize: 27,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF111827),
                          letterSpacing: -0.5,
                        ),
                      ),

                      const SizedBox(height: 8),

                      const Text(
                        "Please enter your email and password",
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF6B7280),
                        ),
                      ),

                      const SizedBox(height: 28),

                      // Form Body: either standard credentials OR biometric-first view
                      if (_hasAnyBiometric && !_showPasswordFields) ...[
                        _buildBiometricFirstView(),
                      ] else ...[
                        _buildStandardLoginView(),
                      ],

                      const Spacer(),

                      // Footer: Forgot Passcode? • Switch Account
                      Padding(
                        padding: const EdgeInsets.only(top: 16, bottom: 20),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            GestureDetector(
                              onTap: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Password recovery link sent to your registered email.'),
                                    backgroundColor: brandViolet,
                                  ),
                                );
                              },
                              child: const Text(
                                "Forgot Passcode?",
                                style: TextStyle(
                                  color: Color(0xFF9CA3AF),
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 10),
                              child: Icon(Icons.circle, size: 5, color: brandViolet),
                            ),
                            GestureDetector(
                              onTap: () {
                                _usernameController.clear();
                                _passwordController.clear();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Account switched. Enter your credentials.'),
                                    backgroundColor: brandViolet,
                                  ),
                                );
                              },
                              child: const Text(
                                "Switch Account",
                                style: TextStyle(
                                  color: brandViolet,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.bold,
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
            );
          },
        ),
      ),
    );
  }

  /// 1. Standard Login View (matches Top row of mockup: fields + Sign In + Biometrics below)
  Widget _buildStandardLoginView() {
    return Column(
      children: [
        // Username Field
        TextField(
          controller: _usernameController,
          style: const TextStyle(fontSize: 14.5),
          decoration: InputDecoration(
            hintText: "Username",
            hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13.5),
            contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: borderViolet.withValues(alpha: 0.6), width: 1.4),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: brandViolet, width: 2),
            ),
          ),
        ),

        const SizedBox(height: 14),

        // Password Field
        TextField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          style: const TextStyle(fontSize: 14.5),
          decoration: InputDecoration(
            hintText: "Password",
            hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13.5),
            contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
            suffixIcon: IconButton(
              key: const ValueKey('passwordVisibilityToggle'),
              icon: Icon(
                _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                color: brandViolet,
                size: 20,
              ),
              onPressed: () {
                setState(() => _obscurePassword = !_obscurePassword);
              },
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: borderViolet.withValues(alpha: 0.6), width: 1.4),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: brandViolet, width: 2),
            ),
          ),
        ),

        const SizedBox(height: 20),

        // Sign in Button (Purple if password only, or clean styling if biometrics available)
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _onSignIn,
            style: ElevatedButton.styleFrom(
              backgroundColor: _hasAnyBiometric ? disabledButtonBg : brandViolet,
              foregroundColor: _hasAnyBiometric ? brandViolet : Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    "Sign in",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _hasAnyBiometric ? disabledButtonText : Colors.white,
                    ),
                  ),
          ),
        ),

        // Biometric Icons directly below Sign In button (matches Top Row of mockup)
        if (_hasAnyBiometric) ...[
          const SizedBox(height: 24),
          _buildBiometricIconsRow(),
        ],
      ],
    );
  }

  /// 2. Biometric-First View (matches Bottom row of mockup: big biometric scanner + buttons)
  Widget _buildBiometricFirstView() {
    return Column(
      children: [
        const SizedBox(height: 20),

        // Main Biometric Large Action Icon
        if (_hasFaceId && !_hasFingerprint) ...[
          _buildFaceIdBigCircle(),
        ] else if (_hasFingerprint && !_hasFaceId) ...[
          _buildFingerprintBigCircle(),
        ] else ...[
          // Both active: show Face ID as primary + Use Fingerprints secondary
          _buildFaceIdBigCircle(),
        ],

        const SizedBox(height: 32),

        // If BOTH Face ID and Fingerprint are active: show "Use Fingerprints" button
        if (_hasFaceId && _hasFingerprint) ...[
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton(
              onPressed: _authenticateWithFingerprint,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: borderViolet, width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text(
                'Use Fingerprints',
                style: TextStyle(
                  color: brandViolet,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],

        // "Use password instead" purple button (matches mockup)
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: () {
              setState(() => _showPasswordFields = true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: brandViolet,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text(
              'Use password instead',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Biometric icons displayed when in standard login mode
  Widget _buildBiometricIconsRow() {
    if (_hasFingerprint && _hasFaceId) {
      // Both active: render both icons side by side
      return Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildFingerprintButton(),
              const SizedBox(width: 32),
              _buildFaceIdButton(),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Tap Fingerprint or Face ID to sign in',
            style: TextStyle(fontSize: 11.5, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w500),
          ),
        ],
      );
    } else if (_hasFingerprint) {
      // Fingerprint only
      return Column(
        children: [
          _buildFingerprintButton(),
          const SizedBox(height: 10),
          const Text(
            'Tap fingerprint sensor to sign in',
            style: TextStyle(fontSize: 11.5, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w500),
          ),
        ],
      );
    } else {
      // Face ID only
      return Column(
        children: [
          _buildFaceIdButton(),
          const SizedBox(height: 10),
          const Text(
            'Tap Face ID to glance and sign in',
            style: TextStyle(fontSize: 11.5, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w500),
          ),
        ],
      );
    }
  }

  Widget _buildFingerprintBigCircle() {
    return GestureDetector(
      onTap: _authenticateWithFingerprint,
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: borderViolet.withValues(alpha: 0.18),
              blurRadius: 22,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: const Center(
          child: Icon(
            Icons.fingerprint_rounded,
            size: 68,
            color: Color(0xFF4A10B4),
          ),
        ),
      ),
    );
  }

  Widget _buildFaceIdBigCircle() {
    return GestureDetector(
      onTap: _authenticateWithFaceId,
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: borderViolet.withValues(alpha: 0.18),
              blurRadius: 22,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Center(
          child: SizedBox(
            width: 54,
            height: 54,
            child: CustomPaint(
              painter: _FaceIdIconPainter(color: const Color(0xFF4A10B4)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFingerprintButton() {
    return GestureDetector(
      onTap: _authenticateWithFingerprint,
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: borderViolet.withValues(alpha: 0.14),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Center(
          child: Icon(
            Icons.fingerprint_rounded,
            size: 42,
            color: Color(0xFF4A10B4),
          ),
        ),
      ),
    );
  }

  Widget _buildFaceIdButton() {
    return GestureDetector(
      onTap: _authenticateWithFaceId,
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: borderViolet.withValues(alpha: 0.14),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: SizedBox(
            width: 36,
            height: 36,
            child: CustomPaint(
              painter: _FaceIdIconPainter(color: const Color(0xFF4A10B4)),
            ),
          ),
        ),
      ),
    );
  }
}

/// Face ID Vector Icon Painter
class _FaceIdIconPainter extends CustomPainter {
  final Color color;

  _FaceIdIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = size.width * 0.09
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final w = size.width;
    final h = size.height;
    final cornerLen = w * 0.26;
    final r = w * 0.14;

    // Top-left bracket
    final pathTL = Path()
      ..moveTo(0, cornerLen)
      ..lineTo(0, r)
      ..arcToPoint(Offset(r, 0), radius: Radius.circular(r))
      ..lineTo(cornerLen, 0);
    canvas.drawPath(pathTL, paint);

    // Top-right bracket
    final pathTR = Path()
      ..moveTo(w - cornerLen, 0)
      ..lineTo(w - r, 0)
      ..arcToPoint(Offset(w, r), radius: Radius.circular(r))
      ..lineTo(cornerLen, 0);
    canvas.drawPath(pathTR, paint);

    // Bottom-left bracket
    final pathBL = Path()
      ..moveTo(0, h - cornerLen)
      ..lineTo(0, h - r)
      ..arcToPoint(Offset(r, h), radius: Radius.circular(r))
      ..lineTo(cornerLen, h);
    canvas.drawPath(pathBL, paint);

    // Bottom-right bracket
    final pathBR = Path()
      ..moveTo(w - cornerLen, h)
      ..lineTo(w - r, h)
      ..arcToPoint(Offset(w, h - r), radius: Radius.circular(r))
      ..lineTo(w, h - cornerLen);
    canvas.drawPath(pathBR, paint);

    // Eyes
    final eyePaint = Paint()
      ..color = color
      ..strokeWidth = size.width * 0.08
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(w * 0.35, h * 0.38),
      Offset(w * 0.35, h * 0.46),
      eyePaint,
    );
    canvas.drawLine(
      Offset(w * 0.65, h * 0.38),
      Offset(w * 0.65, h * 0.46),
      eyePaint,
    );

    // Nose
    final nosePath = Path()
      ..moveTo(w * 0.50, h * 0.40)
      ..lineTo(w * 0.50, h * 0.56)
      ..lineTo(w * 0.44, h * 0.56);
    canvas.drawPath(nosePath, eyePaint);

    // Smile Arc
    final smileRect = Rect.fromCircle(
      center: Offset(w * 0.5, h * 0.54),
      radius: w * 0.18,
    );
    canvas.drawArc(smileRect, 0.45, 2.24, false, eyePaint);
  }

  @override
  bool shouldRepaint(covariant _FaceIdIconPainter oldDelegate) => oldDelegate.color != color;
}

/// Interactive Biometric Verification Modal
class _BiometricAuthModal extends StatefulWidget {
  final String title;
  final String subtitle;
  final Widget icon;
  final String authType;
  final VoidCallback onSuccess;

  const _BiometricAuthModal({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.authType,
    required this.onSuccess,
  });

  @override
  State<_BiometricAuthModal> createState() => _BiometricAuthModalState();
}

class _BiometricAuthModalState extends State<_BiometricAuthModal> {
  bool _verified = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) {
        setState(() => _verified = true);
        Future.delayed(const Duration(milliseconds: 500), widget.onSuccess);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFE5E7EB),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: _verified ? const Color(0xFFDCFCE7) : const Color(0xFFF3E8FF),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: _verified
                  ? const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 54)
                  : widget.icon,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            _verified ? '${widget.authType} Verified!' : widget.title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _verified ? 'Logging into Aura Bank...' : widget.subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 24),
          if (!_verified)
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w600),
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}