// lib/features/business/presentation/bloc/business_dashboard_event.dart

import 'package:equatable/equatable.dart';

abstract class BusinessDashboardEvent extends Equatable {
  const BusinessDashboardEvent();

  @override
  List<Object?> get props => [];
}

class LoadBusinessDashboard extends BusinessDashboardEvent {}

class RefreshBusinessDashboard extends BusinessDashboardEvent {}

class UpdateBusinessStatus extends BusinessDashboardEvent {
  final String status;
  const UpdateBusinessStatus(this.status);

  @override
  List<Object?> get props => [status];
}
