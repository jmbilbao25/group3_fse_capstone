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

/// Model for a calendar month containing its weekly flow points
class MonthFlowData {
  final String monthName;
  final String shortName;
  final int monthIndex;
  final List<FlowPointData> weeks;

  const MonthFlowData({
    required this.monthName,
    required this.shortName,
    required this.monthIndex,
    required this.weeks,
  });
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
  int _selectedMonthOfYear = 9; // Defaults to October 2026 (Index 9 in Jan..Dec)
  int _selectedWeekIndex = 3; // Defaults to Week 4 (matches Page 11 design)
  int _selectedMonthIndex = 3; // Defaults to April in Yearly mode
  int _selectedYear = 2026; // Defaults to 2026 (options: 2026, 2025)
  int _selectedQuarterIndex = 0; // 0 = All (12M), 1 = Q1, 2 = Q2, 3 = Q3, 4 = Q4
  bool _showAllTotals = false;

  late AnimationController _animController;
  late Animation<double> _scrubAnimation;
  double _currentScrubFraction = 3.0; // Current floating position in index space

  static const Color brandViolet = AuraColors.primary;
  static const Color accentGreen = AuraColors.creditGreen;
  static const Color lightGreen = Color(0xFF10B981);
  static const Color textDark = AuraColors.textPrimary;
  static const Color textGray = AuraColors.textMuted;

  // Catalog of all 12 Months in 2026 with weekly data
  late final List<MonthFlowData> _monthsCatalog;

  // Yearly Datasets
  late final List<FlowPointData> _yearlyMonths2026;
  late final List<FlowPointData> _yearlyMonths2025;

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
    // 12 Months Catalog for 2026 with realistic weekly breakdown
    _monthsCatalog = [
      MonthFlowData(
        monthName: 'January 2026',
        shortName: 'Jan',
        monthIndex: 0,
        weeks: [
          FlowPointData(
            label: 'Week 1',
            shortLabel: 'W1',
            dateSubtitle: 'Jan 01 - Jan 07, 2026',
            received: 8000.0,
            sent: 18000.0,
            inTransfers: 1,
            outTransfers: 3,
            transactions: const [
              AnalyticsTxItem(name: 'Annual Software License', initial: 'S', avatarBg: Color(0xFF3949AB), time: 'Jan 03, 11:30 am', amount: 12000.0, isReceived: false),
              AnalyticsTxItem(name: 'Client Retainer', initial: 'C', avatarBg: Color(0xFF00897B), time: 'Jan 05, 2:15 pm', amount: 8000.0, isReceived: true, status: 'RECEIVED'),
              AnalyticsTxItem(name: 'Office Supplies', initial: 'O', avatarBg: Color(0xFFE65100), time: 'Jan 06, 4:00 pm', amount: 6000.0, isReceived: false),
            ],
          ),
          FlowPointData(
            label: 'Week 2',
            shortLabel: 'W2',
            dateSubtitle: 'Jan 08 - Jan 14, 2026',
            received: 10000.0,
            sent: 15000.0,
            inTransfers: 2,
            outTransfers: 2,
            transactions: const [
              AnalyticsTxItem(name: 'Direct Credit', initial: 'D', avatarBg: Color(0xFF5E17EB), time: 'Jan 10, 10:00 am', amount: 10000.0, isReceived: true, status: 'RECEIVED'),
              AnalyticsTxItem(name: 'Operational Expenses', initial: 'O', avatarBg: Color(0xFFD81B60), time: 'Jan 12, 1:45 pm', amount: 15000.0, isReceived: false),
            ],
          ),
          FlowPointData(
            label: 'Week 3',
            shortLabel: 'W3',
            dateSubtitle: 'Jan 15 - Jan 21, 2026',
            received: 12000.0,
            sent: 22000.0,
            inTransfers: 1,
            outTransfers: 4,
            transactions: const [
              AnalyticsTxItem(name: 'Consultancy Inward', initial: 'C', avatarBg: Color(0xFF2ECC71), time: 'Jan 18, 9:20 am', amount: 12000.0, isReceived: true, status: 'RECEIVED'),
              AnalyticsTxItem(name: 'Marketing Campaign', initial: 'M', avatarBg: Color(0xFF8E24AA), time: 'Jan 19, 3:30 pm', amount: 22000.0, isReceived: false),
            ],
          ),
          FlowPointData(
            label: 'Week 4',
            shortLabel: 'W4',
            dateSubtitle: 'Jan 22 - Jan 31, 2026',
            received: 15000.0,
            sent: 19000.0,
            inTransfers: 2,
            outTransfers: 3,
            transactions: const [
              AnalyticsTxItem(name: 'Direct Settlement', initial: 'S', avatarBg: Color(0xFF00ACC1), time: 'Jan 25, 2:00 pm', amount: 15000.0, isReceived: true, status: 'RECEIVED'),
              AnalyticsTxItem(name: 'Interbank Clearing', initial: 'I', avatarBg: Color(0xFFE53935), time: 'Jan 28, 5:15 pm', amount: 19000.0, isReceived: false),
            ],
          ),
        ],
      ),
      MonthFlowData(
        monthName: 'February 2026',
        shortName: 'Feb',
        monthIndex: 1,
        weeks: [
          FlowPointData(
            label: 'Week 1',
            shortLabel: 'W1',
            dateSubtitle: 'Feb 01 - Feb 07, 2026',
            received: 14000.0,
            sent: 11000.0,
            inTransfers: 1,
            outTransfers: 2,
            transactions: const [
              AnalyticsTxItem(name: 'Consulting Honorarium', initial: 'C', avatarBg: Color(0xFF7C4DFF), time: 'Feb 03, 10:15 am', amount: 14000.0, isReceived: true, status: 'RECEIVED'),
              AnalyticsTxItem(name: 'Other Bank Transfer', initial: 'O', avatarBg: Color(0xFFE65100), time: 'Feb 05, 3:20 pm', amount: 11000.0, isReceived: false),
            ],
          ),
          FlowPointData(
            label: 'Week 2',
            shortLabel: 'W2',
            dateSubtitle: 'Feb 08 - Feb 14, 2026',
            received: 18000.0,
            sent: 16000.0,
            inTransfers: 2,
            outTransfers: 3,
            transactions: const [
              AnalyticsTxItem(name: 'Commercial Inward', initial: 'M', avatarBg: Color(0xFF00897B), time: 'Feb 10, 1:15 pm', amount: 18000.0, isReceived: true, status: 'RECEIVED'),
              AnalyticsTxItem(name: 'Supplier Settlement', initial: 'S', avatarBg: Color(0xFF3949AB), time: 'Feb 12, 4:40 pm', amount: 16000.0, isReceived: false),
            ],
          ),
          FlowPointData(
            label: 'Week 3',
            shortLabel: 'W3',
            dateSubtitle: 'Feb 15 - Feb 21, 2026',
            received: 20000.0,
            sent: 12000.0,
            inTransfers: 1,
            outTransfers: 2,
            transactions: const [
              AnalyticsTxItem(name: 'Direct Wire', initial: 'W', avatarBg: Color(0xFF5E17EB), time: 'Feb 17, 11:00 am', amount: 20000.0, isReceived: true, status: 'RECEIVED'),
              AnalyticsTxItem(name: 'Software Upgrade', initial: 'S', avatarBg: Color(0xFFD81B60), time: 'Feb 19, 2:50 pm', amount: 12000.0, isReceived: false),
            ],
          ),
          FlowPointData(
            label: 'Week 4',
            shortLabel: 'W4',
            dateSubtitle: 'Feb 22 - Feb 28, 2026',
            received: 15000.0,
            sent: 13000.0,
            inTransfers: 1,
            outTransfers: 2,
            transactions: const [
              AnalyticsTxItem(name: 'Service Deposit', initial: 'S', avatarBg: Color(0xFF2ECC71), time: 'Feb 24, 9:30 am', amount: 15000.0, isReceived: true, status: 'RECEIVED'),
              AnalyticsTxItem(name: 'Facility Lease', initial: 'F', avatarBg: Color(0xFF8E24AA), time: 'Feb 27, 4:10 pm', amount: 13000.0, isReceived: false),
            ],
          ),
        ],
      ),
      MonthFlowData(
        monthName: 'March 2026',
        shortName: 'Mar',
        monthIndex: 2,
        weeks: [
          FlowPointData(
            label: 'Week 1',
            shortLabel: 'W1',
            dateSubtitle: 'Mar 01 - Mar 07, 2026',
            received: 8000.0,
            sent: 16000.0,
            inTransfers: 1,
            outTransfers: 3,
            transactions: const [
              AnalyticsTxItem(name: 'Apex Digital Wire', initial: 'A', avatarBg: Color(0xFF047857), time: 'Mar 04, 11:20 am', amount: 8000.0, isReceived: true, status: 'RECEIVED'),
              AnalyticsTxItem(name: 'Q1 Compliance Filing', initial: 'C', avatarBg: Color(0xFFE65100), time: 'Mar 06, 2:10 pm', amount: 16000.0, isReceived: false),
            ],
          ),
          FlowPointData(
            label: 'Week 2',
            shortLabel: 'W2',
            dateSubtitle: 'Mar 08 - Mar 14, 2026',
            received: 12000.0,
            sent: 21000.0,
            inTransfers: 1,
            outTransfers: 3,
            transactions: const [
              AnalyticsTxItem(name: 'Project Payout', initial: 'P', avatarBg: Color(0xFF5E17EB), time: 'Mar 11, 1:45 pm', amount: 12000.0, isReceived: true, status: 'RECEIVED'),
              AnalyticsTxItem(name: 'Marketing Campaign', initial: 'M', avatarBg: Color(0xFF3949AB), time: 'Mar 13, 3:30 pm', amount: 21000.0, isReceived: false),
            ],
          ),
          FlowPointData(
            label: 'Week 3',
            shortLabel: 'W3',
            dateSubtitle: 'Mar 15 - Mar 21, 2026',
            received: 15000.0,
            sent: 18000.0,
            inTransfers: 1,
            outTransfers: 2,
            transactions: const [
              AnalyticsTxItem(name: 'Client Honorarium', initial: 'C', avatarBg: Color(0xFF00897B), time: 'Mar 18, 10:00 am', amount: 15000.0, isReceived: true, status: 'RECEIVED'),
              AnalyticsTxItem(name: 'Server Infrastructure', initial: 'S', avatarBg: Color(0xFFD81B60), time: 'Mar 20, 4:15 pm', amount: 18000.0, isReceived: false),
            ],
          ),
          FlowPointData(
            label: 'Week 4',
            shortLabel: 'W4',
            dateSubtitle: 'Mar 22 - Mar 31, 2026',
            received: 10000.0,
            sent: 14000.0,
            inTransfers: 1,
            outTransfers: 2,
            transactions: const [
              AnalyticsTxItem(name: 'Settlement Credit', initial: 'S', avatarBg: Color(0xFF2ECC71), time: 'Mar 25, 2:20 pm', amount: 10000.0, isReceived: true, status: 'RECEIVED'),
              AnalyticsTxItem(name: 'Office Maintenance', initial: 'O', avatarBg: Color(0xFF8E24AA), time: 'Mar 29, 5:00 pm', amount: 14000.0, isReceived: false),
            ],
          ),
        ],
      ),
      MonthFlowData(
        monthName: 'April 2026',
        shortName: 'Apr',
        monthIndex: 3,
        weeks: [
          FlowPointData(
            label: 'Week 1',
            shortLabel: 'W1',
            dateSubtitle: 'Apr 01 - Apr 07, 2026',
            received: 25000.0,
            sent: 8000.0,
            inTransfers: 2,
            outTransfers: 1,
            transactions: const [
              AnalyticsTxItem(name: 'Enterprise Contract', initial: 'E', avatarBg: Color(0xFF5E17EB), time: 'Apr 03, 9:45 am', amount: 25000.0, isReceived: true, status: 'RECEIVED'),
              AnalyticsTxItem(name: 'Cloud Maintenance', initial: 'C', avatarBg: Color(0xFFE65100), time: 'Apr 05, 3:30 pm', amount: 8000.0, isReceived: false),
            ],
          ),
          FlowPointData(
            label: 'Week 2',
            shortLabel: 'W2',
            dateSubtitle: 'Apr 08 - Apr 14, 2026',
            received: 32000.0,
            sent: 14000.0,
            inTransfers: 2,
            outTransfers: 2,
            transactions: const [
              AnalyticsTxItem(name: 'Partner Bank Settlement', initial: 'P', avatarBg: Color(0xFF00897B), time: 'Apr 10, 11:15 am', amount: 32000.0, isReceived: true, status: 'RECEIVED'),
              AnalyticsTxItem(name: 'Vendor Clearing', initial: 'V', avatarBg: Color(0xFF3949AB), time: 'Apr 12, 2:40 pm', amount: 14000.0, isReceived: false),
            ],
          ),
          FlowPointData(
            label: 'Week 3',
            shortLabel: 'W3',
            dateSubtitle: 'Apr 15 - Apr 21, 2026',
            received: 18000.0,
            sent: 6500.0,
            inTransfers: 1,
            outTransfers: 1,
            transactions: const [
              AnalyticsTxItem(name: 'Project Milestone B', initial: 'P', avatarBg: Color(0xFF2ECC71), time: 'Apr 17, 10:20 am', amount: 18000.0, isReceived: true, status: 'RECEIVED'),
              AnalyticsTxItem(name: 'Other Bank Transfer', initial: 'O', avatarBg: Color(0xFFD81B60), time: 'Apr 19, 4:10 pm', amount: 6500.0, isReceived: false),
            ],
          ),
          FlowPointData(
            label: 'Week 4',
            shortLabel: 'W4',
            dateSubtitle: 'Apr 22 - Apr 30, 2026',
            received: 28500.0,
            sent: 12000.0,
            inTransfers: 2,
            outTransfers: 2,
            transactions: const [
              AnalyticsTxItem(name: 'Retainer Inflow', initial: 'R', avatarBg: Color(0xFF8E24AA), time: 'Apr 25, 1:30 pm', amount: 28500.0, isReceived: true, status: 'RECEIVED'),
              AnalyticsTxItem(name: 'Facility Lease Share', initial: 'F', avatarBg: Color(0xFF00ACC1), time: 'Apr 28, 5:00 pm', amount: 12000.0, isReceived: false),
            ],
          ),
        ],
      ),
      MonthFlowData(
        monthName: 'May 2026',
        shortName: 'May',
        monthIndex: 4,
        weeks: [
          FlowPointData(
            label: 'Week 1',
            shortLabel: 'W1',
            dateSubtitle: 'May 01 - May 07, 2026',
            received: 9000.0,
            sent: 12000.0,
            inTransfers: 1,
            outTransfers: 2,
            transactions: const [
              AnalyticsTxItem(name: 'Advisory Inflow', initial: 'A', avatarBg: Color(0xFF7C4DFF), time: 'May 03, 11:00 am', amount: 9000.0, isReceived: true, status: 'RECEIVED'),
              AnalyticsTxItem(name: 'Office Supplies', initial: 'O', avatarBg: Color(0xFFE65100), time: 'May 05, 2:15 pm', amount: 12000.0, isReceived: false),
            ],
          ),
          FlowPointData(
            label: 'Week 2',
            shortLabel: 'W2',
            dateSubtitle: 'May 08 - May 14, 2026',
            received: 14000.0,
            sent: 10000.0,
            inTransfers: 1,
            outTransfers: 1,
            transactions: const [
              AnalyticsTxItem(name: 'Client Deposit', initial: 'C', avatarBg: Color(0xFF00897B), time: 'May 11, 10:45 am', amount: 14000.0, isReceived: true, status: 'RECEIVED'),
              AnalyticsTxItem(name: 'Logistics Fee', initial: 'L', avatarBg: Color(0xFF3949AB), time: 'May 13, 3:30 pm', amount: 10000.0, isReceived: false),
            ],
          ),
          FlowPointData(
            label: 'Week 3',
            shortLabel: 'W3',
            dateSubtitle: 'May 15 - May 21, 2026',
            received: 22000.0,
            sent: 25000.0,
            inTransfers: 2,
            outTransfers: 3,
            transactions: const [
              AnalyticsTxItem(name: 'Settlement Inward', initial: 'S', avatarBg: Color(0xFF5E17EB), time: 'May 18, 1:20 pm', amount: 22000.0, isReceived: true, status: 'RECEIVED'),
              AnalyticsTxItem(name: 'Equipment Maintenance', initial: 'E', avatarBg: Color(0xFFD81B60), time: 'May 20, 4:50 pm', amount: 25000.0, isReceived: false),
            ],
          ),
          FlowPointData(
            label: 'Week 4',
            shortLabel: 'W4',
            dateSubtitle: 'May 22 - May 31, 2026',
            received: 16000.0,
            sent: 13000.0,
            inTransfers: 1,
            outTransfers: 2,
            transactions: const [
              AnalyticsTxItem(name: 'Contract Payout', initial: 'C', avatarBg: Color(0xFF2ECC71), time: 'May 26, 11:30 am', amount: 16000.0, isReceived: true, status: 'RECEIVED'),
              AnalyticsTxItem(name: 'Rent Allocation', initial: 'R', avatarBg: Color(0xFF8E24AA), time: 'May 29, 2:10 pm', amount: 13000.0, isReceived: false),
            ],
          ),
        ],
      ),
      MonthFlowData(
        monthName: 'June 2026',
        shortName: 'Jun',
        monthIndex: 5,
        weeks: [
          FlowPointData(
            label: 'Week 1',
            shortLabel: 'W1',
            dateSubtitle: 'Jun 01 - Jun 07, 2026',
            received: 12000.0,
            sent: 15000.0,
            inTransfers: 1,
            outTransfers: 2,
            transactions: const [
              AnalyticsTxItem(name: 'Inward Wire', initial: 'I', avatarBg: Color(0xFF00ACC1), time: 'Jun 04, 10:15 am', amount: 12000.0, isReceived: true, status: 'RECEIVED'),
              AnalyticsTxItem(name: 'Software Licensing', initial: 'S', avatarBg: Color(0xFFE65100), time: 'Jun 06, 3:45 pm', amount: 15000.0, isReceived: false),
            ],
          ),
          FlowPointData(
            label: 'Week 2',
            shortLabel: 'W2',
            dateSubtitle: 'Jun 08 - Jun 14, 2026',
            received: 28000.0,
            sent: 12500.0,
            inTransfers: 2,
            outTransfers: 2,
            transactions: const [
              AnalyticsTxItem(name: 'Apex Digital Wire', initial: 'A', avatarBg: Color(0xFF047857), time: 'Jun 10, 1:30 pm', amount: 28000.0, isReceived: true, status: 'RECEIVED'),
              AnalyticsTxItem(name: 'Supplier Order', initial: 'S', avatarBg: Color(0xFF3949AB), time: 'Jun 12, 4:20 pm', amount: 12500.0, isReceived: false),
            ],
          ),
          FlowPointData(
            label: 'Week 3',
            shortLabel: 'W3',
            dateSubtitle: 'Jun 15 - Jun 21, 2026',
            received: 14000.0,
            sent: 18000.0,
            inTransfers: 1,
            outTransfers: 2,
            transactions: const [
              AnalyticsTxItem(name: 'Service Fee', initial: 'S', avatarBg: Color(0xFF5E17EB), time: 'Jun 17, 11:10 am', amount: 14000.0, isReceived: true, status: 'RECEIVED'),
              AnalyticsTxItem(name: 'Insurance Premium', initial: 'I', avatarBg: Color(0xFFD81B60), time: 'Jun 19, 2:50 pm', amount: 18000.0, isReceived: false),
            ],
          ),
          FlowPointData(
            label: 'Week 4',
            shortLabel: 'W4',
            dateSubtitle: 'Jun 22 - Jun 30, 2026',
            received: 19000.0,
            sent: 16500.0,
            inTransfers: 1,
            outTransfers: 2,
            transactions: const [
              AnalyticsTxItem(name: 'Professional Fee', initial: 'P', avatarBg: Color(0xFF2ECC71), time: 'Jun 25, 9:40 am', amount: 19000.0, isReceived: true, status: 'RECEIVED'),
              AnalyticsTxItem(name: 'Same Bank Transfer', initial: 'S', avatarBg: Color(0xFF8E24AA), time: 'Jun 28, 5:15 pm', amount: 16500.0, isReceived: false),
            ],
          ),
        ],
      ),
      MonthFlowData(
        monthName: 'July 2026',
        shortName: 'Jul',
        monthIndex: 6,
        weeks: [
          FlowPointData(
            label: 'Week 1',
            shortLabel: 'W1',
            dateSubtitle: 'Jul 01 - Jul 07, 2026',
            received: 10000.0,
            sent: 8000.0,
            inTransfers: 1,
            outTransfers: 1,
            transactions: const [
              AnalyticsTxItem(name: 'Inward Remittance', initial: 'I', avatarBg: Color(0xFF7C4DFF), time: 'Jul 03, 10:30 am', amount: 10000.0, isReceived: true, status: 'RECEIVED'),
              AnalyticsTxItem(name: 'Interbank Transfer', initial: 'I', avatarBg: Color(0xFFE65100), time: 'Jul 06, 2:15 pm', amount: 8000.0, isReceived: false),
            ],
          ),
          FlowPointData(
            label: 'Week 2',
            shortLabel: 'W2',
            dateSubtitle: 'Jul 08 - Jul 14, 2026',
            received: 16000.0,
            sent: 19000.0,
            inTransfers: 1,
            outTransfers: 3,
            transactions: const [
              AnalyticsTxItem(name: 'Service Contract', initial: 'S', avatarBg: Color(0xFF00897B), time: 'Jul 10, 1:45 pm', amount: 16000.0, isReceived: true, status: 'RECEIVED'),
              AnalyticsTxItem(name: 'Hardware Maintenance', initial: 'H', avatarBg: Color(0xFF3949AB), time: 'Jul 12, 4:30 pm', amount: 19000.0, isReceived: false),
            ],
          ),
          FlowPointData(
            label: 'Week 3',
            shortLabel: 'W3',
            dateSubtitle: 'Jul 15 - Jul 21, 2026',
            received: 21000.0,
            sent: 14000.0,
            inTransfers: 2,
            outTransfers: 2,
            transactions: const [
              AnalyticsTxItem(name: 'Commercial Inflow', initial: 'C', avatarBg: Color(0xFF5E17EB), time: 'Jul 17, 11:20 am', amount: 21000.0, isReceived: true, status: 'RECEIVED'),
              AnalyticsTxItem(name: 'Office Supplies', initial: 'O', avatarBg: Color(0xFFD81B60), time: 'Jul 19, 3:15 pm', amount: 14000.0, isReceived: false),
            ],
          ),
          FlowPointData(
            label: 'Week 4',
            shortLabel: 'W4',
            dateSubtitle: 'Jul 22 - Jul 31, 2026',
            received: 25000.0,
            sent: 11000.0,
            inTransfers: 2,
            outTransfers: 1,
            transactions: const [
              AnalyticsTxItem(name: 'Retainer Payment', initial: 'R', avatarBg: Color(0xFF2ECC71), time: 'Jul 26, 10:00 am', amount: 25000.0, isReceived: true, status: 'RECEIVED'),
              AnalyticsTxItem(name: 'Supplier Transfer', initial: 'S', avatarBg: Color(0xFF8E24AA), time: 'Jul 29, 4:45 pm', amount: 11000.0, isReceived: false),
            ],
          ),
        ],
      ),
      MonthFlowData(
        monthName: 'August 2026',
        shortName: 'Aug',
        monthIndex: 7,
        weeks: [
          FlowPointData(
            label: 'Week 1',
            shortLabel: 'W1',
            dateSubtitle: 'Aug 01 - Aug 07, 2026',
            received: 18000.0,
            sent: 11000.0,
            inTransfers: 1,
            outTransfers: 2,
            transactions: const [
              AnalyticsTxItem(name: 'Project Milestone', initial: 'P', avatarBg: Color(0xFF00ACC1), time: 'Aug 03, 11:15 am', amount: 18000.0, isReceived: true, status: 'RECEIVED'),
              AnalyticsTxItem(name: 'Internet Fiber', initial: 'I', avatarBg: Color(0xFFE65100), time: 'Aug 05, 3:20 pm', amount: 11000.0, isReceived: false),
            ],
          ),
          FlowPointData(
            label: 'Week 2',
            shortLabel: 'W2',
            dateSubtitle: 'Aug 08 - Aug 14, 2026',
            received: 9500.0,
            sent: 20500.0,
            inTransfers: 1,
            outTransfers: 3,
            transactions: const [
              AnalyticsTxItem(name: 'Apex Digital Transfer', initial: 'A', avatarBg: Color(0xFF047857), time: 'Aug 10, 10:45 am', amount: 9500.0, isReceived: true, status: 'RECEIVED'),
              AnalyticsTxItem(name: 'Vendor Payout', initial: 'V', avatarBg: Color(0xFF3949AB), time: 'Aug 12, 2:50 pm', amount: 20500.0, isReceived: false),
            ],
          ),
          FlowPointData(
            label: 'Week 3',
            shortLabel: 'W3',
            dateSubtitle: 'Aug 15 - Aug 21, 2026',
            received: 34000.0,
            sent: 15000.0,
            inTransfers: 2,
            outTransfers: 2,
            transactions: const [
              AnalyticsTxItem(name: 'Customer Wire Settlement', initial: 'C', avatarBg: Color(0xFF5E17EB), time: 'Aug 17, 1:15 pm', amount: 34000.0, isReceived: true, status: 'RECEIVED'),
              AnalyticsTxItem(name: 'Cloud Hosting Subscription', initial: 'C', avatarBg: Color(0xFFD81B60), time: 'Aug 19, 4:10 pm', amount: 15000.0, isReceived: false),
            ],
          ),
          FlowPointData(
            label: 'Week 4',
            shortLabel: 'W4',
            dateSubtitle: 'Aug 22 - Aug 31, 2026',
            received: 12500.0,
            sent: 16500.0,
            inTransfers: 1,
            outTransfers: 2,
            transactions: const [
              AnalyticsTxItem(name: 'Consultation Fee', initial: 'C', avatarBg: Color(0xFF2ECC71), time: 'Aug 25, 9:30 am', amount: 12500.0, isReceived: true, status: 'RECEIVED'),
              AnalyticsTxItem(name: 'Operational Expenses', initial: 'O', avatarBg: Color(0xFF8E24AA), time: 'Aug 28, 5:00 pm', amount: 16500.0, isReceived: false),
            ],
          ),
        ],
      ),
      MonthFlowData(
        monthName: 'September 2026',
        shortName: 'Sep',
        monthIndex: 8,
        weeks: [
          FlowPointData(
            label: 'Week 1',
            shortLabel: 'W1',
            dateSubtitle: 'Sep 01 - Sep 07, 2026',
            received: 14000.0,
            sent: 9500.0,
            inTransfers: 1,
            outTransfers: 2,
            transactions: const [
              AnalyticsTxItem(name: 'Client Retainer', initial: 'C', avatarBg: Color(0xFF7C4DFF), time: 'Sep 03, 10:15 am', amount: 14000.0, isReceived: true, status: 'RECEIVED'),
              AnalyticsTxItem(name: 'Software Licenses', initial: 'S', avatarBg: Color(0xFFE65100), time: 'Sep 05, 3:30 pm', amount: 9500.0, isReceived: false),
            ],
          ),
          FlowPointData(
            label: 'Week 2',
            shortLabel: 'W2',
            dateSubtitle: 'Sep 08 - Sep 14, 2026',
            received: 22500.0,
            sent: 18000.0,
            inTransfers: 2,
            outTransfers: 3,
            transactions: const [
              AnalyticsTxItem(name: 'MeyBank Inward Clearing', initial: 'M', avatarBg: Color(0xFF701A75), time: 'Sep 10, 1:40 pm', amount: 22500.0, isReceived: true, status: 'RECEIVED'),
              AnalyticsTxItem(name: 'Supplier Clearing Payout', initial: 'S', avatarBg: Color(0xFF3949AB), time: 'Sep 12, 4:15 pm', amount: 18000.0, isReceived: false),
            ],
          ),
          FlowPointData(
            label: 'Week 3',
            shortLabel: 'W3',
            dateSubtitle: 'Sep 15 - Sep 21, 2026',
            received: 16000.0,
            sent: 24500.0,
            inTransfers: 1,
            outTransfers: 4,
            transactions: const [
              AnalyticsTxItem(name: 'Direct Settlement', initial: 'D', avatarBg: Color(0xFF00897B), time: 'Sep 17, 11:20 am', amount: 16000.0, isReceived: true, status: 'RECEIVED'),
              AnalyticsTxItem(name: 'Office Equipment Refresh', initial: 'O', avatarBg: Color(0xFF5E17EB), time: 'Sep 19, 2:50 pm', amount: 24500.0, isReceived: false),
            ],
          ),
          FlowPointData(
            label: 'Week 4',
            shortLabel: 'W4',
            dateSubtitle: 'Sep 22 - Sep 30, 2026',
            received: 28000.0,
            sent: 12000.0,
            inTransfers: 2,
            outTransfers: 2,
            transactions: const [
              AnalyticsTxItem(name: 'Dividend Credit', initial: 'D', avatarBg: Color(0xFF2ECC71), time: 'Sep 25, 9:50 am', amount: 28000.0, isReceived: true, status: 'RECEIVED'),
              AnalyticsTxItem(name: 'Other Bank Transfer', initial: 'O', avatarBg: Color(0xFFD81B60), time: 'Sep 28, 4:30 pm', amount: 12000.0, isReceived: false),
            ],
          ),
        ],
      ),
      // October 2026 (Default - 5 Weeks)
      MonthFlowData(
        monthName: 'October 2026',
        shortName: 'Oct',
        monthIndex: 9,
        weeks: [
          FlowPointData(
            label: 'Week 1',
            shortLabel: 'W1',
            dateSubtitle: 'Oct 01 - Oct 07, 2026',
            received: 8000.0,
            sent: 14500.0,
            inTransfers: 1,
            outTransfers: 3,
            transactions: const [
              AnalyticsTxItem(name: 'Angel Lou F. Yabut', initial: 'A', avatarBg: Color(0xFF7C4DFF), time: 'Oct 03, 2:45 pm', amount: 2500.0, isReceived: false),
              AnalyticsTxItem(name: 'Mae G. Mercado', initial: 'M', avatarBg: Color(0xFF7928CA), time: 'Oct 04, 9:15 am', amount: 4500.0, isReceived: false),
              AnalyticsTxItem(name: 'Direct Deposit', initial: 'D', avatarBg: Color(0xFF00897B), time: 'Oct 02, 10:00 am', amount: 8000.0, isReceived: true, status: 'RECEIVED'),
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
              AnalyticsTxItem(name: 'Drake Montefalco', initial: 'D', avatarBg: Color(0xFF220055), time: 'Oct 14, 2:45 pm', amount: 2500.0, isReceived: false),
              AnalyticsTxItem(name: 'Klare Riego', initial: 'K', avatarBg: Color(0xFFBA68C8), time: 'Oct 14, 1:45 pm', amount: 26500.0, isReceived: true, status: 'RECEIVED'),
              AnalyticsTxItem(name: 'Business Supplies', initial: 'B', avatarBg: Color(0xFF3949AB), time: 'Oct 11, 4:20 pm', amount: 16000.0, isReceived: false),
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
              AnalyticsTxItem(name: 'Jessie Mae Dela Paz', initial: 'J', avatarBg: Color(0xFF00ACC1), time: 'Oct 16, 11:30 am', amount: 5000.0, isReceived: true, status: 'RECEIVED'),
              AnalyticsTxItem(name: 'Hardware Reorder', initial: 'H', avatarBg: Color(0xFF5E35B1), time: 'Oct 18, 3:15 pm', amount: 27500.0, isReceived: false),
              AnalyticsTxItem(name: 'Cloud Services', initial: 'C', avatarBg: Color(0xFF43A047), time: 'Oct 20, 8:40 am', amount: 5000.0, isReceived: false),
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
              AnalyticsTxItem(name: 'Mae G. Mercado', initial: 'M', avatarBg: Color(0xFF5E17EB), time: 'Oct 24, 10:15 am', amount: 18500.0, isReceived: true, status: 'RECEIVED'),
              AnalyticsTxItem(name: 'Office Lease Share', initial: 'O', avatarBg: Color(0xFFD81B60), time: 'Oct 26, 4:00 pm', amount: 10500.0, isReceived: false),
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
              AnalyticsTxItem(name: 'Payroll Reimbursement', initial: 'P', avatarBg: Color(0xFF1E88E5), time: 'Oct 30, 2:00 pm', amount: 25000.0, isReceived: false),
              AnalyticsTxItem(name: 'Consulting Honorarium', initial: 'C', avatarBg: Color(0xFF2ECC71), time: 'Oct 31, 5:30 pm', amount: 5000.0, isReceived: true, status: 'RECEIVED'),
              AnalyticsTxItem(name: 'Petty Cash', initial: 'P', avatarBg: Color(0xFF8E24AA), time: 'Oct 31, 6:00 pm', amount: 4000.0, isReceived: false),
            ],
          ),
        ],
      ),
      MonthFlowData(
        monthName: 'November 2026',
        shortName: 'Nov',
        monthIndex: 10,
        weeks: [
          FlowPointData(
            label: 'Week 1',
            shortLabel: 'W1',
            dateSubtitle: 'Nov 01 - Nov 07, 2026',
            received: 16000.0,
            sent: 14000.0,
            inTransfers: 1,
            outTransfers: 2,
            transactions: const [
              AnalyticsTxItem(name: 'Retainer Credit', initial: 'R', avatarBg: Color(0xFF7C4DFF), time: 'Nov 03, 10:20 am', amount: 16000.0, isReceived: true, status: 'RECEIVED'),
              AnalyticsTxItem(name: 'Operations Reserve', initial: 'O', avatarBg: Color(0xFFE65100), time: 'Nov 05, 3:15 pm', amount: 14000.0, isReceived: false),
            ],
          ),
          FlowPointData(
            label: 'Week 2',
            shortLabel: 'W2',
            dateSubtitle: 'Nov 08 - Nov 14, 2026',
            received: 21000.0,
            sent: 11000.0,
            inTransfers: 2,
            outTransfers: 2,
            transactions: const [
              AnalyticsTxItem(name: 'Client Settlement', initial: 'C', avatarBg: Color(0xFF00897B), time: 'Nov 10, 1:45 pm', amount: 21000.0, isReceived: true, status: 'RECEIVED'),
              AnalyticsTxItem(name: 'Hardware Upgrade', initial: 'H', avatarBg: Color(0xFF3949AB), time: 'Nov 12, 4:20 pm', amount: 11000.0, isReceived: false),
            ],
          ),
          FlowPointData(
            label: 'Week 3',
            shortLabel: 'W3',
            dateSubtitle: 'Nov 15 - Nov 21, 2026',
            received: 15000.0,
            sent: 25000.0,
            inTransfers: 1,
            outTransfers: 3,
            transactions: const [
              AnalyticsTxItem(name: 'Direct Deposit', initial: 'D', avatarBg: Color(0xFF5E17EB), time: 'Nov 17, 11:30 am', amount: 15000.0, isReceived: true, status: 'RECEIVED'),
              AnalyticsTxItem(name: 'Vendor Clearing', initial: 'V', avatarBg: Color(0xFFD81B60), time: 'Nov 19, 3:00 pm', amount: 25000.0, isReceived: false),
            ],
          ),
          FlowPointData(
            label: 'Week 4',
            shortLabel: 'W4',
            dateSubtitle: 'Nov 22 - Nov 30, 2026',
            received: 24000.0,
            sent: 18000.0,
            inTransfers: 2,
            outTransfers: 2,
            transactions: const [
              AnalyticsTxItem(name: 'Inward Wire', initial: 'I', avatarBg: Color(0xFF2ECC71), time: 'Nov 25, 10:00 am', amount: 24000.0, isReceived: true, status: 'RECEIVED'),
              AnalyticsTxItem(name: 'Facility Share', initial: 'F', avatarBg: Color(0xFF8E24AA), time: 'Nov 28, 4:40 pm', amount: 18000.0, isReceived: false),
            ],
          ),
        ],
      ),
      MonthFlowData(
        monthName: 'December 2026',
        shortName: 'Dec',
        monthIndex: 11,
        weeks: [
          FlowPointData(
            label: 'Week 1',
            shortLabel: 'W1',
            dateSubtitle: 'Dec 01 - Dec 07, 2026',
            received: 18000.0,
            sent: 12000.0,
            inTransfers: 1,
            outTransfers: 2,
            transactions: const [
              AnalyticsTxItem(name: 'Holiday Retainer', initial: 'H', avatarBg: Color(0xFF7C4DFF), time: 'Dec 03, 11:15 am', amount: 18000.0, isReceived: true, status: 'RECEIVED'),
              AnalyticsTxItem(name: 'Holiday Corporate Event', initial: 'C', avatarBg: Color(0xFFE65100), time: 'Dec 05, 3:30 pm', amount: 12000.0, isReceived: false),
            ],
          ),
          FlowPointData(
            label: 'Week 2',
            shortLabel: 'W2',
            dateSubtitle: 'Dec 08 - Dec 14, 2026',
            received: 24000.0,
            sent: 19000.0,
            inTransfers: 2,
            outTransfers: 3,
            transactions: const [
              AnalyticsTxItem(name: 'Project Bonus Release', initial: 'P', avatarBg: Color(0xFF00897B), time: 'Dec 10, 1:20 pm', amount: 24000.0, isReceived: true, status: 'RECEIVED'),
              AnalyticsTxItem(name: 'Operational Reserve', initial: 'O', avatarBg: Color(0xFF3949AB), time: 'Dec 12, 4:10 pm', amount: 19000.0, isReceived: false),
            ],
          ),
          FlowPointData(
            label: 'Week 3',
            shortLabel: 'W3',
            dateSubtitle: 'Dec 15 - Dec 21, 2026',
            received: 35000.0,
            sent: 28000.0,
            inTransfers: 2,
            outTransfers: 3,
            transactions: const [
              AnalyticsTxItem(name: 'Client Wire', initial: 'C', avatarBg: Color(0xFF5E17EB), time: 'Dec 17, 10:45 am', amount: 35000.0, isReceived: true, status: 'RECEIVED'),
              AnalyticsTxItem(name: 'Annual Vendor Settlement', initial: 'V', avatarBg: Color(0xFFD81B60), time: 'Dec 19, 2:50 pm', amount: 28000.0, isReceived: false),
            ],
          ),
          FlowPointData(
            label: 'Week 4',
            shortLabel: 'W4',
            dateSubtitle: 'Dec 22 - Dec 28, 2026',
            received: 42000.0,
            sent: 34000.0,
            inTransfers: 3,
            outTransfers: 4,
            transactions: const [
              AnalyticsTxItem(name: '13th Month Settlement', initial: 'M', avatarBg: Color(0xFF2ECC71), time: 'Dec 24, 9:30 am', amount: 42000.0, isReceived: true, status: 'RECEIVED'),
              AnalyticsTxItem(name: 'Year-End Clearing', initial: 'Y', avatarBg: Color(0xFF8E24AA), time: 'Dec 27, 4:00 pm', amount: 34000.0, isReceived: false),
            ],
          ),
          FlowPointData(
            label: 'Week 5',
            shortLabel: 'W5',
            dateSubtitle: 'Dec 29 - Dec 31, 2026',
            received: 20000.0,
            sent: 15000.0,
            inTransfers: 1,
            outTransfers: 2,
            transactions: const [
              AnalyticsTxItem(name: 'Final Inward Settlement', initial: 'F', avatarBg: Color(0xFF00ACC1), time: 'Dec 30, 2:15 pm', amount: 20000.0, isReceived: true, status: 'RECEIVED'),
              AnalyticsTxItem(name: 'Year-End Reserve', initial: 'R', avatarBg: Color(0xFF5E35B1), time: 'Dec 31, 5:00 pm', amount: 15000.0, isReceived: false),
            ],
          ),
        ],
      ),
    ];

    // Yearly Dataset (12 Months in 2026)
    _yearlyMonths2026 = [
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

    // Yearly Dataset (12 Months in 2025)
    _yearlyMonths2025 = [
      FlowPointData(
        label: 'January',
        shortLabel: 'Jan',
        dateSubtitle: 'Jan 01 - Jan 31, 2025',
        received: 12000.0,
        sent: 38000.0,
        inTransfers: 2,
        outTransfers: 12,
        transactions: const [],
      ),
      FlowPointData(
        label: 'February',
        shortLabel: 'Feb',
        dateSubtitle: 'Feb 01 - Feb 28, 2025',
        received: 20000.0,
        sent: 32000.0,
        inTransfers: 3,
        outTransfers: 11,
        transactions: const [],
      ),
      FlowPointData(
        label: 'March',
        shortLabel: 'Mar',
        dateSubtitle: 'Mar 01 - Mar 31, 2025',
        received: 9000.0,
        sent: 36000.0,
        inTransfers: 2,
        outTransfers: 14,
        transactions: const [],
      ),
      FlowPointData(
        label: 'April',
        shortLabel: 'Apr',
        dateSubtitle: 'Apr 01 - Apr 30, 2025',
        received: 52000.0,
        sent: 14000.0,
        inTransfers: 4,
        outTransfers: 10,
        transactions: const [],
      ),
      FlowPointData(
        label: 'May',
        shortLabel: 'May',
        dateSubtitle: 'May 01 - May 31, 2025',
        received: 18000.0,
        sent: 30000.0,
        inTransfers: 3,
        outTransfers: 12,
        transactions: const [],
      ),
      FlowPointData(
        label: 'June',
        shortLabel: 'Jun',
        dateSubtitle: 'Jun 01 - Jun 30, 2025',
        received: 13000.0,
        sent: 42000.0,
        inTransfers: 2,
        outTransfers: 8,
        transactions: const [],
      ),
      FlowPointData(
        label: 'July',
        shortLabel: 'Jul',
        dateSubtitle: 'Jul 01 - Jul 31, 2025',
        received: 21000.0,
        sent: 35000.0,
        inTransfers: 4,
        outTransfers: 18,
        transactions: const [],
      ),
      FlowPointData(
        label: 'August',
        shortLabel: 'Aug',
        dateSubtitle: 'Aug 01 - Aug 31, 2025',
        received: 11500.0,
        sent: 32000.0,
        inTransfers: 3,
        outTransfers: 15,
        transactions: const [],
      ),
      FlowPointData(
        label: 'September',
        shortLabel: 'Sep',
        dateSubtitle: 'Sep 01 - Sep 30, 2025',
        received: 15000.0,
        sent: 39000.0,
        inTransfers: 3,
        outTransfers: 14,
        transactions: const [],
      ),
      FlowPointData(
        label: 'October',
        shortLabel: 'Oct',
        dateSubtitle: 'Oct 01 - Oct 31, 2025',
        received: 45000.0,
        sent: 85000.0,
        inTransfers: 3,
        outTransfers: 15,
        transactions: const [],
      ),
      FlowPointData(
        label: 'November',
        shortLabel: 'Nov',
        dateSubtitle: 'Nov 01 - Nov 30, 2025',
        received: 16000.0,
        sent: 40000.0,
        inTransfers: 2,
        outTransfers: 14,
        transactions: const [],
      ),
      FlowPointData(
        label: 'December',
        shortLabel: 'Dec',
        dateSubtitle: 'Dec 01 - Dec 31, 2025',
        received: 25000.0,
        sent: 52000.0,
        inTransfers: 3,
        outTransfers: 18,
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

  void _onSelectMonthOfYear(int newIdx) {
    if (newIdx < 0 || newIdx >= _monthsCatalog.length) return;
    if (_selectedMonthOfYear == newIdx) return;
    setState(() {
      _selectedMonthOfYear = newIdx;
      final weeks = _currentMonthlyWeeks;
      _selectedWeekIndex = _selectedWeekIndex.clamp(0, weeks.length - 1);
      _showAllTotals = false;
      _currentScrubFraction = _selectedWeekIndex.toDouble();
    });
    _animateToTarget(_selectedWeekIndex.toDouble());
  }

  void _onSelectYear(int newYear) {
    if (_selectedYear == newYear) return;
    setState(() {
      _selectedYear = newYear;
      final list = _currentYearlyFilteredMonths;
      _selectedMonthIndex = _selectedMonthIndex.clamp(0, list.length - 1);
      _currentScrubFraction = _selectedMonthIndex.toDouble();
    });
    _animateToTarget(_selectedMonthIndex.toDouble());
  }

  void _onSelectQuarter(int quarterIdx) {
    if (_selectedQuarterIndex == quarterIdx) return;
    setState(() {
      _selectedQuarterIndex = quarterIdx;
      if (quarterIdx == 0) {
        _selectedMonthIndex = 3; // April default in full year
      } else {
        _selectedMonthIndex = 0; // First month of selected quarter
      }
      _currentScrubFraction = _selectedMonthIndex.toDouble();
    });
    _animateToTarget(_selectedMonthIndex.toDouble());
  }

  void _onToggleMode(bool monthly) {
    if (_isMonthly == monthly) return;
    setState(() {
      _isMonthly = monthly;
      _showAllTotals = false;
      final maxLen = (monthly ? _currentMonthlyWeeks : _currentYearlyFilteredMonths).length;
      final activeIdx = monthly
          ? _selectedWeekIndex.clamp(0, maxLen - 1)
          : _selectedMonthIndex.clamp(0, maxLen - 1);
      _currentScrubFraction = activeIdx.toDouble();
    });
    _animateToTarget(
      (monthly ? _selectedWeekIndex : _selectedMonthIndex).toDouble(),
    );
  }

  List<FlowPointData> get _currentMonthlyWeeks =>
      _monthsCatalog[_selectedMonthOfYear].weeks;

  List<FlowPointData> get _currentFullYearMonths =>
      _selectedYear == 2026 ? _yearlyMonths2026 : _yearlyMonths2025;

  List<FlowPointData> get _currentYearlyFilteredMonths {
    final full = _currentFullYearMonths;
    switch (_selectedQuarterIndex) {
      case 1:
        return full.sublist(0, 3);
      case 2:
        return full.sublist(3, 6);
      case 3:
        return full.sublist(6, 9);
      case 4:
        return full.sublist(9, 12);
      default:
        return full;
    }
  }

  List<FlowPointData> get _currentDataset =>
      _isMonthly ? _currentMonthlyWeeks : _currentYearlyFilteredMonths;

  FlowPointData get _activePointData {
    final list = _currentDataset;
    final index = _isMonthly
        ? _selectedWeekIndex.clamp(0, list.length - 1)
        : _selectedMonthIndex.clamp(0, list.length - 1);
    return list[index];
  }

  String get _currentMonthName => _monthsCatalog[_selectedMonthOfYear].monthName;

  String get _currentPeriodLabel {
    if (_isMonthly) return _currentMonthName;
    if (_selectedQuarterIndex == 0) return '$_selectedYear';
    return 'Q$_selectedQuarterIndex $_selectedYear';
  }

  // Grand totals
  double get _totalSentMonth {
    double sum = 0;
    for (final w in _currentMonthlyWeeks) {
      sum += w.sent;
    }
    return sum;
  }

  double get _totalReceivedMonth {
    double sum = 0;
    for (final w in _currentMonthlyWeeks) {
      sum += w.received;
    }
    return sum;
  }

  int get _transfersOutMonth {
    int sum = 0;
    for (final w in _currentMonthlyWeeks) {
      sum += w.outTransfers;
    }
    return sum;
  }

  int get _transfersInMonth {
    int sum = 0;
    for (final w in _currentMonthlyWeeks) {
      sum += w.inTransfers;
    }
    return sum;
  }

  double get _totalSentPeriod {
    if (_selectedQuarterIndex == 0 && _selectedYear == 2026) {
      return 508000.0;
    }
    double sum = 0;
    for (final m in _currentYearlyFilteredMonths) {
      sum += m.sent;
    }
    return sum;
  }

  double get _totalReceivedPeriod {
    if (_selectedQuarterIndex == 0 && _selectedYear == 2026) {
      return 160000.0;
    }
    double sum = 0;
    for (final m in _currentYearlyFilteredMonths) {
      sum += m.received;
    }
    return sum;
  }

  int get _transfersOutPeriod {
    if (_selectedQuarterIndex == 0 && _selectedYear == 2026) {
      return 185;
    }
    int sum = 0;
    for (final m in _currentYearlyFilteredMonths) {
      sum += m.outTransfers;
    }
    return sum;
  }

  int get _transfersInPeriod {
    if (_selectedQuarterIndex == 0 && _selectedYear == 2026) {
      return 43;
    }
    int sum = 0;
    for (final m in _currentYearlyFilteredMonths) {
      sum += m.inTransfers;
    }
    return sum;
  }

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

              // Mode-specific selector card:
              // - Monthly Mode: Month Dropdown Selector
              // - Yearly Mode: Fiscal Year & Quarter Filter Card
              if (_isMonthly) ...[
                const SizedBox(height: 14),
                _buildMonthDropdownSelector(),
              ] else ...[
                const SizedBox(height: 14),
                _buildYearAndQuarterFilterCard(),
              ],

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

  Widget _buildMonthDropdownSelector() {
    final canGoPrev = _selectedMonthOfYear > 0;
    final canGoNext = _selectedMonthOfYear < _monthsCatalog.length - 1;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFEDE9FE), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: brandViolet.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // Calendar Icon Badge in soft lavender
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFF3E8FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.calendar_month_rounded, color: brandViolet, size: 20),
          ),
          const SizedBox(width: 12),
          // Month Dropdown Trigger & Label
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'STATEMENT PERIOD',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: brandViolet,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 1),
                DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    key: const ValueKey('monthDropdownButton'),
                    value: _selectedMonthOfYear,
                    isDense: true,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, color: brandViolet, size: 22),
                    dropdownColor: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    elevation: 8,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: textDark,
                    ),
                    items: List.generate(_monthsCatalog.length, (idx) {
                      final item = _monthsCatalog[idx];
                      final isSelected = idx == _selectedMonthOfYear;
                      return DropdownMenuItem<int>(
                        value: idx,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              item.monthName,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                color: isSelected ? brandViolet : textDark,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: isSelected ? const Color(0xFFF3E8FF) : const Color(0xFFF9FAFB),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: isSelected ? const Color(0xFFDDD6FE) : const Color(0xFFE5E7EB),
                                  width: 0.8,
                                ),
                              ),
                              child: Text(
                                '${item.weeks.length} Weeks',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: isSelected ? brandViolet : textGray,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    onChanged: (newIdx) {
                      if (newIdx != null) {
                        _onSelectMonthOfYear(newIdx);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Micro Navigation Chevrons (< and >)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                key: const ValueKey('prevMonthBtn'),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                icon: Icon(
                  Icons.chevron_left_rounded,
                  size: 20,
                  color: canGoPrev ? brandViolet : const Color(0xFFD1D5DB),
                ),
                onPressed: canGoPrev ? () => _onSelectMonthOfYear(_selectedMonthOfYear - 1) : null,
              ),
              const SizedBox(width: 2),
              IconButton(
                key: const ValueKey('nextMonthBtn'),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                icon: Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: canGoNext ? brandViolet : const Color(0xFFD1D5DB),
                ),
                onPressed: canGoNext ? () => _onSelectMonthOfYear(_selectedMonthOfYear + 1) : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildYearAndQuarterFilterCard() {
    final canGoPrevYear = _selectedYear > 2025;
    final canGoNextYear = _selectedYear < 2026;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFEDE9FE), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: brandViolet.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Year selection with icon and quick-nav chevrons
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3E8FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.calendar_today_rounded, color: brandViolet, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'FISCAL YEAR',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: brandViolet,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 1),
                    DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        key: const ValueKey('yearDropdownButton'),
                        value: _selectedYear,
                        isDense: true,
                        icon: const Icon(Icons.keyboard_arrow_down_rounded, color: brandViolet, size: 20),
                        dropdownColor: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        elevation: 8,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: textDark,
                        ),
                        items: const [
                          DropdownMenuItem<int>(
                            value: 2026,
                            child: Text(
                              '2026 (Current)',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: textDark,
                              ),
                            ),
                          ),
                          DropdownMenuItem<int>(
                            value: 2025,
                            child: Text(
                              '2025 (Previous)',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: textDark,
                              ),
                            ),
                          ),
                        ],
                        onChanged: (newYear) {
                          if (newYear != null) {
                            _onSelectYear(newYear);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Chevron buttons for Year navigation
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    key: const ValueKey('prevYearBtn'),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    icon: Icon(
                      Icons.chevron_left_rounded,
                      size: 20,
                      color: canGoPrevYear ? brandViolet : const Color(0xFFD1D5DB),
                    ),
                    onPressed: canGoPrevYear ? () => _onSelectYear(2025) : null,
                  ),
                  const SizedBox(width: 2),
                  IconButton(
                    key: const ValueKey('nextYearBtn'),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    icon: Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: canGoNextYear ? brandViolet : const Color(0xFFD1D5DB),
                    ),
                    onPressed: canGoNextYear ? () => _onSelectYear(2026) : null,
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Subtle Divider
          Container(
            height: 1,
            color: const Color(0xFFF3F4F6),
          ),

          const SizedBox(height: 8),

          // Row 2: Quarter Filter segmented pill bar
          Row(
            children: [
              const Text(
                'QUARTER',
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  color: textGray,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  height: 32,
                  padding: const EdgeInsets.all(2.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F5FA),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFEDE9FE), width: 1.0),
                  ),
                  child: Row(
                    children: [
                      _buildQuarterPill(0, 'All'),
                      _buildQuarterPill(1, 'Q1'),
                      _buildQuarterPill(2, 'Q2'),
                      _buildQuarterPill(3, 'Q3'),
                      _buildQuarterPill(4, 'Q4'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuarterPill(int index, String label) {
    final isSelected = _selectedQuarterIndex == index;
    return Expanded(
      child: GestureDetector(
        key: ValueKey('quarterPill_$label'),
        onTap: () => _onSelectQuarter(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: isSelected ? brandViolet : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: brandViolet.withValues(alpha: 0.25),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? Colors.white : textDark,
              ),
            ),
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
                        ? (_isMonthly
                            ? 'Full Month Summary ($_currentMonthName)'
                            : (_selectedQuarterIndex == 0
                                ? 'Full Year Summary ($_selectedYear)'
                                : 'Quarter $_selectedQuarterIndex Summary ($_selectedYear)'))
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
        ? (_isMonthly ? _totalSentMonth : _totalSentPeriod)
        : active.sent;
    final sentCount = _showAllTotals
        ? (_isMonthly ? _transfersOutMonth : _transfersOutPeriod)
        : active.outTransfers;

    final receivedAmount = _showAllTotals
        ? (_isMonthly ? _totalReceivedMonth : _totalReceivedPeriod)
        : active.received;
    final receivedCount = _showAllTotals
        ? (_isMonthly ? _transfersInMonth : _transfersInPeriod)
        : active.inTransfers;

    final sentTitle = _showAllTotals
        ? (_isMonthly ? 'Total Sent' : 'Total Sent ($_currentPeriodLabel)')
        : 'Sent (${active.shortLabel})';
    final receivedTitle = _showAllTotals
        ? (_isMonthly ? 'Total Received' : 'Total Received ($_currentPeriodLabel)')
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
    final weeks = _currentMonthlyWeeks;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(weeks.length, (index) {
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
    final dataset = _currentYearlyFilteredMonths;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: List.generate(dataset.length, (index) {
          final isSelected = _selectedMonthIndex == index;
          final item = dataset[index];
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
                      'Highlighted: ${active.label} $_selectedYear',
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
              monthTitle: '${active.label} $_selectedYear (Selected)',
              transfers: '${active.inTransfers + active.outTransfers} Transfers • + ${_formatCurrency(active.received)}',
              gross: 'PHP ${_formatCurrency(active.sent)}',
              net: '${active.net >= 0 ? '+' : '-'} PHP ${_formatCompactK(active.net.abs())} net',
              avatarBg: brandViolet,
            ),
          ),

          const SizedBox(height: 16),

          if (_selectedQuarterIndex == 0) ...[
            const Text(
              'Quarter 3',
              style: TextStyle(fontSize: 12, color: textGray, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),

            _buildQuarterRow(
              initial: 'Jul',
              monthTitle: 'July $_selectedYear',
              transfers: '24 transfers • + 38,000.00',
              gross: 'PHP 42,000.00',
              net: '+ PHP 25.5k net',
              avatarBg: const Color(0xFF6200EA),
            ),
            const SizedBox(height: 10),
            _buildQuarterRow(
              initial: 'Aug',
              monthTitle: 'August $_selectedYear',
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
              monthTitle: 'June $_selectedYear',
              transfers: '10 Transfers • + 38,000.00',
              gross: 'PHP 50,000.00',
              net: '+ PHP 15.2k net',
              avatarBg: const Color(0xFFBA68C8),
            ),
          ] else ...[
            Text(
              'Quarter $_selectedQuarterIndex Overview ($_selectedYear)',
              style: const TextStyle(fontSize: 12, color: textGray, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            for (final m in _currentYearlyFilteredMonths) ...[
              if (m != active) ...[
                _buildQuarterRow(
                  initial: m.shortLabel,
                  monthTitle: '${m.label} $_selectedYear',
                  transfers: '${m.inTransfers + m.outTransfers} Transfers • + ${_formatCurrency(m.received)}',
                  gross: 'PHP ${_formatCurrency(m.sent)}',
                  net: '${m.net >= 0 ? '+' : '-'} PHP ${_formatCompactK(m.net.abs())} net',
                  avatarBg: const Color(0xFF6200EA),
                ),
                const SizedBox(height: 10),
              ],
            ],
          ],
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
              style: TextStyle(
                fontSize: 11,
                color: net.startsWith('+') ? accentGreen : const Color(0xFFDC2626),
                fontWeight: FontWeight.w600,
              ),
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
    // Exactly n points: weeks in Monthly mode, 12 months in Yearly mode.
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
    // For Monthly: draw clean straight pointed segments connecting the exact week vertices
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

    // 3. Draw All Pointed Vertices / Nodes on both lines
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

    // 4. Calculate Current Animated Scrub Position
    final clampedScrub = scrubFraction.clamp(0.0, (n - 1).toDouble());
    final scrubX = paddingX + (clampedScrub * xStep);

    // Interpolate Y positions at the exact scrub position
    final scrubYGreen = _interpolateY(greenPoints, clampedScrub);
    final scrubYViolet = _interpolateY(violetPoints, clampedScrub);

    // Interpolate Value amounts at scrub position
    final scrubValGreen = _interpolateValue(dataset.map((d) => d.received).toList(), clampedScrub);
    final scrubValViolet = _interpolateValue(dataset.map((d) => d.sent).toList(), clampedScrub);

    // 5. Draw Vertical Guideline
    final dashPaint = Paint()
      ..color = const Color(0xFF8B5CF6).withValues(alpha: 0.40)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    _drawDashedVerticalLine(canvas, scrubX, paddingTop - 12, h - 8, dashPaint);

    // 6. Draw Highlighted Active Scrub Rings
    // Active Green Ring
    canvas.drawCircle(Offset(scrubX, scrubYGreen), 8.0, Paint()..color = const Color(0xFF2ECC71).withValues(alpha: 0.25));
    canvas.drawCircle(Offset(scrubX, scrubYGreen), 5.5, greenNodePaint);
    canvas.drawCircle(Offset(scrubX, scrubYGreen), 3.0, whiteInnerPaint);

    // Active Violet Ring
    canvas.drawCircle(Offset(scrubX, scrubYViolet), 8.0, Paint()..color = const Color(0xFF5E17EB).withValues(alpha: 0.25));
    canvas.drawCircle(Offset(scrubX, scrubYViolet), 5.5, violetNodePaint);
    canvas.drawCircle(Offset(scrubX, scrubYViolet), 3.0, whiteInnerPaint);

    // 7. Draw Floating Pointed Callout Badges
    _drawPointedBadge(
      canvas: canvas,
      center: Offset(scrubX, scrubYGreen - 18),
      text: '+${_formatCompactK(scrubValGreen)} In',
      bgColor: const Color(0xFF059669),
      pointDown: true,
    );

    _drawPointedBadge(
      canvas: canvas,
      center: Offset(scrubX, scrubYViolet + 18),
      text: '-${_formatCompactK(scrubValViolet)} Out',
      bgColor: const Color(0xFF220055),
      pointDown: false,
    );
  }

  Path _buildPath(List<Offset> points, {required bool isMonthly}) {
    final path = Path();
    if (points.isEmpty) return path;
    path.moveTo(points[0].dx, points[0].dy);

    if (isMonthly) {
      for (int i = 1; i < points.length; i++) {
        path.lineTo(points[i].dx, points[i].dy);
      }
    } else {
      for (int i = 0; i < points.length - 1; i++) {
        final p0 = i > 0 ? points[i - 1] : points[i];
        final p1 = points[i];
        final p2 = points[i + 1];
        final p3 = (i + 2 < points.length) ? points[i + 2] : p2;

        final cp1x = p1.dx + (p2.dx - p0.dx) / 6;
        final cp1y = p1.dy + (p2.dy - p0.dy) / 6;
        final cp2x = p2.dx - (p3.dx - p1.dx) / 6;
        final cp2y = p2.dy - (p3.dy - p1.dy) / 6;

        path.cubicTo(cp1x, cp1y, cp2x, cp2y, p2.dx, p2.dy);
      }
    }

    return path;
  }

  double _interpolateY(List<Offset> points, double fraction) {
    if (points.isEmpty) return 0;
    if (points.length == 1) return points.first.dy;

    final lower = fraction.floor().clamp(0, points.length - 1);
    final upper = fraction.ceil().clamp(0, points.length - 1);
    if (lower == upper) return points[lower].dy;

    final t = fraction - lower;
    return points[lower].dy + (points[upper].dy - points[lower].dy) * t;
  }

  double _interpolateValue(List<double> vals, double fraction) {
    if (vals.isEmpty) return 0;
    if (vals.length == 1) return vals.first;

    final lower = fraction.floor().clamp(0, vals.length - 1);
    final upper = fraction.ceil().clamp(0, vals.length - 1);
    if (lower == upper) return vals[lower];

    final t = fraction - lower;
    return vals[lower] + (vals[upper] - vals[lower]) * t;
  }

  void _drawDashedVerticalLine(Canvas canvas, double x, double startY, double endY, Paint paint) {
    const dashHeight = 4.0;
    const dashSpace = 3.5;
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

  void _drawPointedBadge({
    required Canvas canvas,
    required Offset center,
    required String text,
    required Color bgColor,
    required bool pointDown,
  }) {
    const textStyle = TextStyle(
      color: Colors.white,
      fontSize: 10,
      fontWeight: FontWeight.w800,
      letterSpacing: 0.2,
    );
    final textSpan = TextSpan(text: text, style: textStyle);
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    )..layout();

    const paddingH = 9.0;
    const paddingV = 4.0;
    final badgeW = textPainter.width + (2 * paddingH);
    final badgeH = textPainter.height + (2 * paddingV);

    final left = center.dx - (badgeW / 2);
    final top = center.dy - (badgeH / 2);
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(left, top, badgeW, badgeH),
      const Radius.circular(8),
    );

    canvas.drawRRect(rrect, Paint()..color = bgColor);

    final borderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawRRect(rrect, borderPaint);

    final textOffset = Offset(
      left + paddingH,
      top + paddingV,
    );
    textPainter.paint(canvas, textOffset);
  }

  String _formatCompactK(double val) {
    if (val >= 1000) {
      return '${(val / 1000).toStringAsFixed(1)}k';
    }
    return val.toStringAsFixed(0);
  }

  @override
  bool shouldRepaint(covariant _PointedTransferFlowPainter oldDelegate) {
    return oldDelegate.scrubFraction != scrubFraction ||
        oldDelegate.dataset != dataset ||
        oldDelegate.isMonthly != isMonthly;
  }
}
