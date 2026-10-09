import 'package:flutter/material.dart';

enum AuraLogoStyle {
  wine, // Rich deep bordeaux wine (#4E0C1B -> #80142D)
  violet, // Regal imperial violet (#380084 -> #6312C9)
  white, // Monochrome crisp white (for dark backgrounds)
  dark, // Modern onyx slate (#181824)
}

/// Official Aura Bank Logo: "The Aura Horizon Monogram"
/// The signature vector mark featuring an architectural 'A' apex
/// fused with an orbital continuous radiant ribbon and central geometric spark.
class AuraLogo extends StatelessWidget {
  final double size;
  final AuraLogoStyle style;
  final bool showBadgeContainer;
  final double borderRadius;

  const AuraLogo({
    super.key,
    this.size = 44.0,
    this.style = AuraLogoStyle.violet,
    this.showBadgeContainer = true,
    this.borderRadius = 12.0,
  });

  @override
  Widget build(BuildContext context) {
    if (!showBadgeContainer) {
      return SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          size: Size(size, size),
          painter: _AuraMonogramPainter(style: style, standalone: true),
        ),
      );
    }

    final List<Color> bgGradient = switch (style) {
      AuraLogoStyle.wine => const [Color(0xFF4A0E17), Color(0xFF6B1224)],
      AuraLogoStyle.violet => const [Color(0xFF2E006A), Color(0xFF4B0FAF)],
      AuraLogoStyle.white => const [Colors.white, Color(0xFFF0F0F4)],
      AuraLogoStyle.dark => const [Color(0xFF1E1E28), Color(0xFF111118)],
    };

    final shadowColor = switch (style) {
      AuraLogoStyle.wine => const Color(0xFF4A0E17).withValues(alpha: 0.35),
      AuraLogoStyle.violet => const Color(0xFF380084).withValues(alpha: 0.35),
      AuraLogoStyle.white => Colors.black.withValues(alpha: 0.08),
      AuraLogoStyle.dark => Colors.black.withValues(alpha: 0.25),
    };

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: bgGradient,
        ),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: size * 0.25,
            offset: Offset(0, size * 0.1),
          ),
        ],
      ),
      child: Center(
        child: SizedBox(
          width: size * 0.62,
          height: size * 0.62,
          child: CustomPaint(
            painter: _AuraMonogramPainter(
              style: style,
              standalone: false,
            ),
          ),
        ),
      ),
    );
  }
}

class _AuraMonogramPainter extends CustomPainter {
  final AuraLogoStyle style;
  final bool standalone;

  _AuraMonogramPainter({required this.style, required this.standalone});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final Color strokeColor = (style == AuraLogoStyle.white && standalone)
        ? Colors.white
        : (!standalone && (style == AuraLogoStyle.wine || style == AuraLogoStyle.violet || style == AuraLogoStyle.dark))
            ? Colors.white
            : const Color(0xFF4A0E17);

    final Color accentColor = (style == AuraLogoStyle.wine)
        ? const Color(0xFFFFC2CD)
        : (style == AuraLogoStyle.violet)
            ? const Color(0xFFD4B5FF)
            : Colors.white;

    // 1. Draw the primary upward Architectural 'A' Chevron Vault
    final chevronPaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.14
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final chevronPath = Path();
    chevronPath.moveTo(w * 0.16, h * 0.88);
    chevronPath.lineTo(w * 0.50, h * 0.14);
    chevronPath.lineTo(w * 0.84, h * 0.88);
    canvas.drawPath(chevronPath, chevronPaint);

    // 2. Draw the continuous Horizon Aura Loop weaving through the crossbar
    final loopPaint = Paint()
      ..color = accentColor.withValues(alpha: standalone ? 0.9 : 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.09
      ..strokeCap = StrokeCap.round;

    final loopPath = Path();
    loopPath.moveTo(w * 0.08, h * 0.58);
    loopPath.cubicTo(
      w * 0.30, h * 0.42,
      w * 0.70, h * 0.74,
      w * 0.92, h * 0.58,
    );
    canvas.drawPath(loopPath, loopPaint);

    // 3. Central Cryptographic Diamond Spark (Apex Clarity)
    final sparkPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.fill;

    final sparkPath = Path();
    final cx = w * 0.50;
    final cy = h * 0.50;
    final sparkRadius = w * 0.10;

    sparkPath.moveTo(cx, cy - sparkRadius);
    sparkPath.quadraticBezierTo(cx, cy, cx + sparkRadius, cy);
    sparkPath.quadraticBezierTo(cx, cy, cx, cy + sparkRadius);
    sparkPath.quadraticBezierTo(cx, cy, cx - sparkRadius, cy);
    sparkPath.quadraticBezierTo(cx, cy, cx, cy - sparkRadius);
    canvas.drawPath(sparkPath, sparkPaint);
  }

  @override
  bool shouldRepaint(covariant _AuraMonogramPainter oldDelegate) =>
      oldDelegate.style != style || oldDelegate.standalone != standalone;
}

/// Brand Header component matching the Aura Bank statement & dashboard headers
class AuraBrandHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final AuraLogoStyle style;
  final Widget? trailing;
  final VoidCallback? onBack;

  const AuraBrandHeader({
    super.key,
    this.title = 'Aura Bank',
    this.subtitle = 'Interbank Network Ledger',
    this.style = AuraLogoStyle.violet,
    this.trailing,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (onBack != null) ...[
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            color: const Color(0xFF1E1E2D),
            onPressed: onBack,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
          const SizedBox(width: 8),
        ],
        AuraLogo(size: 38, style: style, borderRadius: 10),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF181824),
                  letterSpacing: -0.3,
                ),
              ),
              if (subtitle.isNotEmpty)
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF8A92A6),
                    letterSpacing: 0.1,
                  ),
                ),
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}
