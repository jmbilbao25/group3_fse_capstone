import 'package:flutter/material.dart';
import '../services/bank_service.dart';
import '../theme/aura_theme.dart';
import '../widgets/aura_logo.dart';
import 'review_transfer_screen.dart';

class SendMoneyScreen extends StatefulWidget {
  final VoidCallback? onBack;

  const SendMoneyScreen({super.key, this.onBack});

  @override
  State<SendMoneyScreen> createState() => _SendMoneyScreenState();
}

class _SendMoneyScreenState extends State<SendMoneyScreen> {
  final BankService _bankService = BankService();
  bool _isAuraToAura = true;

  final TextEditingController _accountController =
      TextEditingController(text: '1234 5678 9123 4569');
  final TextEditingController _recipientController =
      TextEditingController(text: 'Jessie Mae Dela Paz');
  final TextEditingController _amountController =
      TextEditingController(text: '50000.00');
  final TextEditingController _remarksController = TextEditingController();

  String _selectedPurpose = 'Personal / Family';
  final List<String> _purposes = [
    'Personal / Family',
    'Bills & Utilities',
    'Business / Supplier',
    'Investment / Savings',
    'Emergency',
  ];

  static const Color brandViolet = AuraColors.primary;
  static const Color textDark = AuraColors.textPrimary;
  static const Color textGray = AuraColors.textMuted;
  static const Color cardBorder = AuraColors.cardBorder;
  static const Color greenCredit = AuraColors.creditGreen;

  @override
  void dispose() {
    _accountController.dispose();
    _recipientController.dispose();
    _amountController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fee = _isAuraToAura ? 0.0 : 10.0;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // Top Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                        color: textDark,
                        onPressed: widget.onBack ?? () => Navigator.of(context).pop(),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      ),
                      const SizedBox(width: 8),
                      const AuraLogo(size: 32, style: AuraLogoStyle.violet, borderRadius: 8),
                      const SizedBox(width: 10),
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
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // From Section
                        const Text(
                          'From:',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: textDark),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: cardBorder, width: 1.2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.02),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Savings Account',
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: textDark),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Avail: ₱ ${_formatAmountPlain(_bankService.availableBalance)}',
                                    style: const TextStyle(fontSize: 11, color: textGray),
                                  ),
                                ],
                              ),
                              const Icon(Icons.keyboard_arrow_down_rounded, color: textDark),
                            ],
                          ),
                        ),

                        const SizedBox(height: 18),

                        // Transfer Mode Toggle: Aura to Aura vs Other Bank
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => setState(() => _isAuraToAura = true),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    decoration: BoxDecoration(
                                      color: _isAuraToAura ? Colors.white : Colors.transparent,
                                      borderRadius: BorderRadius.circular(10),
                                      boxShadow: _isAuraToAura
                                          ? [
                                              BoxShadow(
                                                color: Colors.black.withValues(alpha: 0.05),
                                                blurRadius: 4,
                                                offset: const Offset(0, 1),
                                              ),
                                            ]
                                          : null,
                                    ),
                                    child: Center(
                                      child: Text(
                                        'Aura to Aura',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: _isAuraToAura ? brandViolet : textGray,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => setState(() => _isAuraToAura = false),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    decoration: BoxDecoration(
                                      color: !_isAuraToAura ? Colors.white : Colors.transparent,
                                      borderRadius: BorderRadius.circular(10),
                                      boxShadow: !_isAuraToAura
                                          ? [
                                              BoxShadow(
                                                color: Colors.black.withValues(alpha: 0.05),
                                                blurRadius: 4,
                                                offset: const Offset(0, 1),
                                              ),
                                            ]
                                          : null,
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.account_balance_rounded,
                                            size: 15, color: !_isAuraToAura ? brandViolet : textGray),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Other Bank',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: !_isAuraToAura ? brandViolet : textGray,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 18),

                        // Partner Bank info card if Other Bank selected (PDF Page 8)
                        if (!_isAuraToAura) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFDF4FF),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFF0ABFC), width: 0.8),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF701A75),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Center(
                                    child: Text('M', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: const [
                                      Text('MeyBank', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: textDark)),
                                      Text('Partner Bank', style: TextStyle(fontSize: 10, color: textGray)),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFD1FAE5),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text('Instapay', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: greenCredit)),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Account Number Input
                        _buildInputField(
                          label: 'Account Number',
                          controller: _accountController,
                          hint: 'Enter account number',
                          keyboardType: TextInputType.number,
                        ),

                        const SizedBox(height: 16),

                        // Recipient Name Input
                        _buildInputField(
                          label: 'Recipient Name',
                          controller: _recipientController,
                          hint: 'Enter recipient full name',
                        ),

                        const SizedBox(height: 16),

                        // Enter Amount Input
                        const Text(
                          'Enter Amount',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: textGray),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9FAFB),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: cardBorder),
                          ),
                          child: Row(
                            children: [
                              const Text('PHP ', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: textDark)),
                              Expanded(
                                child: TextField(
                                  controller: _amountController,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: textDark),
                                  decoration: const InputDecoration(border: InputBorder.none),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 6),
                        Text(
                          _isAuraToAura ? 'Transfer Fee: FREE' : 'Transfer Fee: PHP 10.00',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _isAuraToAura ? greenCredit : textGray,
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Purpose Selector
                        const Text(
                          'Purpose',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: textGray),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9FAFB),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: cardBorder),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              isDense: true,
                              isExpanded: true,
                              value: _selectedPurpose,
                              items: _purposes.map((p) {
                                return DropdownMenuItem(value: p, child: Text(p, style: const TextStyle(fontSize: 13, color: textDark, fontWeight: FontWeight.w600)));
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) setState(() => _selectedPurpose = val);
                              },
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Remarks (Optional)
                        _buildInputField(
                          label: 'Remarks (Optional)',
                          controller: _remarksController,
                          hint: 'Enter details',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // Bottom Sticky Button: "Send Money"
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    elevation: 0,
                  ),
                  onPressed: () {
                    final enteredAmount = double.tryParse(_amountController.text.replaceAll(',', '')) ?? 0.0;
                    if (enteredAmount <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter a valid amount')),
                      );
                      return;
                    }

                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => ReviewTransferScreen(
                          senderName: _bankService.user.name,
                          senderAccount: _bankService.savingsAccountNumber,
                          recipientName: _recipientController.text.trim(),
                          recipientAccount: _accountController.text.trim(),
                          recipientBank: _isAuraToAura ? 'Aura Bank' : 'MeyBank',
                          amount: enteredAmount,
                          fee: fee,
                          remarks: _remarksController.text.trim(),
                        ),
                      ),
                    );
                  },
                  child: const Text(
                    'Send Money',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: textGray),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: cardBorder),
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: textDark),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(fontSize: 13, color: textGray, fontWeight: FontWeight.w400),
              border: InputBorder.none,
            ),
          ),
        ),
      ],
    );
  }

  String _formatAmountPlain(double amount) {
    final parts = amount.toStringAsFixed(0);
    return parts.replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }
}
