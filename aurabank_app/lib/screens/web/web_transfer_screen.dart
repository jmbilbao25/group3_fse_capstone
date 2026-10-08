import 'package:flutter/material.dart';
import '../../services/bank_service.dart';

class WebTransferScreen extends StatefulWidget {
  final VoidCallback? onBack;

  const WebTransferScreen({super.key, this.onBack});

  @override
  State<WebTransferScreen> createState() => _WebTransferScreenState();
}

class _WebTransferScreenState extends State<WebTransferScreen> {
  final BankService _bankService = BankService();

  // Form State
  String _selectedSourceAccount = 'Savings';
  bool _isAuraToAura = true;
  String _selectedPartnerBank = 'MeyBank';
  String _selectedPurpose = 'Remittance';

  final TextEditingController _accountController =
      TextEditingController(text: '1234568898951');
  final TextEditingController _recipientController =
      TextEditingController(text: 'Jessie Mae Dela Paz');
  final TextEditingController _amountController =
      TextEditingController(text: '5000');
  final TextEditingController _remarksController =
      TextEditingController();

  bool _isSubmitting = false;

  static const Color brandViolet = Color(0xFF380084);
  static const Color borderLight = Color(0xFFE5E7EB);
  static const Color bgSurface = Color(0xFFF9FAFB);

  List<Map<String, dynamic>> get _sourceAccounts => [
        {
          'type': 'Savings',
          'title': 'Savings Account',
          'accountNo': 'AUR-SAV-9821(1000-2000-3001)',
          'balance': _bankService.availableBalance,
        },
        {
          'type': 'Current',
          'title': 'Current Account',
          'accountNo': 'AUR-CUR-4412(1000-2000-3002)',
          'balance': 125000.0,
        },
        {
          'type': 'Credit',
          'title': 'Credit Line Account',
          'accountNo': 'AUR-CRD-7703(1000-2000-3003)',
          'balance': 75000.0,
        },
      ];

  static const List<Map<String, dynamic>> _frequentPayees = [
    {
      'name': 'Jessie',
      'fullName': 'Jessie Mae Dela Paz',
      'initials': 'JM',
      'account': '1234568898951',
      'bgColor': Color(0xFFEDE9FE),
      'textColor': Color(0xFF5B21B6),
      'isAura': true,
      'bank': 'Aura Bank Direct ••••• 98951',
    },
    {
      'name': 'Alex',
      'fullName': 'Alex Tan',
      'initials': 'AT',
      'account': '9876543210123',
      'bgColor': Color(0xFFE0E7FF),
      'textColor': Color(0xFF3730A3),
      'isAura': false,
      'bank': 'MeyBank ••••• 10123',
    },
  ];

  static const List<String> _purposes = [
    'Remittance',
    'Funds Transfer',
    'Bills Payment',
    'Savings & Stash',
    'Payroll / Allowance',
  ];

  @override
  void initState() {
    super.initState();
    _bankService.addListener(_onServiceUpdate);
    _amountController.addListener(() => setState(() {}));
    _accountController.addListener(() => setState(() {}));
    _recipientController.addListener(() => setState(() {}));
    _remarksController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _bankService.removeListener(_onServiceUpdate);
    _accountController.dispose();
    _recipientController.dispose();
    _amountController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  void _onServiceUpdate() {
    if (mounted) setState(() {});
  }

  Map<String, dynamic> get _currentSourceAccountData {
    return _sourceAccounts.firstWhere(
      (a) => a['type'] == _selectedSourceAccount,
      orElse: () => _sourceAccounts.first,
    );
  }

  double get _currentSourceBalance =>
      (_currentSourceAccountData['balance'] as double?) ?? 0.0;

  double get _parsedAmount {
    final clean = _amountController.text.replaceAll(',', '').trim();
    return double.tryParse(clean) ?? 0.0;
  }

  double get _transferFee => _isAuraToAura ? 0.0 : 10.0;

  double get _totalDebit => _parsedAmount + _transferFee;

  void _setExactAmount(double val) {
    setState(() {
      _amountController.text = val.toInt().toString();
    });
  }

  String _formatCurrency(double val) {
    final parts = val.toStringAsFixed(2).split('.');
    final integerPart = parts[0].replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
    return '$integerPart.${parts[1]}';
  }

  void _applyPayee(Map<String, dynamic> payee) {
    setState(() {
      _recipientController.text = payee['fullName'] as String;
      _accountController.text = payee['account'] as String;
      _isAuraToAura = payee['isAura'] as bool;
    });
  }

  void _initiateTransfer() {
    final amount = _parsedAmount;

    if (amount <= 0) {
      _showWarningSnackBar('Please enter a valid transfer amount.');
      return;
    }

    if (_totalDebit > _currentSourceBalance) {
      _showWarningSnackBar(
          'Total deduction (PHP ${_formatCurrency(_totalDebit)}) exceeds available balance.');
      return;
    }

    if (_accountController.text.trim().isEmpty) {
      _showWarningSnackBar('Please enter the recipient account number.');
      return;
    }

    if (_recipientController.text.trim().isEmpty) {
      _showWarningSnackBar('Please enter the recipient name.');
      return;
    }

    _showVerificationModal();
  }

  void _showWarningSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFFDC2626),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showVerificationModal() {
    showDialog(
      context: context,
      barrierDismissible: !_isSubmitting,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              elevation: 0,
              backgroundColor: Colors.transparent,
              child: Container(
                width: 480,
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFAF5FF),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.lock_outline_rounded,
                        color: brandViolet,
                        size: 26,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Confirm Transfer',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Please review the transfer details before proceeding.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: borderLight),
                      ),
                      child: Column(
                        children: [
                          _buildModalRow('Recipient', _recipientController.text.trim()),
                          const SizedBox(height: 8),
                          _buildModalRow('Account Number', _accountController.text.trim()),
                          const SizedBox(height: 8),
                          _buildModalRow(
                            'Bank',
                            _isAuraToAura ? 'Aura Bank (Direct)' : _selectedPartnerBank,
                          ),
                          const Divider(height: 20, color: borderLight),
                          _buildModalRow(
                            'Transfer Amount',
                            'PHP ${_formatCurrency(_parsedAmount)}',
                            isBold: true,
                          ),
                          const SizedBox(height: 6),
                          _buildModalRow(
                            'Transfer Fee',
                            _transferFee == 0
                                ? 'FREE'
                                : 'PHP ${_formatCurrency(_transferFee)}',
                            color: _transferFee == 0
                                ? const Color(0xFF16A34A)
                                : const Color(0xFF374151),
                          ),
                          const Divider(height: 20, color: borderLight),
                          _buildModalRow(
                            'Total Deduction',
                            'PHP ${_formatCurrency(_totalDebit)}',
                            isBold: true,
                            color: brandViolet,
                            fontSize: 16,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _isSubmitting ? null : () => Navigator.of(ctx).pop(),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFFD1D5DB)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF4B5563),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isSubmitting
                                ? null
                                : () async {
                                    setModalState(() => _isSubmitting = true);
                                    setState(() => _isSubmitting = true);

                                    final result = await _bankService.executeTransfer(
                                      targetAccount: _accountController.text.trim(),
                                      recipientName: _recipientController.text.trim(),
                                      amount: _parsedAmount,
                                      destinationBank: _isAuraToAura ? 'Aura Bank Direct' : _selectedPartnerBank,
                                      remarks: _remarksController.text.trim().isNotEmpty
                                          ? _remarksController.text.trim()
                                          : _selectedPurpose,
                                    );

                                    setModalState(() => _isSubmitting = false);
                                    if (mounted) setState(() => _isSubmitting = false);

                                    if (ctx.mounted) Navigator.of(ctx).pop();

                                    final isOk = result['success'] == true;
                                    if (isOk) {
                                      _showReceiptModal((result['reference'] ?? result['t24_reference'] ??
                                          'TXN-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}') as String);
                                    } else {
                                      _showWarningSnackBar((result['failureReason'] ?? result['message'] ?? 'Transfer failed') as String);
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: brandViolet,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: _isSubmitting
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor:
                                          AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : const Text(
                                    'Confirm & Send',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildModalRow(
    String label,
    String value, {
    bool isBold = false,
    Color? color,
    double fontSize = 13,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12.5,
            color: Color(0xFF6B7280),
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
            color: color ?? const Color(0xFF111827),
          ),
        ),
      ],
    );
  }

  void _showReceiptModal(String ref) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            width: 480,
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(
                    color: Color(0xFFDCFCE7),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xFF16A34A),
                    size: 34,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Transfer Successful',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Your funds have been transferred successfully.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                ),
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAF5FF),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFF3E8FF)),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'TOTAL DEDUCTION',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF6B21A8),
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'PHP ${_formatCurrency(_totalDebit)}',
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF1E103F),
                        ),
                      ),
                      const Divider(height: 20, color: Color(0xFFE9D5FF)),
                      _buildModalRow('Reference Number', ref),
                      const SizedBox(height: 6),
                      _buildModalRow('Recipient', _recipientController.text.trim()),
                      const SizedBox(height: 6),
                      _buildModalRow('Account Number', _accountController.text.trim()),
                      const SizedBox(height: 6),
                      _buildModalRow('Status', 'COMPLETED', color: const Color(0xFF16A34A)),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: brandViolet,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    child: const Text('Done', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 28.0),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 920;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Page Title & Back Button
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: borderLight),
                        ),
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: const Icon(Icons.arrow_back_rounded, size: 18, color: Color(0xFF374151)),
                          onPressed: () {
                            if (widget.onBack != null) {
                              widget.onBack!();
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Send Money',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF111827),
                              letterSpacing: -0.4,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Fast and secure local and inter-bank transfers',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF6B7280),
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  if (isWide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left Column (Form)
                        Expanded(
                          flex: 62,
                          child: _buildMainTransferForm(),
                        ),
                        const SizedBox(width: 24),
                        // Right Column (Summary & Frequent Payees)
                        Expanded(
                          flex: 38,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildTransferSummaryCard(),
                              const SizedBox(height: 20),
                              _buildFrequentPayeesCard(),
                            ],
                          ),
                        ),
                      ],
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildMainTransferForm(),
                        const SizedBox(height: 24),
                        _buildTransferSummaryCard(),
                        const SizedBox(height: 20),
                        _buildFrequentPayeesCard(),
                      ],
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // --- MAIN FORM (LEFT COLUMN) ---
  Widget _buildMainTransferForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header: FROM SOURCE ACCOUNT
        const Text(
          'FROM SOURCE ACCOUNT',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: Color(0xFF6B7280),
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 10),

        // Source Account Selector Card
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderLight),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedSourceAccount,
              isExpanded: true,
              icon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: Color(0xFF6B7280),
                size: 22,
              ),
              items: _sourceAccounts.map((acc) {
                return DropdownMenuItem<String>(
                  value: acc['type'] as String,
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(
                          color: brandViolet,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.account_balance_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              acc['title'] as String,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF111827),
                              ),
                            ),
                            const SizedBox(height: 2),
                            RichText(
                              text: TextSpan(
                                style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                                children: [
                                  TextSpan(
                                    text: '${acc['accountNo']} • Available: ',
                                  ),
                                  TextSpan(
                                    text: '₱${_formatCurrency(acc['balance'] as double)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF111827),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedSourceAccount = val);
              },
            ),
          ),
        ),

        const SizedBox(height: 20),

        // Channel Segmented Buttons: Aura to Aura vs Other Bank
        Container(
          height: 44,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFFE5E7EB),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _isAuraToAura = true),
                  borderRadius: BorderRadius.circular(9),
                  child: Container(
                    decoration: BoxDecoration(
                      color: _isAuraToAura ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(9),
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
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.bolt_rounded,
                          size: 16,
                          color: _isAuraToAura ? brandViolet : const Color(0xFF6B7280),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Aura to Aura',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _isAuraToAura ? const Color(0xFF111827) : const Color(0xFF4B5563),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Free',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF16A34A),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _isAuraToAura = false),
                  borderRadius: BorderRadius.circular(9),
                  child: Container(
                    decoration: BoxDecoration(
                      color: !_isAuraToAura ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(9),
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
                        Icon(
                          Icons.account_balance_rounded,
                          size: 15,
                          color: !_isAuraToAura ? brandViolet : const Color(0xFF6B7280),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Other Bank',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: !_isAuraToAura ? const Color(0xFF111827) : const Color(0xFF4B5563),
                          ),
                        ),
                        const SizedBox(width: 5),
                        const Text(
                          'InstaPay (₱10)',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF6B7280),
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

        const SizedBox(height: 20),

        // Form Fields Container
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderLight),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!_isAuraToAura) ...[
                const Text(
                  'Destination Bank',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF374151),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
                  decoration: BoxDecoration(
                    color: bgSurface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: borderLight),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedPartnerBank,
                      isExpanded: true,
                      icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: Color(0xFF6B7280)),
                      items: const [
                        DropdownMenuItem(value: 'MeyBank', child: Text('MeyBank (Group 2 Partner)')),
                        DropdownMenuItem(value: 'Apex Digital Bank', child: Text('Apex Digital Bank (Group 1 Partner)')),
                        DropdownMenuItem(value: 'Nexus Core Bank', child: Text('Nexus Core Bank (Group 4 Partner)')),
                        DropdownMenuItem(value: 'BDO Unibank', child: Text('BDO Unibank')),
                        DropdownMenuItem(value: 'BPI', child: Text('Bank of the Philippine Islands')),
                        DropdownMenuItem(value: 'GCash', child: Text('GCash Wallet')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedPartnerBank = val);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 18),
              ],

              // Account Number
              const Text(
                'Account Number',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF374151),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(
                  color: bgSurface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: borderLight),
                ),
                child: TextField(
                  controller: _accountController,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                    letterSpacing: 0.5,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // Recipient Name
              const Text(
                'Recipient Name',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF374151),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(
                  color: bgSurface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: borderLight),
                ),
                child: TextField(
                  controller: _recipientController,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // Enter Amount Header + Transfer Fee indicator
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Enter Amount',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF374151),
                    ),
                  ),
                  Text(
                    _isAuraToAura ? 'Transfer Fee: PHP 0.00' : 'Transfer Fee: PHP 10.00',
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: Color(0xFF9CA3AF),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // Amount Input Field with leading PHP
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: bgSurface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: borderLight),
                ),
                child: Row(
                  children: [
                    const Text(
                      'PHP',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _amountController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF111827),
                        ),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: '0',
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 6),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Quick Amount Pills (+ PHP 1,000, + PHP 5,000, + PHP 10,000)
              Row(
                children: [
                  _buildQuickAmountPill('+ PHP 1,000', 1000.0),
                  const SizedBox(width: 8),
                  _buildQuickAmountPill('+ PHP 5,000', 5000.0),
                  const SizedBox(width: 8),
                  _buildQuickAmountPill('+ PHP 10,000', 10000.0),
                ],
              ),

              const SizedBox(height: 18),

              // Purpose & Remarks side by side
              Row(
                children: [
                  // Purpose Dropdown
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Purpose',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF374151),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                          decoration: BoxDecoration(
                            color: bgSurface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: borderLight),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedPurpose,
                              isExpanded: true,
                              icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: Color(0xFF6B7280)),
                              items: _purposes.map((p) {
                                return DropdownMenuItem(
                                  value: p,
                                  child: Row(
                                    children: [
                                      const Icon(Icons.send_rounded, size: 14, color: brandViolet),
                                      const SizedBox(width: 8),
                                      Text(
                                        p,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF111827),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) setState(() => _selectedPurpose = val);
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 14),

                  // Remarks (Optional)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Remarks (Optional)',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF374151),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          decoration: BoxDecoration(
                            color: bgSurface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: borderLight),
                          ),
                          child: TextField(
                            controller: _remarksController,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF111827),
                            ),
                            decoration: const InputDecoration(
                              hintText: 'Enter details...',
                              hintStyle: TextStyle(
                                color: Color(0xFF9CA3AF),
                                fontSize: 13,
                              ),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuickAmountPill(String label, double val) {
    return InkWell(
      onTap: () => _setExactAmount(val),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: bgSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderLight),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF374151),
          ),
        ),
      ),
    );
  }

  // --- RIGHT COLUMN: TRANSFER SUMMARY CARD ---
  Widget _buildTransferSummaryCard() {
    final recipientName = _recipientController.text.trim().isNotEmpty
        ? _recipientController.text.trim()
        : 'Jessie Mae Dela Paz';
    final accountNum = _accountController.text.trim().isNotEmpty
        ? _accountController.text.trim()
        : '1234568898951';
    final last5 = accountNum.length >= 5
        ? accountNum.substring(accountNum.length - 5)
        : accountNum;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Transfer Summary',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 16),

          // Recipient Preview Capsule
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFAF5FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: brandViolet,
                  child: Text(
                    recipientName.isNotEmpty ? recipientName[0] : 'J',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              recipientName,
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF111827),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.check_circle,
                            size: 14,
                            color: Color(0xFF10B981),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _isAuraToAura
                            ? 'Aura Bank Direct ••••• $last5'
                            : '$_selectedPartnerBank ••••• $last5',
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFF6B7280),
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Transfer Amount Breakdown
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Transfer Amount',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF6B7280),
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                'PHP ${_formatCurrency(_parsedAmount)}',
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Transfer Fee Breakdown
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Transfer Fee',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF6B7280),
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                _transferFee == 0 ? 'FREE' : 'PHP ${_formatCurrency(_transferFee)}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: _transferFee == 0 ? const Color(0xFF10B981) : const Color(0xFF111827),
                ),
              ),
            ],
          ),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(color: borderLight, height: 1),
          ),

          // Total Deduction
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              const Text(
                'Total Deduction',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                ),
              ),
              Text(
                'PHP ${_formatCurrency(_totalDebit)}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF111827),
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // CTA: Send Money Now ->
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _initiateTransfer,
              style: ElevatedButton.styleFrom(
                backgroundColor: brandViolet,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Text(
                    'Send Money Now',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward_rounded, size: 16, color: Colors.white),
                ],
              ),
            ),
          ),

          const SizedBox(height: 14),

          // Protected by 256-bit Bank Encryption
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.shield_outlined, size: 13, color: Color(0xFF10B981)),
              SizedBox(width: 6),
              Text(
                'Protected by 256-bit Bank Encryption',
                style: TextStyle(
                  fontSize: 11,
                  color: Color(0xFF6B7280),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- RIGHT COLUMN: FREQUENT PAYEES CARD ---
  Widget _buildFrequentPayeesCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'FREQUENT PAYEES',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Color(0xFF6B7280),
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: _frequentPayees.map((p) {
              return Padding(
                padding: const EdgeInsets.only(right: 18.0),
                child: InkWell(
                  onTap: () => _applyPayee(p),
                  borderRadius: BorderRadius.circular(12),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: p['bgColor'] as Color,
                        child: Text(
                          p['initials'] as String,
                          style: TextStyle(
                            color: p['textColor'] as Color,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        p['name'] as String,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF374151),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
