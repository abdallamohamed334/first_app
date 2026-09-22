import 'package:equatable/equatable.dart';

abstract class UserHomeEvent extends Equatable {
  const UserHomeEvent();

  @override
  List<Object?> get props => [];
}

class UserHomeStarted extends UserHomeEvent {
  const UserHomeStarted();
}

class UserHomeRefreshed extends UserHomeEvent {
  const UserHomeRefreshed();
}

class SearchOffers extends UserHomeEvent {
  final String query;

  const SearchOffers(this.query);

  @override
  List<Object?> get props => [query];
}

class FilterByCategory extends UserHomeEvent {
  final String category;

  const FilterByCategory(this.category);

  @override
  List<Object?> get props => [category];
}

class FilterByIntent extends UserHomeEvent {
  final String intent;

  const FilterByIntent(this.intent);

  @override
  List<Object?> get props => [intent];
}
