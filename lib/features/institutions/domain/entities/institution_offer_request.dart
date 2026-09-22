// lib/features/institutions/domain/entities/institution_offer_request.dart

import 'dart:ui';

import 'institution_offer.dart';

class InstitutionOfferRequest {
  final String id;
  final String offerId;
  final String requesterId;
  final int quantity;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? pickupCode;
  final String? bookingCode; // ✅ إضافة bookingCode
  final String? pickupTokenHash;
  final DateTime? pickupTokenExpiresAt;
  final DateTime? pickupTokenUsedAt;
  final DateTime? pickedUpAt;
  final DateTime? completedAt;
  final String? cancellationReason;
  final InstitutionOffer? institutionOffers;
  final Map<String, dynamic>? offer;

  const InstitutionOfferRequest({
    required this.id,
    required this.offerId,
    required this.requesterId,
    required this.quantity,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.pickupCode,
    this.bookingCode, // ✅ إضافة bookingCode
    this.pickupTokenHash,
    this.pickupTokenExpiresAt,
    this.pickupTokenUsedAt,
    this.pickedUpAt,
    this.completedAt,
    this.cancellationReason,
    this.institutionOffers,
    this.offer,
  });

  factory InstitutionOfferRequest.fromJson(Map<String, dynamic> json) {
    InstitutionOffer? offer;
    if (json['institution_offers'] != null) {
      try {
        offer = InstitutionOffer.fromJson(
          Map<String, dynamic>.from(json['institution_offers']),
        );
      } catch (_) {
        offer = null;
      }
    }

    return InstitutionOfferRequest(
      id: json['id']?.toString() ?? '',
      offerId: json['offer_id']?.toString() ?? '',
      requesterId: json['requester_id']?.toString() ?? '',
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      status: json['status']?.toString() ?? 'pending',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : DateTime.now(),
      pickupCode: json['pickup_code']?.toString(),
      bookingCode: json['booking_code']?.toString(), // ✅ إضافة bookingCode
      pickupTokenHash: json['pickup_token_hash']?.toString(),
      pickupTokenExpiresAt: json['pickup_token_expires_at'] != null
          ? DateTime.parse(json['pickup_token_expires_at'])
          : null,
      pickupTokenUsedAt: json['pickup_token_used_at'] != null
          ? DateTime.parse(json['pickup_token_used_at'])
          : null,
      pickedUpAt: json['picked_up_at'] != null
          ? DateTime.parse(json['picked_up_at'])
          : null,
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'])
          : null,
      cancellationReason: json['cancellation_reason']?.toString(),
      institutionOffers: offer,
      offer: json['institution_offers'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'offer_id': offerId,
      'requester_id': requesterId,
      'quantity': quantity,
      'status': status,
      'pickup_code': pickupCode,
      'booking_code': bookingCode, // ✅ إضافة bookingCode
      'pickup_token_hash': pickupTokenHash,
      'pickup_token_expires_at': pickupTokenExpiresAt?.toIso8601String(),
      'pickup_token_used_at': pickupTokenUsedAt?.toIso8601String(),
      'picked_up_at': pickedUpAt?.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'cancellation_reason': cancellationReason,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'institution_offers': institutionOffers?.toJson(),
    };
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'offer_id': offerId,
      'requester_id': requesterId,
      'quantity': quantity,
      'status': status,
      'pickup_code': pickupCode,
      'booking_code': bookingCode, // ✅ إضافة bookingCode
      'pickup_token_hash': pickupTokenHash,
      'pickup_token_expires_at': pickupTokenExpiresAt?.toIso8601String(),
      'pickup_token_used_at': pickupTokenUsedAt?.toIso8601String(),
      'picked_up_at': pickedUpAt?.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'cancellation_reason': cancellationReason,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'institution_offers': institutionOffers?.toJson(),
    };
  }

  bool get isPending => status == 'pending';
  bool get isAccepted => status == 'accepted';
  bool get isReadyForPickup => status == 'ready_for_pickup';
  bool get isPickedUp => status == 'picked_up';
  bool get isCompleted => status == 'completed';
  bool get isCancelled => status == 'cancelled';
  bool get isActive => !isCancelled && !isCompleted;

  bool get hasValidPickupCode {
    if (pickupCode == null || pickupCode!.isEmpty) return false;
    if (pickupTokenUsedAt != null) return false;
    if (pickupTokenExpiresAt == null) return false;
    return pickupTokenExpiresAt!.isAfter(DateTime.now().toUtc());
  }

  String get statusDisplay {
    switch (status) {
      case 'pending':
        return '⏳ قيد المراجعة';
      case 'accepted':
        return '✅ تم القبول';
      case 'ready_for_pickup':
        return '📦 جاهز للاستلام';
      case 'picked_up':
        return '📋 تم الاستلام';
      case 'completed':
        return '🎉 مكتمل';
      case 'cancelled':
        return '❌ ملغي';
      default:
        return status;
    }
  }

  Color get statusColor {
    switch (status) {
      case 'pending':
        return const Color(0xFFE28B00);
      case 'accepted':
        return const Color(0xFF3679C8);
      case 'ready_for_pickup':
        return const Color(0xFF0B7650);
      case 'picked_up':
        return const Color(0xFF6651B5);
      case 'completed':
        return const Color(0xFF0B7650);
      case 'cancelled':
        return const Color(0xFFD64545);
      default:
        return const Color(0xFF71837C);
    }
  }

  InstitutionOfferRequest copyWith({
    String? id,
    String? offerId,
    String? requesterId,
    int? quantity,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? pickupCode,
    String? bookingCode, // ✅ إضافة bookingCode
    String? pickupTokenHash,
    DateTime? pickupTokenExpiresAt,
    DateTime? pickupTokenUsedAt,
    DateTime? pickedUpAt,
    DateTime? completedAt,
    String? cancellationReason,
    InstitutionOffer? institutionOffers,
    Map<String, dynamic>? offer,
  }) {
    return InstitutionOfferRequest(
      id: id ?? this.id,
      offerId: offerId ?? this.offerId,
      requesterId: requesterId ?? this.requesterId,
      quantity: quantity ?? this.quantity,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      pickupCode: pickupCode ?? this.pickupCode,
      bookingCode: bookingCode ?? this.bookingCode, // ✅ إضافة bookingCode
      pickupTokenHash: pickupTokenHash ?? this.pickupTokenHash,
      pickupTokenExpiresAt: pickupTokenExpiresAt ?? this.pickupTokenExpiresAt,
      pickupTokenUsedAt: pickupTokenUsedAt ?? this.pickupTokenUsedAt,
      pickedUpAt: pickedUpAt ?? this.pickedUpAt,
      completedAt: completedAt ?? this.completedAt,
      cancellationReason: cancellationReason ?? this.cancellationReason,
      institutionOffers: institutionOffers ?? this.institutionOffers,
      offer: offer ?? this.offer,
    );
  }
}
