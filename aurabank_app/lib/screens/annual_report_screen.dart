import 'package:flutter/material.dart';
import '../models/bank_models.dart';
import '../services/bank_service.dart';
import '../theme/aura_theme.dart';
import '../widgets/aura_logo.dart';
import 'statement_preview_screen.dart';

class AnnualTxItem {
  final String id;
  final String title;
  final String subtitle;
  final String quarter;
  final double amount;
  final bool isIncoming;
  final String counterparty;
  final String reference;
  final String initial;
  final Color avatarBg;
  final String status;

  const AnnualTxItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.quarter,
    required this.amount,
    required this.isIncoming,
    required this.counterparty,
    required this.reference,
    required this.initial,
    required this.avatarBg,
    this.status = 'SETTLED',
  });
}

class AnnualReportScreen extends StatefulWidget {
  final VoidCallback? onBack;

  const AnnualReportScreen({super.key, this.onBack});

  @override
  State<AnnualReportScreen> createState() => _AnnualReportScreenState();
}

class _AnnualReportScreenState extends State<AnnualReportScreen> {
  final BankService _bankService = BankService();
  String _selectedPeriod = 'Annual Report (2026)';
  bool _isPeriodDropdownOpen = false;
  String _filterTab = 'All'; // 'All', 'In', 'Out'
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  static const Color brandViolet = AuraColors.primary;
  static const Color brandAccent = AuraColors.accent;
  static const Color greenCredit = AuraColors.creditGreen;
  static const Color redDebit = AuraColors.debitRed;
  static const Color textDark = AuraColors.textPrimary;
  static const Color textMuted = AuraColors.textMuted;
  static const Color cardBorder = AuraColors.cardBorder;
  static const Color bgCanvas = AuraColors.canvas;

  final List<String> _availablePeriods = [
    'Annual Report (2026)',
    'FY 2025 Annual Dossier',
    'FY 2024 Historical Ledger',
  ];

  late final List<AnnualTxItem> _allYearlyItems;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });

    _allYearlyItems = [
      // Q4
      const AnnualTxItem(
        id: 'ann_q4_in',
        title: 'Quarter 4 Inflow Tranche',
        subtitle: '15 Dec 2026 • 11:30 AM',
        quarter: 'Quarter 4 (Oct-Dec 2026)',
        amount: 145000.0,
        isIncoming: true,
        counterparty: 'Temenos Core Clearing',
        reference: 'Q4-DISB-9901',
        initial: 'Q4',
        avatarBg: Color(0xFF6200EA),
      ),
      const AnnualTxItem(
        id: 'ann_q4_out',
        title: 'Quarter 4 Tax & Supplier Amortization',
        subtitle: '28 Dec 2026 • 04:00 PM',
        quarter: 'Quarter 4 (Oct-Dec 2026)',
        amount: 119000.0,
        isIncoming: false,
        counterparty: 'Bureau of Internal Revenue',
        reference: 'TAX-Q4-2026',
        initial: 'TX',
        avatarBg: Color(0xFFC2185B),
      ),

      // Q3
      const AnnualTxItem(
        id: 'ann_q3_in',
        title: 'Quarter 3 Commercial Dividend',
        subtitle: '05 Oct 2026 • 10:00 AM',
        quarter: 'Quarter 3 (July-Sept 2026)',
        amount: 156700.0,
        isIncoming: true,
        counterparty: 'Aura Capital Equity',
        reference: 'DIV-2026-Q3',
        initial: 'AC',
        avatarBg: Color(0xFF00897B),
      ),
      const AnnualTxItem(
        id: 'ann_q3_out',
        title: 'Quarter 3 Capital Expenditure',
        subtitle: '18 Sept 2026 • 02:15 PM',
        quarter: 'Quarter 3 (July-Sept 2026)',
        amount: 100000.0,
        isIncoming: false,
        counterparty: 'Equinix Data Center Lease',
        reference: 'CAPEX-Q3-882',
        initial: 'EQ',
        avatarBg: Color(0xFFE65100),
      ),

      // Q2
      const AnnualTxItem(
        id: 'ann_q2_in',
        title: 'Quarter 2 Inter-Bank Clearing',
        subtitle: '09 July 2026 • 06:00 AM',
        quarter: 'Quarter 2 (April-June 2026)',
        amount: 108300.0,
        isIncoming: true,
        counterparty: 'BDO Unibank Remittance',
        reference: 'CLR-2026-Q2',
        initial: 'BD',
        avatarBg: Color(0xFF1565C0),
      ),
      const AnnualTxItem(
        id: 'ann_q2_out',
        title: 'Quarter 2 Operational Expense',
        subtitle: '25 June 2026 • 05:45 PM',
        quarter: 'Quarter 2 (April-June 2026)',
        amount: 90000.0,
        isIncoming: false,
        counterparty: 'Oracle Cloud Infrastructure',
        reference: 'OCI-Q2-7712',
        initial: 'OC',
        avatarBg: Color(0xFF5E35B1),
      ),

      // Q1
      const AnnualTxItem(
        id: 'ann_q1_in',
        title: 'Quarter 1 Retained Earnings Tranche',
        subtitle: '16 April 2026 • 10:00 AM',
        quarter: 'Quarter 1 (Jan-March 2026)',
        amount: 150000.0,
        isIncoming: true,
        counterparty: 'Central Treasury Ledger',
        reference: 'Q1-EARN-2026',
        initial: 'CT',
        avatarBg: Color(0xFF2E7D32),
      ),
      const AnnualTxItem(
        id: 'ann_q1_out',
        title: 'Quarter 1 Strategic Amortization',
        subtitle: '28 March 2026 • 03:30 PM',
        quarter: 'Quarter 1 (Jan-March 2026)',
        amount: 106000.0,
        isIncoming: false,
        counterparty: 'BSP Settlement Account',
        reference: 'BSP-AMORT-Q1',
        initial: 'BS',
        avatarBg: Color(0xFFD81B60),
      ),
    ];
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  double get _totalReceivedYear => 560000.0;
  double get _totalSentYear => 415000.0;
  double get _netPerformance => _totalReceivedYear - _totalSentYear;

  @override
  Widget build(BuildContext context) {
    final user = _bankService.user;

    // Filter items based on Tab
    var filteredList = _allYearlyItems.where((t) {
      if (_filterTab == 'In') return t.isIncoming;
      if (_filterTab == 'Out') return !t.isIncoming;
      return true;
    }).toList();

    // Filter items based on Search
    if (_searchQuery.isNotEmpty) {
      filteredList = filteredList.where((t) {
        return t.title.toLowerCase().contains(_searchQuery) ||
            t.counterparty.toLowerCase().contains(_searchQuery) ||
            t.reference.toLowerCase().contains(_searchQuery) ||
            t.quarter.toLowerCase().contains(_searchQuery);
      }).toList();
    }

    final totalCount = _allYearlyItems.length;
    final inCount = _allYearlyItems.where((t) => t.isIncoming).length;
    final outCount = _allYearlyItems.where((t) => !t.isIncoming).length;

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
                        // Title + Back Button
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
                                    'Aura Annual Report',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      color: brandViolet,
                                      letterSpacing: -0.4,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  const Text(
                                    'Jan 01 - Dec 31, 2026',
                                    style: TextStyle(
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

                        // Uppercase Selector Label
                        const Text(
                          'SELECT REPORT PERIOD',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            color: textMuted,
                          ),
                        ),

                        const SizedBox(height: 8),

                        // Period Selector Dropdown
                        _buildPeriodDropdown(),

                        const SizedBox(height: 16),

                        // Annual Dossier Certificate Card
                        _buildAnnualDossierCard(user),

                        const SizedBox(height: 18),

                        // Search Bar
                        _buildSearchBar(),

                        const SizedBox(height: 16),

                        // Filter Tabs: All, In, Out (with Counts!)
                        _buildFilterTabs(totalCount, inCount, outCount),

                        const SizedBox(height: 16),

                        // Section Label with count
                        Text(
                          _filterTab == 'All'
                              ? 'QUARTERLY & ANNUAL SETTLEMENTS ($totalCount)'
                              : '$_filterTab TRANSFERS (${filteredList.length})',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            color: textMuted,
                          ),
                        ),

                        const SizedBox(height: 10),

                        // Transactions List
                        if (filteredList.isEmpty)
                          _buildEmptyState()
                        else
                          ...filteredList.map((item) => _buildAnnualTxTile(item)),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // Sticky Bottom Export as PDF Button
            Positioned(
              left: 20,
              right: 20,
              bottom: 18,
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: AuraColors.buttonShadow,
                ),
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: brandViolet,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                  ),
                  icon: const Icon(Icons.print_outlined, size: 20, color: Colors.white),
                  label: const Text(
                    'Export as PDF',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                  onPressed: () {
                    // Navigate to StatementPreviewScreen with annual statement
                    final annualStatement = MonthlyStatement(
                      monthKey: '2026-ANNUAL',
                      title: 'Annual Report (2026)',
                      dateRange: 'Jan 01 - Dec 31, 2026',
                      totalReceived: _totalReceivedYear,
                      totalSent: _totalSentYear,
                      transactions: [
                        for (final item in _allYearlyItems)
                          BankTransaction(
                            id: item.id,
                            reference: item.reference,
                            counterparty: item.counterparty,
                            type: item.isIncoming ? TransactionType.incoming : TransactionType.outgoing,
                            amount: item.amount,
                            timestamp: DateTime(2026, 12, 31),
                            displayTime: item.subtitle,
                            status: TransactionStatus.settled,
                            initial: item.initial,
                            avatarColorValue: item.avatarBg.toARGB32(),
                          ),
                      ],
                    );

                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (ctx) => StatementPreviewScreen(statement: annualStatement),
                      ),
                    );
                  },
                ),
              ),
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
          Row(
            children: const [
              AuraLogo(size: 32, style: AuraLogoStyle.violet, borderRadius: 8),
              SizedBox(width: 8),
              Text(
                'Aura Bank',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: textDark,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF3E8FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE9D5FF)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.verified_user_rounded, color: brandViolet, size: 12),
                SizedBox(width: 4),
                Text(
                  'BSP Regulated',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: brandViolet,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodDropdown() {
    return Column(
      children: [
        GestureDetector(
          onTap: () => setState(() => _isPeriodDropdownOpen = !_isPeriodDropdownOpen),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _isPeriodDropdownOpen ? brandViolet : cardBorder,
                width: _isPeriodDropdownOpen ? 1.5 : 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded, size: 17, color: brandViolet),
                    const SizedBox(width: 10),
                    Text(
                      _selectedPeriod,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: textDark,
                      ),
                    ),
                  ],
                ),
                Icon(
                  _isPeriodDropdownOpen
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: brandViolet,
                ),
              ],
            ),
          ),
        ),
        if (_isPeriodDropdownOpen)
          Container(
            margin: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE9D5FF)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: _availablePeriods.map((period) {
                final isSelected = _selectedPeriod == period;
                return ListTile(
                  dense: true,
                  title: Text(
                    period,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                      color: isSelected ? brandViolet : textDark,
                    ),
                  ),
                  trailing: isSelected
                      ? const Icon(Icons.check_circle_rounded, color: brandViolet, size: 18)
                      : null,
                  onTap: () {
                    setState(() {
                      _selectedPeriod = period;
                      _isPeriodDropdownOpen = false;
                    });
                  },
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildAnnualDossierCard(UserProfile user) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cardBorder, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const AuraLogo(size: 36, style: AuraLogoStyle.violet, borderRadius: 10),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Aura Bank',
                      style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: textDark),
                    ),
                    Text(
                      'Interbank Network Ledger',
                      style: TextStyle(fontSize: 10, color: textMuted),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEDE9FE),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Annual Dossier',
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: brandViolet),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ACCOUNT HOLDER',
                      style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: textMuted),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user.name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: textDark),
                    ),
                    Text(
                      '${_bankService.savingsAccountNumber} (Savings)',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, color: textMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: const [
                  Text(
                    'STATEMENT PERIOD',
                    style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: textMuted),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Jan 01 - Dec 31, 2026',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: textDark),
                  ),
                  Text(
                    'Currency: PHP',
                    style: TextStyle(fontSize: 11, color: textMuted),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 16),
          const Divider(color: cardBorder, height: 1),
          const SizedBox(height: 16),

          // Financial Key Totals
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'TOTAL RECEIVED',
                      style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: textMuted),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'PHP ${_formatCurrency(_totalReceivedYear)}',
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        color: greenCredit,
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
                      style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: textMuted),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'PHP ${_formatCurrency(_totalSentYear)}',
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        color: brandViolet,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Net surplus pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFBBF7D0)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: const [
                      Icon(Icons.trending_up_rounded, color: greenCredit, size: 16),
                      SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Annual Net Performance',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: textDark),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '+ PHP ${_formatCurrency(_netPerformance)}',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
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

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cardBorder),
      ),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(fontSize: 13, color: textDark),
        decoration: InputDecoration(
          hintText: 'Search quarterly tranches or references...',
          hintStyle: const TextStyle(fontSize: 12.5, color: textMuted),
          prefixIcon: const Icon(Icons.search_rounded, color: textMuted, size: 20),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 18, color: textMuted),
                  onPressed: () => _searchController.clear(),
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildFilterTabs(int allCount, int inCount, int outCount) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE9D5FF), width: 1.2),
      ),
      child: Row(
        children: [
          Expanded(child: _buildTabButton('All', allCount)),
          Expanded(child: _buildTabButton('In', inCount)),
          Expanded(child: _buildTabButton('Out', outCount)),
        ],
      ),
    );
  }

  Widget _buildTabButton(String label, int count) {
    final isSelected = _filterTab == label;
    return GestureDetector(
      onTap: () => setState(() => _filterTab = label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? brandViolet : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: brandViolet.withValues(alpha: 0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? Colors.white : textMuted,
              ),
            ),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white.withValues(alpha: 0.2) : const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: isSelected ? Colors.white : textMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnnualTxTile(AnnualTxItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
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
          // IN / OUT Pill Indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
            decoration: BoxDecoration(
              color: item.isIncoming ? const Color(0xFFE8F8EE) : const Color(0xFFFEE2E2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              item.isIncoming ? 'IN' : 'OUT',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: item.isIncoming ? greenCredit : redDebit,
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Title, Quarter & Reference
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${item.subtitle} • ${item.reference}',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: textMuted),
                ),
                const SizedBox(height: 2),
                Text(
                  item.quarter,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: brandAccent,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // Amount & Status
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${item.isIncoming ? '+' : '-'} ₱${_formatCurrency(item.amount)}',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: item.isIncoming ? greenCredit : brandViolet,
                ),
              ),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  item.status,
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: textMuted,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          children: const [
            Icon(Icons.search_off_rounded, size: 44, color: textMuted),
            SizedBox(height: 12),
            Text(
              'No yearly settlements match your filter.',
              style: TextStyle(fontSize: 13, color: textMuted, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  String _formatCurrency(double val) {
    final parts = val.toStringAsFixed(2).split('.');
    final integerPart = parts[0].replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
    return '$integerPart.${parts[1]}';
  }
}
