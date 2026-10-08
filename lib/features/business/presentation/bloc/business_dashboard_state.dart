// lib/features/business/presentation/bloc/business_dashboard_state.dart

import 'package:equatable/equatable.dart';
import 'package:loqma/core/models/business.dart';

abstract class BusinessDashboardState extends Equatable {
  const BusinessDashboardState();

  @override
  List<Object?> get props => [];

  get status => null;
}

class BusinessDashboardInitial extends BusinessDashboardState {}

class BusinessDashboardLoading extends BusinessDashboardState {}

class BusinessDashboardLoaded extends BusinessDashboardState {
  final Business business;
  final List<String> capabilities;
  final int activeOffers;
  final int pendingRequests;
  final int completedRequests;
  final double rating;

  const BusinessDashboardLoaded({
    required this.business,
    required this.capabilities,
    this.activeOffers = 0,
    this.pendingRequests = 0,
    this.completedRequests = 0,
    this.rating = 0,
  });

  @override
  List<Object?> get props => [
        business,
        capabilities,
        activeOffers,
        pendingRequests,
        completedRequests,
        rating,
      ];
}

class BusinessDashboardError extends BusinessDashboardState {
  final String message;
  const BusinessDashboardError(this.message);

  @override
  List<Object?> get props => [message];
}
