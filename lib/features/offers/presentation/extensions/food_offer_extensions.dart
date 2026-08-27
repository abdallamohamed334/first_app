import 'package:flutter/material.dart';
import '../../domain/entities/food_offer.dart';
import '../../domain/entities/food_offer_status.dart';

/// Extension methods for FoodOffer in the Presentation layer
///
/// This converts domain data to UI-specific data
extension FoodOfferExtensions on FoodOffer {
  // ✅ Get status color without relying on another extension getter.
  Color get statusColor {
    switch (status) {
      case FoodOfferStatus.available:
        return const Color(0xFF0D631B);
      case FoodOfferStatus.reserved:
        return const Color(0xFFFF9800);
      case FoodOfferStatus.completed:
        return const Color(0xFF2196F3);
      case FoodOfferStatus.cancelled:
        return const Color(0xFFF44336);
      case FoodOfferStatus.expired:
        return const Color(0xFF9E9E9E);
    }
  }

  // ✅ Get status icon without relying on another extension.
  IconData get statusIcon {
    switch (status) {
      case FoodOfferStatus.available:
        return Icons.check_circle;
      case FoodOfferStatus.reserved:
        return Icons.hourglass_top;
      case FoodOfferStatus.completed:
        return Icons.done_all;
      case FoodOfferStatus.cancelled:
        return Icons.cancel;
      case FoodOfferStatus.expired:
        return Icons.timer_off;
    }
  }

  String get _statusDisplay {
    switch (status) {
      case FoodOfferStatus.available:
        return 'متاح';
      case FoodOfferStatus.reserved:
        return 'محجوز';
      case FoodOfferStatus.completed:
        return 'مكتمل';
      case FoodOfferStatus.cancelled:
        return 'ملغي';
      case FoodOfferStatus.expired:
        return 'منتهي';
    }
  }

  // ✅ Get status badge widget without relying on status.badge.
  Widget get statusBadge {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(statusIcon, size: 12, color: statusColor),
          const SizedBox(width: 4),
          Text(
            _statusDisplay,
            style: TextStyle(
              fontSize: 10,
              color: statusColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ✅ Get formatted location (truncated if too long)
  String get formattedLocation {
    if (pickupLocation.length > 30) {
      return '${pickupLocation.substring(0, 30)}...';
    }
    return pickupLocation;
  }

  // ✅ Get urgency level - استخدام isExpired من FoodOffer
  FoodUrgency get urgency {
    if (isExpired) return FoodUrgency.expired;
    if (isUrgent) return FoodUrgency.urgent;
    if (isAvailable) return FoodUrgency.normal;
    return FoodUrgency.unavailable;
  }

  // ✅ Get time remaining with color
  ({String text, Color color}) get timeRemainingWithColor {
    final now = DateTime.now();
    final difference = expiryTime.difference(now);

    if (difference.inDays > 0) {
      return (
        text: '${difference.inDays} يوم',
        color: Colors.green,
      );
    } else if (difference.inHours > 0) {
      if (difference.inHours <= 2) {
        return (
          text: '${difference.inHours} ساعة',
          color: Colors.red,
        );
      }
      return (
        text: '${difference.inHours} ساعة',
        color: Colors.orange,
      );
    } else if (difference.inMinutes > 0) {
      return (
        text: '${difference.inMinutes} دقيقة',
        color: Colors.red,
      );
    } else {
      return (
        text: 'انتهى',
        color: Colors.grey,
      );
    }
  }

  // ✅ Get full address
  String get fullAddress => pickupLocation;

  // ✅ Get short description
  String get shortDescription {
    if (description.length > 40) {
      return '${description.substring(0, 40)}...';
    }
    return description;
  }

  // ✅ Get quantity display
  String get quantityDisplay => '$quantity وجبة';

  // ✅ Get food type with icon
  ({String label, IconData icon}) get foodTypeWithIcon {
    switch (foodType.toLowerCase()) {
      case 'نباتي':
      case 'vegetarian':
        return (label: 'نباتي', icon: Icons.eco);
      case 'مخبوزات':
      case 'bakery':
        return (label: 'مخبوزات', icon: Icons.bakery_dining);
      case 'وجبات رئيسية':
      case 'main':
        return (label: 'وجبات رئيسية', icon: Icons.lunch_dining);
      case 'حلويات':
      case 'dessert':
        return (label: 'حلويات', icon: Icons.cake);
      case 'فطور':
      case 'breakfast':
        return (label: 'فطور', icon: Icons.breakfast_dining);
      default:
        return (label: foodType, icon: Icons.restaurant);
    }
  }
}

/// Food urgency levels for UI
enum FoodUrgency {
  urgent,
  normal,
  expired,
  unavailable,
}

extension FoodUrgencyExtensions on FoodUrgency {
  String get displayName {
    switch (this) {
      case FoodUrgency.urgent:
        return 'عاجل';
      case FoodUrgency.normal:
        return 'متاح';
      case FoodUrgency.expired:
        return 'منتهي';
      case FoodUrgency.unavailable:
        return 'غير متاح';
    }
  }

  Color get color {
    switch (this) {
      case FoodUrgency.urgent:
        return Colors.red;
      case FoodUrgency.normal:
        return Colors.green;
      case FoodUrgency.expired:
        return Colors.grey;
      case FoodUrgency.unavailable:
        return Colors.orange;
    }
  }

  IconData get icon {
    switch (this) {
      case FoodUrgency.urgent:
        return Icons.warning_amber_rounded;
      case FoodUrgency.normal:
        return Icons.check_circle;
      case FoodUrgency.expired:
        return Icons.timer_off;
      case FoodUrgency.unavailable:
        return Icons.block;
    }
  }
}


