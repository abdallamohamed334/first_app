import 'package:equatable/equatable.dart';
import '../../../offers/domain/entities/food_offer.dart';

abstract class MapEvent extends Equatable {
  const MapEvent();

  @override
  List<Object?> get props => [];
}

class MapStarted extends MapEvent {
  const MapStarted();
}

class SelectOffer extends MapEvent {
  final FoodOffer? offer; // ✅ nullable عشان نقدر نعمل clear
  const SelectOffer(this.offer);

  @override
  List<Object?> get props => [offer];
}

class FilterOffers extends MapEvent {
  final String filter;
  const FilterOffers(this.filter);

  @override
  List<Object?> get props => [filter];
}

class SearchLocation extends MapEvent {
  final String query;
  const SearchLocation(this.query);

  @override
  List<Object?> get props => [query];
}

class ChangeRadius extends MapEvent {
  final double radius;
  const ChangeRadius(this.radius);

  @override
  List<Object?> get props => [radius];
}

class GoToMyLocation extends MapEvent {
  const GoToMyLocation();
}
