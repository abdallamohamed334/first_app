// lib/features/map/data/repositories/map_repository_impl.dart

import 'package:loqma/features/map/data/repositories/map_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../offers/domain/entities/food_offer.dart';
import '../../../../core/services/location_service.dart';

class MapRepositoryImpl implements MapRepository {
  final SupabaseClient _client;

  MapRepositoryImpl({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  @override
  Future<List<FoodOffer>> getNearbyOffers({
    required double latitude,
    required double longitude,
    int radiusMeters = LocationService.defaultRadiusMeters,
  }) async {
    print('📍 [MapRepository] getNearbyOffers called');
    print(
        '📍 [MapRepository] latitude: $latitude, longitude: $longitude, radius: $radiusMeters');

    try {
      final response = await _client.rpc(
        'get_nearby_institution_offers',
        params: {
          'p_latitude': latitude,
          'p_longitude': longitude,
          'p_radius_meters': radiusMeters,
        },
      );

      print(
          '📍 [MapRepository] Response received, type: ${response.runtimeType}');

      if (response is! List) {
        print('📍 [MapRepository] Response is not a List');
        return [];
      }

      final offers = <FoodOffer>[];
      for (final item in response) {
        if (item is! Map) continue;
        try {
          offers.add(FoodOffer.fromJson(Map<String, dynamic>.from(item)));
        } catch (e) {
          print('⚠️ MapRepositoryImpl: failed to parse offer: $e');
        }
      }

      print('📍 [MapRepository] Parsed ${offers.length} offers');
      return offers;
    } catch (e) {
      print('📍 [MapRepository] Error: $e');
      throw Exception('تعذر جلب العروض القريبة: $e');
    }
  }

  // ✅ إضافة دالة جديدة لجلب كل العروض مع المسافة
  @override
  Future<List<FoodOffer>> getAllOffers({
    required double latitude,
    required double longitude,
    int limit = 50,
    int offset = 0,
  }) async {
    print('📍 [MapRepository] getAllOffers called');
    print(
        '📍 [MapRepository] latitude: $latitude, longitude: $longitude, limit: $limit, offset: $offset');

    try {
      final response = await _client.rpc(
        'get_all_institution_offers',
        params: {
          'p_latitude': latitude,
          'p_longitude': longitude,
          'p_limit': limit,
          'p_offset': offset,
        },
      );

      print(
          '📍 [MapRepository] getAllOffers response received, type: ${response.runtimeType}');

      if (response is! List) {
        print('📍 [MapRepository] Response is not a List');
        return [];
      }

      final offers = <FoodOffer>[];
      for (final item in response) {
        if (item is! Map) continue;
        try {
          offers.add(FoodOffer.fromJson(Map<String, dynamic>.from(item)));
        } catch (e) {
          print('⚠️ MapRepositoryImpl: failed to parse offer: $e');
        }
      }

      print('📍 [MapRepository] getAllOffers parsed ${offers.length} offers');
      return offers;
    } catch (e) {
      print('📍 [MapRepository] getAllOffers Error: $e');
      throw Exception('تعذر جلب كل العروض: $e');
    }
  }
}
