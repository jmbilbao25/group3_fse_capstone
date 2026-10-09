import 'package:flutter/material.dart';
import 'package:aurabank_core/models/bank_models.dart';
import 'package:aurabank_core/widgets/statement_document.dart';

class WebStatementPreviewScreen extends StatelessWidget {
  final MonthlyStatement statement;

  const WebStatementPreviewScreen({super.key, required this.statement});

  static const Color textDark = Color(0xFF10171C);
  static const Color textGray = Color(0xFF7D8892);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 20, 28, 8),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.arrow_back_rounded, size: 18, color: textDark),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Aura Statement ${statement.title}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: textDark,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Preview before download',
                        style: TextStyle(fontSize: 12, color: textGray),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(32, 8, 32, 32),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 880),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      StatementDocument(
                        statement: statement,
                        showDigitalSeal: false,
                      ),
                      const SizedBox(height: 20),
                      StatementDownloadButton(statement: statement),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
