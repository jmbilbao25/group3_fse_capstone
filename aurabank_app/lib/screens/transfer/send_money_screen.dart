import 'package:flutter/material.dart';
import '../../services/bank_service.dart';
import '../../widgets/aura_logo.dart';
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

  static const List<Map<String, dynamic>> _recentRecipients = [
    {
      'name': 'Jessie Mae Dela Paz',
      'account': '1234568898951',
      'bank': 'MeyBank',
      'isAura': false,
      'partnerIndex': 0,
      'gradient': [Color(0xFF5B21B6), Color(0xFF7C3AED)],
    },
    {
      'name': 'Angel Lou F. Yabut',
      'account': '7128901234567',
      'bank': 'Aura Bank',
      'isAura': true,
      'partnerIndex': 0,
      'gradient': [Color(0xFF2563EB), Color(0xFF38BDF8)],
    },
    {
      'name': 'Mae G. Mercado',
      'account': '4491882019238',
      'bank': 'Apex Digital Bank',
      'isAura': false,
      'partnerIndex': 1,
      'gradient': [Color(0xFF059669), Color(0xFF10B981)],
    },
    {
      'name': 'Luis Tan',
      'account': '9975401288412',
      'bank': 'Aura Bank',
      'isAura': true,
      'partnerIndex': 0,
      'gradient': [Color(0xFFD97706), Color(0xFFFBBF24)],
    },
  ];

  // Refined Color Palette
  static const Color brandPrimary = Color(0xFF2A0054);
  static const Color brandViolet = Color(0xFF4C1D95);
  static const Color brandAccent = Color(0xFF6D28D9);
  static const Color textDark = Color(0xFF0F172A);
  static const Color textGray = Color(0xFF64748B);
  static const Color textMuted = Color(0xFF94A3B8);
  static const Color surfaceWhite = Colors.white;
  static const Color cardBorder = Color(0xFFE2E8F0);
  static const Color inputBg = Color(0xFFF8FAFC);
  static const Color emeraldGreen = Color(0xFF059669);

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

  String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts[0].isEmpty) return 'A';
    if (parts.length == 1) {
      return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
    }
    return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
  }

  void _applyQuickAmount(double delta) {
    final current = double.tryParse(_amountController.text.replaceAll(',', '')) ?? 0.0;
    final next = (current + delta).clamp(0.0, _currentSourceBalance);
    setState(() {
      _amountController.text = next == next.roundToDouble()
          ? next.toInt().toString()
          : next.toStringAsFixed(2);
    });
  }

  void _applyMaxAmount() {
    setState(() {
      _amountController.text = _currentSourceBalance == _currentSourceBalance.roundToDouble()
          ? _currentSourceBalance.toInt().toString()
          : _currentSourceBalance.toStringAsFixed(2);
    });
  }

  void _onSendMoney() {
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

  void _showEditRecipientSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.52),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final viewInsets = MediaQuery.of(context).viewInsets;
          final viewPadding = MediaQuery.of(context).viewPadding;

          return Align(
            alignment: Alignment.bottomCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Container(
                margin: EdgeInsets.only(
                  left: 14,
                  right: 14,
                  bottom: viewInsets.bottom > 0
                      ? viewInsets.bottom + 14
                      : (viewPadding.bottom > 0 ? viewPadding.bottom + 12 : 20),
                ),
                decoration: BoxDecoration(
                  color: surfaceWhite,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: cardBorder.withValues(alpha: 0.9), width: 1),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x380F172A),
                      blurRadius: 36,
                      spreadRadius: 0,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(28),
                  clipBehavior: Clip.antiAlias,
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Sleek Drag Handle
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

                        // Sheet Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Recipient Information',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    color: textDark,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                SizedBox(height: 3),
                                Text(
                                  'Choose a recent contact or enter new details',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w500,
                                    color: textGray,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                shape: BoxShape.circle,
                                border: Border.all(color: cardBorder),
                              ),
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                icon: const Icon(Icons.close_rounded, size: 18, color: textGray),
                                onPressed: () => Navigator.of(ctx).pop(),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Recent Contacts Quick Pick Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'QUICK SELECT RECENT',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.9,
                                color: textMuted,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF3E8FF),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text(
                                'Tap to fill',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: brandAccent,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Responsive Grid / Row for Recent Contacts (No overflow, fully mobile-native)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: _recentRecipients.map((r) {
                            final isSelected =
                                _recipientController.text == (r['name'] as String);
                            final gradient = r['gradient'] as List<Color>;
                            final firstName = (r['name'] as String).split(' ').first;
                            final shortBank = (r['bank'] as String)
                                .replaceAll(' Digital Bank', '')
                                .replaceAll(' Bank', '');

                            return Expanded(
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () {
                                  setState(() {
                                    _recipientController.text = r['name'] as String;
                                    _accountController.text = r['account'] as String;
                                    _isAuraToAura = r['isAura'] as bool;
                                    _selectedPartnerBankIndex = r['partnerIndex'] as int;
                                  });
                                  setModalState(() {});
                                },
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Stack(
                                      clipBehavior: Clip.none,
                                      alignment: Alignment.center,
                                      children: [
                                        AnimatedContainer(
                                          duration: const Duration(milliseconds: 200),
                                          width: 48,
                                          height: 48,
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: gradient,
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            ),
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: isSelected ? brandAccent : Colors.white,
                                              width: isSelected ? 2.5 : 1.5,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: isSelected
                                                    ? brandAccent.withValues(alpha: 0.35)
                                                    : Colors.black.withValues(alpha: 0.08),
                                                blurRadius: isSelected ? 8 : 4,
                                                offset: const Offset(0, 3),
                                              ),
                                            ],
                                          ),
                                          alignment: Alignment.center,
                                          child: Text(
                                            _getInitials(r['name'] as String),
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w900,
                                              color: Colors.white,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ),
                                        if (isSelected)
                                          Positioned(
                                            right: -2,
                                            bottom: -2,
                                            child: Container(
                                              width: 18,
                                              height: 18,
                                              decoration: BoxDecoration(
                                                color: brandAccent,
                                                shape: BoxShape.circle,
                                                border: Border.all(color: Colors.white, width: 1.5),
                                              ),
                                              child: const Icon(
                                                Icons.check_rounded,
                                                size: 11,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      firstName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                        color: isSelected ? brandViolet : textDark,
                                      ),
                                    ),
                                    const SizedBox(height: 1),
                                    Text(
                                      shortBank,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w500,
                                        color: isSelected ? brandAccent : textGray,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),

                        const SizedBox(height: 18),

                        // Name Field
                        const Text(
                          'Account Holder Name',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: textGray,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          decoration: BoxDecoration(
                            color: inputBg,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: cardBorder),
                          ),
                          child: TextField(
                            controller: _recipientController,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: textDark,
                            ),
                            decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.person_outline_rounded, size: 20, color: brandAccent),
                              hintText: 'Enter recipient name',
                              hintStyle: TextStyle(fontSize: 13, color: textMuted),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                            ),
                            onChanged: (_) {
                              setModalState(() {});
                              setState(() {});
                            },
                          ),
                        ),

                        const SizedBox(height: 14),

                        // Account Number Field
                        const Text(
                          'Account Number',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: textGray,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          decoration: BoxDecoration(
                            color: inputBg,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: cardBorder),
                          ),
                          child: TextField(
                            controller: _accountController,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: textDark,
                              letterSpacing: 0.5,
                            ),
                            decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.tag_rounded, size: 20, color: brandAccent),
                              hintText: 'Enter account number',
                              hintStyle: TextStyle(fontSize: 13, color: textMuted),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                            ),
                            onChanged: (_) {
                              setModalState(() {});
                              setState(() {});
                            },
                          ),
                        ),

                        if (!_isAuraToAura) ...[
                          const SizedBox(height: 14),
                          const Text(
                            'Destination Partner Bank',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: textGray,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                            decoration: BoxDecoration(
                              color: inputBg,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: cardBorder),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<int>(
                                isExpanded: true,
                                value: _selectedPartnerBankIndex,
                                icon: const Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  color: brandAccent,
                                  size: 24,
                                ),
                                items: List.generate(_partnerBanks.length, (idx) {
                                  final b = _partnerBanks[idx];
                                  return DropdownMenuItem(
                                    value: idx,
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 28,
                                          height: 28,
                                          decoration: BoxDecoration(
                                            color: (b['color'] as Color).withValues(alpha: 0.15),
                                            shape: BoxShape.circle,
                                          ),
                                          alignment: Alignment.center,
                                          child: Text(
                                            b['avatar'] as String,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w900,
                                              color: b['color'] as Color,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              b['name'] as String,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w800,
                                                fontSize: 13,
                                                color: textDark,
                                              ),
                                            ),
                                            Text(
                                              b['group'] as String,
                                              style: const TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w500,
                                                color: textGray,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                                onChanged: (val) {
                                  if (val != null) {
                                    setModalState(() => _selectedPartnerBankIndex = val);
                                    setState(() => _selectedPartnerBankIndex = val);
                                  }
                                },
                              ),
                            ),
                          ),
                        ],

                        const SizedBox(height: 20),

                        // Save Details Button
                        Container(
                          width: double.infinity,
                          height: 50,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [brandPrimary, brandAccent],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: brandPrimary.withValues(alpha: 0.3),
                                blurRadius: 14,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            onPressed: () => Navigator.of(ctx).pop(),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 18),
                                SizedBox(width: 8),
                                Text(
                                  'Save Details',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Bar
              _buildTopBar(),

              const SizedBox(height: 18),

              // Card 1: "From:" Account Selector
              _buildFromCard(),

              const SizedBox(height: 16),

              // Card 2: Recipient, Channel Toggle & Hero Amount
              _buildRecipientAndAmountCard(),

              const SizedBox(height: 16),

              // Card 3: Purpose & Remarks
              _buildPurposeAndRemarksCard(),

              const SizedBox(height: 24),

              // Primary CTA Button: "Send Money"
              _buildSendMoneyButton(),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: surfaceWhite,
                shape: BoxShape.circle,
                border: Border.all(color: cardBorder),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 17),
                color: brandViolet,
                onPressed: widget.onBack ?? () => Navigator.of(context).pop(),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: surfaceWhite,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cardBorder),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Row(
                children: [
                  AuraLogo(size: 20, style: AuraLogoStyle.violet, borderRadius: 5),
                  SizedBox(width: 8),
                  Text(
                    'Aura Bank',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: textDark,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFF3E8FF),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Row(
            children: [
              Icon(Icons.bolt_rounded, size: 14, color: brandAccent),
              SizedBox(width: 4),
              Text(
                'Instant',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: brandAccent,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFromCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surfaceWhite,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: cardBorder, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E1B4B).withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3E8FF),
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Icon(
                  _currentSourceAccountData['icon'] as IconData,
                  color: brandAccent,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    itemHeight: 64.0,
                    isExpanded: true,
                    value: _selectedSourceAccount,
                    borderRadius: BorderRadius.circular(20),
                    dropdownColor: surfaceWhite,
                    selectedItemBuilder: (context) {
                      return _sourceAccounts.map((item) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'From:',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                                color: textGray,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              item['title'] as String,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: textDark,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ],
                        );
                      }).toList();
                    },
                    icon: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        shape: BoxShape.circle,
                        border: Border.all(color: cardBorder),
                      ),
                      child: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: brandViolet,
                        size: 24,
                      ),
                    ),
                    items: _sourceAccounts.map((item) {
                      final isSelected = item['type'] == _selectedSourceAccount;
                      return DropdownMenuItem<String>(
                        value: item['type'] as String,
                        child: Row(
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: isSelected ? const Color(0xFFF3E8FF) : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                item['icon'] as IconData,
                                size: 18,
                                color: isSelected ? brandAccent : textGray,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    item['type'] as String,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13.5,
                                      color: isSelected ? brandViolet : textDark,
                                    ),
                                  ),
                                  Text(
                                    '${item['accountNo']} • Available: PHP ${_formatAmountPlain(item['balance'] as double)}',
                                    style: const TextStyle(fontSize: 11, color: textGray, fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                            ),
                            if (isSelected)
                              const Icon(Icons.check_circle_rounded, color: brandAccent, size: 18),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedSourceAccount = val);
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: cardBorder),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _currentSourceAccountData['accountNo'] as String,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: textGray,
                  ),
                ),
                Text(
                  'Available: PHP ${_formatAmountPlain(_currentSourceBalance)}',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: emeraldGreen,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecipientAndAmountCard() {
    final destinationBank = _isAuraToAura
        ? 'Aura Bank'
        : (_partnerBanks[_selectedPartnerBankIndex]['name'] as String);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: surfaceWhite,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: cardBorder, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E1B4B).withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Segmented Capsule Toggle
          Container(
            padding: const EdgeInsets.all(3.5),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _isAuraToAura = true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      decoration: BoxDecoration(
                        color: _isAuraToAura ? surfaceWhite : Colors.transparent,
                        borderRadius: BorderRadius.circular(11),
                        border: _isAuraToAura ? Border.all(color: cardBorder) : null,
                        boxShadow: _isAuraToAura
                            ? [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 5,
                                  offset: const Offset(0, 1),
                                ),
                              ]
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_isAuraToAura) ...[
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: emeraldGreen,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          Text(
                            'Aura to Aura',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: _isAuraToAura ? brandPrimary : textGray,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _isAuraToAura = false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      decoration: BoxDecoration(
                        color: !_isAuraToAura ? surfaceWhite : Colors.transparent,
                        borderRadius: BorderRadius.circular(11),
                        border: !_isAuraToAura ? Border.all(color: cardBorder) : null,
                        boxShadow: !_isAuraToAura
                            ? [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 5,
                                  offset: const Offset(0, 1),
                                ),
                              ]
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (!_isAuraToAura) ...[
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: brandAccent,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          Text(
                            'Other Bank',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: !_isAuraToAura ? brandPrimary : textGray,
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

          const SizedBox(height: 16),

          // Recipient Profile Card Row
          InkWell(
            onTap: _showEditRecipientSheet,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: inputBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: cardBorder),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [brandPrimary, brandAccent],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _getInitials(_recipientController.text),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -0.5,
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
                                _recipientController.text.trim().isNotEmpty
                                    ? _recipientController.text.trim()
                                    : 'Jessie Mae Dela Paz',
                                style: const TextStyle(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w800,
                                  color: textDark,
                                  letterSpacing: -0.2,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.verified_rounded,
                              size: 15,
                              color: Color(0xFF2563EB),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEDE9FE),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                destinationBank,
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  color: brandViolet,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Account No. ${_accountController.text.trim().isNotEmpty ? _accountController.text.trim() : '1234568898951'}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: textGray,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: surfaceWhite,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: cardBorder),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Change',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: brandAccent,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(Icons.edit_outlined, size: 13, color: brandAccent),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Editorial Hero Amount Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: inputBg,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'TRANSFER AMOUNT',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.9,
                        color: textMuted,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _isAuraToAura ? const Color(0xFFE6F8F0) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _isAuraToAura ? 'Zero Fee' : 'Fee: PHP 10.00',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: _isAuraToAura ? emeraldGreen : textGray,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Currency and Amount Input
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEDE9FE),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'PHP',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: brandViolet,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _amountController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: textDark,
                          letterSpacing: -0.5,
                        ),
                        decoration: const InputDecoration(
                          hintText: '0',
                          hintStyle: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFFCBD5E1),
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // Quick Amount Preset Chips
                Row(
                  children: [
                    _buildQuickChip('+500', () => _applyQuickAmount(500)),
                    const SizedBox(width: 6),
                    _buildQuickChip('+1,000', () => _applyQuickAmount(1000)),
                    const SizedBox(width: 6),
                    _buildQuickChip('+5,000', () => _applyQuickAmount(5000)),
                    const SizedBox(width: 6),
                    _buildQuickChip('Max', _applyMaxAmount, isMax: true),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Available Balance & Transfer Limit Strip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.account_balance_wallet_outlined, size: 14, color: emeraldGreen),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Available Balance: PHP ${_formatAmountPlain(_currentSourceBalance)}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF334155),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  height: 16,
                  color: cardBorder,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                ),
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.shield_outlined, size: 14, color: textGray),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Transfer Limit: PHP ${_formatAmountPlain(_currentSourceBalance)}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: textGray,
                          ),
                          overflow: TextOverflow.ellipsis,
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
  }

  Widget _buildQuickChip(String label, VoidCallback onTap, {bool isMax = false}) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isMax ? const Color(0xFFF3E8FF) : surfaceWhite,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isMax ? const Color(0xFFDDD6FE) : cardBorder,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: isMax ? brandAccent : textDark,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPurposeAndRemarksCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: surfaceWhite,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: cardBorder, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E1B4B).withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Purpose Dropdown Label
          const Text(
            'Purpose',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: textDark,
            ),
          ),
          const SizedBox(height: 8),

          // Purpose Dropdown Field
          Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: inputBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: cardBorder),
            ),
            alignment: Alignment.center,
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isDense: true,
                isExpanded: true,
                value: _selectedPurpose,
                selectedItemBuilder: (context) {
                  return _purposes.map((p) {
                    final name = p['name'] as String;
                    final icon = p['icon'] as IconData;
                    return Row(
                      children: [
                        Icon(icon, size: 18, color: brandAccent),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            name,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: textDark,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ],
                    );
                  }).toList();
                },
                hint: const Row(
                  children: [
                    Icon(Icons.category_outlined, size: 18, color: textMuted),
                    SizedBox(width: 10),
                    Text(
                      'Select transfer purpose',
                      style: TextStyle(
                        fontSize: 13,
                        color: textGray,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: brandAccent,
                  size: 24,
                ),
                borderRadius: BorderRadius.circular(16),
                items: _purposes.map((p) {
                  final name = p['name'] as String;
                  final icon = p['icon'] as IconData;
                  final desc = p['desc'] as String;

                  return DropdownMenuItem<String>(
                    value: name,
                    child: Row(
                      children: [
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3E8FF),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(icon, color: brandAccent, size: 16),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                  color: textDark,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                              Text(
                                desc,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  color: textGray,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _selectedPurpose = val);
                  }
                },
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Remarks Label
          const Text(
            'Remarks (Optional)',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: textDark,
            ),
          ),
          const SizedBox(height: 8),

          // Remarks Input Field
          Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: inputBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: cardBorder),
            ),
            alignment: Alignment.center,
            child: Row(
              children: [
                const Icon(Icons.edit_note_rounded, size: 22, color: textMuted),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _remarksController,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: textDark,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Enter details',
                      hintStyle: TextStyle(
                        fontSize: 13,
                        color: textMuted,
                        fontWeight: FontWeight.w400,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSendMoneyButton() {
    return Container(
      width: double.infinity,
      height: 54,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [brandPrimary, Color(0xFF4C1D95)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: brandPrimary.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          elevation: 0,
        ),
        onPressed: _onSendMoney,
        child: const Text(
          'Send Money',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: 0.3,
          ),
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
