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
  final String title; // Added title
  final double amount;
  final DateTime date;
  final String note;
  final TransactionType type;
  final int walletId;
  final int? toWalletId;
  final int? categoryId;

  TransactionModel({
    this.id,
    required this.title,
    required this.amount,
    required this.date,
    required this.note,
    required this.type,
    required this.walletId,
    this.toWalletId,
    this.categoryId,
  });

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
      'title': title,
      'amount': amount,
      'date': "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}",
      'note': note,
      'type': type.name,
      'walletId': walletId,
      'toWalletId': toWalletId,
      'categoryId': categoryId,
    };
  }

  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    return TransactionModel(
      id: map['id'],
      title: map['title'] ?? '',
      amount: (map['amount'] as num).toDouble(),
      date: DateTime.parse(map['date']),
      note: map['note'] ?? '',
      type: TransactionType.values.byName(map['type']),
      walletId: map['walletId'],
      toWalletId: map['toWalletId'],
      categoryId: map['categoryId'],
    );
  }
}
