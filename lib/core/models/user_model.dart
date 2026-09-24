// lib/features/auth/domain/entities/user_model.dart

import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

class UserModel extends Equatable {
  final String id;
  final String name;
  final String? email;
  final String? phone;
  final String? avatarUrl;
  final UserType type;
  final int level;
  final int points;
  final int mealsSaved;
  final int tasksCompleted;
  final bool isVerified;
  final bool isPhoneVerified;
  final String? city;
  final String? address;

  // ✅ في Dart بنسميهم lat/lng (سهلة)، بس في DB: latitude/longitude
  final double? lat;
  final double? lng;

  final DateTime createdAt;
  final DateTime? lastActive;

  // ✅ Relations
  final String? serviceProviderId;
  final String? institutionId;

  const UserModel({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    this.avatarUrl,
    required this.type,
    this.level = 1,
    this.points = 0,
    this.mealsSaved = 0,
    this.tasksCompleted = 0,
    this.isVerified = false,
    this.isPhoneVerified = false,
    this.city,
    this.address,
    this.lat,
    this.lng,
    required this.createdAt,
    this.lastActive,
    this.serviceProviderId,
    this.institutionId,
  });

  // ═══════════════════════════════════════════════════════════
  // fromJson
  // ═══════════════════════════════════════════════════════════
  factory UserModel.fromJson(Map<String, dynamic> json) {
    final rawRole = json['role'] ?? json['user_type'];

    return UserModel(
      id: _string(json['id']),
      name: _string(json['name'], fallback: 'مستخدم جُود'),
      email: _nullableString(json['email']),
      phone: _nullableString(json['phone']),
      avatarUrl: _nullableString(json['avatar_url']),
      type: UserType.fromString(rawRole),
      level: _toInt(json['level'], fallback: 1),
      points: _toInt(json['points']),
      mealsSaved: _toInt(json['meals_saved']),
      tasksCompleted: _toInt(json['tasks_completed']),
      isVerified: _toBool(json['is_verified']),
      isPhoneVerified: _toBool(json['is_phone_verified']),
      city: _nullableString(json['city']),
      address: _nullableString(json['address']),
      // ✅ بنقرأ من latitude/longitude
      lat: _toDouble(json['latitude']),
      lng: _toDouble(json['longitude']),
      createdAt: _toDateTime(json['created_at']) ?? DateTime.now().toUtc(),
      lastActive: _toDateTime(json['last_active']),
      serviceProviderId: _nullableString(json['service_provider_id']),
      institutionId: _nullableString(json['institution_id']),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // toJson
  // ═══════════════════════════════════════════════════════════
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'avatar_url': avatarUrl,
      'role': type.value,
      'level': level,
      'points': points,
      'meals_saved': mealsSaved,
      'tasks_completed': tasksCompleted,
      'is_verified': isVerified,
      'is_phone_verified': isPhoneVerified,
      'city': city,
      'address': address,
      // ✅ بنكتب في latitude/longitude
      'latitude': lat,
      'longitude': lng,
      'created_at': createdAt.toIso8601String(),
      'last_active': lastActive?.toIso8601String(),
      'service_provider_id': serviceProviderId,
      'institution_id': institutionId,
    };
  }

  // ═══════════════════════════════════════════════════════════
  // Getters
  // ═══════════════════════════════════════════════════════════
  bool get isUser => type == UserType.user;
  bool get isProvider => type == UserType.provider;
  bool get isInstitution => type == UserType.institution;
  bool get isAdmin => type == UserType.admin;

  String get fullAddress {
    if (city != null && address != null) return '$address، $city';
    return address ?? city ?? 'لم يتم تحديد العنوان';
  }

  bool get hasLocationInfo => city != null || address != null;

  // ✅ هل عند المستخدم إحداثيات محفوظة؟
  bool get hasCoordinates => lat != null && lng != null;

  double get nextLevelProgress {
    final safeLevel = level < 1 ? 1 : level;
    final pointsForNextLevel = safeLevel * 100;
    final progress = (points % pointsForNextLevel) / pointsForNextLevel;
    return progress.clamp(0.0, 1.0).toDouble();
  }

  int get pointsToNextLevel {
    final safeLevel = level < 1 ? 1 : level;
    final pointsForNextLevel = safeLevel * 100;
    return pointsForNextLevel - (points % pointsForNextLevel);
  }

  String get levelTitle {
    switch (level) {
      case 2:
        return 'متطوع';
      case 3:
        return 'بطل إنقاذ';
      case 4:
        return 'سفير الخير';
      case 5:
        return 'أسطورة';
      default:
        return 'مبتدئ';
    }
  }

  // ═══════════════════════════════════════════════════════════
  // copyWith
  // ═══════════════════════════════════════════════════════════
  UserModel copyWith({
    String? name,
    String? email,
    String? phone,
    String? avatarUrl,
    UserType? type,
    int? level,
    int? points,
    int? mealsSaved,
    int? tasksCompleted,
    bool? isVerified,
    bool? isPhoneVerified,
    String? city,
    String? address,
    double? lat,
    double? lng,
    DateTime? lastActive,
    String? serviceProviderId,
    String? institutionId,
  }) {
    return UserModel(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      type: type ?? this.type,
      level: level ?? this.level,
      points: points ?? this.points,
      mealsSaved: mealsSaved ?? this.mealsSaved,
      tasksCompleted: tasksCompleted ?? this.tasksCompleted,
      isVerified: isVerified ?? this.isVerified,
      isPhoneVerified: isPhoneVerified ?? this.isPhoneVerified,
      city: city ?? this.city,
      address: address ?? this.address,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      createdAt: createdAt,
      lastActive: lastActive ?? this.lastActive,
      serviceProviderId: serviceProviderId ?? this.serviceProviderId,
      institutionId: institutionId ?? this.institutionId,
    );
  }

  // ═══════════════════════════════════════════════════════════
  // Equality
  // ═══════════════════════════════════════════════════════════
  @override
  List<Object?> get props => [
        id,
        name,
        email,
        phone,
        avatarUrl,
        type,
        level,
        points,
        mealsSaved,
        tasksCompleted,
        isVerified,
        isPhoneVerified,
        city,
        address,
        lat,
        lng,
        createdAt,
        lastActive,
        serviceProviderId,
        institutionId,
      ];

  // ═══════════════════════════════════════════════════════════
  // Helpers
  // ═══════════════════════════════════════════════════════════
  static String _string(dynamic value, {String fallback = ''}) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? fallback : text;
  }

  static String? _nullableString(dynamic value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  static int _toInt(dynamic value, {int fallback = 0}) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
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

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    final text = value.toString().trim();
    if (text.isEmpty) return null;
    return double.tryParse(text);
  }
}

// ═══════════════════════════════════════════════════════════════
// ✅ UserType
// ═══════════════════════════════════════════════════════════════
enum UserType {
  user('user'),
  provider('provider'),
  institution('institution'),
  admin('admin');

  final String value;

  const UserType(this.value);

  static UserType fromString(dynamic value) {
    switch (value?.toString().trim().toLowerCase()) {
      case 'provider':
        return UserType.provider;
      case 'institution':
      case 'charity':
        return UserType.institution;
      case 'admin':
        return UserType.admin;
      case 'restaurant':
      case 'business':
      case 'hotel':
      case 'supermarket':
      case 'bakery':
      case 'cafe':
      case 'user':
      default:
        return UserType.user;
    }
  }

  String get displayName {
    switch (this) {
      case UserType.user:
        return 'مستخدم';
      case UserType.provider:
        return 'مقدم خدمة';
      case UserType.institution:
        return 'مؤسسة';
      case UserType.admin:
        return 'مدير';
    }
  }

  IconData get icon {
    switch (this) {
      case UserType.user:
        return Icons.person_rounded;
      case UserType.provider:
        return Icons.handyman_rounded;
      case UserType.institution:
        return Icons.business_rounded;
      case UserType.admin:
        return Icons.admin_panel_settings_rounded;
    }
  }

  Color get color {
    switch (this) {
      case UserType.user:
        return const Color(0xFF3679C8);
      case UserType.provider:
        return const Color(0xFF2E9B5C);
      case UserType.institution:
        return const Color(0xFFE28B00);
      case UserType.admin:
        return const Color(0xFFE31C25);
    }
  }
}

// ═══════════════════════════════════════════════════════════════
// UserStats
// ═══════════════════════════════════════════════════════════════
class UserStats extends Equatable {
  final int points;
  final int mealsSaved;
  final int tasksCompleted;
  final int totalDonations;
  final int totalOffers;
  final int completedPickups;
  final double averageRating;

  const UserStats({
    this.points = 0,
    this.mealsSaved = 0,
    this.tasksCompleted = 0,
    this.totalDonations = 0,
    this.totalOffers = 0,
    this.completedPickups = 0,
    this.averageRating = 0,
  });

  factory UserStats.fromJson(Map<String, dynamic> json) {
    return UserStats(
      points: UserModel._toInt(json['points']),
      mealsSaved: UserModel._toInt(json['meals_saved']),
      tasksCompleted: UserModel._toInt(json['tasks_completed']),
      totalDonations: UserModel._toInt(json['total_donations']),
      totalOffers: UserModel._toInt(json['total_offers']),
      completedPickups: UserModel._toInt(json['completed_pickups']),
      averageRating: _toDouble(json['avg_rating']),
    );
  }

  factory UserStats.fromUserModel(UserModel user) {
    return UserStats(
      points: user.points,
      mealsSaved: user.mealsSaved,
      tasksCompleted: user.tasksCompleted,
    );
  }

  double getProgressForLevel(int level) {
    final safeLevel = level < 1 ? 1 : level;
    final pointsForNextLevel = safeLevel * 100;
    return (points % pointsForNextLevel) / pointsForNextLevel;
  }

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  @override
  List<Object?> get props => [
        points,
        mealsSaved,
        tasksCompleted,
        totalDonations,
        totalOffers,
        completedPickups,
        averageRating,
      ];
}
