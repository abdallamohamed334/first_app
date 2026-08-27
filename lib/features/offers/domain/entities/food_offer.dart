// lib/features/offers/domain/entities/food_offer.dart

import 'dart:convert';
import 'dart:ui';

import 'package:equatable/equatable.dart';
import 'food_offer_status.dart';

class FoodOffer extends Equatable {
  final String id;
  final String title;
  final String description;
  final int quantity;
  final String foodType;
  final DateTime expiryTime;
  final DateTime pickupBefore;
  final String pickupLocation;
  final double latitude;
  final double longitude;
  final String? image;
  final FoodOfferStatus status;
  final String? businessId; // ✅ بدلاً من restaurantId
  final String? charityId;
  final DateTime createdAt;
  final DateTime updatedAt;

  // ✅ بيانات المؤسسة (Business)
  final Map<String, dynamic>? business;

  // ✅ الحقول الجديدة
  final List<String>? images;
  final String? estimatedWeight;
  final int? servesCount;
  final String? foodCondition;
  final String? packaging;
  final bool requiresRefrigeration;
  final bool isHalal;
  final bool isVegetarian;
  final String? pickupNotes;
  final String? contactName;
  final String? contactPhone;
  final int? pickupWindowMinutes;
  final String? priority;
  final int views;
  final int interestedCount;
  final int shares;

  const FoodOffer({
    required this.id,
    required this.title,
    required this.description,
    required this.quantity,
    required this.foodType,
    required this.expiryTime,
    required this.pickupBefore,
    required this.pickupLocation,
    required this.latitude,
    required this.longitude,
    this.image,
    required this.status,
    this.businessId,
    this.charityId,
    required this.createdAt,
    required this.updatedAt,
    this.business,
    this.images,
    this.estimatedWeight,
    this.servesCount,
    this.foodCondition,
    this.packaging,
    this.requiresRefrigeration = false,
    this.isHalal = true,
    this.isVegetarian = false,
    this.pickupNotes,
    this.contactName,
    this.contactPhone,
    this.pickupWindowMinutes = 30,
    this.priority = 'medium',
    this.views = 0,
    this.interestedCount = 0,
    this.shares = 0,
  });

  // ✅ Factory method from JSON (Supabase)
  factory FoodOffer.fromJson(Map<String, dynamic> json) {
    final business = json['businesses'] as Map<String, dynamic>?;

    return FoodOffer(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'عرض طعام',
      description: json['description'] as String? ?? 'لا يوجد وصف',
      quantity: json['quantity'] as int? ?? 0,
      foodType: json['food_type'] as String? ?? 'غير محدد',
      expiryTime: json['expiry_time'] != null
          ? DateTime.parse(json['expiry_time'] as String)
          : DateTime.now(),
      pickupBefore: json['pickup_before'] != null
          ? DateTime.parse(json['pickup_before'] as String)
          : DateTime.now().add(const Duration(hours: 2)),
      pickupLocation: json['pickup_location'] as String? ?? 'موقع غير محدد',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 30.0444,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 31.2357,
      image: _firstImage([
        json['image'],
        json['image_url'],
        json['offer_image'],
        json['photo_url'],
      ]),
      status:
          FoodOfferStatus.fromString(json['status'] as String? ?? 'available'),
      businessId: json['business_id'] as String?,
      charityId: json['charity_id'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
      business: business,
      images: _imageList([
        json['images'],
        json['image_urls'],
        json['offer_images'],
        json['media'],
      ]),
      estimatedWeight: json['estimated_weight'] as String?,
      servesCount: json['serves_count'] as int?,
      foodCondition: json['food_condition'] as String?,
      packaging: json['packaging'] as String?,
      requiresRefrigeration: json['requires_refrigeration'] as bool? ?? false,
      isHalal: json['is_halal'] as bool? ?? true,
      isVegetarian: json['is_vegetarian'] as bool? ?? false,
      pickupNotes: json['pickup_notes'] as String?,
      contactName: json['contact_name'] as String?,
      contactPhone: json['contact_phone'] as String?,
      pickupWindowMinutes: json['pickup_window_minutes'] as int? ?? 30,
      priority: json['priority'] as String? ?? 'medium',
      views: json['views'] as int? ?? 0,
      interestedCount: json['interested_count'] as int? ?? 0,
      shares: json['shares'] as int? ?? 0,
    );
  }

  // ✅ To JSON for Supabase
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'quantity': quantity,
      'food_type': foodType,
      'expiry_time': expiryTime.toIso8601String(),
      'pickup_before': pickupBefore.toIso8601String(),
      'pickup_location': pickupLocation,
      'latitude': latitude,
      'longitude': longitude,
      'image': image,
      'status': status.value,
      'business_id': businessId,
      'charity_id': charityId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'images': images,
      'estimated_weight': estimatedWeight,
      'serves_count': servesCount,
      'food_condition': foodCondition,
      'packaging': packaging,
      'requires_refrigeration': requiresRefrigeration,
      'is_halal': isHalal,
      'is_vegetarian': isVegetarian,
      'pickup_notes': pickupNotes,
      'contact_name': contactName,
      'contact_phone': contactPhone,
      'pickup_window_minutes': pickupWindowMinutes,
      'priority': priority,
      'views': views,
      'interested_count': interestedCount,
      'shares': shares,
    };
  }

  List<String> get displayImages {
    final result = <String>[];
    final single = image?.trim();
    if (single != null && single.isNotEmpty) result.add(single);
    for (final value in images ?? const <String>[]) {
      final text = value.trim();
      if (text.isNotEmpty && !result.contains(text)) result.add(text);
    }
    return List<String>.unmodifiable(result);
  }

  String? get displayImage =>
      displayImages.isEmpty ? null : displayImages.first;

  static String? _firstImage(List<dynamic> values) {
    final all = _imageList(values);
    if (all == null || all.isEmpty) return null;
    return all.first;
  }

  static List<String>? _imageList(List<dynamic> values) {
    final result = <String>[];
    for (final value in values) {
      _collectImages(value, result);
    }
    return result.isEmpty ? null : List<String>.unmodifiable(result);
  }

  static void _collectImages(dynamic value, List<String> result) {
    if (value is List) {
      for (final item in value) {
        _collectImages(item, result);
      }
      return;
    }
    if (value is Map) {
      for (final key in const ['public_url', 'url', 'image_url', 'path']) {
        _collectImages(value[key], result);
      }
      return;
    }
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty || text == 'null') return;
    try {
      final decoded = jsonDecode(text);
      if (decoded is List || decoded is Map) {
        _collectImages(decoded, result);
        return;
      }
    } catch (_) {
      // Keep plain URL values.
    }
    for (final part in text.split(',')) {
      final url = part.trim();
      if (url.isNotEmpty && !result.contains(url)) result.add(url);
    }
  }

  // ✅ Get business name
  String get businessName {
    return business?['name'] as String? ?? 'مطعم';
  }

  // ✅ Get business logo
  String? get businessLogo {
    return business?['logo'] as String?;
  }

  // ✅ Get business rating
  double get businessRating {
    final rating = business?['rating'] as num?;
    return rating?.toDouble() ?? 0.0;
  }

  // ✅ Get business type
  String get businessType {
    return business?['business_type'] as String? ?? 'restaurant';
  }

  // ✅ إحداثيات الخريطة
  double get mapLatitude =>
      (business?['latitude'] as num?)?.toDouble() ?? latitude;
  double get mapLongitude =>
      (business?['longitude'] as num?)?.toDouble() ?? longitude;

  // ✅ العنوان اللي يتعرض
  String get displayLocation =>
      pickupLocation.isNotEmpty && pickupLocation != 'موقع غير محدد'
          ? pickupLocation
          : (business?['address'] as String? ?? 'طنطا - شارع البحر');

  // ✅ Helper properties
  bool get isAvailable => status == FoodOfferStatus.available;
  bool get isReserved => status == FoodOfferStatus.reserved;
  bool get isCompleted => status == FoodOfferStatus.completed;
  bool get isCancelled => status == FoodOfferStatus.cancelled;

  bool get isExpired => DateTime.now().isAfter(expiryTime);

  bool get isUrgent {
    final hoursRemaining = expiryTime.difference(DateTime.now()).inHours;
    return hoursRemaining <= 2 && isAvailable;
  }

  String get timeRemaining {
    final now = DateTime.now();
    final difference = expiryTime.difference(now);

    if (difference.inDays > 0) {
      return '${difference.inDays} يوم';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} ساعة';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} دقيقة';
    } else {
      return 'انتهى';
    }
  }

  String get statusDisplay {
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

  @override
  List<Object?> get props => [
        id,
        title,
        description,
        quantity,
        foodType,
        expiryTime,
        pickupBefore,
        pickupLocation,
        latitude,
        longitude,
        image,
        status,
        businessId,
        charityId,
        createdAt,
        updatedAt,
        business,
        images,
        estimatedWeight,
        servesCount,
        foodCondition,
        packaging,
        requiresRefrigeration,
        isHalal,
        isVegetarian,
        pickupNotes,
        contactName,
        contactPhone,
        pickupWindowMinutes,
        priority,
        views,
        interestedCount,
        shares,
      ];
}
