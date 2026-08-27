import 'package:equatable/equatable.dart';

abstract class VolunteerEvent extends Equatable {
  const VolunteerEvent();

  @override
  List<Object?> get props => [];
}

class VolunteerStarted extends VolunteerEvent {
  const VolunteerStarted();
}

class VolunteerFilterChanged extends VolunteerEvent {
  final String filter;

  const VolunteerFilterChanged(this.filter);

  @override
  List<Object> get props => [filter];
}

class VolunteerRefresh extends VolunteerEvent {
  const VolunteerRefresh();
}