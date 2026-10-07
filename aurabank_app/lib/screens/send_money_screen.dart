import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  final TextEditingController _accountController =
      TextEditingController(text: '1234 5678 9123 4569');
  final TextEditingController _recipientController =
      TextEditingController(text: 'Jessie Mae Dela Paz');
  final TextEditingController _amountController =
      TextEditingController(text: '50000.00');
  final TextEditingController _remarksController = TextEditingController();

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

  static const List<Map<String, dynamic>> _quickRecipients = [
    {
      'name': 'Jessie Mae Dela Paz',
      'account': '1234 5678 9123 4569',
      'isAura': true,
      'bank': 'Aura Bank',
      'avatar': 'J',
      'color': Color(0xFF4F46E5),
    },
    {
      'name': 'Angel Lou F. Yabut',
      'account': '7128 9012 3456 7890',
      'isAura': true,
      'bank': 'Aura Bank',
      'avatar': 'A',
      'color': Color(0xFF2E0854),
    },
    {
      'name': 'Mae G. Mercado',
      'account': '4491 8820 1923 8810',
      'isAura': false,
      'bank': 'Apex Digital Bank',
      'partnerIndex': 1,
      'avatar': 'M',
      'color': Color(0xFF7928CA),
    },
    {
      'name': 'Luis Tan',
      'account': '9975 4012 8841 2309',
      'isAura': true,
      'bank': 'Aura Bank',
      'avatar': 'L',
      'color': Color(0xFF059669),
    },
  ];

  String _selectedPurpose = 'Personal / Family';
  final List<String> _purposes = [
    'Personal / Family',
    'Allowance / Support',
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

  double get _currentAmount {
    return double.tryParse(_amountController.text.replaceAll(',', '')) ?? 0.0;
  }

  double get _currentFee => _isAuraToAura ? 0.0 : 10.0;

  void _addAmount(double add) {
    final next = _currentAmount + add;
    setState(() {
      _amountController.text = next.toStringAsFixed(2);
    });
  }

  void _setMaxAmount() {
    setState(() {
      _amountController.text = _bankService.availableBalance.toStringAsFixed(2);
    });
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.trim().isNotEmpty) {
      setState(() {
        _accountController.text = data.text!.trim();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account number pasted from clipboard'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    }
  }

  void _onSendMoney() {
    final enteredAmount = _currentAmount;
    if (enteredAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount to transfer')),
      );
      return;
    }

    if (enteredAmount > _bankService.availableBalance) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Amount exceeds available account balance')),
      );
      return;
    }

    final destinationBank = _isAuraToAura
        ? 'Aura Bank'
        : (_partnerBanks[_selectedPartnerBankIndex]['name'] as String);

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ReviewTransferScreen(
          senderName: _bankService.user.name,
          senderAccount: _bankService.savingsAccountNumber,
          recipientName: _recipientController.text.trim(),
          recipientAccount: _accountController.text.trim(),
          recipientBank: destinationBank,
          amount: enteredAmount,
          fee: _currentFee,
          remarks: _remarksController.text.trim(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final amount = _currentAmount;
    final fee = _currentFee;

    return Scaffold(
      backgroundColor: const Color(0xFFFBFBFE),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // Top Header with Aura branding and security indicator
                _buildHeader(),

                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 110),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Funding Account Card ("From:")
                        _buildFundingAccountCard(),

                        const SizedBox(height: 18),

                        // Transfer Scope Selector: Aura to Aura vs Other Bank
                        _buildTransferScopeSelector(),

                        const SizedBox(height: 14),

                        // Destination Bank Card (Active when Other Bank is selected)
                        if (!_isAuraToAura) ...[
                          _buildDestinationPartnerBankCard(),
                          const SizedBox(height: 14),
                        ] else ...[
                          _buildAuraIntraBankBanner(),
                          const SizedBox(height: 14),
                        ],

                        // Quick Recent Recipients Carousel
                        _buildQuickRecipientsSection(),

                        const SizedBox(height: 16),

                        // Recipient Information Section
                        _buildRecipientDetailsCard(),

                        const SizedBox(height: 16),

                        // Amount Card with Quick Chips & Fee Notice
                        _buildAmountHeroCard(),

                        const SizedBox(height: 16),

                        // Purpose & Remarks
                        _buildTransferDetailsCard(),

                        const SizedBox(height: 16),

                        // Real-Time Settlement & Fee Breakdown
                        _buildTransferSummaryBreakdown(amount, fee),

                        const SizedBox(height: 12),

                        // Security guarantee badge
                        const Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.lock_outline_rounded, size: 12, color: textGray),
                              SizedBox(width: 5),
                              Text(
                                'End-to-End Encrypted • Zero-Trust Ledger Controls',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: textGray,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // Bottom Sticky Floating CTA: "Send Money"
            _buildStickyBottomButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1)),
      ),
      child: Row(
        children: [
          Material(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: widget.onBack ?? () => Navigator.of(context).pop(),
              child: const Padding(
                padding: EdgeInsets.all(8.0),
                child: Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: textDark),
              ),
            ),
          ),
          const SizedBox(width: 12),
          const AuraLogo(size: 30, style: AuraLogoStyle.violet, borderRadius: 8),
          const SizedBox(width: 10),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Aura Bank',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: textDark,
                  letterSpacing: -0.2,
                ),
              ),
              Text(
                'Instant Fund Transfer',
                style: TextStyle(
                  fontSize: 10.5,
                  color: textGray,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFA7F3D0), width: 0.8),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.shield_outlined, size: 12, color: greenCredit),
                SizedBox(width: 4),
                Text(
                  'Encrypted',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: greenCredit,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFundingAccountCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF380084), Color(0xFF7000FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'FROM ACCOUNT',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: textGray,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        '● Active',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: greenCredit,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                const Text(
                  'Aura Primary Savings',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: textDark),
                ),
                const SizedBox(height: 2),
                Text(
                  'Available: ₱ ${_formatAmountPlain(_bankService.availableBalance)}',
                  style: const TextStyle(fontSize: 11.5, color: textGray, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const Icon(Icons.check_circle_rounded, color: brandViolet, size: 20),
        ],
      ),
    );
  }

  Widget _buildTransferScopeSelector() {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          // Aura to Aura Tab
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _isAuraToAura = true),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                decoration: BoxDecoration(
                  color: _isAuraToAura ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: _isAuraToAura
                      ? Border.all(color: const Color(0xFF7000FF).withValues(alpha: 0.15), width: 1.5)
                      : null,
                  boxShadow: _isAuraToAura
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.bolt_rounded,
                          size: 16,
                          color: _isAuraToAura ? brandViolet : textGray,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Aura to Aura',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: _isAuraToAura ? brandViolet : textDark,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Same Bank • FREE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: _isAuraToAura ? greenCredit : textGray,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(width: 4),

          // Other Bank Tab
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _isAuraToAura = false),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                decoration: BoxDecoration(
                  color: !_isAuraToAura ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: !_isAuraToAura
                      ? Border.all(color: const Color(0xFF7000FF).withValues(alpha: 0.15), width: 1.5)
                      : null,
                  boxShadow: !_isAuraToAura
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.account_balance_rounded,
                          size: 15,
                          color: !_isAuraToAura ? brandViolet : textGray,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Other Bank',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: !_isAuraToAura ? brandViolet : textDark,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'InstaPay • ₱10.00',
                      style: TextStyle(
                        fontSize: 10,
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
    );
  }

  Widget _buildAuraIntraBankBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF5FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE9D5FF), width: 1.0),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: brandViolet.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.flash_on_rounded, color: brandViolet, size: 18),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Aura Same-Bank Transfer',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: textDark),
                ),
                SizedBox(height: 1),
                Text(
                  'Direct ledger transfer • Zero fee • Instant settlement',
                  style: TextStyle(fontSize: 10.5, color: textGray, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFD1FAE5),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'FREE',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: greenCredit),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDestinationPartnerBankCard() {
    final selectedBank = _partnerBanks[_selectedPartnerBankIndex];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE9D5FF), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7000FF).withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'DESTINATION PARTNER BANK',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: brandViolet,
                  letterSpacing: 0.5,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                decoration: BoxDecoration(
                  color: const Color(0xFFD1FAE5),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'InstaPay 24/7',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: greenCredit,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          InkWell(
            onTap: _showSelectPartnerBankSheet,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFAF5FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE9D5FF)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: selectedBank['color'] as Color,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      selectedBank['avatar'] as String,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          selectedBank['name'] as String,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: textDark,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          selectedBank['group'] as String,
                          style: const TextStyle(
                            fontSize: 10.5,
                            color: textGray,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFDDD6FE)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Change',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: brandViolet,
                          ),
                        ),
                        SizedBox(width: 2),
                        Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: brandViolet),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Quick 3 partner bank selector tabs
          Row(
            children: [
              for (int i = 0; i < _partnerBanks.length; i++)
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedPartnerBankIndex = i),
                    child: Container(
                      margin: EdgeInsets.only(right: i < _partnerBanks.length - 1 ? 6 : 0),
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      decoration: BoxDecoration(
                        color: _selectedPartnerBankIndex == i
                            ? (_partnerBanks[i]['color'] as Color).withValues(alpha: 0.12)
                            : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _selectedPartnerBankIndex == i
                              ? (_partnerBanks[i]['color'] as Color)
                              : const Color(0xFFE2E8F0),
                          width: _selectedPartnerBankIndex == i ? 1.5 : 1.0,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _partnerBanks[i]['shortName'] as String,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: _selectedPartnerBankIndex == i ? FontWeight.w800 : FontWeight.w600,
                          color: _selectedPartnerBankIndex == i
                              ? (_partnerBanks[i]['color'] as Color)
                              : textDark,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickRecipientsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'RECENT RECIPIENTS',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: textGray,
                letterSpacing: 0.5,
              ),
            ),
            Text(
              'Tap to autofill',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: textGray,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: _quickRecipients.map((r) {
              final isSelected = _recipientController.text.trim() == r['name'];
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _recipientController.text = r['name'] as String;
                      _accountController.text = r['account'] as String;
                      _isAuraToAura = r['isAura'] as bool;
                      if (!_isAuraToAura && r.containsKey('partnerIndex')) {
                        _selectedPartnerBankIndex = r['partnerIndex'] as int;
                      }
                    });
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFFFAF5FF) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? brandViolet : cardBorder,
                        width: isSelected ? 1.4 : 1.0,
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: r['color'] as Color,
                          child: Text(
                            r['avatar'] as String,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (r['name'] as String).split(' ').first,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: isSelected ? brandViolet : textDark,
                              ),
                            ),
                            Text(
                              r['isAura'] ? 'Aura' : (r['bank'] as String).split(' ').first,
                              style: const TextStyle(fontSize: 9.5, color: textGray),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildRecipientDetailsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Account Number Input
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'ACCOUNT NUMBER',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: textGray,
                  letterSpacing: 0.5,
                ),
              ),
              InkWell(
                onTap: _pasteFromClipboard,
                borderRadius: BorderRadius.circular(6),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Row(
                    children: [
                      Icon(Icons.content_paste_rounded, size: 12, color: brandViolet),
                      SizedBox(width: 3),
                      Text(
                        'Paste',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: brandViolet,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.pin_outlined, size: 18, color: textGray),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _accountController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: textDark,
                      letterSpacing: 0.5,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Enter account number',
                      hintStyle: TextStyle(fontSize: 13, color: textGray, fontWeight: FontWeight.w400),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Recipient Name Input
          const Text(
            'RECIPIENT NAME',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: textGray,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.person_outline_rounded, size: 18, color: textGray),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _recipientController,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: textDark,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Enter recipient full name',
                      hintStyle: TextStyle(fontSize: 13, color: textGray, fontWeight: FontWeight.w400),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                if (_recipientController.text.trim().isNotEmpty)
                  const Icon(Icons.check_circle_rounded, size: 16, color: greenCredit),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountHeroCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'ENTER AMOUNT',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: textGray,
                  letterSpacing: 0.5,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                decoration: BoxDecoration(
                  color: _isAuraToAura ? const Color(0xFFECFDF5) : const Color(0xFFFAF5FF),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _isAuraToAura ? 'Transfer Fee: FREE' : 'Transfer Fee: PHP 10.00',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: _isAuraToAura ? greenCredit : brandViolet,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                'PHP',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: brandViolet,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: textDark,
                    letterSpacing: -0.5,
                  ),
                  decoration: const InputDecoration(
                    hintText: '0.00',
                    hintStyle: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFD1D5DB),
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
          const SizedBox(height: 12),
          // Quick amount increment chips
          Row(
            children: [
              _buildAmountChip('+₱500', 500),
              const SizedBox(width: 6),
              _buildAmountChip('+₱1k', 1000),
              const SizedBox(width: 6),
              _buildAmountChip('+₱5k', 5000),
              const SizedBox(width: 6),
              _buildAmountChip('+₱10k', 10000),
              const SizedBox(width: 6),
              _buildMaxChip(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAmountChip(String label, double addAmount) {
    return Expanded(
      child: InkWell(
        onTap: () => _addAmount(addAmount),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: textDark,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMaxChip() {
    return Expanded(
      child: InkWell(
        onTap: _setMaxAmount,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFFAF5FF),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFDDD6FE)),
          ),
          alignment: Alignment.center,
          child: const Text(
            'MAX',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: brandViolet,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTransferDetailsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'PURPOSE',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: textGray,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isDense: true,
                isExpanded: true,
                value: _selectedPurpose,
                icon: const Icon(Icons.keyboard_arrow_down_rounded, color: textDark),
                items: _purposes.map((p) {
                  return DropdownMenuItem(
                    value: p,
                    child: Row(
                      children: [
                        const Icon(Icons.label_outline_rounded, size: 16, color: textGray),
                        const SizedBox(width: 8),
                        Text(
                          p,
                          style: const TextStyle(fontSize: 13, color: textDark, fontWeight: FontWeight.w700),
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

          const SizedBox(height: 14),

          const Text(
            'REMARKS (OPTIONAL)',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: textGray,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.edit_note_rounded, size: 18, color: textGray),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _remarksController,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textDark),
                    decoration: const InputDecoration(
                      hintText: 'Add an optional note for recipient',
                      hintStyle: TextStyle(fontSize: 12.5, color: textGray, fontWeight: FontWeight.w400),
                      border: InputBorder.none,
                      isDense: true,
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

  Widget _buildTransferSummaryBreakdown(double amount, double fee) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Transfer Amount',
                style: TextStyle(fontSize: 11.5, color: textGray, fontWeight: FontWeight.w500),
              ),
              Text(
                'PHP ${_formatAmountPlain(amount)}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: textDark),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _isAuraToAura ? 'Aura Transfer Fee' : 'InstaPay Network Fee',
                style: const TextStyle(fontSize: 11.5, color: textGray, fontWeight: FontWeight.w500),
              ),
              Text(
                fee == 0.0 ? 'FREE' : 'PHP ${_formatAmountPlain(fee)}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: fee == 0.0 ? greenCredit : textDark,
                ),
              ),
            ],
          ),
          const Divider(color: Color(0xFFE2E8F0), height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total Deduction',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: textDark),
              ),
              Text(
                'PHP ${_formatAmountPlain(amount + fee)}',
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w900,
                  color: brandViolet,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStickyBottomButton() {
    return Positioned(
      left: 20,
      right: 20,
      bottom: 16,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          boxShadow: AuraColors.buttonShadow,
        ),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: brandViolet,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 20),
          ),
          onPressed: _onSendMoney,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              const Text(
                'Send Money',
                style: TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 0.2,
                ),
              ),
              const Spacer(),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSelectPartnerBankSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
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
              'Select Destination Bank',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: textDark),
            ),
            const SizedBox(height: 12),
            for (int i = 0; i < _partnerBanks.length; i++)
              ListTile(
                contentPadding: const EdgeInsets.symmetric(vertical: 2),
                leading: CircleAvatar(
                  backgroundColor: _partnerBanks[i]['color'] as Color,
                  child: Text(
                    _partnerBanks[i]['avatar'] as String,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                title: Text(
                  _partnerBanks[i]['name'] as String,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                subtitle: Text(
                  _partnerBanks[i]['group'] as String,
                  style: const TextStyle(fontSize: 11, color: textGray),
                ),
                trailing: _selectedPartnerBankIndex == i
                    ? const Icon(Icons.check_circle_rounded, color: brandViolet)
                    : null,
                onTap: () {
                  setState(() => _selectedPartnerBankIndex = i);
                  Navigator.of(ctx).pop();
                },
              ),
          ],
        ),
      ),
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
