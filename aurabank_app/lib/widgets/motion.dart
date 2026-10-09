import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/aura_theme.dart';

/// Motion primitives. Everything animates transform and opacity only, uses
/// one controller per effect, and collapses to the final state under reduced
/// motion.

/// Scales down while pressed. Wrap any tappable surface.
class Pressable extends StatefulWidget {
  const Pressable(
      {super.key,
      required this.child,
      this.onTap,
      this.scale = 0.96,
      this.haptic = true});

  final Widget child;
  final VoidCallback? onTap;
  final double scale;
  final bool haptic;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => _set(true) : null,
      onTapUp: enabled ? (_) => _set(false) : null,
      onTapCancel: enabled ? () => _set(false) : null,
      onTap: enabled
          ? () {
              if (widget.haptic) HapticFeedback.lightImpact();
              widget.onTap!();
            }
          : null,
      child: AnimatedScale(
        scale: _down && !AuraMotion.reduced(context) ? widget.scale : 1,
        duration: _down ? const Duration(milliseconds: 90) : AuraMotion.medium,
        curve: _down ? Curves.easeOut : AuraMotion.emphasized,
        child: widget.child,
      ),
    );
  }
}

/// Fades and rises into place once, after [delay]. Use [Reveal.stagger] for
/// list rows so the total cascade stays short however long the list is.
class Reveal extends StatefulWidget {
  const Reveal({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.offset = 16,
    this.duration = const Duration(milliseconds: 520),
  });

  /// Delay for item [i]: 45 ms apart, capped so the last row is never late.
  static Duration stagger(int i, {int base = 0}) =>
      Duration(milliseconds: base + (i.clamp(0, 6) * 45));

  final Widget child;
  final Duration delay;
  final double offset;
  final Duration duration;

  @override
  State<Reveal> createState() => _RevealState();
}

class _RevealState extends State<Reveal> with SingleTickerProviderStateMixin {
  // The delay is folded into one controller as a leading Interval, so a
  // cascade costs no timers and nothing outlives the widget.
  late final AnimationController _c = AnimationController(vsync: this, duration: widget.delay + widget.duration);
  late final Animation<double> _t = CurvedAnimation(
    parent: _c,
    curve: Interval(widget.delay.inMicroseconds / (widget.delay + widget.duration).inMicroseconds, 1,
        curve: AuraMotion.emphasized),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AuraMotion.reduced(context)) {
      _c.value = 1;
    } else if (_c.status == AnimationStatus.dismissed) {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _t,
      child: widget.child,
      builder: (context, child) => Opacity(
        opacity: _t.value,
        alwaysIncludeSemantics: true,
        child: Transform.translate(offset: Offset(0, widget.offset * (1 - _t.value)), child: child),
      ),
    );
  }
}

/// Counts a currency value up to [value] the first time it is shown, then
/// rolls between values when it changes. Tabular figures keep width stable.
class CountUpText extends StatelessWidget {
  const CountUpText(
      {super.key,
      required this.value,
      required this.format,
      required this.style});

  final double value;
  final String Function(double) format;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final s =
        style.copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
    if (AuraMotion.reduced(context)) return Text(format(value), style: s);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: value * 0.92, end: value),
      duration: const Duration(milliseconds: 1100),
      curve: AuraMotion.emphasized,
      builder: (context, v, _) => Text(format(v), style: s),
    );
  }
}

/// Fade-through for switching between sibling views (tabs). The incoming view
/// fades up from 98% scale; the outgoing one simply fades.
class FadeThrough extends StatelessWidget {
  const FadeThrough({super.key, required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (AuraMotion.reduced(context)) return child;
    return TweenAnimationBuilder<double>(
      key: ValueKey(index),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 280),
      curve: AuraMotion.emphasized,
      child: child,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.scale(scale: 0.985 + 0.015 * t, child: child),
      ),
    );
  }
}

/// Draws a check mark stroke by stroke inside a filled disc. One-shot.
class AnimatedCheck extends StatelessWidget {
  const AnimatedCheck(
      {super.key,
      this.size = 88,
      this.color = AuraColors.mint,
      this.success = true});

  final double size;
  final Color color;
  final bool success;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: AuraMotion.reduced(context) ? 1 : 0, end: 1),
      duration: const Duration(milliseconds: 900),
      builder: (context, t, _) => RepaintBoundary(
        child: CustomPaint(
            size: Size.square(size), painter: _CheckPainter(t, color, success)),
      ),
    );
  }
}

class _CheckPainter extends CustomPainter {
  _CheckPainter(this.t, this.color, this.success);
  final double t;
  final Color color;
  final bool success;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    // Disc pops in over the first 40%, with a soft halo ring that expands and fades.
    final disc = AuraMotion.emphasized.transform((t / 0.4).clamp(0.0, 1.0));
    final halo = (t / 0.7).clamp(0.0, 1.0);
    canvas.drawCircle(c, r * (0.7 + 0.45 * halo),
        Paint()..color = color.withValues(alpha: 0.35 * (1 - halo)));
    canvas.drawCircle(c, r * disc, Paint()..color = color);

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = size.width * 0.075
      ..color = AuraColors.ink;
    final draw =
        Curves.easeOutCubic.transform(((t - 0.35) / 0.55).clamp(0.0, 1.0));
    final path = success
        ? (Path()
          ..moveTo(c.dx - r * 0.36, c.dy + r * 0.02)
          ..lineTo(c.dx - r * 0.1, c.dy + r * 0.28)
          ..lineTo(c.dx + r * 0.38, c.dy - r * 0.24))
        : (Path()
          ..moveTo(c.dx - r * 0.28, c.dy - r * 0.28)
          ..lineTo(c.dx + r * 0.28, c.dy + r * 0.28)
          ..moveTo(c.dx + r * 0.28, c.dy - r * 0.28)
          ..lineTo(c.dx - r * 0.28, c.dy + r * 0.28));
    for (final m in path.computeMetrics()) {
      canvas.drawPath(m.extractPath(0, m.length * draw), stroke);
    }
  }

  @override
  bool shouldRepaint(covariant _CheckPainter old) => old.t != t;
}
