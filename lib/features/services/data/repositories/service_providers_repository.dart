// lib/features/services/data/repositories/service_providers_repository.dart

import 'package:flutter/foundation.dart';
import 'package:loqma/core/services/supabase_service.dart';
import 'package:loqma/features/services/domain/entities/service_provider.dart';
import 'package:loqma/features/services/domain/entities/service_review.dart';

class ServiceProvidersRepository {
  final _client = SupabaseService().client;
  static const _publicProviderColumns = '''
    id, category_id, provider_type, display_name, bio,
    experience_years, skills, profile_image_url, cover_image_url,
    portfolio_images, governorate, city, address, service_areas, available_days, latitude, longitude,
    max_distance_km, pricing_type, price_from, price_currency,
    accepts_installments, phone, whatsapp, email, website,
    founded_year, employees_count, branches,
    verification_status, is_active, is_available, availability_note,
    total_jobs, completed_jobs, cancelled_jobs, volunteer_jobs,
    rating_avg, total_reviews, response_time_minutes, created_at, updated_at,
    category_name, category_icon, category_slug, owner_name, owner_avatar
  ''';

  // ═══════════════════════════════════════════════════════════
  // جلب مقدمي الخدمة المنشورين في التصنيف
  // ═══════════════════════════════════════════════════════════
  Future<List<ServiceProvider>> listByCategory({
    required String categoryId,
    String? providerType,
    String? pricingType,
    String? area, // ✅ جديد — فلتر المنطقة
    String? governorate,
    String? city,
    int limit = 50,
  }) async {
    try {
      var query = _client
          .from('published_service_providers')
          .select(_publicProviderColumns)
          .eq('category_id', categoryId);

      if (providerType != null && providerType.isNotEmpty) {
        query = query.eq('provider_type', providerType);
      }
      if (pricingType != null && pricingType.isNotEmpty) {
        query = query.eq('pricing_type', pricingType);
      }

      if (governorate != null && governorate.isNotEmpty) {
        query = query.eq('governorate', governorate);
      }
      if (city != null && city.isNotEmpty) {
        query = query.eq('city', city);
      }

      // ✅ فلتر المنطقة — يتحقق إن المزود بيخدم المنطقة دي
      if (area != null && area.isNotEmpty) {
        query = query.contains('service_areas', [area]);
      }

      final rows = await query
          .order('rating_avg', ascending: false)
          .order('total_reviews', ascending: false)
          .limit(limit);

      final list = (rows as List)
          .map((r) => ServiceProvider.fromMap(Map<String, dynamic>.from(r)))
          .toList();

      debugPrint('✅ Loaded providers in category $categoryId: ${list.length}');
      return list;
    } catch (e) {
      debugPrint('❌ listByCategory error: $e');
      rethrow;
    }
  }

  /// مزودون حقيقيون معتمدون، متاحون، بسعر رمزي وفي مدينة المستخدم.
  /// المسافة الدقيقة تُحسب في طبقة العرض باستخدام إحداثيات المستخدم.
  Future<List<ServiceProvider>> listNearbySymbolic({
    required String city,
    int limit = 60,
  }) async {
    try {
      final cleanCity = city.trim();
      if (cleanCity.isEmpty) return const <ServiceProvider>[];

      final rows = await _client
          .from('published_service_providers')
          .select(_publicProviderColumns)
          .eq('city', cleanCity)
          .eq('pricing_type', 'symbolic')
          .not('latitude', 'is', null)
          .not('longitude', 'is', null)
          .order('rating_avg', ascending: false)
          .order('total_reviews', ascending: false)
          .limit(limit);

      return (rows as List)
          .map((row) => ServiceProvider.fromMap(Map<String, dynamic>.from(row)))
          .where((provider) => provider.isVerified && provider.isAvailable)
          .toList(growable: false);
    } catch (e) {
      debugPrint('❌ listNearbySymbolic error: $e');
      return const <ServiceProvider>[];
    }
  }

  // ═══════════════════════════════════════════════════════════
  // ✅ جلب المناطق المتاحة في تصنيف معين
  // ═══════════════════════════════════════════════════════════
  Future<List<String>> getAvailableAreas({
    required String categoryId,
  }) async {
    try {
      final rows = await _client
          .from('published_service_providers')
          .select('service_areas')
          .eq('category_id', categoryId);

      final Set<String> areas = {};
      for (final row in rows) {
        final raw = row['service_areas'];
        if (raw is List) {
          for (final a in raw) {
            final t = a?.toString().trim() ?? '';
            if (t.isNotEmpty) areas.add(t);
          }
        }
      }

      final list = areas.toList()..sort();
      debugPrint('✅ Available areas: ${list.length} → $list');
      return list;
    } catch (e) {
      debugPrint('❌ getAvailableAreas error: $e');
      return [];
    }
  }

  Future<List<String>> getAvailableGovernorates({
    required String categoryId,
  }) async {
    try {
      final rows = await _client
          .from('published_service_providers')
          .select('governorate')
          .eq('category_id', categoryId)
          .not('governorate', 'is', null);
      final values = rows
          .map((row) => row['governorate']?.toString().trim() ?? '')
          .where((value) => value.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
      return values;
    } catch (e) {
      debugPrint('❌ getAvailableGovernorates error: $e');
      return [];
    }
  }

  Future<List<String>> getAvailableCities({
    required String categoryId,
    required String governorate,
  }) async {
    try {
      final rows = await _client
          .from('published_service_providers')
          .select('city')
          .eq('category_id', categoryId)
          .eq('governorate', governorate)
          .not('city', 'is', null);
      final values = rows
          .map((row) => row['city']?.toString().trim() ?? '')
          .where((value) => value.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
      return values;
    } catch (e) {
      debugPrint('❌ getAvailableCities error: $e');
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════════
  // جلب مقدم خدمة بالتفصيل
  // ═══════════════════════════════════════════════════════════
  Future<ServiceProvider?> getById(String id) async {
    try {
      final row = await _client
          .from('published_service_providers')
          .select(_publicProviderColumns)
          .eq('id', id)
          .maybeSingle();

      if (row == null) return null;
      return ServiceProvider.fromMap(Map<String, dynamic>.from(row));
    } catch (e) {
      debugPrint('❌ getById error: $e');
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════
  // جلب تقييمات مقدم الخدمة
  // ═══════════════════════════════════════════════════════════
  Future<List<ServiceReview>> listReviews({
    required String providerId,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final rows = await _client
          .from('published_service_reviews')
          .select()
          .eq('to_provider_id', providerId)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      final list = (rows as List)
          .map((r) => ServiceReview.fromMap(Map<String, dynamic>.from(r)))
          .toList();

      debugPrint('✅ Loaded reviews: ${list.length}');
      return list;
    } catch (e) {
      debugPrint('❌ listReviews error: $e');
      rethrow;
    }
  }

  // ═══════════════════════════════════════════════════════════
  // ⭐ هل المستخدم قيّم المقدم ده قبل كده؟
  // ═══════════════════════════════════════════════════════════
  Future<ServiceReview?> getUserReviewForProvider({
    required String providerId,
    required String userId,
  }) async {
    try {
      final row = await _client
          .from('service_reviews')
          .select()
          .eq('to_provider_id', providerId)
          .eq('from_user_id', userId)
          .maybeSingle();

      if (row == null) return null;
      return ServiceReview.fromMap(Map<String, dynamic>.from(row));
    } catch (e) {
      debugPrint('❌ getUserReview error: $e');
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════
  // ⭐ إضافة تقييم جديد
  // ═══════════════════════════════════════════════════════════
  Future<ServiceReview?> submitReview({
    required String providerId,
    required String userId,
    required int rating,
    String? comment,
    List<String> tags = const [],
    bool isAnonymous = false,
  }) async {
    try {
      // ✅ تأكد إنه مقيّمش قبل كده
      final existing = await getUserReviewForProvider(
        providerId: providerId,
        userId: userId,
      );
      if (existing != null) {
        throw Exception('أنت قيّمت المقدم ده بالفعل');
      }

      // ✅ تجهيز التعليق
      final trimmedComment = comment?.trim();
      final finalComment = (trimmedComment == null || trimmedComment.isEmpty)
          ? null
          : trimmedComment;

      // ✅ تجهيز التاجات
      final finalTags = tags.isEmpty ? null : tags;

      // ✅ أضف التقييم
      final row = await _client
          .from('service_reviews')
          .insert({
            'to_provider_id': providerId,
            'from_user_id': userId,
            'rating': rating,
            'comment': finalComment,
            'tags': finalTags,
            'is_anonymous': isAnonymous,
            'request_id': null,
          })
          .select()
          .single();

      debugPrint('✅ Review submitted: $rating ⭐');
      return ServiceReview.fromMap(Map<String, dynamic>.from(row));
    } catch (e) {
      debugPrint('❌ submitReview error: $e');
      rethrow;
    }
  }
}
