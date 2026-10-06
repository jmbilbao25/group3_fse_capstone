import 'package:flutter/material.dart';
import '../theme/aura_theme.dart';

class TransactionReceiptScreen extends StatelessWidget {
  final bool isSuccess;
  final String senderName;
  final String senderAccount;
  final String recipientName;
  final String recipientAccount;
  final String recipientBank;
  final double amount;
  final double fee;
  final String referenceNumber;
  final String? failureReason;
  final VoidCallback? onTryAgain;

  const TransactionReceiptScreen({
    super.key,
    this.isSuccess = true,
    required this.senderName,
    required this.senderAccount,
    required this.recipientName,
    required this.recipientAccount,
    required this.recipientBank,
    required this.amount,
    this.fee = 0.0,
    required this.referenceNumber,
    this.failureReason,
    this.onTryAgain,
  });

  static const Color brandViolet = AuraColors.primary;
  static const Color textDark = AuraColors.textPrimary;
  static const Color textGray = AuraColors.textMuted;
  static const Color cardBorder = AuraColors.cardBorder;
  static const Color greenSuccess = AuraColors.creditGreen;
  static const Color redFail = AuraColors.debitRed;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final dateStr = '${now.day.toString().padLeft(2, '0')} October ${now.year}';
    final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    return Scaffold(
      backgroundColor: const Color(0xFFFBFBFD),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
          child: Column(
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                    color: textDark,
                    onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                  ),
                  const Text(
                    'Receipt',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: textDark),
                  ),
                  IconButton(
                    icon: const Icon(Icons.share_outlined, size: 20),
                    color: textDark,
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Receipt image saved to device.')),
                      );
                    },
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Status Icon Circle
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: isSuccess ? const Color(0xFFD1FAE5) : const Color(0xFFFFE4E6),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    isSuccess ? Icons.check_rounded : Icons.close_rounded,
                    color: isSuccess ? greenSuccess : redFail,
                    size: 48,
                  ),
                ),
              ),

              const SizedBox(height: 18),

              const Text(
                'Transaction Receipt',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textDark),
              ),
              const SizedBox(height: 6),
              Text(
                'PHP ${_formatAmount(amount)}',
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: textDark,
                  letterSpacing: -0.5,
                ),
              ),

              if (!isSuccess) ...[
                const SizedBox(height: 6),
                const Text(
                  'Your money has not been deducted',
                  style: TextStyle(fontSize: 12, color: textGray, fontWeight: FontWeight.w500),
                ),
              ],

              const SizedBox(height: 24),

              // Receipt Details Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: cardBorder),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _buildReceiptRow('From', senderName, 'Aura Bank: $senderAccount'),
                    const Divider(color: cardBorder, height: 24),
                    _buildReceiptRow('To', recipientName, '$recipientBank: $recipientAccount'),
                    const Divider(color: cardBorder, height: 24),
                    _buildSimpleRow('Transfer Amount', 'PHP ${_formatAmount(amount)}'),
                    const SizedBox(height: 12),
                    _buildSimpleRow('Transfer Fee', fee == 0.0 ? 'FREE' : 'PHP ${_formatAmount(fee)}', feeColor: fee == 0.0 ? greenSuccess : textDark),
                    const SizedBox(height: 12),
                    _buildSimpleRow('Total Amount', 'PHP ${_formatAmount(amount + fee)}', isBold: true),
                    const Divider(color: cardBorder, height: 24),
                    _buildSimpleRow('Reference Number', referenceNumber),
                    const SizedBox(height: 12),
                    _buildSimpleRow('Transaction Date', dateStr),
                    const SizedBox(height: 12),
                    _buildSimpleRow('Transaction Time', timeStr),

                    if (!isSuccess) ...[
                      const Divider(color: cardBorder, height: 24),
                      _buildSimpleRow('Status', 'Failed', feeColor: redFail, isBold: true),
                      const SizedBox(height: 12),
                      _buildSimpleRow('Failure Reason', failureReason ?? 'Destination Bank Timeout'),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 32),

              if (!isSuccess && onTryAgain != null) ...[
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: brandViolet,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    ),
                    onPressed: onTryAgain,
                    child: const Text('Try Again', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              SizedBox(
                width: double.infinity,
                height: 48,
                child: isSuccess
                    ? ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: brandViolet,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        ),
                        onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                        child: const Text('Back to home', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                      )
                    : OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: cardBorder),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        ),
                        onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                        child: const Text('Back to home', style: TextStyle(color: textDark, fontWeight: FontWeight.w700, fontSize: 15)),
                      ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReceiptRow(String label, String value, String subValue) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: textGray, fontWeight: FontWeight.w500)),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(value, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: textDark)),
            const SizedBox(height: 2),
            Text(subValue, style: const TextStyle(fontSize: 11, color: textGray)),
          ],
        ),
      ],
    );
  }

  Widget _buildSimpleRow(String label, String value, {Color? feeColor, bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: textGray, fontWeight: FontWeight.w500)),
        Text(
          value,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
            color: feeColor ?? textDark,
          ),
        ),
      ],
    );
  }

  String _formatAmount(double amount) {
    final parts = amount.toStringAsFixed(2).split('.');
    final intPart = parts[0].replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
    return '$intPart.${parts[1]}';
  }
}
