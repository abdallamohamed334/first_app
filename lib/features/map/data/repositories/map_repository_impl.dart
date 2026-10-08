// lib/features/map/data/repositories/map_repository_impl.dart

import 'dart:math' as math;

import 'package:wasla/features/map/data/repositories/map_repository.dart';
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
      if (_isMissingSridError(e)) {
        print('📍 [MapRepository] Missing SRID 4326; using Haversine fallback.');
        return _getOffersWithoutPostgis(
          latitude: latitude,
          longitude: longitude,
          radiusMeters: radiusMeters,
          nearbyOnly: true,
        );
      }
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
      if (_isMissingSridError(e)) {
        print(
          '📍 [MapRepository] Missing SRID 4326; using Haversine fallback.',
        );
        return _getOffersWithoutPostgis(
          latitude: latitude,
          longitude: longitude,
          limit: limit,
          offset: offset,
        );
      }
      print('📍 [MapRepository] getAllOffers Error: $e');
      throw Exception('تعذر جلب كل العروض: $e');
    }
  }

  bool _isMissingSridError(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('cannot find srid') && message.contains('4326');
  }

  Future<List<FoodOffer>> _getOffersWithoutPostgis({
    required double latitude,
    required double longitude,
    int radiusMeters = LocationService.defaultRadiusMeters,
    int limit = 50,
    int offset = 0,
    bool nearbyOnly = false,
  }) async {
    try {
      final now = DateTime.now().toUtc();
      final rows = await _client
          .from('institution_offers')
          .select('''
            *,
            institutions:institution_id (
              id,
              name,
              institution_type,
              logo_url,
              address,
              phone,
              latitude,
              longitude
            )
          ''')
          .eq('status', 'active')
          .gt('remaining_quantity', 0)
          .gt('expires_at', now.toIso8601String())
          .filter('deleted_at', 'is', 'null')
          .order('created_at', ascending: false)
          .limit(1000);

      final candidates = <FoodOffer>[];
      for (final raw in rows) {
        if (raw is! Map) continue;
        final item = Map<String, dynamic>.from(raw);
        final institutionRaw = item['institutions'];
        if (institutionRaw is! Map) continue;
        final institution = Map<String, dynamic>.from(institutionRaw);
        final offerLatitude = _asDouble(institution['latitude']);
        final offerLongitude = _asDouble(institution['longitude']);
        if (offerLatitude == null || offerLongitude == null) continue;

        final distance = _distanceMeters(
          latitude,
          longitude,
          offerLatitude,
          offerLongitude,
        );
        if (nearbyOnly && distance > radiusMeters) continue;

        final expiresAt = item['expires_at']?.toString() ??
            now.add(const Duration(days: 1)).toIso8601String();
        final institutionId = item['institution_id']?.toString() ??
            institution['id']?.toString();
        final imageList = _asImages(item['images']);
        final institutionType =
            institution['institution_type']?.toString() ?? 'institution';
        final business = <String, dynamic>{
          'id': institutionId,
          'name': institution['name']?.toString() ?? 'مؤسسة',
          'business_type': institutionType,
          'institution_type': institutionType,
          'logo_url': institution['logo_url'],
          'address': institution['address'],
          'phone': institution['phone'],
          'latitude': offerLatitude,
          'longitude': offerLongitude,
        };
        final normalized = <String, dynamic>{
          'id': item['id']?.toString() ?? '',
          'title': item['title']?.toString() ?? 'عرض',
          'description': item['description']?.toString() ?? '',
          'quantity': _asInt(item['remaining_quantity']) ??
              _asInt(item['quantity']) ??
              0,
          'food_type': item['food_type']?.toString() ??
              item['category']?.toString() ??
              'مواد غذائية',
          'expiry_time': expiresAt,
          'pickup_before': item['pickup_before']?.toString() ?? expiresAt,
          'pickup_location': item['pickup_location']?.toString() ?? '',
          'latitude': offerLatitude,
          'longitude': offerLongitude,
          'image': imageList.isEmpty ? null : imageList.first,
          'images': imageList,
          'status': 'available',
          'business_id': institutionId,
          'created_at': item['created_at']?.toString(),
          'updated_at': item['updated_at']?.toString(),
          'businesses': business,
          'requires_refrigeration': item['requires_refrigeration'] ?? false,
          'is_halal': item['is_halal'] ?? true,
          'is_vegetarian': item['is_vegetarian'] ?? false,
          'pickup_notes': item['pickup_notes'],
          'contact_phone': item['contact_phone'] ?? institution['phone'],
          'sale_price': item['symbolic_price'],
          'original_price': item['original_price'],
          'source': 'institution',
          'details': item,
          'distance_meters': distance,
        };
        candidates.add(FoodOffer.fromJson(normalized));
      }

      candidates.sort((a, b) => (a.distanceMeters ?? double.infinity)
          .compareTo(b.distanceMeters ?? double.infinity));
      final safeOffset = math.max(0, offset);
      final safeLimit = math.max(0, limit);
      if (safeOffset >= candidates.length || safeLimit == 0) {
        return const <FoodOffer>[];
      }
      final end = math.min(safeOffset + safeLimit, candidates.length);
      return candidates.sublist(safeOffset, end);
    } catch (error) {
      print('📍 [MapRepository] Haversine fallback failed: $error');
      throw Exception('تعذر جلب العروض بدون PostGIS: $error');
    }
  }

  double? _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  List<String> _asImages(dynamic value) {
    if (value is List) {
      return value
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
    }
    if (value is String && value.trim().isNotEmpty) {
      return [value.trim()];
    }
    return const <String>[];
  }

  double _distanceMeters(
    double latitude1,
    double longitude1,
    double latitude2,
    double longitude2,
  ) {
    const earthRadiusMeters = 6371000.0;
    final deltaLatitude = _radians(latitude2 - latitude1);
    final deltaLongitude = _radians(longitude2 - longitude1);
    final a = math.pow(math.sin(deltaLatitude / 2), 2) +
        math.cos(_radians(latitude1)) *
            math.cos(_radians(latitude2)) *
            math.pow(math.sin(deltaLongitude / 2), 2);
    return earthRadiusMeters * 2 * math.asin(math.sqrt(a.clamp(0.0, 1.0)));
  }

  double _radians(double degrees) => degrees * math.pi / 180;
}
