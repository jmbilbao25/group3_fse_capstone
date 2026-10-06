import 'package:flutter/material.dart';
import '../models/bank_models.dart';
import '../services/bank_service.dart';
import '../theme/aura_theme.dart';
import '../widgets/aura_logo.dart';
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

  static const Color brandPrimary = AuraColors.primary;
  static const Color brandAccent = AuraColors.accent;
  static const Color brandLight = AuraColors.tintPurple;
  static const Color brandBorder = AuraColors.borderPurple;
  static const Color greenCredit = AuraColors.creditGreen;
  static const Color debitRed = AuraColors.debitRed;
  static const Color textDark = AuraColors.textPrimary;
  static const Color textMuted = AuraColors.textMuted;
  static const Color cardBorder = AuraColors.cardBorder;
  static const Color bgCanvas = AuraColors.canvas;

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
    final filteredCount = transactions.length;
    final recordCountLabel = _filterTab == 'All' && _searchQuery.isEmpty
        ? 'TRANSFERS RECORD ($totalCount)'
        : 'TRANSFERS RECORD ($filteredCount OF $totalCount)';

    return Scaffold(
      backgroundColor: bgCanvas,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // Top Header Row
                _buildTopHeader(),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Page Title & Period Subtitle
                        Row(
                          children: [
                            IconButton(
                              onPressed: widget.onBack ?? () => Navigator.of(context).maybePop(),
                              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                              color: textDark,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Statement of Account',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      color: brandPrimary,
                                      letterSpacing: -0.4,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    statement.dateRange,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: brandAccent,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Uppercase Label
                        const Text(
                          'SELECT STATEMENT MONTH',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            color: textMuted,
                          ),
                        ),

                        const SizedBox(height: 8),

                        // Month Dropdown Button
                        _buildMonthSelectorButton(statement),

                        // Dropdown Popover List
                        if (_isMonthDropdownOpen) _buildMonthDropdownOverlay(),

                        const SizedBox(height: 16),

                        // E-Statement Card
                        _buildEStatementCard(statement),

                        const SizedBox(height: 20),

                        // Transfers Record Section Header & Tabs
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              recordCountLabel,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                                color: textMuted,
                              ),
                            ),
                            _buildFilterTabs(),
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
                              'No transfer records match your criteria',
                              style: TextStyle(fontSize: 13, color: textMuted),
                            ),
                          )
                        else
                          ...transactions.map(_buildTransactionRow),

                        const SizedBox(height: 20),

                        // System Generated Audit Stamp
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: const [
                            Text(
                              'System Generated • Aura Core',
                              style: TextStyle(fontSize: 10, color: textMuted),
                            ),
                            Text(
                              'TS: 2026-10-03',
                              style: TextStyle(fontSize: 10, color: textMuted),
                            ),
                          ],
                        ),
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
              bottom: 18,
              child: _buildExportButton(statement),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const AuraLogo(size: 32, style: AuraLogoStyle.violet, borderRadius: 8),
              const SizedBox(width: 8),
              const Text(
                'Aura Bank',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: textDark,
                ),
              ),
            ],
          ),
          Row(
            children: [
              if (_isMonthDropdownOpen)
                Container(
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: greenCredit.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: greenCredit,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      const Text(
                        'Live',
                        style: TextStyle(
                          color: greenCredit,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              Stack(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: cardBorder),
                    ),
                    child: const Icon(
                      Icons.notifications_none_rounded,
                      size: 20,
                      color: textDark,
                    ),
                  ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: debitRed,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMonthSelectorButton(MonthlyStatement statement) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _isMonthDropdownOpen = !_isMonthDropdownOpen;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
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
            Text(
              statement.title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: textDark,
              ),
            ),
            Icon(
              _isMonthDropdownOpen
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
              color: textDark,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthDropdownOverlay() {
    final months = _bankService.statements.entries.toList();

    return Container(
      margin: const EdgeInsets.only(top: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cardBorder, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Column(
          children: months.map((entry) {
            final isSelected = entry.key == _selectedMonthKey;
            return InkWell(
              onTap: () {
                setState(() {
                  _selectedMonthKey = entry.key;
                  _isMonthDropdownOpen = false;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                color: isSelected ? brandLight : Colors.transparent,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      entry.value.title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                        color: isSelected ? brandPrimary : textDark,
                      ),
                    ),
                    if (isSelected)
                      const Icon(Icons.check_rounded, color: brandAccent, size: 18),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildEStatementCard(MonthlyStatement statement) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cardBorder, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header inside card
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const AuraLogo(size: 34, style: AuraLogoStyle.violet, borderRadius: 8),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Aura Bank',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: textDark,
                      ),
                    ),
                    Text(
                      'Intra-Bank Network Ledger',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: brandLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: brandBorder, width: 0.8),
                ),
                child: const Text(
                  'E-STATEMENT',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: brandAccent,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Account Holder & Statement Period Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ACCOUNT HOLDER',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                        color: textMuted,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _bankService.user.name,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: textDark,
                      ),
                    ),
                    const SizedBox(height: 1),
                    const Text(
                      '•••• 5521 (Savings)',
                      style: TextStyle(fontSize: 11, color: textMuted),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'STATEMENT PERIOD',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      color: textMuted,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    statement.dateRange,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: textDark,
                    ),
                  ),
                  const SizedBox(height: 1),
                  const Text(
                    'Currency: PHP (₱)',
                    style: TextStyle(fontSize: 11, color: textMuted),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 16),
          const Divider(color: cardBorder, height: 1),
          const SizedBox(height: 16),

          // Total Received & Total Sent KPI Row
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'TOTAL RECEIVED',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                        color: textMuted,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatCurrency(statement.totalReceived),
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: greenCredit,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'TOTAL SENT',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                        color: textMuted,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatCurrency(statement.totalSent),
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: debitRed,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Count Breakdown Box (ALL / IN / OUT)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFFAF8FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFEDE9FE), width: 0.8),
            ),
            child: Row(
              children: [
                _buildCountColumn('ALL', statement.allCount.toString(), textDark),
                _buildCountDivider(),
                _buildCountColumn('IN', statement.inCount.toString(), greenCredit),
                _buildCountDivider(),
                _buildCountColumn('OUT', statement.outCount.toString(), debitRed),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCountColumn(String label, String count, Color countColor) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: textMuted,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            count,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: countColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCountDivider() {
    return Container(
      width: 1,
      height: 24,
      color: const Color(0xFFDDD6FE),
    );
  }

  Widget _buildFilterTabs() {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFFF0EFF2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: ['All', 'In', 'Out'].map((tab) {
          final isSelected = _filterTab == tab;
          return GestureDetector(
            onTap: () => setState(() => _filterTab = tab),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(7),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ]
                    : null,
              ),
              child: Text(
                tab,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected ? brandPrimary : textMuted,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cardBorder, width: 1.0),
      ),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(fontSize: 13, color: textDark),
        decoration: InputDecoration(
          hintText: 'Search recipient or reference (e.g. Maria, AUR-...',
          hintStyle: const TextStyle(fontSize: 12, color: textMuted),
          prefixIcon: const Icon(Icons.search_rounded, size: 18, color: textMuted),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close_rounded, size: 16, color: textMuted),
                  onPressed: () => _searchController.clear(),
                )
              : null,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildTransactionRow(BankTransaction t) {
    final isIncoming = t.isIncoming;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cardBorder, width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.015),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // IN / OUT Pill Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: isIncoming ? const Color(0xFFE6F8F0) : const Color(0xFFFEE2E2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              isIncoming ? 'IN' : 'OUT',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: isIncoming ? greenCredit : debitRed,
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Name and Reference / Timestamp
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.counterparty,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${t.reference} • ${t.displayTime}  ${t.statusDisplay}',
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // Amount
          Text(
            t.formattedAmount,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: isIncoming ? greenCredit : debitRed,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExportButton(MonthlyStatement statement) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: AuraColors.buttonShadow,
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: brandPrimary,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => StatementPreviewScreen(statement: statement),
            ),
          );
        },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.print_outlined, color: Colors.white, size: 19),
            SizedBox(width: 8),
            Text(
              'Export as PDF',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatCurrency(double amount) {
    final parts = amount.toStringAsFixed(2).split('.');
    final intPart = parts[0].replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
    return '₱$intPart.${parts[1]}';
  }
}
