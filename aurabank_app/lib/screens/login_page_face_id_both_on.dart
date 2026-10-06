import 'package:flutter/material.dart';

/// Custom Face ID Icon Widget matching the Aura Bank biometric design
class FaceIdIcon extends StatelessWidget {
  final double size;
  final Color color;
  final Color backgroundColor;

  const FaceIdIcon({
    super.key,
    this.size = 100.0,
    this.color = Colors.white,
    this.backgroundColor = const Color(0xFF380084),
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
            blurRadius: 18,
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

/// Screen: Login Page - Face ID - both on
class LoginPageFaceIdBothOn extends StatefulWidget {
  final VoidCallback? onFaceIdTap;
  final VoidCallback? onUseFingerprints;
  final VoidCallback? onUsePasswordInstead;
  final VoidCallback? onForgotPassword;
  final VoidCallback? onSwitchAccount;

  const LoginPageFaceIdBothOn({
    super.key,
    this.onFaceIdTap,
    this.onUseFingerprints,
    this.onUsePasswordInstead,
    this.onForgotPassword,
    this.onSwitchAccount,
  });

  @override
  State<LoginPageFaceIdBothOn> createState() => _LoginPageFaceIdBothOnState();
}

class _LoginPageFaceIdBothOnState extends State<LoginPageFaceIdBothOn> {
  @override
  Widget build(BuildContext context) {
    const brandViolet = Color(0xFF380084);
    const textGray = Color(0xFF6B7280);
    const linkGray = Color(0xFF9CA3AF);

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
                // Top section (Logo + Welcome Text)
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
                        color: textGray,
                      ),
                    ),
                  ],
                ),

                // Middle section: Face ID Biometric Icon
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40.0),
                  child: GestureDetector(
                    onTap: widget.onFaceIdTap,
                    child: const FaceIdIcon(
                      size: 104,
                      backgroundColor: brandViolet,
                    ),
                  ),
                ),

                // Bottom section: Action buttons and Footer Links
                Column(
                  children: [
                    // Button 1: "Use Fingerprints" (White with subtle shadow / purple text)
                    Container(
                      width: double.infinity,
                      height: 54,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                        border: Border.all(
                          color: const Color(0xFFE5E7EB),
                          width: 1,
                        ),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: widget.onUseFingerprints ?? () {},
                          child: const Center(
                            child: Text(
                              'Use Fingerprints',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: brandViolet,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Button 2: "Use password instead" (Violet with white text)
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: widget.onUsePasswordInstead ?? () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: brandViolet,
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
                            color: Colors.white,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 36),

                    // Footer Links: Forgot Passcode? • Switch Account
                    Padding(
                      padding: const EdgeInsets.only(bottom: 24.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          GestureDetector(
                            onTap: widget.onForgotPassword,
                            child: const Text(
                              'Forgot Passcode?',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: linkGray,
                              ),
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 10.0),
                            child: Text(
                              '•',
                              style: TextStyle(
                                fontSize: 16,
                                color: brandViolet,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: widget.onSwitchAccount,
                            child: const Text(
                              'Switch Account',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: brandViolet,
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
      ),
    );
  }
}
