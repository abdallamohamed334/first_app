import 'package:equatable/equatable.dart';
import '../../../offers/domain/entities/food_offer.dart';

abstract class MapState extends Equatable {
  const MapState();
  @override
  List<Object?> get props => [];
}

class MapInitial extends MapState {
  const MapInitial();
}

class MapLoading extends MapState {
  const MapLoading();
}

class MapLoaded extends MapState {
  final List<FoodOffer> allOffers;
  final List<FoodOffer> filteredOffers;
  final FoodOffer? selectedOffer;
  final String selectedFilter;
  final double radius; // ✅ غيّر من int لـ double
  final double? userLatitude;
  final double? userLongitude;

  const MapLoaded({
    required this.allOffers,
    required this.filteredOffers,
    this.selectedOffer,
    this.selectedFilter = 'كل الوجبات',
    this.radius = 5.0, // ✅ 5.0 بدل 5
    this.userLatitude,
    this.userLongitude,
  });

  List<FoodOffer> get offers => allOffers;

  MapLoaded copyWith({
    List<FoodOffer>? allOffers,
    List<FoodOffer>? filteredOffers,
    FoodOffer? selectedOffer,
    String? selectedFilter,
    double? radius, // ✅ double
    double? userLatitude,
    double? userLongitude,
  }) {
    return MapLoaded(
      allOffers: allOffers ?? this.allOffers,
      filteredOffers: filteredOffers ?? this.filteredOffers,
      selectedOffer: selectedOffer ?? this.selectedOffer,
      selectedFilter: selectedFilter ?? this.selectedFilter,
      radius: radius ?? this.radius,
      userLatitude: userLatitude ?? this.userLatitude,
      userLongitude: userLongitude ?? this.userLongitude,
    );
  }

  @override
  List<Object?> get props => [
        allOffers,
        filteredOffers,
        selectedOffer,
        selectedFilter,
        radius,
        userLatitude,
        userLongitude,
      ];
}

class MapError extends MapState {
  final String message;
  const MapError(this.message);
  @override
  List<Object?> get props => [message];
}
