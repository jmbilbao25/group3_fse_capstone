import 'package:flutter/material.dart';
import '../services/bank_service.dart';
import '../theme/aura_theme.dart';
import '../widgets/aura_logo.dart';
import 'review_transfer_screen.dart';

class SendMoneyScreen extends StatefulWidget {
  final VoidCallback? onBack;
  final bool initialIsAuraToAura;
  final int initialPartnerBankIndex;

  const SendMoneyScreen({
    super.key,
    this.onBack,
    this.initialIsAuraToAura = true,
    this.initialPartnerBankIndex = 0,
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

  final TextEditingController _accountController =
      TextEditingController(text: '1234568898951');
  final TextEditingController _recipientController =
      TextEditingController(text: 'Jessie Mae Dela Paz');
  final TextEditingController _amountController =
      TextEditingController();
  final TextEditingController _remarksController =
      TextEditingController();

  static const List<Map<String, dynamic>> _sourceAccounts = [
    {
      'type': 'Savings',
      'title': 'Savings Account',
      'accountNo': 'AUR-SAV-9821',
      'balance': 50000.0,
      'icon': Icons.savings_outlined,
    },
    {
      'type': 'Current',
      'title': 'Current Account',
      'accountNo': 'AUR-CUR-4412',
      'balance': 125000.0,
      'icon': Icons.account_balance_wallet_outlined,
    },
    {
      'type': 'Credit',
      'title': 'Credit Account',
      'accountNo': 'AUR-CRD-7703',
      'balance': 75000.0,
      'icon': Icons.credit_card_outlined,
    },
  ];

  static const List<String> _purposes = [
    'Remittance',
    'Funds Transfer',
    'Bills Payment',
    'Savings',
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
    },
    {
      'name': 'Angel Lou F. Yabut',
      'account': '7128901234567',
      'bank': 'Aura Bank',
      'isAura': true,
      'partnerIndex': 0,
    },
    {
      'name': 'Mae G. Mercado',
      'account': '4491882019238',
      'bank': 'Apex Digital Bank',
      'isAura': false,
      'partnerIndex': 1,
    },
    {
      'name': 'Luis Tan',
      'account': '9975401288412',
      'bank': 'Aura Bank',
      'isAura': true,
      'partnerIndex': 0,
    },
  ];

  static const Color brandViolet = Color(0xFF380084);
  static const Color textDark = Color(0xFF111827);
  static const Color textGray = Color(0xFF6B7280);
  static const Color cardBorder = Color(0xFFE5E7EB);
  static const Color inputBg = Color(0xFFDCDFE4);

  @override
  void initState() {
    super.initState();
    _isAuraToAura = widget.initialIsAuraToAura;
    _selectedPartnerBankIndex = widget.initialPartnerBankIndex;
  }

  @override
  void dispose() {
    _accountController.dispose();
    _recipientController.dispose();
    _amountController.dispose();
    _remarksController.dispose();
    super.dispose();
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
    final text = _amountController.text.replaceAll(',', '').trim();
    final enteredAmount = double.tryParse(text) ?? 0.0;

    if (enteredAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an amount greater than 0')),
      );
      return;
    }

    if (enteredAmount > _currentSourceBalance) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Amount exceeds available account balance')),
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1D5DB),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Recipient Information',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: textDark),
              ),
              const SizedBox(height: 14),

              // Recent Contacts quick pick
              const Text(
                'QUICK SELECT RECENT',
                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: textGray),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _recentRecipients.map((r) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ActionChip(
                        label: Text(
                          r['name'] as String,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                        onPressed: () {
                          setState(() {
                            _recipientController.text = r['name'] as String;
                            _accountController.text = r['account'] as String;
                            _isAuraToAura = r['isAura'] as bool;
                            _selectedPartnerBankIndex = r['partnerIndex'] as int;
                          });
                          Navigator.of(ctx).pop();
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 14),

              // Name Field
              const Text(
                'Account Holder Name',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: textGray),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _recipientController,
                decoration: InputDecoration(
                  hintText: 'Enter recipient name',
                  filled: true,
                  fillColor: const Color(0xFFF3F4F6),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),

              const SizedBox(height: 12),

              // Account Number Field
              const Text(
                'Account Number',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: textGray),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _accountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: 'Enter account number',
                  filled: true,
                  fillColor: const Color(0xFFF3F4F6),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),

              if (!_isAuraToAura) ...[
                const SizedBox(height: 12),
                const Text(
                  'Destination Partner Bank',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: textGray),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      isExpanded: true,
                      value: _selectedPartnerBankIndex,
                      items: List.generate(_partnerBanks.length, (idx) {
                        return DropdownMenuItem(
                          value: idx,
                          child: Text(
                            _partnerBanks[idx]['name'] as String,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
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
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: brandViolet,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Save Details', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Bar (Circle back button + Aura Bank pill)
              _buildTopBar(),

              const SizedBox(height: 20),

              // Card 1: "From:" Dropdown (Savings, Current, Credit)
              _buildFromCard(),

              const SizedBox(height: 16),

              // Card 2: Recipient, Channel Toggle & Amount Box
              _buildRecipientAndAmountCard(),

              const SizedBox(height: 16),

              // Card 3: Purpose Dropdown & Remarks
              _buildPurposeAndRemarksCard(),

              const SizedBox(height: 24),

              // Bottom Button: "Send Money"
              _buildSendMoneyButton(),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
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
            color: brandViolet,
            onPressed: widget.onBack ?? () => Navigator.of(context).pop(),
          ),
        ),
        const SizedBox(width: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: cardBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Row(
            children: [
              AuraLogo(size: 22, style: AuraLogoStyle.violet, borderRadius: 5),
              SizedBox(width: 8),
              Text(
                'Aura Bank',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: textDark,
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
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: cardBorder, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: _selectedSourceAccount,
          borderRadius: BorderRadius.circular(20),
          selectedItemBuilder: (context) {
            return _sourceAccounts.map((item) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'From:',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: textDark,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item['title'] as String,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: textGray,
                    ),
                  ),
                ],
              );
            }).toList();
          },
          icon: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: cardBorder),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: brandViolet,
              size: 26,
            ),
          ),
          items: _sourceAccounts.map((item) {
            return DropdownMenuItem<String>(
              value: item['type'] as String,
              child: Row(
                children: [
                  Icon(item['icon'] as IconData, size: 20, color: brandViolet),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        item['type'] as String,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: textDark,
                        ),
                      ),
                      Text(
                        'Available: PHP ${_formatAmountPlain(item['balance'] as double)}',
                        style: const TextStyle(fontSize: 11, color: textGray),
                      ),
                    ],
                  ),
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
    );
  }

  Widget _buildRecipientAndAmountCard() {
    final destinationBank = _isAuraToAura
        ? 'Aura Bank'
        : (_partnerBanks[_selectedPartnerBankIndex]['name'] as String);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: cardBorder, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Aura to Aura vs Other Bank Segmented Bar
          Container(
            padding: const EdgeInsets.all(3.5),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _isAuraToAura = true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
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
                      alignment: Alignment.center,
                      child: Text(
                        'Aura to Aura',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: _isAuraToAura ? brandViolet : textGray,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _isAuraToAura = false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
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
                      alignment: Alignment.center,
                      child: Text(
                        'Other Bank',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: !_isAuraToAura ? brandViolet : textGray,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Recipient Profile Row
          InkWell(
            onTap: _showEditRecipientSheet,
            borderRadius: BorderRadius.circular(12),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: Color(0xFF380084),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.person, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _recipientController.text.trim().isNotEmpty
                            ? _recipientController.text.trim()
                            : 'Jessie Mae Dela Paz',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: textDark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        destinationBank,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF4B5563),
                        ),
                      ),
                      Text(
                        'Account No. ${_accountController.text.trim().isNotEmpty ? _accountController.text.trim() : '1234568898951'}',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: textGray,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.edit_outlined, size: 18, color: brandViolet),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Amount Box (Matching Grey Card with PHP prefix)
          Container(
            height: 60,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: inputBg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Text(
                  'PHP ',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: textDark,
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: textDark,
                    ),
                    decoration: const InputDecoration(
                      hintText: '0',
                      hintStyle: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF9CA3AF),
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
          ),

          const SizedBox(height: 10),

          // Available Balance & Transfer Limit subtext
          Text(
            'Available Balance: PHP ${_formatAmountPlain(_currentSourceBalance)}',
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF4B5563),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Transfer Limit: PHP ${_formatAmountPlain(_currentSourceBalance)}',
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF4B5563),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPurposeAndRemarksCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: cardBorder, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
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
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: textDark,
            ),
          ),
          const SizedBox(height: 8),

          // Purpose Grey Dropdown Box
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: inputBg,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isDense: true,
                isExpanded: true,
                value: _selectedPurpose,
                hint: const Text(
                  'Select transfer purpose',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF4B5563),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: brandViolet,
                  size: 24,
                ),
                borderRadius: BorderRadius.circular(14),
                items: _purposes.map((p) {
                  return DropdownMenuItem<String>(
                    value: p,
                    child: Text(
                      p,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: textDark,
                      ),
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
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: textDark,
            ),
          ),
          const SizedBox(height: 8),

          // Remarks Grey Input Box
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: inputBg,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
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
                  color: Color(0xFF6B7280),
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
    );
  }

  Widget _buildSendMoneyButton() {
    return Container(
      width: double.infinity,
      height: 52,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: AuraColors.buttonShadow,
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2E0854),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          elevation: 0,
        ),
        onPressed: _onSendMoney,
        child: const Text(
          'Send Money',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Colors.white,
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
