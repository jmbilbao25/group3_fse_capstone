import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/bank_models.dart';
import 'device_storage.dart';

enum AppEnvironment { local, prod }

class BankService extends ChangeNotifier {
  static final BankService _instance = BankService._internal();
  factory BankService() => _instance;
  BankService._internal();

  // Multi-environment routing (Local Docker PC vs Azure Cloud Prod)
  AppEnvironment environment = (const String.fromEnvironment('ENV', defaultValue: 'local')).toLowerCase() == 'prod'
      ? AppEnvironment.prod
      : AppEnvironment.local;

  static String _resolveInitialLocalUrl() {
    const envUrl = String.fromEnvironment('LOCAL_API_URL');
    if (envUrl.isNotEmpty) return envUrl;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://127.0.0.1:8080';
    }
    return 'http://localhost:8080';
  }

  String localUrl = _resolveInitialLocalUrl();
  String cloudUrl = const String.fromEnvironment('CLOUD_API_URL', defaultValue: 'https://gateway.aurabank.azurecontainerapps.io');
  bool autoFallbackToLocal = true;
  String? lastConnectionStatus;
  int? lastPingLatencyMs;

  String get baseUrl => environment == AppEnvironment.prod ? cloudUrl : localUrl;

  void setEnvironment(AppEnvironment env) {
    environment = env;
    notifyListeners();
  }

  void setCloudUrl(String url) {
    cloudUrl = url;
    notifyListeners();
  }

  void setLocalUrl(String url) {
    localUrl = url;
    notifyListeners();
  }

  void setAutoFallback(bool enable) {
    autoFallbackToLocal = enable;
    notifyListeners();
  }

  Future<bool> testConnection() async {
    final candidateTargets = <String>{
      baseUrl,
      'http://127.0.0.1:8080',
      'http://localhost:8080',
      'http://192.168.18.110:8080',
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) ...[
        'http://10.0.2.2:8080',
      ],
    }.toList();

    for (final target in candidateTargets) {
      final stopwatch = Stopwatch()..start();
      try {
        final res = await http.get(Uri.parse('$target/actuator/health')).timeout(const Duration(seconds: 2));
        stopwatch.stop();
        lastPingLatencyMs = stopwatch.elapsedMilliseconds;
        if (res.statusCode >= 200 && res.statusCode < 400) {
          localUrl = target;
          lastConnectionStatus = 'Healthy (${res.statusCode}) - ${lastPingLatencyMs}ms';
          notifyListeners();
          return true;
        }
      } catch (_) {
        try {
          final res = await http.get(Uri.parse('$target/api/v1/accounts/1000-2000-3001')).timeout(const Duration(seconds: 2));
          stopwatch.stop();
          lastPingLatencyMs = stopwatch.elapsedMilliseconds;
          if (res.statusCode >= 200 && res.statusCode < 500) {
            localUrl = target;
            lastConnectionStatus = 'Healthy (${res.statusCode}) - ${lastPingLatencyMs}ms';
            notifyListeners();
            return true;
          }
        } catch (_) {}
      }
    }

    lastPingLatencyMs = null;
    lastConnectionStatus = 'Unreachable';
    notifyListeners();
    return false;
  }

  // Active User Profile
  final UserProfile user = UserProfile(
    name: 'Elijah Riley Montefalco',
    phoneNumber: '+63 967 830 4637',
    email: 'elijahriley.montefalco@gmail.com',
    address: 'Alegria, Bukidnon',
    dob: 'July 10, 1999',
    gender: 'Male',
    civilStatus: 'Married',
    faceIdEnabled: false,
    fingerprintEnabled: false,
    pushAlertsEnabled: true,
  );

  // Available Balance (defaults to ₱50,000,000 as seen in UI, or real backend balance)
  double availableBalance = 50000000.0;
  final String savingsAccountNumber = '123456789123';
  String activeAccountId = '1000-2000-3001';

  // Bank Cards
  final List<BankCard> cards = [
    BankCard(
      id: 'CARD-01',
      title: 'Savings',
      cardNumber: '1235 5267 8795 0809',
      expiry: '08/29',
      cvv: '158',
      holderName: 'Elijah Montefalco',
      gradientStart: 0xFF2A085C,
      gradientEnd: 0xFF5E17EB,
    ),
    BankCard(
      id: 'CARD-02',
      title: 'Current',
      cardNumber: '1235 5267 8795 1016',
      expiry: '09/32',
      cvv: '143',
      holderName: 'Juan S. Dela Cruz',
      gradientStart: 0xFF2A085C,
      gradientEnd: 0xFF5E17EB,
    ),
    BankCard(
      id: 'CARD-03',
      title: 'Credit',
      cardNumber: '1235 5267 8795 8776',
      expiry: '10/56',
      cvv: '155',
      holderName: 'Juan S. Dela Cruz',
      gradientStart: 0xFF190634,
      gradientEnd: 0xFF4A154B,
    ),
  ];

  // Statements mapped by monthKey (All 12 Months: Jan - Dec 2026)
  final Map<String, MonthlyStatement> statements = {
    '2026-12': MonthlyStatement(
      monthKey: '2026-12',
      title: 'December 2026',
      dateRange: 'Dec 01 - Dec 31, 2026',
      totalReceived: 85000.00,
      totalSent: 54200.00,
      transactions: [
        BankTransaction(
          id: 'TXN-DEC-01',
          reference: 'AUR-991201',
          counterparty: 'Annual Dividend Equity',
          type: TransactionType.incoming,
          amount: 60000.00,
          timestamp: DateTime(2026, 12, 15, 10, 00),
          displayTime: 'Dec 15, 10:00 AM',
          status: TransactionStatus.settled,
          initial: 'A',
          avatarColorValue: 0xFF059669,
        ),
        BankTransaction(
          id: 'TXN-DEC-02',
          reference: 'AUR-991202',
          counterparty: 'Executive 13th Month Tranche',
          type: TransactionType.incoming,
          amount: 25000.00,
          timestamp: DateTime(2026, 12, 18, 14, 30),
          displayTime: 'Dec 18, 2:30 PM',
          status: TransactionStatus.settled,
          initial: 'E',
          avatarColorValue: 0xFF059669,
        ),
        BankTransaction(
          id: 'TXN-DEC-03',
          reference: 'AUR-991203',
          counterparty: 'Holiday Supplier Bonus',
          type: TransactionType.outgoing,
          amount: 32200.00,
          timestamp: DateTime(2026, 12, 22, 16, 45),
          displayTime: 'Dec 22, 4:45 PM',
          status: TransactionStatus.settled,
          initial: 'H',
          avatarColorValue: 0xFF7928CA,
        ),
        BankTransaction(
          id: 'TXN-DEC-04',
          reference: 'AUR-991204',
          counterparty: 'Bureau of Internal Revenue',
          type: TransactionType.outgoing,
          amount: 22000.00,
          timestamp: DateTime(2026, 12, 28, 11, 15),
          displayTime: 'Dec 28, 11:15 AM',
          status: TransactionStatus.settled,
          initial: 'B',
          avatarColorValue: 0xFF7928CA,
        ),
      ],
    ),
    '2026-11': MonthlyStatement(
      monthKey: '2026-11',
      title: 'November 2026',
      dateRange: 'Nov 01 - Nov 30, 2026',
      totalReceived: 42000.00,
      totalSent: 31500.00,
      transactions: [
        BankTransaction(
          id: 'TXN-NOV-01',
          reference: 'AUR-991101',
          counterparty: 'Central Bank Clearing',
          type: TransactionType.incoming,
          amount: 42000.00,
          timestamp: DateTime(2026, 11, 08, 9, 30),
          displayTime: 'Nov 08, 9:30 AM',
          status: TransactionStatus.settled,
          initial: 'C',
          avatarColorValue: 0xFF059669,
        ),
        BankTransaction(
          id: 'TXN-NOV-02',
          reference: 'AUR-991102',
          counterparty: 'Oracle Cloud Subscription',
          type: TransactionType.outgoing,
          amount: 18500.00,
          timestamp: DateTime(2026, 11, 19, 15, 20),
          displayTime: 'Nov 19, 3:20 PM',
          status: TransactionStatus.settled,
          initial: 'O',
          avatarColorValue: 0xFF7928CA,
        ),
        BankTransaction(
          id: 'TXN-NOV-03',
          reference: 'AUR-991103',
          counterparty: 'Office Facilities Lease',
          type: TransactionType.outgoing,
          amount: 13000.00,
          timestamp: DateTime(2026, 11, 26, 17, 00),
          displayTime: 'Nov 26, 5:00 PM',
          status: TransactionStatus.settled,
          initial: 'O',
          avatarColorValue: 0xFF7928CA,
        ),
      ],
    ),
    '2026-10': MonthlyStatement(
      monthKey: '2026-10',
      title: 'October 2026',
      dateRange: 'October 1 - 31, 2026',
      totalReceived: 52000.00,
      totalSent: 22000.00,
      transactions: [
        BankTransaction(
          id: 'TXN-OCT-01',
          reference: 'AUR-997540',
          counterparty: 'Drake Montero',
          type: TransactionType.incoming,
          amount: 2000.00,
          timestamp: DateTime(2026, 10, 1, 8, 0),
          displayTime: '01 Oct 2026 - 8:00 AM',
          status: TransactionStatus.settled,
          channel: 'Same Bank',
          initial: 'D',
          avatarColorValue: 0xFF3B0764,
        ),
        BankTransaction(
          id: 'TXN-OCT-02',
          reference: 'AUR-997811',
          counterparty: 'Klare Riego',
          type: TransactionType.incoming,
          amount: 50000.00,
          timestamp: DateTime(2026, 10, 5, 10, 0),
          displayTime: '05 Oct 2026 - 10:00 AM',
          status: TransactionStatus.settled,
          channel: 'Same Bank',
          initial: 'K',
          avatarColorValue: 0xFF581C87,
        ),
        BankTransaction(
          id: 'TXN-OCT-03',
          reference: 'AUR-996411',
          counterparty: 'Jessi Mey',
          type: TransactionType.outgoing,
          amount: 10000.00,
          timestamp: DateTime(2026, 10, 10, 14, 0),
          displayTime: '10 Oct 2026 - 2:00 PM',
          status: TransactionStatus.settled,
          channel: 'Other Bank',
          initial: 'J',
          avatarColorValue: 0xFF7E22CE,
        ),
        BankTransaction(
          id: 'TXN-OCT-04',
          reference: 'AUR-998241',
          counterparty: 'Angel Lou',
          type: TransactionType.outgoing,
          amount: 12000.00,
          timestamp: DateTime(2026, 10, 15, 16, 0),
          displayTime: '15 Oct 2026 - 4:00 PM',
          status: TransactionStatus.settled,
          channel: 'Other Bank',
          initial: 'A',
          avatarColorValue: 0xFF9333EA,
        ),
      ],
    ),
    '2026-09': MonthlyStatement(
      monthKey: '2026-09',
      title: 'September 2026',
      dateRange: 'Sep 01 - Sep 30, 2026',
      totalReceived: 45000.00,
      totalSent: 28400.00,
      transactions: [
        BankTransaction(
          id: 'TXN-SEP-01',
          reference: 'AUR-882194',
          counterparty: 'Drake Montero',
          type: TransactionType.incoming,
          amount: 45000.00,
          timestamp: DateTime(2026, 9, 15, 10, 30),
          displayTime: 'Sep 15, 10:30 AM',
          status: TransactionStatus.settled,
          initial: 'D',
          avatarColorValue: 0xFF059669,
        ),
        BankTransaction(
          id: 'TXN-SEP-02',
          reference: 'AUR-883901',
          counterparty: 'Klare Riego',
          type: TransactionType.outgoing,
          amount: 28400.00,
          timestamp: DateTime(2026, 9, 24, 16, 15),
          displayTime: 'Sep 24, 4:15 PM',
          status: TransactionStatus.settled,
          initial: 'K',
          avatarColorValue: 0xFF7928CA,
        ),
      ],
    ),
    '2026-08': MonthlyStatement(
      monthKey: '2026-08',
      title: 'August 2026',
      dateRange: 'Aug 01 - Aug 31, 2026',
      totalReceived: 58000.00,
      totalSent: 34100.00,
      transactions: [
        BankTransaction(
          id: 'TXN-AUG-01',
          reference: 'AUR-880801',
          counterparty: 'Aura Capital Remittance',
          type: TransactionType.incoming,
          amount: 58000.00,
          timestamp: DateTime(2026, 8, 11, 10, 15),
          displayTime: 'Aug 11, 10:15 AM',
          status: TransactionStatus.settled,
          initial: 'A',
          avatarColorValue: 0xFF059669,
        ),
        BankTransaction(
          id: 'TXN-AUG-02',
          reference: 'AUR-880802',
          counterparty: 'Enterprise Cloud Backup',
          type: TransactionType.outgoing,
          amount: 19100.00,
          timestamp: DateTime(2026, 8, 19, 14, 00),
          displayTime: 'Aug 19, 2:00 PM',
          status: TransactionStatus.settled,
          initial: 'E',
          avatarColorValue: 0xFF7928CA,
        ),
        BankTransaction(
          id: 'TXN-AUG-03',
          reference: 'AUR-880803',
          counterparty: 'Corporate Legal Retainer',
          type: TransactionType.outgoing,
          amount: 15000.00,
          timestamp: DateTime(2026, 8, 27, 16, 30),
          displayTime: 'Aug 27, 4:30 PM',
          status: TransactionStatus.settled,
          initial: 'C',
          avatarColorValue: 0xFF7928CA,
        ),
      ],
    ),
    '2026-07': MonthlyStatement(
      monthKey: '2026-07',
      title: 'July 2026',
      dateRange: 'Jul 01 - Jul 31, 2026',
      totalReceived: 49500.00,
      totalSent: 38200.00,
      transactions: [
        BankTransaction(
          id: 'TXN-JUL-01',
          reference: 'AUR-880701',
          counterparty: 'BDO Clearing Remittance',
          type: TransactionType.incoming,
          amount: 49500.00,
          timestamp: DateTime(2026, 7, 12, 11, 00),
          displayTime: 'Jul 12, 11:00 AM',
          status: TransactionStatus.settled,
          initial: 'B',
          avatarColorValue: 0xFF059669,
        ),
        BankTransaction(
          id: 'TXN-JUL-02',
          reference: 'AUR-880702',
          counterparty: 'Equinix Data Center Lease',
          type: TransactionType.outgoing,
          amount: 25000.00,
          timestamp: DateTime(2026, 7, 21, 15, 45),
          displayTime: 'Jul 21, 3:45 PM',
          status: TransactionStatus.settled,
          initial: 'E',
          avatarColorValue: 0xFF7928CA,
        ),
        BankTransaction(
          id: 'TXN-JUL-03',
          reference: 'AUR-880703',
          counterparty: 'Security Auditing Firm',
          type: TransactionType.outgoing,
          amount: 13200.00,
          timestamp: DateTime(2026, 7, 28, 17, 10),
          displayTime: 'Jul 28, 5:10 PM',
          status: TransactionStatus.settled,
          initial: 'S',
          avatarColorValue: 0xFF7928CA,
        ),
      ],
    ),
    '2026-06': MonthlyStatement(
      monthKey: '2026-06',
      title: 'June 2026',
      dateRange: 'Jun 01 - Jun 30, 2026',
      totalReceived: 50000.00,
      totalSent: 15200.00,
      transactions: [
        BankTransaction(
          id: 'TXN-JUN-01',
          reference: 'AUR-880601',
          counterparty: 'Central Treasury Ledger',
          type: TransactionType.incoming,
          amount: 50000.00,
          timestamp: DateTime(2026, 6, 14, 9, 30),
          displayTime: 'Jun 14, 9:30 AM',
          status: TransactionStatus.settled,
          initial: 'C',
          avatarColorValue: 0xFF059669,
        ),
        BankTransaction(
          id: 'TXN-JUN-02',
          reference: 'AUR-880602',
          counterparty: 'Hardware Maintenance Tranche',
          type: TransactionType.outgoing,
          amount: 15200.00,
          timestamp: DateTime(2026, 6, 25, 14, 20),
          displayTime: 'Jun 25, 2:20 PM',
          status: TransactionStatus.settled,
          initial: 'H',
          avatarColorValue: 0xFF7928CA,
        ),
      ],
    ),
    '2026-05': MonthlyStatement(
      monthKey: '2026-05',
      title: 'May 2026',
      dateRange: 'May 01 - May 31, 2026',
      totalReceived: 62000.00,
      totalSent: 41000.00,
      transactions: [
        BankTransaction(
          id: 'TXN-MAY-01',
          reference: 'AUR-880501',
          counterparty: 'Commercial Dividend Deposit',
          type: TransactionType.incoming,
          amount: 62000.00,
          timestamp: DateTime(2026, 5, 10, 10, 00),
          displayTime: 'May 10, 10:00 AM',
          status: TransactionStatus.settled,
          initial: 'C',
          avatarColorValue: 0xFF059669,
        ),
        BankTransaction(
          id: 'TXN-MAY-02',
          reference: 'AUR-880502',
          counterparty: 'Software Enterprise Licensure',
          type: TransactionType.outgoing,
          amount: 41000.00,
          timestamp: DateTime(2026, 5, 22, 16, 00),
          displayTime: 'May 22, 4:00 PM',
          status: TransactionStatus.settled,
          initial: 'S',
          avatarColorValue: 0xFF7928CA,
        ),
      ],
    ),
    '2026-04': MonthlyStatement(
      monthKey: '2026-04',
      title: 'April 2026',
      dateRange: 'Apr 01 - Apr 30, 2026',
      totalReceived: 38000.00,
      totalSent: 22000.00,
      transactions: [
        BankTransaction(
          id: 'TXN-APR-01',
          reference: 'AUR-880401',
          counterparty: 'Executive Retained Tranche',
          type: TransactionType.incoming,
          amount: 38000.00,
          timestamp: DateTime(2026, 4, 15, 11, 30),
          displayTime: 'Apr 15, 11:30 AM',
          status: TransactionStatus.settled,
          initial: 'E',
          avatarColorValue: 0xFF059669,
        ),
        BankTransaction(
          id: 'TXN-APR-02',
          reference: 'AUR-880402',
          counterparty: 'Q2 Tax Pre-settlement',
          type: TransactionType.outgoing,
          amount: 22000.00,
          timestamp: DateTime(2026, 4, 28, 15, 15),
          displayTime: 'Apr 28, 3:15 PM',
          status: TransactionStatus.settled,
          initial: 'Q',
          avatarColorValue: 0xFF7928CA,
        ),
      ],
    ),
    '2026-03': MonthlyStatement(
      monthKey: '2026-03',
      title: 'March 2026',
      dateRange: 'Mar 01 - Mar 31, 2026',
      totalReceived: 44000.00,
      totalSent: 29500.00,
      transactions: [
        BankTransaction(
          id: 'TXN-MAR-01',
          reference: 'AUR-880301',
          counterparty: 'Treasury Disbursal Node',
          type: TransactionType.incoming,
          amount: 44000.00,
          timestamp: DateTime(2026, 3, 10, 9, 45),
          displayTime: 'Mar 10, 9:45 AM',
          status: TransactionStatus.settled,
          initial: 'T',
          avatarColorValue: 0xFF059669,
        ),
        BankTransaction(
          id: 'TXN-MAR-02',
          reference: 'AUR-880302',
          counterparty: 'BSP Statutory Amortization',
          type: TransactionType.outgoing,
          amount: 29500.00,
          timestamp: DateTime(2026, 3, 26, 14, 30),
          displayTime: 'Mar 26, 2:30 PM',
          status: TransactionStatus.settled,
          initial: 'B',
          avatarColorValue: 0xFF7928CA,
        ),
      ],
    ),
    '2026-02': MonthlyStatement(
      monthKey: '2026-02',
      title: 'February 2026',
      dateRange: 'Feb 01 - Feb 28, 2026',
      totalReceived: 36000.00,
      totalSent: 19800.00,
      transactions: [
        BankTransaction(
          id: 'TXN-FEB-01',
          reference: 'AUR-880201',
          counterparty: 'Aura Private Vault Credit',
          type: TransactionType.incoming,
          amount: 36000.00,
          timestamp: DateTime(2026, 2, 14, 11, 00),
          displayTime: 'Feb 14, 11:00 AM',
          status: TransactionStatus.settled,
          initial: 'A',
          avatarColorValue: 0xFF059669,
        ),
        BankTransaction(
          id: 'TXN-FEB-02',
          reference: 'AUR-880202',
          counterparty: 'Digital Certification Authority',
          type: TransactionType.outgoing,
          amount: 19800.00,
          timestamp: DateTime(2026, 2, 24, 16, 45),
          displayTime: 'Feb 24, 4:45 PM',
          status: TransactionStatus.settled,
          initial: 'D',
          avatarColorValue: 0xFF7928CA,
        ),
      ],
    ),
    '2026-01': MonthlyStatement(
      monthKey: '2026-01',
      title: 'January 2026',
      dateRange: 'Jan 01 - Jan 31, 2026',
      totalReceived: 55000.00,
      totalSent: 31000.00,
      transactions: [
        BankTransaction(
          id: 'TXN-JAN-01',
          reference: 'AUR-880101',
          counterparty: 'FY2026 Capital Retention',
          type: TransactionType.incoming,
          amount: 55000.00,
          timestamp: DateTime(2026, 1, 05, 10, 00),
          displayTime: 'Jan 05, 10:00 AM',
          status: TransactionStatus.settled,
          initial: 'F',
          avatarColorValue: 0xFF059669,
        ),
        BankTransaction(
          id: 'TXN-JAN-02',
          reference: 'AUR-880102',
          counterparty: 'Infrastructure Setup Fee',
          type: TransactionType.outgoing,
          amount: 31000.00,
          timestamp: DateTime(2026, 1, 22, 15, 30),
          displayTime: 'Jan 22, 3:30 PM',
          status: TransactionStatus.settled,
          initial: 'I',
          avatarColorValue: 0xFF7928CA,
        ),
      ],
    ),
  };

  // Recent Dashboard Transactions
  List<BankTransaction> get recentTransactions => [
        BankTransaction(
          id: 'TX-REC-01',
          reference: 'AUR-712891',
          counterparty: 'Angel Lou F. Yabut',
          type: TransactionType.outgoing,
          amount: 150000.00,
          timestamp: DateTime.now().subtract(const Duration(hours: 3)),
          displayTime: 'Today, 2:45 pm',
          status: TransactionStatus.settled,
          channel: 'Same Bank',
          initial: 'A',
          avatarColorValue: 0xFF2E0854,
        ),
        BankTransaction(
          id: 'TX-REC-02',
          reference: 'AUR-712892',
          counterparty: 'Mae G. Mercado',
          type: TransactionType.incoming,
          amount: 25000.00,
          timestamp: DateTime.now().subtract(const Duration(hours: 6)),
          displayTime: 'Today, 11:30 am',
          status: TransactionStatus.settled,
          channel: 'Other Bank',
          initial: 'M',
          avatarColorValue: 0xFF7928CA,
        ),
        BankTransaction(
          id: 'TX-REC-03',
          reference: 'AUR-712893',
          counterparty: 'Jessie Mae Dela Paz',
          type: TransactionType.outgoing,
          amount: 25000.00,
          timestamp: DateTime.now().subtract(const Duration(hours: 12)),
          displayTime: 'Yesterday, 4:20 pm',
          status: TransactionStatus.failed,
          channel: 'Same Bank',
          initial: 'J',
          avatarColorValue: 0xFF4F46E5,
        ),
      ];

  void toggleCardLock(int cardIndex) {
    if (cardIndex >= 0 && cardIndex < cards.length) {
      cards[cardIndex].isLocked = !cards[cardIndex].isLocked;
      notifyListeners();
    }
  }

    Future<void> initPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      user.faceIdEnabled = prefs.getBool('face_id_enabled') ?? false;
      user.fingerprintEnabled = prefs.getBool('fingerprint_enabled') ?? false;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> setFaceIdEnabled(bool enabled) async {
    user.faceIdEnabled = enabled;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('face_id_enabled', enabled);
    } catch (_) {}
  }

  Future<void> setFingerprintEnabled(bool enabled) async {
    user.fingerprintEnabled = enabled;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('fingerprint_enabled', enabled);
    } catch (_) {}
  }

  Future<void> setPushAlertsEnabled(bool enabled) async {
    user.pushAlertsEnabled = enabled;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('push_alerts_enabled', enabled);
    } catch (_) {}
  }

  void updateUserProfile({
    String? name,
    String? phoneNumber,
    String? email,
    String? address,
    String? dob,
    String? gender,
    String? civilStatus,
  }) {
    if (name != null) user.name = name;
    if (phoneNumber != null) user.phoneNumber = phoneNumber;
    if (email != null) user.email = email;
    if (address != null) user.address = address;
    if (dob != null) user.dob = dob;
    if (gender != null) user.gender = gender;
    if (civilStatus != null) user.civilStatus = civilStatus;
    notifyListeners();
  }

  // Fetch live accounts & transactions from backend database if running
  Future<void> syncWithBackend() async {
    try {
      // 1. Fetch Accounts for U1001 from Oracle / Account Service
      final accRes = await http
          .get(Uri.parse('$baseUrl/api/v1/accounts?userId=U1001'))
          .timeout(const Duration(seconds: 2));

      if (accRes.statusCode == 200) {
        final List<dynamic> accList = jsonDecode(accRes.body);
        if (accList.isNotEmpty) {
          final firstAcc = accList.first;
          final accId = firstAcc['account_id'] ?? firstAcc['accountId'];
          if (accId != null) {
            activeAccountId = accId.toString();
          }
          if (firstAcc['availableBalance'] != null) {
            availableBalance = (firstAcc['availableBalance'] as num).toDouble();
          } else if (firstAcc['available_balance'] != null) {
            availableBalance = (firstAcc['available_balance'] as num).toDouble();
          } else if (accId != null) {
            try {
              final balRes = await http
                  .get(Uri.parse('$baseUrl/api/v1/accounts/$accId/balance'))
                  .timeout(const Duration(seconds: 2));
              if (balRes.statusCode == 200) {
                final balData = jsonDecode(balRes.body);
                if (balData['available_balance'] != null) {
                  availableBalance = (balData['available_balance'] as num).toDouble();
                }
              }
            } catch (_) {}
          }
        }
      }

      // 2. Fetch Immutable Audit Records from PostgreSQL Ledger Engine
      final auditRes = await http
          .get(Uri.parse('$baseUrl/api/v1/ledger/audit'))
          .timeout(const Duration(seconds: 2));

      if (auditRes.statusCode == 200) {
        final List<dynamic> auditList = jsonDecode(auditRes.body);
        if (auditList.isNotEmpty) {
          final octStatement = statements['2026-10'];
          if (octStatement != null) {
            for (final record in auditList) {
              final txnId = record['transactionId'] ?? 'AUR-${DateTime.now().millisecondsSinceEpoch}';
              final alreadyExists = octStatement.transactions.any((t) => t.reference == txnId);
              if (!alreadyExists) {
                octStatement.transactions.insert(
                  0,
                  BankTransaction(
                    id: 'DB-$txnId',
                    reference: txnId,
                    counterparty: record['targetAccountId'] ?? 'Transfer Settlement',
                    type: TransactionType.outgoing,
                    amount: (record['amount'] as num?)?.toDouble() ?? 0.0,
                    timestamp: DateTime.now(),
                    displayTime: 'Live DB Sync',
                    status: TransactionStatus.settled,
                    initial: 'A',
                    avatarColorValue: 0xFF4A0E17,
                  ),
                );
              }
            }
          }
        }
      }
      notifyListeners();
    } catch (_) {
      // Backend/DB currently offline; retains seed test data from 03_seed_sample_data.sql
    }
  }

  // Multi-Stage Risk Analysis (Gate 0 -> XGBoost S2 -> Laya Scam & Threat Synthesis)
  Future<Map<String, dynamic>> analyzeTransferRisk({
    required String targetAccount,
    required double amount,
    String? memo,
    bool isScreenSharing = false,
    String? callState,
    String? inputMode,
    bool isEmulator = false,
    List<String>? runningPackages,
    List<String>? detectedThreats,
    bool? remoteAppActive,
    bool? activeCall,
    bool? hooking,
    bool? rooted,
    bool? isVpn,
    String? deviceId,
    bool? isPrimaryDevice,
  }) async {
    final effectiveRemote = remoteAppActive ?? isScreenSharing;
    final effectiveCall = activeCall ?? (callState != null && callState != 'IDLE');
    final payload = {
      'account_id': activeAccountId,
      'target_account_id': targetAccount,
      'amount': amount,
      'memo': memo ?? '',
      'user_id': 'U1001',
      'emulator': isEmulator,
      if (deviceId != null) 'device_id': deviceId,
      if (isPrimaryDevice != null) 'is_primary_device': isPrimaryDevice,
      if (effectiveRemote) 'remote_app_active': true,
      if (effectiveCall) 'active_call': true,
      if (hooking != null) 'hooking': hooking,
      if (rooted != null) 'rooted': rooted,
      if (isVpn != null) 'is_vpn': isVpn,
      'device_context': {
        if (runningPackages != null && runningPackages.isNotEmpty) 'running_packages': runningPackages,
        if (detectedThreats != null && detectedThreats.isNotEmpty) 'detected_threats': detectedThreats,
        if (hooking != null) 'hooking': hooking,
        if (rooted != null) 'rooted': rooted,
        if (isEmulator) 'emulator': true,
        'remote_app_active': effectiveRemote,
        'active_call': effectiveCall,
        'media_projection': {
          'is_screen_sharing': effectiveRemote,
        },
        'telephony': {
          'call_state': effectiveCall ? 'CALL_STATE_OFFHOOK' : (callState ?? 'IDLE'),
        },
        'interaction': {
          'account_input_mode': inputMode ?? 'TYPED',
        }
      }
    };

    // 1. Primary endpoint attempt
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/v1/risk/analyze'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
    } catch (_) {
      // 2. Fallback to local Docker PC if Cloud is unresponsive
      if (environment == AppEnvironment.prod && autoFallbackToLocal) {
        try {
          final fallbackRes = await http.post(
            Uri.parse('$localUrl/api/v1/risk/analyze'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          ).timeout(const Duration(seconds: 4));

          if (fallbackRes.statusCode == 200) {
            debugPrint('[AURA CLOUD FALLBACK] Cloud risk-service unavailable. Executed on local Docker PC.');
            return jsonDecode(fallbackRes.body);
          }
        } catch (_) {}
      }
    }

    return {
      'decision': 'ALLOW',
      'fraud_score': 0,
      'primary_flag': 'NORMAL_TRANSACTION',
      'advisory_tier': 'NONE',
    };
  }

  // Transfer execution with Temenos T24 CBS settlement + immutable database update
  Future<Map<String, dynamic>> executeTransfer({
    required String targetAccount,
    required String recipientName,
    required double amount,
    required String destinationBank,
    String? remarks,
    List<String>? runningPackages,
    List<String>? detectedThreats,
    bool? remoteAppActive,
    bool? activeCall,
    bool? hooking,
    bool? rooted,
    bool? isEmulator,
    bool? isVpn,
    String? deviceId,
    bool? isPrimaryDevice,
  }) async {
    final dateStr = DateTime.now().year.toString().substring(2) +
        DateTime.now().month.toString().padLeft(2, '0') +
        DateTime.now().day.toString().padLeft(2, '0');
    final fallbackRef = 'FT$dateStr${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

    final effectiveUserId = (user.email.toLowerCase().contains('juan') || activeAccountId.contains('3001'))
        ? 'usr-1001-cst-001'
        : 'U1001';

    final payload = {
      'accountId': activeAccountId,
      'targetAccountId': targetAccount,
      'amount': amount,
      'currency': 'PHP',
      'eventType': 'TRANSFER',
      'mutationType': 'TRANSFER',
      'reference': fallbackRef,
      'initiatorUserId': effectiveUserId,
      'remarks': remarks ?? 'Mobile Fund Transfer to $recipientName',
      if (deviceId != null) 'deviceId': deviceId,
      if (isPrimaryDevice != null) 'isPrimaryDevice': isPrimaryDevice,
      if (remoteAppActive != null) 'remoteAppActive': remoteAppActive,
      if (activeCall != null) 'activeCall': activeCall,
      if (hooking != null) 'hooking': hooking,
      if (rooted != null) 'rooted': rooted,
      if (isEmulator != null) 'emulator': isEmulator,
      if (isVpn != null) 'isVpn': isVpn,
      if (runningPackages != null && runningPackages.isNotEmpty) 'runningPackages': runningPackages,
      if (detectedThreats != null && detectedThreats.isNotEmpty) 'detectedThreats': detectedThreats,
    };

    final token = DeviceStorage.getAccessToken() ?? 'active_token';
    final headers = {
      'Content-Type': 'application/json',
      'X-Idempotency-Key': 'TX-${DateTime.now().millisecondsSinceEpoch}-${DateTime.now().microsecondsSinceEpoch}',
      'Authorization': 'Bearer $token',
    };

    // Candidate endpoints: Gateway (:8080) and direct Ledger Engine (:8082)
    final candidateEndpoints = [
      '$baseUrl/api/v1/ledger/transfer',
      '$baseUrl/api/v1/ledger/transfers',
      '$baseUrl/api/v1/ledger/mutate',
      'http://localhost:8082/api/v1/ledger/transfer',
      'http://localhost:8082/api/v1/ledger/mutate',
      if (environment == AppEnvironment.prod && autoFallbackToLocal) '$localUrl/api/v1/ledger/transfer',
    ];

    for (final endpoint in candidateEndpoints) {
      try {
        final response = await http.post(
          Uri.parse(endpoint),
          headers: headers,
          body: jsonEncode(payload),
        ).timeout(const Duration(seconds: 4));

        if (response.statusCode >= 200 && response.statusCode < 300) {
          final data = jsonDecode(response.body);
          final t24Ref = data['t24_reference'] ?? data['t24Reference'] ?? data['transaction_id'] ?? fallbackRef;
          final newBal = (data['balance_after'] ?? data['available_balance'] as num?)?.toDouble();
          if (newBal != null) {
            availableBalance = newBal;
          } else {
            availableBalance -= amount;
          }
          _applyLocalTransfer(amount, recipientName, t24Ref, remarks);
          return {
            'success': true,
            'reference': t24Ref,
            't24_reference': t24Ref,
            'amount': amount,
            'status': data['status'] ?? 'COMMITTED',
            'threat_category': data['threat_category'] ?? data['threatCategory'],
            'cause_of_suspicion': data['cause_of_suspicion'] ?? data['causeOfSuspicion'],
            'sar_draft_created': data['sar_draft_created'] ?? data['sarDraftCreated'] ?? false,
            'sar_report_id': data['sar_report_id'] ?? data['sarReportId'],
          };
        } else if (response.statusCode == 400 || response.statusCode == 403 || response.statusCode == 422) {
          try {
            final errData = jsonDecode(response.body);
            return {
              'success': false,
              'reference': fallbackRef,
              'failureReason': errData['message'] ?? errData['error'] ?? 'Transfer rejected by core banking (${response.statusCode})',
              'threat_category': errData['threat_category'] ?? errData['threatCategory'],
              'cause_of_suspicion': errData['cause_of_suspicion'] ?? errData['causeOfSuspicion'],
              'sar_draft_created': errData['sar_draft_created'] ?? errData['sarDraftCreated'] ?? false,
              'sar_report_id': errData['sar_report_id'] ?? errData['sarReportId'],
            };
          } catch (_) {
            return {
              'success': false,
              'reference': fallbackRef,
              'failureReason': 'Transfer rejected by core banking (${response.statusCode})',
            };
          }
        }
      } catch (_) {
        // Try next candidate endpoint
      }
    }

    // 3. Perform in-memory mutation fallback
    _applyLocalTransfer(amount, recipientName, fallbackRef, remarks);
    return {'success': true, 'reference': fallbackRef, 't24_reference': fallbackRef, 'amount': amount};
  }

  void _applyLocalTransfer(double amount, String recipientName, String ref, String? remarks) {
    availableBalance -= amount;

    // Add to October statement
    final octStatement = statements['2026-10'];
    if (octStatement != null) {
      final newTxn = BankTransaction(
        id: 'TXN-${DateTime.now().millisecondsSinceEpoch}',
        reference: ref,
        counterparty: recipientName,
        type: TransactionType.outgoing,
        amount: amount,
        timestamp: DateTime.now(),
        displayTime: 'Today, Just now',
        status: TransactionStatus.settled,
        remarks: remarks,
        initial: recipientName.isNotEmpty ? recipientName[0].toUpperCase() : 'A',
        avatarColorValue: 0xFF8B1538,
      );
      octStatement.transactions.insert(0, newTxn);
    }
    notifyListeners();
  }

  void setKycStatus(String status, {String? reason}) {
    user.kycStatus = status;
    user.kycReviewReason = reason;
    notifyListeners();
  }

  // Update customer location in Oracle XE Master (for geo-velocity & anomaly simulation)
  Future<bool> updateCustomerLocation({
    required double latitude,
    required double longitude,
    required String locationName,
    String? ipAddress,
  }) async {
    final effectiveUserId = (user.email.toLowerCase().contains('juan') || activeAccountId.contains('3001'))
        ? 'usr-1001-cst-001'
        : 'U1001';

    final payload = {
      'latitude': latitude,
      'longitude': longitude,
      'location_name': locationName,
      'ip_address': ipAddress ?? '112.198.45.10',
    };

    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer active_token',
    };

    final candidateUrls = [
      '$baseUrl/api/v1/ledger/users/$effectiveUserId/location',
      'http://localhost:8082/api/v1/ledger/users/$effectiveUserId/location',
      '$baseUrl/api/v1/users/$effectiveUserId/location',
    ];

    for (final url in candidateUrls) {
      try {
        final res = await http.post(
          Uri.parse(url),
          headers: headers,
          body: jsonEncode(payload),
        ).timeout(const Duration(seconds: 3));

        if (res.statusCode >= 200 && res.statusCode < 300) {
          debugPrint('[GEO UPDATE] Location updated to $locationName for $effectiveUserId');
          return true;
        }
      } catch (_) {}
    }
    return false;
  }
}

