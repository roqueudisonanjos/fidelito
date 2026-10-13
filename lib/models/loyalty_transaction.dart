class LoyaltyTransaction {
  final String id;
  final String companyId;
  final String type;
  final int points;
  final String? description;
  final DateTime createdAt;

  LoyaltyTransaction({
    required this.id,
    required this.companyId,
    required this.type,
    required this.points,
    this.description,
    required this.createdAt,
  });

  factory LoyaltyTransaction.fromMap(
    Map<String, dynamic> map,
  ) {
    return LoyaltyTransaction(
      id: map['id'] as String,
      companyId:
          map['company_id'] as String,
      type: map['type'] as String,
      points: map['points'] as int,
      description:
          map['description'] as String?,
      createdAt:
          DateTime.parse(
        map['created_at'] as String,
      ),
    );
  }
}