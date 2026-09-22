import '../../../../core/services/location_service.dart';
import '../../../offers/domain/entities/food_offer.dart';

abstract class MapRepository {
  Future<List<FoodOffer>> getNearbyOffers({
    required double latitude,
    required double longitude,
    int radiusMeters = LocationService.defaultRadiusMeters,
  });

  Future<List<FoodOffer>> getAllOffers({
    required double latitude,
    required double longitude,
    int limit = 50,
    int offset = 0,
  });
}
