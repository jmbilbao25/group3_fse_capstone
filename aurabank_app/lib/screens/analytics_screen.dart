import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/aura_theme.dart';
import '../widgets/aura_logo.dart';
import 'statement_screen.dart';
import 'annual_report_screen.dart';

/// Data point model for transfer flow points
class FlowPointData {
  final String label;
  final String shortLabel;
  final String dateSubtitle;
  final double received;
  final double sent;
  final int inTransfers;
  final int outTransfers;
  final List<AnalyticsTxItem> transactions;

  const FlowPointData({
    required this.label,
    required this.shortLabel,
    required this.dateSubtitle,
    required this.received,
    required this.sent,
    required this.inTransfers,
    required this.outTransfers,
    required this.transactions,
  });

  double get net => received - sent;
}

class AnalyticsTxItem {
  final String name;
  final String initial;
  final Color avatarBg;
  final String time;
  final double amount;
  final bool isReceived;
  final String status;

  const AnalyticsTxItem({
    required this.name,
    required this.initial,
    required this.avatarBg,
    required this.time,
    required this.amount,
    required this.isReceived,
    this.status = 'COMPLETED',
  });
}

class AnalyticsScreen extends StatefulWidget {
  final VoidCallback? onBack;

  const AnalyticsScreen({super.key, this.onBack});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen>
    with SingleTickerProviderStateMixin {
  bool _isMonthly = true;

  // Selected indices
  int _selectedWeekIndex = 3; // Defaults to Week 4 (matches Page 11 design)
  int _selectedMonthIndex = 3; // Defaults to April (matches Page 12 design)
  bool _showAllTotals = false;

  late AnimationController _animController;
  late Animation<double> _scrubAnimation;
  double _currentScrubFraction = 3.0; // Current floating position in index space

  static const Color brandViolet = AuraColors.primary;
  static const Color accentGreen = AuraColors.creditGreen;
  static const Color lightGreen = Color(0xFF10B981);
  static const Color textDark = AuraColors.textPrimary;
  static const Color textGray = AuraColors.textMuted;

  // Monthly Dataset (5 Weeks in October 2026)
  late final List<FlowPointData> _monthlyWeeks;

  // Yearly Dataset (12 Months in 2026)
  late final List<FlowPointData> _yearlyMonths;

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );

    _scrubAnimation = Tween<double>(begin: 3.0, end: 3.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    )..addListener(() {
        setState(() {
          _currentScrubFraction = _scrubAnimation.value;
        });
      });

    _initDatasets();
  }

  void _initDatasets() {
    _monthlyWeeks = [
      FlowPointData(
        label: 'Week 1',
        shortLabel: 'W1',
        dateSubtitle: 'Oct 01 - Oct 07, 2026',
        received: 8000.0,
        sent: 14500.0,
        inTransfers: 1,
        outTransfers: 3,
        transactions: const [
          AnalyticsTxItem(
            name: 'Angel Lou F. Yabut',
            initial: 'A',
            avatarBg: Color(0xFF7C4DFF),
            time: 'Oct 03, 2:45 pm',
            amount: 2500.0,
            isReceived: false,
          ),
          AnalyticsTxItem(
            name: 'Meralco Utility Bill',
            initial: 'M',
            avatarBg: Color(0xFFE65100),
            time: 'Oct 04, 9:15 am',
            amount: 4500.0,
            isReceived: false,
          ),
          AnalyticsTxItem(
            name: 'Direct Deposit',
            initial: 'D',
            avatarBg: Color(0xFF00897B),
            time: 'Oct 02, 10:00 am',
            amount: 8000.0,
            isReceived: true,
            status: 'RECEIVED',
          ),
        ],
      ),
      FlowPointData(
        label: 'Week 2',
        shortLabel: 'W2',
        dateSubtitle: 'Oct 08 - Oct 14, 2026',
        received: 26500.0,
        sent: 18500.0,
        inTransfers: 1,
        outTransfers: 4,
        transactions: const [
          AnalyticsTxItem(
            name: 'Drake Montefalco',
            initial: 'D',
            avatarBg: Color(0xFF220055),
            time: 'Oct 14, 2:45 pm',
            amount: 2500.0,
            isReceived: false,
          ),
          AnalyticsTxItem(
            name: 'Klare Riego',
            initial: 'K',
            avatarBg: Color(0xFFBA68C8),
            time: 'Oct 14, 1:45 pm',
            amount: 26500.0,
            isReceived: true,
            status: 'RECEIVED',
          ),
          AnalyticsTxItem(
            name: 'Business Supplies',
            initial: 'B',
            avatarBg: Color(0xFF3949AB),
            time: 'Oct 11, 4:20 pm',
            amount: 16000.0,
            isReceived: false,
          ),
        ],
      ),
      FlowPointData(
        label: 'Week 3',
        shortLabel: 'W3',
        dateSubtitle: 'Oct 15 - Oct 21, 2026',
        received: 5000.0,
        sent: 32500.0,
        inTransfers: 1,
        outTransfers: 5,
        transactions: const [
          AnalyticsTxItem(
            name: 'Jessie Mae Dela Paz',
            initial: 'J',
            avatarBg: Color(0xFF00ACC1),
            time: 'Oct 16, 11:30 am',
            amount: 5000.0,
            isReceived: true,
            status: 'RECEIVED',
          ),
          AnalyticsTxItem(
            name: 'Hardware Reorder',
            initial: 'H',
            avatarBg: Color(0xFF5E35B1),
            time: 'Oct 18, 3:15 pm',
            amount: 27500.0,
            isReceived: false,
          ),
          AnalyticsTxItem(
            name: 'Cloud Services',
            initial: 'C',
            avatarBg: Color(0xFF43A047),
            time: 'Oct 20, 8:40 am',
            amount: 5000.0,
            isReceived: false,
          ),
        ],
      ),
      FlowPointData(
        label: 'Week 4',
        shortLabel: 'W4',
        dateSubtitle: 'Oct 22 - Oct 28, 2026',
        received: 18500.0,
        sent: 10500.0,
        inTransfers: 1,
        outTransfers: 2,
        transactions: const [
          AnalyticsTxItem(
            name: 'Mae G. Mercado',
            initial: 'M',
            avatarBg: Color(0xFF5E17EB),
            time: 'Oct 24, 10:15 am',
            amount: 18500.0,
            isReceived: true,
            status: 'RECEIVED',
          ),
          AnalyticsTxItem(
            name: 'Office Lease Share',
            initial: 'O',
            avatarBg: Color(0xFFD81B60),
            time: 'Oct 26, 4:00 pm',
            amount: 10500.0,
            isReceived: false,
          ),
        ],
      ),
      FlowPointData(
        label: 'Week 5',
        shortLabel: 'W5',
        dateSubtitle: 'Oct 29 - Oct 31, 2026',
        received: 5000.0,
        sent: 29000.0,
        inTransfers: 1,
        outTransfers: 4,
        transactions: const [
          AnalyticsTxItem(
            name: 'Payroll Reimbursement',
            initial: 'P',
            avatarBg: Color(0xFF1E88E5),
            time: 'Oct 30, 2:00 pm',
            amount: 25000.0,
            isReceived: false,
          ),
          AnalyticsTxItem(
            name: 'Consulting Honorarium',
            initial: 'C',
            avatarBg: Color(0xFF2ECC71),
            time: 'Oct 31, 5:30 pm',
            amount: 5000.0,
            isReceived: true,
            status: 'RECEIVED',
          ),
          AnalyticsTxItem(
            name: 'Petty Cash',
            initial: 'P',
            avatarBg: Color(0xFF8E24AA),
            time: 'Oct 31, 6:00 pm',
            amount: 4000.0,
            isReceived: false,
          ),
        ],
      ),
    ];

    _yearlyMonths = [
      FlowPointData(
        label: 'January',
        shortLabel: 'Jan',
        dateSubtitle: 'Jan 01 - Jan 31, 2026',
        received: 15000.0,
        sent: 45000.0,
        inTransfers: 3,
        outTransfers: 16,
        transactions: const [],
      ),
      FlowPointData(
        label: 'February',
        shortLabel: 'Feb',
        dateSubtitle: 'Feb 01 - Feb 28, 2026',
        received: 25000.0,
        sent: 38000.0,
        inTransfers: 4,
        outTransfers: 14,
        transactions: const [],
      ),
      FlowPointData(
        label: 'March',
        shortLabel: 'Mar',
        dateSubtitle: 'Mar 01 - Mar 31, 2026',
        received: 10000.0,
        sent: 42000.0,
        inTransfers: 2,
        outTransfers: 19,
        transactions: const [],
      ),
      FlowPointData(
        label: 'April',
        shortLabel: 'Apr',
        dateSubtitle: 'Apr 01 - Apr 30, 2026',
        received: 68500.0,
        sent: 16500.0,
        inTransfers: 6,
        outTransfers: 12,
        transactions: const [],
      ),
      FlowPointData(
        label: 'May',
        shortLabel: 'May',
        dateSubtitle: 'May 01 - May 31, 2026',
        received: 22000.0,
        sent: 35000.0,
        inTransfers: 3,
        outTransfers: 15,
        transactions: const [],
      ),
      FlowPointData(
        label: 'June',
        shortLabel: 'Jun',
        dateSubtitle: 'Jun 01 - Jun 30, 2026',
        received: 15200.0,
        sent: 50000.0,
        inTransfers: 3,
        outTransfers: 10,
        transactions: const [],
      ),
      FlowPointData(
        label: 'July',
        shortLabel: 'Jul',
        dateSubtitle: 'Jul 01 - Jul 31, 2026',
        received: 25500.0,
        sent: 42000.0,
        inTransfers: 5,
        outTransfers: 24,
        transactions: const [],
      ),
      FlowPointData(
        label: 'August',
        shortLabel: 'Aug',
        dateSubtitle: 'Aug 01 - Aug 31, 2026',
        received: 13800.0,
        sent: 38200.0,
        inTransfers: 3,
        outTransfers: 19,
        transactions: const [],
      ),
      FlowPointData(
        label: 'September',
        shortLabel: 'Sep',
        dateSubtitle: 'Sep 01 - Sep 30, 2026',
        received: 18000.0,
        sent: 45000.0,
        inTransfers: 4,
        outTransfers: 18,
        transactions: const [],
      ),
      FlowPointData(
        label: 'October',
        shortLabel: 'Oct',
        dateSubtitle: 'Oct 01 - Oct 31, 2026',
        received: 58000.0,
        sent: 105000.0,
        inTransfers: 4,
        outTransfers: 18,
        transactions: const [],
      ),
      FlowPointData(
        label: 'November',
        shortLabel: 'Nov',
        dateSubtitle: 'Nov 01 - Nov 30, 2026',
        received: 20000.0,
        sent: 48000.0,
        inTransfers: 3,
        outTransfers: 17,
        transactions: const [],
      ),
      FlowPointData(
        label: 'December',
        shortLabel: 'Dec',
        dateSubtitle: 'Dec 01 - Dec 31, 2026',
        received: 30000.0,
        sent: 63300.0,
        inTransfers: 4,
        outTransfers: 22,
        transactions: const [],
      ),
    ];
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _animateToTarget(double targetIndex) {
    _animController.stop();
    _scrubAnimation = Tween<double>(
      begin: _currentScrubFraction,
      end: targetIndex,
    ).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );
    _animController.forward(from: 0.0);
  }

  void _onSelectWeek(int index) {
    setState(() {
      _selectedWeekIndex = index;
      _showAllTotals = false;
    });
    _animateToTarget(index.toDouble());
  }

  void _onSelectMonth(int index) {
    setState(() {
      _selectedMonthIndex = index;
      _showAllTotals = false;
    });
    _animateToTarget(index.toDouble());
  }

  void _onToggleMode(bool monthly) {
    if (_isMonthly == monthly) return;
    setState(() {
      _isMonthly = monthly;
      _showAllTotals = false;
      final target = (monthly ? _selectedWeekIndex : _selectedMonthIndex).toDouble();
      _currentScrubFraction = target;
    });
    _animateToTarget(
      (monthly ? _selectedWeekIndex : _selectedMonthIndex).toDouble(),
    );
  }

  List<FlowPointData> get _currentDataset =>
      _isMonthly ? _monthlyWeeks : _yearlyMonths;

  FlowPointData get _activePointData {
    final list = _currentDataset;
    final index = _isMonthly
        ? _selectedWeekIndex.clamp(0, list.length - 1)
        : _selectedMonthIndex.clamp(0, list.length - 1);
    return list[index];
  }

  // Grand totals
  double get _totalSentMonth => 105000.0;
  double get _totalReceivedMonth => 58000.0;
  int get _transfersOutMonth => 18;
  int get _transfersInMonth => 4;

  double get _totalSentYear => 508000.0;
  double get _totalReceivedYear => 160000.0;
  int get _transfersOutYear => 185;
  int get _transfersInYear => 43;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Header: Logo + App Name
              Row(
                children: [
                  if (widget.onBack != null) ...[
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                      onPressed: widget.onBack,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
                    const SizedBox(width: 4),
                  ],
                  const AuraLogo(size: 40, style: AuraLogoStyle.violet, borderRadius: 10),
                  const SizedBox(width: 12),
                  const Text(
                    'Aura Bank',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: textDark,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // 2. Segmented Toggle: Monthly / Yearly
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF5E17EB), width: 1.5),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _onToggleMode(true),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _isMonthly ? const Color(0xFFEDE9FE) : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text(
                              'Monthly',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: _isMonthly ? brandViolet : textGray,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _onToggleMode(false),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: !_isMonthly ? const Color(0xFFEDE9FE) : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text(
                              'Yearly',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: !_isMonthly ? brandViolet : textGray,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Active filter pill indicator
              _buildSelectionBanner(),

              const SizedBox(height: 12),

              // 3. KPI Cards: Total Sent & Total Received (Dynamic with selected week/month)
              _buildDynamicKpiCards(),

              const SizedBox(height: 18),

              // 4. Interactive Movable Transfer Flow with Pointed Lines & Callouts
              _buildInteractiveTransferFlowSection(),

              const SizedBox(height: 18),

              // 5. Flow Cashflow Delta Card
              _buildFlowBreakdownCard(),

              const SizedBox(height: 18),

              // 6. History Section (Monthly History vs Yearly Summaries)
              _isMonthly ? _buildMonthlyHistorySection() : _buildYearlySummariesSection(),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectionBanner() {
    final active = _activePointData;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF7FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE9D5FF)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: brandViolet,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _showAllTotals
                        ? (_isMonthly ? 'Full Month Summary (October 2026)' : 'Full Year Summary (2026)')
                        : '${active.label} Selected (${active.dateSubtitle})',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: brandViolet,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              setState(() => _showAllTotals = !_showAllTotals);
            },
            child: Text(
              _showAllTotals ? 'Filter by Flow' : 'Show All',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF7C3AED),
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDynamicKpiCards() {
    final active = _activePointData;

    final sentAmount = _showAllTotals
        ? (_isMonthly ? _totalSentMonth : _totalSentYear)
        : active.sent;
    final sentCount = _showAllTotals
        ? (_isMonthly ? _transfersOutMonth : _transfersOutYear)
        : active.outTransfers;

    final receivedAmount = _showAllTotals
        ? (_isMonthly ? _totalReceivedMonth : _totalReceivedYear)
        : active.received;
    final receivedCount = _showAllTotals
        ? (_isMonthly ? _transfersInMonth : _transfersInYear)
        : active.inTransfers;

    final sentTitle = _showAllTotals
        ? (_isMonthly ? 'Total Sent' : 'Total Sent (2026)')
        : 'Sent (${active.shortLabel})';
    final receivedTitle = _showAllTotals
        ? (_isMonthly ? 'Total Received' : 'Total Received (2026)')
        : 'Received (${active.shortLabel})';

    return Row(
      children: [
        // Total Sent Card (Deep Royal Violet)
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: brandViolet,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: brandViolet.withValues(alpha: 0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sentTitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'PHP ${_formatCurrency(sentAmount)}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '$sentCount Transfers Out',
                      style: const TextStyle(fontSize: 10, color: Colors.white70),
                    ),
                    const Icon(Icons.arrow_downward, color: Colors.white, size: 14),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 14),
        // Total Received Card (White with Green Accents)
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE5E7EB)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  receivedTitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: textGray,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'PHP ${_formatCurrency(receivedAmount)}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: textDark,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '$receivedCount Transfers In',
                      style: const TextStyle(fontSize: 10, color: textGray),
                    ),
                    const Icon(Icons.arrow_upward, color: accentGreen, size: 14),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInteractiveTransferFlowSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
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
          // Header with Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Flexible(
                      child: Text(
                        'Transfer Flow',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: textDark,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEDE9FE),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Drag / Tap',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: brandViolet,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildLegendDot(lightGreen, 'Received'),
                  const SizedBox(width: 8),
                  _buildLegendDot(brandViolet, 'Sent'),
                ],
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Interactive Movable Chart Canvas with GestureDetector
          LayoutBuilder(
            builder: (context, constraints) {
              final chartWidth = constraints.maxWidth;
              const chartHeight = 180.0;
              final dataset = _currentDataset;

              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (details) {
                  _handleScrubGesture(details.localPosition.dx, chartWidth, dataset.length);
                },
                onHorizontalDragUpdate: (details) {
                  _handleScrubGesture(details.localPosition.dx, chartWidth, dataset.length);
                },
                onHorizontalDragEnd: (details) {
                  // Snap cleanly to nearest integer index
                  final targetIndex = _currentScrubFraction.round().clamp(0, dataset.length - 1);
                  if (_isMonthly) {
                    _onSelectWeek(targetIndex);
                  } else {
                    _onSelectMonth(targetIndex);
                  }
                },
                child: SizedBox(
                  height: chartHeight,
                  width: chartWidth,
                  child: CustomPaint(
                    painter: _PointedTransferFlowPainter(
                      dataset: dataset,
                      scrubFraction: _currentScrubFraction,
                      isMonthly: _isMonthly,
                    ),
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 12),

          // Clickable Week / Month Pills Bar
          _isMonthly ? _buildWeekClickablePills() : _buildMonthClickablePills(),
        ],
      ),
    );
  }

  void _handleScrubGesture(double localX, double totalWidth, int count) {
    const double paddingX = 24.0;
    final usableWidth = totalWidth - (2 * paddingX);
    if (usableWidth <= 0 || count <= 1) return;

    final normalized = (localX - paddingX) / usableWidth;
    final indexFraction = (normalized * (count - 1)).clamp(0.0, (count - 1).toDouble());

    setState(() {
      _currentScrubFraction = indexFraction;
      final nearest = indexFraction.round().clamp(0, count - 1);
      if (_isMonthly) {
        _selectedWeekIndex = nearest;
      } else {
        _selectedMonthIndex = nearest;
      }
      _showAllTotals = false;
    });
  }

  Widget _buildWeekClickablePills() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(_monthlyWeeks.length, (index) {
        final isSelected = _selectedWeekIndex == index;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2.0),
            child: GestureDetector(
              onTap: () => _onSelectWeek(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? brandViolet : const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? brandViolet : const Color(0xFFE5E7EB),
                    width: isSelected ? 1.5 : 1.0,
                  ),
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
                child: Column(
                  children: [
                    Text(
                      'Week ${index + 1}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                        color: isSelected ? Colors.white : textDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isSelected ? accentGreen : Colors.transparent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildMonthClickablePills() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: List.generate(_yearlyMonths.length, (index) {
          final isSelected = _selectedMonthIndex == index;
          final item = _yearlyMonths[index];
          return Padding(
            padding: const EdgeInsets.only(right: 6.0),
            child: GestureDetector(
              onTap: () => _onSelectMonth(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? brandViolet : const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? brandViolet : const Color(0xFFE5E7EB),
                    width: isSelected ? 1.5 : 1.0,
                  ),
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
                child: Column(
                  children: [
                    Text(
                      item.label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                        color: isSelected ? Colors.white : textDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isSelected ? accentGreen : Colors.transparent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildFlowBreakdownCard() {
    final active = _activePointData;
    final isPositive = active.net >= 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF7FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE9D5FF)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isPositive ? const Color(0xFFE8F8EE) : const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isPositive ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                    color: isPositive ? accentGreen : const Color(0xFFDC2626),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${active.label} Net Flow',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: textDark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isPositive ? 'Surplus / Positive Cash In' : 'Deficit / High Outflow',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          color: isPositive ? accentGreen : const Color(0xFFDC2626),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${isPositive ? '+' : '-'} PHP ${_formatCurrency(active.net.abs())}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: isPositive ? accentGreen : const Color(0xFFDC2626),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${active.inTransfers} In • ${active.outTransfers} Out',
                style: const TextStyle(fontSize: 10, color: textGray),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendDot(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: textDark, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildMonthlyHistorySection() {
    final active = _activePointData;
    final txList = active.transactions;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Monthly History',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textDark),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Showing ${active.label} (${active.dateSubtitle})',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, color: textGray),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Prominent "View Statement" Button
              GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const StatementScreen(),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: brandViolet,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: brandViolet.withValues(alpha: 0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Text(
                    'View\nStatement',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      height: 1.1,
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          if (txList.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'No transactions recorded for ${active.label}.',
                  style: const TextStyle(fontSize: 12, color: textGray),
                ),
              ),
            )
          else ...[
            Text(
              active.dateSubtitle,
              style: const TextStyle(fontSize: 12, color: textGray, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            for (int i = 0; i < txList.length; i++) ...[
              if (i > 0) const SizedBox(height: 12),
              _buildTransactionItem(
                avatarBg: txList[i].avatarBg,
                initial: txList[i].initial,
                name: txList[i].name,
                time: txList[i].time,
                amount: '${txList[i].isReceived ? '+' : '-'} Php ${_formatCurrency(txList[i].amount)}',
                status: txList[i].status,
                statusColor: txList[i].isReceived ? accentGreen : accentGreen,
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildYearlySummariesSection() {
    final active = _activePointData;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Monthly Summaries',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textDark),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Highlighted: ${active.label} 2026',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, color: textGray),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // "Annual Report" Button
              GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const AnnualReportScreen(),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: brandViolet,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: brandViolet.withValues(alpha: 0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Text(
                    'Annual\nReport',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      height: 1.1,
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Active Month Highlight
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFAF7FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFD8B4FE)),
            ),
            child: _buildQuarterRow(
              initial: active.shortLabel,
              monthTitle: '${active.label} 2026 (Selected)',
              transfers: '${active.inTransfers + active.outTransfers} Transfers • + ${_formatCurrency(active.received)}',
              gross: 'PHP ${_formatCurrency(active.sent)}',
              net: '${active.net >= 0 ? '+' : '-'} PHP ${_formatCompactK(active.net.abs())} net',
              avatarBg: brandViolet,
            ),
          ),

          const SizedBox(height: 16),

          const Text(
            'Quarter 3',
            style: TextStyle(fontSize: 12, color: textGray, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),

          _buildQuarterRow(
            initial: 'Jul',
            monthTitle: 'July 2026',
            transfers: '24 transfers • + 38,000.00',
            gross: 'PHP 42,000.00',
            net: '+ PHP 25.5k net',
            avatarBg: const Color(0xFF6200EA),
          ),
          const SizedBox(height: 10),
          _buildQuarterRow(
            initial: 'Aug',
            monthTitle: 'August 2026',
            transfers: '19 Transfers • + 38,000.00',
            gross: 'PHP 38,200.00',
            net: '+ PHP 13.8k net',
            avatarBg: const Color(0xFF9C27B0),
          ),

          const SizedBox(height: 16),

          const Text(
            'Quarter 2',
            style: TextStyle(fontSize: 12, color: textGray, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),

          _buildQuarterRow(
            initial: 'Jun',
            monthTitle: 'June 2026',
            transfers: '10 Transfers • + 38,000.00',
            gross: 'PHP 50,000.00',
            net: '+ PHP 15.2k net',
            avatarBg: const Color(0xFFBA68C8),
          ),
        ],
      ),
    );
  }

  Widget _buildQuarterRow({
    required String initial,
    required String monthTitle,
    required String transfers,
    required String gross,
    required String net,
    required Color avatarBg,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: avatarBg,
                child: Text(
                  initial,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      monthTitle,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: textDark),
                    ),
                    Text(
                      transfers,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, color: textGray),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              gross,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textDark),
            ),
            Text(
              net,
              style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: accentGreen),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTransactionItem({
    required Color avatarBg,
    required String initial,
    required String name,
    required String time,
    required String amount,
    required String status,
    required Color statusColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: avatarBg,
                child: Text(
                  initial,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: textDark),
                    ),
                    Text(
                      time,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, color: textGray),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              amount,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textDark),
            ),
            Text(
              status,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: statusColor),
            ),
          ],
        ),
      ],
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

  String _formatCompactK(double val) {
    if (val >= 1000) {
      return '${(val / 1000).toStringAsFixed(1)}k';
    }
    return val.toStringAsFixed(0);
  }
}

/// Custom painter for pointed transfer flow with pointed callout badges,
/// node vertices, vertical guideline scrubber, and smooth gradients.
class _PointedTransferFlowPainter extends CustomPainter {
  final List<FlowPointData> dataset;
  final double scrubFraction;
  final bool isMonthly;

  _PointedTransferFlowPainter({
    required this.dataset,
    required this.scrubFraction,
    required this.isMonthly,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    if (dataset.isEmpty || w <= 0 || h <= 0) return;

    const double paddingX = 24.0;
    const double paddingTop = 38.0; // Space for pointed callout badge above
    const double paddingBottom = 38.0; // Space for pointed callout badge below
    final usableW = w - (2 * paddingX);
    final usableH = h - paddingTop - paddingBottom;

    // Baseline axis
    final axisPaint = Paint()
      ..color = const Color(0xFFF3F4F6)
      ..strokeWidth = 1.0;
    canvas.drawLine(Offset(0, h - 8), Offset(w, h - 8), axisPaint);

    // Subtle horizontal grid guides
    final gridPaint = Paint()
      ..color = const Color(0xFFF9FAFB)
      ..strokeWidth = 1.0;
    canvas.drawLine(Offset(paddingX, paddingTop + usableH * 0.33), Offset(w - paddingX, paddingTop + usableH * 0.33), gridPaint);
    canvas.drawLine(Offset(paddingX, paddingTop + usableH * 0.66), Offset(w - paddingX, paddingTop + usableH * 0.66), gridPaint);

    final n = dataset.length;
    final xStep = n > 1 ? usableW / (n - 1) : 0.0;

    // Determine max value for normalization
    double maxVal = 10000.0;
    for (final p in dataset) {
      maxVal = math.max(maxVal, math.max(p.received, p.sent));
    }
    maxVal *= 1.25; // 25% overhead for visual breathing room

    // Compute coordinate points for Received (In, Green) and Sent (Out, Violet)
    // Exactly n points: 5 points for the 5 weeks in Monthly mode, 12 points for the 12 months in Yearly mode.
    // "kung ilan lang weeks yun lang yung spikes line"
    final greenPoints = <Offset>[];
    final violetPoints = <Offset>[];

    for (int i = 0; i < n; i++) {
      final x = paddingX + (i * xStep);
      final greenNorm = (dataset[i].received / maxVal).clamp(0.05, 0.95);
      final violetNorm = (dataset[i].sent / maxVal).clamp(0.05, 0.95);

      final yGreen = (paddingTop + usableH) - (greenNorm * usableH);
      final yViolet = (paddingTop + usableH) - (violetNorm * usableH);

      greenPoints.add(Offset(x, yGreen));
      violetPoints.add(Offset(x, yViolet));
    }

    // Build path:
    // For Monthly: draw clean straight pointed segments connecting the exact week vertices (5 weeks = 5 spikes)
    // For Yearly: retain smooth spline across the 12 months
    final greenPath = _buildPath(greenPoints, isMonthly: isMonthly);
    final violetPath = _buildPath(violetPoints, isMonthly: isMonthly);

    // 1. Draw subtle area gradients under curves
    final greenAreaPath = Path.from(greenPath)
      ..lineTo(greenPoints.last.dx, h - 8)
      ..lineTo(greenPoints.first.dx, h - 8)
      ..close();
    final greenShader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        const Color(0xFF2ECC71).withValues(alpha: 0.14),
        const Color(0xFF2ECC71).withValues(alpha: 0.0),
      ],
    ).createShader(Rect.fromLTWH(0, paddingTop, w, usableH));
    canvas.drawPath(greenAreaPath, Paint()..shader = greenShader);

    final violetAreaPath = Path.from(violetPath)
      ..lineTo(violetPoints.last.dx, h - 8)
      ..lineTo(violetPoints.first.dx, h - 8)
      ..close();
    final violetShader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        const Color(0xFF5E17EB).withValues(alpha: 0.12),
        const Color(0xFF5E17EB).withValues(alpha: 0.0),
      ],
    ).createShader(Rect.fromLTWH(0, paddingTop, w, usableH));
    canvas.drawPath(violetAreaPath, Paint()..shader = violetShader);

    // 2. Draw Main Spline / Line Strokes
    final greenStrokePaint = Paint()
      ..color = const Color(0xFF2ECC71)
      ..strokeWidth = 2.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(greenPath, greenStrokePaint);

    final violetStrokePaint = Paint()
      ..color = const Color(0xFF5E17EB)
      ..strokeWidth = 2.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(violetPath, violetStrokePaint);

    // 3. Draw All Pointed Vertices / Nodes on both lines (exactly 1 per week / month)
    final greenNodePaint = Paint()
      ..color = const Color(0xFF2ECC71)
      ..style = PaintingStyle.fill;
    final violetNodePaint = Paint()
      ..color = const Color(0xFF5E17EB)
      ..style = PaintingStyle.fill;
    final whiteInnerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    for (int i = 0; i < greenPoints.length; i++) {
      // Received vertex
      canvas.drawCircle(greenPoints[i], 4.5, greenNodePaint);
      canvas.drawCircle(greenPoints[i], 2.2, whiteInnerPaint);

      // Sent vertex
      canvas.drawCircle(violetPoints[i], 4.5, violetNodePaint);
      canvas.drawCircle(violetPoints[i], 2.2, whiteInnerPaint);
    }

    // 4. Calculate Interpolated Active Scrubber Coordinates
    final scrubClamped = scrubFraction.clamp(0.0, (n - 1).toDouble());
    final lowerIdx = scrubClamped.floor().clamp(0, n - 1);
    final upperIdx = math.min(lowerIdx + 1, n - 1);
    final t = scrubClamped - lowerIdx;

    final scrubX = paddingX + (scrubClamped * xStep);
    final activeGreenY = _lerpDouble(greenPoints[lowerIdx].dy, greenPoints[upperIdx].dy, t);
    final activeVioletY = _lerpDouble(violetPoints[lowerIdx].dy, violetPoints[upperIdx].dy, t);

    // 5. Vertical Dashed Guideline Scrubber through active point
    final guidePaint = Paint()
      ..color = const Color(0xFF5E17EB).withValues(alpha: 0.35)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    _drawDashedVerticalLine(canvas, scrubX, 10, h - 8, guidePaint);

    // 6. Glowing Halos on the Active Nodes
    // Active Green Vertex Halo
    final greenHaloPaint = Paint()
      ..color = const Color(0xFF2ECC71).withValues(alpha: 0.28)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(scrubX, activeGreenY), 10.0, greenHaloPaint);
    canvas.drawCircle(Offset(scrubX, activeGreenY), 5.5, greenNodePaint);
    canvas.drawCircle(Offset(scrubX, activeGreenY), 2.5, whiteInnerPaint);

    // Active Violet Vertex Halo
    final violetHaloPaint = Paint()
      ..color = const Color(0xFF5E17EB).withValues(alpha: 0.28)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(scrubX, activeVioletY), 10.0, violetHaloPaint);
    canvas.drawCircle(Offset(scrubX, activeVioletY), 5.5, violetNodePaint);
    canvas.drawCircle(Offset(scrubX, activeVioletY), 2.5, whiteInnerPaint);

    // 7. Interpolate Values for Callout Tooltips
    final activeRecVal = _lerpDouble(dataset[lowerIdx].received, dataset[upperIdx].received, t);
    final activeSentVal = _lerpDouble(dataset[lowerIdx].sent, dataset[upperIdx].sent, t);

    final greenText = '+${_formatCompactK(activeRecVal)} In';
    final violetText = '-${_formatCompactK(activeSentVal)} Out';

    // 8. Render Pointed Callout Badges with Triangle Carets
    // Green Callout (Pointing Down to Green Vertex)
    _drawPointedBadge(
      canvas: canvas,
      targetX: scrubX,
      targetY: activeGreenY,
      text: greenText,
      bgColor: const Color(0xFF10B981),
      textColor: Colors.white,
      pointingDown: true, // Caret points down to vertex
      canvasWidth: w,
    );

    // Violet Callout (Pointing Up to Violet Vertex)
    _drawPointedBadge(
      canvas: canvas,
      targetX: scrubX,
      targetY: activeVioletY,
      text: violetText,
      bgColor: const Color(0xFF380084),
      textColor: Colors.white,
      pointingDown: false, // Caret points up to vertex
      canvasWidth: w,
    );
  }

  void _drawPointedBadge({
    required Canvas canvas,
    required double targetX,
    required double targetY,
    required String text,
    required Color bgColor,
    required Color textColor,
    required bool pointingDown,
    required double canvasWidth,
  }) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w800,
          fontSize: 10.5,
          letterSpacing: 0.2,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    const double hPadding = 8.0;
    const double vPadding = 4.0;
    const double caretH = 5.0;
    const double caretW = 8.0;

    final badgeW = textPainter.width + (2 * hPadding);
    final badgeH = textPainter.height + (2 * vPadding);

    // Clamp badge body x so it doesn't clip screen boundaries
    final clampedBadgeX = (targetX - (badgeW / 2)).clamp(6.0, canvasWidth - badgeW - 6.0);

    final badgeY = pointingDown
        ? (targetY - caretH - badgeH - 4.0) // Positioned above vertex
        : (targetY + caretH + 4.0); // Positioned below vertex

    // Draw Drop Shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.12)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);
    final badgeRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(clampedBadgeX, badgeY, badgeW, badgeH),
      const Radius.circular(7.0),
    );
    canvas.drawRRect(badgeRRect, shadowPaint);

    // Draw Main Badge Background
    final bgPaint = Paint()..color = bgColor;
    canvas.drawRRect(badgeRRect, bgPaint);

    // Draw Pointed Caret Triangle pointing to vertex target
    final caretPath = Path();
    if (pointingDown) {
      // Caret base at bottom of badge, point at (targetX, targetY - 4)
      caretPath.moveTo(targetX - (caretW / 2), badgeY + badgeH);
      caretPath.lineTo(targetX + (caretW / 2), badgeY + badgeH);
      caretPath.lineTo(targetX, targetY - 4.0);
      caretPath.close();
    } else {
      // Caret base at top of badge, point at (targetX, targetY + 4)
      caretPath.moveTo(targetX - (caretW / 2), badgeY);
      caretPath.lineTo(targetX + (caretW / 2), badgeY);
      caretPath.lineTo(targetX, targetY + 4.0);
      caretPath.close();
    }
    canvas.drawPath(caretPath, bgPaint);

    // Paint Text
    textPainter.paint(
      canvas,
      Offset(clampedBadgeX + hPadding, badgeY + vPadding),
    );
  }

  Path _buildPath(List<Offset> points, {required bool isMonthly}) {
    final path = Path();
    if (points.isEmpty) return path;
    if (isMonthly) {
      // Connect exactly the week points with straight segments, producing crisp pointed spikes at each week
      // (kung ilan lang ang weeks, yun lang ang spikes line)
      path.moveTo(points.first.dx, points.first.dy);
      for (int i = 1; i < points.length; i++) {
        path.lineTo(points[i].dx, points[i].dy);
      }
      return path;
    } else {
      return _buildSmoothSpline(points, tensionDivisor: 6.5);
    }
  }

  Path _buildSmoothSpline(List<Offset> points, {double tensionDivisor = 6.0}) {
    final path = Path();
    if (points.isEmpty) return path;
    path.moveTo(points.first.dx, points.first.dy);

    for (int i = 0; i < points.length - 1; i++) {
      final p0 = i > 0 ? points[i - 1] : points[i];
      final p1 = points[i];
      final p2 = points[i + 1];
      final p3 = i < points.length - 2 ? points[i + 2] : p2;

      // Catmull-Rom with tighter tension for spiky peaks
      final cp1x = p1.dx + (p2.dx - p0.dx) / tensionDivisor;
      final cp1y = p1.dy + (p2.dy - p0.dy) / tensionDivisor;
      final cp2x = p2.dx - (p3.dx - p1.dx) / tensionDivisor;
      final cp2y = p2.dy - (p3.dy - p1.dy) / tensionDivisor;

      path.cubicTo(cp1x, cp1y, cp2x, cp2y, p2.dx, p2.dy);
    }
    return path;
  }

  void _drawDashedVerticalLine(
    Canvas canvas,
    double x,
    double startY,
    double endY,
    Paint paint,
  ) {
    const double dashHeight = 4.0;
    const double dashSpace = 3.0;
    double currentY = startY;

    while (currentY < endY) {
      canvas.drawLine(
        Offset(x, currentY),
        Offset(x, math.min(currentY + dashHeight, endY)),
        paint,
      );
      currentY += dashHeight + dashSpace;
    }
  }

  double _lerpDouble(double a, double b, double t) => a + (b - a) * t;

  String _formatCompactK(double val) {
    if (val >= 1000) {
      return '${(val / 1000).toStringAsFixed(1)}k';
    }
    return val.toStringAsFixed(0);
  }

  @override
  bool shouldRepaint(covariant _PointedTransferFlowPainter oldDelegate) {
    return oldDelegate.scrubFraction != scrubFraction ||
        oldDelegate.isMonthly != isMonthly ||
        oldDelegate.dataset != dataset;
  }
}
