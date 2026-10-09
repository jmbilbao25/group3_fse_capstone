import '../../widgets/aura_logo.dart';
import 'package:flutter/material.dart';
import '../../models/annual_quarter_item.dart';
import '../../services/bank_service.dart';
import 'statement_preview_screen.dart';

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

  static const Color brandPurple = Color(0xFF10171C);
  static const Color brandViolet = Color(0xFF1C6E5A);
  static const Color greenCredit = Color(0xFF17805F);
  static const Color darkGreen = Color(0xFF17805F);
  static const Color redDebit = Color(0xFFC8423B);
  static const Color textDark = Color(0xFF10171C);
  static const Color textGray = Color(0xFF7D8892);
  static const Color cardBorder = Color(0xFFEAECEE);
  static const Color lavenderBg = Color(0xFFFBF8FD);
  static const Color lavenderBorder = Color(0xFFE6F6EF);

  final List<String> _availablePeriods = [
    'Annual Report (2026)',
    'FY 2025 Annual Dossier',
    'FY 2024 Historical Ledger',
  ];

  late final List<AnnualQuarterItem> _quarterItems;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });

    _quarterItems = const [
      AnnualQuarterItem(
        id: 'q4',
        title: 'Quarter 4 (Oct-Dec 2026)',
        subtitle: 'Q4 2026',
        amount: 26000.0,
        settledCount: 53,
        isIncoming: true,
      ),
      AnnualQuarterItem(
        id: 'q3',
        title: 'Quarter 3 (July-Sept 2026)',
        subtitle: '05 Oct 2026 - 10:00 AM',
        amount: 56700.0,
        settledCount: 63,
        isIncoming: true,
      ),
      AnnualQuarterItem(
        id: 'q2',
        title: 'Quarter 2 (April-June 2026)',
        subtitle: 'Q2 2026',
        amount: 90000.0,
        settledCount: 48,
        isIncoming: true,
      ),
      AnnualQuarterItem(
        id: 'q1',
        title: 'Quarter 1 (Jan-March 2026)',
        subtitle: 'Q1 2026',
        amount: 50000.0,
        settledCount: 42,
        isIncoming: true,
      ),
    ];
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
    const totalReceived = 560000.0;
    const totalSent = 415000.0;
    const allCount = 4;
    const inCount = 4;
    const outCount = 0;

    var filteredItems = _quarterItems.where((item) {
      if (_filterTab == 'In') return item.isIncoming;
      if (_filterTab == 'Out') return !item.isIncoming;
      return true;
    }).toList();

    if (_searchQuery.isNotEmpty) {
      filteredItems = filteredItems.where((item) {
        return item.title.toLowerCase().contains(_searchQuery) ||
            item.subtitle.toLowerCase().contains(_searchQuery);
      }).toList();
    }

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
                        // Label: Select Report Period
                        const Text(
                          'Select Report Period',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF2E3A43),
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Period Selector Container
                        _buildPeriodSelector(),

                        if (_isPeriodDropdownOpen) _buildPeriodDropdownList(),

                        const SizedBox(height: 18),

                        // Main Annual Dossier Card
                        _buildAnnualCard(totalReceived, totalSent, allCount, inCount, outCount),

                        const SizedBox(height: 24),

                        // Transfer Record Section Header & Filter Pills
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Transfer Record (${_quarterItems.length})',
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

                        // Quarter Items List
                        if (filteredItems.isEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 36),
                            alignment: Alignment.center,
                            child: const Text(
                              'No report records found',
                              style: TextStyle(fontSize: 13, color: textGray),
                            ),
                          )
                        else
                          ...filteredItems.map(_buildQuarterCard),

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
              child: _buildExportPdfButton(),
            ),
          ],
        ),
      ),
    );
  }

  // Header with circular back button and centered title + date subtitle
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

          // Title & Date Subtitle
          Column(
            children: const [
              Text(
                'Aura Annual Report',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: textDark,
                  letterSpacing: -0.4,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Jan 01 - Dec 31, 2026',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: textGray,
                ),
              ),
            ],
          ),

          // Balancing spacer
          const SizedBox(width: 44),
        ],
      ),
    );
  }

  // Period Selector Dropdown
  Widget _buildPeriodSelector() {
    return GestureDetector(
      onTap: () {
        setState(() {
          _isPeriodDropdownOpen = !_isPeriodDropdownOpen;
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
              _selectedPeriod,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: textDark,
              ),
            ),
            Icon(
              _isPeriodDropdownOpen
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
  Widget _buildPeriodDropdownList() {
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
        children: _availablePeriods.map((period) {
          final isSelected = period == _selectedPeriod;
          return InkWell(
            onTap: () {
              setState(() {
                _selectedPeriod = period;
                _isPeriodDropdownOpen = false;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              color: isSelected ? lavenderBg : Colors.transparent,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    period,
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

  // Main Annual Dossier Card
  Widget _buildAnnualCard(
    double totalReceived,
    double totalSent,
    int allCount,
    int inCount,
    int outCount,
  ) {
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
          // Row 1: Aura Bank Branding & Annual Dossier Badge
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
                  'Annual Dossier',
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

          // Row 2: Account Holder & Statement Period
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
                    children: const [
                      Text(
                        'Statement Period',
                        style: TextStyle(fontSize: 10, color: textGray),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Jan 01 - Dec 31, 2026',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: textDark,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 2),
                      Text(
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
                        'PHP ${_formatCurrency(totalReceived)}',
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
                        'PHP ${_formatCurrency(totalSent)}',
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
                        '$allCount',
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
                        '$inCount',
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
                        '$outCount',
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

  // Quarter Item Card (Matching SOA - Annual)
  Widget _buildQuarterCard(AnnualQuarterItem item) {
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
          // Circle Avatar with "IN"
          CircleAvatar(
            radius: 19,
            backgroundColor: darkGreen,
            child: const Text(
              'IN',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Title and Subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
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
                  item.subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: textGray,
                  ),
                ),
              ],
            ),
          ),

          // Amount and Settled Count Subtitle
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '+ ${_formatCurrency(item.amount)}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: greenCredit,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${item.settledCount} Transfer Settled',
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
  Widget _buildExportPdfButton() {
    final statement = _bankService.statements['2026-10']!;
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
