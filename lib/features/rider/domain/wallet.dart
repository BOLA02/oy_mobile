enum TxType { credit, debit }

enum TxStatus { pending, completed, failed }

class WalletTx {
  const WalletTx({
    required this.id,
    required this.amount,
    required this.type,
    required this.status,
    required this.description,
    required this.createdAt,
    this.orderId,
  });

  final String id;
  final double amount;
  final TxType type;
  final TxStatus status;
  final String description;
  final DateTime createdAt;
  final int? orderId;

  /// Money that really reached the wallet: a completed credit.
  bool get isEarning => type == TxType.credit && status == TxStatus.completed;

  factory WalletTx.fromJson(Map<String, dynamic> j) => WalletTx(
        id: '${j['id']}',
        amount: (j['amount'] as num?)?.toDouble() ?? 0,
        type: j['type'] == 'debit' ? TxType.debit : TxType.credit,
        status: switch (j['status']) {
          'completed' => TxStatus.completed,
          'failed' => TxStatus.failed,
          _ => TxStatus.pending,
        },
        description: '${j['description'] ?? ''}',
        createdAt: DateTime.tryParse('${j['createdAt']}')?.toLocal() ?? DateTime.now(),
        orderId: (j['orderId'] as num?)?.toInt(),
      );
}

class DayEarning {
  const DayEarning(this.day, this.amount);

  final DateTime day;
  final double amount;
}

class WalletSummary {
  const WalletSummary({
    required this.balance,
    required this.pendingPayouts,
    required this.transactions,
    required this.hasBankDetails,
    required this.bankVerified,
    required this.linkedBankAccount,
  });

  /// Withdrawable money.
  final double balance;

  /// Withdrawals requested and awaiting the admin's transfer.
  final double pendingPayouts;
  final List<WalletTx> transactions;
  final bool hasBankDetails;
  final bool bankVerified;
  final String linkedBankAccount;

  /// Only a verified account can be paid; the server blocks the rest.
  bool get canWithdraw => hasBankDetails && bankVerified && balance > 0;

  /// Why the withdraw button is off, or null when it is on.
  String? get withdrawBlockedReason {
    if (balance <= 0) return 'Nothing to withdraw yet.';
    if (!hasBankDetails) {
      return linkedBankAccount.startsWith('Not setup')
          ? 'Add a bank account by emailing support.'
          : 'Your bank account is waiting for verification.';
    }
    return null;
  }

  double earnedSince(DateTime from) =>
      transactions.where((t) => t.isEarning && !t.createdAt.isBefore(from)).fold(0, (s, t) => s + t.amount);

  static DateTime _midnight(DateTime d) => DateTime(d.year, d.month, d.day);

  double today(DateTime now) => earnedSince(_midnight(now));

  /// The server's week starts on Sunday, so this matches the figures the rider
  /// sees elsewhere.
  double thisWeek(DateTime now) {
    final midnight = _midnight(now);
    return earnedSince(midnight.subtract(Duration(days: now.weekday % 7)));
  }

  /// Earnings for each of the last seven days, oldest first, ending today.
  List<DayEarning> lastSevenDays(DateTime now) {
    final today = _midnight(now);
    return [
      for (var i = 6; i >= 0; i--)
        () {
          final start = DateTime(today.year, today.month, today.day - i);
          final end = DateTime(today.year, today.month, today.day - i + 1);
          final sum = transactions
              .where((t) => t.isEarning && !t.createdAt.isBefore(start) && t.createdAt.isBefore(end))
              .fold<double>(0, (s, t) => s + t.amount);
          return DayEarning(start, sum);
        }(),
    ];
  }

  factory WalletSummary.fromJson(Map<String, dynamic> data) {
    final wallet = (data['wallet'] as Map<String, dynamic>?) ?? const {};
    final txs = wallet['transactions'];
    return WalletSummary(
      balance: (wallet['balance'] as num?)?.toDouble() ?? 0,
      pendingPayouts: (wallet['pendingPayouts'] as num?)?.toDouble() ?? 0,
      transactions: txs is List ? txs.whereType<Map<String, dynamic>>().map(WalletTx.fromJson).toList() : const [],
      hasBankDetails: data['hasBankDetails'] == true,
      bankVerified: data['bankVerified'] == true,
      linkedBankAccount: '${data['linkedBankAccount'] ?? ''}',
    );
  }
}
