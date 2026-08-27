// lib/features/offers/domain/entities/food_offer_status.dart

enum FoodOfferStatus {
  available('متاح'),
  reserved('محجوز'),
  completed('مكتمل'),
  cancelled('ملغي'),
  expired('منتهي'); // ✅ جديد

  final String displayName;

  const FoodOfferStatus(this.displayName);

  static FoodOfferStatus fromString(String value) {
    switch (value) {
      case 'available':
        return FoodOfferStatus.available;
      case 'reserved':
        return FoodOfferStatus.reserved;
      case 'completed':
        return FoodOfferStatus.completed;
      case 'cancelled':
        return FoodOfferStatus.cancelled;
      case 'expired': // ✅ جديد
        return FoodOfferStatus.expired;
      default:
        return FoodOfferStatus.available;
    }
  }

  String get value {
    switch (this) {
      case FoodOfferStatus.available:
        return 'available';
      case FoodOfferStatus.reserved:
        return 'reserved';
      case FoodOfferStatus.completed:
        return 'completed';
      case FoodOfferStatus.cancelled:
        return 'cancelled';
      case FoodOfferStatus.expired: // ✅ جديد
        return 'expired';
    }
  }

  String get colorHex {
    switch (this) {
      case FoodOfferStatus.available:
        return '#0D631B';
      case FoodOfferStatus.reserved:
        return '#FF9800';
      case FoodOfferStatus.completed:
        return '#2196F3';
      case FoodOfferStatus.cancelled:
        return '#F44336';
      case FoodOfferStatus.expired: // ✅ جديد
        return '#9E9E9E';
    }
  }

  // ✅ Getter لمعرفة إذا كان العرض منتهي
  bool get isExpired => this == FoodOfferStatus.expired;

  // ✅ Getter لمعرفة إذا كان العرض متاح
  bool get isAvailable => this == FoodOfferStatus.available;
}
