// lib/features/map/presentation/cubit/map_state.dart

import 'package:equatable/equatable.dart';
import 'package:latlong2/latlong.dart';
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
  final LatLng? userLocation;
  final List<FoodOffer> nearbyOffers;
  final String? errorMessage;
  final bool isLoading;

  const MapState({
    this.status = MapStatus.initial,
    this.userLocation,
    this.nearbyOffers = const [],
    this.errorMessage,
    this.isLoading = false,
  });

  MapState copyWith({
    MapStatus? status,
    LatLng? userLocation,
    List<FoodOffer>? nearbyOffers,
    String? errorMessage,
    bool? isLoading,
  }) {
    return MapState(
      status: status ?? this.status,
      userLocation: userLocation ?? this.userLocation,
      nearbyOffers: nearbyOffers ?? this.nearbyOffers,
      errorMessage: errorMessage ?? this.errorMessage,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  @override
  List<Object?> get props => [
        status,
        userLocation,
        nearbyOffers,
        errorMessage,
        isLoading,
      ];
}
