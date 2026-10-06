enum TransactionType { incoming, outgoing }

enum TransactionStatus { settled, completed, inward, failed }

class BankTransaction {
  final String id;
  final String reference;
  final String counterparty;
  final TransactionType type;
  final double amount;
  final DateTime timestamp;
  final String displayTime;
  final TransactionStatus status;
  final String? remarks;
  final String initial;
  final int avatarColorValue;

  const BankTransaction({
    required this.id,
    required this.reference,
    required this.counterparty,
    required this.type,
    required this.amount,
    required this.timestamp,
    required this.displayTime,
    required this.status,
    this.remarks,
    required this.initial,
    required this.avatarColorValue,
  });

  bool get isIncoming => type == TransactionType.incoming;

  String get formattedAmount {
    final absAmount = amount.abs().toStringAsFixed(2);
    // Add comma formatting
    final parts = absAmount.split('.');
    final intPart = parts[0].replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
    final sign = isIncoming ? '+' : '-';
    return '$sign₱$intPart.${parts[1]}';
  }

  String get plainFormattedAmount {
    final absAmount = amount.abs().toStringAsFixed(2);
    final parts = absAmount.split('.');
    final intPart = parts[0].replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
    return '₱$intPart.${parts[1]}';
  }

  String get statusDisplay {
    switch (status) {
      case TransactionStatus.settled:
        return isIncoming ? 'Transfer Received' : 'Transfer Sent';
      case TransactionStatus.completed:
        return 'COMPLETED';
      case TransactionStatus.inward:
        return 'Intrabank Inward';
      case TransactionStatus.failed:
        return 'Failed';
    }
  }

  factory BankTransaction.fromJson(Map<String, dynamic> json) {
    return BankTransaction(
      id: json['id'] ?? '',
      reference: json['reference'] ?? 'AUR-000000',
      counterparty: json['counterparty'] ?? 'Unknown',
      type: json['type'] == 'IN' ? TransactionType.incoming : TransactionType.outgoing,
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      timestamp: DateTime.tryParse(json['timestamp'] ?? '') ?? DateTime.now(),
      displayTime: json['displayTime'] ?? '',
      status: _parseStatus(json['status']),
      remarks: json['remarks'],
      initial: (json['counterparty'] as String?)?.isNotEmpty == true
          ? (json['counterparty'] as String)[0].toUpperCase()
          : 'A',
      avatarColorValue: json['avatarColorValue'] ?? 0xFF4A0E17,
    );
  }

  static TransactionStatus _parseStatus(dynamic s) {
    if (s == 'FAILED') return TransactionStatus.failed;
    if (s == 'INWARD') return TransactionStatus.inward;
    if (s == 'COMPLETED') return TransactionStatus.completed;
    return TransactionStatus.settled;
  }
}

class BankCard {
  final String id;
  final String title;
  final String cardNumber;
  final String expiry;
  final String cvv;
  final String holderName;
  bool isLocked;
  final int gradientStart;
  final int gradientEnd;

  BankCard({
    required this.id,
    required this.title,
    required this.cardNumber,
    required this.expiry,
    required this.cvv,
    required this.holderName,
    this.isLocked = false,
    required this.gradientStart,
    required this.gradientEnd,
  });

  String get maskedCardNumber {
    final clean = cardNumber.replaceAll(' ', '');
    if (clean.length < 4) return '•••• •••• •••• ••••';
    final last4 = clean.substring(clean.length - 4);
    return '•••• •••• •••• $last4';
  }
}

class MonthlyStatement {
  final String monthKey; // e.g. "2026-10"
  final String title; // "October 2026"
  final String dateRange; // "Oct 01 - Oct 31, 2026"
  final double totalReceived;
  final double totalSent;
  final List<BankTransaction> transactions;

  const MonthlyStatement({
    required this.monthKey,
    required this.title,
    required this.dateRange,
    required this.totalReceived,
    required this.totalSent,
    required this.transactions,
  });

  int get allCount => transactions.length;
  int get inCount => transactions.where((t) => t.isIncoming).length;
  int get outCount => transactions.where((t) => !t.isIncoming).length;
}

class UserProfile {
  String name;
  String phoneNumber;
  String email;
  String address;
  String dob;
  String gender;
  String civilStatus;
  bool faceIdEnabled;
  bool fingerprintEnabled;
  bool pushAlertsEnabled;

  UserProfile({
    required this.name,
    required this.phoneNumber,
    required this.email,
    required this.address,
    required this.dob,
    required this.gender,
    required this.civilStatus,
    this.faceIdEnabled = true,
    this.fingerprintEnabled = true,
    this.pushAlertsEnabled = true,
  });
}
