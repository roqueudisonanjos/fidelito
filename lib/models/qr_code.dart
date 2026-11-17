class QrCodeModel {
  final String id;
  final String code;
  final int points;
  final DateTime expiresAt;

  QrCodeModel({
    required this.id,
    required this.code,
    required this.points,
    required this.expiresAt,
  });

  factory QrCodeModel.fromMap(Map<String, dynamic> map) {
    return QrCodeModel(
      id: map['id'] as String,
      code: map['code'] as String,
      points: map['points'] as int,
      expiresAt: DateTime.parse(map['expires_at'] as String),
    );
  }
}
