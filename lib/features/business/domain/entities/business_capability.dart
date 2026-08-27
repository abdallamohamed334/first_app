// lib/features/business/domain/entities/business_capability.dart

import 'package:flutter/material.dart';

enum BusinessCapability {
  createFoodOffers('create_food_offers'),
  manageRequests('manage_requests'),
  scanPickupQr('scan_pickup_qr'),
  manageProducts('manage_products'),
  manageRooms('manage_rooms'),
  analytics('analytics'),
  donations('donations'),
  reports('reports');

  final String value;
  const BusinessCapability(this.value);

  static BusinessCapability fromString(String value) {
    return BusinessCapability.values.firstWhere(
      (e) => e.value == value,
      orElse: () => BusinessCapability.createFoodOffers,
    );
  }

  String get displayName {
    switch (this) {
      case BusinessCapability.createFoodOffers:
        return 'إنشاء عروض';
      case BusinessCapability.manageRequests:
        return 'إدارة الطلبات';
      case BusinessCapability.scanPickupQr:
        return 'مسح QR';
      case BusinessCapability.manageProducts:
        return 'إدارة المنتجات';
      case BusinessCapability.manageRooms:
        return 'إدارة الغرف';
      case BusinessCapability.analytics:
        return 'إحصائيات';
      case BusinessCapability.donations:
        return 'تبرعات';
      case BusinessCapability.reports:
        return 'تقارير';
    }
  }

  IconData get icon {
    switch (this) {
      case BusinessCapability.createFoodOffers:
        return Icons.add_circle;
      case BusinessCapability.manageRequests:
        return Icons.request_page;
      case BusinessCapability.scanPickupQr:
        return Icons.qr_code_scanner;
      case BusinessCapability.manageProducts:
        return Icons.inventory_2;
      case BusinessCapability.manageRooms:
        return Icons.bed;
      case BusinessCapability.analytics:
        return Icons.bar_chart;
      case BusinessCapability.donations:
        return Icons.volunteer_activism;
      case BusinessCapability.reports:
        return Icons.description;
    }
  }
}
