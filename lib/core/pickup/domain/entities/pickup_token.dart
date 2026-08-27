class PickupToken {
  final String id;
  final String requestId;
  final String userId;
  final String restaurantId;
  final String token;
  final DateTime expiresAt;
  final DateTime? usedAt;
  final DateTime createdAt;

  const PickupToken({
    required this.id,
    required this.requestId,
    required this.userId,
    required this.restaurantId,
    required this.token,
    required this.expiresAt,
    this.usedAt,
    required this.createdAt,
  });

  bool get isExpired => !DateTime.now().toUtc().isBefore(expiresAt.toUtc());

  bool get isUsed => usedAt != null;

  bool get isValid => !isUsed && !isExpired;

  factory PickupToken.fromJson(Map<String, dynamic> json) {
    final expiresAt = _date(json['expires_at']);
    final createdAt = _date(json['created_at']);

    if (expiresAt == null || createdAt == null) {
      throw const FormatException(
        'Pickup token is missing a valid expires_at or created_at value',
      );
    }

    return PickupToken(
      id: _requiredString(json['id'], 'id'),
      requestId: _requiredString(json['request_id'], 'request_id'),
      userId: _requiredString(json['user_id'], 'user_id'),
      restaurantId: _requiredString(json['restaurant_id'], 'restaurant_id'),
      token: _requiredString(json['token'], 'token'),
      expiresAt: expiresAt,
      usedAt: _date(json['used_at']),
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'request_id': requestId,
      'user_id': userId,
      'restaurant_id': restaurantId,
      'token': token,
      'expires_at': expiresAt.toUtc().toIso8601String(),
      'used_at': usedAt?.toUtc().toIso8601String(),
      'created_at': createdAt.toUtc().toIso8601String(),
    };
  }

  static String _requiredString(dynamic value, String field) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) {
      throw FormatException('Pickup token is missing $field');
    }
    return text;
  }

  static DateTime? _date(dynamic value) {
    if (value is DateTime) return value.toUtc();
    if (value == null) return null;
    return DateTime.tryParse(value.toString())?.toUtc();
  }
}
