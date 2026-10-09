import 'package:flutter/material.dart';

import '../theme/aura_theme.dart';

/// Badge treatments. `violet` and `wine` are legacy names kept for existing
/// call sites; both now render the ink badge.
enum AuraLogoStyle { wine, violet, white, dark }

/// The Aura mark: an arch that reads as the letter A and as an aurora arc over
/// the horizon, crossed by the same ribbon that runs across the cards.
///
/// Drawn on a 64 unit grid so the SVG in `frontend/public/mark.svg` and this
/// painter stay the same shape.
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
    final onLight = style == AuraLogoStyle.white;
    return Semantics(
      label: 'Aura Bank',
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: AuraMarkPainter(badge: showBadgeContainer, lightBadge: onLight, radius: borderRadius),
        ),
      ),
    );
  }
}

class AuraMarkPainter extends CustomPainter {
  const AuraMarkPainter({this.badge = true, this.lightBadge = false, this.radius = 12});

  final bool badge;
  final bool lightBadge;
  final double radius;

  static Path arch(double u) => Path()
    ..moveTo(18 * u, 48 * u)
    ..cubicTo(18 * u, 29 * u, 24.5 * u, 15 * u, 32 * u, 15 * u)
    ..cubicTo(39.5 * u, 15 * u, 46 * u, 29 * u, 46 * u, 48 * u);

  static Path ribbon(double u) => Path()
    ..moveTo(22.5 * u, 37 * u)
    ..cubicTo(26.5 * u, 33 * u, 29.5 * u, 33 * u, 32 * u, 35.5 * u)
    ..cubicTo(34.5 * u, 38 * u, 37.5 * u, 38 * u, 41.5 * u, 34 * u);

  @override
  void paint(Canvas canvas, Size size) {
    final u = size.width / 64;
    final rect = Offset.zero & size;
    // Unbadged + lightBadge means the bare mark sits on a dark surface.
    final darkGround = badge ? !lightBadge : lightBadge;

    if (badge) {
      final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));
      canvas.drawRRect(rrect, Paint()..color = lightBadge ? Colors.white : AuraColors.ink);
      if (darkGround) {
        // A low glow on the horizon, so the badge reads as a night sky rather
        // than a flat tile.
        canvas.save();
        canvas.clipRRect(rrect);
        canvas.drawRect(
          rect,
          Paint()
            ..shader = RadialGradient(
              center: const Alignment(0, 1.1),
              radius: 0.9,
              colors: [AuraColors.mint.withValues(alpha: 0.28), AuraColors.mint.withValues(alpha: 0)],
            ).createShader(rect),
        );
        canvas.restore();
      }
    }

    final archColors = darkGround
        ? const [AuraColors.sky, AuraColors.mint]
        : const [AuraColors.accentVibrant, AuraColors.accent];

    canvas.drawPath(
      arch(u),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6.4 * u
        ..strokeCap = StrokeCap.round
        ..shader = LinearGradient(colors: archColors).createShader(Rect.fromLTWH(18 * u, 15 * u, 28 * u, 33 * u)),
    );
    canvas.drawPath(
      ribbon(u),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.6 * u
        ..strokeCap = StrokeCap.round
        ..color = darkGround ? Colors.white.withValues(alpha: 0.94) : AuraColors.ink,
    );
  }

  @override
  bool shouldRepaint(covariant AuraMarkPainter old) =>
      old.badge != badge || old.lightBadge != lightBadge || old.radius != radius;
}

/// Mark plus wordmark.
class AuraWordmark extends StatelessWidget {
  const AuraWordmark({super.key, this.size = 32, this.onDark = false});

  final double size;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AuraLogo(size: size, borderRadius: size * 0.28),
        SizedBox(width: size * 0.32),
        Text(
          'Aura',
          style: TextStyle(
            fontSize: size * 0.62,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.4,
            color: onDark ? Colors.white : AuraColors.ink,
          ),
        ),
      ],
    );
  }
}

/// Brand header used on statements and documents.
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
            color: AuraColors.ink,
            onPressed: onBack,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
          const SizedBox(width: 8),
        ],
        AuraLogo(size: 38, style: style, borderRadius: 11),
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
                  fontWeight: FontWeight.w600,
                  color: AuraColors.ink,
                  letterSpacing: -0.3,
                ),
              ),
              if (subtitle.isNotEmpty)
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AuraColors.textMuted),
                ),
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}
