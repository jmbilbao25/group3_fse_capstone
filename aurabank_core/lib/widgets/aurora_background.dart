import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/aura_theme.dart';

/// Northern lights over an ink sky.
///
/// Three curtains drift on one slow loop. Each curtain is a single stroked
/// path with a mask blur, so a frame costs three blurred draws regardless of
/// screen size, and the painter repaints off the controller without a widget
/// rebuild. Phases advance by whole turns per loop, so the cycle has no seam.
///
/// Under reduced motion the sky holds a single composed frame.
class AuroraBackground extends StatefulWidget {
  const AuroraBackground({
    super.key,
    this.child,
    this.intensity = 1,
    this.period = const Duration(seconds: 26),
  });

  final Widget? child;

  /// 0 to 1. Lower values keep the sky behind dense content.
  final double intensity;
  final Duration period;

  @override
  State<AuroraBackground> createState() => _AuroraBackgroundState();
}

class _AuroraBackgroundState extends State<AuroraBackground> with SingleTickerProviderStateMixin {
  late final AnimationController _loop = AnimationController(vsync: this, duration: widget.period);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AuraMotion.reduced(context)) {
      _loop
        ..stop()
        ..value = 0.18;
    } else if (!_loop.isAnimating) {
      _loop.repeat();
    }
  }

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(
          child: CustomPaint(
            painter: AuroraPainter(progress: _loop, intensity: widget.intensity),
            isComplex: true,
            willChange: true,
          ),
        ),
        if (widget.child != null) widget.child!,
      ],
    );
  }
}

class _Curtain {
  const _Curtain({
    required this.base,
    required this.amplitude,
    required this.waves,
    required this.turns,
    required this.width,
    required this.colors,
    required this.offset,
  });

  /// Vertical centre as a share of height.
  final double base;
  final double amplitude;

  /// Wave count across the width.
  final double waves;

  /// Whole phase turns per loop. Integers keep the loop seamless.
  final int turns;
  final double width;
  final List<Color> colors;
  final double offset;
}

class AuroraPainter extends CustomPainter {
  AuroraPainter({required Animation<double> progress, this.intensity = 1})
      : _progress = progress,
        super(repaint: progress);

  final Animation<double> _progress;
  final double intensity;

  static const _curtains = [
    _Curtain(
      base: 0.30,
      amplitude: 0.07,
      waves: 1.2,
      turns: 1,
      width: 0.20,
      colors: [Color(0x0097CFF3), AuraColors.sky, AuraColors.mint, Color(0x00A7E8D1)],
      offset: 0,
    ),
    _Curtain(
      base: 0.46,
      amplitude: 0.09,
      waves: 0.9,
      turns: -1,
      width: 0.16,
      colors: [Color(0x00A7E8D1), AuraColors.mint, Color(0xFF7FD6C0), Color(0x0097CFF3)],
      offset: 1.9,
    ),
    _Curtain(
      base: 0.18,
      amplitude: 0.05,
      waves: 1.6,
      turns: 2,
      width: 0.10,
      colors: [Color(0x00BEC6F7), AuraColors.periwinkle, AuraColors.sky, Color(0x0097CFF3)],
      offset: 3.4,
    ),
  ];

  static const int _samples = 28;

  /// Fixed star positions (unit square) from a seeded generator, so the sky
  /// is the same on every launch and no allocation happens per frame.
  static final List<Offset> _stars = () {
    final r = math.Random(7);
    return List.generate(46, (_) => Offset(r.nextDouble(), r.nextDouble() * 0.62));
  }();
  Float32List? _starBuf;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final t = _progress.value * math.pi * 2;
    final h = size.height;
    final w = size.width;
    final unit = math.min(w, h * 1.4);

    canvas.drawRect(rect, Paint()..color = AuraColors.ink);

    // Stars: three brightness groups twinkle out of phase. Three batched
    // drawRawPoints calls in total, whatever the screen size.
    final buf = _starBuf ??= Float32List(_stars.length * 2);
    for (var g = 0; g < 3; g++) {
      var n = 0;
      for (var i = g; i < _stars.length; i += 3) {
        buf[n++] = _stars[i].dx * w;
        buf[n++] = _stars[i].dy * h;
      }
      final twinkle = 0.35 + 0.35 * (0.5 + 0.5 * math.sin(t * 3 + g * 2.1));
      canvas.drawRawPoints(
        ui.PointMode.points,
        Float32List.sublistView(buf, 0, n),
        Paint()
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 1.2 + g * 0.5
          ..color = Colors.white.withValues(alpha: twinkle * intensity),
      );
    }

    for (final c in _curtains) {
      final path = Path();
      for (var i = 0; i <= _samples; i++) {
        final x = w * (i / _samples) * 1.2 - w * 0.1;
        final phase = (x / w) * math.pi * 2 * c.waves + c.offset + t * c.turns;
        final y = h * c.base +
            h * c.amplitude * math.sin(phase) +
            h * c.amplitude * 0.35 * math.sin(phase * 2.1 + t * c.turns);
        i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
      }
      final shimmer = 0.78 + 0.22 * math.sin(t * c.turns + c.offset);
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = unit * c.width
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, unit * c.width * 0.26)
          ..shader = LinearGradient(colors: c.colors)
              .createShader(rect)
          ..color = Color.fromRGBO(255, 255, 255, (0.78 * shimmer * intensity).clamp(0, 1)),
      );
    }

    // The horizon. Holds the bottom of the sky so content there stays legible.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AuraColors.ink.withValues(alpha: 0.10),
            AuraColors.ink.withValues(alpha: 0),
            AuraColors.ink.withValues(alpha: 0.55),
            AuraColors.ink.withValues(alpha: 0.92),
          ],
          stops: const [0, 0.32, 0.72, 1],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant AuroraPainter old) => old.intensity != intensity || old._progress != _progress;
}
