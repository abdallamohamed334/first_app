import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

class UserModel extends Equatable {
  final String id;
  final String name;
  final String email;
  final String? phone;
  final String? avatarUrl;
  final UserType type;
  final int level;
  final int points;
  final int mealsSaved;
  final int tasksCompleted;
  final bool isVerified;
  final String? city;
  final String? address;
  final DateTime createdAt;
  final DateTime? lastActive;
  final String? businessId;
  final String? restaurantId;
  final String? charityId;
  final String? institutionId;

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.avatarUrl,
    required this.type,
    this.level = 1,
    this.points = 0,
    this.mealsSaved = 0,
    this.tasksCompleted = 0,
    this.isVerified = false,
    this.city,
    this.address,
    required this.createdAt,
    this.lastActive,
    this.businessId,
    this.restaurantId,
    this.charityId,
    this.institutionId,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: _string(json['id']),
      name: _string(json['name'], fallback: 'مستخدم لقمة'),
      email: _string(json['email']),
      phone: _nullableString(json['phone']),
      avatarUrl: _nullableString(json['avatar_url']),
      type: UserType.fromString(json['user_type']),
      level: _toInt(json['level'], fallback: 1),
      points: _toInt(json['points']),
      mealsSaved: _toInt(json['meals_saved']),
      tasksCompleted: _toInt(json['tasks_completed']),
      isVerified: _toBool(json['is_verified']),
      city: _nullableString(json['city']),
      address: _nullableString(json['address']),
      createdAt: _toDateTime(json['created_at']) ?? DateTime.now().toUtc(),
      lastActive: _toDateTime(json['last_active']),
      businessId: _nullableString(json['business_id']),
      restaurantId: _nullableString(json['restaurant_id']),
      charityId: _nullableString(json['charity_id']),
      institutionId: _nullableString(json['institution_id']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'avatar_url': avatarUrl,
      'user_type': type.value,
      'level': level,
      'points': points,
      'meals_saved': mealsSaved,
      'tasks_completed': tasksCompleted,
      'is_verified': isVerified,
      'city': city,
      'address': address,
      'created_at': createdAt.toIso8601String(),
      'last_active': lastActive?.toIso8601String(),
      'business_id': businessId,
      'restaurant_id': restaurantId,
      'charity_id': charityId,
      'institution_id': institutionId,
    };
  }

  String get businessIdDisplay => businessId ?? restaurantId ?? '';

  UserModel copyWith({
    String? name,
    String? phone,
    String? avatarUrl,
    int? level,
    int? points,
    int? mealsSaved,
    int? tasksCompleted,
    bool? isVerified,
    String? city,
    String? address,
    DateTime? lastActive,
    String? businessId,
    String? restaurantId,
    String? charityId,
    String? institutionId,
  }) {
    return UserModel(
      id: id,
      name: name ?? this.name,
      email: email,
      phone: phone ?? this.phone,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      type: type,
      level: level ?? this.level,
      points: points ?? this.points,
      mealsSaved: mealsSaved ?? this.mealsSaved,
      tasksCompleted: tasksCompleted ?? this.tasksCompleted,
      isVerified: isVerified ?? this.isVerified,
      city: city ?? this.city,
      address: address ?? this.address,
      createdAt: createdAt,
      lastActive: lastActive ?? this.lastActive,
      businessId: businessId ?? this.businessId,
      restaurantId: restaurantId ?? this.restaurantId,
      charityId: charityId ?? this.charityId,
      institutionId: institutionId ?? this.institutionId,
    );
  }

  String get fullAddress {
    if (city != null && address != null) return '$address، $city';
    return address ?? city ?? 'لم يتم تحديد العنوان';
  }

  bool get hasLocationInfo => city != null || address != null;

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
        city,
        address,
        createdAt,
        lastActive,
        businessId,
        restaurantId,
        charityId,
        institutionId,
      ];

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
}

enum UserType {
  user('user'),
  restaurant('restaurant'),
  charity('charity'),
  institution('institution'),
  admin('admin');

  final String value;

  const UserType(this.value);

  static UserType fromString(dynamic value) {
    switch (value?.toString().trim().toLowerCase()) {
      case 'restaurant':
      case 'business':
        return UserType.restaurant;
      case 'charity':
        return UserType.charity;
      case 'institution':
        return UserType.institution;
      case 'admin':
        return UserType.admin;
      default:
        return UserType.user;
    }
  }

  String get displayName {
    switch (this) {
      case UserType.user:
        return 'مستخدم';
      case UserType.restaurant:
        return 'مطعم';
      case UserType.charity:
        return 'جمعية خيرية';
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
      case UserType.restaurant:
        return Icons.restaurant_rounded;
      case UserType.charity:
        return Icons.volunteer_activism_rounded;
      case UserType.institution:
        return Icons.storefront_rounded;
      case UserType.admin:
        return Icons.admin_panel_settings_rounded;
    }
  }
}

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
