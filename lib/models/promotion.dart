class Promotion {
  final String id;
  final String companyId;
  final String title;
  final String? description;
  final String type;
  final int pointsRequired;
  final double? discountPercentage;
  final String? giftDescription;

  final DateTime? startsAt;
  final DateTime? endsAt;

  Promotion({
    required this.id,
    required this.companyId,
    required this.title,
    this.description,
    required this.type,
    required this.pointsRequired,
    this.discountPercentage,
    this.giftDescription,
    this.startsAt,
    this.endsAt,
  });

  factory Promotion.fromMap(
    Map<String, dynamic> map,
  ) {
    return Promotion(
      id: map['id'] as String,
      companyId: map['company_id'] as String,
      title: map['title'] as String,
      description:
          map['description'] as String?,
      type: map['type'] as String,
      pointsRequired:
          map['points_required'] as int,

      discountPercentage:
          map['discount_percentage'] != null
              ? (map['discount_percentage'] as num)
                  .toDouble()
              : null,

      giftDescription:
          map['gift_description'] as String?,

      startsAt:
          map['starts_at'] != null
              ? DateTime.tryParse(
                  map['starts_at'].toString(),
                )
              : null,

      endsAt:
          map['ends_at'] != null
              ? DateTime.tryParse(
                  map['ends_at'].toString(),
                )
              : null,
    );
  }
}