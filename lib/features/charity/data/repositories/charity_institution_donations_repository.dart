import 'package:flutter/foundation.dart';
import 'package:loqma/core/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CharityInstitutionDonationsRepository {
  final SupabaseClient _client;

  CharityInstitutionDonationsRepository({SupabaseClient? client})
      : _client = client ?? SupabaseService().client;

  Future<String> _currentCharityId() async {
    final userId = _client.auth.currentUser?.id;

    if (userId == null || userId.isEmpty) {
      throw const FormatException('يجب تسجيل الدخول أولًا');
    }

    final raw = await _client.rpc('get_my_charity_context');
    final data =
        raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};

    final charityId = data['charity_id']?.toString().trim() ?? '';
    final rpcUserId = data['user_id']?.toString().trim() ?? '';

    debugPrint(
      '🔎 [InstitutionDonations] '
      'allowed=${data['allowed']} '
      'charityId=$charityId '
      'rpcUserId=$rpcUserId '
      'currentUser=$userId '
      'status=${data['status']}',
    );

    if (data['allowed'] != true ||
        charityId.isEmpty ||
        rpcUserId.isEmpty ||
        rpcUserId != userId) {
      throw FormatException(
        data['message']?.toString() ?? 'لا توجد جمعية مرتبطة بالحساب',
      );
    }

    return charityId;
  }

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

  /// الاسم الذي تستخدمه صفحة تبرعات المؤسسات.
  Future<List<Map<String, dynamic>>> listCharityVolunteers() async {
    await _currentCharityId();

    final raw = await _client.rpc('list_my_charity_volunteers_manage');
    if (raw is! List) return const <Map<String, dynamic>>[];

    return raw
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
  }

  /// اسم بديل للتوافق مع الصفحات القديمة.
  Future<List<Map<String, dynamic>>> getCharityVolunteers() =>
      listCharityVolunteers();

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
    final result = await _client.rpc('institution_generate_pickup_code',
        params: {'p_donation_id': donationId.trim()});
    return _mapSuccessfulResult(result);
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

  Future<void> _rpc(String name, Map<String, dynamic> params) async {
    final result = await _client.rpc(name, params: params);

    if (result == null) return;
    if (result is Map) {
      final data = Map<String, dynamic>.from(result);
      if (data['success'] == true ||
          data['ok'] == true ||
          data['error'] == null) {
        return;
      }
      throw FormatException(
        data['message']?.toString() ??
            data['error']?.toString() ??
            'تعذر تنفيذ العملية حاليًا',
      );
    }
  }

  Map<String, dynamic> _mapSuccessfulResult(dynamic result) {
    if (result is Map) {
      final data = Map<String, dynamic>.from(result);
      if (data['success'] == false || data['ok'] == false) {
        throw FormatException(
          data['message']?.toString() ??
              data['error']?.toString() ??
              'تعذر تنفيذ العملية حاليًا',
        );
      }
      return data;
    }
    throw const FormatException('استجابة غير متوقعة من الخادم');
  }
}
