class PromotionRedemption {
  final String id;
  final String promotionId;
  final String companyId;
  final String customerId;
  final int pointsSpent;
  final String status;
  final DateTime redeemedAt;
  final DateTime? usedAt;
  final DateTime createdAt;
  final String? promotionTitle;
  final String? promotionDescription;
  final String? promotionType;
  final num? discountPercentage;
  final String? giftDescription;

  final String? companyName;

  PromotionRedemption({
    required this.id,
    required this.promotionId,
    required this.companyId,
    required this.customerId,
    required this.pointsSpent,
    required this.status,
    required this.redeemedAt,
    required this.usedAt,
    required this.createdAt,
    this.promotionTitle,
    this.promotionDescription,
    this.promotionType,
    this.discountPercentage,
    this.giftDescription,
    this.companyName,
  });

  factory PromotionRedemption.fromMap(Map<String, dynamic> map,) {
    final promotion = map['promotions'] as Map<String, dynamic>?;

    final company =
        map['companies'] as Map<String, dynamic>?;

    return PromotionRedemption(
      id: map['id'] as String,
      promotionId: map['promotion_id'] as String,
      companyId: map['company_id'] as String,
      customerId: map['customer_id'] as String,
      pointsSpent:
          (map['points_spent'] as num).toInt(),
      status: map['status'] as String,
      redeemedAt:
          DateTime.parse(map['redeemed_at'] as String),
      usedAt: map['used_at'] != null
          ? DateTime.parse(map['used_at'] as String)
          : null,
      createdAt:
          DateTime.parse(map['created_at'] as String),

      promotionTitle:
          promotion?['title'] as String?,

      promotionDescription:
          promotion?['description'] as String?,

      promotionType:
          promotion?['type'] as String?,

      discountPercentage:
          promotion?['discount_percentage'] as num?,

      giftDescription:
          promotion?['gift_description'] as String?,

      companyName:
          company?['name'] as String?,
    );

  }

  bool get isAvailable => status == 'available';

  bool get isUsed => status == 'used';

  bool get isCancelled => status == 'cancelled';

  String get rewardText {
    if (promotionType == 'discount' && discountPercentage != null) {
      return '${discountPercentage!.toStringAsFixed(0)}% de desconto';
    }

    if (promotionType == 'gift' && giftDescription != null) {
      return giftDescription!;
    }

    return promotionTitle ?? 'Benefício';

  }

  String get statusText {
    switch (status) {
      case 'available':
        return 'Disponível';

      case 'used':
        return 'Utilizado';

      case 'cancelled':
        return 'Cancelado';

      default:
        return status;
      }
    }
}
