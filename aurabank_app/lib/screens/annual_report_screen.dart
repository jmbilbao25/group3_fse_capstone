import 'package:flutter/material.dart';
import '../services/bank_service.dart';
import '../theme/aura_theme.dart';
import '../widgets/aura_logo.dart';

class AnnualReportScreen extends StatelessWidget {
  const AnnualReportScreen({super.key});

  static const Color brandViolet = AuraColors.primary;
  static const Color greenCredit = AuraColors.creditGreen;
  static const Color textDark = AuraColors.textPrimary;
  static const Color textMuted = AuraColors.textMuted;
  static const Color cardBorder = AuraColors.cardBorder;
  static const Color bgCanvas = AuraColors.canvas;

  @override
  Widget build(BuildContext context) {
    final bankService = BankService();

    final quarters = [
      {
        'title': 'Quarter 4 (Oct-Dec 2026)',
        'subtitle': 'Q4 2026',
        'amount': '+ ₱26,000.00',
        'transfers': '53 Transfer Settled',
      },
      {
        'title': 'Quarter 3 (July-Sept 2026)',
        'subtitle': '05 Oct 2026 - 10:00 AM',
        'amount': '+ ₱56,700.00',
        'transfers': '63 Transfer Settled',
      },
      {
        'title': 'Quarter 2 (April-June 2026)',
        'subtitle': '09 Oct 2026 - 06:00 AM',
        'amount': '+ ₱90,000.00',
        'transfers': '60 Transfer Settled',
      },
      {
        'title': 'Quarter 1 (Jan-March 2026)',
        'subtitle': '16 Oct 2026 - 10:00 AM',
        'amount': '+ ₱50,000.00',
        'transfers': '53 Transfer Settled',
      },
    ];

    return Scaffold(
      backgroundColor: bgCanvas,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // Top Header Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                        color: textDark,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      ),
                      const SizedBox(width: 8),
                      const AuraLogo(size: 32, style: AuraLogoStyle.violet, borderRadius: 8),
                      const SizedBox(width: 8),
                      const Text(
                        'Aura Bank',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: textDark,
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(18, 4, 18, 96),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title
                        const Text(
                          'Aura Annual Report',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: brandViolet,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Jan 01 - Dec 31, 2026',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: textMuted,
                          ),
                        ),

                        const SizedBox(height: 16),

                        const Text(
                          'SELECT REPORT PERIOD',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            color: textMuted,
                          ),
                        ),

                        const SizedBox(height: 8),

                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: cardBorder, width: 1.2),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: const [
                              Text(
                                'Annual Report (2026)',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: textDark,
                                ),
                              ),
                              Icon(Icons.keyboard_arrow_down_rounded, color: textDark),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Annual Dossier Card
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: cardBorder, width: 1.2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.03),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const AuraLogo(size: 34, style: AuraLogoStyle.violet, borderRadius: 8),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: const [
                                        Text(
                                          'Aura Bank',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w800,
                                            color: textDark,
                                          ),
                                        ),
                                        Text(
                                          'Intra-Bank Network Ledger',
                                          style: TextStyle(fontSize: 10, color: textMuted),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF3E8FF),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text(
                                      'Annual Dossier',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: brandViolet,
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 16),

                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'ACCOUNT HOLDER',
                                        style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: textMuted),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        bankService.user.name,
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: textDark),
                                      ),
                                      Text(
                                        '${bankService.savingsAccountNumber} (Savings)',
                                        style: const TextStyle(fontSize: 11, color: textMuted),
                                      ),
                                    ],
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: const [
                                      Text(
                                        'STATEMENT PERIOD',
                                        style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: textMuted),
                                      ),
                                      SizedBox(height: 2),
                                      Text(
                                        'Jan 01 - Dec 31, 2026',
                                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: textDark),
                                      ),
                                      Text(
                                        'Currency: PHP',
                                        style: TextStyle(fontSize: 11, color: textMuted),
                                      ),
                                    ],
                                  ),
                                ],
                              ),

                              const SizedBox(height: 16),
                              const Divider(color: cardBorder, height: 1),
                              const SizedBox(height: 16),

                              Row(
                                children: const [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'TOTAL RECEIVED',
                                          style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: textMuted),
                                        ),
                                        SizedBox(height: 3),
                                        Text(
                                          'PHP 560,000.00',
                                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: greenCredit),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          'TOTAL SENT',
                                          style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: textMuted),
                                        ),
                                        SizedBox(height: 3),
                                        Text(
                                          'PHP 415,000.00',
                                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: brandViolet),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        const Text(
                          'Quarterly Performance (4 Quarters)',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: textMuted,
                            letterSpacing: 0.5,
                          ),
                        ),

                        const SizedBox(height: 12),

                        ...quarters.map((q) {
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: cardBorder),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE6F8F0),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    'IN',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: greenCredit,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        q['title']!,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                          color: textDark,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${q['subtitle']} • ${q['transfers']}',
                                        style: const TextStyle(fontSize: 10.5, color: textMuted),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  q['amount']!,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: greenCredit,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // Sticky Bottom Button
            Positioned(
              left: 20,
              right: 20,
              bottom: 18,
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: AuraColors.buttonShadow,
                ),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: brandViolet,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  ),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Annual Report dossier exported as PDF.')),
                    );
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.print_outlined, color: Colors.white, size: 19),
                      SizedBox(width: 8),
                      Text(
                        'Export as PDF',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
