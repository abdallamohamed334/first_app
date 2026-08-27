import 'package:flutter/foundation.dart';

import 'package:loqma/core/services/supabase_service.dart';
import 'package:loqma/features/booking/domain/entities/booking.dart';

class BookingRepository {
  final SupabaseService _supabase;

  BookingRepository(this._supabase);

  static const String _bookingSelect = '''
    *,
    food_offers:offer_id (
      id, title, image, quantity, description, pickup_location, expiry_time, status
    ),
    restaurants:restaurant_id (
      id, name, logo, address, phone
    )
  ''';

  Future<List<Booking>> getMyBookings(String userId) async {
    final cleanUserId = userId.trim();
    if (cleanUserId.isEmpty) return const <Booking>[];

    try {
      await _expireOverdueBookings();
      final response = await _supabase.client
          .from('offer_requests')
          .select(_bookingSelect)
          .eq('user_id', cleanUserId)
          .order('requested_at', ascending: false);

      if (response is! List) return const <Booking>[];
      return response
          .whereType<Map>()
          .map((row) => Booking.fromJson(Map<String, dynamic>.from(row)))
          .toList();
    } catch (error) {
      _log('LOAD BOOKINGS', error);
      return const <Booking>[];
    }
  }

  Future<Booking?> getBookingById(String bookingId) async {
    final cleanId = bookingId.trim();
    if (cleanId.isEmpty) return null;

    try {
      final response = await _supabase.client
          .from('offer_requests')
          .select(_bookingSelect)
          .eq('id', cleanId)
          .maybeSingle();
      if (response == null) return null;
      return Booking.fromJson(Map<String, dynamic>.from(response));
    } catch (error) {
      _log('LOAD BOOKING', error);
      return null;
    }
  }

  Future<String?> resolveRestaurantId({
    String? restaurantId,
    String? businessId,
    String? offerId,
  }) async {
    try {
      final direct = _clean(restaurantId);
      if (direct != null) {
        final byId = await _supabase.client
            .from('restaurants')
            .select('id')
            .eq('id', direct)
            .maybeSingle();
        if (byId != null) return _clean(byId['id']);

        final byUser = await _supabase.client
            .from('restaurants')
            .select('id')
            .eq('user_id', direct)
            .maybeSingle();
        if (byUser != null) return _clean(byUser['id']);

        final business = await _supabase.client
            .from('businesses')
            .select('user_id')
            .eq('id', direct)
            .maybeSingle();
        final ownerId = _clean(business?['user_id']);
        if (ownerId != null) return _restaurantForUser(ownerId);
      }

      final business = _clean(businessId);
      if (business != null) {
        final businessRow = await _supabase.client
            .from('businesses')
            .select('user_id')
            .eq('id', business)
            .maybeSingle();
        final ownerId = _clean(businessRow?['user_id']);
        if (ownerId != null) return _restaurantForUser(ownerId);
      }

      final offer = _clean(offerId);
      if (offer != null) {
        final offerRow = await _supabase.client
            .from('food_offers')
            .select('business_id, restaurant_id')
            .eq('id', offer)
            .maybeSingle();
        final offerRestaurant = _clean(offerRow?['restaurant_id']);
        if (offerRestaurant != null) {
          final row = await _supabase.client
              .from('restaurants')
              .select('id')
              .eq('id', offerRestaurant)
              .maybeSingle();
          if (row != null) return _clean(row['id']);
        }
        final offerBusiness = _clean(offerRow?['business_id']);
        if (offerBusiness != null) {
          final businessRow = await _supabase.client
              .from('businesses')
              .select('user_id')
              .eq('id', offerBusiness)
              .maybeSingle();
          final ownerId = _clean(businessRow?['user_id']);
          if (ownerId != null) return _restaurantForUser(ownerId);
        }
      }
    } catch (error) {
      _log('RESOLVE RESTAURANT', error);
    }
    return null;
  }

  Future<String?> _restaurantForUser(String userId) async {
    final row = await _supabase.client
        .from('restaurants')
        .select('id')
        .eq('user_id', userId)
        .maybeSingle();
    return _clean(row?['id']);
  }

  Future<Booking?> createBooking({
    required String offerId,
    required String userId,
    String? restaurantId,
    String? businessId,
  }) async {
    final cleanOffer = offerId.trim();
    final cleanUser = userId.trim();
    if (cleanOffer.isEmpty || cleanUser.isEmpty) return null;

    try {
      final actualRestaurantId = await resolveRestaurantId(
        restaurantId: restaurantId,
        businessId: businessId,
        offerId: cleanOffer,
      );
      if (actualRestaurantId == null) return null;

      final rawResult = await _supabase.client.rpc(
        'create_food_offer_request',
        params: {
          'p_offer_id': cleanOffer,
          'p_restaurant_id': actualRestaurantId,
        },
      );
      final result = rawResult is List ? rawResult.first : rawResult;
      final requestId = result is Map ? result['id']?.toString() : null;
      if (requestId == null || requestId.isEmpty) return null;

      final response = await _supabase.client
          .from('offer_requests')
          .select(_bookingSelect)
          .eq('id', requestId)
          .single();

      final booking = Booking.fromJson(Map<String, dynamic>.from(response));
      await _notifyFoodOfferOwner(
        offerId: cleanOffer,
        bookingId: booking.id,
        requesterId: cleanUser,
      );
      return booking;
    } catch (error) {
      _log('CREATE BOOKING', error);
      return null;
    }
  }

  Future<String?> generatePickupToken({
    required String bookingId,
    required String userId,
    String? restaurantId,
    String? businessId,
  }) async {
    final cleanBooking = bookingId.trim();
    final cleanUser = userId.trim();
    final actualRestaurantId = await resolveRestaurantId(
      restaurantId: restaurantId,
      businessId: businessId,
    );
    if (cleanBooking.isEmpty ||
        cleanUser.isEmpty ||
        actualRestaurantId == null) {
      return null;
    }

    try {
      final response = await _supabase.client.rpc(
        'generate_pickup_token',
        params: {
          'p_request_id': cleanBooking,
          'p_user_id': cleanUser,
          'p_restaurant_id': actualRestaurantId,
        },
      );
      return _tokenFromResponse(response);
    } catch (error) {
      _log('GENERATE PICKUP TOKEN', error);
      return null;
    }
  }

  Future<Map<String, dynamic>> verifyPickupToken({
    required String token,
    required String restaurantId,
    String? businessId,
  }) async {
    final actualRestaurantId = await resolveRestaurantId(
      restaurantId: restaurantId,
      businessId: businessId,
    );
    if (token.trim().isEmpty || actualRestaurantId == null) {
      return _failure('بيانات رمز الاستلام غير مكتملة');
    }

    try {
      final response = await _supabase.client.rpc(
        'complete_pickup_by_qr',
        params: {
          'p_token': token.trim(),
          'p_restaurant_id': actualRestaurantId,
        },
      );
      final data = _asMap(response);
      if (data == null) return _failure('تعذر التحقق من رمز الاستلام');
      return {
        'success': data['success'] == true,
        'requestId': _clean(data['request_id']),
        'userId': _clean(data['user_id']),
        'offerId': _clean(data['offer_id']),
        'businessId': _clean(data['business_id']),
        'pointsEarned': _asInt(data['points_earned']),
        'message': _clean(data['message']) ?? 'تعذر التحقق من رمز الاستلام',
      };
    } catch (error) {
      _log('VERIFY PICKUP TOKEN', error);
      return _failure('تعذر التحقق من رمز الاستلام حاليًا');
    }
  }

  Future<Map<String, dynamic>> completePickupByQr({
    required String token,
    required String restaurantId,
    String? businessId,
  }) =>
      verifyPickupToken(
        token: token,
        restaurantId: restaurantId,
        businessId: businessId,
      );

  Future<bool> cancelBooking(String bookingId, {String? userId}) async {
    final requestId = bookingId.trim();
    final currentUserId =
        (userId ?? _supabase.client.auth.currentUser?.id ?? '').trim();
    if (requestId.isEmpty || currentUserId.isEmpty) return false;

    try {
      final response = await _supabase.client.rpc(
        'update_food_offer_request_status',
        params: {
          'p_request_id': requestId,
          'p_next_status': 'cancelled',
        },
      );
      final data = _asMap(response);
      return data?['success'] == true && data?['status'] == 'cancelled';
    } catch (error) {
      _log('CANCEL BOOKING', error);
      return false;
    }
  }

  Future<void> _expireOverdueBookings() async {
    try {
      await _supabase.client.rpc('expire_overdue_food_offers');
    } catch (error) {
      _log('EXPIRE BOOKINGS', error);
    }
  }

  Future<void> _notifyFoodOfferOwner({
    required String offerId,
    required String bookingId,
    required String requesterId,
  }) async {
    try {
      final offer = await _supabase.client
          .from('food_offers')
          .select('title, business_id, businesses:business_id(user_id)')
          .eq('id', offerId)
          .maybeSingle();
      final business = _asMap(offer?['businesses']);
      final ownerId = _clean(business?['user_id']);
      if (ownerId == null || ownerId == requesterId) return;

      await _supabase.client.functions.invoke(
        'send-notification',
        body: {
          'userId': ownerId,
          'title': 'حجز جديد على عرضك',
          'body': 'تم تسجيل حجز جديد على أحد عروضك.',
          'data': {
            'type': 'food_booking_created',
            'booking_id': bookingId,
            'offer_id': offerId,
          },
        },
      );
    } catch (error) {
      _log('BOOKING NOTIFICATION', error);
    }
  }

  static Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    if (value is List && value.isNotEmpty) return _asMap(value.first);
    return null;
  }

  static String? _tokenFromResponse(dynamic value) {
    final map = _asMap(value);
    final mapToken = _clean(map?['token'] ?? map?['pickup_token']);
    if (mapToken != null) return mapToken;
    final direct = _clean(value);
    return direct == null || direct == 'null' ? null : direct;
  }

  static String? _clean(dynamic value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(_clean(value) ?? '') ?? 0;
  }

  static Map<String, dynamic> _failure(String message) => {
        'success': false,
        'message': message,
      };

  void _log(String operation, Object error) {
    if (kDebugMode) debugPrint('$operation failed: ${error.runtimeType}');
  }
}
