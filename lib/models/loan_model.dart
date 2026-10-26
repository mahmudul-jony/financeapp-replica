import 'package:financeapp/models/transaction_model.dart';

enum LoanTransactionType { give, recover, take, repay }

class LoanRecipient {
  final int? id;
  final String name;
  double totalAmount; // Positive for given, can also use for taken (maybe separate or signed)
  final bool isDebt; // true if it's a loan taken (we owe money)

  LoanRecipient({
    this.id,
    required this.name,
    required this.totalAmount,
    this.isDebt = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'totalAmount': totalAmount,
      'isDebt': isDebt ? 1 : 0,
    };
  }

  factory LoanRecipient.fromMap(Map<String, dynamic> map) {
    return LoanRecipient(
      id: map['id'],
      name: map['name'],
      totalAmount: (map['totalAmount'] as num).toDouble(),
      isDebt: map['isDebt'] == 1,
    );
  }
}

class LoanTransaction {
  final int? id;
  final int recipientId;
  final double amount;
  final LoanTransactionType type;
  final int walletId;
  final DateTime date;
  final String note;

  LoanTransaction({
    this.id,
    required this.recipientId,
    required this.amount,
    required this.type,
    required this.walletId,
    required this.date,
    required this.note,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'recipientId': recipientId,
      'amount': amount,
      'type': type.name,
      'walletId': walletId,
      'date': date.toIso8601String(),
      'note': note,
    };
  }

  factory LoanTransaction.fromMap(Map<String, dynamic> map) {
    return LoanTransaction(
      id: map['id'],
      recipientId: map['recipientId'],
      amount: (map['amount'] as num).toDouble(),
      type: LoanTransactionType.values.byName(map['type']),
      walletId: map['walletId'],
      date: DateTime.parse(map['date']),
      note: map['note'] ?? '',
    );
  }

  TransactionModel toTransactionModel(String recipientName) {
    TransactionType txType;
    String titlePrefix;
    switch (type) {
      case LoanTransactionType.give:
        txType = TransactionType.loanGiven;
        titlePrefix = "Loan Given";
        break;
      case LoanTransactionType.recover:
        txType = TransactionType.loanRecovered;
        titlePrefix = "Loan Recovered";
        break;
      case LoanTransactionType.take:
        txType = TransactionType.loanTaken;
        titlePrefix = "Loan Taken";
        break;
      case LoanTransactionType.repay:
        txType = TransactionType.loanRepaid;
        titlePrefix = "Loan Repaid";
        break;
    }

    return TransactionModel(
      title: "$titlePrefix · $recipientName",
      amount: amount,
      date: date,
      note: note,
      type: txType,
      walletId: walletId,
    );
  }
}
