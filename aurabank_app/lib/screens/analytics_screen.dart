import 'package:flutter/material.dart';
import '../theme/aura_theme.dart';
import '../widgets/aura_logo.dart';
import 'statement_screen.dart';
import 'annual_report_screen.dart';

class AnalyticsScreen extends StatefulWidget {
  final VoidCallback? onBack;

  const AnalyticsScreen({super.key, this.onBack});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  bool _isMonthly = true;

  static const Color brandViolet = AuraColors.primary;
  static const Color accentGreen = AuraColors.creditGreen;
  static const Color lightGreen = Color(0xFF10B981);
  static const Color textDark = AuraColors.textPrimary;
  static const Color textGray = AuraColors.textMuted;

  @override
  Widget build(BuildContext context) {
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
                  if (widget.onBack != null) ...[
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                      onPressed: widget.onBack,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
                    const SizedBox(width: 4),
                  ],
                  const AuraLogo(size: 40, style: AuraLogoStyle.violet, borderRadius: 10),
                  const SizedBox(width: 12),
                  const Text(
                    'Aura Bank',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: textDark,
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
                  border: Border.all(color: const Color(0xFF5E17EB), width: 1.5),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _isMonthly = true),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _isMonthly ? const Color(0xFFEDE9FE) : Colors.transparent,
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
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: !_isMonthly ? const Color(0xFFEDE9FE) : Colors.transparent,
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
              _isMonthly ? _buildMonthlyKpiCards() : _buildYearlyKpiCards(),

              const SizedBox(height: 20),

              // 4. Transfer Flow Chart
              _buildTransferFlowSection(),

              const SizedBox(height: 20),

              // 5. History Section (Monthly History vs Monthly Summaries)
              _isMonthly ? _buildMonthlyHistorySection() : _buildYearlySummariesSection(),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMonthlyKpiCards() {
    return Row(
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
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Total Sent',
                  style: TextStyle(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 6),
                const Text(
                  'PHP 105,000.00',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text('18 Transfers Out', style: TextStyle(fontSize: 10, color: Colors.white70)),
                    Icon(Icons.arrow_downward, color: Colors.white, size: 14),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 14),
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
                  color: Colors.black.withValues(alpha: 0.04),
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
                  style: TextStyle(fontSize: 12, color: textGray, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 6),
                const Text(
                  'PHP 58,000.00',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textDark),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text('4 Transfers In', style: TextStyle(fontSize: 10, color: textGray)),
                    Icon(Icons.arrow_upward, color: accentGreen, size: 14),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildYearlyKpiCards() {
    return Row(
      children: [
        // Total Sent (2026)
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: brandViolet,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: brandViolet.withValues(alpha: 0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Total Sent (2026)',
                  style: TextStyle(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 6),
                const Text(
                  'PHP 508,000.00',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text('185 Transfers Out', style: TextStyle(fontSize: 10, color: Colors.white70)),
                    Icon(Icons.arrow_downward, color: Colors.white, size: 14),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 14),
        // Total Received (2026)
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE5E7EB)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Total Received (2026)',
                  style: TextStyle(fontSize: 12, color: textGray, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 6),
                const Text(
                  'PHP 160,000.00',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textDark),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text('43 Transfers In', style: TextStyle(fontSize: 10, color: textGray)),
                    Icon(Icons.arrow_upward, color: accentGreen, size: 14),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTransferFlowSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Transfer Flow',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textDark),
              ),
              Row(
                children: [
                  _buildLegendDot(lightGreen, 'Received'),
                  const SizedBox(width: 12),
                  _buildLegendDot(brandViolet, 'Sent'),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 140,
            width: double.infinity,
            child: CustomPaint(
              painter: _TransferFlowPainter(isMonthly: _isMonthly),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: _isMonthly
                ? const [
                    Text('Week 1', style: TextStyle(fontSize: 10, color: textGray)),
                    Text('Week 2', style: TextStyle(fontSize: 10, color: textGray)),
                    Text('Week 3', style: TextStyle(fontSize: 10, color: textGray)),
                    Text('Week 4', style: TextStyle(fontSize: 10, color: textGray)),
                    Text('Week 5', style: TextStyle(fontSize: 10, color: textGray)),
                  ]
                : const [
                    Text('January', style: TextStyle(fontSize: 10, color: textGray)),
                    Text('February', style: TextStyle(fontSize: 10, color: textGray)),
                    Text('March', style: TextStyle(fontSize: 10, color: textGray)),
                    Text('April', style: TextStyle(fontSize: 10, color: textGray)),
                    Text('May', style: TextStyle(fontSize: 10, color: textGray)),
                  ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendDot(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: textDark, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildMonthlyHistorySection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Monthly History',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textDark),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Transfers settled in October 2026',
                    style: TextStyle(fontSize: 11, color: textGray),
                  ),
                ],
              ),
              // Prominent "View Statement" Button
              GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const StatementScreen(),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: brandViolet,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: brandViolet.withValues(alpha: 0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
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
              ),
            ],
          ),

          const SizedBox(height: 16),

          const Text(
            'October 14, 2026',
            style: TextStyle(fontSize: 12, color: textGray, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 10),

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

          const Text(
            'October 03, 2026',
            style: TextStyle(fontSize: 12, color: textGray, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 10),

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
    );
  }

  Widget _buildYearlySummariesSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Monthly Summaries',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textDark),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Quarterly disbursement (2026)',
                    style: TextStyle(fontSize: 11, color: textGray),
                  ),
                ],
              ),
              // "Annual Report" Button
              GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const AnnualReportScreen(),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: brandViolet,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: brandViolet.withValues(alpha: 0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Text(
                    'Annual\nReport',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      height: 1.1,
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          const Text(
            'Quarter 3',
            style: TextStyle(fontSize: 12, color: textGray, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),

          _buildQuarterRow(
            initial: 'Jul',
            monthTitle: 'July 2026',
            transfers: '24 transfers • + 38,000.00',
            gross: 'PHP 42,000.00',
            net: '+ PHP 25.5k net',
            avatarBg: const Color(0xFF6200EA),
          ),
          const SizedBox(height: 10),
          _buildQuarterRow(
            initial: 'Aug',
            monthTitle: 'August 2026',
            transfers: '19 Transfers • + 38,000.00',
            gross: 'PHP 38,200.00',
            net: '+ PHP 13.8k net',
            avatarBg: const Color(0xFF9C27B0),
          ),

          const SizedBox(height: 16),

          const Text(
            'Quarter 2',
            style: TextStyle(fontSize: 12, color: textGray, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),

          _buildQuarterRow(
            initial: 'Jun',
            monthTitle: 'June 2026',
            transfers: '10 Transfers • + 38,000.00',
            gross: 'PHP 50,000.00',
            net: '+ PHP 15.2k net',
            avatarBg: const Color(0xFFBA68C8),
          ),
        ],
      ),
    );
  }

  Widget _buildQuarterRow({
    required String initial,
    required String monthTitle,
    required String transfers,
    required String gross,
    required String net,
    required Color avatarBg,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: avatarBg,
              child: Text(
                initial,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  monthTitle,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: textDark),
                ),
                Text(
                  transfers,
                  style: const TextStyle(fontSize: 11, color: textGray),
                ),
              ],
            ),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              gross,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textDark),
            ),
            Text(
              net,
              style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: accentGreen),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTransactionItem({
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
              radius: 18,
              backgroundColor: avatarBg,
              child: Text(
                initial,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: textDark),
                ),
                Text(
                  time,
                  style: const TextStyle(fontSize: 11, color: textGray),
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
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textDark),
            ),
            Text(
              status,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: statusColor),
            ),
          ],
        ),
      ],
    );
  }
}

class _TransferFlowPainter extends CustomPainter {
  final bool isMonthly;
  _TransferFlowPainter({required this.isMonthly});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final axisPaint = Paint()
      ..color = const Color(0xFFE5E7EB)
      ..strokeWidth = 1.5;

    canvas.drawLine(Offset(0, h - 10), Offset(w, h - 10), axisPaint);

    // Green Line (Received)
    final greenPaint = Paint()
      ..color = const Color(0xFF2ECC71)
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final greenPath = Path();
    greenPath.moveTo(0, h * 0.65);
    greenPath.cubicTo(w * 0.12, h * 0.58, w * 0.18, h * 0.72, w * 0.28, h * 0.45);
    greenPath.cubicTo(w * 0.35, h * 0.35, w * 0.45, h * 0.68, w * 0.55, h * 0.55);
    greenPath.cubicTo(w * 0.65, h * 0.40, w * 0.75, h * 0.20, w * 0.85, h * 0.30);
    greenPath.cubicTo(w * 0.90, h * 0.35, w * 0.95, h * 0.50, w, h * 0.45);

    canvas.drawPath(greenPath, greenPaint);

    // Violet Line (Sent)
    final violetPaint = Paint()
      ..color = const Color(0xFF5E17EB)
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final violetPath = Path();
    violetPath.moveTo(0, h * 0.75);
    violetPath.cubicTo(w * 0.12, h * 0.70, w * 0.18, h * 0.82, w * 0.28, h * 0.58);
    violetPath.cubicTo(w * 0.35, h * 0.48, w * 0.45, h * 0.80, w * 0.55, h * 0.70);
    violetPath.cubicTo(w * 0.65, h * 0.60, w * 0.75, h * 0.38, w * 0.85, h * 0.48);
    violetPath.cubicTo(w * 0.90, h * 0.52, w * 0.95, h * 0.65, w, h * 0.55);

    canvas.drawPath(violetPath, violetPaint);

    // Callout labels
    final greenLabel = isMonthly ? '+18.5k' : '+68.5k';
    final violetLabel = isMonthly ? '-10.5k' : '-16.5k';

    final textPainterGreen = TextPainter(
      text: TextSpan(
        text: greenLabel,
        style: const TextStyle(
          color: Color(0xFF2ECC71),
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainterGreen.paint(canvas, Offset(w * 0.65, h * 0.10));

    final textPainterViolet = TextPainter(
      text: TextSpan(
        text: violetLabel,
        style: const TextStyle(
          color: Color(0xFF380084),
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainterViolet.paint(canvas, Offset(w * 0.75, h * 0.82));
  }

  @override
  bool shouldRepaint(covariant _TransferFlowPainter oldDelegate) =>
      oldDelegate.isMonthly != isMonthly;
}
