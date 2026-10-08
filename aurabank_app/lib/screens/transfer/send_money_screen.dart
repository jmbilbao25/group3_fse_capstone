import 'package:flutter/material.dart';
import '../../services/bank_service.dart';
import '../../widgets/aura_logo.dart';
import '../../widgets/require_device_approval.dart';
import 'review_transfer_screen.dart';

class SendMoneyScreen extends StatefulWidget {
  final VoidCallback? onBack;
  final bool initialIsAuraToAura;
  final int initialPartnerBankIndex;
  final String? initialAccountNo;
  final String? initialRecipientName;
  final String? initialAmount;

  const SendMoneyScreen({
    super.key,
    this.onBack,
    this.initialIsAuraToAura = true,
    this.initialPartnerBankIndex = 0,
    this.initialAccountNo,
    this.initialRecipientName,
    this.initialAmount,
  });

  @override
  State<SendMoneyScreen> createState() => _SendMoneyScreenState();
}

class _SendMoneyScreenState extends State<SendMoneyScreen> {
  final BankService _bankService = BankService();
  late bool _isAuraToAura;
  late int _selectedPartnerBankIndex;

  String _selectedSourceAccount = 'Savings';
  String? _selectedPurpose;

  late final TextEditingController _accountController;
  late final TextEditingController _recipientController;
  late final TextEditingController _amountController;
  final TextEditingController _remarksController =
      TextEditingController();

  List<Map<String, dynamic>> get _sourceAccounts => [
    {
      'type': 'Savings',
      'title': 'Savings Account',
      'accountNo': 'AUR-SAV-9821 (${_bankService.activeAccountId})',
      'balance': _bankService.availableBalance,
      'icon': Icons.account_balance_rounded,
    },
    {
      'type': 'Current',
      'title': 'Current Account',
      'accountNo': 'AUR-CUR-4412',
      'balance': 125000.0,
      'icon': Icons.account_balance_wallet_rounded,
    },
    {
      'type': 'Credit',
      'title': 'Credit Account',
      'accountNo': 'AUR-CRD-7703',
      'balance': 75000.0,
      'icon': Icons.credit_card_rounded,
    },
  ];

  static const List<Map<String, dynamic>> _purposes = [
    {
      'name': 'Remittance',
      'icon': Icons.send_rounded,
      'desc': 'Family support & personal remittance',
    },
    {
      'name': 'Funds Transfer',
      'icon': Icons.swap_horiz_rounded,
      'desc': 'General fund & account movement',
    },
    {
      'name': 'Bills Payment',
      'icon': Icons.receipt_long_rounded,
      'desc': 'Utilities, dues & merchant checkout',
    },
    {
      'name': 'Savings',
      'icon': Icons.account_balance_rounded,
      'desc': 'Personal stash & emergency reserve',
    },
  ];

  static const List<Map<String, dynamic>> _partnerBanks = [
    {
      'name': 'MeyBank',
      'shortName': 'MeyBank',
      'group': 'Group 2 Partner Bank • MEY-002',
      'avatar': 'M',
      'color': Color(0xFF701A75),
    },
    {
      'name': 'Apex Digital Bank',
      'shortName': 'Apex Digital',
      'group': 'Group 1 Partner Bank • APX-001',
      'avatar': 'A',
      'color': Color(0xFF047857),
    },
    {
      'name': 'Nexus Core Bank',
      'shortName': 'Nexus Core',
      'group': 'Group 4 Partner Bank • NEX-004',
      'avatar': 'N',
      'color': Color(0xFF1E3A8A),
    },
  ];
  @override
  void initState() {
    super.initState();
    _isAuraToAura = widget.initialIsAuraToAura;
    _selectedPartnerBankIndex = widget.initialPartnerBankIndex;
    _bankService.addListener(_onServiceUpdate);
    _accountController = TextEditingController(
      text: widget.initialAccountNo ?? '1234568898951',
    );
    _recipientController = TextEditingController(
      text: widget.initialRecipientName ?? 'Jessie Mae Dela Paz',
    );
    _amountController = TextEditingController(
      text: widget.initialAmount ?? '',
    );
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

  double get _currentSourceBalance {
    final match = _sourceAccounts.firstWhere(
      (a) => a['type'] == _selectedSourceAccount,
      orElse: () => _sourceAccounts.first,
    );
    return match['balance'] as double;
  }

  Map<String, dynamic> get _currentSourceAccountData {
    return _sourceAccounts.firstWhere(
      (a) => a['type'] == _selectedSourceAccount,
      orElse: () => _sourceAccounts.first,
    );
  }


  void _onSendMoney() {
    if (!RequireDeviceApproval.canTransact(context)) {
      return;
    }

    final text = _amountController.text.replaceAll(',', '').trim();
    final enteredAmount = double.tryParse(text) ?? 0.0;

    if (enteredAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFFDC2626),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: const Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Text('Please enter an amount greater than 0', style: TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      );
      return;
    }

    if (enteredAmount > _currentSourceBalance) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFFDC2626),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Text('Amount exceeds available account balance', style: TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      );
      return;
    }

    final destinationBank = _isAuraToAura
        ? 'Aura Bank'
        : (_partnerBanks[_selectedPartnerBankIndex]['name'] as String);

    final fee = _isAuraToAura ? 0.0 : 10.0;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ReviewTransferScreen(
          senderName: _bankService.user.name,
          senderAccount: _currentSourceAccountData['accountNo'] as String,
          recipientName: _recipientController.text.trim().isNotEmpty
              ? _recipientController.text.trim()
              : 'Jessie Mae Dela Paz',
          recipientAccount: _accountController.text.trim().isNotEmpty
              ? _accountController.text.trim()
              : '1234568898951',
          recipientBank: destinationBank,
          amount: enteredAmount,
          fee: fee,
          remarks: _remarksController.text.trim().isNotEmpty
              ? _remarksController.text.trim()
              : (_selectedPurpose ?? 'Funds Transfer'),
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Bar: Back Button + Aura Bank Brand Pill
              _buildTopBar(),

              const SizedBox(height: 16),

              // Card 1: "From:" Account Selector Card
              _buildFromCard(),

              const SizedBox(height: 14),

              // Segmented Tab Bar: "Aura to Aura" vs "Other Bank"
              _buildTabSelector(),

              const SizedBox(height: 14),

              // Card 2: Account Details Card (Includes Partner Bank Banner if Other Bank)
              _buildAccountDetailsCard(),

              const SizedBox(height: 14),

              // Card 3: Enter Amount Card
              _buildAmountCard(),

              const SizedBox(height: 14),

              // Card 4: Purpose & Remarks Card
              _buildPurposeAndRemarksCard(),

              const SizedBox(height: 18),

              // Primary CTA Button: "Send Money"
              _buildSendMoneyButton(),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Row(
      children: [
        // Circular back button
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            color: const Color(0xFF38008A),
            onPressed: widget.onBack ?? () => Navigator.of(context).pop(),
          ),
        ),
        const SizedBox(width: 12),
        // Aura Bank Pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AuraLogo(size: 24, style: AuraLogoStyle.violet, borderRadius: 6),
              SizedBox(width: 8),
              Text(
                'Aura Bank',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Colors.black,
                  decoration: TextDecoration.underline,
                  decorationThickness: 2.0,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFromCard() {
    return InkWell(
      onTap: _showSourceAccountPicker,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB), width: 1.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 3),
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
                  'From:',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '$_selectedSourceAccount Account • ₱${_formatAmountPlain(_currentSourceBalance)}',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE5E7EB)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: Color(0xFF38008A),
                size: 24,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabSelector() {
    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFE5E7EB),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _isAuraToAura = true),
              child: Container(
                decoration: BoxDecoration(
                  color: _isAuraToAura ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: _isAuraToAura
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  'Aura to Aura',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: _isAuraToAura ? const Color(0xFF38008A) : const Color(0xFF6B7280),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _isAuraToAura = false),
              child: Container(
                decoration: BoxDecoration(
                  color: !_isAuraToAura ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: !_isAuraToAura
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.account_balance_rounded,
                      size: 15,
                      color: !_isAuraToAura ? const Color(0xFF38008A) : const Color(0xFF6B7280),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Other Bank',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: !_isAuraToAura ? const Color(0xFF38008A) : const Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountDetailsCard() {
    final partnerBank = _partnerBanks[_selectedPartnerBankIndex];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1.0),
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
          if (!_isAuraToAura) ...[
            InkWell(
              onTap: _showPartnerBankPicker,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3E8FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFF38008A),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        partnerBank['avatar'] as String,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          partnerBank['name'] as String,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 1),
                        const Text(
                          'Partner Bank',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF6B7280),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'instapay',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF16A34A),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],

          const Text(
            'Account Number',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.centerLeft,
            child: TextField(
              controller: _accountController,
              keyboardType: TextInputType.number,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: Colors.black,
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
                hintText: '1234 5678 9123 4569',
                hintStyle: TextStyle(
                  color: Color(0xFF9CA3AF),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),

          const SizedBox(height: 14),

          const Text(
            'Recipient Name',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.centerLeft,
            child: TextField(
              controller: _recipientController,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: Colors.black,
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
                hintText: 'Jessie Mae Dela Paz',
                hintStyle: TextStyle(
                  color: Color(0xFF9CA3AF),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1.0),
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
          const Text(
            'Enter Amount',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                const Text(
                  'PHP ',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.black,
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Colors.black,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      hintText: '0.00',
                      hintStyle: TextStyle(
                        color: Color(0xFF9CA3AF),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Transfer Fee: PHP 10.00',
            style: TextStyle(
              fontSize: 10,
              color: Color(0xFF9CA3AF),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPurposeAndRemarksCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1.0),
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
          const Text(
            'Purpose',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: _showPurposePicker,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _selectedPurpose ?? 'Select transfer purpose',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: _selectedPurpose != null ? FontWeight.w700 : FontWeight.w500,
                      color: _selectedPurpose != null ? Colors.black : const Color(0xFF6B7280),
                    ),
                  ),
                  const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: Color(0xFF38008A),
                    size: 22,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 14),

          const Text(
            'Remarks (Optional)',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.centerLeft,
            child: TextField(
              controller: _remarksController,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
                hintText: 'Enter details',
                hintStyle: TextStyle(
                  color: Color(0xFF9CA3AF),
                  fontSize: 12.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSendMoneyButton() {
    return RequireDeviceApproval(
      actionLabel: 'Money transfers',
      child: Container(
        width: double.infinity,
        height: 50,
        decoration: BoxDecoration(
          color: const Color(0xFF38008A),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF38008A).withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        onPressed: _onSendMoney,
        child: const Text(
          'Send Money',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: 0.3,
          ),
        ),
      ),
    ),
    );
  }

  void _showSourceAccountPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Select Source Account',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 14),
            ..._sourceAccounts.map((acc) {
              final isSel = acc['type'] == _selectedSourceAccount;
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: isSel ? const Color(0xFFF3E8FF) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSel ? const Color(0xFF38008A) : const Color(0xFFE2E8F0),
                    width: isSel ? 1.5 : 1.0,
                  ),
                ),
                child: ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isSel ? const Color(0xFF38008A) : Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      acc['icon'] as IconData,
                      color: isSel ? Colors.white : const Color(0xFF6B7280),
                      size: 20,
                    ),
                  ),
                  title: Text(
                    acc['title'] as String,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                  ),
                  subtitle: Text(
                    '${acc['accountNo']} • Available: ₱${_formatAmountPlain(acc['balance'] as double)}',
                    style: const TextStyle(fontSize: 11.5, color: Color(0xFF6B7280)),
                  ),
                  trailing: isSel
                      ? const Icon(Icons.check_circle_rounded, color: Color(0xFF38008A), size: 22)
                      : null,
                  onTap: () {
                    setState(() => _selectedSourceAccount = acc['type'] as String);
                    Navigator.of(ctx).pop();
                  },
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  void _showPartnerBankPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Select Destination Bank',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 14),
            ...List.generate(_partnerBanks.length, (idx) {
              final b = _partnerBanks[idx];
              final isSel = idx == _selectedPartnerBankIndex;
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: isSel ? const Color(0xFFF3E8FF) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSel ? const Color(0xFF38008A) : const Color(0xFFE2E8F0),
                    width: isSel ? 1.5 : 1.0,
                  ),
                ),
                child: ListTile(
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFF38008A),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      b['avatar'] as String,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  title: Text(
                    b['name'] as String,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                  ),
                  subtitle: Text(
                    b['group'] as String,
                    style: const TextStyle(fontSize: 11.5, color: Color(0xFF6B7280)),
                  ),
                  trailing: isSel
                      ? const Icon(Icons.check_circle_rounded, color: Color(0xFF38008A), size: 22)
                      : null,
                  onTap: () {
                    setState(() => _selectedPartnerBankIndex = idx);
                    Navigator.of(ctx).pop();
                  },
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  void _showPurposePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Select Transfer Purpose',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 14),
            ..._purposes.map((p) {
              final name = p['name'] as String;
              final isSel = name == _selectedPurpose;
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: isSel ? const Color(0xFFF3E8FF) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSel ? const Color(0xFF38008A) : const Color(0xFFE2E8F0),
                    width: isSel ? 1.5 : 1.0,
                  ),
                ),
                child: ListTile(
                  leading: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: isSel ? const Color(0xFF38008A) : const Color(0xFFEDE9FE),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      p['icon'] as IconData,
                      color: isSel ? Colors.white : const Color(0xFF38008A),
                      size: 20,
                    ),
                  ),
                  title: Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                  ),
                  subtitle: Text(
                    p['desc'] as String,
                    style: const TextStyle(fontSize: 11.5, color: Color(0xFF6B7280)),
                  ),
                  trailing: isSel
                      ? const Icon(Icons.check_circle_rounded, color: Color(0xFF38008A), size: 22)
                      : null,
                  onTap: () {
                    setState(() => _selectedPurpose = name);
                    Navigator.of(ctx).pop();
                  },
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  String _formatAmountPlain(double amount) {
    final parts = amount.toStringAsFixed(2);
    final splitParts = parts.split('.');
    final formattedInt = splitParts[0].replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
    return '$formattedInt.${splitParts[1]}';
  }
}
