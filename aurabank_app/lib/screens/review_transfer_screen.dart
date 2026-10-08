import 'package:flutter/material.dart';
import '../services/bank_service.dart';
import '../theme/aura_theme.dart';
import 'receipt_screen.dart';

class ReviewTransferScreen extends StatefulWidget {
  final String senderName;
  final String senderAccount;
  final String recipientName;
  final String recipientAccount;
  final String recipientBank;
  final double amount;
  final double fee;
  final String? remarks;

  const ReviewTransferScreen({
    super.key,
    required this.senderName,
    required this.senderAccount,
    required this.recipientName,
    required this.recipientAccount,
    required this.recipientBank,
    required this.amount,
    this.fee = 0.0,
    this.remarks,
  });

  @override
  State<ReviewTransferScreen> createState() => _ReviewTransferScreenState();
}

class _ReviewTransferScreenState extends State<ReviewTransferScreen> {
  final BankService _bankService = BankService();
  bool _isFavorite = false;

  static const Color brandViolet = AuraColors.primary;
  static const Color textDark = AuraColors.textPrimary;
  static const Color textGray = AuraColors.textMuted;
  static const Color cardBorder = AuraColors.cardBorder;
  static const Color greenSuccess = AuraColors.creditGreen;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AuraColors.canvas,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Bar
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                    color: textDark,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Review Transfer',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: textDark,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Sender & Recipient Card
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
                    // Sender
                    Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: const BoxDecoration(
                            color: AuraColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.person, color: Colors.white, size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.senderName,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: textDark,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Account No. ${widget.senderAccount}',
                                style: const TextStyle(fontSize: 11, color: textGray),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),
                    const Center(
                      child: Icon(Icons.keyboard_double_arrow_down_rounded, color: textGray, size: 24),
                    ),
                    const SizedBox(height: 12),

                    // Recipient
                    Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: const Color(0xFF7928CA).withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.account_balance_rounded, color: Color(0xFF7928CA), size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.recipientName,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: textDark,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${widget.recipientBank} No. ${widget.recipientAccount}',
                                style: const TextStyle(fontSize: 11, color: textGray),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // Amount Card
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
                    _buildAmountRow('Transfer Amount', 'PHP ${_formatAmount(widget.amount)}'),
                    const SizedBox(height: 14),
                    _buildAmountRow('Transfer Fee', widget.fee == 0.0 ? 'FREE' : 'PHP ${_formatAmount(widget.fee)}', feeColor: greenSuccess),
                    const Divider(color: cardBorder, height: 28),
                    _buildAmountRow('Total Amount', 'PHP ${_formatAmount(widget.amount + widget.fee)}', isTotal: true),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // Add as Favorite
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: cardBorder),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Add as Favorite',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textDark),
                    ),
                    IconButton(
                      icon: Icon(
                        _isFavorite ? Icons.favorite : Icons.favorite_border_rounded,
                        color: _isFavorite ? const Color(0xFFEF4444) : textGray,
                      ),
                      onPressed: () => setState(() => _isFavorite = !_isFavorite),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 36),

              // Confirm & Send Button
              Container(
                width: double.infinity,
                height: 50,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: AuraColors.buttonShadow,
                ),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: brandViolet,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                    elevation: 0,
                  ),
                  onPressed: _showConfirmationModal,
                  child: const Text(
                    'Confirm & Send',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                ),
              ),

              const SizedBox(height: 14),

              Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    'Cancel Transaction',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textGray),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAmountRow(String label, String value, {Color? feeColor, bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTotal ? 14 : 13,
            fontWeight: isTotal ? FontWeight.w700 : FontWeight.w500,
            color: isTotal ? textDark : textGray,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isTotal ? 16 : 14,
            fontWeight: isTotal ? FontWeight.w900 : FontWeight.w700,
            color: feeColor ?? textDark,
          ),
        ),
      ],
    );
  }

  void _showConfirmationModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: AuraColors.primary,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: const Color(0xFFE11D48).withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFE11D48), size: 36),
              ),
              const SizedBox(height: 16),
              const Text(
                'Do you want to continue?',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white),
              ),
              const SizedBox(height: 10),
              Text(
                'You are sending PHP ${_formatAmount(widget.amount)}. Please make sure the recipient details are correct, as completed transfers cannot be reversed.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: Colors.white70, height: 1.4),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Amount', style: TextStyle(fontSize: 11, color: textGray)),
                        const SizedBox(height: 2),
                        Text(
                          'PHP ${_formatAmount(widget.amount)}',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: textDark),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('To', style: TextStyle(fontSize: 11, color: textGray)),
                        const SizedBox(height: 2),
                        Text(
                          widget.recipientName,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: textDark),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: brandViolet,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  ),
                  onPressed: () async {
                    final navigator = Navigator.of(context);
                    navigator.pop();
                    final result = await _bankService.executeTransfer(
                      targetAccount: widget.recipientAccount,
                      recipientName: widget.recipientName,
                      amount: widget.amount,
                      destinationBank: widget.recipientBank,
                      remarks: widget.remarks,
                    );

                    if (!mounted) return;
                    navigator.pushReplacement(
                      MaterialPageRoute(
                        builder: (context) => TransactionReceiptScreen(
                          isSuccess: result['success'] == true,
                          senderName: widget.senderName,
                          senderAccount: widget.senderAccount,
                          recipientName: widget.recipientName,
                          recipientAccount: widget.recipientAccount,
                          recipientBank: widget.recipientBank,
                          amount: widget.amount,
                          fee: widget.fee,
                          referenceNumber: result['reference'] ?? 'AUR-990123',
                        ),
                      ),
                    );
                  },
                  child: const Text('Confirm Transfer', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel Transaction', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        );
      },
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
