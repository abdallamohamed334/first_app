import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:loqma/core/services/supabase_service.dart';

class BusinessOperationsRepository {
  final SupabaseClient _client;

  BusinessOperationsRepository({SupabaseClient? client})
      : _client = client ?? SupabaseService().client;

  Future<List<Map<String, dynamic>>> listMyOffers() async {
    final rows = await _client.rpc('restaurant_list_my_offers');
    return _maps(rows);
  }

  Future<List<Map<String, dynamic>>> listMyRequests() async {
    final rows = await _client.rpc('restaurant_list_my_offer_requests');
    return _maps(rows);
  }

  Future<Map<String, dynamic>> getCurrentBusinessProfile() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      throw const FormatException('جلسة المؤسسة غير صالحة');
    }
    final row = await _client
        .from('businesses')
        .select(
            'id, user_id, name, owner_name, phone, email, address, city, description, status, is_verified, capabilities')
        .eq('user_id', userId)
        .maybeSingle();
    if (row == null) {
      throw const FormatException('لم يتم العثور على بيانات المؤسسة');
    }
    return Map<String, dynamic>.from(row);
  }

  Future<Map<String, dynamic>> createFoodOffer({
    required String title,
    required String description,
    required int quantity,
    required String foodType,
    required DateTime expiryTime,
    required DateTime pickupBefore,
    required double salePrice,
    double? originalPrice,
    String? pickupLocation,
    String? image,
  }) async {
    final result = await _client.rpc(
      'restaurant_create_food_offer_authorized',
      params: {
        'p_title': title.trim(),
        'p_description': description.trim(),
        'p_quantity': quantity,
        'p_food_type': foodType.trim(),
        'p_expiry_time': expiryTime.toUtc().toIso8601String(),
        'p_pickup_before': pickupBefore.toUtc().toIso8601String(),
        'p_sale_price': salePrice,
        'p_original_price': originalPrice,
        'p_pickup_location': pickupLocation?.trim(),
        'p_image': image?.trim(),
      },
    );
    return _map(result);
  }

  Future<Map<String, dynamic>> setOfferPaused({
    required String offerId,
    required bool paused,
    String? reason,
  }) async {
    final result = await _client.rpc(
      'restaurant_pause_offer_authorized',
      params: {
        'p_offer_id': offerId,
        'p_paused': paused,
        'p_reason': reason?.trim(),
      },
    );
    return _map(result);
  }

  Future<Map<String, dynamic>> verifyPickupCode(String code) async {
    final result = await _client.rpc(
      'restaurant_verify_pickup_code_authorized',
      params: {'p_token': code.trim()},
    );
    return _map(result);
  }

  Future<List<Map<String, dynamic>>> listActiveCharities() async {
    final rows = await _client
        .from('charities')
        .select('id, name, logo, address, description, is_verified')
        .eq('status', 'active')
        .eq('is_verified', true)
        .order('name');
    return _maps(rows);
  }

  Future<Map<String, dynamic>> createCharityDonation({
    required String charityId,
    required String itemTitle,
    required String description,
    required int quantity,
    required String condition,
    List<String> images = const [],
  }) async {
    final result = await _client.rpc(
      'restaurant_create_charity_donation_authorized',
      params: {
        'p_charity_id': charityId,
        'p_item_title': itemTitle.trim(),
        'p_description': description.trim(),
        'p_quantity': quantity,
        'p_item_condition': condition.trim(),
        'p_images': images,
      },
    );
    return _map(result);
  }

  static List<Map<String, dynamic>> _maps(dynamic value) {
    if (value is! List) return const <Map<String, dynamic>>[];
    return value
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  static Map<String, dynamic> _map(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    throw const FormatException('استجابة غير صالحة من الخادم');
  }
}
