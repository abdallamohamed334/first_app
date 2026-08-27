import 'package:flutter/material.dart';

enum BusinessType {
  restaurant('restaurant', 'مطعم', Icons.restaurant),
  hotel('hotel', 'فندق', Icons.hotel),
  supermarket('supermarket', 'سوبر ماركت', Icons.shopping_cart),
  grocery('grocery', 'بقالة', Icons.local_grocery_store),
  bakery('bakery', 'مخبز وحلويات', Icons.bakery_dining),
  cafe('cafe', 'كافيه', Icons.local_cafe),
  gameStore('game_store', 'محل ألعاب', Icons.toys),
  other('other', 'مؤسسة أخرى', Icons.storefront);

  final String value;
  final String displayName;
  final IconData icon;

  const BusinessType(this.value, this.displayName, this.icon);

  static BusinessType fromString(String? raw) {
    switch ((raw ?? '').trim().toLowerCase()) {
      case 'restaurant':
        return BusinessType.restaurant;
      case 'hotel':
        return BusinessType.hotel;
      case 'supermarket':
        return BusinessType.supermarket;
      case 'grocery':
      case 'grocery_store':
        return BusinessType.grocery;
      case 'bakery':
      case 'sweets':
      case 'confectionery':
        return BusinessType.bakery;
      case 'cafe':
      case 'café':
        return BusinessType.cafe;
      case 'game_store':
      case 'games':
      case 'toy_store':
        return BusinessType.gameStore;
      case 'other':
      case 'business':
      default:
        return BusinessType.other;
    }
  }
}
