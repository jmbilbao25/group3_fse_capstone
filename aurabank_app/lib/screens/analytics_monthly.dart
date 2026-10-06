import 'package:flutter/material.dart';

/// Screen: Analytics - Monthly
class AnalyticsMonthlyScreen extends StatefulWidget {
  const AnalyticsMonthlyScreen({super.key});

  @override
  State<AnalyticsMonthlyScreen> createState() => _AnalyticsMonthlyScreenState();
}

class _AnalyticsMonthlyScreenState extends State<AnalyticsMonthlyScreen> {
  bool _isMonthly = true;
  int _currentNavIndex = 3; // 3 is 'Analytics'

  @override
  Widget build(BuildContext context) {
    const brandViolet = Color(0xFF380084);
    const accentGreen = Color(0xFF00C853);
    const lightGreen = Color(0xFF2ECC71);
    const textDark = Color(0xFF1E1E2D);
    const textGray = Color(0xFF8A92A6);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Header: Logo + App Name
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: brandViolet,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: brandViolet.withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text(
                        'A',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.underline,
                          decorationColor: Colors.white,
                          decorationThickness: 2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Aura Bank',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: textDark,
                      decoration: TextDecoration.underline,
                      decorationColor: textDark,
                      decorationThickness: 2,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // 2. Segmented Toggle: Monthly / Yearly
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF0091FF), width: 1.5),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _isMonthly = true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _isMonthly ? const Color(0xFFC7C7CC) : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text(
                              'Monthly',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: _isMonthly ? brandViolet : textGray,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _isMonthly = false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: !_isMonthly ? const Color(0xFFC7C7CC) : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text(
                              'Yearly',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: !_isMonthly ? brandViolet : textGray,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // 3. KPI Cards: Total Sent & Total Received
              Row(
                children: [
                  // Total Sent Card (Violet)
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: brandViolet,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: brandViolet.withValues(alpha: 0.25),
                            blurRadius: 12,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Total Sent',
                            style: TextStyle(
                              color: Color(0xFFD4C7F5),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'PHP 105,000.00',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Divider(color: Color(0xFF5E2B97), thickness: 1, height: 1),
                          const SizedBox(height: 8),
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '18 Transfers Out',
                                style: TextStyle(
                                  color: Color(0xFFD4C7F5),
                                  fontSize: 11,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                              Icon(Icons.arrow_downward, color: Colors.white, size: 14),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Total Received Card (White)
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Total Received',
                            style: TextStyle(
                              color: brandViolet,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'PHP 58,000.00',
                            style: TextStyle(
                              color: brandViolet,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Divider(color: Color(0xFF380084), thickness: 1.5, height: 1),
                          const SizedBox(height: 8),
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '4 Transfers In',
                                style: TextStyle(
                                  color: brandViolet,
                                  fontSize: 11,
                                  fontStyle: FontStyle.italic,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Icon(Icons.arrow_upward, color: brandViolet, size: 14),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // 4. Transfer Flow Card (with Custom Bezier Wave Chart)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title and Legend
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Transfer Flow',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: brandViolet,
                          ),
                        ),
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: lightGreen,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Text(
                              'Received',
                              style: TextStyle(fontSize: 10, color: lightGreen, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(width: 10),
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: brandViolet,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Text(
                              'Sent',
                              style: TextStyle(fontSize: 10, color: brandViolet, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Custom Chart
                    SizedBox(
                      height: 200,
                      width: double.infinity,
                      child: CustomPaint(
                        painter: _TransferFlowPainter(),
                      ),
                    ),

                    const SizedBox(height: 8),

                    // X-Axis Weeks
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Week 1', style: TextStyle(fontSize: 10, color: textGray, fontWeight: FontWeight.w500)),
                        Text('Week 2', style: TextStyle(fontSize: 10, color: textGray, fontWeight: FontWeight.w500)),
                        Text('Week 3', style: TextStyle(fontSize: 10, color: textGray, fontWeight: FontWeight.w500)),
                        Text('Week 4', style: TextStyle(fontSize: 10, color: textGray, fontWeight: FontWeight.w500)),
                        Text('Week 5', style: TextStyle(fontSize: 10, color: textGray, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // 5. Monthly History Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header & View Statement Button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Monthly History',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: brandViolet,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Transfers settled in October 2026',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF5E17EB),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: brandViolet,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Text(
                            'View\nStatement',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              height: 1.1,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Date Group 1
                    const Text(
                      'October 14, 2026',
                      style: TextStyle(
                        fontSize: 12,
                        color: textGray,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Transaction 1: Drake Montefalco
                    _buildTransactionItem(
                      avatarBg: const Color(0xFF220055),
                      initial: 'D',
                      name: 'Drake Montefalco',
                      time: 'Today, 2:45 pm',
                      amount: '- Php 2,500.00',
                      status: 'COMPLETED',
                      statusColor: accentGreen,
                    ),

                    const SizedBox(height: 12),

                    // Transaction 2: Klare Riego
                    _buildTransactionItem(
                      avatarBg: const Color(0xFFBA68C8),
                      initial: 'K',
                      name: 'Klare Riego',
                      time: 'Today, 1:45 pm',
                      amount: '+ Php 26,500.00',
                      status: 'RECEIVED',
                      statusColor: accentGreen,
                    ),

                    const SizedBox(height: 16),

                    // Date Group 2
                    const Text(
                      'October 03, 2026',
                      style: TextStyle(
                        fontSize: 12,
                        color: textGray,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Transaction 3: Angel Lou
                    _buildTransactionItem(
                      avatarBg: const Color(0xFF7C4DFF),
                      initial: 'A',
                      name: 'Angel Lou',
                      time: 'Today, 2:45 pm',
                      amount: '- Php 2,500.00',
                      status: 'COMPLETED',
                      statusColor: accentGreen,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),

      // 6. Bottom Navigation Bar
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentNavIndex,
          onTap: (index) => setState(() => _currentNavIndex = index),
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: brandViolet,
          unselectedItemColor: Colors.black,
          selectedFontSize: 11,
          unselectedFontSize: 11,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.account_balance_outlined),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.credit_card_outlined),
              label: 'Cards',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.qr_code_scanner_rounded),
              label: 'Scan',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.show_chart_rounded, color: Color(0xFF5E17EB)),
              label: 'Analytics',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline_rounded),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }

  static Widget _buildTransactionItem({
    required Color avatarBg,
    required String initial,
    required String name,
    required String time,
    required String amount,
    required String status,
    required Color statusColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: avatarBg,
              child: Text(
                initial,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Color(0xFF1E1E2D),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  time,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF8A92A6),
                  ),
                ),
              ],
            ),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              amount,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: Color(0xFF1E1E2D),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              status,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 10,
                color: statusColor,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Custom Chart Painter for Transfer Flow
class _TransferFlowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Base axis line
    final axisPaint = Paint()
      ..color = const Color(0xFF333333)
      ..strokeWidth = 2.0;

    canvas.drawLine(Offset(0, h - 10), Offset(w, h - 10), axisPaint);

    // 1. Green Line (Received)
    final greenPaint = Paint()
      ..color = const Color(0xFF2ECC71)
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final greenPath = Path();
    greenPath.moveTo(0, h * 0.65);
    greenPath.cubicTo(w * 0.08, h * 0.60, w * 0.10, h * 0.70, w * 0.16, h * 0.70);
    greenPath.cubicTo(w * 0.20, h * 0.70, w * 0.22, h * 0.45, w * 0.28, h * 0.45);
    greenPath.cubicTo(w * 0.32, h * 0.45, w * 0.34, h * 0.58, w * 0.38, h * 0.58);
    greenPath.cubicTo(w * 0.42, h * 0.20, w * 0.48, h * 0.35, w * 0.52, h * 0.60);
    greenPath.cubicTo(w * 0.58, h * 0.70, w * 0.62, h * 0.62, w * 0.66, h * 0.62);
    greenPath.cubicTo(w * 0.70, h * 0.62, w * 0.74, h * 0.25, w * 0.80, h * 0.25);
    greenPath.cubicTo(w * 0.84, h * 0.25, w * 0.86, h * 0.60, w * 0.90, h * 0.60);
    greenPath.cubicTo(w * 0.93, h * 0.48, w * 0.96, h * 0.32, w, h * 0.48);

    canvas.drawPath(greenPath, greenPaint);

    // 2. Violet Line (Sent)
    final violetPaint = Paint()
      ..color = const Color(0xFF5E17EB)
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final violetPath = Path();
    violetPath.moveTo(0, h * 0.75);
    violetPath.cubicTo(w * 0.08, h * 0.70, w * 0.12, h * 0.80, w * 0.16, h * 0.80);
    violetPath.cubicTo(w * 0.20, h * 0.80, w * 0.23, h * 0.55, w * 0.28, h * 0.55);
    violetPath.cubicTo(w * 0.33, h * 0.55, w * 0.35, h * 0.68, w * 0.38, h * 0.68);
    violetPath.cubicTo(w * 0.43, h * 0.35, w * 0.48, h * 0.50, w * 0.52, h * 0.78);
    violetPath.cubicTo(w * 0.58, h * 0.88, w * 0.62, h * 0.75, w * 0.66, h * 0.75);
    violetPath.cubicTo(w * 0.70, h * 0.75, w * 0.74, h * 0.42, w * 0.80, h * 0.42);
    violetPath.cubicTo(w * 0.85, h * 0.42, w * 0.87, h * 0.78, w * 0.91, h * 0.78);
    violetPath.cubicTo(w * 0.94, h * 0.60, w * 0.97, h * 0.48, w, h * 0.56);

    canvas.drawPath(violetPath, violetPaint);

    // Callout labels
    // +18.5k (Green)
    final textPainterGreen = TextPainter(
      text: const TextSpan(
        text: '+18.5k',
        style: TextStyle(
          color: Color(0xFF2ECC71),
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainterGreen.paint(canvas, Offset(w * 0.70, h * 0.10));

    // -10.5k (Violet)
    final textPainterViolet = TextPainter(
      text: const TextSpan(
        text: '-10.5k',
        style: TextStyle(
          color: Color(0xFF380084),
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainterViolet.paint(canvas, Offset(w * 0.80, h * 0.84));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
