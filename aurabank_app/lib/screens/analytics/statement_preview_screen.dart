import 'package:flutter/material.dart';
import '../../models/bank_models.dart';
import '../../services/bank_service.dart';
import '../../theme/aura_theme.dart';
import '../../widgets/aura_logo.dart';

class StatementPreviewScreen extends StatefulWidget {
  final MonthlyStatement statement;

  const StatementPreviewScreen({super.key, required this.statement});

  @override
  State<StatementPreviewScreen> createState() => _StatementPreviewScreenState();
}

class _StatementPreviewScreenState extends State<StatementPreviewScreen> {
  final BankService _bankService = BankService();
  bool _isDownloading = false;

  static const Color brandPrimary = AuraColors.primary;
  static const Color brandAccent = AuraColors.accent;
  static const Color brandLight = AuraColors.tintPurple;
  static const Color brandBorder = AuraColors.borderPurple;
  static const Color greenCredit = AuraColors.creditGreen;
  static const Color debitRed = AuraColors.debitRed;
  static const Color textDark = AuraColors.textPrimary;
  static const Color textMuted = AuraColors.textMuted;
  static const Color cardBorder = AuraColors.cardBorder;
  static const Color bgCanvas = AuraColors.canvas;

  @override
  Widget build(BuildContext context) {
    final statement = widget.statement;

    return Scaffold(
      backgroundColor: bgCanvas,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // Top Navigation Bar
                _buildTopBar(statement),

                // Statement Document Canvas
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(18, 8, 18, 96),
                    child: _buildDocumentCard(statement),
                  ),
                ),
              ],
            ),

            // Bottom Sticky Button: "Download PDF"
            Positioned(
              left: 20,
              right: 20,
              bottom: 18,
              child: _buildDownloadButton(statement),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(MonthlyStatement statement) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // [X Done] Pill Button
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: cardBorder, width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.close_rounded, size: 16, color: textDark),
                  SizedBox(width: 4),
                  Text(
                    'Done',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: textDark,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Center Title
          Text(
            'Aura Statement ${statement.title}',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: textDark,
              letterSpacing: -0.2,
            ),
          ),

          // Share Button
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: cardBorder, width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.share_outlined, size: 18, color: textDark),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Statement link copied to clipboard'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentCard(MonthlyStatement statement) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header with Regulated info & E-Statement badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const AuraLogo(size: 38, style: AuraLogoStyle.violet, borderRadius: 10),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Aura Bank (PH)',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: textDark,
                      ),
                    ),
                    SizedBox(height: 1),
                    Text(
                      'BSP Regulated • Member: PDIC',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: brandLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: brandBorder, width: 0.8),
                ),
                child: const Text(
                  'E-STATEMENT',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: brandAccent,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),
          const Divider(color: cardBorder, height: 1),
          const SizedBox(height: 16),

          // 2. Account Holder & Statement Period (with RECONCILED badge)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ACCOUNT HOLDER',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      color: textMuted,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _bankService.user.name,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: textDark,
                    ),
                  ),
                  const SizedBox(height: 1),
                  const Text(
                    '•••• 5521 (Savings)',
                    style: TextStyle(fontSize: 11, color: textMuted),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'STATEMENT PERIOD',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      color: textMuted,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    statement.dateRange,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: textDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE6F8F0),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'RECONCILED',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: greenCredit,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 16),

          // 3. Compact KPI Bar
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: AuraColors.bgLavender,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AuraColors.borderLavender, width: 0.8),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'ALL',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: textMuted,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        statement.allCount.toString(),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: textDark,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(width: 1, height: 26, color: AuraColors.borderLavender),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'TOTAL RECEIVED',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                          color: textMuted,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatCurrency(statement.totalReceived),
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: greenCredit,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(width: 1, height: 26, color: AuraColors.borderLavender),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'TOTAL SENT',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                          color: textMuted,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatCurrency(statement.totalSent),
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: debitRed,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // 4. Transactional Journal Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'TRANSACTIONAL JOURNAL',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.7,
                  color: textMuted,
                ),
              ),
              Text(
                'Total Settled Transfers (${statement.allCount})',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: textMuted,
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // 5. Table Header & Rows
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: cardBorder, width: 1.0),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: Column(
                children: [
                  // Table Column Titles
                  Container(
                    color: const Color(0xFFF8F8FA),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      children: const [
                        Expanded(
                          flex: 3,
                          child: Text(
                            'DATE/REF',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                              color: textMuted,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 4,
                          child: Text(
                            'COUNTERPARTY',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                              color: textMuted,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Text(
                            'AMOUNT',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                              color: textMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Data Rows
                  ...statement.transactions.map((t) => _buildTableRow(t)),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),
          const Divider(color: cardBorder, height: 1),
          const SizedBox(height: 16),

          // 6. Digitally Verified Seal & QR Code
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Row(
                    children: [
                      Icon(Icons.check_rounded, size: 14, color: greenCredit),
                      SizedBox(width: 4),
                      Text(
                        'DIGITALLY VERIFIED',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                          color: greenCredit,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 3),
                  Text(
                    'SHA256: 8f9c2d10...4a2b910e',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 9.5,
                      color: textMuted,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),

              // Aesthetic QR Code Pattern
              _buildDigitalSealQr(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTableRow(BankTransaction t) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: cardBorder, width: 0.8)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Date & Ref
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.displayTime,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: textDark,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  t.reference,
                  style: const TextStyle(
                    fontSize: 9.5,
                    color: textMuted,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),

          // Counterparty
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.counterparty,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: textDark,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  t.statusDisplay,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                    color: t.isIncoming ? greenCredit : textMuted,
                  ),
                ),
              ],
            ),
          ),

          // Amount
          Expanded(
            flex: 3,
            child: Text(
              t.formattedAmount,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: t.isIncoming ? greenCredit : debitRed,
                letterSpacing: -0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDigitalSealQr() {
    return Container(
      width: 44,
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: cardBorder, width: 1.0),
      ),
      child: CustomPaint(
        painter: _SimulatedQrPainter(),
      ),
    );
  }

  Widget _buildDownloadButton(MonthlyStatement statement) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: AuraColors.buttonShadow,
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: brandPrimary,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
        onPressed: _isDownloading
            ? null
            : () async {
                setState(() => _isDownloading = true);
                await Future.delayed(const Duration(milliseconds: 1200));
                if (mounted) {
                  setState(() => _isDownloading = false);
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      title: Row(
                        children: const [
                          Icon(Icons.check_circle_rounded, color: greenCredit, size: 24),
                          SizedBox(width: 8),
                          Text('PDF Downloaded', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                        ],
                      ),
                      content: Text(
                        'Aura_Statement_${statement.title.replaceAll(' ', '_')}.pdf has been saved and verified.',
                        style: const TextStyle(fontSize: 13, color: textDark),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('OK', style: TextStyle(color: brandPrimary, fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                  );
                }
              },
        child: _isDownloading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.2,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.download_rounded, color: Colors.white, size: 19),
                  SizedBox(width: 8),
                  Text(
                    'Download PDF',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  String _formatCurrency(double amount) {
    final parts = amount.toStringAsFixed(2).split('.');
    final intPart = parts[0].replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
    return '₱$intPart.${parts[1]}';
  }
}

class _SimulatedQrPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF1E1E2D)
      ..style = PaintingStyle.fill;

    final cell = size.width / 7.0;

    // Corner Finder Patterns
    void drawFinder(double x, double y) {
      canvas.drawRect(Rect.fromLTWH(x, y, cell * 3, cell * 3), paint);
      canvas.drawRect(
        Rect.fromLTWH(x + cell * 0.7, y + cell * 0.7, cell * 1.6, cell * 1.6),
        Paint()..color = Colors.white,
      );
      canvas.drawRect(
        Rect.fromLTWH(x + cell * 1.1, y + cell * 1.1, cell * 0.8, cell * 0.8),
        paint,
      );
    }

    drawFinder(0, 0);
    drawFinder(size.width - cell * 3, 0);
    drawFinder(0, size.height - cell * 3);

    // Micro matrix dots
    final dotPositions = [
      Offset(cell * 4, cell * 1),
      Offset(cell * 3.5, cell * 3.5),
      Offset(cell * 5, cell * 3),
      Offset(cell * 4, cell * 5),
      Offset(cell * 5.5, cell * 5.5),
    ];

    for (final p in dotPositions) {
      canvas.drawRect(Rect.fromLTWH(p.dx, p.dy, cell * 0.9, cell * 0.9), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
