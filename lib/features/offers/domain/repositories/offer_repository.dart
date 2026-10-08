import 'package:dartz/dartz.dart';
import 'package:loqma/core/errors/failures.dart';
import '../entities/food_offer.dart';

abstract class OfferRepository {
  Future<Either<Failure, List<FoodOffer>>> getAvailableOffers();
  Future<Either<Failure, List<FoodOffer>>> getOffersByRestaurant(
      String restaurantId);
  Future<Either<Failure, FoodOffer>> getOfferById(String id);
  Future<Either<Failure, FoodOffer>> createOffer(FoodOffer offer);
  Future<Either<Failure, FoodOffer>> updateOffer(FoodOffer offer);
  Future<Either<Failure, void>> deleteOffer(String id);
  Future<Either<Failure, FoodOffer>> reserveOffer(String id, String charityId);
  Future<Either<Failure, FoodOffer>> completeOffer(String id);
}
