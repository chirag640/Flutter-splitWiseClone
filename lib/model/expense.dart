class Expense {
  final String id;
  final String userId;
  final String description;
  final double amount;

  Expense({required this.id, required this.userId, required this.description, required this.amount});

  Map<String, dynamic> toMap() {
    return {
      // Persist as 'createdBy' for consistency with other parts of the app
      'createdBy': userId,
      'description': description,
      'amount': amount,
    };
  }

  factory Expense.fromMap(String id, Map<String, dynamic> map) {
    return Expense(
      id: id,
      // Support multiple possible field names when reading existing docs
      userId: (map['userId'] ?? map['createdBy'] ?? map['paidBy'] ?? '') as String,
      description: map['description'] ?? '',
      amount: _parseAmount(map['amount']),
    );
  }
  
  static double _parseAmount(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      return double.tryParse(value) ?? 0.0;
    }
    return 0.0;
  }
}