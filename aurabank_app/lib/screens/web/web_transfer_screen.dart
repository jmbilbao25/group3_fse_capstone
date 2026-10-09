import 'dart:math' as math;
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

  static const List<Map<String, dynamic>> _purposes = [
    {
      'title': 'Remittance',
      'subtitle': 'Family support & personal remittance',
      'icon': Icons.send_rounded,
    },
    {
      'title': 'Funds Transfer',
      'subtitle': 'General fund & account movement',
      'icon': Icons.swap_horiz_rounded,
    },
    {
      'title': 'Bills Payment',
      'subtitle': 'Utilities, dues & merchant checkout',
      'icon': Icons.receipt_long_rounded,
    },
    {
      'title': 'Savings',
      'subtitle': 'Personal stash & emergency reserve',
      'icon': Icons.account_balance_rounded,
    },
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
    // Step 1: Confirmation Modal (Desktop Dialog)
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
                width: 460,
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 32,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFAF5FF),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.shield_rounded,
                        color: brandViolet,
                        size: 28,
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
                    Text(
                      'You are sending PHP ${_formatCurrency(_parsedAmount)} to ${_recipientController.text.trim()}. Please confirm to proceed with secure verification.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF6B7280),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAF5FF),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFF3E8FF)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Amount',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'PHP ${_formatCurrency(_parsedAmount)}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF111827),
                                ),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text(
                                'Memo',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _remarksController.text.trim().isNotEmpty
                                    ? _remarksController.text.trim()
                                    : _selectedPurpose,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF111827),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(14),
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
                          const Divider(height: 18, color: borderLight),
                          _buildModalRow(
                            'Transfer Fee',
                            _transferFee == 0
                                ? 'FREE'
                                : 'PHP ${_formatCurrency(_transferFee)}',
                            color: _transferFee == 0
                                ? const Color(0xFF16A34A)
                                : const Color(0xFF374151),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          _showBiometricApprovalModal();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: brandViolet,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.shield_rounded, size: 18, color: Colors.white),
                            SizedBox(width: 8),
                            Text(
                              'Verify & Transfer',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text(
                        'Cancel Transaction',
                        style: TextStyle(
                          color: Color(0xFF6B7280),
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
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

  // Step 2: Approve with Biometrics (WebAuthn / Passkey Simulation)
  void _showBiometricApprovalModal() {
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
                width: 460,
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 32,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAF5FF),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFE9D5FF),
                          width: 2,
                        ),
                      ),
                      child: const Icon(
                        Icons.face_retouching_natural_rounded,
                        color: brandViolet,
                        size: 34,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Approve with Biometrics',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Authorize with your biometrics or WebAuthn passkey to confirm this transfer.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF6B7280),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 18),
                    // Security verification status badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFA7F3D0)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.verified_rounded,
                            color: Color(0xFF059669),
                            size: 15,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Identity Verified • Secure Web Transfer',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF065F46),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
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
                                  destinationBank: _isAuraToAura
                                      ? 'Aura Bank Direct'
                                      : _selectedPartnerBank,
                                  remarks: _remarksController.text.trim().isNotEmpty
                                      ? _remarksController.text.trim()
                                      : _selectedPurpose,
                                );

                                setModalState(() => _isSubmitting = false);
                                if (mounted) setState(() => _isSubmitting = false);

                                if (ctx.mounted) Navigator.of(ctx).pop();

                                final isOk = result['success'] == true;
                                if (isOk) {
                                  _showReceiptModal((result['reference'] ??
                                          result['t24_reference'] ??
                                          'FT${DateTime.now().millisecondsSinceEpoch.toString().substring(3)}')
                                      as String);
                                } else {
                                  _showWarningSnackBar(
                                      (result['failureReason'] ??
                                              result['message'] ??
                                              'Transfer failed')
                                          as String);
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: brandViolet,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                        ),
                        child: _isSubmitting
                            ? const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  ),
                                  SizedBox(width: 10),
                                  Text(
                                    'Verifying Biometrics...',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.fingerprint_rounded, size: 20, color: Colors.white),
                                  SizedBox(width: 8),
                                  Text(
                                    'Confirm with Biometrics',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: _isSubmitting ? null : () => Navigator.of(ctx).pop(),
                      child: const Text(
                        'Cancel Transaction',
                        style: TextStyle(
                          color: Color(0xFF6B7280),
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
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

  // Step 3: Transaction Receipt Modal (Clean Desktop Architecture)
  void _showReceiptModal(String ref) {
    final now = DateTime.now();
    final months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    final dateStr = '${now.day.toString().padLeft(2, '0')} ${months[now.month - 1]} ${now.year}';
    final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

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
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 36,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 58,
                  height: 58,
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
                const SizedBox(height: 14),
                const Text(
                  'Transaction Receipt',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'PHP ${_formatCurrency(_parsedAmount)}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF111827),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: borderLight),
                  ),
                  child: Column(
                    children: [
                      _buildModalRow(
                        'From',
                        '${_currentSourceAccountData['title']} • ${_currentSourceAccountData['accountNo']}',
                      ),
                      const SizedBox(height: 8),
                      _buildModalRow(
                        'To',
                        '${_recipientController.text.trim()} (${_accountController.text.trim()})',
                      ),
                      const Divider(height: 20, color: borderLight),
                      _buildModalRow('Transfer Amount', 'PHP ${_formatCurrency(_parsedAmount)}'),
                      const SizedBox(height: 8),
                      _buildModalRow(
                        'Transfer Fee',
                        _transferFee == 0 ? 'FREE' : 'PHP ${_formatCurrency(_transferFee)}',
                        color: _transferFee == 0 ? const Color(0xFF16A34A) : const Color(0xFF111827),
                      ),
                      const SizedBox(height: 8),
                      _buildModalRow(
                        'Total Amount',
                        'PHP ${_formatCurrency(_totalDebit)}',
                        isBold: true,
                      ),
                      const Divider(height: 20, color: borderLight),
                      _buildModalRow('Reference Number', ref),
                      const SizedBox(height: 8),
                      _buildModalRow('Transaction Date', dateStr),
                      const SizedBox(height: 8),
                      _buildModalRow('Transaction Time', timeStr),
                      const SizedBox(height: 8),
                      _buildModalRow('Status', 'COMPLETED', color: const Color(0xFF16A34A)),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: brandViolet,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Back to Home',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                    ),
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

              return isWide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left Column (Form)
                        Expanded(
                          flex: 60,
                          child: _buildMainTransferForm(),
                        ),
                        const SizedBox(width: 24),
                        // Right Column (Transfer Summary)
                        Expanded(
                          flex: 40,
                          child: _buildTransferSummaryCard(),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildMainTransferForm(),
                        const SizedBox(height: 24),
                        _buildTransferSummaryCard(),
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
          const SizedBox(height: 12),

          // Source Account Selector Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(12),
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
              color: const Color(0xFFF3F4F6),
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
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

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
              RichText(
                text: TextSpan(
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF6B7280)),
                  children: [
                    const TextSpan(text: 'Transfer Fee: '),
                    TextSpan(
                      text: _isAuraToAura ? 'FREE' : 'PHP 10.00',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: _isAuraToAura ? const Color(0xFF10B981) : const Color(0xFF111827),
                      ),
                    ),
                  ],
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
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: bgSurface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: borderLight),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedPurpose,
                          isExpanded: true,
                          itemHeight: 64,
                          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: Color(0xFF6B7280)),
                          items: _purposes.map((p) {
                            final title = p['title'] as String;
                            final subtitle = p['subtitle'] as String;
                            final icon = p['icon'] as IconData;

                            return DropdownMenuItem<String>(
                              value: title,
                              child: Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFAF5FF),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: const Color(0xFFF3E8FF)),
                                    ),
                                    child: Icon(
                                      icon,
                                      size: 18,
                                      color: brandViolet,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          title,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF111827),
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 1),
                                        Text(
                                          subtitle,
                                          style: const TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w400,
                                            color: Color(0xFF6B7280),
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                          selectedItemBuilder: (context) {
                            return _purposes.map((p) {
                              final title = p['title'] as String;
                              final icon = p['icon'] as IconData;
                              return Row(
                                children: [
                                  Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFAF5FF),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      icon,
                                      size: 16,
                                      color: brandViolet,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      title,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF111827),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              );
                            }).toList();
                          },
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

          // Recipient & Route Preview Capsule (From -> To with vertical connecting line)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderLight),
            ),
            child: Column(
              children: [
                // Sender (DEBIT ACCOUNT)
                Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: const BoxDecoration(
                        color: Color(0xFFEDE9FE),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_upward_rounded,
                        size: 15,
                        color: Color(0xFF6B21A8),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'DEBIT ACCOUNT',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF6B7280),
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            'Savings (AUR-SAV-9821)',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF111827),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // Connecting Line
                Padding(
                  padding: const EdgeInsets.only(left: 13),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      width: 2,
                      height: 16,
                      color: const Color(0xFFE9D5FF),
                    ),
                  ),
                ),

                // Recipient (CREDIT ACCOUNT)
                Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: const BoxDecoration(
                        color: Color(0xFFD1FAE5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_downward_rounded,
                        size: 15,
                        color: Color(0xFF059669),
                      ),
                    ),
                    const SizedBox(width: 10),
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
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF111827),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.check_circle,
                                size: 13,
                                color: Color(0xFF10B981),
                              ),
                            ],
                          ),
                          const SizedBox(height: 1),
                          Text(
                            _isAuraToAura
                                ? 'Aura Bank Direct ••••• $last5'
                                : '$_selectedPartnerBank ••••• $last5',
                            style: const TextStyle(
                              fontSize: 11,
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
                  fontSize: 12.5,
                  color: Color(0xFF6B7280),
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                'PHP ${_formatCurrency(_parsedAmount)}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Transfer Fee Breakdown
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Transfer Fee',
                style: TextStyle(
                  fontSize: 12.5,
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

          const SizedBox(height: 10),

          // Settlement Speed
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Settlement Speed',
                style: TextStyle(
                  fontSize: 12.5,
                  color: Color(0xFF6B7280),
                  fontWeight: FontWeight.w500,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.bolt_rounded, size: 14, color: Color(0xFF10B981)),
                  SizedBox(width: 2),
                  Text(
                    'Real-Time (Instant)',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF10B981),
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Balance After Transfer
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Balance After Transfer',
                style: TextStyle(
                  fontSize: 12.5,
                  color: Color(0xFF6B7280),
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                '₱${_formatCurrency(math.max(0.0, _currentSourceBalance - _totalDebit))}',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // Total Deduction Card (Lavender Tint)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF3E8FF).withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Total Deduction',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111827),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Debited immediately',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: Color(0xFF6B7280),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                Text(
                  'PHP ${_formatCurrency(_totalDebit)}',
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    color: brandViolet,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

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
        ],
      ),
    );
  }
}
