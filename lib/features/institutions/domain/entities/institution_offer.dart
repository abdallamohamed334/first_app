// lib/features/institutions/domain/entities/institution_offer.dart

import 'dart:ui';

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

  // ✅ حقول إضافية من institution_offers
  final String? foodType;
  final bool? isHalal;
  final bool? isVegetarian;
  final String? foodCondition;
  final bool? requiresRefrigeration;
  final String? pickupNotes;
  final String? contactPhone;
  final String? pickupTime;
  final DateTime? deletedAt;

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
    // ✅ حقول إضافية
    this.foodType,
    this.isHalal,
    this.isVegetarian,
    this.foodCondition,
    this.requiresRefrigeration,
    this.pickupNotes,
    this.contactPhone,
    this.pickupTime,
    this.deletedAt,
  });

  bool get isExpired => DateTime.now().toUtc().isAfter(expiresAt.toUtc());
  bool get isSoldOut => remainingQuantity <= 0 || status == 'sold_out';
  bool get isActive => status == 'active' && !isExpired && !isSoldOut;
  String? get firstImage => images.isEmpty ? null : images.first;

  // ✅ دالة للحصول على حالة المنتج بالعربي
  String get conditionLabel {
    switch (foodCondition) {
      case 'new':
        return 'جديد';
      case 'very_good':
        return 'ممتاز';
      case 'good':
        return 'جيد';
      case 'needs_repair':
        return 'يحتاج إصلاح';
      default:
        return foodCondition ?? 'غير محدد';
    }
  }

  // ✅ دالة للحصول على لون حالة المنتج
  Color get conditionColor {
    switch (foodCondition) {
      case 'new':
        return const Color(0xFF0B7650);
      case 'very_good':
        return const Color(0xFF3679C8);
      case 'good':
        return const Color(0xFFB77700);
      case 'needs_repair':
        return const Color(0xFFD64545);
      default:
        return const Color(0xFF71837C);
    }
  }

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
      // ✅ حقول إضافية
      foodType: _nullableText(json['food_type']),
      isHalal: json['is_halal'] as bool?,
      isVegetarian: json['is_vegetarian'] as bool?,
      foodCondition: _nullableText(json['food_condition']),
      requiresRefrigeration: json['requires_refrigeration'] as bool?,
      pickupNotes: _nullableText(json['pickup_notes']),
      contactPhone: _nullableText(json['contact_phone']),
      pickupTime: _nullableText(json['pickup_time']),
      deletedAt: json['deleted_at'] != null
          ? DateTime.tryParse(json['deleted_at'].toString())
          : null,
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
      // ✅ حقول إضافية
      'food_type': foodType,
      'is_halal': isHalal,
      'is_vegetarian': isVegetarian,
      'food_condition': foodCondition,
      'requires_refrigeration': requiresRefrigeration,
      'pickup_notes': pickupNotes,
      'contact_phone': contactPhone,
      'pickup_time': pickupTime,
      'deleted_at': deletedAt?.toUtc().toIso8601String(),
    };
  }

  // ✅ دالة لنسخ الكائن مع تحديث بعض الحقول
  InstitutionOffer copyWith({
    String? id,
    String? institutionId,
    String? institutionName,
    String? institutionType,
    String? institutionLogoUrl,
    String? title,
    String? description,
    String? category,
    int? quantity,
    int? remainingQuantity,
    double? symbolicPrice,
    double? originalPrice,
    List<String>? images,
    String? pickupLocation,
    DateTime? expiresAt,
    DateTime? pickupBefore,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? foodType,
    bool? isHalal,
    bool? isVegetarian,
    String? foodCondition,
    bool? requiresRefrigeration,
    String? pickupNotes,
    String? contactPhone,
    String? pickupTime,
    DateTime? deletedAt,
  }) {
    return InstitutionOffer(
      id: id ?? this.id,
      institutionId: institutionId ?? this.institutionId,
      institutionName: institutionName ?? this.institutionName,
      institutionType: institutionType ?? this.institutionType,
      institutionLogoUrl: institutionLogoUrl ?? this.institutionLogoUrl,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      quantity: quantity ?? this.quantity,
      remainingQuantity: remainingQuantity ?? this.remainingQuantity,
      symbolicPrice: symbolicPrice ?? this.symbolicPrice,
      originalPrice: originalPrice ?? this.originalPrice,
      images: images ?? this.images,
      pickupLocation: pickupLocation ?? this.pickupLocation,
      expiresAt: expiresAt ?? this.expiresAt,
      pickupBefore: pickupBefore ?? this.pickupBefore,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      foodType: foodType ?? this.foodType,
      isHalal: isHalal ?? this.isHalal,
      isVegetarian: isVegetarian ?? this.isVegetarian,
      foodCondition: foodCondition ?? this.foodCondition,
      requiresRefrigeration:
          requiresRefrigeration ?? this.requiresRefrigeration,
      pickupNotes: pickupNotes ?? this.pickupNotes,
      contactPhone: contactPhone ?? this.contactPhone,
      pickupTime: pickupTime ?? this.pickupTime,
      deletedAt: deletedAt ?? this.deletedAt,
    );
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
