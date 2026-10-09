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
  final String? channel;
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
    this.channel,
    required this.initial,
    required this.avatarColorValue,
  });

  bool get isIncoming => type == TransactionType.incoming;

  String get channelName => channel ?? (status == TransactionStatus.inward ? 'Other Bank' : 'Same Bank');

  String get transferSubtitle {
    if (status == TransactionStatus.failed) {
      return '$channelName Transfer • Failed';
    }
    return '$channelName Transfer • Settled';
  }

  String get formattedIntegerAmount {
    final absAmount = amount.abs().toStringAsFixed(0);
    return absAmount.replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

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
        return '$channelName Transfer • Settled';
      case TransactionStatus.completed:
        return '$channelName Transfer • Completed';
      case TransactionStatus.inward:
        return 'Other Bank Transfer • Settled';
      case TransactionStatus.failed:
        return '$channelName Transfer • Failed';
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
      channel: json['channel'] ?? (json['status'] == 'INWARD' ? 'Other Bank' : 'Same Bank'),
      initial: (json['counterparty'] as String?)?.isNotEmpty == true
          ? (json['counterparty'] as String)[0].toUpperCase()
          : 'A',
      avatarColorValue: json['avatarColorValue'] ?? 0xFF10171C,
    );
  }

  static TransactionStatus _parseStatus(dynamic s) {
    if (s == 'FAILED') return TransactionStatus.failed;
    if (s == 'INWARD') return TransactionStatus.inward;
    if (s == 'COMPLETED') return TransactionStatus.completed;
    return TransactionStatus.settled;
  }
}

enum CardNetwork {
  visa('Visa'),
  mastercard('Mastercard');

  const CardNetwork(this.label);
  final String label;
}

/// A debit card drawn on the customer's savings account. Aura issues no
/// credit products, so every card spends from the same balance.
class BankCard {
  final String id;
  final String title;
  final String cardNumber;
  final String expiry;
  final String cvv;
  final String holderName;
  final CardNetwork network;
  final bool isVirtual;
  bool isLocked;

  BankCard({
    required this.id,
    required this.title,
    required this.cardNumber,
    required this.expiry,
    required this.cvv,
    required this.holderName,
    required this.network,
    this.isVirtual = false,
    this.isLocked = false,
  });

  String get last4 {
    final clean = cardNumber.replaceAll(' ', '');
    return clean.length < 4 ? '••••' : clean.substring(clean.length - 4);
  }

  String get maskedCardNumber => '•••• •••• •••• $last4';

  String get kindLabel => isVirtual ? 'Virtual debit' : 'Debit';
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
  String kycStatus;
  String? kycReviewReason;

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
    this.kycStatus = 'UNVERIFIED',
    this.kycReviewReason,
  });

  bool get isKycVerified => kycStatus.toUpperCase() == 'VERIFIED' || kycStatus.toUpperCase() == 'ACTIVE';
}
