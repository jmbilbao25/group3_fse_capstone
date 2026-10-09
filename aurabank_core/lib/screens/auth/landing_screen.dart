import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../theme/aura_theme.dart';
import '../../widgets/aura_card.dart';
import '../../widgets/aura_logo.dart';
import '../../widgets/aurora_background.dart';
import 'login_screen.dart';

/// First run. Aurora sky, two cards floating in it, three short pages.
class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _Page {
  const _Page(this.title, this.body);
  final String title;
  final String body;
}

const _pages = [
  _Page('Manage\nyour money', 'One savings account, Visa and Mastercard debit cards, and transfers that land in seconds.'),
  _Page('Protected on\nevery transfer', 'Laya checks each transfer for scams and unusual activity before money leaves your account.'),
  _Page('Open an account\nfrom your phone', 'Verify your ID with the camera. A person on our team reviews every application.'),
];

class _LandingScreenState extends State<LandingScreen> with SingleTickerProviderStateMixin {
  final PageController _pager = PageController();
  final ValueNotifier<double> _page = ValueNotifier(0);
  late final AnimationController _float = AnimationController(vsync: this, duration: const Duration(seconds: 7));

  @override
  void initState() {
    super.initState();
    _pager.addListener(() => _page.value = _pager.page ?? 0);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    AuraMotion.reduced(context) ? _float.stop() : _float.repeat();
  }

  @override
  void dispose() {
    _float.dispose();
    _pager.dispose();
    _page.dispose();
    super.dispose();
  }

  void _toLogin() {
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      pageBuilder: (_, __, ___) => const LoginScreen(),
      transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
      transitionDuration: AuraMotion.resolve(context, AuraMotion.medium),
    ));
  }

  void _next() {
    final i = _page.value.round();
    if (i >= _pages.length - 1) return _toLogin();
    if (AuraMotion.reduced(context)) return _pager.jumpToPage(i + 1);
    _pager.animateToPage(i + 1, duration: AuraMotion.resolve(context, AuraMotion.medium), curve: AuraMotion.emphasized);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AuraColors.ink,
      body: AuroraBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, c) => c.maxWidth >= 900 ? _wide(c) : _narrow(),
          ),
        ),
      ),
    );
  }

  /// Phone: copy on top, cards behind it, controls along the bottom.
  Widget _narrow() {
    return Stack(
      children: [
        Positioned.fill(child: _FloatingCards(float: _float, page: _page)),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(padding: const EdgeInsets.fromLTRB(24, 12, 12, 0), child: _header(30)),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 28),
                child: _copy(titleSize: 40, bodySize: 16, bodyWidth: 320, inset: 24),
              ),
            ),
            Padding(padding: const EdgeInsets.fromLTRB(24, 0, 24, 24), child: _controls()),
          ],
        ),
      ],
    );
  }

  /// Desktop: one centred 1200px column, copy left and cards right, with the
  /// header and the controls sharing the same edges as the copy.
  Widget _wide(BoxConstraints c) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 56, vertical: 28),
          child: Column(
            children: [
              _header(36),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      flex: 5,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            height: 300,
                            child: _copy(titleSize: 64, bodySize: 19, bodyWidth: 440, inset: 0),
                          ),
                          const SizedBox(height: 36),
                          ConstrainedBox(constraints: const BoxConstraints(maxWidth: 440), child: _controls()),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 6,
                      child: _FloatingCards(float: _float, page: _page, maxCard: 400, topFactor: 0.30),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(double mark) => Row(
        children: [
          AuraWordmark(size: mark, onDark: true),
          const Spacer(),
          TextButton(
            onPressed: _toLogin,
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            child: const Text('Sign in'),
          ),
        ],
      );

  Widget _controls() => Row(
        children: [
          ValueListenableBuilder<double>(
            valueListenable: _page,
            builder: (_, p, __) => PageDots(
              count: _pages.length,
              page: p,
              color: Colors.white,
              track: Colors.white.withValues(alpha: 0.28),
            ),
          ),
          const Spacer(),
          _NextButton(onTap: _next),
        ],
      );

  /// The paged headline and body. The copy slides less than the swipe, so it
  /// reads as a plane behind the finger rather than glued to it.
  Widget _copy({required double titleSize, required double bodySize, required double bodyWidth, required double inset}) {
    return PageView.builder(
      controller: _pager,
      itemCount: _pages.length,
      itemBuilder: (context, i) => ValueListenableBuilder<double>(
        valueListenable: _page,
        builder: (context, p, child) {
          final d = (p - i).clamp(-1.0, 1.0);
          return Opacity(
            opacity: (1 - d.abs() * 1.2).clamp(0.0, 1.0),
            child: Transform.translate(offset: Offset(d * 120, 0), child: child),
          );
        },
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: inset),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _pages[i].title,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: titleSize,
                  height: 1.06,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -titleSize * 0.03,
                ),
              ),
              SizedBox(height: titleSize * 0.35),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: bodyWidth),
                child: Text(
                  _pages[i].body,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.74), fontSize: bodySize, height: 1.45),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NextButton extends StatelessWidget {
  const _NextButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Next',
      child: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.12)),
        child: Material(
          color: AuraColors.mint,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: const SizedBox.square(
              dimension: 64,
              child: Icon(Icons.arrow_forward_rounded, color: AuraColors.ink, size: 26),
            ),
          ),
        ),
      ),
    );
  }
}

/// Two glass cards hanging in the sky. They bob on the float loop and swing a
/// little as the pages turn, so the scene answers the swipe.
class _FloatingCards extends StatelessWidget {
  const _FloatingCards({required this.float, required this.page, this.maxCard = 340, this.topFactor = 0.40});

  final double maxCard;

  /// Vertical anchor of the pair, as a share of the available height.
  final double topFactor;
  final Animation<double> float;
  final ValueListenable<double> page;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(builder: (context, c) {
        final w = math.min(math.min(c.maxWidth * 0.78, maxCard), c.maxHeight * 0.55);
        final right = c.maxWidth - w - 12;
        final top = c.maxHeight * topFactor;
        return AnimatedBuilder(
          animation: Listenable.merge([float, page]),
          builder: (context, _) {
            final t = float.value * math.pi * 2;
            final p = page.value;
            Widget card(double x, double y, double angle, double bob, String amount, String last4, bool front) =>
                Positioned(
                  left: x,
                  top: y + math.sin(t + bob) * 8,
                  child: Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.0012)
                      ..rotateZ(angle)
                      ..rotateY(-0.22 + p * 0.10 + math.sin(t + bob) * 0.03)
                      ..rotateX(0.10),
                    child: _GlassCard(width: w, amount: amount, last4: last4, front: front),
                  ),
                );
            return Stack(children: [
              card(math.min(c.maxWidth * 0.26, right) - p * 10, top - 64, -0.16, 0, '₱ 76,302.50', '3417', false),
              card(math.min(c.maxWidth * 0.06, right - w * 0.2) + p * 6, top + w * 0.30, -0.24, 1.6, '₱ 34,240.31', '2314', true),
            ]);
          },
        );
      }),
    );
  }
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.width, required this.amount, required this.last4, required this.front});

  final double width;
  final String amount;
  final String last4;
  final bool front;

  @override
  Widget build(BuildContext context) {
    final h = width / kCardAspect;
    final faint = Colors.white.withValues(alpha: front ? 0.72 : 0.5);
    return SizedBox(
      width: width,
      height: h,
      child: CustomPaint(
        painter: _GlassPainter(front: front),
        child: Padding(
          padding: EdgeInsets.all(width * 0.065),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text('Balance', style: TextStyle(color: faint, fontSize: width * 0.038)),
                const Spacer(),
                Icon(Icons.contactless_outlined, color: faint, size: width * 0.07),
              ]),
              Text(
                amount,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: front ? 1 : 0.7),
                  fontSize: width * 0.088,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.5,
                ),
              ),
              const Spacer(),
              Row(children: [
                Text('••••  $last4', style: TextStyle(color: faint, fontSize: width * 0.042, letterSpacing: 1.2)),
                const Spacer(),
                Text('VISA',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: front ? 0.95 : 0.6),
                      fontSize: width * 0.07,
                      fontWeight: FontWeight.w700,
                      fontStyle: FontStyle.italic,
                      letterSpacing: -0.5,
                    )),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

/// Translucent stock with a lit rim and the ribbon traced as a hairline. No
/// backdrop blur: the sky moves under it every frame and a live blur would
/// cost more than the effect is worth.
class _GlassPainter extends CustomPainter {
  const _GlassPainter({required this.front});
  final bool front;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final w = size.width;
    final h = size.height;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(w * 0.06));
    canvas.drawRRect(
      rrect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: front ? 0.16 : 0.08),
            AuraColors.ink.withValues(alpha: front ? 0.55 : 0.35),
          ],
        ).createShader(rect),
    );
    canvas.drawRRect(
      rrect.deflate(0.6),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..shader = LinearGradient(
          colors: [AuraColors.mint.withValues(alpha: 0.85), AuraColors.sky.withValues(alpha: 0.35)],
        ).createShader(rect),
    );
    canvas.save();
    canvas.clipRRect(rrect);
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.40, -h * 0.05)
        ..cubicTo(w * 0.30, h * 0.40, w * 0.88, h * 0.22, w * 0.82, h * 0.62)
        ..cubicTo(w * 0.78, h * 0.92, w * 0.46, h * 1.0, w * 0.30, h * 1.1),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = AuraColors.mint.withValues(alpha: front ? 0.75 : 0.4),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _GlassPainter old) => old.front != front;
}

/// Backward compatibility alias
typedef SplashScreen = LandingScreen;
