import 'package:flutter/material.dart';

class Booking {
  final String id;
  final String offerId;
  final String userId;
  final String? restaurantId;
  final String? businessId;
  final BookingStatus status;
  final DateTime requestedAt;
  final DateTime? updatedAt;
  final DateTime? completedAt;
  final String? notes;
  final String? pickupTokenHash;
  final DateTime? pickupTokenExpiresAt;
  final DateTime? pickupTokenUsedAt;
  final String? offerTitle;
  final String? offerImage;
  final String? restaurantName;
  final String? businessName;
  final String? restaurantLogo;
  final String? businessLogo;
  final String? businessAddress;
  final String? businessPhone;
  final int? quantity;

  const Booking({
    required this.id,
    required this.offerId,
    required this.userId,
    this.restaurantId,
    this.businessId,
    required this.status,
    required this.requestedAt,
    this.updatedAt,
    this.completedAt,
    this.notes,
    this.pickupTokenHash,
    this.pickupTokenExpiresAt,
    this.pickupTokenUsedAt,
    this.offerTitle,
    this.offerImage,
    this.restaurantName,
    this.businessName,
    this.restaurantLogo,
    this.businessLogo,
    this.businessAddress,
    this.businessPhone,
    this.quantity,
  });

  bool get canGenerateQR =>
      status == BookingStatus.readyForPickup &&
      (pickupTokenHash == null || pickupTokenHash!.isEmpty);

  bool get isTokenValid {
    final expiry = pickupTokenExpiresAt;
    return pickupTokenHash != null &&
        pickupTokenHash!.isNotEmpty &&
        pickupTokenUsedAt == null &&
        expiry != null &&
        DateTime.now().toUtc().isBefore(expiry.toUtc());
  }

  String get timeRemaining {
    final expiry = pickupTokenExpiresAt;
    if (expiry == null) return 'غير محدد';
    final diff = expiry.toUtc().difference(DateTime.now().toUtc());
    if (diff.isNegative || diff.inSeconds == 0) return 'انتهى';
    final minutes = diff.inMinutes;
    final seconds = diff.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  String get businessNameDisplay =>
      _clean(businessName) ?? _clean(restaurantName) ?? 'مطعم';

  String? get businessLogoDisplay =>
      _clean(businessLogo) ?? _clean(restaurantLogo);

  String get businessIdDisplay =>
      _clean(businessId) ?? _clean(restaurantId) ?? '';

  factory Booking.fromJson(Map<String, dynamic> json) {
    final business = _asMap(json['businesses']);
    final restaurant = _asMap(json['restaurants']);
    final foodOffer = _asMap(json['food_offers']);

    return Booking(
      id: _required(json['id'], 'id'),
      offerId: _required(json['offer_id'], 'offer_id'),
      userId: _required(json['user_id'], 'user_id'),
      restaurantId: _clean(json['restaurant_id']),
      businessId: _clean(json['business_id']) ?? _clean(json['restaurant_id']),
      status: BookingStatus.fromString(json['status']),
      requestedAt: _date(json['requested_at']) ?? DateTime.now().toUtc(),
      updatedAt: _date(json['updated_at']),
      completedAt: _date(json['completed_at']),
      notes: _clean(json['notes']),
      pickupTokenHash: _clean(json['pickup_token_hash']),
      pickupTokenExpiresAt: _date(json['pickup_token_expires_at']),
      pickupTokenUsedAt: _date(json['pickup_token_used_at']),
      offerTitle: _clean(foodOffer?['title']) ?? _clean(json['offer_title']),
      offerImage: _clean(foodOffer?['image']) ?? _clean(json['offer_image']),
      restaurantName: _clean(restaurant?['name']),
      businessName: _clean(business?['name']) ?? _clean(restaurant?['name']),
      restaurantLogo: _clean(restaurant?['logo']),
      businessLogo: _clean(business?['logo']) ?? _clean(restaurant?['logo']),
      businessAddress:
          _clean(business?['address']) ?? _clean(restaurant?['address']),
      businessPhone: _clean(business?['phone']) ?? _clean(restaurant?['phone']),
      quantity: _int(foodOffer?['quantity'] ?? json['quantity']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'offer_id': offerId,
        'user_id': userId,
        'restaurant_id': restaurantId,
        'business_id': businessId,
        'status': status.value,
        'requested_at': requestedAt.toUtc().toIso8601String(),
        'updated_at': updatedAt?.toUtc().toIso8601String(),
        'completed_at': completedAt?.toUtc().toIso8601String(),
        'notes': notes,
        'pickup_token_hash': pickupTokenHash,
        'pickup_token_expires_at':
            pickupTokenExpiresAt?.toUtc().toIso8601String(),
        'pickup_token_used_at': pickupTokenUsedAt?.toUtc().toIso8601String(),
      };

  static Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    if (value is List && value.isNotEmpty && value.first is Map) {
      return _asMap(value.first);
    }
    return null;
  }

  static String _required(dynamic value, String field) {
    final result = _clean(value);
    if (result == null) throw FormatException('Missing booking field: $field');
    return result;
  }

  static String? _clean(dynamic value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  static DateTime? _date(dynamic value) {
    if (value is DateTime) return value.toUtc();
    final text = _clean(value);
    if (text == null) return null;
    return DateTime.tryParse(text)?.toUtc();
  }

  static int? _int(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(_clean(value) ?? '');
  }
}

enum BookingStatus {
  pending('pending'),
  accepted('accepted'),
  rejected('rejected'),
  readyForPickup('ready_for_pickup'),
  completed('completed'),
  cancelled('cancelled'),
  expired('expired');

  final String value;
  const BookingStatus(this.value);

  static BookingStatus fromString(dynamic value) {
    final normalized = value?.toString().trim().toLowerCase();
    return BookingStatus.values.firstWhere(
      (item) => item.value == normalized,
      orElse: () => BookingStatus.pending,
    );
  }

  String get displayName {
    switch (this) {
      case BookingStatus.pending:
        return 'في انتظار الموافقة';
      case BookingStatus.accepted:
        return 'تم القبول';
      case BookingStatus.rejected:
        return 'تم الرفض';
      case BookingStatus.readyForPickup:
        return 'جاهز للاستلام';
      case BookingStatus.completed:
        return 'تم التسليم';
      case BookingStatus.cancelled:
        return 'ملغي';
      case BookingStatus.expired:
        return 'منتهي';
    }
  }

  Color get color {
    switch (this) {
      case BookingStatus.pending:
        return Colors.orange;
      case BookingStatus.accepted:
        return Colors.blue;
      case BookingStatus.rejected:
        return Colors.red;
      case BookingStatus.readyForPickup:
        return Colors.green;
      case BookingStatus.completed:
        return Colors.teal;
      case BookingStatus.cancelled:
        return Colors.red;
      case BookingStatus.expired:
        return Colors.grey;
    }
  }

  IconData get icon {
    switch (this) {
      case BookingStatus.pending:
        return Icons.hourglass_empty;
      case BookingStatus.accepted:
        return Icons.check_circle_outline;
      case BookingStatus.rejected:
        return Icons.cancel_outlined;
      case BookingStatus.readyForPickup:
        return Icons.qr_code_scanner;
      case BookingStatus.completed:
        return Icons.celebration;
      case BookingStatus.cancelled:
        return Icons.cancel;
      case BookingStatus.expired:
        return Icons.timer_off;
    }
  }
}
