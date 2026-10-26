enum CategoryType { income, expense }

class Category {
  final int? id;
  final String name;
  final int iconCode;
  final CategoryType type;
  final bool isArchived;

  Category({
    this.id,
    required this.name,
    required this.iconCode,
    required this.type,
    this.isArchived = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'iconCode': iconCode,
      'type': type.name,
      'is_archived': isArchived ? 1 : 0,
    };
  }

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'],
      name: map['name'],
      iconCode: map['iconCode'],
      type: CategoryType.values.byName(map['type']),
      isArchived: map['is_archived'] == 1,
    );
  }
}
