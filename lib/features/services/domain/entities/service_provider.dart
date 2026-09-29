// lib/features/services/domain/entities/service_provider.dart

import 'dart:convert';

class ServiceProvider {
  final String id;
  final String userId;
  final String categoryId;
  final String? categoryName;
  final String? categoryIcon;
  final String? categorySlug;

  final String providerType; // individual | freelancer | company
  final String displayName;
  final String? bio;
  final int? experienceYears;
  final List<String> skills;

  final String? profileImageUrl;
  final String? coverImageUrl;
  final List<String> portfolioImages;

  final String? city;
  final String? address;
  final List<String> serviceAreas;
  final double? latitude;
  final double? longitude;
  final int maxDistanceKm;

  final String pricingType; // free | symbolic | market
  final double? priceFrom;
  final String priceCurrency;
  final bool acceptsInstallments;

  final String? phone;
  final String? whatsapp;
  final String? email;
  final String? website;

  // شركات
  final String? companyLegalName;
  final int? employeesCount;
  final int? foundedYear;
  final List<dynamic> branches;

  // توثيق
  final String verificationStatus;
  final bool isActive;
  final bool isAvailable;
  final String? availabilityNote;

  // إحصائيات
  final int totalJobs;
  final int completedJobs;
  final int volunteerJobs;
  final double ratingAvg;
  final int totalReviews;

  // owner
  final String? ownerName;
  final String? ownerAvatar;

  const ServiceProvider({
    required this.id,
    required this.userId,
    required this.categoryId,
    this.categoryName,
    this.categoryIcon,
    this.categorySlug,
    this.providerType = 'individual',
    required this.displayName,
    this.bio,
    this.experienceYears,
    this.skills = const [],
    this.profileImageUrl,
    this.coverImageUrl,
    this.portfolioImages = const [],
    this.city,
    this.address,
    this.serviceAreas = const [],
    this.latitude,
    this.longitude,
    this.maxDistanceKm = 15,
    this.pricingType = 'market',
    this.priceFrom,
    this.priceCurrency = 'EGP',
    this.acceptsInstallments = false,
    this.phone,
    this.whatsapp,
    this.email,
    this.website,
    this.companyLegalName,
    this.employeesCount,
    this.foundedYear,
    this.branches = const [],
    this.verificationStatus = 'pending',
    this.isActive = true,
    this.isAvailable = true,
    this.availabilityNote,
    this.totalJobs = 0,
    this.completedJobs = 0,
    this.volunteerJobs = 0,
    this.ratingAvg = 0,
    this.totalReviews = 0,
    this.ownerName,
    this.ownerAvatar,
  });

  bool get isCompany => providerType == 'company';
  bool get isVerified => verificationStatus == 'approved';
  bool get isFree => pricingType == 'free';
  bool get isSymbolic => pricingType == 'symbolic';

  String get pricingLabel {
    switch (pricingType) {
      case 'free':
        return 'تطوعي';
      case 'symbolic':
        return 'سعر رمزي';
      default:
        return priceFrom != null && priceFrom! > 0
            ? 'من ${priceFrom!.toStringAsFixed(0)} ج.م'
            : 'سعر السوق';
    }
  }

  factory ServiceProvider.fromMap(Map<String, dynamic> map) {
    final portfolio = _parseImages(map['portfolio_images']);

    return ServiceProvider(
      id: map['id']?.toString() ?? '',
      userId: map['user_id']?.toString() ?? '',
      categoryId: map['category_id']?.toString() ?? '',
      categoryName: map['category_name']?.toString(),
      categoryIcon: map['category_icon']?.toString(),
      categorySlug: map['category_slug']?.toString(),
      providerType: map['provider_type']?.toString() ?? 'individual',
      displayName: map['display_name']?.toString() ?? '',
      bio: map['bio']?.toString(),
      experienceYears: _asInt(map['experience_years']),
      skills: _stringList(map['skills']),
      profileImageUrl: _parseImageUrl(map['profile_image_url']),
      coverImageUrl: _parseImageUrl(map['cover_image_url']),
      portfolioImages: portfolio,
      city: map['city']?.toString(),
      address: map['address']?.toString(),
      serviceAreas: _stringList(map['service_areas']),
      latitude: _asDouble(map['latitude']),
      longitude: _asDouble(map['longitude']),
      maxDistanceKm: _asInt(map['max_distance_km']) ?? 15,
      pricingType: map['pricing_type']?.toString() ?? 'market',
      priceFrom: _asDouble(map['price_from']),
      priceCurrency: map['price_currency']?.toString() ?? 'EGP',
      acceptsInstallments: map['accepts_installments'] as bool? ?? false,
      phone: map['phone']?.toString(),
      whatsapp: map['whatsapp']?.toString(),
      email: map['email']?.toString(),
      website: map['website']?.toString(),
      companyLegalName: map['company_legal_name']?.toString(),
      employeesCount: _asInt(map['employees_count']),
      foundedYear: _asInt(map['founded_year']),
      branches: _parseBranches(map['branches']),
      verificationStatus: map['verification_status']?.toString() ?? 'pending',
      isActive: map['is_active'] as bool? ?? true,
      isAvailable: map['is_available'] as bool? ?? true,
      availabilityNote: map['availability_note']?.toString(),
      totalJobs: _asInt(map['total_jobs']) ?? 0,
      completedJobs: _asInt(map['completed_jobs']) ?? 0,
      volunteerJobs: _asInt(map['volunteer_jobs']) ?? 0,
      ratingAvg: _asDouble(map['rating_avg']) ?? 0,
      totalReviews: _asInt(map['total_reviews']) ?? 0,
      ownerName: map['owner_name']?.toString(),
      ownerAvatar: map['owner_avatar']?.toString(),
    );
  }

  static double? _asDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString().trim());
  }

  static int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toInt();
    final text = value.toString().trim();
    return int.tryParse(text) ?? double.tryParse(text)?.toInt();
  }

  // ═══════════════════════════════════════════════════════════
  // ✅ Parsers قوية — بتشتغل مع أي شكل بيانات
  // ═══════════════════════════════════════════════════════════

  /// صور متعددة (portfolio)
  static List<String> _parseImages(dynamic value) {
    if (value == null) return const [];

    // List عادي
    if (value is List) {
      return value
          .map((e) => e?.toString() ?? '')
          .where((s) => s.isNotEmpty && s != 'null')
          .toList();
    }

    // JSON string
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty || trimmed == 'null') return const [];

      if (trimmed.startsWith('[')) {
        try {
          final decoded = jsonDecode(trimmed);
          if (decoded is List) {
            return decoded
                .map((e) => e?.toString() ?? '')
                .where((s) => s.isNotEmpty && s != 'null')
                .toList();
          }
        } catch (e) {
          debugPrint('❌ JSON decode error: $e');
        }
      }

      // string واحد مفصول بفاصلة
      if (trimmed.contains(',')) {
        return trimmed
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty && s != 'null')
            .toList();
      }

      // URL واحد
      if (trimmed.startsWith('http')) {
        return [trimmed];
      }
    }

    return const [];
  }

  /// URL واحد (غلاف / أفاتار)
  static String? _parseImageUrl(dynamic value) {
    if (value == null) return null;
    final s = value.toString().trim();
    if (s.isEmpty || s == 'null') return null;
    return s;
  }

  /// قائمة نصوص عادية (skills, service_areas)
  static List<String> _stringList(dynamic value) {
    if (value == null) return const [];

    if (value is List) {
      return value
          .map((e) => e?.toString() ?? '')
          .where((s) => s.isNotEmpty && s != 'null')
          .toList();
    }

    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty || trimmed == 'null') return const [];

      // JSON array
      if (trimmed.startsWith('[')) {
        try {
          final decoded = jsonDecode(trimmed);
          if (decoded is List) {
            return decoded
                .map((e) => e?.toString() ?? '')
                .where((s) => s.isNotEmpty && s != 'null')
                .toList();
          }
        } catch (_) {}
      }

      // مفصول بفواصل
      if (trimmed.contains(',')) {
        return trimmed
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty && s != 'null')
            .toList();
      }

      return [trimmed];
    }

    return const [];
  }

  /// الفروع (JSON array من objects)
  static List<dynamic> _parseBranches(dynamic value) {
    if (value == null) return const [];

    if (value is List) return value;

    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty || trimmed == 'null') return const [];

      if (trimmed.startsWith('[')) {
        try {
          final decoded = jsonDecode(trimmed);
          if (decoded is List) return decoded;
        } catch (e) {
          debugPrint('❌ branches JSON error: $e');
        }
      }
    }

    return const [];
  }
}
