import 'package:flutter/material.dart';
import '../../models/bank_models.dart';
import '../../theme/aura_theme.dart';
import '../../widgets/statement_document.dart';

class StatementPreviewScreen extends StatelessWidget {
  final MonthlyStatement statement;

  const StatementPreviewScreen({super.key, required this.statement});

  static const Color textDark = AuraColors.textPrimary;
  static const Color cardBorder = AuraColors.cardBorder;
  static const Color bgCanvas = AuraColors.canvas;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgCanvas,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _buildTopBar(context, statement),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(18, 8, 18, 96),
                    child: StatementDocument(statement: statement),
                  ),
                ),
              ],
            ),
            Positioned(
              left: 20,
              right: 20,
              bottom: 18,
              child: StatementDownloadButton(statement: statement),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, MonthlyStatement statement) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
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
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
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
          Text(
            'Aura Statement ${statement.title}',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: textDark,
              letterSpacing: -0.2,
            ),
          ),
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
}
