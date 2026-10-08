// lib/features/charity/domain/repositories/charity_restaurant_donations_repository.dart

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:loqma/core/services/supabase_service.dart';

class CharityRestaurantDonationsRepository {
  final SupabaseClient _client = SupabaseService().client;

  // FIXED: `restaurant_charity_donations` has NO `offer_id` column, so the
  // previous per-row lookup into `food_offers` always found nothing and
  // silently overwrote the REAL `item_title`/`quantity` already present on
  // the row (from `select('*')`) with generic placeholders. This table has
  // its own `item_title`, `quantity`, and `images` columns — we just use
  // them directly now, with fallbacks only when they're genuinely empty.
  Future<List<Map<String, dynamic>>> listDonations() async {
    try {
      final response =
          await _client.from('restaurant_charity_donations').select('''
            *,
            restaurants!inner(
              id,
              name,
              logo,
              address,
              phone
            )
          ''').order('created_at', ascending: false);

      final donations = <Map<String, dynamic>>[];
      for (final raw in response) {
        final donation = Map<String, dynamic>.from(raw as Map);
        final title = donation['item_title']?.toString().trim();
        if (title == null || title.isEmpty) {
          donation['item_title'] = 'تبرع غذائي';
        }
        donation['quantity'] = donation['quantity'] ?? 0;
        donations.add(donation);
      }

      print('✅ Loaded ${donations.length} donations');
      return donations;
    } catch (e) {
      print('❌ Error listing donations: $e');
      rethrow;
    }
  }

  // Generic status writer. Callers must only pass values allowed by
  // restaurant_charity_donations_status_check: pending, accepted, rejected,
  // volunteer_assigned, picked_up, completed, cancelled, expired.
  Future<Map<String, dynamic>> updateDonationStatusDirect({
    required String donationId,
    required String status,
  }) async {
    try {
      print('📌 Updating donation status: $donationId -> $status');

      final response = await _client
          .from('restaurant_charity_donations')
          .update({
            'status': status,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', donationId)
          .select()
          .single();

      print('✅ Donation status updated: $response');
      return response;
    } catch (e) {
      print('❌ Error updating donation status: $e');
      rethrow;
    }
  }

  // ✅ جلب مندوبين الجمعية - من جدول charity_volunteers
  Future<List<Map<String, dynamic>>> getCharityVolunteers() async {
    try {
      final response = await _client
          .from('charity_volunteers')
          .select('id, name, phone, avatar_url, status')
          .eq('status', 'active')
          .order('name', ascending: true);

      print('✅ Found ${response.length} charity volunteers');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('❌ Error getting charity volunteers: $e');
      return [];
    }
  }

  // ✅ جلب مندوبين خارجيين - من جدول users
  Future<List<Map<String, dynamic>>> getExternalVolunteers() async {
    try {
      final response = await _client
          .from('users')
          .select('id, name, phone, avatar_url')
          .eq('user_type', 'user')
          .eq('is_active', true)
          .order('name', ascending: true);

      print('✅ Found ${response.length} external volunteers');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('❌ Error getting external volunteers: $e');
      return [];
    }
  }

  // ✅ تعيين مندوب — this already writes status: 'volunteer_assigned', which
  // is a valid value, so it was never the source of the constraint errors.
  Future<void> assignVolunteer({
    required String donationId,
    required String volunteerId,
    required String volunteerType,
  }) async {
    try {
      print('📌🔍 assignVolunteer START');
      print('📌🔍 donationId: $donationId');
      print('📌🔍 volunteerId: $volunteerId');
      print('📌🔍 volunteerType: $volunteerType');

      Map<String, dynamic>? volunteer;
      String volunteerName = 'مندوب';
      String volunteerPhone = '';

      if (volunteerType == 'internal') {
        volunteer = await _client
            .from('charity_volunteers')
            .select('id, name, phone')
            .eq('id', volunteerId)
            .eq('status', 'active')
            .maybeSingle();

        if (volunteer == null) {
          throw Exception('المندوب غير موجود أو غير نشط');
        }
      } else {
        volunteer = await _client
            .from('users')
            .select('id, name, phone')
            .eq('id', volunteerId)
            .eq('is_active', true)
            .maybeSingle();

        if (volunteer == null) {
          throw Exception('المندوب الخارجي غير موجود');
        }
      }

      volunteerName = volunteer['name']?.toString() ?? 'مندوب';
      volunteerPhone = volunteer['phone']?.toString() ?? '';

      print('📌🔍 Volunteer found: $volunteerName');
      print('📌🔍 Volunteer phone: $volunteerPhone');

      final volunteerTypeValue = volunteerType == 'internal'
          ? 'charity_volunteer'
          : 'external_volunteer';

      final updateData = {
        'charity_volunteer_id': volunteerId,
        'volunteer_type': volunteerTypeValue,
        'volunteer_name': volunteerName,
        'volunteer_phone': volunteerPhone,
        'status': 'volunteer_assigned',
        'updated_at': DateTime.now().toIso8601String(),
      };

      print('📌🔍 Update data: $updateData');

      final response = await _client
          .from('restaurant_charity_donations')
          .update(updateData)
          .eq('id', donationId)
          .select();

      print('📌🔍 Response: $response');
      print('✅ Volunteer assigned: $volunteerName ($volunteerTypeValue)');
    } catch (e) {
      print('❌ Error assigning volunteer: $e');
      rethrow;
    }
  }

  // ✅ إنشاء كود الاستلام (يستخدمه المطعم من صفحته الخاصة، وليس من هنا)
  Future<String> generatePickupCode(String donationId) async {
    try {
      final response = await _client.rpc(
        'generate_donation_pickup_code',
        params: {'p_donation_id': donationId},
      );

      return response['code']?.toString() ?? '';
    } catch (e) {
      print('❌ Error generating pickup code: $e');
      rethrow;
    }
  }

  // ✅ التحقق من صحة الكود (الجمعية هي اللي تتحقق) — على نجاح التحقق، الحالة
  // تتحول لـ picked_up مباشرة (قيمة صالحة في الـ check constraint).
  Future<bool> verifyPickupCode({
    required String donationId,
    required String code,
  }) async {
    try {
      final response = await _client.rpc(
        'verify_donation_pickup_code',
        params: {
          'p_donation_id': donationId,
          'p_code': code,
        },
      );

      final valid = response['valid'] as bool? ?? false;
      if (valid) {
        await updateDonationStatusDirect(
          donationId: donationId,
          status: 'picked_up',
        );
      }
      return valid;
    } catch (e) {
      print('❌ Error verifying pickup code: $e');
      return false;
    }
  }

  // ✅ تأكيد وصول التبرع للجمعية
  Future<void> confirmArrivalToCharity(String donationId) async {
    try {
      await updateDonationStatusDirect(
        donationId: donationId,
        status: 'completed',
      );

      print('✅ Donation arrived to charity: $donationId');
    } catch (e) {
      print('❌ Error confirming arrival: $e');
      rethrow;
    }
  }
}
