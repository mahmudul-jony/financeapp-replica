class Wallet {
  final int? id;
  final String name;
  double balance;
  double frozenAmount;
  final int color;
  final bool isDefault;
  final bool isArchived;

  Wallet({
    this.id,
    required this.name,
    required this.balance,
    this.frozenAmount = 0.0,
    required this.color,
    this.isDefault = false,
    this.isArchived = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'balance': balance,
      'frozen_amount': frozenAmount,
      'color': color,
      'isDefault': isDefault ? 1 : 0,
      'is_archived': isArchived ? 1 : 0,
    };
  }

  factory Wallet.fromMap(Map<String, dynamic> map) {
    return Wallet(
      id: map['id'],
      name: map['name'],
      balance: (map['balance'] as num).toDouble(),
      frozenAmount: (map['frozen_amount'] as num? ?? 0.0).toDouble(),
      color: map['color'],
      isDefault: map['isDefault'] == 1,
      isArchived: map['is_archived'] == 1,
    );
  }
}
