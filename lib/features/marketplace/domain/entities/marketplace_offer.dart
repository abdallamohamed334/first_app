// lib/features/marketplace/domain/entities/marketplace_offer.dart

class MarketplaceOffer {
  final String marketplaceOfferId;
  final String sourceType;
  final String sourceId;
  final String categoryId;
  final String categorySlug;
  final String? categoryNameAr;

  final String title;
  final String? description;

  final int quantity;
  final int? remainingQuantity;
  final double? price;
  final String? originalPrice;

  final String? image;
  final List<String> images;

  final String? pickupLocation;
  final double? latitude;
  final double? longitude;
  final double? distanceMeters;

  // ✅ معلومات صاحب العرض
  final String? ownerId;
  final String? ownerName;
  final String? ownerAvatar;

  // ✅ حالة المنتج
  final String? itemCondition;

  final String status;
  final DateTime? createdAt;

  const MarketplaceOffer({
    required this.marketplaceOfferId,
    required this.sourceType,
    required this.sourceId,
    required this.categoryId,
    required this.categorySlug,
    this.categoryNameAr,
    required this.title,
    this.description,
    required this.quantity,
    this.remainingQuantity,
    this.price,
    this.originalPrice,
    this.image,
    required this.images,
    this.pickupLocation,
    this.latitude,
    this.longitude,
    this.distanceMeters,
    this.ownerId,
    this.ownerName,
    this.ownerAvatar,
    this.itemCondition,
    required this.status,
    this.createdAt,
  });

  // ============================================================
  // Helpers
  // ============================================================

  bool get isNew => itemCondition == 'new';

  int get availableQuantity => remainingQuantity ?? quantity;

  bool get isLowStock => availableQuantity > 0 && availableQuantity <= 3;

  bool get isSoldOut => availableQuantity <= 0;

  bool get hasPrice => price != null && price! > 0;

  bool get hasDiscount =>
      originalPrice != null &&
      originalPrice!.isNotEmpty &&
      hasPrice &&
      double.tryParse(originalPrice!) != null &&
      double.parse(originalPrice!) > price!;

  double? get discountPercent {
    if (!hasDiscount) return null;
    final original = double.tryParse(originalPrice!);
    if (original == null || original <= 0) return null;
    final discount = ((original - price!) / original) * 100;
    return discount.clamp(0, 100);
  }

  String? get distanceDisplay {
    if (distanceMeters == null) return null;
    final meters = distanceMeters!;
    if (meters < 1000) return '${meters.round()} م';
    return '${(meters / 1000).toStringAsFixed(1)} كم';
  }

  String get sourceTypeLabel {
    switch (sourceType) {
      case 'community':
        return 'مستخدم';
      case 'institution':
        return 'محل';
      case 'business':
        return 'مؤسسة';
      default:
        return 'عرض';
    }
  }

  String? get conditionLabel {
    switch (itemCondition) {
      case 'new':
        return 'جديد';
      case 'used':
        return 'مستعمل';
      case 'very_good':
        return 'جيد جدًا';
      case 'good':
        return 'جيد';
      case 'needs_repair':
        return 'يحتاج إصلاح';
      default:
        return null;
    }
  }
}
