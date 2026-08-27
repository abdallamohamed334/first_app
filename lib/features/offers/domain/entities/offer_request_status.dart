// lib/features/offers/domain/entities/offer_request_status.dart

import 'package:flutter/material.dart';

enum OfferRequestStatus {
  pending,
  accepted,
  readyForPickup,
  completed,
  cancelled,
  expired,
}

extension OfferRequestStatusExtension on OfferRequestStatus {
  String get displayName {
    switch (this) {
      case OfferRequestStatus.pending:
        return '⏳ قيد الانتظار';
      case OfferRequestStatus.accepted:
        return '✅ تم القبول';
      case OfferRequestStatus.readyForPickup:
        return '📦 جاهز للاستلام';
      case OfferRequestStatus.completed:
        return '🎉 تم الاستلام';
      case OfferRequestStatus.cancelled:
        return '❌ ملغي';
      case OfferRequestStatus.expired:
        return '⏰ منتهي';
    }
  }

  Color get color {
    switch (this) {
      case OfferRequestStatus.pending:
        return Colors.orange;
      case OfferRequestStatus.accepted:
        return Colors.blue;
      case OfferRequestStatus.readyForPickup:
        return Colors.green;
      case OfferRequestStatus.completed:
        return Colors.teal;
      case OfferRequestStatus.cancelled:
        return Colors.red;
      case OfferRequestStatus.expired:
        return Colors.grey;
    }
  }

  IconData get icon {
    switch (this) {
      case OfferRequestStatus.pending:
        return Icons.hourglass_empty;
      case OfferRequestStatus.accepted:
        return Icons.check_circle;
      case OfferRequestStatus.readyForPickup:
        return Icons.qr_code_scanner;
      case OfferRequestStatus.completed:
        return Icons.celebration;
      case OfferRequestStatus.cancelled:
        return Icons.cancel;
      case OfferRequestStatus.expired:
        return Icons.timer_off;
    }
  }

  static OfferRequestStatus fromString(String value) {
    switch (value) {
      case 'pending':
        return OfferRequestStatus.pending;
      case 'accepted':
        return OfferRequestStatus.accepted;
      case 'ready_for_pickup':
        return OfferRequestStatus.readyForPickup;
      case 'completed':
        return OfferRequestStatus.completed;
      case 'cancelled':
        return OfferRequestStatus.cancelled;
      case 'expired':
        return OfferRequestStatus.expired;
      default:
        return OfferRequestStatus.pending;
    }
  }
}
