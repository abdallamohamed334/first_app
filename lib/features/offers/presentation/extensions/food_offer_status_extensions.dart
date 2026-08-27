import 'package:flutter/material.dart';

enum BusinessType {
  restaurant('restaurant'),
  hotel('hotel'),
  supermarket('supermarket'),
  bakery('bakery'),
  cafe('cafe'),
  business('business');

  final String value;

  const BusinessType(this.value);

  static BusinessType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'restaurant':
        return BusinessType.restaurant;
      case 'hotel':
        return BusinessType.hotel;
      case 'supermarket':
        return BusinessType.supermarket;
      case 'bakery':
        return BusinessType.bakery;
      case 'cafe':
        return BusinessType.cafe;
      case 'business':
        return BusinessType.business;
      default:
        return BusinessType.business;
    }
  }

  String get displayName {
    switch (this) {
      case BusinessType.restaurant:
        return 'مطعم';
      case BusinessType.hotel:
        return 'فندق';
      case BusinessType.supermarket:
        return 'سوبر ماركت';
      case BusinessType.bakery:
        return 'مخبز';
      case BusinessType.cafe:
        return 'كافيه';
      case BusinessType.business:
        return 'مؤسسة';
    }
  }

  // ✅ ✅ ✅ أضف الـ icon هنا
  IconData get icon {
    switch (this) {
      case BusinessType.restaurant:
        return Icons.restaurant;
      case BusinessType.hotel:
        return Icons.hotel;
      case BusinessType.supermarket:
        return Icons.shopping_cart;
      case BusinessType.bakery:
        return Icons.bakery_dining;
      case BusinessType.cafe:
        return Icons.local_cafe;
      case BusinessType.business:
        return Icons.storefront;
    }
  }
}
