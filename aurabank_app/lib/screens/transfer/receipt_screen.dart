import 'package:flutter/material.dart';
import '../../theme/aura_theme.dart';
import '../../widgets/motion.dart';

class TransactionReceiptScreen extends StatefulWidget {
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
  final VoidCallback? onBackToHome;

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
    this.onBackToHome,
  });

  @override
  State<TransactionReceiptScreen> createState() =>
      _TransactionReceiptScreenState();
}

class _TransactionReceiptScreenState extends State<TransactionReceiptScreen> {
  late bool _isSuccess;

  static const Color brandViolet = AuraColors.primary;
  static const Color textDark = Color(0xFF10171C);
  static const Color textMuted = Color(0xFF6E7882);
  static const Color cardBorder = Color(0xFFF1F3F4);
  static const Color greenSuccess = Color(0xFF2FA37E);
  static const Color redFail = Color(0xFFC8423B);

  @override
  void initState() {
    super.initState();
    _isSuccess = widget.isSuccess;
  }

  void _handleBackToHome() {
    if (widget.onBackToHome != null) {
      widget.onBackToHome!();
    } else {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    final dateStr =
        '${now.day.toString().padLeft(2, '0')} ${months[now.month - 1]} ${now.year}';
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    final senderDisplay = widget.senderName.trim().isNotEmpty
        ? widget.senderName
        : 'Elijah Riley Montefalco';
    final senderAccDisplay = widget.senderAccount.trim().isNotEmpty
        ? widget.senderAccount
        : '1235484874877';
    final recipientDisplay = widget.recipientName.trim().isNotEmpty
        ? widget.recipientName
        : 'Jessie Mae R. Dela Paz';
    final recipientBankDisplay = widget.recipientBank.trim().isNotEmpty
        ? widget.recipientBank
        : 'MeyBank';
    final recipientAccDisplay = widget.recipientAccount.trim().isNotEmpty
        ? widget.recipientAccount
        : '1154848785378';
    final refDisplay = widget.referenceNumber.trim().isNotEmpty
        ? widget.referenceNumber
        : '1235498758130';

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 12.0),
              child: Column(
                children: [
                  // Symmetrical Top Header (Back + Receipt Title + Share)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Circular Elevated Back Button
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: const Color(0xFFE6E8EA), width: 1.0),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                                size: 17, color: textDark),
                            padding: EdgeInsets.zero,
                            onPressed: _handleBackToHome,
                          ),
                        ),

                        // Center Title
                        const Text(
                          'Receipt',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: textDark,
                            letterSpacing: -0.3,
                          ),
                        ),

                        // Circular Elevated Share Button
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: const Color(0xFFE6E8EA), width: 1.0),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.share_outlined,
                                size: 20, color: brandViolet),
                            padding: EdgeInsets.zero,
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content:
                                        Text('Receipt image saved to device.')),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Status Icon Circle Hero (Scan - Image 6 / Scan - Failed)
                  GestureDetector(
                    onTap: () {
                      setState(() => _isSuccess = !_isSuccess);
                    },
                    child: AnimatedCheck(
                      key: ValueKey(_isSuccess),
                      size: 96,
                      success: _isSuccess,
                      color: _isSuccess
                          ? AuraColors.mint
                          : const Color(0xFFF6CFCB),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Sub-header title
                  const Text(
                    'Transaction Receipt',
                    style: TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF334155),
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Heroic Amount
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'PHP ${_formatAmount(widget.amount)}',
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: textDark,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),

                  if (!_isSuccess) ...[
                    const SizedBox(height: 6),
                    const Text(
                      'Your money has not been deducted',
                      style: TextStyle(
                          fontSize: 12.5,
                          color: textMuted,
                          fontWeight: FontWeight.w600),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Sculpted Receipt Dossier Card (Scan - image 6 / Scan - Failed)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: cardBorder, width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color:
                              const Color(0xFF10171C).withValues(alpha: 0.05),
                          blurRadius: 18,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        _buildReceiptRow('From', senderDisplay,
                            'Aura Bank: $senderAccDisplay'),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Divider(
                              color: cardBorder, height: 1, thickness: 1),
                        ),
                        _buildReceiptRow('To', recipientDisplay,
                            '$recipientBankDisplay: $recipientAccDisplay'),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Divider(
                              color: cardBorder, height: 1, thickness: 1),
                        ),
                        _buildSimpleRow('Transfer Amount',
                            'PHP ${_formatAmount(widget.amount)}'),
                        const SizedBox(height: 14),
                        _buildSimpleRow(
                          'Transfer Fee',
                          widget.fee == 0.0
                              ? 'FREE'
                              : 'PHP ${_formatAmount(widget.fee)}',
                          feeColor: widget.fee == 0.0 ? greenSuccess : textDark,
                        ),
                        const SizedBox(height: 14),
                        _buildSimpleRow('Total Amount',
                            'PHP ${_formatAmount(widget.amount + widget.fee)}',
                            isBold: true),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Divider(
                              color: cardBorder, height: 1, thickness: 1),
                        ),
                        _buildSimpleRow('Reference Number', refDisplay),
                        const SizedBox(height: 14),
                        _buildSimpleRow('Transaction Date', dateStr),
                        const SizedBox(height: 14),
                        _buildSimpleRow('Transaction Time', timeStr),
                        if (!_isSuccess) ...[
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Divider(
                                color: cardBorder, height: 1, thickness: 1),
                          ),
                          _buildSimpleRow('Status', 'Failed',
                              feeColor: redFail, isBold: true),
                          const SizedBox(height: 14),
                          _buildSimpleRow(
                              'Failure Reason',
                              widget.failureReason ??
                                  'Destination Bank Timeout'),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Actions Section
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        if (!_isSuccess) ...[
                          Container(
                            width: double.infinity,
                            height: 52,
                            decoration: BoxDecoration(
                              color: brandViolet,
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [
                                BoxShadow(
                                  color: brandViolet.withValues(alpha: 0.35),
                                  blurRadius: 18,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18)),
                              ),
                              onPressed: widget.onTryAgain ??
                                  () => Navigator.of(context).pop(),
                              child: const Text(
                                'Try Again',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],

                        // Primary / Secondary CTA: "Back to home" (Scan - Image 6 & Failed)
                        Container(
                          width: double.infinity,
                          height: 52,
                          decoration: BoxDecoration(
                            color: _isSuccess ? brandViolet : Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: _isSuccess
                                ? null
                                : Border.all(color: const Color(0xFFE6E8EA)),
                            boxShadow: [
                              BoxShadow(
                                color: _isSuccess
                                    ? brandViolet.withValues(alpha: 0.35)
                                    : Colors.black.withValues(alpha: 0.04),
                                blurRadius: _isSuccess ? 18 : 14,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18)),
                            ),
                            onPressed: _handleBackToHome,
                            child: Text(
                              'Back to home',
                              style: TextStyle(
                                color: _isSuccess ? Colors.white : brandViolet,
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
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
        Text(
          label,
          style: const TextStyle(
            fontSize: 13.5,
            color: textMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: textDark,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subValue,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: textMuted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSimpleRow(String label, String value,
      {Color? feeColor, bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13.5,
            color: textMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: isBold ? FontWeight.w800 : FontWeight.w700,
                color: feeColor ?? textDark,
              ),
            ),
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
