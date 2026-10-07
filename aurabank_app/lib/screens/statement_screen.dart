import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/bank_models.dart';
import '../services/bank_service.dart';
import 'statement_preview_screen.dart';
import 'annual_report_screen.dart';

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

  static const Color brandPrimary = Color(0xFF2A0054);
  static const Color brandAccent = Color(0xFF6D28D9);
  static const Color greenCredit = Color(0xFF059669);
  static const Color debitRed = Color(0xFFDC2626);
  static const Color textDark = Color(0xFF0F172A);
  static const Color textMuted = Color(0xFF64748B);
  static const Color cardBorder = Color(0xFFE2E8F0);
  static const Color bgCanvas = Color(0xFFF8FAFC);
  static const Color badgeBg = Color(0xFFF1F5F9);
  static const Color bannerBg = Color(0xFFF5F3FF);

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

  @override
  Widget build(BuildContext context) {
    final statement = _bankService.statements[_selectedMonthKey] ??
        _bankService.statements['2026-10']!;

    // Filter transactions based on tab
    var transactions = statement.transactions.where((t) {
      if (_filterTab == 'In') return t.isIncoming;
      if (_filterTab == 'Out') return !t.isIncoming;
      return true;
    }).toList();

    // Filter transactions based on search query
    if (_searchQuery.isNotEmpty) {
      transactions = transactions.where((t) {
        return t.counterparty.toLowerCase().contains(_searchQuery) ||
            t.reference.toLowerCase().contains(_searchQuery) ||
            t.amount.toString().contains(_searchQuery);
      }).toList();
    }

    final totalCount = statement.transactions.length;
    final filteredCount = transactions.length;

    return Scaffold(
      backgroundColor: bgCanvas,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // Top Header Row (Back <, Center Title, + Action)
                _buildTopHeader(),

                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Label above period selector
                        const Text(
                          'Select Statement Month',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: textMuted,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Month Dropdown Box
                        _buildMonthSelectorButton(statement),

                        // Month Dropdown Popover List
                        if (_isMonthDropdownOpen) _buildMonthDropdownOverlay(),

                        const SizedBox(height: 16),

                        // Main Institutional Dossier Card
                        _buildDossierCard(statement),

                        const SizedBox(height: 20),

                        // Transfer Record Section Header (Title + Tabs)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              'Transfer Record ($filteredCount)',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: textDark,
                                letterSpacing: -0.3,
                              ),
                            ),
                            _buildFilterTabs(
                              totalCount,
                              statement.inCount,
                              statement.outCount,
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // Search Bar
                        _buildSearchBar(),

                        const SizedBox(height: 12),

                        // Transaction List
                        if (transactions.isEmpty)
                          _buildEmptyState()
                        else
                          ...transactions.map(_buildTransactionCard),

                        const SizedBox(height: 24),

                        // System Generated Audit Stamp
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: const [
                            Expanded(
                              child: Text(
                                'System Generated • Aura Core Ledger',
                                style: TextStyle(fontSize: 10, color: textMuted),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            SizedBox(width: 8),
                            Text(
                              'TS: 2026-10-31',
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
              bottom: 16,
              child: _buildExportButton(statement),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Circular Back Button
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: cardBorder, width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 17, color: textDark),
              padding: EdgeInsets.zero,
              onPressed: widget.onBack ?? () => Navigator.of(context).maybePop(),
            ),
          ),

          // Center Title
          const Text(
            'Statement of Account',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: textDark,
              letterSpacing: -0.3,
            ),
          ),

          // Circular Plus Button (Quick Menu)
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: cardBorder, width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: IconButton(
              icon: const Icon(Icons.add_rounded, size: 24, color: brandAccent),
              padding: EdgeInsets.zero,
              onPressed: _showQuickActionsSheet,
            ),
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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _isMonthDropdownOpen ? brandAccent : const Color(0xFF6D28D9),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: brandAccent.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              statement.title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: textDark,
                letterSpacing: -0.2,
              ),
            ),
            Icon(
              _isMonthDropdownOpen
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
              color: brandAccent,
              size: 26,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthDropdownOverlay() {
    final months = _bankService.statements.entries.toList();

    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE9D5FF), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: brandPrimary.withValues(alpha: 0.12),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 260),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
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
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFFF3E8FF) : Colors.transparent,
                          border: const Border(
                            bottom: BorderSide(color: Color(0xFFF3F4F6), width: 0.8),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.calendar_month_rounded,
                                  size: 16,
                                  color: isSelected ? brandAccent : textMuted,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  entry.value.title,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                    color: isSelected ? brandPrimary : textDark,
                                  ),
                                ),
                              ],
                            ),
                            if (isSelected)
                              const Icon(Icons.check_circle_rounded, color: brandAccent, size: 18),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            // Switch to Annual Report Button at bottom of dropdown
            InkWell(
              onTap: () {
                setState(() => _isMonthDropdownOpen = false);
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const AnnualReportScreen(),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  color: Color(0xFFFAF5FF),
                  border: Border(
                    top: BorderSide(color: Color(0xFFEDE9FE), width: 1.0),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Row(
                      children: [
                        Icon(Icons.auto_graph_rounded, size: 16, color: brandAccent),
                        SizedBox(width: 10),
                        Text(
                          'Switch to Aura Annual Report (2026)',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: brandAccent,
                          ),
                        ),
                      ],
                    ),
                    Icon(Icons.arrow_forward_ios_rounded, size: 12, color: brandAccent),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDossierCard(MonthlyStatement statement) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cardBorder, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Aura Bank Header + E-Statement Tag
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: brandPrimary,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: const Text(
                  'A',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Aura Bank',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: textDark,
                        letterSpacing: -0.2,
                      ),
                    ),
                    Text(
                      'Intra-Bank Network Ledger',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w500,
                        color: textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: cardBorder, width: 0.8),
                ),
                child: const Text(
                  'E-Statement',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF475569),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Two Inner Floating Cards (Account Holder & Statement Period)
          Row(
            children: [
              // Left Card: Account Holder
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: cardBorder),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
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
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          color: textMuted,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _bankService.user.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: textDark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        '1584 4447 3697 1327 (Savings)',
                        style: TextStyle(
                          fontSize: 9.5,
                          color: textMuted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Right Card: Statement Period
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: cardBorder),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Statement Period',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          color: textMuted,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'October 1 - 31, 2026',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: textDark,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Currency: PHP',
                        style: TextStyle(
                          fontSize: 9.5,
                          color: textMuted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Financial Totals Banner (Lavender Box)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: bannerBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFEDE9FE)),
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
                          fontWeight: FontWeight.w700,
                          color: textDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'PHP ${_formatCurrency(statement.totalReceived)}',
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w900,
                          color: greenCredit,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  height: 32,
                  color: const Color(0xFFDDD6FE),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Total Sent',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: textDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'PHP ${_formatCurrency(statement.totalSent)}',
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w900,
                          color: debitRed,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Counter Pills Row: ALL / IN / OUT
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cardBorder),
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
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: textMuted,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            count,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
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
      height: 22,
      color: cardBorder,
    );
  }

  Widget _buildFilterTabs(int allCount, int inCount, int outCount) {
    final tabs = ['All', 'In', 'Out'];
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: tabs.map((tab) {
          final isSelected = _filterTab == tab;
          return GestureDetector(
            onTap: () => setState(() => _filterTab = tab),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
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
                  fontSize: 11.5,
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
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cardBorder),
      ),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textDark),
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.search_rounded, size: 20, color: textMuted),
          hintText: 'Search',
          hintStyle: const TextStyle(fontSize: 13, color: textMuted),
          border: InputBorder.none,
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close_rounded, size: 16, color: textMuted),
                  onPressed: () => _searchController.clear(),
                )
              : null,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildTransactionCard(BankTransaction t) {
    final isIncoming = t.isIncoming;
    final initial = t.counterparty.isNotEmpty ? t.counterparty[0].toUpperCase() : 'T';

    // Color code monogram avatars based on counterparty
    Color avatarColor = const Color(0xFF2A0054);
    if (t.counterparty.contains('Klare')) avatarColor = const Color(0xFF7C3AED);
    if (t.counterparty.contains('Jessi')) avatarColor = const Color(0xFF4C1D95);
    if (t.counterparty.contains('Angel')) avatarColor = const Color(0xFF6D28D9);

    return GestureDetector(
      onTap: () => _showTransactionDetailsModal(t),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
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
            // Circular Avatar Monogram
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: avatarColor,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                initial,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),

            const SizedBox(width: 12),

            // Counterparty Name + Date / Time
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
                    t.displayTime,
                    style: const TextStyle(
                      fontSize: 11,
                      color: textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            // Amount + Status Label
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${isIncoming ? '+' : '-'} ${_formatCurrency(t.amount)}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: isIncoming ? greenCredit : debitRed,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isIncoming ? 'Transfer Received' : 'Transfer Sent',
                  style: const TextStyle(
                    fontSize: 10,
                    color: textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 36),
      alignment: Alignment.center,
      child: Column(
        children: const [
          Icon(Icons.inbox_outlined, size: 36, color: textMuted),
          SizedBox(height: 8),
          Text(
            'No transfer records match your criteria',
            style: TextStyle(fontSize: 13, color: textMuted, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildExportButton(MonthlyStatement statement) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: brandPrimary,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: brandPrimary.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => StatementPreviewScreen(statement: statement),
            ),
          );
        },
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.print_outlined, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Text(
              'Export as PDF',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showTransactionDetailsModal(BankTransaction t) {
    final isIncoming = t.isIncoming;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Container(
            margin: const EdgeInsets.fromLTRB(14, 0, 14, 20),
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x380F172A),
                  blurRadius: 36,
                  offset: Offset(0, 10),
                ),
              ],
            ),
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Transaction Details',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: textDark),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20, color: textMuted),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Center(
                  child: Column(
                    children: [
                      Text(
                        '${isIncoming ? '+' : '-'} ${_formatCurrency(t.amount)}',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: isIncoming ? greenCredit : debitRed,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: isIncoming ? const Color(0xFFE6F8F0) : const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          isIncoming ? 'SETTLED INFLOW' : 'SETTLED OUTFLOW',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: isIncoming ? greenCredit : debitRed,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _buildReceiptRow('Counterparty', t.counterparty),
                _buildReceiptRow('Reference ID', t.reference, copyable: true),
                _buildReceiptRow('Timestamp', t.displayTime),
                _buildReceiptRow('Channel', isIncoming ? 'Intra-Bank Clearing' : 'InstaPay Network'),
                _buildReceiptRow('Audit Status', 'BSP Verified • Member PDIC'),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: brandPrimary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Close', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReceiptRow(String label, String value, {bool copyable = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: textMuted, fontWeight: FontWeight.w600)),
          Row(
            children: [
              Text(value, style: const TextStyle(fontSize: 12, color: textDark, fontWeight: FontWeight.w800)),
              if (copyable) ...[
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: value));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Copied $value to clipboard')),
                    );
                  },
                  child: const Icon(Icons.copy_rounded, size: 13, color: brandAccent),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  void _showQuickActionsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Container(
            margin: const EdgeInsets.fromLTRB(14, 0, 14, 20),
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x380F172A),
                  blurRadius: 36,
                  offset: Offset(0, 10),
                ),
              ],
            ),
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
                  'Statement Operations',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: textDark),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: const Color(0xFFF3E8FF), borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.auto_graph_rounded, color: brandAccent, size: 20),
                  ),
                  title: const Text('View Aura Annual Report (2026)', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
                  subtitle: const Text('Access full fiscal year dossier & quarterly audit', style: TextStyle(fontSize: 11, color: textMuted)),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (c) => const AnnualReportScreen()),
                    );
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.verified_outlined, color: greenCredit, size: 20),
                  ),
                  title: const Text('Certificate of Balance Verification', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
                  subtitle: const Text('Generate BSP certified digital proof of funds', style: TextStyle(fontSize: 11, color: textMuted)),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Balance Certificate verified via Aura Core.')),
                    );
                  },
                ),
              ],
            ),
          ),
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
    return '$intPart.${parts[1]}';
  }
}
