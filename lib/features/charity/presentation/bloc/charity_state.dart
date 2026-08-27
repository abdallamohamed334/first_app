part of 'charity_bloc.dart';

abstract class CharityState {
  const CharityState();
}

class CharityInitial extends CharityState {
  const CharityInitial();
}

class CharityLoading extends CharityState {
  const CharityLoading();
}

class CharityLoaded extends CharityState {
  final List<Map<String, dynamic>> charities;

  const CharityLoaded({required this.charities});

  @override
  List<Object?> get props => [charities];
}

class CharityError extends CharityState {
  final String message;

  const CharityError(this.message);

  @override
  List<Object?> get props => [message];
}
