import '../../widgets/aura_logo.dart';
import 'package:flutter/material.dart';
import '../../models/bank_models.dart';
import '../../services/bank_service.dart';
import 'statement_preview_screen.dart';

class StatementScreen extends StatefulWidget {
  final VoidCallback? onBack;

  const StatementScreen({super.key, this.onBack});

  @override
  State<StatementScreen> createState() => _StatementScreenState();
}

class _StatementScreenState extends State<StatementScreen> {
  final BankService _bankService = BankService();
  String _selectedMonthKey = '2026-10';
  bool _isMonthDropdownOpen = false;
  String _filterTab = 'All'; // 'All', 'In', 'Out'
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  static const Color brandPurple = Color(0xFF10171C);
  static const Color brandViolet = Color(0xFF1C6E5A);
  static const Color greenCredit = Color(0xFF17805F);
  static const Color redDebit = Color(0xFFC8423B);
  static const Color textDark = Color(0xFF10171C);
  static const Color textGray = Color(0xFF7D8892);
  static const Color cardBorder = Color(0xFFEAECEE);
  static const Color lavenderBg = Color(0xFFFBF8FD);
  static const Color lavenderBorder = Color(0xFFE6F6EF);

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatCurrency(double amount) {
    final absAmount = amount.abs().toStringAsFixed(2);
    final parts = absAmount.split('.');
    final intPart = parts[0].replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
    return '$intPart.${parts[1]}';
  }

  @override
  Widget build(BuildContext context) {
    final statement = _bankService.statements[_selectedMonthKey] ??
        _bankService.statements['2026-10']!;

    // Filter transactions
    var transactions = statement.transactions.where((t) {
      if (_filterTab == 'In') return t.isIncoming;
      if (_filterTab == 'Out') return !t.isIncoming;
      return true;
    }).toList();

    if (_searchQuery.isNotEmpty) {
      transactions = transactions.where((t) {
        return t.counterparty.toLowerCase().contains(_searchQuery) ||
            t.reference.toLowerCase().contains(_searchQuery);
      }).toList();
    }

    final totalCount = statement.transactions.length;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // Top Header Row with Back Button and Centered Title
                _buildHeader(context),

                // Scrollable Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 96),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Label: Select Statement Month
                        const Text(
                          'Select Statement Month',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF2E3A43),
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Month Dropdown Container
                        _buildMonthSelector(statement),

                        // Expandable Dropdown List if open
                        if (_isMonthDropdownOpen) _buildMonthDropdownList(),

                        const SizedBox(height: 18),

                        // Main E-Statement Card
                        _buildEStatementCard(statement),

                        const SizedBox(height: 24),

                        // Transfer Record Section Header & Filter Pills
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Transfer Record ($totalCount)',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: textDark,
                                letterSpacing: -0.3,
                              ),
                            ),
                            _buildFilterSegment(),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Search Bar
                        _buildSearchBar(),
                        const SizedBox(height: 14),

                        // Transactions List
                        if (transactions.isEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 36),
                            alignment: Alignment.center,
                            child: const Text(
                              'No transfer records found',
                              style: TextStyle(fontSize: 13, color: textGray),
                            ),
                          )
                        else
                          ...transactions.map(_buildTransactionCard),

                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // Sticky Bottom Button: "Export as PDF"
            Positioned(
              left: 20,
              right: 20,
              bottom: 20,
              child: _buildExportPdfButton(statement),
            ),
          ],
        ),
      ),
    );
  }

  // Header with circular back button and centered title
  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Circular Back Button with Shadow
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
              padding: EdgeInsets.zero,
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 18,
                color: brandViolet,
              ),
              onPressed: widget.onBack ?? () => Navigator.maybePop(context),
            ),
          ),

          // Title
          const Text(
            'Statement of Account',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: textDark,
              letterSpacing: -0.4,
            ),
          ),

          // Balancing spacer
          const SizedBox(width: 44),
        ],
      ),
    );
  }

  // Month selector card
  Widget _buildMonthSelector(MonthlyStatement statement) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _isMonthDropdownOpen = !_isMonthDropdownOpen;
        });
      },
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: brandViolet,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              statement.title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: textDark,
              ),
            ),
            Icon(
              _isMonthDropdownOpen
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
              color: brandViolet,
              size: 28,
            ),
          ],
        ),
      ),
    );
  }

  // Dropdown list popover
  Widget _buildMonthDropdownList() {
    final keys = _bankService.statements.keys.toList();
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: keys.map((key) {
          final item = _bankService.statements[key]!;
          final isSelected = key == _selectedMonthKey;
          return InkWell(
            onTap: () {
              setState(() {
                _selectedMonthKey = key;
                _isMonthDropdownOpen = false;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              color: isSelected ? lavenderBg : Colors.transparent,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    item.title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? brandViolet : textDark,
                    ),
                  ),
                  if (isSelected)
                    const Icon(Icons.check_rounded, color: brandViolet, size: 18),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // Main E-Statement Card
  Widget _buildEStatementCard(MonthlyStatement statement) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Row 1: Aura Bank Branding & E-Statement Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const AuraLogo(
                      size: 40,
                      style: AuraLogoStyle.violet,
                      borderRadius: 10,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Aura Bank',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: textDark,
                              decoration: TextDecoration.underline,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Intra-Bank Network Ledger',
                            style: TextStyle(
                              fontSize: 11,
                              color: textGray,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F3F4),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'E-Statement',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2E3A43),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Row 2: Account Holder & Statement Period (two inner white cards)
          Row(
            children: [
              // Account Holder
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFF1F3F4)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Account Holder',
                        style: TextStyle(fontSize: 10, color: textGray),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _bankService.user.name.isNotEmpty ? _bankService.user.name : 'Juan Dela Cruz',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: textDark,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_bankService.savingsAccountNumber} (Savings)',
                        style: const TextStyle(fontSize: 9.5, color: textGray),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Statement Period
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFF1F3F4)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Statement Period',
                        style: TextStyle(fontSize: 10, color: textGray),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        statement.dateRange,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: textDark,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Currency: PHP',
                        style: TextStyle(fontSize: 9.5, color: textGray),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Row 3: Total Received & Total Sent Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: lavenderBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: lavenderBorder),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Total Received',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: textDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'PHP ${_formatCurrency(statement.totalReceived)}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: greenCredit,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  height: 32,
                  color: const Color(0xFFC9EBDD),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Total Sent',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: textDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'PHP ${_formatCurrency(statement.totalSent)}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: redDebit,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // Row 4: Counts (ALL, IN, OUT) Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: lavenderBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: lavenderBorder),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      const Text(
                        'ALL',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF2E3A43),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${statement.allCount}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: textDark,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  height: 30,
                  color: const Color(0xFFC9EBDD),
                ),
                Expanded(
                  child: Column(
                    children: [
                      const Text(
                        'IN',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: greenCredit,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${statement.inCount}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: greenCredit,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  height: 30,
                  color: const Color(0xFFC9EBDD),
                ),
                Expanded(
                  child: Column(
                    children: [
                      const Text(
                        'OUT',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: redDebit,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${statement.outCount}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: redDebit,
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

  // Filter Segment Pills: All, In, Out
  Widget _buildFilterSegment() {
    const tabs = ['All', 'In', 'Out'];
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F3F4),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: tabs.map((tab) {
          final isSelected = _filterTab == tab;
          return GestureDetector(
            onTap: () {
              setState(() {
                _filterTab = tab;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ]
                    : null,
              ),
              child: Text(
                tab,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? textDark : textGray,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // Search Bar
  Widget _buildSearchBar() {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cardBorder),
      ),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(fontSize: 13, color: textDark),
        decoration: InputDecoration(
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: Color(0xFF9AA3AB),
            size: 20,
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 16, color: Color(0xFF9AA3AB)),
                  onPressed: () {
                    _searchController.clear();
                  },
                )
              : null,
          hintText: 'Search',
          hintStyle: const TextStyle(color: Color(0xFF9AA3AB), fontSize: 13),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  // Transaction Item Card
  Widget _buildTransactionCard(BankTransaction item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Circle Avatar with Initial
          CircleAvatar(
            radius: 19,
            backgroundColor: Color(item.avatarColorValue),
            child: Text(
              item.initial,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Name and timestamp
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.counterparty,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: textDark,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  item.displayTime,
                  style: const TextStyle(
                    fontSize: 11,
                    color: textGray,
                  ),
                ),
              ],
            ),
          ),

          // Amount and status subtitle
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${item.isIncoming ? '+' : '-'} ${_formatCurrency(item.amount)}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: item.isIncoming ? greenCredit : redDebit,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                item.isIncoming ? 'Transfer Received' : 'Transfer Sent',
                style: const TextStyle(
                  fontSize: 10,
                  color: textGray,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Sticky Export as PDF Button
  Widget _buildExportPdfButton(MonthlyStatement statement) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => StatementPreviewScreen(statement: statement),
            ),
          );
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color: brandPurple,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: brandPurple.withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(
                Icons.print_outlined,
                color: Colors.white,
                size: 22,
              ),
              SizedBox(width: 10),
              Text(
                'Export as PDF',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
