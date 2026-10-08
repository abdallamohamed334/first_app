import 'package:loqma/core/models/business.dart';
import 'package:loqma/core/services/supabase_service.dart';

class BusinessRepository {
  final SupabaseService _supabase;

  BusinessRepository(this._supabase);

  Future<Business?> getBusinessById(String businessId) async {
    try {
      if (businessId.trim().isEmpty) return null;

      final response = await _supabase.client
          .from('businesses')
          .select()
          .eq('id', businessId)
          .maybeSingle();

      if (response == null) return null;
      return Business.fromJson(response);
    } catch (e) {
      print('❌ Error getting business: $e');
      return null;
    }
  }

  Future<List<String>> _getRestaurantIdsForBusiness(
    String businessId,
  ) async {
    final ids = <String>{};
    if (businessId.trim().isEmpty) return <String>[];

    try {
      final business = await _supabase.client
          .from('businesses')
          .select('user_id')
          .eq('id', businessId)
          .maybeSingle();

      final ownerId = business?['user_id']?.toString();
      if (ownerId != null && ownerId.isNotEmpty) {
        final restaurant = await _supabase.client
            .from('restaurants')
            .select('id')
            .eq('user_id', ownerId)
            .maybeSingle();

        final restaurantId = restaurant?['id']?.toString();
        if (restaurantId != null && restaurantId.isNotEmpty) {
          ids.add(restaurantId);
        }
      }
    } catch (e) {
      print('⚠️ Could not resolve restaurant ID: $e');
    }

    print('📌 Restaurant IDs for business: $ids');
    return ids.toList();
  }

  Future<List<Map<String, dynamic>>> getPickupRequests(
    String businessId, {
    String? status,
  }) async {
    try {
      final restaurantIds = await _getRestaurantIdsForBusiness(businessId);
      if (restaurantIds.isEmpty) return <Map<String, dynamic>>[];

      var query = _supabase.client.from('offer_requests').select('''
            *,
            food_offers:offer_id (
              id,
              title,
              image,
              quantity,
              status
            ),
            users:user_id (
              id,
              name,
              phone,
              email,
              avatar_url
            )
          ''').inFilter('restaurant_id', restaurantIds);

      if (status != null && status.isNotEmpty && status != 'all') {
        query = query.eq('status', status);
      }

      final response = await query.order('requested_at', ascending: false);
      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      print('❌ Error getting pickup requests: $e');
      return <Map<String, dynamic>>[];
    }
  }

  // قبول أو رفض طلب الحجز.
  // accepted: الطلب مقبول والعرض يصبح reserved.
  // rejected: الطلب يصبح cancelled والعرض يعود available.
  Future<bool> respondToRequest({
    required String requestId,
    required String businessId,
    required bool accept,
  }) async {
    try {
      final restaurantIds = await _getRestaurantIdsForBusiness(businessId);
      if (restaurantIds.isEmpty) {
        print('❌ No restaurant IDs found');
        return false;
      }

      final request = await _supabase.client
          .from('offer_requests')
          .select('id, user_id, offer_id, status')
          .eq('id', requestId)
          .inFilter('restaurant_id', restaurantIds)
          .maybeSingle();

      if (request == null) {
        print('❌ Request not found for this business');
        return false;
      }

      final currentStatus = request['status']?.toString() ?? '';
      if (currentStatus != 'pending') {
        print('⚠️ Request already processed: $currentStatus');
        return false;
      }

      final newRequestStatus = accept ? 'accepted' : 'cancelled';
      final newOfferStatus = accept ? 'reserved' : 'available';

      final updatedRequest = await _supabase.client
          .from('offer_requests')
          .update({
            'status': newRequestStatus,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', requestId)
          .inFilter('restaurant_id', restaurantIds)
          .eq('status', 'pending')
          .select('id, user_id, offer_id, status')
          .maybeSingle();

      if (updatedRequest == null) {
        print('❌ Request was not updated');
        return false;
      }

      try {
        await _supabase.client.from('food_offers').update({
          'status': newOfferStatus,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', request['offer_id']);
      } catch (e) {
        print('⚠️ Offer status update failed: $e');
      }

      try {
        await _supabase.client.rpc(
          'notify_booking_response',
          params: {
            'p_request_id': requestId,
            'p_status': newRequestStatus,
          },
        );
      } catch (e) {
        print('⚠️ Notification failed but request was updated: $e');
      }

      return true;
    } catch (e) {
      print('❌ Error responding to request: $e');
      return false;
    }
  }

  Future<bool> markReadyForPickup({
    required String requestId,
    required String businessId,
  }) async {
    try {
      final restaurantIds = await _getRestaurantIdsForBusiness(businessId);
      if (restaurantIds.isEmpty) return false;

      final request = await _supabase.client
          .from('offer_requests')
          .select('id, user_id, offer_id, status')
          .eq('id', requestId)
          .inFilter('restaurant_id', restaurantIds)
          .maybeSingle();

      if (request == null || request['status']?.toString() != 'accepted') {
        print('⚠️ Only accepted requests can be marked ready');
        return false;
      }

      final expiresAt = DateTime.now().add(const Duration(hours: 24));

      final updated = await _supabase.client
          .from('offer_requests')
          .update({
            'status': 'ready_for_pickup',
            'pickup_token_expires_at': expiresAt.toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', requestId)
          .inFilter('restaurant_id', restaurantIds)
          .eq('status', 'accepted')
          .select('id, user_id, offer_id')
          .maybeSingle();

      if (updated == null) return false;

      // إنشاء رمز الاستلام إن كانت دالة RPC موجودة.
      try {
        await _supabase.client.rpc(
          'generate_pickup_token',
          params: {
            'p_request_id': requestId,
            'p_user_id': request['user_id'],
            'p_restaurant_id': restaurantIds.first,
          },
        );
      } catch (e) {
        print('⚠️ Pickup token generation failed: $e');
      }

      try {
        await _supabase.client.rpc(
          'notify_booking_response',
          params: {
            'p_request_id': requestId,
            'p_status': 'ready_for_pickup',
          },
        );
      } catch (e) {
        print('⚠️ Ready notification failed: $e');
      }

      return true;
    } catch (e) {
      print('❌ Error marking request ready: $e');
      return false;
    }
  }

  Future<bool> confirmPickup({
    required String requestId,
    required String businessId,
  }) async {
    try {
      final restaurantIds = await _getRestaurantIdsForBusiness(businessId);
      if (restaurantIds.isEmpty) return false;

      final response = await _supabase.client
          .from('offer_requests')
          .update({
            'status': 'completed',
            'completed_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', requestId)
          .inFilter('restaurant_id', restaurantIds)
          .eq('status', 'ready_for_pickup')
          .select('id, user_id, offer_id')
          .maybeSingle();

      if (response == null) return false;

      try {
        await _supabase.client.rpc(
          'notify_booking_response',
          params: {
            'p_request_id': requestId,
            'p_status': 'completed',
          },
        );
      } catch (e) {
        print('⚠️ Completion notification failed: $e');
      }

      return true;
    } catch (e) {
      print('❌ Error confirming pickup: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>> getBusinessStats(String businessId) async {
    try {
      final restaurantIds = await _getRestaurantIdsForBusiness(businessId);

      if (restaurantIds.isEmpty) {
        print('⚠️ No restaurant IDs found for stats');
        return _emptyStats();
      }

      final now = DateTime.now();
      final startOfToday = DateTime(now.year, now.month, now.day);
      final startOfTomorrow = startOfToday.add(const Duration(days: 1));

      final allRequests = await _supabase.client
          .from('offer_requests')
          .select('id, status, requested_at')
          .inFilter('restaurant_id', restaurantIds);

      final todayRequests = await _supabase.client
          .from('offer_requests')
          .select('id, status, requested_at')
          .inFilter('restaurant_id', restaurantIds)
          .gte('requested_at', startOfToday.toUtc().toIso8601String())
          .lt('requested_at', startOfTomorrow.toUtc().toIso8601String());

      final all = (allRequests as List).cast<Map<String, dynamic>>();
      final today = (todayRequests as List).cast<Map<String, dynamic>>();

      final pendingRequests =
          all.where((request) => request['status'] == 'pending').length;
      final readyPickups = all
          .where((request) => request['status'] == 'ready_for_pickup')
          .length;
      final completed =
          all.where((request) => request['status'] == 'completed').length;

      final business = await getBusinessById(businessId);

      final stats = <String, dynamic>{
        // هذه هي المفاتيح التي تستخدمها BusinessDashboardPage.
        'pendingRequests': pendingRequests,
        'pendingPickups': readyPickups,
        'todayPickups': today.length,
        'totalPickups': all.length,
        'completedCount': completed,
        'points': business?.points ?? 0,
      };

      print('✅ Business stats: $stats');
      return stats;
    } catch (e) {
      print('❌ Error getting business stats: $e');
      return _emptyStats();
    }
  }

  Map<String, dynamic> _emptyStats() {
    return {
      'pendingRequests': 0,
      'pendingPickups': 0,
      'todayPickups': 0,
      'totalPickups': 0,
      'completedCount': 0,
      'points': 0,
    };
  }
}
