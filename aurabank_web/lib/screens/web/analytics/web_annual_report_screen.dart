import 'package:flutter/material.dart';
import 'package:aurabank_core/models/annual_quarter_item.dart';
import 'package:aurabank_core/widgets/aura_logo.dart';
import 'package:aurabank_core/services/bank_service.dart';
import 'web_statement_preview_screen.dart';

class WebAnnualReportScreen extends StatefulWidget {
  final VoidCallback? onBack;

  const WebAnnualReportScreen({super.key, this.onBack});

  @override
  State<WebAnnualReportScreen> createState() => _WebAnnualReportScreenState();
}

class _WebAnnualReportScreenState extends State<WebAnnualReportScreen> {
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
  static const Color slateCardBg = Color(0xFFF7F7F7);
  static const Color slateCardBorder = Color(0xFFE6E8EA);

  final List<String> _availablePeriods = const [
    'Annual Report (2026)',
    'FY 2025 Annual Dossier',
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

    final totalCount = _quarterItems.length;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 880),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top Navigation Header with PDF Export Button
                  _buildTopHeader(context),
                  const SizedBox(height: 18),

                  // Select Report Period Bar
                  _buildPeriodSelectorBar(),
                  if (_isPeriodDropdownOpen) ...[
                    const SizedBox(height: 6),
                    _buildPeriodDropdownMenu(),
                  ],
                  const SizedBox(height: 18),

                  // Main Official Annual Dossier Card
                  _buildMainAnnualCard(totalReceived, totalSent, allCount, inCount, outCount),
                  const SizedBox(height: 24),

                  // Transfer Record Header & Filter Pills
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

                  // Quarter Items List
                  if (filteredItems.isEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 36),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: cardBorder),
                      ),
                      child: const Text(
                        'No report records found',
                        style: TextStyle(fontSize: 13, color: textGray),
                      ),
                    )
                  else
                    ...filteredItems.map(_buildQuarterCard),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Top Header: Back button + Title & Subtitle + Export as PDF CTA
  Widget _buildTopHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cardBorder),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: IconButton(
                padding: EdgeInsets.zero,
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  size: 18,
                  color: textDark,
                ),
                onPressed: widget.onBack ?? () => Navigator.maybePop(context),
              ),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                    color: textGray,
                  ),
                ),
              ],
            ),
          ],
        ),

        // Export as PDF Button
        ElevatedButton.icon(
          onPressed: () {
            final statement = _bankService.statements['2026-10']!;
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => WebStatementPreviewScreen(
                  statement: statement,
                ),
              ),
            );
          },
          icon: const Icon(Icons.picture_as_pdf_rounded, size: 16, color: Colors.white),
          label: const Text(
            'Export as PDF',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: brandPurple,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }

  // Select Report Period Bar
  Widget _buildPeriodSelectorBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Select Report Period',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: textGray,
            ),
          ),
          InkWell(
            onTap: () {
              setState(() {
                _isPeriodDropdownOpen = !_isPeriodDropdownOpen;
              });
            },
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F7F7),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: cardBorder),
              ),
              child: Row(
                children: [
                  Text(
                    _selectedPeriod,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: textDark,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _isPeriodDropdownOpen
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: textGray,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodDropdownMenu() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: isSelected ? const Color(0xFFF2FAF6) : Colors.transparent,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    period,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? brandViolet : textDark,
                    ),
                  ),
                  if (isSelected)
                    const Icon(Icons.check_rounded, size: 16, color: brandViolet),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // Main Official Annual Dossier Card
  Widget _buildMainAnnualCard(
    double totalReceived,
    double totalSent,
    int allCount,
    int inCount,
    int outCount,
  ) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: Branding & Annual Dossier Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const AuraLogo(
                    size: 38,
                    style: AuraLogoStyle.violet,
                    borderRadius: 10,
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Aura Bank',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: textDark,
                        ),
                      ),
                      Text(
                        'Intra-Bank Network Ledger',
                        style: TextStyle(
                          fontSize: 11,
                          color: textGray,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F3F4),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFEAECEE)),
                ),
                child: const Text(
                  'Annual Dossier',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: Color(0xFF47525C),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // Row 1: Account Holder & Statement Period (Matching side-by-side light gray cards)
          LayoutBuilder(
            builder: (context, constraints) {
              final isSmall = constraints.maxWidth < 560;
              final accountCard = Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: slateCardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: slateCardBorder),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Account Holder',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.6,
                              color: textGray,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Elijah Riley Montefalco',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: textDark,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 3),
                          Text(
                            '1584 4447 3697 1327 (Savings)',
                            style: TextStyle(fontSize: 10.5, color: textGray),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE6F6EF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.person_rounded, size: 20, color: brandViolet),
                    ),
                  ],
                ),
              );

              final statementCard = Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: slateCardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: slateCardBorder),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start, // LEFT ALIGNED!
                        children: const [
                          Text(
                            'Statement Period',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.6,
                              color: textGray,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Jan 01 - Dec 31, 2026',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: textDark,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Currency: PHP',
                            style: TextStyle(fontSize: 10.5, color: textGray),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F3F4),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.calendar_today_rounded, size: 18, color: textGray),
                    ),
                  ],
                ),
              );

              if (isSmall) {
                return Column(
                  children: [
                    accountCard,
                    const SizedBox(height: 12),
                    statementCard,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: accountCard),
                  const SizedBox(width: 14),
                  Expanded(child: statementCard),
                ],
              );
            },
          ),

          const SizedBox(height: 14),

          // Row 2: Total Received & Total Sent (Matching side-by-side cards)
          LayoutBuilder(
            builder: (context, constraints) {
              final isSmall = constraints.maxWidth < 560;

              final receivedCard = Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFE4F5EE),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFA7E8D1)),
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
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.6,
                              color: greenCredit,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'PHP ${_formatCurrency(totalReceived)}',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: greenCredit,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE4F5EE),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.arrow_downward_rounded, size: 20, color: greenCredit),
                    ),
                  ],
                ),
              );

              final sentCard = Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFDF3F2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFECDD3)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Total Sent',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.6,
                              color: redDebit,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'PHP ${_formatCurrency(totalSent)}',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: redDebit,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFBE9E7),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.arrow_upward_rounded, size: 20, color: redDebit),
                    ),
                  ],
                ),
              );

              if (isSmall) {
                return Column(
                  children: [
                    receivedCard,
                    const SizedBox(height: 12),
                    sentCard,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: receivedCard),
                  const SizedBox(width: 14),
                  Expanded(child: sentCard),
                ],
              );
            },
          ),

          const SizedBox(height: 14),

          // Row 3: 3-Column Pill (ALL | IN | OUT)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F7F7),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: cardBorder),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      const Text(
                        'ALL',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                          color: textGray,
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
                Container(width: 1, height: 28, color: cardBorder),
                Expanded(
                  child: Column(
                    children: [
                      const Text(
                        'IN',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
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
                Container(width: 1, height: 28, color: cardBorder),
                Expanded(
                  child: Column(
                    children: [
                      const Text(
                        'OUT',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
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

  // Segment Filter Tab (All | In | Out)
  Widget _buildFilterSegment() {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F3F4),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: ['All', 'In', 'Out'].map((tab) {
          final isSelected = _filterTab == tab;
          return GestureDetector(
            onTap: () => setState(() => _filterTab = tab),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
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
                  fontSize: 11.5,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cardBorder),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, size: 18, color: textGray),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchController,
              style: const TextStyle(fontSize: 12.5, color: textDark),
              decoration: const InputDecoration(
                hintText: 'Search',
                hintStyle: TextStyle(fontSize: 12.5, color: textGray),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          if (_searchQuery.isNotEmpty)
            GestureDetector(
              onTap: () {
                _searchController.clear();
                setState(() => _searchQuery = '');
              },
              child: const Icon(Icons.close_rounded, size: 16, color: textGray),
            ),
        ],
      ),
    );
  }

  // Quarter Item Card
  Widget _buildQuarterCard(AnnualQuarterItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cardBorder),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: darkGreen,
            child: const Text(
              'IN',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.subtitle,
                  style: const TextStyle(fontSize: 10.5, color: textGray),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '+ ${_formatCurrency(item.amount)}',
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: greenCredit,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${item.settledCount} Transfer Settled',
                style: const TextStyle(fontSize: 10, color: textGray),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
