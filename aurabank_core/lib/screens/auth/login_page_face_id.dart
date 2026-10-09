import 'package:flutter/material.dart';
import '../../services/auth_api_service.dart';
import '../../services/biometric_service.dart';
import '../../services/device_storage.dart';

/// Custom Face ID Icon Widget matching the Aura Bank biometric design
class FaceIdIcon extends StatelessWidget {
  final double size;
  final Color color;
  final Color backgroundColor;

  const FaceIdIcon({
    super.key,
    this.size = 64.0,
    this.color = Colors.white,
    this.backgroundColor = const Color(0xFF10171C),
  });



  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: backgroundColor.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Center(
        child: CustomPaint(
          size: Size(size * 0.58, size * 0.58),
          painter: _FaceIdPainter(color: color),
        ),
      ),
    );
  }
}

class _FaceIdPainter extends CustomPainter {
  final Color color;

  _FaceIdPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = size.width * 0.08
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final w = size.width;
    final h = size.height;
    final cornerLen = w * 0.24;
    final r = w * 0.12;

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
      ..lineTo(w, cornerLen);
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

    // Eyes (vertical dashes)
    final eyePaint = Paint()
      ..color = color
      ..strokeWidth = size.width * 0.075
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

    // Nose (small hook / line)
    final nosePath = Path()
      ..moveTo(w * 0.50, h * 0.40)
      ..lineTo(w * 0.50, h * 0.56)
      ..lineTo(w * 0.44, h * 0.56);
    canvas.drawPath(nosePath, eyePaint);

    // Smile Arc
    final smileRect = Rect.fromCircle(
      center: Offset(w * 0.5, h * 0.54),
      radius: w * 0.20,
    );
    canvas.drawArc(smileRect, 0.45, 2.24, false, eyePaint);
  }

  @override
  bool shouldRepaint(covariant _FaceIdPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Screen: Login Page - Face ID
class LoginPageFaceId extends StatefulWidget {
  final VoidCallback? onLoginSuccess;
  final VoidCallback? onFaceIdTap;
  final VoidCallback? onForgotPassword;
  final VoidCallback? onSwitchAccount;

  const LoginPageFaceId({
    super.key,
    this.onLoginSuccess,
    this.onFaceIdTap,
    this.onForgotPassword,
    this.onSwitchAccount,
  });

  @override
  State<LoginPageFaceId> createState() => _LoginPageFaceIdState();
}

class _LoginPageFaceIdState extends State<LoginPageFaceId> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleFaceIdAuth();
    });
  }

  Future<void> _handleFaceIdAuth() async {
    final biometric = BiometricService();
    final bool canAuth = await biometric.canAuthenticate();
    if (!canAuth) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Face ID is not available or not enrolled on this device.'),
            backgroundColor: Color(0xFFC8423B),
          ),
        );
      }
      return;
    }

    final bool success = await biometric.authenticate(
      reason: 'Glance at camera for Face ID to sign in to Aura Bank',
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
          content: Text('Face ID verification cancelled or not recognized. Tap to retry.'),
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

                    // Face ID Biometric Action Icon
                    GestureDetector(
                      onTap: widget.onFaceIdTap ?? _handleFaceIdAuth,
                      child: const FaceIdIcon(
                        size: 68,
                        backgroundColor: Color(0xFF10171C),
                        color: Colors.white,
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

