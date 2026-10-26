import 'package:financeapp/models/transaction_model.dart';

enum SavingsTransactionType { deposit, withdraw }

class Savings {
  final int? id;
  final String title;
  double amount;
  final DateTime date;
  final String note;

  Savings({
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

  factory Savings.fromMap(Map<String, dynamic> map) {
    return Savings(
      id: map['id'],
      title: map['title'],
      amount: (map['amount'] as num).toDouble(),
      date: DateTime.parse(map['date']),
      note: map['note'] ?? '',
    );
  }
}

class SavingsTransaction {
  final int? id;
  final int savingsId;
  final double amount;
  final SavingsTransactionType type;
  final int walletId;
  final DateTime date;
  final String note;

  SavingsTransaction({
    this.id,
    required this.savingsId,
    required this.amount,
    required this.type,
    required this.walletId,
    required this.date,
    required this.note,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'savingsId': savingsId,
      'amount': amount,
      'type': type.name,
      'walletId': walletId,
      'date': date.toIso8601String(),
      'note': note,
    };
  }

  factory SavingsTransaction.fromMap(Map<String, dynamic> map) {
    return SavingsTransaction(
      id: map['id'],
      savingsId: map['savingsId'],
      amount: (map['amount'] as num).toDouble(),
      type: SavingsTransactionType.values.byName(map['type']),
      walletId: map['walletId'],
      date: DateTime.parse(map['date']),
      note: map['note'] ?? '',
    );
  }

  TransactionModel toTransactionModel({bool isMore = false}) {
    TransactionType txType;
    String title;
    switch (type) {
      case SavingsTransactionType.deposit:
        txType = isMore ? TransactionType.savingsIncreased : TransactionType.savingsCreated;
        title = isMore ? "Savings Increased" : "Savings Created";
        break;
      case SavingsTransactionType.withdraw:
        txType = TransactionType.savingsWithdrawal;
        title = "Savings Withdrawn";
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
