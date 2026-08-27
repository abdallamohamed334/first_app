class InstitutionOffer {
  final String id;
  final String institutionId;
  final String institutionName;
  final String? institutionType;
  final String? institutionLogoUrl;
  final String title;
  final String description;
  final String category;
  final int quantity;
  final int remainingQuantity;
  final double symbolicPrice;
  final double? originalPrice;
  final List<String> images;
  final String? pickupLocation;
  final DateTime expiresAt;
  final DateTime? pickupBefore;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  const InstitutionOffer({
    required this.id,
    required this.institutionId,
    required this.institutionName,
    this.institutionType,
    this.institutionLogoUrl,
    required this.title,
    required this.description,
    required this.category,
    required this.quantity,
    required this.remainingQuantity,
    required this.symbolicPrice,
    this.originalPrice,
    required this.images,
    this.pickupLocation,
    required this.expiresAt,
    this.pickupBefore,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isExpired => DateTime.now().toUtc().isAfter(expiresAt.toUtc());
  bool get isSoldOut => remainingQuantity <= 0 || status == 'sold_out';
  bool get isActive => status == 'active' && !isExpired && !isSoldOut;
  String? get firstImage => images.isEmpty ? null : images.first;

  double? get discountPercent {
    if (originalPrice == null || originalPrice! <= 0) return null;
    final discount = ((originalPrice! - symbolicPrice) / originalPrice!) * 100;
    return discount.clamp(0, 100).toDouble();
  }

  factory InstitutionOffer.fromJson(Map<String, dynamic> json) {
    final institution = _asMap(json['institutions']);
    final expiresAt = _date(json['expires_at']) ?? DateTime.now().toUtc();
    final createdAt = _date(json['created_at']) ?? DateTime.now().toUtc();

    return InstitutionOffer(
      id: _text(json['id']),
      institutionId: _text(json['institution_id']),
      institutionName: _text(institution['name'], fallback: 'مؤسسة'),
      institutionType: _nullableText(institution['institution_type']),
      institutionLogoUrl: _firstNonEmptyText([
        institution['logo_url'],
        institution['image_url'],
        institution['logo'],
      ]),
      title: _text(json['title'], fallback: 'عرض بدون اسم'),
      description: _text(json['description']),
      category: _text(json['category'], fallback: 'other'),
      quantity: _int(json['quantity']),
      remainingQuantity:
          _int(json['remaining_quantity'], fallback: _int(json['quantity'])),
      symbolicPrice: _double(json['symbolic_price']),
      originalPrice: _nullableDouble(json['original_price']),
      images: _stringList(json['images']),
      pickupLocation: _nullableText(json['pickup_location']),
      expiresAt: expiresAt,
      pickupBefore: _date(json['pickup_before']),
      status: _text(json['status'], fallback: 'active'),
      createdAt: createdAt,
      updatedAt: _date(json['updated_at']) ?? createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'institution_id': institutionId,
      'title': title,
      'description': description,
      'category': category,
      'quantity': quantity,
      'remaining_quantity': remainingQuantity,
      'symbolic_price': symbolicPrice,
      'original_price': originalPrice,
      'images': images,
      'pickup_location': pickupLocation,
      'expires_at': expiresAt.toUtc().toIso8601String(),
      'pickup_before': pickupBefore?.toUtc().toIso8601String(),
      'status': status,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    return const <String, dynamic>{};
  }

  static String _text(dynamic value, {String fallback = ''}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  static String? _nullableText(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }

  static String? _firstNonEmptyText(List<dynamic> values) {
    for (final value in values) {
      final text = _nullableText(value);
      if (text != null) return text;
    }
    return null;
  }

  static int _int(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static double _double(dynamic value, {double fallback = 0}) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static double? _nullableDouble(dynamic value) {
    if (value == null) return null;
    final result = _double(value);
    return result == 0 && value.toString().trim() != '0' ? null : result;
  }

  static DateTime? _date(dynamic value) {
    if (value is DateTime) return value;
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : DateTime.tryParse(text);
  }

  static List<String> _stringList(dynamic value) {
    if (value is! List) return const <String>[];
    return value
        .map((item) => item?.toString().trim() ?? '')
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }
}
