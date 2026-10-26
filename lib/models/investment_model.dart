import 'package:financeapp/models/transaction_model.dart';

enum InvestmentTransactionType { invest, profit, withdraw, expense, adjustment }

class Investment {
  final int? id;
  final String title;
  double amount;
  final DateTime date;
  final String note;

  Investment({
    this.id,
    required this.title,
    required this.amount,
    required this.date,
    required this.note,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'date': date.toIso8601String(),
      'note': note,
    };
  }

  factory Investment.fromMap(Map<String, dynamic> map) {
    return Investment(
      id: map['id'],
      title: map['title'],
      amount: (map['amount'] as num).toDouble(),
      date: DateTime.parse(map['date']),
      note: map['note'] ?? '',
    );
  }
}

class InvestmentTransaction {
  final int? id;
  final int investmentId;
  final double amount;
  final InvestmentTransactionType type;
  final int walletId;
  final DateTime date;
  final String note;

  InvestmentTransaction({
    this.id,
    required this.investmentId,
    required this.amount,
    required this.type,
    required this.walletId,
    required this.date,
    required this.note,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'investmentId': investmentId,
      'amount': amount,
      'type': type.name,
      'walletId': walletId,
      'date': date.toIso8601String(),
      'note': note,
    };
  }

  factory InvestmentTransaction.fromMap(Map<String, dynamic> map) {
    return InvestmentTransaction(
      id: map['id'],
      investmentId: map['investmentId'],
      amount: (map['amount'] as num).toDouble(),
      type: InvestmentTransactionType.values.byName(map['type']),
      walletId: map['walletId'],
      date: DateTime.parse(map['date']),
      note: map['note'] ?? '',
    );
  }

  TransactionModel toTransactionModel(String investmentTitle, {bool isMore = false}) {
    TransactionType txType;
    String title;
    switch (type) {
      case InvestmentTransactionType.invest:
        txType = isMore ? TransactionType.investmentIncreased : TransactionType.investmentCreated;
        title = isMore ? "Investment Increased" : "Investment Created";
        break;
      case InvestmentTransactionType.profit:
        txType = TransactionType.investmentProfit;
        title = "Profit Added";
        break;
      case InvestmentTransactionType.withdraw:
        txType = TransactionType.investmentWithdraw;
        title = "Investment Withdrawn";
        break;
      case InvestmentTransactionType.expense:
        txType = TransactionType.investmentExpense;
        title = "Investment Expense";
        break;
      case InvestmentTransactionType.adjustment:
        txType = TransactionType.investmentAdjustment;
        title = "Investment Adjustment";
        break;
    }

    return TransactionModel(
      title: title,
      amount: amount,
      date: date,
      note: note,
      type: txType,
      walletId: walletId,
    );
  }
}
