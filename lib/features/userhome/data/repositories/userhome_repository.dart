// lib/features/userhome/data/repositories/userhome_repository.dart

import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:loqma/core/models/community_stats.dart';
import 'package:loqma/core/models/nearby_place.dart';
import 'package:loqma/core/services/supabase_service.dart';
import 'package:loqma/features/offers/domain/entities/food_offer.dart';
import 'package:loqma/features/userhome/domain/entities/category_offer.dart';
import 'package:loqma/features/userhome/domain/user_home_policy.dart';
import 'package:loqma/features/userhome/presentation/widgets/home_banner_carousel.dart';
import 'package:loqma/features/userhome/presentation/widgets/home_delivery_donations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserHomeRepository {
  static const _categoryRequestTimeout = Duration(seconds: 8);
  final SupabaseService _supabaseService;
  Future<Map<String, List<String>>>? _categoryChildrenFuture;
  final Map<String, String> _categorySlugById = <String, String>{};

  UserHomeRepository({required SupabaseService supabaseService})
    : _supabaseService = supabaseService;

  SupabaseClient get _client => _supabaseService.client;

  Future<Map<String, List<String>>> _getCategoryChildren() {
    final cached = _categoryChildrenFuture;
    if (cached != null) return cached;
    final future = _loadCategoryChildren();
    _categoryChildrenFuture = future;
    return future;
  }

  Future<Map<String, List<String>>> _loadCategoryChildren() async {
    try {
      final rows = await _client
          .from('marketplace_categories')
          .select('id, parent_id, slug')
          .eq('is_active', true)
          .limit(5000)
          .timeout(_categoryRequestTimeout);
      final childrenByParent = <String, List<String>>{};
      for (final raw in rows) {
        final row = Map<String, dynamic>.from(raw);
        final id = row['id']?.toString() ?? '';
        final parentId = row['parent_id']?.toString() ?? '';
        if (id.isEmpty) continue;
        final slug = row['slug']?.toString().trim().toLowerCase() ?? '';
        if (slug.isNotEmpty) _categorySlugById[id] = slug;
        if (parentId.isEmpty) continue;
        childrenByParent.putIfAbsent(parentId, () => <String>[]).add(id);
      }
      return childrenByParent;
    } catch (e, stack) {
      debugPrint('❌ _loadCategoryChildren error: $e');
      debugPrintStack(stackTrace: stack);
      _categoryChildrenFuture = null;
      return <String, List<String>>{};
    }
  }

  // ---------------------------------------------------------------------------
  // Current User
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>?> getCurrentUser() async {
    try {
      final session = await _supabaseService.getCurrentSession();

      if (session == null) {
        return null;
      }

      return {'id': session.user.id, 'email': session.user.email};
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

    final a =
        sin(dLat / 2) * sin(dLat / 2) +
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
          .order('created_at', ascending: false)
          .limit(100);

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

          final source = businessType == 'restaurant'
              ? 'restaurant'
              : 'institution';

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

  Future<List<Map<String, dynamic>>> getDeliveryTasks({
    required double latitude,
    required double longitude,
  }) async {
    try {
      final response = await _client.rpc(
        'nearby_rescue_tasks',
        params: {
          'p_lat': latitude,
          'p_lng': longitude,
          'p_radius_km': 15.0,
          'p_limit': 10,
        },
      );
      if (response is! List) return [];
      return response.map((raw) {
        final item = Map<String, dynamic>.from(raw as Map);
        return <String, dynamic>{
          'id': item['id'],
          'title': item['title'],
          'donor_name': item['donor_name'],
          'pickup_location': item['pickup_address'],
          'delivery_location': item['charity_name'],
          'quantity': item['quantity'],
          'distance': item['distance_km'],
          'pickup_before': item['pickup_before'],
        };
      }).toList();
    } catch (e) {
      debugPrint('❌ getDeliveryTasks error: $e');
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // Delivery Donations
  // ---------------------------------------------------------------------------

  Future<List<DeliveryDonation>> getDeliveryDonations() async {
    // التطوع المستقل متوقف عمدًا. صلاحية الـRPC القديم مغلقة في Production،
    // لذلك لا نستدعي list_open_donations_for_volunteers من User Home ونرجع
    // قائمة فارغة بدون ضوضاء في السجل.
    return <DeliveryDonation>[];
  }

  // ---------------------------------------------------------------------------
  // Community Stats
  // ---------------------------------------------------------------------------

  Future<CommunityStats> getCommunityStats() async {
    return _supabaseService.getCommunityStats();
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
      final now = DateTime.now().toUtc();
      final response = await _client
          .from('home_banners')
          .select('id, image_url, offer_id, sort_order, starts_at, ends_at')
          .eq('is_active', true)
          .order('sort_order', ascending: true)
          .limit(50);

      return response
          .where((json) {
            final startsAt = DateTime.tryParse(
              json['starts_at']?.toString() ?? '',
            );
            final endsAt = DateTime.tryParse(
              json['ends_at']?.toString() ?? '',
            );
            return (startsAt == null || !now.isBefore(startsAt.toUtc())) &&
                (endsAt == null || !now.isAfter(endsAt.toUtc()));
          })
          .map((json) => HomeBanner.fromJson(json))
          .toList(growable: false);
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
          .order('sort_order', ascending: true)
          .limit(200)
          .timeout(_categoryRequestTimeout);

      return response.map((item) => Map<String, dynamic>.from(item)).toList();
    } catch (e, stack) {
      debugPrint('❌ getMainCategories ERROR: $e');
      debugPrintStack(stackTrace: stack);
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getSubCategories(String parentId) async {
    try {
      final response = await _client
          .from('marketplace_categories')
          .select('id, slug, name_ar, name_en, icon, sort_order')
          .eq('parent_id', parentId)
          .eq('is_active', true)
          .order('sort_order', ascending: true)
          .limit(200)
          .timeout(_categoryRequestTimeout);

      return response.map((item) => Map<String, dynamic>.from(item)).toList();
    } catch (e) {
      debugPrint('❌ getSubCategories error: $e');
      return [];
    }
  }

  /// Returns a category plus every nested descendant, not only its first-level
  /// children. This keeps parent institution sections inclusive of all offers.
  Future<List<String>> getCategoryTreeIds(String categoryId) async {
    try {
      // All callers share one in-flight/completed read of the category
      // dimension, so several institution sections do not create one
      // database request per category.
      final childrenByParent = await _getCategoryChildren();

      final result = <String>{categoryId};
      final pending = <String>[categoryId];
      while (pending.isNotEmpty) {
        final parentId = pending.removeLast();
        for (final childId in childrenByParent[parentId] ?? const <String>[]) {
          if (result.add(childId)) pending.add(childId);
        }
      }
      return result.toList(growable: false);
    } catch (e, stack) {
      debugPrint('❌ getCategoryTreeIds error: $e');
      debugPrintStack(stackTrace: stack);
      return <String>[categoryId];
    }
  }

  Future<Map<String, List<CategoryOffer>>> getNearbyMainCategoryOffers({
    required double latitude,
    required double longitude,
    double radiusKm = 70,
    int limitPerCategory = 8,
  }) async {
    try {
      final response = await _client.rpc(
        'get_nearby_marketplace_category_offers',
        params: {
          'p_latitude': latitude,
          'p_longitude': longitude,
          'p_radius_km': radiusKm,
          'p_limit_per_category': limitPerCategory,
        },
      );
      final grouped = <String, List<CategoryOffer>>{};
      final seenOfferIdsByRoot = <String, Set<String>>{};
      for (final rawRow in (response as List)) {
        final row = Map<String, dynamic>.from(rawRow as Map);
        final rootId = row['root_category_id']?.toString() ?? '';
        final offerId = row['offer_id']?.toString() ?? '';
        if (rootId.isEmpty || offerId.isEmpty) continue;
        final latitudeValue = _toDouble(row['latitude']);
        final longitudeValue = _toDouble(row['longitude']);
        final distanceMeters = _toDouble(row['distance_meters']);
        if (latitudeValue == null ||
            longitudeValue == null ||
            distanceMeters == null ||
            distanceMeters > radiusKm * 1000) {
          continue;
        }
        final seenIds = seenOfferIdsByRoot.putIfAbsent(
          rootId,
          () => <String>{},
        );
        if (!seenIds.add(offerId)) continue;
        final imagesRaw = row['images'];
        final images = imagesRaw is List
            ? imagesRaw
                  .map((value) => value.toString().trim())
                  .where((value) => value.isNotEmpty)
                  .toList(growable: false)
            : const <String>[];
        final rawOffer = row['raw'] is Map
            ? Map<String, dynamic>.from(row['raw'] as Map)
            : <String, dynamic>{};
        final offer = CategoryOffer(
          id: offerId,
          title: row['title']?.toString() ?? 'عرض',
          description: row['description']?.toString(),
          price: _toDouble(row['price']),
          originalPrice: _toDouble(row['original_price']),
          image: images.isEmpty ? null : images.first,
          images: images,
          ownerType: row['owner_type']?.toString() ?? 'community',
          ownerName: row['owner_name']?.toString(),
          ownerLogo: row['owner_logo']?.toString(),
          latitude: latitudeValue,
          longitude: longitudeValue,
          distanceMeters: distanceMeters,
          categoryId: row['offer_category_id']?.toString(),
          categoryName: row['offer_category_name_ar']?.toString(),
          status: row['status']?.toString() ?? 'available',
          createdAt:
              DateTime.tryParse(row['created_at']?.toString() ?? '') ??
              DateTime.now(),
          raw: rawOffer,
        );
        grouped.putIfAbsent(rootId, () => <CategoryOffer>[]).add(offer);
      }
      return grouped;
    } catch (e, stack) {
      debugPrint('❌ getNearbyMainCategoryOffers error: $e');
      debugPrintStack(stackTrace: stack);
      return {};
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

      // getCategoryTreeIds shares the category-dimension request and fills this
      // cache. Avoid a second request for the same category on every tap.
      await _getCategoryChildren();
      var slug = _categorySlugById[categoryId] ?? '';
      if (slug.isEmpty) {
        try {
          final categoryInfo = await _client
              .from('marketplace_categories')
              .select('id, slug')
              .eq('id', categoryId)
              .maybeSingle()
              .timeout(_categoryRequestTimeout);
          slug = categoryInfo?['slug']?.toString().trim().toLowerCase() ?? '';
          if (slug.isNotEmpty) _categorySlugById[categoryId] = slug;
        } catch (e) {
          // The category tree is enough to continue loading offers. A slow
          // slug lookup must not turn a valid category tap into an empty page.
          debugPrint('⚠️ category slug lookup skipped: $e');
        }
      }
      final isFood = slug == 'food';
      final isGrocery = slug == 'grocery';
      const institutionCategorySlugs = {'institution-offers'};
      final isInstitutionOffers = institutionCategorySlugs.contains(slug);
      final isInstitutionCatalogCategory =
          UserHomePolicy.isAllowedCatalogSlug(slug);

      debugPrint(
        '📌 getOffersByCategory: categoryId=$categoryId '
        'slug=$slug isFood=$isFood isGrocery=$isGrocery',
      );

      // ------------------------------------------------------
      // 2) اجمع كل الـ IDs: التصنيف + الفرعيات
      // ------------------------------------------------------

      final allCategoryIds = await getCategoryTreeIds(categoryId);

      debugPrint(
        '📌 getOffersByCategory: allCategoryIds=${allCategoryIds.length}',
      );

      // ------------------------------------------------------
      // 3) اجلب العروض حسب نوع التصنيف
      // ------------------------------------------------------

      final results = <List<CategoryOffer>>[];

      // عروض المؤسسات لها مسار مستقل ولا تختلط بعروض الأفراد أو الطعام.
      if (!isInstitutionOffers) {
        results.add(await _getCommunityOffersByCategoryIds(allCategoryIds));
      }

      if (isFood) {
        // ✅ food → عروض المطاعم بس من food_offers
        results.add(await _getFoodOffersByCategoryIds(allCategoryIds));
      } else if (isGrocery || isInstitutionOffers || isInstitutionCatalogCategory) {
        // ✅ institution categories → عروض المؤسسات فقط
        results.add(await _getInstitutionOffersByCategoryIds(allCategoryIds));
      } else {
        // باقي التصنيفات → institution_offers + food_offers
        final institution = await _getInstitutionOffersByCategoryIds(
          allCategoryIds,
        );
        final food = await _getFoodOffersByCategoryIds(allCategoryIds);
        results.add([...institution, ...food]);
      }

      final allOffers = <CategoryOffer>[for (final list in results) ...list];

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
        if (latitude != null && longitude != null) {
          // A missing seller location is not evidence that the offer is nearby.
          if (offer.latitude == null || offer.longitude == null) continue;
          final distanceMeters = offer.distanceMeters;
          if (distanceMeters == null || distanceMeters > radiusKm * 1000) {
            continue;
          }
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

      return uniqueCategoryOffersById(filtered);
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
            marketplace_categories!community_offers_marketplace_category_fkey (
              id,
              name_ar
            )
          ''')
          .inFilter('marketplace_category_id', categoryIds)
          .eq('listing_type', 'symbolic_sale')
          .filter('charity_id', 'is', null)
          .eq('status', 'available')
          .gt('expires_at', DateTime.now().toUtc().toIso8601String())
          .order('created_at', ascending: false)
          .limit(200)
          .timeout(_categoryRequestTimeout);

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

          final createdAt =
              DateTime.tryParse(json['created_at']?.toString() ?? '') ??
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
            category,
            quantity,
            remaining_quantity,
            symbolic_price,
            original_price,
            images,
            pickup_location,
            expires_at,
            pickup_before,
            pickup_start,
            pickup_end,
            product_expiry_at,
            storage_condition,
            product_subcategory,
            meat_cut,
            product_weight,
            product_prepared_at,
            min_booking_quantity,
            max_booking_quantity,
            food_type,
            is_halal,
            is_vegetarian,
            food_condition,
            requires_refrigeration,
            pickup_notes,
            contact_phone,
            pickup_time,
            marketplace_category_id,
            status,
            latitude,
            longitude,
            created_at,
            institutions:institution_id (
              id,
              name,
              logo_url,
              latitude,
              longitude
            ),
            marketplace_categories!institution_offers_marketplace_category_fkey (
              id,
              name_ar
            )
          ''')
          .inFilter('marketplace_category_id', categoryIds)
          .eq('status', 'active')
          .or(
            'expires_at.is.null,expires_at.gt.${DateTime.now().toUtc().toIso8601String()}',
          )
          .filter('deleted_at', 'is', 'null')
          .gt('remaining_quantity', 0)
          .order('created_at', ascending: false)
          .limit(200)
          .timeout(_categoryRequestTimeout);

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

          final createdAt =
              DateTime.tryParse(json['created_at']?.toString() ?? '') ??
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
              // Institution coordinates are the source of truth; offer-level
              // coordinates are optional in older rows.
              latitude: _toDouble(json['latitude']) ?? _toDouble(inst['latitude']),
              longitude: _toDouble(json['longitude']) ?? _toDouble(inst['longitude']),
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
            marketplace_categories!food_offers_marketplace_category_fkey (
              id,
              name_ar
            )
          ''')
          .inFilter('marketplace_category_id', categoryIds)
          .eq('status', 'available')
          .eq('is_paused', false)
          .gt('expiry_time', DateTime.now().toUtc().toIso8601String())
          .order('created_at', ascending: false)
          .limit(200)
          .timeout(_categoryRequestTimeout);

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

          final createdAt =
              DateTime.tryParse(json['created_at']?.toString() ?? '') ??
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
