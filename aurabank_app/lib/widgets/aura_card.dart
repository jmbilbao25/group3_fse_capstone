import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/bank_models.dart';
import '../theme/aura_theme.dart';
import 'aura_logo.dart';
import 'motion.dart';

/// Card system, ported from the Banking-App-Test deck and restyled for Aura.
///
/// The physics are the original's: a swipe turns cards about their vertical
/// axis instead of sliding them, a flip swaps faces at the edge-on midpoint,
/// and the specular highlight travels with the page offset. The material is
/// new: ink stock with an aurora ribbon and a low horizon bloom.

/// ISO/IEC 7810 ID-1 proportion.
const double kCardAspect = 85.60 / 53.98;

/// Ribbon hues per card, chosen from the card id so a card keeps its look
/// wherever it sits in the deck.
class CardColourway {
  const CardColourway(this.ribbon, this.bloom);
  final List<Color> ribbon;
  final List<Color> bloom;
}

const _colourways = [
  CardColourway(
      [AuraColors.sky, AuraColors.mint], [AuraColors.sky, AuraColors.mint]),
  CardColourway([AuraColors.mint, Color(0xFF7FD6C0)],
      [Color(0xFF6FC7B0), AuraColors.mint]),
  CardColourway([AuraColors.periwinkle, AuraColors.sky],
      [AuraColors.periwinkle, AuraColors.sky]),
];

CardColourway colourwayFor(String id) {
  var hash = 0;
  for (final unit in id.codeUnits) {
    hash = (hash * 31 + unit) & 0xffffff;
  }
  return _colourways[hash % _colourways.length];
}

/// Scheme marks. Visa is the bundled word mark on a white plate; Mastercard
/// is drawn from its published geometry.
class NetworkMark extends StatelessWidget {
  const NetworkMark({super.key, required this.network, required this.width});

  final CardNetwork network;
  final double width;

  static const double _aspect = 1.55;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: network.label,
      child: ExcludeSemantics(
        child: SizedBox(
          width: width,
          height: width / _aspect,
          child: switch (network) {
            CardNetwork.mastercard =>
              const CustomPaint(painter: _MastercardPainter()),
            CardNetwork.visa => DecoratedBox(
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(width * 0.1)),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                      horizontal: width * 0.12, vertical: width * 0.1),
                  child: Image.asset('assets/brand/visa.webp',
                      fit: BoxFit.contain, filterQuality: FilterQuality.medium),
                ),
              ),
          },
        ),
      ),
    );
  }
}

class _MastercardPainter extends CustomPainter {
  const _MastercardPainter();

  static final Paint _red = Paint()..color = const Color(0xFFEB001B);
  static final Paint _yellow = Paint()..color = const Color(0xFFF79E1B);
  static final Paint _overlap = Paint()..color = const Color(0xFFFF5F00);
  static Size? _cachedSize;
  static Path? _cachedOverlap;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.height / 2;
    final left = Rect.fromCircle(center: Offset(r, r), radius: r);
    final right = Rect.fromCircle(center: Offset(size.width - r, r), radius: r);
    if (_cachedSize != size) {
      _cachedSize = size;
      _cachedOverlap = Path.combine(PathOperation.intersect,
          Path()..addOval(left), Path()..addOval(right));
    }
    canvas
      ..drawOval(left, _red)
      ..drawOval(right, _yellow)
      ..drawPath(_cachedOverlap!, _overlap);
  }

  @override
  bool shouldRepaint(covariant _MastercardPainter oldDelegate) => false;
}

/// The stock: ink, a horizon bloom and the aurora ribbon. [sheen] runs -1..1
/// and moves the highlight across the face.
class _CardStockPainter extends CustomPainter {
  const _CardStockPainter(
      {required this.colourway,
      this.sheen = 0,
      this.ribbon = true,
      this.frozen = false});

  final CardColourway colourway;
  final double sheen;
  final bool ribbon;
  final bool frozen;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final w = size.width;
    final h = size.height;

    canvas.drawRect(rect, Paint()..color = AuraColors.ink);

    // Horizon bloom off the lower left, the way the aurora sits low on the sky.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.95, 1.25),
          radius: 1.05,
          colors: [
            colourway.bloom.first.withValues(alpha: 0.85),
            colourway.bloom.last.withValues(alpha: 0.32),
            colourway.bloom.last.withValues(alpha: 0),
          ],
          stops: const [0, 0.42, 1],
        ).createShader(rect),
    );

    if (ribbon) {
      final path = Path()
        ..moveTo(w * 0.70, -h * 0.08)
        ..cubicTo(w * 0.64, h * 0.16, w * 0.90, h * 0.20, w * 0.84, h * 0.40)
        ..cubicTo(w * 0.79, h * 0.56, w * 0.94, h * 0.64, w * 1.06, h * 0.50);
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = w * 0.034
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomRight,
            colors: colourway.ribbon,
          ).createShader(rect),
      );
    }

    // Specular sheen, travelling with the swipe or the pointer.
    final x = sheen * 0.9;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment(x - 1.4, -1),
          end: Alignment(x + 0.6, 1),
          colors: [
            Colors.white.withValues(alpha: 0),
            Colors.white.withValues(alpha: 0.10),
            Colors.white.withValues(alpha: 0),
          ],
          stops: const [0.34, 0.5, 0.66],
        ).createShader(rect),
    );

    if (frozen) {
      canvas.drawRect(rect,
          Paint()..color = const Color(0xFFDDEAF3).withValues(alpha: 0.38));
    }

    // Milled edge.
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.deflate(0.5), Radius.circular(w * 0.055)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.white.withValues(alpha: 0.10),
    );
  }

  @override
  bool shouldRepaint(covariant _CardStockPainter old) =>
      old.sheen != sheen ||
      old.colourway != colourway ||
      old.ribbon != ribbon ||
      old.frozen != frozen;
}

BoxDecoration _cardShadow(double lift) => BoxDecoration(
      boxShadow: [
        BoxShadow(
          color: AuraColors.ink.withValues(alpha: 0.30 * lift),
          blurRadius: 30 * lift,
          spreadRadius: -6,
          offset: Offset(0, 16 * lift),
        ),
      ],
    );

/// Front of a card. Pass [balance] to show it on the face, as on the wallet.
class AuraCardFace extends StatelessWidget {
  const AuraCardFace({
    super.key,
    required this.card,
    this.sheen = 0,
    this.lift = 1,
    this.balance,
    this.balanceValue,
    this.formatBalance,
    this.balanceVisible = true,
    this.onToggleBalance,
  });

  final BankCard card;
  final double sheen;
  final double lift;
  final String? balance;

  /// When set with [formatBalance], the balance counts up on first show.
  final double? balanceValue;
  final String Function(double)? formatBalance;
  final bool balanceVisible;
  final VoidCallback? onToggleBalance;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth;
      final radius = BorderRadius.circular(w * 0.055);
      final pad = w * 0.065;
      final onInk = Colors.white.withValues(alpha: 0.62);

      return DecoratedBox(
        decoration: _cardShadow(lift).copyWith(borderRadius: radius),
        child: ClipRRect(
          borderRadius: radius,
          child: CustomPaint(
            painter: _CardStockPainter(
                colourway: colourwayFor(card.id),
                sheen: sheen,
                frozen: card.isLocked),
            child: Padding(
              padding: EdgeInsets.all(pad),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (balance != null)
                        Text('Balance',
                            style: TextStyle(
                                color: onInk,
                                fontSize: w * 0.04,
                                fontWeight: FontWeight.w500))
                      else
                        AuraLogo(
                            size: w * 0.085,
                            borderRadius: w * 0.022,
                            style: AuraLogoStyle.white,
                            showBadgeContainer: false),
                      const Spacer(),
                      if (card.isLocked)
                        _Chip(label: 'Frozen', fontSize: w * 0.034)
                      else
                        Icon(Icons.contactless_outlined,
                            color: Colors.white.withValues(alpha: 0.85),
                            size: w * 0.07),
                    ],
                  ),
                  if (balance != null) ...[
                    SizedBox(height: w * 0.015),
                    GestureDetector(
                      onTap: onToggleBalance,
                      behavior: HitTestBehavior.opaque,
                      child: AnimatedSwitcher(
                        duration: AuraMotion.resolve(context, AuraMotion.fast),
                        child: FittedBox(
                          key: ValueKey(balanceVisible),
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: balanceVisible &&
                                  balanceValue != null &&
                                  formatBalance != null
                              ? CountUpText(
                                  value: balanceValue!,
                                  format: formatBalance!,
                                  style: _balanceStyle(w))
                              : Text(balanceVisible ? balance! : '₱ ••••••',
                                  style: _balanceStyle(w)),
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  Text(
                    '••••  ${card.last4}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.86),
                      fontSize: w * 0.045,
                      letterSpacing: 1.2,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  SizedBox(height: w * 0.012),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Text(
                          card.holderName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: onInk,
                              fontSize: w * 0.04,
                              fontWeight: FontWeight.w500),
                        ),
                      ),
                      NetworkMark(network: card.network, width: w * 0.15),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }
}

TextStyle _balanceStyle(double w) => TextStyle(
      color: Colors.white,
      fontSize: w * 0.092,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.6,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.fontSize});
  final String label;
  final double fontSize;

  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.symmetric(
            horizontal: fontSize * 0.8, vertical: fontSize * 0.3),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(99)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.ac_unit_rounded,
              size: fontSize * 1.1, color: AuraColors.ink),
          SizedBox(width: fontSize * 0.3),
          Text(label,
              style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w600,
                  color: AuraColors.ink)),
        ]),
      );
}

/// Back of a card: stripe, signature panel with CVV, full number and expiry.
class AuraCardBack extends StatelessWidget {
  const AuraCardBack({super.key, required this.card, this.lift = 1});

  final BankCard card;
  final double lift;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth;
      final radius = BorderRadius.circular(w * 0.055);
      final pad = w * 0.065;
      final label = TextStyle(
          color: Colors.white.withValues(alpha: 0.56),
          fontSize: w * 0.032,
          letterSpacing: 1);
      final value = TextStyle(
        color: Colors.white,
        fontSize: w * 0.055,
        fontWeight: FontWeight.w500,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

      return DecoratedBox(
        decoration: _cardShadow(lift).copyWith(borderRadius: radius),
        child: ClipRRect(
          borderRadius: radius,
          child: CustomPaint(
            painter: _CardStockPainter(
                colourway: colourwayFor(card.id),
                ribbon: false,
                frozen: card.isLocked),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: pad * 0.8),
                Container(
                    height: w * 0.13,
                    color: Colors.black.withValues(alpha: 0.55)),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(pad, pad * 0.8, pad, pad),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('CARD NUMBER', style: label),
                        SizedBox(height: w * 0.01),
                        FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(card.cardNumber,
                                style: value.copyWith(letterSpacing: 1.4))),
                        const Spacer(),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('EXPIRES', style: label),
                                  Text(card.expiry, style: value),
                                ]),
                            SizedBox(width: w * 0.08),
                            Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('CVV', style: label),
                                  Text(card.cvv, style: value),
                                ]),
                            const Spacer(),
                            NetworkMark(network: card.network, width: w * 0.15),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
}

/// Turns a card over. Linear, so the face swap lands exactly mid-turn, and the
/// incoming face is counter-rotated so its type is never mirrored.
class FlipCard extends StatelessWidget {
  const FlipCard(
      {super.key,
      required this.showBack,
      required this.front,
      required this.back});

  final bool showBack;
  final Widget front;
  final Widget back;

  @override
  Widget build(BuildContext context) {
    if (AuraMotion.reduced(context)) return showBack ? back : front;
    return TweenAnimationBuilder<double>(
      tween: Tween(end: showBack ? 1 : 0),
      duration: const Duration(milliseconds: 520),
      curve: Curves.linear,
      builder: (context, t, _) {
        final past = t >= 0.5;
        final angle = t * math.pi;
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.0013)
            ..rotateY(past ? angle - math.pi : angle),
          filterQuality: FilterQuality.medium,
          child: past ? back : front,
        );
      },
    );
  }
}

/// Tilts a card toward the pointer (web, desktop) or the finger, and feeds the
/// tilt into the sheen. Springs back on release.
class CardTilt extends StatefulWidget {
  const CardTilt({super.key, required this.builder, this.maxTilt = 0.16});

  final Widget Function(BuildContext context, double sheen) builder;
  final double maxTilt;

  @override
  State<CardTilt> createState() => _CardTiltState();
}

class _CardTiltState extends State<CardTilt>
    with SingleTickerProviderStateMixin {
  final ValueNotifier<Offset> _tilt = ValueNotifier(Offset.zero);
  late final AnimationController _settle = AnimationController(
      vsync: this, duration: AuraMotion.medium)
    ..addListener(() => _tilt.value = Offset.lerp(
        _from, Offset.zero, AuraMotion.emphasized.transform(_settle.value))!);
  Offset _from = Offset.zero;

  void _track(Offset local, Size size) {
    _settle.stop();
    _tilt.value = Offset(
      ((local.dx / size.width) * 2 - 1).clamp(-1.0, 1.0),
      ((local.dy / size.height) * 2 - 1).clamp(-1.0, 1.0),
    );
  }

  void _release() {
    _from = _tilt.value;
    _settle.forward(from: 0);
  }

  @override
  void dispose() {
    _settle.dispose();
    _tilt.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (AuraMotion.reduced(context)) return widget.builder(context, 0);
    return LayoutBuilder(builder: (context, c) {
      final size = c.biggest;
      return MouseRegion(
        onHover: (e) => _track(e.localPosition, size),
        onExit: (_) => _release(),
        child: Listener(
          onPointerDown: (e) => _track(e.localPosition, size),
          onPointerMove: (e) => _track(e.localPosition, size),
          onPointerUp: (_) => _release(),
          onPointerCancel: (_) => _release(),
          child: ValueListenableBuilder<Offset>(
            valueListenable: _tilt,
            builder: (context, t, _) => Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.0012)
                ..rotateX(-t.dy * widget.maxTilt)
                ..rotateY(t.dx * widget.maxTilt),
              child: widget.builder(context, t.dx),
            ),
          ),
        ),
      );
    });
  }
}

/// A swipeable deck. Cards turn away from the finger rather than sliding, and
/// every transform is a continuous function of the page offset, so the deck
/// tracks the gesture and never snaps.
class AuraCardCarousel extends StatefulWidget {
  const AuraCardCarousel({
    super.key,
    required this.cards,
    required this.onPageChanged,
    this.onCardTap,
    this.revealedCardId,
    this.initialIndex = 0,
    this.viewportFraction = 0.78,
    this.maxCardWidth = 360,
  });

  final List<BankCard> cards;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<BankCard>? onCardTap;
  final String? revealedCardId;
  final int initialIndex;
  final double viewportFraction;
  final double maxCardWidth;

  @override
  State<AuraCardCarousel> createState() => _AuraCardCarouselState();
}

class _AuraCardCarouselState extends State<AuraCardCarousel> {
  late final PageController _controller = PageController(
      initialPage: widget.initialIndex,
      viewportFraction: widget.viewportFraction)
    ..addListener(_onScroll);
  late final ValueNotifier<double> _page =
      ValueNotifier(widget.initialIndex.toDouble());
  late int _settled = widget.initialIndex;

  void _onScroll() {
    final value = _controller.hasClients && _controller.position.haveDimensions
        ? _controller.page
        : null;
    if (value == null) return;
    _page.value = value;
    final settled = value.round().clamp(0, widget.cards.length - 1);
    if (settled != _settled) {
      _settled = settled;
      HapticFeedback.selectionClick();
      widget.onPageChanged(settled);
    }
  }

  void _tap(int index) {
    if (index != _page.value.round()) {
      if (AuraMotion.reduced(context)) return _controller.jumpToPage(index);
      _controller.animateToPage(index,
          duration: AuraMotion.resolve(context, AuraMotion.medium),
          curve: AuraMotion.emphasized);
      return;
    }
    widget.onCardTap?.call(widget.cards[index]);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onScroll)
      ..dispose();
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = AuraMotion.reduced(context);
    return LayoutBuilder(builder: (context, c) {
      final cardWidth = math.min(
          c.maxWidth * widget.viewportFraction - 16, widget.maxCardWidth);
      final cardHeight = cardWidth / kCardAspect;
      return Column(
        children: [
          SizedBox(
            height: cardHeight + 36,
            child: PageView.builder(
              controller: _controller,
              clipBehavior: Clip.none,
              itemCount: widget.cards.length,
              itemBuilder: (context, index) {
                final card = widget.cards[index];
                return Center(
                  child: ValueListenableBuilder<double>(
                    valueListenable: _page,
                    builder: (context, page, _) {
                      final d = (page - index).clamp(-1.6, 1.6);
                      final distance = d.abs();
                      final lift = (1 - distance * 0.6).clamp(0.25, 1.0);
                      final face = SizedBox(
                        width: cardWidth,
                        height: cardHeight,
                        child: Semantics(
                          button: true,
                          label:
                              '${card.title}, ${card.network.label} ending ${card.last4}${card.isLocked ? ', frozen' : ''}',
                          child: GestureDetector(
                            onTap: () => _tap(index),
                            child: FlipCard(
                              showBack: card.id == widget.revealedCardId,
                              front: AuraCardFace(
                                  card: card,
                                  sheen: reduced ? 0 : d.clamp(-1.0, 1.0),
                                  lift: lift),
                              back: AuraCardBack(card: card, lift: lift),
                            ),
                          ),
                        ),
                      );
                      final fade = (1 - distance * 0.42).clamp(0.16, 1.0);
                      if (reduced) return Opacity(opacity: fade, child: face);
                      final shrink = 1 - (distance * 0.09).clamp(0.0, 0.2);
                      return Opacity(
                        opacity: fade,
                        child: Transform.translate(
                          offset: Offset(d * 22, distance * 10),
                          child: Transform(
                            alignment: Alignment.center,
                            transform: Matrix4.identity()
                              ..setEntry(3, 2, 0.0013)
                              ..rotateY(d * 0.92)
                              ..rotateZ(d * 0.05)
                              ..scaleByDouble(shrink, shrink, 1, 1),
                            filterQuality: FilterQuality.medium,
                            child: face,
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
          if (widget.cards.length > 1)
            ValueListenableBuilder<double>(
              valueListenable: _page,
              builder: (context, page, _) =>
                  PageDots(count: widget.cards.length, page: page),
            ),
        ],
      );
    });
  }
}

/// Dots that stretch continuously with the page offset.
class PageDots extends StatelessWidget {
  const PageDots(
      {super.key,
      required this.count,
      required this.page,
      this.color = AuraColors.ink,
      this.track});

  final int count;
  final double page;
  final Color color;
  final Color? track;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(count, (i) {
        final near = (1 - (page - i).abs()).clamp(0.0, 1.0);
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: 6 + 16 * near,
          height: 6,
          decoration: BoxDecoration(
            color: Color.lerp(track ?? const Color(0xFFCBD1D6), color, near),
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }
}
