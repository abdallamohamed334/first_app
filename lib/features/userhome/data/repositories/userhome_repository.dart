// lib/features/userhome/data/repositories/userhome_repository.dart

import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:loqma/core/models/community_stats.dart';
import 'package:loqma/core/models/nearby_place.dart';
import 'package:loqma/core/services/supabase_service.dart';
import 'package:loqma/features/offers/domain/entities/food_offer.dart';
import 'package:loqma/features/userhome/domain/entities/category_offer.dart';
import 'package:loqma/features/userhome/presentation/widgets/home_banner_carousel.dart';
import 'package:loqma/features/userhome/presentation/widgets/home_delivery_donations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserHomeRepository {
  final SupabaseService _supabaseService;

  UserHomeRepository({
    required SupabaseService supabaseService,
  }) : _supabaseService = supabaseService;

  SupabaseClient get _client => _supabaseService.client;

  // ---------------------------------------------------------------------------
  // Current User
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>?> getCurrentUser() async {
    try {
      final session = await _supabaseService.getCurrentSession();

      if (session == null) {
        return null;
      }

      return {
        'id': session.user.id,
        'email': session.user.email,
      };
    } catch (e) {
      debugPrint('❌ getCurrentUser error: $e');
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // User Data
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>?> getUserData() async {
    try {
      final session = await _supabaseService.getCurrentSession();

      if (session == null) {
        return null;
      }

      final response = await _client
          .from('users')
          .select('latitude, longitude, city')
          .eq('id', session.user.id)
          .maybeSingle();

      return response;
    } catch (e) {
      debugPrint('❌ getUserData error: $e');
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Nearby Restaurant Offers
  // ---------------------------------------------------------------------------

  Future<List<FoodOffer>> getNearbyRestaurantOffers({
    required double latitude,
    required double longitude,
    double radiusKm = 10,
  }) async {
    try {
      debugPrint('📌 getNearbyRestaurantOffers: START');

      final now = DateTime.now().toUtc().toIso8601String();

      final response = await _client
          .from('food_offers')
          .select('''
            *,
            businesses:business_id (
              id,
              name,
              logo,
              address,
              phone,
              rating,
              latitude,
              longitude,
              business_type
            )
          ''')
          .eq('status', 'available')
          .eq('is_paused', false)
          .gt('expiry_time', now)
          .order('created_at', ascending: false);

      final offers = <FoodOffer>[];

      for (final rawJson in response) {
        try {
          final json = Map<String, dynamic>.from(rawJson);

          final businessRaw = json['businesses'];

          if (businessRaw is! Map) {
            continue;
          }

          final business = Map<String, dynamic>.from(businessRaw);

          final businessType =
              business['business_type']?.toString().toLowerCase() ?? '';

          if (businessType != 'restaurant') {
            continue;
          }

          final businessLat = _toDouble(business['latitude']);
          final businessLng = _toDouble(business['longitude']);

          if (businessLat == null || businessLng == null) {
            continue;
          }

          final distance = _calculateDistance(
            latitude,
            longitude,
            businessLat,
            businessLng,
          );

          if (distance > radiusKm) {
            continue;
          }

          final baseOffer = FoodOffer.fromJson(json);

          final offer = baseOffer.copyWith(
            source: 'restaurant',
            distanceMeters: distance * 1000,
          );

          offers.add(offer);
        } catch (e) {
          debugPrint('⚠️ Failed to parse restaurant offer: $e');
        }
      }

      offers.sort(
        (a, b) => (a.distanceMeters ?? 0).compareTo(b.distanceMeters ?? 0),
      );

      return offers;
    } catch (e, stack) {
      debugPrint('❌ getNearbyRestaurantOffers ERROR: $e');
      debugPrintStack(stackTrace: stack);
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // Distance Calculation
  // ---------------------------------------------------------------------------

  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadiusKm = 6371.0;

    final dLat = _degToRad(lat2 - lat1);
    final dLon = _degToRad(lon2 - lon1);

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degToRad(lat1)) *
            cos(_degToRad(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadiusKm * c;
  }

  double _degToRad(double degrees) {
    return degrees * (pi / 180);
  }

  // ---------------------------------------------------------------------------
  // All Food Offers
  // ---------------------------------------------------------------------------

  Future<List<FoodOffer>> getOffers() async {
    try {
      debugPrint('📌 getOffers: START');

      final now = DateTime.now().toUtc().toIso8601String();

      final response = await _client
          .from('food_offers')
          .select('''
            *,
            businesses:business_id (
              id,
              name,
              logo,
              address,
              phone,
              rating,
              latitude,
              longitude,
              business_type
            )
          ''')
          .eq('status', 'available')
          .eq('is_paused', false)
          .gt('expiry_time', now)
          .order('created_at', ascending: false);

      final offers = <FoodOffer>[];

      for (final rawJson in response) {
        try {
          final json = Map<String, dynamic>.from(rawJson);

          final businessRaw = json['businesses'];

          Map<String, dynamic>? business;

          if (businessRaw is Map) {
            business = Map<String, dynamic>.from(businessRaw);
          }

          final businessType =
              business?['business_type']?.toString().toLowerCase() ?? '';

          final baseOffer = FoodOffer.fromJson(json);

          final source =
              businessType == 'restaurant' ? 'restaurant' : 'institution';

          offers.add(baseOffer.copyWith(source: source));
        } catch (e) {
          debugPrint('⚠️ Failed to parse food offer: $e');
        }
      }

      return offers;
    } catch (e, stack) {
      debugPrint('❌ getOffers ERROR: $e');
      debugPrintStack(stackTrace: stack);
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // User City
  // ---------------------------------------------------------------------------

  Future<String?> getUserCity() async {
    try {
      final session = await _supabaseService.getCurrentSession();

      if (session == null) {
        return 'طنطا، الغربية';
      }

      final response = await _client
          .from('users')
          .select('city')
          .eq('id', session.user.id)
          .maybeSingle();

      final city = response?['city']?.toString().trim();

      if (city == null || city.isEmpty) {
        return 'طنطا، الغربية';
      }

      return city;
    } catch (e) {
      debugPrint('❌ getUserCity error: $e');
      return 'طنطا، الغربية';
    }
  }

  // ---------------------------------------------------------------------------
  // Delivery Tasks
  // ---------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> getDeliveryTasks() async {
    try {
      final response = await _client
          .from('delivery_tasks')
          .select('*')
          .eq('status', 'pending')
          .limit(10);

      return response.map((item) => Map<String, dynamic>.from(item)).toList();
    } catch (e) {
      debugPrint('❌ getDeliveryTasks error: $e');
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // Delivery Donations
  // ---------------------------------------------------------------------------

  Future<List<DeliveryDonation>> getDeliveryDonations() async {
    try {
      final response = await _client
          .from('charity_donation_requests')
          .select('''
            *,
            charities:charity_id (
              id,
              name,
              logo,
              address,
              phone
            ),
            users:donor_id (
              id,
              name,
              email,
              avatar_url
            )
          ''')
          .eq('status', 'pending')
          .order('created_at', ascending: false)
          .limit(10);

      final donations = <DeliveryDonation>[];

      for (final rawJson in response) {
        try {
          final json = Map<String, dynamic>.from(rawJson);

          final charityRaw = json['charities'];
          final charity = charityRaw is Map
              ? Map<String, dynamic>.from(charityRaw)
              : <String, dynamic>{};

          final charityName = charity['name']?.toString() ?? 'جمعية خيرية';

          final donorRaw = json['users'];
          final donor = donorRaw is Map
              ? Map<String, dynamic>.from(donorRaw)
              : <String, dynamic>{};

          final donorName = donor['name']?.toString() ?? 'متبرع';

          final imagesRaw = json['images'];
          final images = <String>[];

          if (imagesRaw is List) {
            for (final image in imagesRaw) {
              final value = image?.toString().trim();
              if (value != null && value.isNotEmpty) {
                images.add(value);
              }
            }
          }

          final image = images.isNotEmpty ? images.first : null;

          DateTime createdAt = DateTime.now();
          final createdAtRaw = json['created_at']?.toString();
          if (createdAtRaw != null && createdAtRaw.isNotEmpty) {
            createdAt = DateTime.tryParse(createdAtRaw) ?? DateTime.now();
          }

          final donation = DeliveryDonation(
            id: json['id']?.toString() ?? '',
            title: json['title']?.toString() ?? 'تبرع طعام',
            description: json['description']?.toString() ?? '',
            pickupLocation: json['pickup_location']?.toString() ?? 'غير محدد',
            deliveryLocation:
                json['delivery_location']?.toString() ?? 'غير محدد',
            distance: 0.0,
            quantity: _toInt(json['quantity']) ?? 0,
            foodType: json['food_type']?.toString() ?? 'وجبات',
            status: json['status']?.toString() ?? 'pending',
            donorName: donorName,
            donorImage: donor['avatar_url']?.toString(),
            createdAt: createdAt,
            image: image,
            charityName: charityName,
            city: json['pickup_city']?.toString() ?? '',
          );

          donations.add(donation);
        } catch (e) {
          debugPrint('⚠️ Failed to parse delivery donation: $e');
        }
      }

      return donations;
    } catch (e, stack) {
      debugPrint('❌ getDeliveryDonations ERROR: $e');
      debugPrintStack(stackTrace: stack);
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // Community Stats
  // ---------------------------------------------------------------------------

  Future<CommunityStats> getCommunityStats() async {
    return const CommunityStats();
  }

  // ---------------------------------------------------------------------------
  // Nearby Places
  // ---------------------------------------------------------------------------

  Future<List<NearbyPlace>> getNearbyPlaces() async {
    return [];
  }

  // ---------------------------------------------------------------------------
  // Home Banners
  // ---------------------------------------------------------------------------

  Future<List<HomeBanner>> getHomeBanners() async {
    try {
      final response = await _client
          .from('home_banners')
          .select('id, image_url, offer_id, sort_order')
          .eq('is_active', true)
          .filter('starts_at', 'is', 'null')
          .filter('ends_at', 'is', 'null')
          .order('sort_order', ascending: true);

      return response.map((json) => HomeBanner.fromJson(json)).toList();
    } catch (e, stack) {
      debugPrint('❌ getHomeBanners error: $e');
      debugPrintStack(stackTrace: stack);
      return [];
    }
  }

  // ===========================================================================
  // MARKETPLACE CATEGORIES
  // ===========================================================================

  Future<List<Map<String, dynamic>>> getMainCategories() async {
    try {
      debugPrint('📌 getMainCategories: START');

      final response = await _client
          .from('marketplace_categories')
          .select('id, slug, name_ar, name_en, icon, sort_order')
          .filter('parent_id', 'is', null)
          .eq('is_active', true)
          .order('sort_order', ascending: true);

      return response.map((item) => Map<String, dynamic>.from(item)).toList();
    } catch (e, stack) {
      debugPrint('❌ getMainCategories ERROR: $e');
      debugPrintStack(stackTrace: stack);
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getSubCategories(
    String parentId,
  ) async {
    try {
      final response = await _client
          .from('marketplace_categories')
          .select('id, slug, name_ar, name_en, icon, sort_order')
          .eq('parent_id', parentId)
          .eq('is_active', true)
          .order('sort_order', ascending: true);

      return response.map((item) => Map<String, dynamic>.from(item)).toList();
    } catch (e) {
      debugPrint('❌ getSubCategories error: $e');
      return [];
    }
  }

  // ===========================================================================
  // OFFERS BY CATEGORY
  // ===========================================================================

  Future<List<CategoryOffer>> getOffersByCategory({
    required String categoryId,
    double? latitude,
    double? longitude,
    double radiusKm = 10,
  }) async {
    try {
      // ------------------------------------------------------
      // 1) جيب الـ slug + الـ subcategories
      // ------------------------------------------------------

      final categoryInfo = await _client
          .from('marketplace_categories')
          .select('id, slug')
          .eq('id', categoryId)
          .maybeSingle();

      final slug = categoryInfo?['slug']?.toString() ?? '';
      final isFood = slug == 'food';
      final isGrocery = slug == 'grocery';

      debugPrint(
        '📌 getOffersByCategory: categoryId=$categoryId '
        'slug=$slug isFood=$isFood isGrocery=$isGrocery',
      );

      // ------------------------------------------------------
      // 2) اجمع كل الـ IDs: التصنيف + الفرعيات
      // ------------------------------------------------------

      final subCategories = await getSubCategories(categoryId);
      final allCategoryIds = <String>[
        categoryId,
        ...subCategories
            .map((c) => c['id']?.toString() ?? '')
            .where((id) => id.isNotEmpty),
      ];

      debugPrint(
        '📌 getOffersByCategory: allCategoryIds=${allCategoryIds.length}',
      );

      // ------------------------------------------------------
      // 3) اجلب العروض حسب نوع التصنيف
      // ------------------------------------------------------

      final results = <List<CategoryOffer>>[];

      // community (عروض المستخدمين) دايماً موجودة
      results.add(
        await _getCommunityOffersByCategoryIds(allCategoryIds),
      );

      if (isFood) {
        // ✅ food → عروض المطاعم بس من food_offers
        results.add(
          await _getFoodOffersByCategoryIds(allCategoryIds),
        );
      } else if (isGrocery) {
        // ✅ grocery → عروض البقالة من institution_offers
        results.add(
          await _getInstitutionOffersByCategoryIds(allCategoryIds),
        );
      } else {
        // باقي التصنيفات → institution_offers + food_offers
        final institution = await _getInstitutionOffersByCategoryIds(
          allCategoryIds,
        );
        final food = await _getFoodOffersByCategoryIds(allCategoryIds);
        results.add([...institution, ...food]);
      }

      final allOffers = <CategoryOffer>[
        for (final list in results) ...list,
      ];

      // ------------------------------------------------------
      // 4) حساب المسافة
      // ------------------------------------------------------

      if (latitude != null && longitude != null) {
        for (int i = 0; i < allOffers.length; i++) {
          final offer = allOffers[i];

          if (offer.latitude == null || offer.longitude == null) {
            continue;
          }

          final distance = _calculateDistance(
            latitude,
            longitude,
            offer.latitude!,
            offer.longitude!,
          );

          allOffers[i] = CategoryOffer(
            id: offer.id,
            title: offer.title,
            description: offer.description,
            price: offer.price,
            originalPrice: offer.originalPrice,
            image: offer.image,
            images: offer.images,
            ownerType: offer.ownerType,
            ownerName: offer.ownerName,
            ownerLogo: offer.ownerLogo,
            latitude: offer.latitude,
            longitude: offer.longitude,
            distanceMeters: distance * 1000,
            categoryId: offer.categoryId,
            categoryName: offer.categoryName,
            status: offer.status,
            createdAt: offer.createdAt,
            raw: offer.raw,
          );
        }
      }

      // ------------------------------------------------------
      // 5) الفلترة حسب نصف القطر
      // ------------------------------------------------------

      final filtered = <CategoryOffer>[];
      for (final offer in allOffers) {
        if (latitude != null &&
            longitude != null &&
            offer.distanceMeters != null &&
            offer.distanceMeters! > radiusKm * 1000) {
          continue;
        }
        filtered.add(offer);
      }

      // ------------------------------------------------------
      // 6) الترتيب
      // ------------------------------------------------------

      filtered.sort((a, b) {
        if (a.distanceMeters != null && b.distanceMeters != null) {
          return a.distanceMeters!.compareTo(b.distanceMeters!);
        }
        return b.createdAt.compareTo(a.createdAt);
      });

      debugPrint(
        '📌 getOffersByCategory: total=${filtered.length} '
        '(categories=${allCategoryIds.length})',
      );

      return filtered;
    } catch (e, stack) {
      debugPrint('❌ getOffersByCategory ERROR: $e');
      debugPrintStack(stackTrace: stack);
      return [];
    }
  }

  // -----------------------------------------------------------
  // Community Offers - Multiple Categories
  // -----------------------------------------------------------

  Future<List<CategoryOffer>> _getCommunityOffersByCategoryIds(
    List<String> categoryIds,
  ) async {
    if (categoryIds.isEmpty) return [];

    try {
      final response = await _client
          .from('community_offers')
          .select('''
            id,
            title,
            description,
            price,
            image,
            images,
            marketplace_category_id,
            status,
            latitude,
            longitude,
            created_at,
            owner:owner_id (
              id,
              name,
              avatar_url
            ),
            marketplace_categories:marketplace_category_id (
              id,
              name_ar
            )
          ''')
          .inFilter('marketplace_category_id', categoryIds)
          .eq('status', 'available')
          .order('created_at', ascending: false)
          .limit(200);

      final offers = <CategoryOffer>[];

      for (final raw in response) {
        try {
          final json = Map<String, dynamic>.from(raw);

          final userRaw = json['owner'];
          final user = userRaw is Map
              ? Map<String, dynamic>.from(userRaw)
              : <String, dynamic>{};

          final categoryRaw = json['marketplace_categories'];
          final category = categoryRaw is Map
              ? Map<String, dynamic>.from(categoryRaw)
              : <String, dynamic>{};

          final images = <String>[];
          final imagesRaw = json['images'];
          if (imagesRaw is List) {
            for (final img in imagesRaw) {
              final s = img?.toString().trim();
              if (s != null && s.isNotEmpty) images.add(s);
            }
          }
          final singleImage = json['image']?.toString().trim();
          if (singleImage != null &&
              singleImage.isNotEmpty &&
              !images.contains(singleImage)) {
            images.insert(0, singleImage);
          }

          final createdAt = DateTime.tryParse(
                json['created_at']?.toString() ?? '',
              ) ??
              DateTime.now();

          offers.add(
            CategoryOffer(
              id: json['id']?.toString() ?? '',
              title: json['title']?.toString() ?? 'عرض',
              description: json['description']?.toString(),
              price: _toDouble(json['price']),
              image: images.isNotEmpty ? images.first : null,
              images: images,
              ownerType: 'community',
              ownerName: user['name']?.toString(),
              ownerLogo: user['avatar_url']?.toString(),
              latitude: _toDouble(json['latitude']),
              longitude: _toDouble(json['longitude']),
              categoryId: json['marketplace_category_id']?.toString(),
              categoryName: category['name_ar']?.toString(),
              status: json['status']?.toString() ?? 'available',
              createdAt: createdAt,
              raw: json,
            ),
          );
        } catch (e) {
          debugPrint('⚠️ community parse error: $e');
        }
      }

      return offers;
    } catch (e) {
      debugPrint('❌ _getCommunityOffersByCategoryIds error: $e');
      return [];
    }
  }

  // -----------------------------------------------------------
  // Institution Offers - Multiple Categories
  // -----------------------------------------------------------

  Future<List<CategoryOffer>> _getInstitutionOffersByCategoryIds(
    List<String> categoryIds,
  ) async {
    if (categoryIds.isEmpty) return [];

    try {
      final response = await _client
          .from('institution_offers')
          .select('''
            id,
            title,
            description,
            symbolic_price,
            original_price,
            images,
            marketplace_category_id,
            status,
            latitude,
            longitude,
            created_at,
            institutions:institution_id (
              id,
              name,
              logo_url
            ),
            marketplace_categories:marketplace_category_id (
              id,
              name_ar
            )
          ''')
          .inFilter('marketplace_category_id', categoryIds)
          .eq('status', 'active')
          .order('created_at', ascending: false)
          .limit(200);

      final offers = <CategoryOffer>[];

      for (final raw in response) {
        try {
          final json = Map<String, dynamic>.from(raw);

          final instRaw = json['institutions'];
          final inst = instRaw is Map
              ? Map<String, dynamic>.from(instRaw)
              : <String, dynamic>{};

          final categoryRaw = json['marketplace_categories'];
          final category = categoryRaw is Map
              ? Map<String, dynamic>.from(categoryRaw)
              : <String, dynamic>{};

          final images = <String>[];
          final imagesRaw = json['images'];
          if (imagesRaw is List) {
            for (final img in imagesRaw) {
              final s = img?.toString().trim();
              if (s != null && s.isNotEmpty) images.add(s);
            }
          }

          final createdAt = DateTime.tryParse(
                json['created_at']?.toString() ?? '',
              ) ??
              DateTime.now();

          offers.add(
            CategoryOffer(
              id: json['id']?.toString() ?? '',
              title: json['title']?.toString() ?? 'عرض',
              description: json['description']?.toString(),
              price: _toDouble(json['symbolic_price']),
              originalPrice: _toDouble(json['original_price']),
              image: images.isNotEmpty ? images.first : null,
              images: images,
              ownerType: 'institution',
              ownerName: inst['name']?.toString(),
              ownerLogo: inst['logo_url']?.toString(),
              latitude: _toDouble(json['latitude']),
              longitude: _toDouble(json['longitude']),
              categoryId: json['marketplace_category_id']?.toString(),
              categoryName: category['name_ar']?.toString(),
              status: json['status']?.toString() ?? 'active',
              createdAt: createdAt,
              raw: json,
            ),
          );
        } catch (e) {
          debugPrint('⚠️ institution parse error: $e');
        }
      }

      return offers;
    } catch (e) {
      debugPrint('❌ _getInstitutionOffersByCategoryIds error: $e');
      return [];
    }
  }

  // -----------------------------------------------------------
  // Food Offers - Multiple Categories (Restaurants)
  // -----------------------------------------------------------

  Future<List<CategoryOffer>> _getFoodOffersByCategoryIds(
    List<String> categoryIds,
  ) async {
    if (categoryIds.isEmpty) return [];

    try {
      final response = await _client
          .from('food_offers')
          .select('''
            id,
            title,
            description,
            sale_price,
            original_price,
            images,
            image,
            marketplace_category_id,
            status,
            latitude,
            longitude,
            created_at,
            is_paused,
            business:business_id (
              id,
              name,
              logo,
              latitude,
              longitude,
              business_type
            ),
            marketplace_categories:marketplace_category_id (
              id,
              name_ar
            )
          ''')
          .inFilter('marketplace_category_id', categoryIds)
          .eq('status', 'available')
          .eq('is_paused', false)
          .order('created_at', ascending: false)
          .limit(200);

      final offers = <CategoryOffer>[];

      for (final raw in response) {
        try {
          final json = Map<String, dynamic>.from(raw);

          final bizRaw = json['business'];
          final biz = bizRaw is Map
              ? Map<String, dynamic>.from(bizRaw)
              : <String, dynamic>{};

          final businessType =
              biz['business_type']?.toString().toLowerCase() ?? '';
          if (businessType != 'restaurant') {
            continue;
          }

          final categoryRaw = json['marketplace_categories'];
          final category = categoryRaw is Map
              ? Map<String, dynamic>.from(categoryRaw)
              : <String, dynamic>{};

          final images = <String>[];
          final imagesRaw = json['images'];
          if (imagesRaw is List) {
            for (final img in imagesRaw) {
              final s = img?.toString().trim();
              if (s != null && s.isNotEmpty) images.add(s);
            }
          }
          final singleImage = json['image']?.toString().trim();
          if (singleImage != null &&
              singleImage.isNotEmpty &&
              !images.contains(singleImage)) {
            images.insert(0, singleImage);
          }

          final createdAt = DateTime.tryParse(
                json['created_at']?.toString() ?? '',
              ) ??
              DateTime.now();

          final bizLat = _toDouble(biz['latitude']);
          final bizLng = _toDouble(biz['longitude']);

          offers.add(
            CategoryOffer(
              id: json['id']?.toString() ?? '',
              title: json['title']?.toString() ?? 'عرض',
              description: json['description']?.toString(),
              price: _toDouble(json['sale_price']),
              originalPrice: _toDouble(json['original_price']),
              image: images.isNotEmpty ? images.first : null,
              images: images,
              ownerType: 'restaurant',
              ownerName: biz['name']?.toString(),
              ownerLogo: biz['logo']?.toString(),
              latitude: bizLat,
              longitude: bizLng,
              categoryId: json['marketplace_category_id']?.toString(),
              categoryName: category['name_ar']?.toString(),
              status: json['status']?.toString() ?? 'available',
              createdAt: createdAt,
              raw: json,
            ),
          );
        } catch (e) {
          debugPrint('⚠️ food offer parse error: $e');
        }
      }

      return offers;
    } catch (e) {
      debugPrint('❌ _getFoodOffersByCategoryIds error: $e');
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }
}
