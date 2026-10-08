// lib/features/institutions/data/repositories/charity_institution_donations_repository.dart

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wasla/core/services/supabase_service.dart';

class CharityInstitutionDonationsRepository {
  final SupabaseClient _client;

  CharityInstitutionDonationsRepository({SupabaseClient? client})
      : _client = client ?? SupabaseService().client;

  Future<List<Map<String, dynamic>>> listMyDonations() async {
    final charityId = await _currentCharityId();

    final rows = await _client
        .from('institution_charity_donations')
        .select('*, institutions(id, name, institution_type, logo_url)')
        .eq('charity_id', charityId)
        .order('created_at', ascending: false);

    return rows
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> listCharityVolunteers() async {
    final charityId = await _currentCharityId();
    final raw = await _client.rpc(
      'list_my_charity_volunteers_manage',
      params: {'p_charity_id': charityId},
    );
    if (raw is! List) return const <Map<String, dynamic>>[];

    return raw
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .where((row) {
      final status = row['status']?.toString().trim().toLowerCase();
      return status == null || status.isEmpty || status == 'active';
    }).toList(growable: false);
  }

  Future<String> _currentCharityId() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      throw const FormatException('يجب تسجيل الدخول أولًا');
    }

    final raw = await _client.rpc('get_my_charity_context');
    final data =
        raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
    final id = data['charity_id']?.toString().trim() ?? '';
    final rpcUserId = data['user_id']?.toString().trim() ?? '';

    debugPrint(
      '🔎 [InstitutionDonations] allowed=${data['allowed']} '
      'charityId=$id rpcUserId=$rpcUserId currentUser=$userId '
      'status=${data['status']}',
    );

    if (data['allowed'] != true ||
        id.isEmpty ||
        rpcUserId.isEmpty ||
        rpcUserId != userId) {
      throw FormatException(
        data['message']?.toString() ?? 'لا توجد جمعية مرتبطة بالحساب',
      );
    }
    return id;
  }

  Future<void> acceptDonation(String donationId, bool accept) async {
    await _rpc('institution_accept_charity_donation', {
      'p_donation_id': donationId.trim(),
      'p_accept': accept,
    });
  }

  Future<void> assignVolunteer({
    required String donationId,
    String? volunteerId,
    required String volunteerName,
    required String volunteerPhone,
  }) async {
    await _rpc('institution_assign_charity_volunteer', {
      'p_donation_id': donationId.trim(),
      'p_volunteer_id': volunteerId,
      'p_volunteer_name': volunteerName.trim(),
      'p_volunteer_phone': volunteerPhone.trim(),
    });
  }

  Future<void> markVolunteerDeparted(String donationId) async {
    await _rpc('institution_mark_volunteer_departed', {
      'p_donation_id': donationId.trim(),
    });
  }

  Future<Map<String, dynamic>> generatePickupCode(String donationId) async {
    return _rpcMap('institution_generate_pickup_code', {
      'p_donation_id': donationId.trim(),
    });
  }

  Future<void> verifyPickupCode({
    required String donationId,
    required String code,
  }) async {
    await _rpc('institution_verify_pickup_code', {
      'p_donation_id': donationId.trim(),
      'p_code': code.trim(),
    });
  }

  Future<void> confirmArrival(String donationId) async {
    await _rpc('institution_confirm_arrival', {
      'p_donation_id': donationId.trim(),
    });
  }

  // ═══════════════════════════════════════════════════════════
  // ✅ RPC Helpers — بيكشفوا الرسالة الحقيقية
  // ═══════════════════════════════════════════════════════════
  Future<void> _rpc(String name, Map<String, dynamic> params) async {
    try {
      final result = await _client.rpc(name, params: params);

      debugPrint('📥 RPC [$name] response=$result');

      if (result is Map) {
        final map = Map<String, dynamic>.from(result);
        if (map['success'] == true) return;

        // ✅ نرمي الرسالة الحقيقية من الـ backend
        final msg = map['message']?.toString().trim() ?? '';
        if (msg.isNotEmpty) {
          throw FormatException(msg);
        }
        throw const FormatException('تعذر تنفيذ العملية حاليًا');
      }

      // لو الـ RPC رجع void، نعتبره نجاح
      return;
    } on PostgrestException catch (e) {
      debugPrint('❌ RPC [$name] Postgrest: ${e.code} - ${e.message}');
      // ✅ نمرر الرسالة الحقيقية من Postgrest
      final msg = e.message.trim();
      if (msg.isNotEmpty && RegExp(r'[\u0600-\u06FF]').hasMatch(msg)) {
        throw FormatException(msg);
      }
      throw FormatException(msg.isNotEmpty ? msg : 'تعذر تنفيذ العملية حاليًا');
    } catch (e) {
      debugPrint('❌ RPC [$name] error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> _rpcMap(
    String name,
    Map<String, dynamic> params,
  ) async {
    try {
      final result = await _client.rpc(name, params: params);

      debugPrint('📥 RPC [$name] response=$result');

      if (result is Map) {
        final map = Map<String, dynamic>.from(result);
        if (map['success'] == true ||
            map['ok'] == true ||
            map['pickup_code'] != null ||
            map['code'] != null) {
          return map;
        }

        final msg = map['message']?.toString().trim() ?? '';
        if (msg.isNotEmpty) {
          throw FormatException(msg);
        }
        throw const FormatException('تعذر تنفيذ العملية حاليًا');
      }

      throw const FormatException('استجابة غير صالحة من الخادم');
    } on PostgrestException catch (e) {
      debugPrint('❌ RPC [$name] Postgrest: ${e.code} - ${e.message}');
      final msg = e.message.trim();
      if (msg.isNotEmpty && RegExp(r'[\u0600-\u06FF]').hasMatch(msg)) {
        throw FormatException(msg);
      }
      throw FormatException(msg.isNotEmpty ? msg : 'تعذر تنفيذ العملية حاليًا');
    } catch (e) {
      debugPrint('❌ RPC [$name] error: $e');
      rethrow;
    }
  }
}
