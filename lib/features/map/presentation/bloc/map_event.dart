// lib/features/map/presentation/bloc/map_event.dart

import 'package:equatable/equatable.dart';
import '../../../offers/domain/entities/food_offer.dart';

abstract class MapEvent extends Equatable {
  const MapEvent();

  @override
  List<Object?> get props => [];
}

class MapStarted extends MapEvent {}

class MapLocationUpdated extends MapEvent {
  final double latitude;
  final double longitude;

  const MapLocationUpdated({
    required this.latitude,
    required this.longitude,
  });

  @override
  List<Object?> get props => [latitude, longitude];
}

class MapLocationError extends MapEvent {
  final String message;

  const MapLocationError(this.message);

  @override
  List<Object?> get props => [message];
}

class MapOffersLoaded extends MapEvent {
  final List<FoodOffer> offers;

  const MapOffersLoaded(this.offers);

  @override
  List<Object?> get props => [offers];
}

class MapOffersError extends MapEvent {
  final String message;

  const MapOffersError(this.message);

  @override
  List<Object?> get props => [message];
}

class SelectOffer extends MapEvent {
  final FoodOffer offer;

  const SelectOffer(this.offer);

  @override
  List<Object?> get props => [offer];
}

class ClearSelectedOffer extends MapEvent {}

class FilterOffers extends MapEvent {
  final String filter;

  const FilterOffers(this.filter);

  @override
  List<Object?> get props => [filter];
}

class ChangeRadius extends MapEvent {
  final int radius;

  const ChangeRadius(this.radius);

  @override
  List<Object?> get props => [radius];
}

class SearchLocation extends MapEvent {
  final String query;

  const SearchLocation(this.query);

  @override
  List<Object?> get props => [query];
}

class GoToMyLocation extends MapEvent {}

class RefreshOffers extends MapEvent {}

class PermissionDenied extends MapEvent {}

class PermissionDeniedForever extends MapEvent {}

class LocationServiceDisabled extends MapEvent {}
