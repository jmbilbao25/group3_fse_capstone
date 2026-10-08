import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/bank_models.dart';
import '../services/bank_service.dart';
import 'statement_preview_screen.dart';
import 'statement_screen.dart';

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
    this.status = '53 Transfer Settled',
  });
}

class YearReportData {
  final String yearLabel;
  final String year;
  final String dateRange;
  final double totalReceived;
  final double totalSent;
  final List<AnnualTxItem> items;

  const YearReportData({
    required this.yearLabel,
    required this.year,
    required this.dateRange,
    required this.totalReceived,
    required this.totalSent,
    required this.items,
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
  String _selectedPeriod = '2026 Annual Report';
  bool _isPeriodDropdownOpen = false;
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

  final List<String> _availablePeriods = [
    '2026 Annual Report',
    '2025 Annual Report',
    '2024 Annual Report',
  ];

  late final Map<String, YearReportData> _annualReports;

  YearReportData get _currentReport =>
      _annualReports[_selectedPeriod] ?? _annualReports['2026 Annual Report']!;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });

    _annualReports = {
      '2026 Annual Report': const YearReportData(
        yearLabel: '2026 Annual Report',
        year: '2026',
        dateRange: 'Jan 01 - Dec 31, 2026',
        totalReceived: 560000.0,
        totalSent: 415000.0,
        items: [
          AnnualTxItem(
            id: 'ann_q4_2026',
            title: 'Quarter 4 (Oct-Dec 2026)',
            subtitle: 'Q4 2026',
            quarter: 'Quarter 4 (Oct-Dec 2026)',
            amount: 26000.0,
            isIncoming: true,
            counterparty: 'Temenos Core Clearing',
            reference: 'Q4-DISB-9901',
            initial: 'IN',
            avatarBg: Color(0xFF059669),
            status: '53 Transfer Settled',
          ),
          AnnualTxItem(
            id: 'ann_q3_2026',
            title: 'Quarter 3 (July-Sept 2026)',
            subtitle: '05 Oct 2026 - 10:00 AM',
            quarter: 'Quarter 3 (July-Sept 2026)',
            amount: 56700.0,
            isIncoming: true,
            counterparty: 'Aura Capital Equity',
            reference: 'DIV-2026-Q3',
            initial: 'IN',
            avatarBg: Color(0xFF059669),
            status: '63 Transfer Settled',
          ),
          AnnualTxItem(
            id: 'ann_q2_2026',
            title: 'Quarter 2 (April-June 2026)',
            subtitle: 'Q2 2026',
            quarter: 'Quarter 2 (April-June 2026)',
            amount: 90000.0,
            isIncoming: true,
            counterparty: 'BDO Unibank Remittance',
            reference: 'CLR-2026-Q2',
            initial: 'IN',
            avatarBg: Color(0xFF059669),
            status: '78 Transfer Settled',
          ),
          AnnualTxItem(
            id: 'ann_q1_2026',
            title: 'Quarter 1 (Jan-March 2026)',
            subtitle: 'Q1 2026',
            quarter: 'Quarter 1 (Jan-March 2026)',
            amount: 50000.0,
            isIncoming: true,
            counterparty: 'Central Treasury Ledger',
            reference: 'Q1-EARN-2026',
            initial: 'IN',
            avatarBg: Color(0xFF059669),
            status: '42 Transfer Settled',
          ),
        ],
      ),
      '2025 Annual Report': const YearReportData(
        yearLabel: '2025 Annual Report',
        year: '2025',
        dateRange: 'Jan 01 - Dec 31, 2025',
        totalReceived: 485000.0,
        totalSent: 362000.0,
        items: [
          AnnualTxItem(
            id: 'ann_q4_2025',
            title: 'Quarter 4 (Oct-Dec 2025)',
            subtitle: 'Q4 2025',
            quarter: 'Quarter 4 (Oct-Dec 2025)',
            amount: 48500.0,
            isIncoming: true,
            counterparty: 'InstaPay Clearing Network',
            reference: 'Q4-SETL-2025',
            initial: 'IN',
            avatarBg: Color(0xFF059669),
            status: '61 Transfer Settled',
          ),
          AnnualTxItem(
            id: 'ann_q3_2025',
            title: 'Quarter 3 (July-Sept 2025)',
            subtitle: 'Q3 2025',
            quarter: 'Quarter 3 (July-Sept 2025)',
            amount: 39200.0,
            isIncoming: true,
            counterparty: 'PESONet Interbank Hub',
            reference: 'Q3-DISB-2025',
            initial: 'IN',
            avatarBg: Color(0xFF059669),
            status: '54 Transfer Settled',
          ),
          AnnualTxItem(
            id: 'ann_q2_2025',
            title: 'Quarter 2 (April-June 2025)',
            subtitle: 'Q2 2025',
            quarter: 'Quarter 2 (April-June 2025)',
            amount: 74000.0,
            isIncoming: true,
            counterparty: 'BDO Unibank Remittance',
            reference: 'Q2-CLR-2025',
            initial: 'IN',
            avatarBg: Color(0xFF059669),
            status: '82 Transfer Settled',
          ),
          AnnualTxItem(
            id: 'ann_q1_2025',
            title: 'Quarter 1 (Jan-March 2025)',
            subtitle: 'Q1 2025',
            quarter: 'Quarter 1 (Jan-March 2025)',
            amount: 46000.0,
            isIncoming: true,
            counterparty: 'Central Treasury Ledger',
            reference: 'Q1-EARN-2025',
            initial: 'IN',
            avatarBg: Color(0xFF059669),
            status: '49 Transfer Settled',
          ),
        ],
      ),
      '2024 Annual Report': const YearReportData(
        yearLabel: '2024 Annual Report',
        year: '2024',
        dateRange: 'Jan 01 - Dec 31, 2024',
        totalReceived: 390000.0,
        totalSent: 295000.0,
        items: [
          AnnualTxItem(
            id: 'ann_q4_2024',
            title: 'Quarter 4 (Oct-Dec 2024)',
            subtitle: 'Q4 2024',
            quarter: 'Quarter 4 (Oct-Dec 2024)',
            amount: 34000.0,
            isIncoming: true,
            counterparty: 'UnionBank Direct Clearing',
            reference: 'Q4-SETL-2024',
            initial: 'IN',
            avatarBg: Color(0xFF059669),
            status: '45 Transfer Settled',
          ),
          AnnualTxItem(
            id: 'ann_q3_2024',
            title: 'Quarter 3 (July-Sept 2024)',
            subtitle: 'Q3 2024',
            quarter: 'Quarter 3 (July-Sept 2024)',
            amount: 51500.0,
            isIncoming: true,
            counterparty: 'PESONet Interbank Hub',
            reference: 'Q3-DISB-2024',
            initial: 'IN',
            avatarBg: Color(0xFF059669),
            status: '58 Transfer Settled',
          ),
          AnnualTxItem(
            id: 'ann_q2_2024',
            title: 'Quarter 2 (April-June 2024)',
            subtitle: 'Q2 2024',
            quarter: 'Quarter 2 (April-June 2024)',
            amount: 58000.0,
            isIncoming: true,
            counterparty: 'Metrobank Remittance',
            reference: 'Q2-CLR-2024',
            initial: 'IN',
            avatarBg: Color(0xFF059669),
            status: '66 Transfer Settled',
          ),
          AnnualTxItem(
            id: 'ann_q1_2024',
            title: 'Quarter 1 (Jan-March 2024)',
            subtitle: 'Q1 2024',
            quarter: 'Quarter 1 (Jan-March 2024)',
            amount: 38000.0,
            isIncoming: true,
            counterparty: 'Central Treasury Ledger',
            reference: 'Q1-EARN-2024',
            initial: 'IN',
            avatarBg: Color(0xFF059669),
            status: '39 Transfer Settled',
          ),
        ],
      ),
    };
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  double get _totalReceivedYear => _currentReport.totalReceived;
  double get _totalSentYear => _currentReport.totalSent;

  @override
  Widget build(BuildContext context) {
    final currentData = _currentReport;
    final allItems = currentData.items;

    // Filter items based on Tab
    var filteredList = allItems.where((t) {
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
            t.quarter.toLowerCase().contains(_searchQuery) ||
            t.amount.toString().contains(_searchQuery);
      }).toList();
    }

    final totalCount = allItems.length;
    final inCount = allItems.where((t) => t.isIncoming).length;
    final outCount = allItems.where((t) => !t.isIncoming).length;
    final filteredCount = filteredList.length;

    return Scaffold(
      backgroundColor: bgCanvas,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // Top Header Row (Back <, Center Title & Subtitle, + Action)
                _buildTopHeader(),

                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Label above period selector
                        const Text(
                          'Select Report Period',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: textMuted,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Period Selector Box
                        _buildPeriodSelectorButton(),

                        // Period Dropdown Popover List
                        if (_isPeriodDropdownOpen) _buildPeriodDropdownOverlay(),

                        const SizedBox(height: 16),

                        // Main Institutional Dossier Card
                        _buildDossierCard(totalCount, inCount, outCount),

                        const SizedBox(height: 20),

                        // Transfer Record Section Header (Title + Tabs)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Text(
                                'Transfer Record ($filteredCount)',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: textDark,
                                  letterSpacing: -0.3,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            _buildFilterTabs(totalCount, inCount, outCount),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // Search Bar
                        _buildSearchBar(),

                        const SizedBox(height: 12),

                        // Transactions List
                        if (filteredList.isEmpty)
                          _buildEmptyState()
                        else
                          ...filteredList.map(_buildAnnualTxCard),

                        const SizedBox(height: 24),

                        // System Generated Audit Stamp
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                'Fiscal Year ${_currentReport.year} • Certified Transfer Ledger',
                                style: const TextStyle(fontSize: 10, color: textMuted),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'BSP REGULATED',
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
              child: _buildExportButton(),
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

          // Center Title & Date Subtitle
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Aura Annual Report',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: textDark,
                    letterSpacing: -0.3,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  _currentReport.dateRange,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: textMuted,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Circular Plus Button
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

  Widget _buildPeriodSelectorButton() {
    return GestureDetector(
      onTap: () {
        setState(() {
          _isPeriodDropdownOpen = !_isPeriodDropdownOpen;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: _isPeriodDropdownOpen ? brandAccent : const Color(0xFFE2E8F0),
            width: _isPeriodDropdownOpen ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: _isPeriodDropdownOpen
                  ? brandAccent.withValues(alpha: 0.12)
                  : Colors.black.withValues(alpha: 0.025),
              blurRadius: _isPeriodDropdownOpen ? 16 : 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F3FF),
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: const Color(0xFFEDE9FE), width: 1),
              ),
              child: const Icon(
                Icons.auto_graph_rounded,
                size: 16,
                color: brandAccent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'REPORT PERIOD',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      color: textMuted,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    _selectedPeriod,
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                      color: textDark,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
            ),
            AnimatedRotation(
              turns: _isPeriodDropdownOpen ? 0.5 : 0.0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFE2E8F0), width: 0.8),
                ),
                child: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: brandAccent,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodDropdownOverlay() {
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
            ..._availablePeriods.map((period) {
              final isSelected = _selectedPeriod == period;
              return InkWell(
                onTap: () {
                  setState(() {
                    _selectedPeriod = period;
                    _isPeriodDropdownOpen = false;
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
                            Icons.auto_graph_rounded,
                            size: 16,
                            color: isSelected ? brandAccent : textMuted,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            period,
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
            }),
            // Switch to Monthly Statement option
            InkWell(
              onTap: () {
                setState(() => _isPeriodDropdownOpen = false);
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const StatementScreen(),
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
                    Expanded(
                      child: Row(
                        children: [
                          Icon(Icons.calendar_month_rounded, size: 16, color: brandAccent),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Switch to Monthly Statement (October 2026)',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: brandAccent,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 6),
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

  Widget _buildDossierCard(int totalCount, int inCount, int outCount) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
        boxShadow: [
          BoxShadow(
            color: const Color(0x0A0F172A),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: const Color(0x040F172A),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Bank Monogram + Identity + Luxury Status Capsule
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2A0054), Color(0xFF4C1D95)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2A0054).withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
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
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Aura Bank',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: textDark,
                        letterSpacing: -0.3,
                      ),
                    ),
                    SizedBox(height: 1),
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
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2E8F0), width: 0.8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    SizedBox(
                      width: 6,
                      height: 6,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Color(0xFF10B981),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    SizedBox(width: 5),
                    Text(
                      'Annual Dossier',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                        color: Color(0xFF475569),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // Metadata Twin Shelf (Account Holder & Statement Period)
          Row(
            children: [
              // Left Shelf: Account Holder
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFF1F5F9)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Account Holder',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                          color: textMuted,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _bankService.user.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
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
              // Right Shelf: Statement Period
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFF1F5F9)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Statement Period',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                          color: textMuted,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _currentReport.dateRange,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: textDark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
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

          // Financial Cash Flow Hero Section (Dual-Tranche Balance)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFAF5FF), Color(0xFFF5F3FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFEDE9FE), width: 1.0),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(3),
                              decoration: const BoxDecoration(
                                color: Color(0xFFECFDF5),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.arrow_downward_rounded, size: 10, color: greenCredit),
                            ),
                            const SizedBox(width: 5),
                            const Text(
                              'Total Received',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF334155),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 5),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'PHP ${_formatCurrency(_totalReceivedYear)}',
                          style: const TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w900,
                            color: greenCredit,
                            letterSpacing: -0.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  height: 36,
                  color: const Color(0xFFDDD6FE),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(3),
                              decoration: const BoxDecoration(
                                color: Color(0xFFFFF1F2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.arrow_upward_rounded, size: 10, color: debitRed),
                            ),
                            const SizedBox(width: 5),
                            const Text(
                              'Total Sent',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF334155),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 5),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'PHP ${_formatCurrency(_totalSentYear)}',
                          style: const TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w900,
                            color: debitRed,
                            letterSpacing: -0.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Counter Strip: ALL / IN / OUT
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFF1F5F9)),
            ),
            child: Row(
              children: [
                _buildCountColumn('ALL', totalCount.toString(), textDark),
                _buildCountDivider(),
                _buildCountColumn('IN', inCount.toString(), greenCredit),
                _buildCountDivider(),
                _buildCountColumn('OUT', outCount.toString(), debitRed),
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

  Widget _buildAnnualTxCard(AnnualTxItem item) {
    return GestureDetector(
      onTap: () => _showQuarterlyDetailsModal(item),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF1F5F9), width: 1.2),
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
            // Squircle Avatar Monogram (Mint squircle with 'IN')
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(color: greenCredit.withValues(alpha: 0.2), width: 0.8),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    item.initial,
                    style: const TextStyle(
                      color: greenCredit,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    width: 15,
                    height: 15,
                    decoration: BoxDecoration(
                      color: greenCredit,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.arrow_downward_rounded,
                      color: Colors.white,
                      size: 9,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(width: 14),

            // Quarter Title + Subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: textDark,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.subtitle,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            // Amount + Settlement Status
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '+ ${_formatCurrency(item.amount)}',
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w900,
                    color: greenCredit,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    item.status,
                    style: const TextStyle(
                      fontSize: 9.5,
                      color: greenCredit,
                      fontWeight: FontWeight.w700,
                    ),
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

  Widget _buildExportButton() {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2A0054), Color(0xFF4C1D95)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2A0054).withValues(alpha: 0.38),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
        ),
        onPressed: () {
          final currentData = _currentReport;
          final annualStatement = MonthlyStatement(
            monthKey: '${currentData.year}-ANNUAL',
            title: currentData.yearLabel,
            dateRange: currentData.dateRange,
            totalReceived: currentData.totalReceived,
            totalSent: currentData.totalSent,
            transactions: [
              for (final item in currentData.items)
                BankTransaction(
                  id: item.id,
                  reference: item.reference,
                  counterparty: item.counterparty,
                  type: item.isIncoming ? TransactionType.incoming : TransactionType.outgoing,
                  amount: item.amount,
                  timestamp: DateTime(int.tryParse(currentData.year) ?? 2026, 12, 31),
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
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.print_outlined, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 10),
            const Text(
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

  void _showQuarterlyDetailsModal(AnnualTxItem item) {
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
                      'Quarterly Audit Tranche',
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
                        '+ ${_formatCurrency(item.amount)}',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: greenCredit,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE6F8F0),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          item.status.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: greenCredit,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _buildReceiptRow('Tranche Title', item.title),
                _buildReceiptRow('Fiscal Period', item.quarter),
                _buildReceiptRow('Clearing Reference', item.reference, copyable: true),
                _buildReceiptRow('Clearing Counterparty', item.counterparty),
                _buildReceiptRow('Audit Status', 'BSP Reconciled • Primary Vault'),
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
                  'Annual Dossier Operations',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: textDark),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: const Color(0xFFF3E8FF), borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.calendar_month_rounded, color: brandAccent, size: 20),
                  ),
                  title: const Text('View Monthly Statement (October 2026)', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
                  subtitle: const Text('Switch to monthly ledger view', style: TextStyle(fontSize: 11, color: textMuted)),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (c) => const StatementScreen()),
                    );
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.verified_outlined, color: greenCredit, size: 20),
                  ),
                  title: const Text('Request Transfer Certificate', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
                  subtitle: const Text('Certified bank certificate for funds transferred', style: TextStyle(fontSize: 11, color: textMuted)),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Transfer Certificate request submitted successfully.')),
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
