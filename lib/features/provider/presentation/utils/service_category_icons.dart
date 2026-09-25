// lib/features/provider/presentation/utils/service_category_icons.dart

import 'package:flutter/material.dart';

/// ✅ بيحوّل اسم الأيقونة من الداتابيز لـ IconData
/// + لون مناسب لكل تصنيف
class ServiceCategoryIcons {
  ServiceCategoryIcons._();

  /// ── الألوان الموحدة للتصنيفات
  static const Color _blue = Color(0xFF3679C8);
  static const Color _orange = Color(0xFFE28B00);
  static const Color _green = Color(0xFF0B7650);
  static const Color _red = Color(0xFFD64545);
  static const Color _purple = Color(0xFF7B4BC8);
  static const Color _teal = Color(0xFF0D9488);
  static const Color _brown = Color(0xFF8B5A2B);
  static const Color _pink = Color(0xFFD946A6);

  /// ── mapping أيقونة النص → IconData
  static IconData getIcon(String? iconName) {
    switch (iconName?.toLowerCase().trim()) {
      case 'plumbing':
        return Icons.plumbing_rounded;
      case 'electrical':
        return Icons.electrical_services_rounded;
      case 'carpentry':
        return Icons.handyman_rounded;
      case 'painting':
        return Icons.format_paint_rounded;
      case 'ac':
        return Icons.ac_unit_rounded;
      case 'appliances':
        return Icons.kitchen_rounded;
      case 'car':
        return Icons.directions_car_rounded;
      case 'maintenance':
        return Icons.build_circle_rounded;
      case 'cleaning':
        return Icons.cleaning_services_rounded;
      case 'tutoring':
        return Icons.school_rounded;
      case 'barber':
        return Icons.content_cut_rounded;
      case 'beauty':
        return Icons.spa_rounded;
      case 'it':
        return Icons.computer_rounded;
      case 'lock':
        return Icons.lock_rounded;
      case 'garden':
        return Icons.yard_rounded;
      case 'moving':
        return Icons.local_shipping_rounded;
      case 'construction':
        return Icons.engineering_rounded;
      case 'other':
        return Icons.more_horiz_rounded;
      default:
        return Icons.category_rounded;
    }
  }

  /// ── لون لكل تصنيف
  static Color getColor(String? iconName) {
    switch (iconName?.toLowerCase().trim()) {
      case 'plumbing':
        return _blue;
      case 'electrical':
        return const Color(0xFFFFB300);
      case 'carpentry':
        return _brown;
      case 'painting':
        return _purple;
      case 'ac':
        return _teal;
      case 'appliances':
        return const Color(0xFF5E6B7A);
      case 'car':
        return _red;
      case 'maintenance':
        return _orange;
      case 'cleaning':
        return _green;
      case 'tutoring':
        return _blue;
      case 'barber':
        return const Color(0xFF37474F);
      case 'beauty':
        return _pink;
      case 'it':
        return _teal;
      case 'lock':
        return _brown;
      case 'garden':
        return const Color(0xFF2E7D32);
      case 'moving':
        return _orange;
      case 'construction':
        return const Color(0xFFFF6B35);
      case 'other':
        return const Color(0xFF87909A);
      default:
        return _blue;
    }
  }
}
