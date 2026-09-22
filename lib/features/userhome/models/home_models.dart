// هذا الملف يمكن استيراد النماذج من core/models بدلاً من إنشاء نماذج جديدة
// ولكن إن أردت نماذج خاصة بالـ UI فقط:

import 'package:flutter/material.dart';

class HomeIntent {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  const HomeIntent({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  static const List<HomeIntent> intents = [
    HomeIntent(
      id: 'buy',
      title: 'أشتري',
      subtitle: 'فائض بسعر رمزي',
      icon: Icons.shopping_bag_rounded,
      color: Color(0xFF0B7650),
    ),
    HomeIntent(
      id: 'sell',
      title: 'أبيع',
      subtitle: 'فائض عندي',
      icon: Icons.attach_money_rounded,
      color: Color(0xFFE28B00),
    ),
    HomeIntent(
      id: 'donate',
      title: 'أتبرع',
      subtitle: 'بفائض لجمعية',
      icon: Icons.volunteer_activism_rounded,
      color: Color(0xFF8A5BB7),
    ),
    HomeIntent(
      id: 'volunteer',
      title: 'أتطوع',
      subtitle: 'أوصل تبرع',
      icon: Icons.delivery_dining_rounded,
      color: Color(0xFF3679C8),
    ),
  ];
}

class HomeCategory {
  final String id;
  final String label;
  final IconData icon;

  const HomeCategory({
    required this.id,
    required this.label,
    required this.icon,
  });

  static const List<HomeCategory> categories = [
    HomeCategory(id: 'الكل', label: 'الكل', icon: Icons.apps_rounded),
    HomeCategory(
        id: 'restaurant', label: '🍽️ مطاعم', icon: Icons.restaurant_rounded),
    HomeCategory(
        id: 'bakery', label: '🥐 مخابز', icon: Icons.bakery_dining_rounded),
    HomeCategory(id: 'sweets', label: '🍰 حلويات', icon: Icons.cake_rounded),
    HomeCategory(
        id: 'grocery', label: '🛒 بقالة', icon: Icons.shopping_basket_rounded),
    HomeCategory(id: 'hotel', label: '🏨 فنادق', icon: Icons.hotel_rounded),
    HomeCategory(
        id: 'hall', label: '🏛️ قاعات', icon: Icons.event_available_rounded),
    HomeCategory(
        id: 'individual', label: '👤 أفراد', icon: Icons.person_rounded),
  ];
}
