// lib/features/institutions/data/repositories/institution_offers_repository.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:loqma/core/services/supabase_service.dart';

import '../../domain/entities/institution_offer.dart';
import '../../domain/entities/institution_offer_request.dart';

class InstitutionOffersRepository {
  final SupabaseClient _client;

  InstitutionOffersRepository({SupabaseClient? client})
      : _client = client ?? SupabaseService().client;

  Future<List<InstitutionOffer>> listAvailableOffers() async {
    final rows = await _client
        .from('institution_offers_core')
        .select('''
          *,
          institutions(id, name, institution_type, logo_url),
          institution_offer_pricing(symbolic_price, original_price, currency),
          institution_offer_inventory(quantity, remaining_quantity, reserved_quantity, unit_label),
          institution_offer_media(public_url, sort_order, is_primary),
          institution_offer_pickup(city, address, location_text, pickup_before, latitude, longitude)
        ''')
        .eq('status', 'active')
        .gt('expires_at', DateTime.now().toUtc().toIso8601String())
        .order('created_at', ascending: false);

    return rows
        .whereType<Map>()
        .map((row) => InstitutionOffer.fromJson(_normalizeCoreRow(row)))
        .where((offer) => offer.isActive && offer.remainingQuantity > 0)
        .toList(growable: false);
  }

  Future<bool> isOwnerOfOffer(String institutionId) async {
    final userId = _client.auth.currentUser?.id;
    final cleanInstitutionId = institutionId.trim();
    if (userId == null || userId.isEmpty || cleanInstitutionId.isEmpty) {
      return false;
    }

    final row = await _client
        .from('institutions')
        .select('id')
        .eq('id', cleanInstitutionId)
        .eq('user_id', userId)
        .maybeSingle();
    return row != null;
  }

  Future<InstitutionOffer?> getOffer(String offerId) async {
    final row = await _client.from('institution_offers_core').select('''
          *,
          institutions(id, name, institution_type, logo_url),
          institution_offer_pricing(symbolic_price, original_price, currency),
          institution_offer_inventory(quantity, remaining_quantity, reserved_quantity, unit_label),
          institution_offer_media(public_url, sort_order, is_primary),
          institution_offer_pickup(city, address, location_text, pickup_before, latitude, longitude)
        ''').eq('id', offerId).maybeSingle();

    return row == null
        ? null
        : InstitutionOffer.fromJson(_normalizeCoreRow(row));
  }

  Map<String, dynamic> _normalizeCoreRow(Map row) {
    final normalized = Map<String, dynamic>.from(row);
    final pricing = _asMap(normalized['institution_offer_pricing']);
    final inventory = _asMap(normalized['institution_offer_inventory']);
    final pickup = _asMap(normalized['institution_offer_pickup']);

    final media = normalized['institution_offer_media'] is List
        ? List<Map<String, dynamic>>.from(
            (normalized['institution_offer_media'] as List)
                .whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item)),
          )
        : <Map<String, dynamic>>[];
    media.sort((a, b) =>
        (a['sort_order'] as num? ?? 0).compareTo(b['sort_order'] as num? ?? 0));

    normalized['symbolic_price'] = pricing['symbolic_price'];
    normalized['original_price'] = pricing['original_price'];
    normalized['quantity'] = inventory['quantity'];
    normalized['remaining_quantity'] = inventory['remaining_quantity'];
    normalized['images'] = media
        .map((item) => item['public_url']?.toString().trim() ?? '')
        .where((url) => url.isNotEmpty)
        .toList(growable: false);
    normalized['pickup_location'] =
        pickup['location_text'] ?? pickup['address'] ?? pickup['city'];
    normalized['pickup_before'] = pickup['pickup_before'];

    // ✅ حقول إضافية
    normalized['food_type'] = row['food_type'] ?? 'وجبات';
    normalized['is_halal'] = row['is_halal'] ?? true;
    normalized['is_vegetarian'] = row['is_vegetarian'] ?? false;
    normalized['food_condition'] = row['food_condition'] ?? 'good';
    normalized['requires_refrigeration'] =
        row['requires_refrigeration'] ?? false;
    normalized['pickup_notes'] = row['pickup_notes'] ?? '';
    normalized['contact_phone'] = row['contact_phone'] ?? '';

    return normalized;
  }

  Map<String, dynamic> _normalizeRequestRow(Map<String, dynamic> row) {
    final normalized = Map<String, dynamic>.from(row);
    final core = _asMap(normalized['institution_offers_core']);
    if (core.isNotEmpty) {
      normalized['institution_offers_core'] = _normalizeCoreRow(core);
    }
    return normalized;
  }

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    if (value is List && value.isNotEmpty && value.first is Map) {
      return Map<String, dynamic>.from(value.first as Map);
    }
    return <String, dynamic>{};
  }

  Future<InstitutionOfferRequest> requestOffer({
    required String offerId,
    int quantity = 1,
  }) async {
    if (offerId.trim().isEmpty) {
      throw const FormatException('العرض غير محدد');
    }
    if (quantity <= 0) {
      throw const FormatException('الكمية المطلوبة غير صحيحة');
    }

    final result = await _client.rpc(
      'institution_request_offer',
      params: {
        'p_offer_id': offerId.trim(),
        'p_quantity': quantity,
      },
    );

    if (result is! Map || result['request_id'] == null) {
      throw const FormatException('تعذر إنشاء طلب العرض');
    }

    final requestId = result['request_id'].toString();
    final row = await _client.from('institution_offer_requests').select('''
          *,
          institution_offers_core(
            *,
            institutions(id, name, institution_type, logo_url),
            institution_offer_pricing(symbolic_price, original_price, currency),
            institution_offer_inventory(quantity, remaining_quantity, reserved_quantity, unit_label),
            institution_offer_media(public_url, sort_order, is_primary),
            institution_offer_pickup(city, address, location_text, pickup_before, latitude, longitude)
          )
        ''').eq('id', requestId).single();

    return InstitutionOfferRequest.fromJson(
      _normalizeRequestRow(Map<String, dynamic>.from(row)),
    );
  }

  Future<InstitutionOfferRequest?> getMyRequestForOffer(String offerId) async {
    final userId = _client.auth.currentUser?.id;
    final cleanOfferId = offerId.trim();
    if (userId == null || userId.isEmpty || cleanOfferId.isEmpty) return null;

    final row = await _client
        .from('institution_offer_requests')
        .select('''
          *,
          institution_offers_core(
            *,
            institutions(id, name, institution_type, logo_url),
            institution_offer_pricing(*),
            institution_offer_inventory(*),
            institution_offer_pickup(*),
            institution_offer_media(*)
          )
        ''')
        .eq('offer_id', cleanOfferId)
        .eq('requester_id', userId)
        .not('status', 'in', '(rejected,cancelled,expired)')
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    return row == null
        ? null
        : InstitutionOfferRequest.fromJson(
            _normalizeRequestRow(Map<String, dynamic>.from(row)),
          );
  }

  Future<Map<String, dynamic>> generatePickupCode(String requestId) async {
    final cleanId = requestId.trim();
    if (cleanId.isEmpty) throw const FormatException('معرف الطلب غير موجود');
    final result = await _client.rpc(
      'institution_generate_offer_request_pickup_code',
      params: {'p_request_id': cleanId},
    );
    if (result is! Map ||
        result['success'] != true ||
        result['pickup_code'] == null) {
      throw const FormatException('تعذر إنشاء كود الاستلام');
    }
    return Map<String, dynamic>.from(result);
  }

  Future<void> completeRequest(String requestId) async {
    final cleanId = requestId.trim();
    if (cleanId.isEmpty) {
      throw const FormatException('معرف الطلب غير موجود');
    }
    final result = await _client.rpc(
      'institution_complete_offer_request',
      params: {'p_request_id': cleanId},
    );
    if (result is! Map || result['success'] != true) {
      throw const FormatException('تعذر تأكيد إكمال الطلب');
    }
  }

  Future<List<InstitutionOfferRequest>> listMyRequests() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      throw const FormatException('يجب تسجيل الدخول أولًا');
    }

    final rows = await _client.from('institution_offer_requests').select('''
          *,
          institution_offers_core(
            *,
            institutions(id, name, institution_type, logo_url),
            institution_offer_pricing(symbolic_price, original_price, currency),
            institution_offer_inventory(quantity, remaining_quantity, reserved_quantity, unit_label),
            institution_offer_media(public_url, sort_order, is_primary),
            institution_offer_pickup(city, address, location_text, pickup_before, latitude, longitude)
          )
        ''').eq('requester_id', userId).order('created_at', ascending: false);

    final parsed = rows
        .whereType<Map>()
        .map((row) => InstitutionOfferRequest.fromJson(
              _normalizeRequestRow(Map<String, dynamic>.from(row)),
            ))
        .toList(growable: false);

    debugPrint('[InstitutionOffers] listMyRequests rows=${parsed.length}');
    for (final request in parsed) {
      final offer = request.offer;
      debugPrint(
        '[InstitutionOffers] request=${request.id} offer=${request.offerId} '
        'offerKeys=${offer?.keys.toList()} images=${offer?['images']}',
      );
    }
    return parsed;
  }

  // ============================================================
  // ✅ دالة جلب عروض المؤسسة مع الحقول الإضافية (تم إصلاحها)
  // ============================================================
  Future<List<Map<String, dynamic>>> getInstitutionOffers({
    required String institutionId,
    String? status,
    int limit = 50,
  }) async {
    try {
      // ✅ بناء الاستعلام بالترتيب الصحيح
      var query = _client.from('institution_offers').select('''
            *,
            institutions:institution_id (
              id,
              name,
              institution_type,
              logo_url,
              address,
              phone
            )
          ''').eq('institution_id', institutionId);

      // ✅ إضافة فلتر الحالة إذا وجد
      if (status != null && status.isNotEmpty) {
        query = query.eq('status', status);
      }

      // ✅ ترتيب وتحديد العدد
      final response =
          await query.order('created_at', ascending: false).limit(limit);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('❌ Error getting institution offers: $e');
      throw Exception('فشل جلب عروض المؤسسة: $e');
    }
  }

  // ============================================================
  // ✅ دالة جلب عرض معين مع الحقول الإضافية
  // ============================================================
  Future<Map<String, dynamic>?> getOfferDetails(String offerId) async {
    try {
      final response = await _client.from('institution_offers').select('''
            *,
            institutions:institution_id (
              id,
              name,
              institution_type,
              logo_url,
              address,
              phone
            )
          ''').eq('id', offerId).maybeSingle();

      return response;
    } catch (e) {
      debugPrint('❌ Error getting offer details: $e');
      throw Exception('فشل جلب تفاصيل العرض: $e');
    }
  }

  // ============================================================
  // ✅ دالة تحديث حالة العرض
  // ============================================================
  Future<void> updateOfferStatus({
    required String offerId,
    required String status,
  }) async {
    try {
      await _client.from('institution_offers').update({
        'status': status,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', offerId);
    } catch (e) {
      debugPrint('❌ Error updating offer status: $e');
      throw Exception('فشل تحديث حالة العرض: $e');
    }
  }

  // ============================================================
  // ✅ دالة حذف العرض (ناعم)
  // ============================================================
  Future<void> deleteOffer(String offerId) async {
    try {
      await _client.from('institution_offers').update({
        'status': 'cancelled',
        'deleted_at': DateTime.now().toUtc().toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', offerId);
    } catch (e) {
      debugPrint('❌ Error deleting offer: $e');
      throw Exception('فشل حذف العرض: $e');
    }
  }

  // ============================================================
  // ✅ دالة البحث في العروض
  // ============================================================
  Future<List<Map<String, dynamic>>> searchOffers({
    String? query,
    String? category,
    String? city,
    double? minPrice,
    double? maxPrice,
    int limit = 20,
  }) async {
    try {
      var searchQuery = _client
          .from('institution_offers')
          .select('''
            *,
            institutions:institution_id (
              id,
              name,
              institution_type,
              logo_url,
              address,
              phone
            )
          ''')
          .eq('status', 'active')
          .gt('expires_at', DateTime.now().toUtc().toIso8601String());

      if (query != null && query.isNotEmpty) {
        searchQuery = searchQuery.ilike('title', '%$query%');
      }

      if (category != null && category.isNotEmpty) {
        searchQuery = searchQuery.eq('category', category);
      }

      if (city != null && city.isNotEmpty) {
        searchQuery = searchQuery.ilike('pickup_location', '%$city%');
      }

      if (minPrice != null) {
        searchQuery = searchQuery.gte('symbolic_price', minPrice);
      }

      if (maxPrice != null) {
        searchQuery = searchQuery.lte('symbolic_price', maxPrice);
      }

      final response =
          await searchQuery.order('created_at', ascending: false).limit(limit);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('❌ Error searching offers: $e');
      throw Exception('فشل البحث عن العروض: $e');
    }
  }
}
