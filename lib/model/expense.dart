class Expense {
  final String id;
  final String userId;
  final String description;
  final double amount;

  Expense({required this.id, required this.userId, required this.description, required this.amount});

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'description': description,
      'amount': amount,
    };
  }

  factory Expense.fromMap(String id, Map<String, dynamic> map) {
    return Expense(
      id: id,
      userId: map['userId'] ?? '',
      description: map['description'] ?? '',
      amount: (map['amount'] is int ? (map['amount'] as int).toDouble() : map['amount']) ?? 0.0,
    );
  }
}