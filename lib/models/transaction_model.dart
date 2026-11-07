enum TransactionType {
  income,
  expense,
  transfer,
  loanGiven,
  loanGivenMore,
  loanRecovered,
  loanTaken,
  loanTakenMore,
  loanRepaid,
  investmentCreated,
  investmentIncreased,
  investmentProfit,
  investmentWithdraw,
  investmentExpense,
  investmentAdjustment,
  savingsCreated,
  savingsIncreased,
  savingsWithdrawal,
  cashWithdrawal
}

class TransactionModel {
  final int? id;
  final String syncId;
  final String title;
  final double debit;
  final double credit;
  final double total;
  final DateTime date;
  final String note;
  final TransactionType type;
  final int walletId;
  final int? toWalletId;
  final int? categoryId;
  final String syncStatus; // 'synced', 'pending', 'pending_delete'
  final DateTime? updatedAt;

  TransactionModel({
    this.id,
    String? syncId,
    required this.title,
    double? amount,
    double? debit,
    double? credit,
    this.total = 0.0,
    required this.date,
    required this.note,
    required this.type,
    required this.walletId,
    this.toWalletId,
    this.categoryId,
    this.syncStatus = 'synced',
    this.updatedAt,
  })  : debit = debit ?? (amount != null && isDebitType(type) ? amount : 0.0),
        credit = credit ?? (amount != null && !isDebitType(type) ? amount : 0.0),
        syncId = (syncId != null && syncId.trim().isNotEmpty)
            ? syncId.trim()
            : (id != null ? formatSyncId(id) : '');

  static bool isDebitType(TransactionType type) {
    switch (type) {
      case TransactionType.expense:
      case TransactionType.transfer:
      case TransactionType.cashWithdrawal:
      case TransactionType.loanGiven:
      case TransactionType.loanGivenMore:
      case TransactionType.loanRepaid:
      case TransactionType.investmentCreated:
      case TransactionType.investmentIncreased:
      case TransactionType.investmentExpense:
      case TransactionType.investmentAdjustment:
      case TransactionType.savingsCreated:
      case TransactionType.savingsIncreased:
        return true;
      case TransactionType.income:
      case TransactionType.loanRecovered:
      case TransactionType.loanTaken:
      case TransactionType.loanTakenMore:
      case TransactionType.investmentProfit:
      case TransactionType.investmentWithdraw:
      case TransactionType.savingsWithdrawal:
        return false;
    }
  }

  static bool isCreditType(TransactionType type) => !isDebitType(type);

  bool get isDebit => isDebitType(type);
  bool get isCredit => !isDebit;
  double get amount => credit > 0 ? credit : debit;

  static String formatSyncId(int id) {
    return 'txid_${id.toString().padLeft(6, '0')}';
  }

  TransactionModel copyWith({
    int? id,
    String? syncId,
    String? title,
    double? amount,
    double? debit,
    double? credit,
    double? total,
    DateTime? date,
    String? note,
    TransactionType? type,
    int? walletId,
    int? toWalletId,
    int? categoryId,
    String? syncStatus,
    DateTime? updatedAt,
  }) {
    final effectiveId = id ?? this.id;
    final effectiveType = type ?? this.type;
    double effectiveDebit = debit ?? this.debit;
    double effectiveCredit = credit ?? this.credit;
    if (amount != null && debit == null && credit == null) {
      if (isDebitType(effectiveType)) {
        effectiveDebit = amount;
        effectiveCredit = 0.0;
      } else {
        effectiveCredit = amount;
        effectiveDebit = 0.0;
      }
    }
    return TransactionModel(
      id: effectiveId,
      syncId: syncId ?? (this.syncId.isNotEmpty ? this.syncId : (effectiveId != null ? formatSyncId(effectiveId) : '')),
      title: title ?? this.title,
      debit: effectiveDebit,
      credit: effectiveCredit,
      total: total ?? this.total,
      date: date ?? this.date,
      note: note ?? this.note,
      type: effectiveType,
      walletId: walletId ?? this.walletId,
      toWalletId: toWalletId ?? this.toWalletId,
      categoryId: categoryId ?? this.categoryId,
      syncStatus: syncStatus ?? this.syncStatus,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  String get displayLabel {
    switch (type) {
      case TransactionType.income:
        return 'Diposit';
      case TransactionType.expense:
        return 'Expense';
      case TransactionType.transfer:
        return 'Transferred';
      case TransactionType.loanGiven:
        return 'Loan Given · ${_extractName(title)}';
      case TransactionType.loanGivenMore:
        return 'More Loan Given · ${_extractName(title)}';
      case TransactionType.loanRecovered:
        return 'Loan Recovered · ${_extractName(title)}';
      case TransactionType.loanTaken:
        return 'Loan Taken · ${_extractName(title)}';
      case TransactionType.loanTakenMore:
        return 'More Loan Taken · ${_extractName(title)}';
      case TransactionType.loanRepaid:
        return 'Loan Repaid · ${_extractName(title)}';
      case TransactionType.investmentCreated:
        return 'Investment Created';
      case TransactionType.investmentIncreased:
        return 'Investment Increased';
      case TransactionType.investmentProfit:
        return 'Profit Added';
      case TransactionType.investmentWithdraw:
        return 'Investment Withdrawn';
      case TransactionType.investmentExpense:
        return 'Investment Expense';
      case TransactionType.investmentAdjustment:
        return 'Investment Adjustment';
      case TransactionType.savingsCreated:
        return 'Savings Created';
      case TransactionType.savingsIncreased:
        return 'Savings Increased';
      case TransactionType.savingsWithdrawal:
        return 'Savings Withdrawn';
      case TransactionType.cashWithdrawal:
        return 'Withdraw';
    }
  }

  String _extractName(String fullTitle) {
    if (fullTitle.contains(': ')) {
      return fullTitle.split(': ').last;
    }
    if (fullTitle.contains('· ')) {
      return fullTitle.split('· ').last;
    }
    return fullTitle;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sync_id': syncId.isNotEmpty ? syncId : (id != null ? formatSyncId(id!) : null),
      'title': title,
      'debit': debit,
      'credit': credit,
      'total': total,
      'date': "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}",
      'note': note,
      'type': type.name,
      'walletId': walletId,
      'toWalletId': toWalletId,
      'categoryId': categoryId,
      'sync_status': syncStatus,
      'updated_at': (updatedAt ?? DateTime.now()).toIso8601String(),
    };
  }

  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    final int? id = map['id'];
    String sId = map['sync_id']?.toString() ?? '';
    if (sId.isEmpty && id != null) {
      sId = formatSyncId(id);
    }

    final rawType = TransactionType.values.byName(map['type']);
    double debit = (map['debit'] as num?)?.toDouble() ?? 0.0;
    double credit = (map['credit'] as num?)?.toDouble() ?? 0.0;
    final double total = (map['total'] as num?)?.toDouble() ?? 0.0;

    // Backward compatibility if loading old records with amount
    if (debit == 0.0 && credit == 0.0 && map['amount'] != null) {
      final amt = (map['amount'] as num).toDouble();
      if (isDebitType(rawType)) {
        debit = amt;
      } else {
        credit = amt;
      }
    }

    return TransactionModel(
      id: id,
      syncId: sId,
      title: map['title'] ?? '',
      debit: debit,
      credit: credit,
      total: total,
      date: DateTime.parse(map['date']),
      note: map['note'] ?? '',
      type: rawType,
      walletId: map['walletId'],
      toWalletId: map['toWalletId'],
      categoryId: map['categoryId'],
      syncStatus: map['sync_status'] ?? 'synced',
      updatedAt: map['updated_at'] != null ? DateTime.tryParse(map['updated_at'].toString()) : null,
    );
  }
}
