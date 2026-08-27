import 'dart:convert';

import 'package:equatable/equatable.dart';

import 'business_type.dart';
import '../../../features/business/domain/entities/business_capability.dart';

class Business extends Equatable {
  final String id;
  final String? userId;
  final BusinessType type;
  final String name;
  final String? ownerName;
  final String phone;
  final String email;
  final String? logo;
  final String? address;
  final double? latitude;
  final double? longitude;
  final String? openingHours;
  final String status;
  final double rating;
  final int totalReviews;
  final bool isVerified;
  final String? description;
  final String? coverImage;
  final int points;
  final int completedCount;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final Set<BusinessCapability> capabilities;

  const Business({
    required this.id,
    this.userId,
    required this.type,
    required this.name,
    this.ownerName,
    required this.phone,
    required this.email,
    this.logo,
    this.address,
    this.latitude,
    this.longitude,
    this.openingHours,
    required this.status,
    required this.rating,
    required this.totalReviews,
    required this.isVerified,
    this.description,
    this.coverImage,
    required this.points,
    required this.completedCount,
    required this.createdAt,
    this.updatedAt,
    this.capabilities = const <BusinessCapability>{},
  });

  factory Business.fromJson(Map<String, dynamic> json) {
    final parsedCapabilities = <BusinessCapability>{};
    final rawCapabilities = json['capabilities'];
    final values = _capabilityValues(rawCapabilities);

    for (final value in values) {
      final capability = BusinessCapability.fromString(value);
      parsedCapabilities.add(capability);
    }

    return Business(
      id: _string(json['id']),
      userId: _nullableString(json['user_id']),
      type: BusinessType.fromString(_nullableString(json['business_type'])),
      name: _string(json['name']),
      ownerName: _nullableString(json['owner_name']),
      phone: _string(json['phone']),
      email: _string(json['email']),
      logo: _nullableString(json['logo']),
      address: _nullableString(json['address']),
      latitude: _toDouble(json['latitude']),
      longitude: _toDouble(json['longitude']),
      openingHours: _nullableString(json['opening_hours']),
      status: _string(json['status'], fallback: 'active'),
      rating: _toDouble(json['rating']) ?? 0,
      totalReviews: _toInt(json['total_reviews']),
      isVerified: _toBool(json['is_verified']),
      description: _nullableString(json['description']),
      coverImage: _nullableString(json['cover_image']),
      points: _toInt(json['points']),
      completedCount: _toInt(json['completed_count']),
      createdAt: _toDateTime(json['created_at']) ?? DateTime.now().toUtc(),
      updatedAt: _toDateTime(json['updated_at']),
      capabilities: Set<BusinessCapability>.unmodifiable(parsedCapabilities),
    );
  }

  bool can(BusinessCapability capability) => capabilities.contains(capability);

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'business_type': type.value,
      'name': name,
      'owner_name': ownerName,
      'phone': phone,
      'email': email,
      'logo': logo,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'opening_hours': openingHours,
      'status': status,
      'rating': rating,
      'total_reviews': totalReviews,
      'is_verified': isVerified,
      'description': description,
      'cover_image': coverImage,
      'points': points,
      'completed_count': completedCount,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'capabilities': capabilities.map((item) => item.value).toList(),
    };
  }

  static List<String> _capabilityValues(dynamic raw) {
    dynamic value = raw;
    if (value is String && value.trim().isNotEmpty) {
      try {
        value = jsonDecode(value);
      } catch (_) {
        value = value.split(',');
      }
    }

    if (value is! List) return const <String>[];
    return value
        .map((item) => item?.toString().trim() ?? '')
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  static String _string(dynamic value, {String fallback = ''}) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? fallback : text;
  }

  static String? _nullableString(dynamic value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  static int _toInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double? _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  static bool _toBool(dynamic value) {
    if (value is bool) return value;
    final normalized = value?.toString().trim().toLowerCase();
    return normalized == 'true' || normalized == '1' || normalized == 'yes';
  }

  static DateTime? _toDateTime(dynamic value) {
    if (value is DateTime) return value;
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        type,
        name,
        ownerName,
        phone,
        email,
        logo,
        address,
        latitude,
        longitude,
        openingHours,
        status,
        rating,
        totalReviews,
        isVerified,
        description,
        coverImage,
        points,
        completedCount,
        createdAt,
        updatedAt,
        capabilities,
      ];
}
