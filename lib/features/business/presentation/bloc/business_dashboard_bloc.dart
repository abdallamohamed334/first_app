import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:loqma/core/models/business.dart';
import 'package:loqma/core/services/supabase_service.dart';
import 'package:loqma/features/business/data/repositories/business_repository.dart';

// ============ EVENTS ============
abstract class BusinessDashboardEvent extends Equatable {
  const BusinessDashboardEvent();

  @override
  List<Object?> get props => [];
}

class LoadDashboardData extends BusinessDashboardEvent {
  final String businessId;
  const LoadDashboardData({required this.businessId});

  @override
  List<Object?> get props => [businessId];
}

class RefreshDashboardData extends BusinessDashboardEvent {
  final String businessId;
  const RefreshDashboardData({required this.businessId});

  @override
  List<Object?> get props => [businessId];
}

// ============ STATES ============
enum DashboardStatus { initial, loading, loaded, error }

class BusinessDashboardState extends Equatable {
  final DashboardStatus status;
  final Business? business;
  final Map<String, dynamic> stats;
  final String? error;

  const BusinessDashboardState({
    this.status = DashboardStatus.initial,
    this.business,
    this.stats = const {},
    this.error,
  });

  factory BusinessDashboardState.loading() {
    return const BusinessDashboardState(status: DashboardStatus.loading);
  }

  factory BusinessDashboardState.loaded({
    required Business business,
    required Map<String, dynamic> stats,
  }) {
    return BusinessDashboardState(
      status: DashboardStatus.loaded,
      business: business,
      stats: stats,
    );
  }

  factory BusinessDashboardState.error(String message) {
    return BusinessDashboardState(
      status: DashboardStatus.error,
      error: message,
    );
  }

  @override
  List<Object?> get props => [status, business, stats, error];
}

// ============ BLOC ============
class BusinessDashboardBloc
    extends Bloc<BusinessDashboardEvent, BusinessDashboardState> {
  final BusinessRepository _repository;
  final SupabaseService _supabase;

  BusinessDashboardBloc(this._repository, this._supabase)
      : super(const BusinessDashboardState()) {
    on<LoadDashboardData>(_onLoadDashboardData);
    on<RefreshDashboardData>(_onRefreshDashboardData);
  }

  Future<void> _onLoadDashboardData(
    LoadDashboardData event,
    Emitter<BusinessDashboardState> emit,
  ) async {
    emit(BusinessDashboardState.loading());

    try {
      final business = await _repository.getBusinessById(event.businessId);

      if (business == null) {
        emit(BusinessDashboardState.error('المطعم غير موجود'));
        return;
      }

      final stats = await _repository.getBusinessStats(event.businessId);

      emit(BusinessDashboardState.loaded(
        business: business,
        stats: stats,
      ));
    } catch (e) {
      emit(BusinessDashboardState.error('حدث خطأ: $e'));
    }
  }

  Future<void> _onRefreshDashboardData(
    RefreshDashboardData event,
    Emitter<BusinessDashboardState> emit,
  ) async {
    add(LoadDashboardData(businessId: event.businessId));
  }
}
