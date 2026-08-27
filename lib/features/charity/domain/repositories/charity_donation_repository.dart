import 'package:supabase_flutter/supabase_flutter.dart';

class SeparateCharityDonationRepository {
  final SupabaseClient _client;

  SeparateCharityDonationRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  String _friendly(Object error) {
    final text = error.toString().replaceFirst('Exception: ', '');
    if (text.contains('status') || text.contains('الانتقال')) {
      return 'لا يمكن تنفيذ هذه الخطوة من الحالة الحالية';
    }
    if (text.contains('كود')) return text;
    return text;
  }

  Future<String> _currentUserId() async {
    final id = _client.auth.currentUser?.id;
    if (id == null || id.isEmpty) throw Exception('يجب تسجيل الدخول أولًا');
    return id;
  }

  Future<Map<String, dynamic>> createDonation({
    required String charityId,
    required String title,
    required String description,
    required String category,
    required int quantity,
    required String condition,
    required String pickupAddress,
    required String donorPhone,
    String? donorNotes,
    List<String> images = const [],
  }) async {
    final donorId = await _currentUserId();
    if (title.trim().length < 3) throw Exception('اكتب عنوانًا واضحًا للتبرع');
    final row = await _client
        .from('charity_donation_requests')
        .insert({
          'donor_id': donorId,
          'charity_id': charityId,
          'title': title.trim(),
          'description': description.trim(),
          'category': category,
          'quantity': quantity,
          'condition': condition,
          'pickup_address': pickupAddress.trim(),
          'donor_phone': donorPhone.trim(),
          'donor_notes': donorNotes?.trim(),
          'images': images,
          'status': 'pending',
        })
        .select()
        .single();
    return Map<String, dynamic>.from(row);
  }

  Future<List<Map<String, dynamic>>> getMyDonations() async {
    final userId = await _currentUserId();
    final rows = await _client.from('charity_donation_requests').select('''
      id, title, description, category, quantity, condition, images,
      pickup_address, donor_phone, donor_notes, charity_notes, status,
      pickup_token_expires_at, donor_pickup_confirmed_at, accepted_at,
      completed_at, created_at, updated_at,
      volunteer_type, volunteer_name, volunteer_phone,
      charities:charity_id (id, name, logo, address, phone, email, is_verified)
    ''').eq('donor_id', userId).order('created_at', ascending: false);
    return (rows as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
  }

  Future<String> _charityIdForCurrentUser() async {
    final userId = await _currentUserId();
    final row = await _client
        .from('charities')
        .select('id, status')
        .eq('user_id', userId)
        .maybeSingle();
    if (row == null) throw Exception('لا توجد جمعية مرتبطة بالحساب');
    if (row['status']?.toString() != 'active') {
      throw Exception('حساب الجمعية ما زال قيد المراجعة');
    }
    return row['id'].toString();
  }

  Future<List<Map<String, dynamic>>> getCharityDonations() async {
    final charityId = await _charityIdForCurrentUser();
    final rows = await _client.from('charity_donation_requests').select('''
      id, donor_id, charity_id, title, description, category, quantity, condition,
      images, pickup_address, donor_phone, donor_notes, charity_notes, status,
      volunteer_type, volunteer_id, volunteer_name, volunteer_phone,
      pickup_token_expires_at, donor_pickup_confirmed_at, accepted_at,
      assigned_at, completed_at, created_at, updated_at,
      users:donor_id (id, name, phone, email, avatar_url)
    ''').eq('charity_id', charityId).order('created_at', ascending: false);
    return (rows as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
  }

  Future<List<Map<String, dynamic>>> getVolunteerDonations() async {
    final userId = await _currentUserId();
    final rows = await _client.from('charity_donation_requests').select('''
      id, title, description, category, quantity, images, pickup_address,
      donor_phone, status, volunteer_name, volunteer_phone, donor_pickup_confirmed_at,
      charities:charity_id (id, name, address, phone)
    ''').eq('volunteer_id', userId).order('created_at', ascending: false);
    return (rows as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
  }

  Future<String> generatePickupToken(String requestId) async {
    try {
      final result = await _client.rpc('generate_direct_donation_pickup_token',
          params: {'p_request_id': requestId});
      return result.toString();
    } catch (e) {
      throw Exception(_friendly(e));
    }
  }

  Future<void> confirmPickup(
      {required String requestId, required String token}) async {
    try {
      await _client.rpc('confirm_direct_donation_pickup',
          params: {'p_request_id': requestId, 'p_token': token.trim()});
    } catch (e) {
      throw Exception(_friendly(e));
    }
  }

  Future<void> assignVolunteer(
      {required String requestId,
      required String volunteerType,
      String? volunteerId,
      String? volunteerName,
      String? volunteerPhone}) async {
    try {
      await _client.rpc('assign_direct_donation_volunteer', params: {
        'p_request_id': requestId,
        'p_volunteer_type': volunteerType,
        'p_volunteer_id': volunteerId,
        'p_volunteer_name': volunteerName,
        'p_volunteer_phone': volunteerPhone,
      });
    } catch (e) {
      throw Exception(_friendly(e));
    }
  }

  Future<void> updateStatus(
      {required String requestId,
      required String status,
      String? notes}) async {
    const allowed = {
      'accepted',
      'rejected',
      'ready_for_pickup',
      'in_transit',
      'completed'
    };
    if (!allowed.contains(status)) {
      throw Exception('هذه الحالة لا يتم تحديثها من صفحة الجمعية');
    }
    try {
      await _client.rpc('advance_direct_donation_status',
          params: {'p_request_id': requestId, 'p_next_status': status});
      if (notes != null && notes.trim().isNotEmpty) {
        await _client
            .from('charity_donation_requests')
            .update({'charity_notes': notes.trim()}).eq('id', requestId);
      }
    } catch (e) {
      throw Exception(_friendly(e));
    }
  }
}
