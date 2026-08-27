import 'package:equatable/equatable.dart';

abstract class HomeEvent extends Equatable {
  const HomeEvent();

  @override
  List<Object?> get props => const [];
}

class HomeInitialized extends HomeEvent {
  const HomeInitialized();
}

class NavigateToTab extends HomeEvent {
  final int index;

  const NavigateToTab(this.index);

  @override
  List<Object> get props => [index];
}

class RefreshHome extends HomeEvent {
  const RefreshHome();
}
