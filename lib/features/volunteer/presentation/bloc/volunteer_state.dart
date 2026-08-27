// lib/features/volunteer/presentation/bloc/volunteer_state.dart

import 'package:equatable/equatable.dart';
import '../models/volunteer_model.dart'; // ✅ استيراد من models

abstract class VolunteerState extends Equatable {
  const VolunteerState();
  @override
  List<Object?> get props => [];
}

class VolunteerInitial extends VolunteerState {}

class VolunteerLoading extends VolunteerState {}

class VolunteerLoaded extends VolunteerState {
  final List<VolunteerModel> volunteers;
  final VolunteerModel? top1;
  final VolunteerModel? top2;
  final VolunteerModel? top3;
  final UserRankInfo? userRank;
  final String selectedFilter;

  const VolunteerLoaded({
    required this.volunteers,
    this.top1,
    this.top2,
    this.top3,
    this.userRank,
    this.selectedFilter = 'الكل',
  });

  @override
  List<Object?> get props => [
        volunteers,
        top1,
        top2,
        top3,
        userRank,
        selectedFilter,
      ];
}

class VolunteerError extends VolunteerState {
  final String message;
  const VolunteerError(this.message);
  @override
  List<Object?> get props => [message];
}
