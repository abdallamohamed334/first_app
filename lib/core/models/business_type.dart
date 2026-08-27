import 'package:flutter/material.dart';

enum BusinessType {
  restaurant('restaurant'),
  hotel('hotel'),
  supermarket('supermarket'),
  bakery('bakery'),
  cafe('cafe'),
  business('business'),
  other('other');

  final String value;

  const BusinessType(this.value);

  static BusinessType fromString(String? value) {
    switch (value?.trim().toLowerCase()) {
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
      case 'other':
        return BusinessType.other;
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
      case BusinessType.other:
        return 'مؤسسة';
    }
  }

  IconData get icon {
    switch (this) {
      case BusinessType.restaurant:
        return Icons.restaurant_rounded;
      case BusinessType.hotel:
        return Icons.hotel_rounded;
      case BusinessType.supermarket:
        return Icons.shopping_cart_rounded;
      case BusinessType.bakery:
        return Icons.bakery_dining_rounded;
      case BusinessType.cafe:
        return Icons.local_cafe_rounded;
      case BusinessType.business:
      case BusinessType.other:
        return Icons.storefront_rounded;
    }
  }
}
