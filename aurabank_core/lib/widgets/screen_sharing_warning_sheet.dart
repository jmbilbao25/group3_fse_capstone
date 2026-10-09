import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';

/// User decision actions available on the Screen Sharing warning sheet.
enum ScreenSharingUserAction {
  cancelTransaction,
  pauseFor10Minutes,
  continueAnyway,
}

/// Modal Bottom Sheet alerting users that active screen sharing or remote display
/// has been detected on their device, protecting against remote access scams.
class ScreenSharingWarningSheet extends StatelessWidget {
  final VoidCallback? onCancel;
  final VoidCallback? onPause;
  final VoidCallback? onContinue;

  const ScreenSharingWarningSheet({
    super.key,
    this.onCancel,
    this.onPause,
    this.onContinue,
  });

  /// Displays the screen sharing warning bottom sheet with a blurred backdrop.
  static Future<ScreenSharingUserAction?> show(
    BuildContext context, {
    VoidCallback? onCancel,
    VoidCallback? onPause,
    VoidCallback? onContinue,
  }) {
    return showModalBottomSheet<ScreenSharingUserAction>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6.0, sigmaY: 6.0),
        child: ScreenSharingWarningSheet(
          onCancel: () {
            Navigator.of(ctx).pop(ScreenSharingUserAction.cancelTransaction);
            onCancel?.call();
          },
          onPause: () {
            Navigator.of(ctx).pop(ScreenSharingUserAction.pauseFor10Minutes);
            onPause?.call();
          },
          onContinue: () {
            Navigator.of(ctx).pop(ScreenSharingUserAction.continueAnyway);
            onContinue?.call();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const brandPurple = Color(0xFF32007D);

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 28.0),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1B1E26) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28.0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(isDark ? 80 : 35),
              blurRadius: 24,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Center Yellow/Amber Squircle Badge with Screen Sharing Phone Icon
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: const Color(0xFFFEFCE8),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: const Color(0xFFFACC15),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFACC15).withAlpha(40),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Center(
                child: CustomPaint(
                  size: const Size(42, 42),
                  painter: _ScreenShareIconPainter(),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Header Title
            Text(
              'Screen Sharing is active',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF10171C),
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 12),

            // Explanatory Scam Warning
            Text.rich(
              TextSpan(
                style: TextStyle(
                  fontSize: 14.5,
                  height: 1.45,
                  color: isDark ? const Color(0xFFD5DADF) : const Color(0xFF334155),
                ),
                children: [
                  const TextSpan(
                    text: 'An app is currently sharing or viewing your screen.\n',
                  ),
                  TextSpan(
                    text: 'Aura Bank will never ask you to share your screen',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF10171C),
                    ),
                  ),
                  const TextSpan(
                    text: ' or transfer money to protect your account',
                  ),
                ],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 26),

            // Primary Button: Cancel Transaction
            SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton(
                key: const Key('screen_sharing_cancel_btn'),
                style: FilledButton.styleFrom(
                  backgroundColor: brandPurple,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () {
                  if (onCancel != null) {
                    onCancel!();
                  } else {
                    Navigator.of(context).pop(ScreenSharingUserAction.cancelTransaction);
                  }
                },
                child: const Text(
                  'Cancel Transaction',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Secondary Button: Pause for 10 minutes
            SizedBox(
              width: double.infinity,
              height: 54,
              child: OutlinedButton(
                key: const Key('screen_sharing_pause_btn'),
                style: OutlinedButton.styleFrom(
                  backgroundColor: isDark ? const Color(0xFF262C38) : Colors.white,
                  foregroundColor: isDark ? const Color(0xFF93A8FF) : brandPurple,
                  side: BorderSide(
                    color: isDark ? const Color(0xFF384357) : const Color(0xFFE6E8EA),
                    width: 1.5,
                  ),
                  elevation: isDark ? 0 : 1,
                  shadowColor: Colors.black.withAlpha(20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () {
                  if (onPause != null) {
                    onPause!();
                  } else {
                    Navigator.of(context).pop(ScreenSharingUserAction.pauseFor10Minutes);
                  }
                },
                child: Text(
                  'Pause for 10 minutes',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isDark ? const Color(0xFF93A8FF) : brandPurple,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Footer Tertiary Row: "I am not sharing my screen • Continue"
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'I am not sharing my screen',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: isDark ? const Color(0xFF9AA3AB) : const Color(0xFF6E7882),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text(
                    '•',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: isDark ? const Color(0xFF6E7882) : const Color(0xFF9AA3AB),
                    ),
                  ),
                ),
                InkWell(
                  key: const Key('screen_sharing_continue_link'),
                  borderRadius: BorderRadius.circular(4),
                  onTap: () {
                    if (onContinue != null) {
                      onContinue!();
                    } else {
                      Navigator.of(context).pop(ScreenSharingUserAction.continueAnyway);
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
                    child: Text(
                      'Continue',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: isDark ? const Color(0xFF93A8FF) : brandPurple,
                        decoration: TextDecoration.underline,
                        decorationColor: isDark ? const Color(0xFF93A8FF) : brandPurple,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }
}

/// Custom painter that renders a sharp vector smartphone outline with an
/// active broadcast / screen transmission badge in warm orange and red.
class _ScreenShareIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Outer phone frame in warm orange
    final phonePaint = Paint()
      ..color = const Color(0xFFEA580C)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final phoneRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(w * 0.48, h * 0.52),
        width: w * 0.54,
        height: h * 0.72,
      ),
      const Radius.circular(7.0),
    );
    canvas.drawRRect(phoneRect, phonePaint);

    // Bottom home indicator bar
    final homePaint = Paint()
      ..color = const Color(0xFFEA580C)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(w * 0.40, h * 0.78),
      Offset(w * 0.56, h * 0.78),
      homePaint,
    );

    // Screen sharing broadcast signal dot at top-right
    final signalDotCenter = Offset(w * 0.68, h * 0.28);

    // White backing cutout behind the dot to ensure clear visibility
    final backingPaint = Paint()
      ..color = const Color(0xFFFEFCE8)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(signalDotCenter, 5.0, backingPaint);

    // Glowing signal dot in vibrant red/orange
    final dotPaint = Paint()
      ..color = const Color(0xFFC8423B)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(signalDotCenter, 3.2, dotPaint);

    // Radiating broadcast wave arc
    final wavePaint = Paint()
      ..color = const Color(0xFFC8423B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;

    // Small upper broadcast arc
    final waveRect = Rect.fromCircle(center: signalDotCenter, radius: 6.8);
    canvas.drawArc(waveRect, -1.2, 1.4, false, wavePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
