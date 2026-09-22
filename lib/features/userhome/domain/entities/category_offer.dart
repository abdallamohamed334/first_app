// lib/features/userhome/domain/entities/category_offer.dart

import 'package:equatable/equatable.dart';

/// نموذج موحّد يمثل أي عرض في الـ Marketplace
/// (سواء من Community أو Institution)
/// لعرضه في صفحة تصنيف معين.
class CategoryOffer extends Equatable {
  final String id;
  final String title;
  final String? description;

  /// السعر المعروض (Symbolic price)
  final double? price;

  /// السعر الأصلي (لو موجود)
  final double? originalPrice;

  /// الصورة الأولى
  final String? image;

  /// كل الصور
  final List<String> images;

  /// نوع صاحب العرض:
  /// - 'community' → عرض من مستخدم
  /// - 'institution' → عرض من محل / مؤسسة
  final String ownerType;

  /// اسم صاحب العرض
  final String? ownerName;

  /// الشعار
  final String? ownerLogo;

  /// الموقع الجغرافي
  final double? latitude;
  final double? longitude;

  /// المسافة من المستخدم (متر)
  final double? distanceMeters;

  /// التصنيف (Master Marketplace Category)
  final String? categoryId;
  final String? categoryName;

  /// الحالة
  final String status;

  /// تاريخ الإنشاء
  final DateTime createdAt;

  /// بيانات إضافية خام
  final Map<String, dynamic> raw;

  const CategoryOffer({
    required this.id,
    required this.title,
    this.description,
    this.price,
    this.originalPrice,
    this.image,
    this.images = const [],
    required this.ownerType,
    this.ownerName,
    this.ownerLogo,
    this.latitude,
    this.longitude,
    this.distanceMeters,
    this.categoryId,
    this.categoryName,
    required this.status,
    required this.createdAt,
    this.raw = const {},
  });

  bool get isCommunity => ownerType == 'community';
  bool get isInstitution => ownerType == 'institution';

  bool get hasPrice => price != null && price! > 0;

  String get priceDisplay {
    if (price == null || price! <= 0) {
      return 'سعر رمزي';
    }
    return '${price!.toStringAsFixed(0)} ج.م';
  }

  String? get originalPriceDisplay {
    if (originalPrice == null || originalPrice! <= 0) {
      return null;
    }
    return '${originalPrice!.toStringAsFixed(0)} ج.م';
  }

  String? get distanceDisplay {
    if (distanceMeters == null) return null;
    final m = distanceMeters!;
    if (m < 1000) return '${m.round()} م';
    return '${(m / 1000).toStringAsFixed(1)} كم';
  }

  @override
  List<Object?> get props => [
        id,
        title,
        description,
        price,
        originalPrice,
        image,
        images,
        ownerType,
        ownerName,
        ownerLogo,
        latitude,
        longitude,
        distanceMeters,
        categoryId,
        categoryName,
        status,
        createdAt,
      ];
}
