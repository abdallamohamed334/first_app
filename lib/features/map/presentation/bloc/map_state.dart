// lib/features/map/presentation/bloc/map_state.dart

import 'package:equatable/equatable.dart';
import '../../../offers/domain/entities/food_offer.dart';

enum MapStatus {
  initial,
  loadingLocation,
  locationLoaded,
  loadingOffers,
  offersLoaded,
  error,
  permissionDenied,
  permissionDeniedForever,
  locationServiceDisabled,
}

class MapState extends Equatable {
  final MapStatus status;
  final double? userLatitude;
  final double? userLongitude;
  final List<FoodOffer> offers;
  final List<FoodOffer> filteredOffers;
  final FoodOffer? selectedOffer;
  final String? selectedFilter;
  final int radius;
  final String? errorMessage;
  final bool isLoading;

  const MapState({
    this.status = MapStatus.initial,
    this.userLatitude,
    this.userLongitude,
    this.offers = const [],
    this.filteredOffers = const [],
    this.selectedOffer,
    this.selectedFilter,
    this.radius = 3000,
    this.errorMessage,
    this.isLoading = false,
  });

  MapState copyWith({
    MapStatus? status,
    double? userLatitude,
    double? userLongitude,
    List<FoodOffer>? offers,
    List<FoodOffer>? filteredOffers,
    FoodOffer? selectedOffer,
    String? selectedFilter,
    int? radius,
    String? errorMessage,
    bool? isLoading,
  }) {
    return MapState(
      status: status ?? this.status,
      userLatitude: userLatitude ?? this.userLatitude,
      userLongitude: userLongitude ?? this.userLongitude,
      offers: offers ?? this.offers,
      filteredOffers: filteredOffers ?? this.filteredOffers,
      selectedOffer: selectedOffer ?? this.selectedOffer,
      selectedFilter: selectedFilter ?? this.selectedFilter,
      radius: radius ?? this.radius,
      errorMessage: errorMessage ?? this.errorMessage,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  @override
  List<Object?> get props => [
        status,
        userLatitude,
        userLongitude,
        offers,
        filteredOffers,
        selectedOffer,
        selectedFilter,
        radius,
        errorMessage,
        isLoading,
      ];
}
