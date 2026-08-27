import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:loqma/core/services/supabase_service.dart';

class CharityInstitutionDonationsRepository {
  final SupabaseClient _client;

  CharityInstitutionDonationsRepository({SupabaseClient? client})
      : _client = client ?? SupabaseService().client;

  Future<List<Map<String, dynamic>>> listMyDonations() async {
    final charity = await _client
        .from('charities')
        .select('id')
        .eq('user_id', _client.auth.currentUser!.id)
        .eq('status', 'active')
        .maybeSingle();
    final charityId = charity?['id']?.toString();
    if (charityId == null || charityId.isEmpty) {
      throw const FormatException('لا توجد جمعية نشطة مرتبطة بالحساب');
    }

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
    final rows = await _client
        .from('charity_volunteers')
        .select('id, name, phone, status')
        .eq('charity_id', charityId)
        .eq('status', 'active')
        .order('name');
    return rows
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
  }

  Future<String> _currentCharityId() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      throw const FormatException('يجب تسجيل الدخول أولًا');
    }
    final charity = await _client
        .from('charities')
        .select('id')
        .eq('user_id', userId)
        .eq('status', 'active')
        .maybeSingle();
    final id = charity?['id']?.toString().trim() ?? '';
    if (id.isEmpty) {
      throw const FormatException('لا توجد جمعية نشطة مرتبطة بالحساب');
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

  Future<void> _rpc(String name, Map<String, dynamic> params) async {
    final result = await _client.rpc(name, params: params);
    if (result is Map && result['success'] == true) return;
    throw const FormatException('تعذر تنفيذ العملية حاليًا');
  }

  Future<Map<String, dynamic>> _rpcMap(
    String name,
    Map<String, dynamic> params,
  ) async {
    final result = await _client.rpc(name, params: params);
    if (result is Map && result['success'] == true) {
      return Map<String, dynamic>.from(result);
    }
    throw const FormatException('تعذر تنفيذ العملية حاليًا');
  }
}
