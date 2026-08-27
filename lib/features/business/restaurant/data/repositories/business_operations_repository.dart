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

    final identity = await _client
        .from('users')
        .select('user_type')
        .eq('id', userId)
        .maybeSingle();
    final type = identity?['user_type']?.toString().trim().toLowerCase();
    const institutionTypes = {
      'restaurant',
      'business',
      'hotel',
      'supermarket',
      'bakery',
      'cafe',
    };
    if (type == null || !institutionTypes.contains(type)) {
      throw const FormatException('هذا الحساب ليس حساب مؤسسة');
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
      'restaurant_create_food_offer',
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
      'set_food_offer_paused',
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
      'restaurant_verify_pickup_code',
      params: {'p_token': code.trim()},
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
