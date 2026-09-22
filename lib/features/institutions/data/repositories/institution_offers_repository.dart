// lib/features/institutions/data/repositories/institution_offers_repository.dart

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:loqma/core/services/supabase_service.dart';

import '../../domain/entities/institution_offer.dart';
import '../../domain/entities/institution_offer_request.dart';

class InstitutionOffersRepository {
  final SupabaseClient _client;

  InstitutionOffersRepository({SupabaseClient? client})
      : _client = client ?? SupabaseService().client;

  // ═══════════════════════════════════════════════════════════
  // ✅ الحد الأقصى اليومي لطلبات البقالة
  // ═══════════════════════════════════════════════════════════

  static const int dailyInstitutionRequestLimit = 5;

  // ============================================================
  // جلب العروض المتاحة (SELECT فقط ✅)
  // ============================================================

  Future<List<InstitutionOffer>> listAvailableOffers() async {
    try {
      final now = DateTime.now().toUtc().toIso8601String();

      final rows = await _client
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
          .gt('expires_at', now)
          .filter('deleted_at', 'is', 'null')
          .order('created_at', ascending: false);

      return rows
          .whereType<Map>()
          .map(
            (row) => InstitutionOffer.fromJson(
              Map<String, dynamic>.from(row),
            ),
          )
          .where(
            (offer) => offer.isActive && offer.remainingQuantity > 0,
          )
          .toList(growable: false);
    } catch (e) {
      debugPrint('❌ listAvailableOffers error: $e');
      return [];
    }
  }

  // ============================================================
  // التحقق من ملكية المؤسسة (SELECT فقط ✅)
  // ============================================================

  Future<bool> isOwnerOfOffer(String institutionId) async {
    try {
      final userId = _client.auth.currentUser?.id;

      if (userId == null || userId.isEmpty || institutionId.trim().isEmpty) {
        return false;
      }

      final row = await _client
          .from('institutions')
          .select('id')
          .eq('id', institutionId.trim())
          .eq('user_id', userId)
          .maybeSingle();

      return row != null;
    } catch (e) {
      debugPrint('❌ isOwnerOfOffer error: $e');
      return false;
    }
  }

  // ============================================================
  // جلب عرض معين (SELECT فقط ✅)
  // ============================================================

  Future<InstitutionOffer?> getOffer(String offerId) async {
    try {
      final cleanOfferId = offerId.trim();

      if (cleanOfferId.isEmpty) {
        return null;
      }

      final row = await _client.from('institution_offers').select('''
            *,
            institutions:institution_id (
              id,
              name,
              institution_type,
              logo_url,
              address,
              phone
            )
          ''').eq('id', cleanOfferId).maybeSingle();

      if (row == null) {
        return null;
      }

      return InstitutionOffer.fromJson(
        Map<String, dynamic>.from(row),
      );
    } catch (e) {
      debugPrint('❌ getOffer error: $e');
      return null;
    }
  }

  // ============================================================
  // ✅ عدد طلبات البقالة النهارده للمستخدم
  // ============================================================

  /// بيرجّع عدد الطلبات النشطة اللي المستخدم عملها النهارده
  /// (باستثناء الملغية/المرفوضة/المنتهية)
  Future<int> getTodayRequestsCount() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null || userId.isEmpty) return 0;

      // بداية اليوم بتوقيت UTC
      final now = DateTime.now().toUtc();
      final startOfDay = DateTime.utc(now.year, now.month, now.day);

      final response = await _client
          .from('institution_offer_requests')
          .select('id')
          .eq('requester_id', userId)
          .gte('created_at', startOfDay.toIso8601String())
          .not('status', 'in', '(cancelled,rejected,expired)');

      return (response as List).length;
    } catch (e) {
      debugPrint('❌ getTodayRequestsCount error: $e');
      return 0;
    }
  }

  /// بيرجّع عدد الطلبات المتبقية للمستخدم النهارده
  Future<int> getRemainingTodayRequests() async {
    final used = await getTodayRequestsCount();
    return (dailyInstitutionRequestLimit - used)
        .clamp(0, dailyInstitutionRequestLimit);
  }

  // ============================================================
  // طلب عرض - RPC آمن 🔐
  // ============================================================

  Future<InstitutionOfferRequest> requestOffer({
    required String offerId,
    int quantity = 1,
  }) {
    return requestOfferSafe(
      offerId: offerId,
      quantity: quantity,
    );
  }

  // ============================================================
  // طلب عرض آمن - Atomic RPC 🔐 (مع حماية الحد اليومي)
  // ============================================================

  Future<InstitutionOfferRequest> requestOfferSafe({
    required String offerId,
    int quantity = 1,
  }) async {
    try {
      final userId = _client.auth.currentUser?.id;

      if (userId == null || userId.isEmpty) {
        throw Exception('يجب تسجيل الدخول أولاً');
      }

      final cleanOfferId = offerId.trim();

      if (cleanOfferId.isEmpty) {
        throw Exception('العرض غير محدد');
      }

      if (quantity <= 0) {
        throw Exception('الكمية المطلوبة غير صحيحة');
      }

      // ═══════════════════════════════════════════════════════════
      // ✅ حماية مبكرة: التحقق من الحد اليومي قبل إرسال الطلب
      // ═══════════════════════════════════════════════════════════
      final todayCount = await getTodayRequestsCount();
      if (todayCount >= dailyInstitutionRequestLimit) {
        throw Exception(
          'وصلت للحد الأقصى من الطلبات اليومية '
          '($dailyInstitutionRequestLimit). حاول تاني بكرة.',
        );
      }

      final result = await _client.rpc(
        'reserve_institution_offer_safe',
        params: {
          'p_offer_id': cleanOfferId,
          'p_requester_id': userId,
          'p_quantity': quantity,
        },
      );

      if (result is! Map || result['success'] != true) {
        throw Exception('تعذر إنشاء طلب العرض');
      }

      final requestId = result['request_id']?.toString();

      if (requestId == null || requestId.isEmpty) {
        throw Exception('تعذر الحصول على تفاصيل الطلب');
      }

      final row = await _client.from('institution_offer_requests').select('''
            *,
            institution_offers:offer_id (
              *,
              institutions:institution_id (
                id,
                name,
                institution_type,
                logo_url,
                address,
                phone
              )
            )
          ''').eq('id', requestId).single();

      return InstitutionOfferRequest.fromJson(
        Map<String, dynamic>.from(row),
      );
    } on PostgrestException catch (e) {
      debugPrint(
        '❌ requestOfferSafe Postgrest '
        'code=${e.code} message=${e.message}',
      );

      // ═══════════════════════════════════════════════════════════
      // ✅ معالجة خطأ الحد اليومي القادم من الـ DB Trigger
      // ═══════════════════════════════════════════════════════════
      if (e.code == 'P0310' ||
          e.message.contains('DAILY_LIMIT_REACHED') ||
          e.message.contains('daily limit')) {
        throw Exception(
          'وصلت للحد الأقصى من الطلبات اليومية '
          '($dailyInstitutionRequestLimit). حاول تاني بكرة.',
        );
      }

      if (e.message.contains('not enough quantity') ||
          e.message.contains('الكمية غير كافية')) {
        throw Exception('الكمية المطلوبة غير متاحة');
      }
      if (e.message.contains('offer not found') || e.code == 'P0301') {
        throw Exception('العرض غير موجود');
      }
      if (e.message.contains('expired') || e.code == 'P0303') {
        throw Exception('العرض منتهي الصلاحية');
      }
      if (e.message.contains('not active')) {
        throw Exception('العرض غير متاح حاليًا');
      }

      rethrow;
    } catch (e) {
      debugPrint('❌ requestOfferSafe error: $e');
      rethrow;
    }
  }

  // ============================================================
  // جلب طلب المستخدم لعرض معين (SELECT فقط ✅)
  // ============================================================

  Future<InstitutionOfferRequest?> getMyRequestForOffer(
    String offerId,
  ) async {
    try {
      final userId = _client.auth.currentUser?.id;
      final cleanOfferId = offerId.trim();

      if (userId == null || userId.isEmpty || cleanOfferId.isEmpty) {
        return null;
      }

      final row = await _client
          .from('institution_offer_requests')
          .select('''
            *,
            institution_offers:offer_id (
              *,
              institutions:institution_id (
                id,
                name,
                institution_type,
                logo_url,
                address,
                phone
              )
            )
          ''')
          .eq('offer_id', cleanOfferId)
          .eq('requester_id', userId)
          .not(
            'status',
            'in',
            '(rejected,cancelled,expired)',
          )
          .order(
            'created_at',
            ascending: false,
          )
          .limit(1)
          .maybeSingle();

      if (row == null) {
        return null;
      }

      return InstitutionOfferRequest.fromJson(
        Map<String, dynamic>.from(row),
      );
    } on PostgrestException catch (e) {
      debugPrint(
        '❌ getMyRequestForOffer Postgrest '
        'code=${e.code} message=${e.message}',
      );
      rethrow;
    } catch (e) {
      debugPrint(
        '❌ getMyRequestForOffer error: $e',
      );
      rethrow;
    }
  }

  // ============================================================
  // ⭐ قبول / رفض طلب - RPC آمن 🔐 (للبقالة)
  // ============================================================

  Future<void> updateOfferRequest({
    required String requestId,
    required bool accept,
  }) async {
    try {
      final cleanRequestId = requestId.trim();

      if (cleanRequestId.isEmpty) {
        throw Exception('معرف الطلب غير موجود');
      }

      debugPrint(
        '➡️ institution_update_offer_request '
        'requestId=$cleanRequestId '
        'accept=$accept',
      );

      final result = await _client.rpc(
        'institution_update_offer_request',
        params: {
          'p_request_id': cleanRequestId,
          'p_accept': accept,
        },
      );

      debugPrint(
        '📥 institution_update_offer_request '
        'response=$result',
      );

      if (result is! Map) {
        throw Exception(
          'استجابة غير صالحة من الخادم',
        );
      }

      final response = Map<String, dynamic>.from(result);

      final success = response['success'] == true;

      final expectedStatus = accept ? 'accepted' : 'rejected';

      final returnedStatus = response['status']?.toString();

      if (!success) {
        throw Exception(
          response['message']?.toString() ?? 'تعذر تحديث حالة الطلب',
        );
      }

      if (returnedStatus != expectedStatus) {
        throw Exception(
          'تم تنفيذ العملية لكن حالة الطلب غير صحيحة: '
          '$returnedStatus',
        );
      }

      debugPrint(
        '✅ updateOfferRequest success '
        'requestId=$cleanRequestId '
        'status=$returnedStatus',
      );
    } on PostgrestException catch (e) {
      debugPrint(
        '❌ updateOfferRequest Postgrest '
        'code=${e.code} '
        'message=${e.message} '
        'details=${e.details}',
      );

      rethrow;
    } catch (e) {
      debugPrint(
        '❌ updateOfferRequest error: $e',
      );

      rethrow;
    }
  }

  // ============================================================
  // ⭐ تجهيز الطلب للاستلام - RPC آمن 🔐 (للبقالة)
  // ============================================================

  Future<void> markOfferRequestReady(
    String requestId,
  ) async {
    try {
      final cleanRequestId = requestId.trim();

      if (cleanRequestId.isEmpty) {
        throw Exception('معرف الطلب غير موجود');
      }

      final result = await _client.rpc(
        'institution_mark_offer_request_ready',
        params: {
          'p_request_id': cleanRequestId,
        },
      );

      debugPrint(
        '📥 institution_mark_offer_request_ready '
        'response=$result',
      );

      if (result is! Map) {
        throw Exception(
          'استجابة غير صالحة من الخادم',
        );
      }

      final response = Map<String, dynamic>.from(result);

      final success = response['success'] == true;

      final status = response['status']?.toString();

      if (!success) {
        throw Exception(
          response['message']?.toString() ?? 'تعذر تجهيز الطلب للاستلام',
        );
      }

      if (status != 'ready_for_pickup') {
        throw Exception(
          'لم يتم تحديث الطلب إلى جاهز للاستلام',
        );
      }

      debugPrint(
        '✅ markOfferRequestReady success '
        'requestId=$cleanRequestId '
        'status=$status',
      );
    } on PostgrestException catch (e) {
      debugPrint(
        '❌ markOfferRequestReady Postgrest '
        'code=${e.code} '
        'message=${e.message} '
        'details=${e.details}',
      );

      rethrow;
    } catch (e) {
      debugPrint(
        '❌ markOfferRequestReady error: $e',
      );

      rethrow;
    }
  }

  // ============================================================
  // ⭐ جلب كود الاستلام - RPC آمن 🔐 (للبقالة - deprecated)
  // ============================================================

  @Deprecated('استخدم generatePickupCodeForUser للمستخدم')
  Future<Map<String, dynamic>> generatePickupCode(
    String requestId,
  ) async {
    try {
      final cleanRequestId = requestId.trim();

      if (cleanRequestId.isEmpty) {
        throw Exception('معرف الطلب غير موجود');
      }

      final response = await _client.rpc(
        'institution_generate_offer_request_pickup_code',
        params: {
          'p_request_id': cleanRequestId,
        },
      );

      debugPrint(
        '📥 generatePickupCode response=$response',
      );

      if (response is! Map) {
        throw Exception(
          'استجابة غير صالحة من الخادم',
        );
      }

      final result = Map<String, dynamic>.from(response);

      if (result['success'] != true) {
        throw Exception(
          result['message']?.toString() ?? 'تعذر إنشاء كود الاستلام',
        );
      }

      final code = result['pickup_code']?.toString() ?? '';

      if (code.isEmpty) {
        throw Exception(
          'تم إنشاء الطلب لكن لم يتم إرجاع كود الاستلام',
        );
      }

      debugPrint(
        '✅ pickup code generated '
        'requestId=$cleanRequestId',
      );

      return result;
    } on PostgrestException catch (e) {
      debugPrint(
        '❌ generatePickupCode Postgrest '
        'code=${e.code} '
        'message=${e.message} '
        'details=${e.details}',
      );

      rethrow;
    } catch (e) {
      debugPrint(
        '❌ generatePickupCode error: $e',
      );

      rethrow;
    }
  }

  // ============================================================
  // ⭐ توليد كود الاستلام للمستخدم - RPC آمن 🔐 (جديد)
  // ============================================================

  Future<Map<String, dynamic>> generatePickupCodeForUser(
    String requestId,
  ) async {
    try {
      final cleanRequestId = requestId.trim();

      if (cleanRequestId.isEmpty) {
        throw Exception('معرف الطلب غير موجود');
      }

      final response = await _client.rpc(
        'user_generate_pickup_code',
        params: {
          'p_request_id': cleanRequestId,
        },
      );

      debugPrint(
        '📥 generatePickupCodeForUser response=$response',
      );

      if (response is! Map) {
        throw Exception(
          'استجابة غير صالحة من الخادم',
        );
      }

      final result = Map<String, dynamic>.from(response);

      if (result['success'] != true) {
        throw Exception(
          result['message']?.toString() ?? 'تعذر إنشاء كود الاستلام',
        );
      }

      final code = result['pickup_code']?.toString() ?? '';

      if (code.isEmpty) {
        throw Exception(
          'تم إنشاء الطلب لكن لم يتم إرجاع كود الاستلام',
        );
      }

      debugPrint(
        '✅ pickup code generated for user '
        'requestId=$cleanRequestId',
      );

      return result;
    } on PostgrestException catch (e) {
      debugPrint(
        '❌ generatePickupCodeForUser Postgrest '
        'code=${e.code} '
        'message=${e.message} '
        'details=${e.details}',
      );

      rethrow;
    } catch (e) {
      debugPrint(
        '❌ generatePickupCodeForUser error: $e',
      );

      rethrow;
    }
  }

  // ============================================================
  // ⭐ التحقق من كود الاستلام - RPC آمن 🔐 (للبقالة)
  // ============================================================

  Future<Map<String, dynamic>> verifyOfferRequestPickupCode({
    required String requestId,
    required String code,
  }) async {
    final cleanRequestId = requestId.trim();

    if (cleanRequestId.isEmpty) {
      throw const FormatException(
        'معرف الطلب غير موجود',
      );
    }

    // تنظيف الكود
    var cleanCode = code
        .trim()
        .replaceAll('٠', '0')
        .replaceAll('١', '1')
        .replaceAll('٢', '2')
        .replaceAll('٣', '3')
        .replaceAll('٤', '4')
        .replaceAll('٥', '5')
        .replaceAll('٦', '6')
        .replaceAll('٧', '7')
        .replaceAll('٨', '8')
        .replaceAll('٩', '9')
        .replaceAll(RegExp(r'[^0-9]'), '');

    if (cleanCode.length != 6) {
      throw const FormatException(
        'كود الاستلام يجب أن يتكون من 6 أرقام',
      );
    }

    try {
      debugPrint(
        '🔐 VERIFY PICKUP START '
        'requestId=$cleanRequestId '
        'codeLength=${cleanCode.length}',
      );

      final result = await _client.rpc(
        'institution_verify_offer_request_pickup_code',
        params: {
          'p_request_id': cleanRequestId,
          'p_code': cleanCode,
        },
      );

      debugPrint(
        '🔐 VERIFY PICKUP RESPONSE=$result',
      );

      if (result is! Map) {
        throw const FormatException(
          'استجابة غير صالحة من الخادم',
        );
      }

      final response = Map<String, dynamic>.from(result);

      final success = response['success'] == true;

      final status = response['status']?.toString();

      debugPrint(
        '🔐 VERIFY PICKUP '
        'success=$success '
        'status=$status',
      );

      if (!success) {
        throw FormatException(
          response['message']?.toString() ?? 'كود الاستلام غير صحيح',
        );
      }

      if (status != 'picked_up') {
        throw const FormatException(
          'تم التحقق من الكود ولكن لم يتم تحديث حالة الطلب',
        );
      }

      debugPrint(
        '✅ PICKUP VERIFIED '
        'requestId=$cleanRequestId '
        'status=picked_up',
      );

      return response;
    } on PostgrestException catch (e) {
      debugPrint(
        '❌ VERIFY PICKUP Postgrest '
        'code=${e.code}',
      );

      debugPrint(
        '❌ VERIFY PICKUP message=${e.message}',
      );

      debugPrint(
        '❌ VERIFY PICKUP details=${e.details}',
      );

      rethrow;
    } catch (e) {
      debugPrint(
        '❌ VERIFY PICKUP error=$e',
      );

      rethrow;
    }
  }

  // ============================================================
  // ⭐ تأكيد إكمال الطلب - RPC آمن 🔐
  // ============================================================

  Future<void> completeRequest(
    String requestId,
  ) async {
    try {
      final cleanRequestId = requestId.trim();

      if (cleanRequestId.isEmpty) {
        throw Exception('معرف الطلب غير موجود');
      }

      final result = await _client.rpc(
        'institution_complete_offer_request',
        params: {
          'p_request_id': cleanRequestId,
        },
      );

      debugPrint(
        '📥 institution_complete_offer_request '
        'response=$result',
      );

      if (result is! Map) {
        throw Exception(
          'استجابة غير صالحة من الخادم',
        );
      }

      final response = Map<String, dynamic>.from(result);

      if (response['success'] != true) {
        throw Exception(
          response['message']?.toString() ?? 'تعذر إكمال الطلب',
        );
      }

      debugPrint(
        '✅ completeRequest success '
        'requestId=$cleanRequestId',
      );
    } on PostgrestException catch (e) {
      debugPrint(
        '❌ completeRequest Postgrest '
        'code=${e.code} '
        'message=${e.message}',
      );

      rethrow;
    } catch (e) {
      debugPrint(
        '❌ completeRequest error: $e',
      );

      rethrow;
    }
  }

  // ============================================================
  // جلب جميع طلبات المستخدم (SELECT فقط ✅)
  // ============================================================

  Future<List<InstitutionOfferRequest>> listMyRequests() async {
    try {
      final userId = _client.auth.currentUser?.id;

      if (userId == null || userId.isEmpty) {
        return [];
      }

      final rows = await _client.from('institution_offer_requests').select('''
            *,
            institution_offers:offer_id (
              *,
              institutions:institution_id (
                id,
                name,
                institution_type,
                logo_url,
                address,
                phone
              )
            )
          ''').eq('requester_id', userId).order(
            'created_at',
            ascending: false,
          );

      return rows
          .whereType<Map>()
          .map(
            (row) => InstitutionOfferRequest.fromJson(
              Map<String, dynamic>.from(row),
            ),
          )
          .toList(growable: false);
    } catch (e) {
      debugPrint(
        '❌ listMyRequests error: $e',
      );

      return [];
    }
  }

  // ============================================================
  // جلب عروض المؤسسة (SELECT فقط ✅)
  // ============================================================

  Future<List<Map<String, dynamic>>> getInstitutionOffers({
    required String institutionId,
    String? status,
    int limit = 50,
  }) async {
    try {
      var query = _client
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
          .eq(
            'institution_id',
            institutionId,
          )
          .filter(
            'deleted_at',
            'is',
            'null',
          );

      if (status != null && status.isNotEmpty) {
        query = query.eq(
          'status',
          status,
        );
      }

      final response = await query
          .order(
            'created_at',
            ascending: false,
          )
          .limit(limit);

      return response
          .whereType<Map>()
          .map(
            (row) => Map<String, dynamic>.from(row),
          )
          .toList();
    } catch (e) {
      debugPrint(
        '❌ getInstitutionOffers error: $e',
      );

      throw Exception(
        'فشل جلب عروض المؤسسة: $e',
      );
    }
  }

  // ============================================================
  // جلب تفاصيل عرض (SELECT فقط ✅)
  // ============================================================

  Future<Map<String, dynamic>?> getOfferDetails(
    String offerId,
  ) async {
    try {
      final response = await _client
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
          .eq(
            'id',
            offerId,
          )
          .filter(
            'deleted_at',
            'is',
            'null',
          )
          .maybeSingle();

      if (response == null) {
        return null;
      }

      return Map<String, dynamic>.from(
        response,
      );
    } catch (e) {
      debugPrint(
        '❌ getOfferDetails error: $e',
      );

      throw Exception(
        'فشل جلب تفاصيل العرض: $e',
      );
    }
  }

  // ============================================================
  // ⭐ البحث عن حجز بالكود - RPC آمن 🔐
  // ============================================================

  Future<Map<String, dynamic>?> findBookingByCode(String code) async {
    try {
      final cleanCode = code
          .trim()
          .replaceAll('٠', '0')
          .replaceAll('١', '1')
          .replaceAll('٢', '2')
          .replaceAll('٣', '3')
          .replaceAll('٤', '4')
          .replaceAll('٥', '5')
          .replaceAll('٦', '6')
          .replaceAll('٧', '7')
          .replaceAll('٨', '8')
          .replaceAll('٩', '9')
          .replaceAll(RegExp(r'[^0-9]'), '');

      if (cleanCode.length != 6) {
        throw Exception('كود الحجز يجب أن يتكون من 6 أرقام');
      }

      final result = await _client.rpc(
        'find_booking_by_code',
        params: {
          'p_code': cleanCode,
        },
      );

      debugPrint('📥 findBookingByCode response=$result');

      if (result == null) return null;

      if (result is! Map) {
        throw Exception('استجابة غير صالحة من الخادم');
      }

      final response = Map<String, dynamic>.from(result);

      if (response['success'] != true) {
        final error = response['error']?.toString() ?? 'حدث خطأ غير متوقع';
        if (response['code'] == 'NOT_FOUND') {
          throw Exception('لا يوجد حجز بهذا الكود');
        }
        if (response['code'] == 'NOT_OWNER') {
          throw Exception('هذا الحجز لا يخص مؤسستك');
        }
        if (response['code'] == 'UNAUTHORIZED') {
          throw Exception('غير مصرح لك بالبحث عن الحجوزات');
        }
        throw Exception(error);
      }

      final booking = Map<String, dynamic>.from(response);
      booking['offer'] = response['offer'] is Map
          ? Map<String, dynamic>.from(response['offer'] as Map)
          : {};
      booking['requester'] = response['requester'] is Map
          ? Map<String, dynamic>.from(response['requester'] as Map)
          : {};

      return booking;
    } on PostgrestException catch (e) {
      debugPrint(
          '❌ findBookingByCode Postgrest code=${e.code} message=${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('❌ findBookingByCode error: $e');
      rethrow;
    }
  }

  // ============================================================
  // ⭐ البحث عن حجز بالـ ID - RPC آمن 🔐
  // ============================================================

  Future<Map<String, dynamic>?> findBookingById(String requestId) async {
    try {
      final cleanId = requestId.trim();

      if (cleanId.isEmpty) {
        throw Exception('معرف الحجز غير موجود');
      }

      final result = await _client.rpc(
        'find_booking_by_id',
        params: {
          'p_request_id': cleanId,
        },
      );

      debugPrint('📥 findBookingById response=$result');

      if (result == null) return null;

      if (result is! Map) {
        throw Exception('استجابة غير صالحة من الخادم');
      }

      final response = Map<String, dynamic>.from(result);

      if (response['success'] != true) {
        throw Exception(response['error']?.toString() ?? 'حدث خطأ غير متوقع');
      }

      final booking = Map<String, dynamic>.from(response);
      booking['offer'] = response['offer'] is Map
          ? Map<String, dynamic>.from(response['offer'] as Map)
          : {};
      booking['requester'] = response['requester'] is Map
          ? Map<String, dynamic>.from(response['requester'] as Map)
          : {};

      return booking;
    } catch (e) {
      debugPrint('❌ findBookingById error: $e');
      rethrow;
    }
  }

  // ============================================================
  // ⭐ تحديث العرض - RPC آمن 🔐
  // ============================================================

  Future<void> updateOffer({
    required String offerId,
    String? title,
    String? description,
    String? category,
    int? quantity,
    int? remainingQuantity,
    double? symbolicPrice,
    double? originalPrice,
    List<String>? images,
    String? pickupLocation,
    DateTime? expiresAt,
    DateTime? pickupEnd,
    String? status,
    String? foodType,
    bool? isHalal,
    bool? isVegetarian,
    String? foodCondition,
    bool? requiresRefrigeration,
    String? pickupNotes,
    String? contactPhone,
  }) async {
    try {
      final cleanOfferId = offerId.trim();

      if (cleanOfferId.isEmpty) {
        throw Exception('معرف العرض غير موجود');
      }

      debugPrint(
        '➡️ updateOffer '
        'offerId=$cleanOfferId '
        'title=$title '
        'quantity=$quantity '
        'symbolicPrice=$symbolicPrice',
      );

      final result = await _client.rpc(
        'update_institution_offer',
        params: {
          'p_offer_id': cleanOfferId,
          'p_title': title,
          'p_description': description,
          'p_category': category,
          'p_quantity': quantity,
          'p_remaining_quantity': remainingQuantity,
          'p_symbolic_price': symbolicPrice,
          'p_original_price': originalPrice,
          'p_images': images,
          'p_pickup_location': pickupLocation,
          'p_expires_at': expiresAt?.toUtc().toIso8601String(),
          'p_pickup_end': pickupEnd?.toUtc().toIso8601String(),
          'p_status': status,
          'p_food_type': foodType,
          'p_is_halal': isHalal,
          'p_is_vegetarian': isVegetarian,
          'p_food_condition': foodCondition,
          'p_requires_refrigeration': requiresRefrigeration,
          'p_pickup_notes': pickupNotes,
          'p_contact_phone': contactPhone,
        },
      );

      debugPrint(
        '📥 updateOffer response=$result',
      );

      if (result is! Map) {
        throw Exception('استجابة غير صالحة من الخادم');
      }

      final response = Map<String, dynamic>.from(result);

      if (response['success'] != true) {
        throw Exception(
          response['message']?.toString() ?? 'تعذر تحديث العرض',
        );
      }

      debugPrint(
        '✅ updateOffer success '
        'offerId=$cleanOfferId',
      );
    } on PostgrestException catch (e) {
      debugPrint(
        '❌ updateOffer Postgrest '
        'code=${e.code} '
        'message=${e.message}',
      );

      final message = e.message.toLowerCase();
      if (message.contains('لا يمكن تغيير الكمية') ||
          message.contains('cannot change quantity')) {
        throw Exception(
            '⚠️ لا يمكن تغيير الكمية لأن هناك طلبات نشطة على هذا العرض');
      }
      if (message.contains('لا يمكن تغيير السعر') ||
          message.contains('cannot change price')) {
        throw Exception(
            '⚠️ لا يمكن تغيير السعر لأن هناك طلبات نشطة على هذا العرض');
      }
      if (message.contains('symbolic price cannot exceed original price')) {
        throw Exception('⚠️ السعر الرمزي لا يمكن أن يكون أكبر من السعر الأصلي');
      }
      if (message.contains('already reserved')) {
        throw Exception('⚠️ لا يمكن تعديل العرض لأنه تم حجز جزء منه');
      }
      if (message.contains('not found') || message.contains('غير موجود')) {
        throw Exception('⚠️ العرض غير موجود أو ليس لك');
      }
      if (message.contains('منتهي الصلاحية') || message.contains('expired')) {
        throw Exception('⚠️ لا يمكن تعديل عرض منتهي الصلاحية');
      }
      if (message.contains('ملغي') || message.contains('cancelled')) {
        throw Exception('⚠️ لا يمكن تعديل عرض ملغي');
      }
      if (message.contains('لا يمكن تشغيل عرض منتهي')) {
        throw Exception('⚠️ لا يمكن تشغيل عرض منتهي الصلاحية');
      }

      rethrow;
    } catch (e) {
      debugPrint(
        '❌ updateOffer error: $e',
      );
      rethrow;
    }
  }

  // ============================================================
  // ⭐ تشغيل/إيقاف العرض مؤقتاً - RPC آمن 🔐
  // ============================================================

  Future<Map<String, dynamic>> toggleOfferStatus({
    required String offerId,
    required bool active,
  }) async {
    final cleanOfferId = offerId.trim();

    if (cleanOfferId.isEmpty) {
      throw Exception('معرف العرض غير موجود');
    }

    try {
      final result = await _client.rpc(
        'toggle_institution_offer_status',
        params: {
          'p_offer_id': cleanOfferId,
          'p_new_status': active ? 'active' : 'paused',
        },
      );

      debugPrint('📥 toggleOfferStatus response=$result');

      if (result is! Map) {
        throw Exception('استجابة غير صالحة من الخادم');
      }

      final response = Map<String, dynamic>.from(result);

      if (response['success'] != true) {
        throw Exception(
          response['message']?.toString() ??
              (active ? 'تعذر تشغيل العرض' : 'تعذر إيقاف العرض مؤقتاً'),
        );
      }

      debugPrint(
        '✅ toggleOfferStatus success '
        'offerId=$cleanOfferId '
        'status=${response['status']}',
      );

      return response;
    } on PostgrestException catch (e) {
      debugPrint(
        '❌ toggleOfferStatus Postgrest '
        'code=${e.code} '
        'message=${e.message}',
      );

      final message = e.message.toLowerCase();
      if (message.contains('لا يمكن تشغيل عرض منتهي')) {
        throw Exception('⚠️ لا يمكن تشغيل عرض منتهي الصلاحية');
      }
      if (message.contains('لا يمكن تشغيل عرض ملغي')) {
        throw Exception('⚠️ لا يمكن تشغيل عرض ملغي');
      }

      rethrow;
    } catch (e) {
      debugPrint(
        '❌ toggleOfferStatus error: $e',
      );
      rethrow;
    }
  }

  // ============================================================
  // ⭐ إلغاء العرض (حتى مع الطلبات) - RPC آمن 🔐
  // ============================================================

  Future<Map<String, dynamic>> cancelOffer(
    String offerId,
  ) async {
    final cleanOfferId = offerId.trim();

    if (cleanOfferId.isEmpty) {
      throw Exception('معرف العرض غير موجود');
    }

    try {
      final result = await _client.rpc(
        'cancel_institution_offer',
        params: {
          'p_offer_id': cleanOfferId,
        },
      );

      debugPrint('📥 cancelOffer response=$result');

      if (result is! Map) {
        throw Exception('استجابة غير صالحة من الخادم');
      }

      final response = Map<String, dynamic>.from(result);

      if (response['success'] != true) {
        throw Exception(
          response['message']?.toString() ?? 'تعذر إلغاء العرض',
        );
      }

      debugPrint(
        '✅ cancelOffer success '
        'offerId=$cleanOfferId',
      );

      return response;
    } on PostgrestException catch (e) {
      debugPrint(
        '❌ cancelOffer Postgrest '
        'code=${e.code} '
        'message=${e.message}',
      );

      final message = e.message.toLowerCase();
      if (message.contains('منتهي الصلاحية') || message.contains('expired')) {
        throw Exception('⚠️ لا يمكن إلغاء عرض منتهي الصلاحية');
      }

      rethrow;
    } catch (e) {
      debugPrint(
        '❌ cancelOffer error: $e',
      );
      rethrow;
    }
  }

  // ============================================================
  // ⭐ تحديث حالة العرض - RPC آمن 🔐
  // ============================================================

  Future<void> updateOfferStatus({
    required String offerId,
    required String status,
  }) async {
    try {
      final cleanOfferId = offerId.trim();

      if (cleanOfferId.isEmpty) {
        throw Exception('معرف العرض غير موجود');
      }

      final result = await _client.rpc(
        'update_institution_offer_status',
        params: {
          'p_offer_id': cleanOfferId,
          'p_status': status,
        },
      );

      debugPrint(
        '📥 updateOfferStatus response=$result',
      );

      if (result is! Map) {
        throw Exception(
          'استجابة غير صالحة من الخادم',
        );
      }

      final response = Map<String, dynamic>.from(result);

      if (response['success'] != true) {
        throw Exception(
          response['message']?.toString() ?? 'تعذر تحديث حالة العرض',
        );
      }

      debugPrint(
        '✅ updateOfferStatus success '
        'offerId=$cleanOfferId '
        'status=$status',
      );
    } on PostgrestException catch (e) {
      debugPrint(
        '❌ updateOfferStatus Postgrest '
        'code=${e.code} '
        'message=${e.message}',
      );

      rethrow;
    } catch (e) {
      debugPrint(
        '❌ updateOfferStatus error: $e',
      );

      rethrow;
    }
  }

  // ============================================================
  // ⭐ حذف العرض Soft Delete - RPC آمن 🔐
  // ============================================================

  Future<void> deleteOffer(
    String offerId,
  ) async {
    try {
      final cleanOfferId = offerId.trim();

      if (cleanOfferId.isEmpty) {
        throw Exception('معرف العرض غير موجود');
      }

      final result = await _client.rpc(
        'delete_institution_offer',
        params: {
          'p_offer_id': cleanOfferId,
        },
      );

      debugPrint(
        '📥 deleteOffer response=$result',
      );

      if (result is! Map) {
        throw Exception(
          'استجابة غير صالحة من الخادم',
        );
      }

      final response = Map<String, dynamic>.from(result);

      if (response['success'] != true) {
        throw Exception(
          response['message']?.toString() ?? 'تعذر حذف العرض',
        );
      }

      debugPrint(
        '✅ deleteOffer success '
        'offerId=$cleanOfferId',
      );
    } on PostgrestException catch (e) {
      debugPrint(
        '❌ deleteOffer Postgrest '
        'code=${e.code} '
        'message=${e.message}',
      );

      rethrow;
    } catch (e) {
      debugPrint(
        '❌ deleteOffer error: $e',
      );

      rethrow;
    }
  }

  // ============================================================
  // البحث في العروض (SELECT فقط ✅)
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
          .eq(
            'status',
            'active',
          )
          .gt(
            'expires_at',
            DateTime.now().toUtc().toIso8601String(),
          )
          .filter(
            'deleted_at',
            'is',
            'null',
          );

      if (query != null && query.trim().isNotEmpty) {
        searchQuery = searchQuery.ilike(
          'title',
          '%${query.trim()}%',
        );
      }

      if (category != null && category.trim().isNotEmpty) {
        searchQuery = searchQuery.eq(
          'category',
          category.trim(),
        );
      }

      if (city != null && city.trim().isNotEmpty) {
        searchQuery = searchQuery.ilike(
          'pickup_location',
          '%${city.trim()}%',
        );
      }

      if (minPrice != null) {
        searchQuery = searchQuery.gte(
          'symbolic_price',
          minPrice,
        );
      }

      if (maxPrice != null) {
        searchQuery = searchQuery.lte(
          'symbolic_price',
          maxPrice,
        );
      }

      final response = await searchQuery
          .order(
            'created_at',
            ascending: false,
          )
          .limit(limit);

      return response
          .whereType<Map>()
          .map(
            (row) => Map<String, dynamic>.from(row),
          )
          .toList();
    } catch (e) {
      debugPrint(
        '❌ searchOffers error: $e',
      );

      throw Exception(
        'فشل البحث عن العروض: $e',
      );
    }
  }
}
