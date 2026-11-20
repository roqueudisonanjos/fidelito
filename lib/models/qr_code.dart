class QrCodeModel {
  final String id;
  final String code;
  final int points;
  final DateTime? expiresAt;
  final bool isStatic;

  QrCodeModel({
    required this.id,
    required this.code,
    required this.points,
    this.expiresAt,
    this.isStatic = false,
  });

  factory QrCodeModel.fromMap(Map<String, dynamic> map) {
    return QrCodeModel(
      id: map['id'] as String,
      code: map['code'] as String,
      points: map['points'] as int,
      expiresAt: map['expires_at'] == null ? null : DateTime.parse(map['expires_at'] as String),
      isStatic: map['is_static'] == true,
    );
  }
}
