import 'package:flutter/material.dart';
import '../models/bank_models.dart';
import '../services/bank_service.dart';
import '../services/statement_file_saver.dart';
import '../services/statement_pdf.dart';
import '../theme/aura_theme.dart';
import 'aura_logo.dart';

class StatementDocument extends StatelessWidget {
  final MonthlyStatement statement;
  final bool showDigitalSeal;

  const StatementDocument({
    super.key,
    required this.statement,
    this.showDigitalSeal = true,
  });

  static const Color brandAccent = AuraColors.accent;
  static const Color brandLight = AuraColors.tintPurple;
  static const Color brandBorder = AuraColors.borderPurple;
  static const Color greenCredit = AuraColors.creditGreen;
  static const Color debitRed = AuraColors.debitRed;
  static const Color textDark = AuraColors.textPrimary;
  static const Color textMuted = AuraColors.textMuted;
  static const Color cardBorder = AuraColors.cardBorder;

  @override
  Widget build(BuildContext context) {
    final holderName = BankService().user.name;

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
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const AuraLogo(size: 38, style: AuraLogoStyle.violet, borderRadius: 10),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                    holderName,
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
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: cardBorder, width: 1.0),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: Column(
                children: [
                  Container(
                    color: const Color(0xFFF8F8FA),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: const Row(
                      children: [
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
                  ...statement.transactions.map((t) => _tableRow(t)),
                ],
              ),
            ),
          ),
          if (showDigitalSeal) ...[
            const SizedBox(height: 24),
            const Divider(color: cardBorder, height: 1),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                _digitalSealQr(),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _tableRow(BankTransaction t) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: cardBorder, width: 0.8)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
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

  Widget _digitalSealQr() {
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

  String _formatCurrency(double amount) {
    final parts = amount.toStringAsFixed(2).split('.');
    final intPart = parts[0].replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
    return '₱$intPart.${parts[1]}';
  }
}

class StatementDownloadButton extends StatefulWidget {
  final MonthlyStatement statement;

  const StatementDownloadButton({super.key, required this.statement});

  @override
  State<StatementDownloadButton> createState() => _StatementDownloadButtonState();
}

class _StatementDownloadButtonState extends State<StatementDownloadButton> {
  bool _isDownloading = false;

  static const Color brandPrimary = AuraColors.primary;
  static const Color greenCredit = AuraColors.creditGreen;
  static const Color textDark = AuraColors.textPrimary;

  @override
  Widget build(BuildContext context) {
    final statement = widget.statement;

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
                final filename = statementPdfFilename(statement.title);
                try {
                  final bytes = buildStatementPdf(
                    statement: statement,
                    accountHolder: BankService().user.name,
                  );
                  final savedAs = await saveStatementPdf(bytes: bytes, filename: filename);
                  if (!context.mounted) return;
                  setState(() => _isDownloading = false);
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      title: const Row(
                        children: [
                          Icon(Icons.check_circle_rounded, color: greenCredit, size: 24),
                          SizedBox(width: 8),
                          Text('PDF Downloaded', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                        ],
                      ),
                      content: Text(
                        '$savedAs has been saved.',
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
                } catch (_) {
                  if (!context.mounted) return;
                  setState(() => _isDownloading = false);
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      title: const Text('Could not save PDF', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                      content: Text(
                        '$filename was not saved.',
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
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
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
}

class _SimulatedQrPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF1E1E2D)
      ..style = PaintingStyle.fill;

    final cell = size.width / 7.0;

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
