// lib/features/services/data/repositories/service_providers_repository.dart

import 'package:flutter/foundation.dart';
import 'package:loqma/core/config/app_config.dart';
import 'package:loqma/core/services/supabase_service.dart';
import 'package:loqma/features/services/domain/entities/service_provider.dart';
import 'package:loqma/features/services/domain/entities/service_review.dart';

class ServiceProvidersRepository {
  final _client = SupabaseService().client;

  // ═══════════════════════════════════════════════════════════
  // جلب مقدمي خدمة في تصنيف معين — مقفول على طنطا
  // ═══════════════════════════════════════════════════════════
  Future<List<ServiceProvider>> listByCategory({
    required String categoryId,
    String? providerType,
    String? pricingType,
    String? area, // ✅ جديد — فلتر المنطقة
    int limit = 50,
  }) async {
    try {
      var query = _client
          .from('published_service_providers')
          .select()
          .eq('category_id', categoryId)
          // ✅ قفل على المدينة
          .eq('city', AppConfig.defaultCity);

      if (providerType != null && providerType.isNotEmpty) {
        query = query.eq('provider_type', providerType);
      }
      if (pricingType != null && pricingType.isNotEmpty) {
        query = query.eq('pricing_type', pricingType);
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

      debugPrint(
          '✅ Loaded providers in ${AppConfig.defaultCity}: ${list.length}');
      return list;
    } catch (e) {
      debugPrint('❌ listByCategory error: $e');
      rethrow;
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
          .eq('category_id', categoryId)
          .eq('city', AppConfig.defaultCity);

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

  // ═══════════════════════════════════════════════════════════
  // جلب مقدم خدمة بالتفصيل
  // ═══════════════════════════════════════════════════════════
  Future<ServiceProvider?> getById(String id) async {
    try {
      final row = await _client
          .from('published_service_providers')
          .select()
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
