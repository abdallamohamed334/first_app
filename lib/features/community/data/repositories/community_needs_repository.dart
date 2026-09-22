// lib/features/community/data/repositories/community_needs_repository.dart

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CommunityNeedsRepository {
  final SupabaseClient _client;

  CommunityNeedsRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  // ============================================================
  // CREATE NEED
  // ============================================================

  Future<Map<String, dynamic>> createNeed({
    required String categoryId,
    required String categorySlug,
    required String categoryNameAr,
    required String title,
    String? description,
    int quantity = 1,
    String urgency = 'normal',
    String? city,
    String? address,
    double? latitude,
    double? longitude,
    // ✅ بيانات التواصل
    String? contactPhone,
    String? contactWhatsapp,
  }) async {
    final authUser = _client.auth.currentUser;

    if (authUser == null) {
      throw Exception('يجب تسجيل الدخول أولًا');
    }

    final cleanTitle = title.trim();

    // Validation
    if (cleanTitle.length < 3) {
      throw Exception('عنوان الاحتياج قصير جدًا (3 أحرف على الأقل)');
    }

    if (quantity <= 0) {
      throw Exception('الكمية يجب أن تكون أكبر من صفر');
    }

    const allowedUrgency = {'low', 'normal', 'high', 'urgent'};
    if (!allowedUrgency.contains(urgency)) {
      throw Exception('الأولوية غير صحيحة');
    }

    // ✅ التحقق من بيانات التواصل
    final cleanPhone = contactPhone?.trim();
    if (cleanPhone == null || cleanPhone.isEmpty) {
      throw Exception('رقم الهاتف مطلوب');
    }

    final cleanWhatsapp = contactWhatsapp?.trim();
    if (cleanWhatsapp == null || cleanWhatsapp.isEmpty) {
      throw Exception('رقم الواتساب مطلوب');
    }

    try {
      final response = await _client
          .from('community_needs')
          .insert({
            'requester_id': authUser.id,
            'category_id': categoryId,
            'category_slug': categorySlug,
            'category_name_ar': categoryNameAr,
            'title': cleanTitle,
            'description': description?.trim(),
            'quantity': quantity,
            'urgency': urgency,
            'city': city?.trim(),
            'address': address?.trim(),
            'latitude': latitude,
            'longitude': longitude,
            // ✅ بيانات التواصل
            'contact_phone': cleanPhone,
            'contact_whatsapp': cleanWhatsapp,
            'status': 'active',
          })
          .select()
          .single();

      return Map<String, dynamic>.from(response);
    } on PostgrestException catch (e) {
      if (e.code == 'P0300') {
        throw Exception(
            'لقد وصلت للحد الأقصى من الاحتياجات اليومية (5). حاول غدًا.');
      }
      rethrow;
    }
  }

  // ============================================================
  // LIST NEEDS (Public)
  // ============================================================

  Future<List<Map<String, dynamic>>> listNeeds({
    String? categoryId,
    String? city,
    String? search,
    int limit = 30,
    int offset = 0,
  }) async {
    try {
      final response = await _client.rpc(
        'list_community_needs',
        params: {
          'p_category_id': categoryId,
          'p_city': city,
          'p_search': search,
          'p_limit': limit,
          'p_offset': offset,
        },
      );

      if (response is! List) return [];

      return response
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
    } catch (error) {
      debugPrint('❌ listNeeds error: $error');
      return [];
    }
  }

  // ============================================================
  // MY NEEDS
  // ============================================================

  Future<List<Map<String, dynamic>>> getMyNeeds() async {
    try {
      final response = await _client.rpc('list_my_community_needs');

      if (response is! List) return [];

      return response
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
    } catch (error) {
      debugPrint('❌ getMyNeeds error: $error');
      return [];
    }
  }

  // ============================================================
  // ✅ GET ONE NEED (بدون join — بـ 2 queries)
  // ============================================================

  Future<Map<String, dynamic>?> getNeedById(String needId) async {
    try {
      // ✅ 1) جلب الاحتياج نفسه
      final needResponse = await _client
          .from('community_needs')
          .select('*')
          .eq('id', needId)
          .maybeSingle();

      if (needResponse == null) return null;

      final need = Map<String, dynamic>.from(needResponse);

      // ✅ 2) جلب بيانات صاحب الاحتياج (query منفصل)
      final requesterId = need['requester_id']?.toString();
      if (requesterId != null && requesterId.isNotEmpty) {
        try {
          final userResponse = await _client
              .from('users')
              .select('id, name, avatar_url, city, phone')
              .eq('id', requesterId)
              .maybeSingle();

          if (userResponse != null) {
            need['users'] = Map<String, dynamic>.from(userResponse);
          }
        } catch (userError) {
          debugPrint('⚠️ Failed to load requester: $userError');
        }
      }

      return need;
    } catch (error) {
      debugPrint('❌ getNeedById error: $error');
      return null;
    }
  }

  // ============================================================
  // TRACK CONTACT (لعدّاد التواصل)
  // ============================================================

  Future<Map<String, dynamic>> trackContact({
    required String needId,
    required String contactType,
  }) async {
    try {
      final response = await _client.rpc(
        'track_need_contact',
        params: {
          'p_need_id': needId,
          'p_contact_type': contactType,
        },
      );

      if (response is Map) {
        return Map<String, dynamic>.from(response);
      }

      return {'success': false};
    } on PostgrestException catch (e) {
      if (e.code == 'P0304') {
        throw Exception('لا يمكنك التواصل مع احتياجك');
      }
      if (e.code == 'P0303') {
        throw Exception('الاحتياج غير متاح');
      }
      rethrow;
    }
  }

  // ============================================================
  // ✅ UPDATE NEED (مع دعم التصنيف)
  // ============================================================

  Future<bool> updateNeed({
    required String needId,
    String? title,
    String? description,
    int? quantity,
    String? urgency,
    String? city,
    String? address,
    String? contactPhone,
    String? contactWhatsapp,
    // ✅ التصنيف
    String? categoryId,
    String? categorySlug,
    String? categoryNameAr,
  }) async {
    try {
      final payload = <String, dynamic>{};

      if (title != null) payload['title'] = title.trim();
      if (description != null) payload['description'] = description.trim();
      if (quantity != null) payload['quantity'] = quantity;
      if (urgency != null) payload['urgency'] = urgency;
      if (city != null) payload['city'] = city.trim();
      if (address != null) payload['address'] = address.trim();
      if (contactPhone != null) payload['contact_phone'] = contactPhone.trim();
      if (contactWhatsapp != null) {
        payload['contact_whatsapp'] = contactWhatsapp.trim();
      }
      // ✅ التصنيف
      if (categoryId != null) payload['category_id'] = categoryId;
      if (categorySlug != null) payload['category_slug'] = categorySlug;
      if (categoryNameAr != null) {
        payload['category_name_ar'] = categoryNameAr;
      }

      if (payload.isEmpty) return true;

      await _client
          .from('community_needs')
          .update(payload)
          .eq('id', needId)
          .eq('requester_id', _client.auth.currentUser!.id);

      return true;
    } catch (error) {
      debugPrint('❌ updateNeed error: $error');
      return false;
    }
  }

  // ============================================================
  // CANCEL NEED
  // ============================================================

  Future<bool> cancelNeed(String needId) async {
    try {
      await _client
          .from('community_needs')
          .update({'status': 'cancelled'})
          .eq('id', needId)
          .eq('requester_id', _client.auth.currentUser!.id);

      return true;
    } catch (error) {
      debugPrint('❌ cancelNeed error: $error');
      return false;
    }
  }

  // ============================================================
  // MARK AS FULFILLED
  // ============================================================

  Future<bool> markAsFulfilled(String needId, {String? fulfilledBy}) async {
    try {
      await _client
          .from('community_needs')
          .update({
            'status': 'fulfilled',
            'fulfilled_by': fulfilledBy,
            'fulfilled_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', needId)
          .eq('requester_id', _client.auth.currentUser!.id);

      return true;
    } catch (error) {
      debugPrint('❌ markAsFulfilled error: $error');
      return false;
    }
  }

  // ============================================================
  // ✅ DISMISS NEED (إخفاء من عند اليوزر بس)
  // ============================================================

  /// بيخفي الاحتياج من عند اليوزر **بس**
  /// البيانات تفضل في DB للأدلة والمراجعة
  Future<bool> dismissNeed(String needId) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('يجب تسجيل الدخول أولًا');
      }

      // ✅ التحقق من الملكية
      final need = await _client
          .from('community_needs')
          .select('requester_id')
          .eq('id', needId)
          .maybeSingle();

      if (need == null) {
        throw Exception('الاحتياج غير موجود');
      }

      if (need['requester_id']?.toString() != userId) {
        throw Exception('لا تملك صلاحية إخفاء هذا الاحتياج');
      }

      // ✅ INSERT في جدول الـ dismissed (upsert عشان لو موجود)
      await _client.from('dismissed_community_needs').upsert(
        {
          'user_id': userId,
          'need_id': needId,
        },
        onConflict: 'user_id,need_id',
      );

      return true;
    } catch (error) {
      debugPrint('❌ dismissNeed error: $error');
      rethrow;
    }
  }

  // ============================================================
  // ✅ UNDO DISMISS (إلغاء الإخفاء — لو عايز ترجع الاحتياج)
  // ============================================================

  Future<bool> undoDismissNeed(String needId) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('يجب تسجيل الدخول أولًا');
      }

      await _client
          .from('dismissed_community_needs')
          .delete()
          .eq('user_id', userId)
          .eq('need_id', needId);

      return true;
    } catch (error) {
      debugPrint('❌ undoDismissNeed error: $error');
      rethrow;
    }
  }

  // ============================================================
  // ⚠️ DELETE NEED (حذف نهائي — DEPRECATED)
  // ============================================================
  //
  // ⚠️ تحذير: الدالة دي بتمسح الاحتياج من DB نهائيًا
  //    من الأفضل استخدام dismissNeed بدلًا منها
  //    عشان البيانات تفضل محفوظة للأدلة والمراجعة.
  //
  // ============================================================

  @Deprecated('استخدم dismissNeed بدل deleteNeed — الأدلة بتفضل في DB')
  Future<bool> deleteNeed(String needId) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('يجب تسجيل الدخول أولًا');
      }

      // ✅ التحقق من الحالة والملكية
      final need = await _client
          .from('community_needs')
          .select('status, requester_id')
          .eq('id', needId)
          .maybeSingle();

      if (need == null) {
        throw Exception('الاحتياج غير موجود');
      }

      if (need['requester_id']?.toString() != userId) {
        throw Exception('لا تملك صلاحية حذف هذا الاحتياج');
      }

      final status = need['status']?.toString() ?? '';
      const allowedStatuses = {'expired', 'cancelled', 'fulfilled'};

      if (!allowedStatuses.contains(status)) {
        throw Exception('لا يمكن حذف احتياج نشط. لازم تلغيه الأول.');
      }

      // ✅ حذف نهائي من DB
      await _client
          .from('community_needs')
          .delete()
          .eq('id', needId)
          .eq('requester_id', userId);

      return true;
    } catch (error) {
      debugPrint('❌ deleteNeed error: $error');
      rethrow;
    }
  }

  // ============================================================
  // MATCHING OFFERS (للاحتياج)
  // ============================================================

  Future<List<Map<String, dynamic>>> findMatchingOffers({
    required String needId,
  }) async {
    try {
      final response = await _client.rpc(
        'find_matching_offers_for_need',
        params: {'p_need_id': needId},
      );

      if (response is! List) return [];

      final rows = response
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList();

      final result = <Map<String, dynamic>>[];
      for (final row in rows) {
        try {
          final signedRow = await _withSignedImageUrl(row);
          result.add(signedRow);
        } catch (_) {
          result.add(row);
        }
      }

      return result;
    } catch (error) {
      debugPrint('❌ findMatchingOffers error: $error');
      return [];
    }
  }

  // ============================================================
  // MATCHING NEEDS (للعرض)
  // ============================================================

  Future<List<Map<String, dynamic>>> findMatchingNeeds({
    required String offerId,
  }) async {
    try {
      final response = await _client.rpc(
        'find_matching_needs_for_offer',
        params: {'p_offer_id': offerId},
      );

      if (response is! List) return [];

      return response
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
    } catch (error) {
      debugPrint('❌ findMatchingNeeds error: $error');
      return [];
    }
  }

  // ============================================================
  // ✅ GET CONTACTS (بدون join — بـ 2 queries)
  // ============================================================

  Future<List<Map<String, dynamic>>> getNeedContacts(String needId) async {
    try {
      // ✅ 1) جلب الـ contacts
      final contactsResponse = await _client
          .from('need_contacts')
          .select('id, contact_type, created_at, contactor_id')
          .eq('need_id', needId)
          .order('created_at', ascending: false);

      final contacts = List<Map<String, dynamic>>.from(contactsResponse);

      if (contacts.isEmpty) return [];

      // ✅ 2) جلب بيانات الـ contactors
      final contactorIds = contacts
          .map((c) => c['contactor_id']?.toString())
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();

      if (contactorIds.isEmpty) return contacts;

      try {
        final usersResponse = await _client
            .from('users')
            .select('id, name, avatar_url')
            .inFilter('id', contactorIds);

        final usersList = List<Map<String, dynamic>>.from(usersResponse);
        final usersMap = <String, Map<String, dynamic>>{};
        for (final u in usersList) {
          final id = u['id']?.toString();
          if (id != null) usersMap[id] = u;
        }

        // ✅ 3) دمج البيانات
        for (var i = 0; i < contacts.length; i++) {
          final contactorId = contacts[i]['contactor_id']?.toString();
          if (contactorId != null && usersMap.containsKey(contactorId)) {
            contacts[i]['users'] = usersMap[contactorId];
          }
        }
      } catch (userError) {
        debugPrint('⚠️ Failed to load contactors: $userError');
      }

      return contacts;
    } catch (error) {
      debugPrint('❌ getNeedContacts error: $error');
      return [];
    }
  }

  // ============================================================
  // HELPERS
  // ============================================================

  Future<Map<String, dynamic>> _withSignedImageUrl(
    Map<String, dynamic> row,
  ) async {
    final result = Map<String, dynamic>.from(row);

    final image = result['image']?.toString();
    if (image == null || image.isEmpty || image == 'null') return result;

    if (image.startsWith('http://') || image.startsWith('https://')) {
      return result;
    }

    try {
      final signed = await _client.storage
          .from('community-offers')
          .createSignedUrl(image, 3600);
      result['image'] = signed;
    } catch (_) {
      // skip
    }

    return result;
  }

  // ============================================================
  // CURRENT USER
  // ============================================================

  String? getCurrentUserId() => _client.auth.currentUser?.id;
}
