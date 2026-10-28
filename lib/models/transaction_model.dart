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
  savingsWithdrawal
}

class TransactionModel {
  final int? id;
  final String syncId;
  final String title;
  final double amount;
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
    required this.amount,
    required this.date,
    required this.note,
    required this.type,
    required this.walletId,
    this.toWalletId,
    this.categoryId,
    this.syncStatus = 'synced',
    this.updatedAt,
  }) : syncId = (syncId != null && syncId.trim().isNotEmpty)
            ? syncId.trim()
            : (id != null ? formatSyncId(id) : '');

  static String formatSyncId(int id) {
    return 'txid_${id.toString().padLeft(6, '0')}';
  }

  TransactionModel copyWith({
    int? id,
    String? syncId,
    String? title,
    double? amount,
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
    return TransactionModel(
      id: effectiveId,
      syncId: syncId ?? (this.syncId.isNotEmpty ? this.syncId : (effectiveId != null ? formatSyncId(effectiveId) : '')),
      title: title ?? this.title,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      note: note ?? this.note,
      type: type ?? this.type,
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
        return 'Money Added';
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
      'amount': amount,
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

    return TransactionModel(
      id: id,
      syncId: sId,
      title: map['title'] ?? '',
      amount: (map['amount'] as num).toDouble(),
      date: DateTime.parse(map['date']),
      note: map['note'] ?? '',
      type: TransactionType.values.byName(map['type']),
      walletId: map['walletId'],
      toWalletId: map['toWalletId'],
      categoryId: map['categoryId'],
      syncStatus: map['sync_status'] ?? 'synced',
      updatedAt: map['updated_at'] != null ? DateTime.tryParse(map['updated_at'].toString()) : null,
    );
  }
}
