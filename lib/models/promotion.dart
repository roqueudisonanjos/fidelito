class Promotion {
  final String id;
  final String companyId;
  final String? companyName;
  final String? companyLogoUrl;
  final String title;
  final String? description;
  final String type;
  final int pointsRequired;
  final double? discountPercentage;
  final String? giftDescription;
  final String? imageUrl;
  final List<String> mediaUrls;

  final DateTime? startsAt;
  final DateTime? endsAt;

  Promotion({
    required this.id,
    required this.companyId,
    this.companyName,
    this.companyLogoUrl,
    required this.title,
    this.description,
    required this.type,
    required this.pointsRequired,
    this.discountPercentage,
    this.giftDescription,
    this.imageUrl,
    this.mediaUrls = const [],
    this.startsAt,
    this.endsAt,
  });

  factory Promotion.fromMap(Map<String, dynamic> map) {
    return Promotion(
      id: map['id'] as String,
      companyId: map['company_id'] as String,
      companyName:
          map['company_name']?.toString() ??
          (map['companies'] is Map
              ? (map['companies'] as Map)['name']?.toString()
              : null),
      companyLogoUrl:
          map['company_logo_url']?.toString() ??
          (map['companies'] is Map
              ? (map['companies'] as Map)['logo_url']?.toString()
              : null),
      title: map['title'] as String,
      description: map['description'] as String?,
      type: map['type'] as String,
      pointsRequired: map['points_required'] as int,

      discountPercentage: map['discount_percentage'] != null
          ? (map['discount_percentage'] as num).toDouble()
          : null,

      giftDescription: map['gift_description'] as String?,
      imageUrl: map['image_url']?.toString(),
      mediaUrls: map['media_urls'] is List ? List<String>.from(map['media_urls'] as List) : (map['image_url'] == null ? const [] : [map['image_url'].toString()]),

      startsAt: map['starts_at'] != null
          ? DateTime.tryParse(map['starts_at'].toString())
          : null,

      endsAt: map['ends_at'] != null
          ? DateTime.tryParse(map['ends_at'].toString())
          : null,
    );
  }
}
