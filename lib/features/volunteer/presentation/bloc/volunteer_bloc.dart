import 'package:bloc/bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:loqma/core/services/supabase_service.dart';
import '../models/volunteer_model.dart';
import 'volunteer_event.dart';
import 'volunteer_state.dart';

@injectable
class VolunteerBloc extends Bloc<VolunteerEvent, VolunteerState> {
  final SupabaseService _supabaseService;

  VolunteerBloc(this._supabaseService) : super(VolunteerInitial()) {
    on<VolunteerStarted>(_onStarted);
    on<VolunteerFilterChanged>(_onFilterChanged);
    on<VolunteerRefresh>(_onRefresh);
  }

  Future<void> _onStarted(
    VolunteerStarted event,
    Emitter<VolunteerState> emit,
  ) async {
    emit(VolunteerLoading());
    await _loadVolunteers(emit, null);
  }

  Future<void> _onFilterChanged(
    VolunteerFilterChanged event,
    Emitter<VolunteerState> emit,
  ) async {
    emit(VolunteerLoading());
    final filterDate = _getFilterDate(event.filter);
    await _loadVolunteers(emit, filterDate);
  }

  Future<void> _onRefresh(
    VolunteerRefresh event,
    Emitter<VolunteerState> emit,
  ) async {
    final currentState = state;
    if (currentState is VolunteerLoaded) {
      final filterDate = _getFilterDate(currentState.selectedFilter);
      await _loadVolunteers(emit, filterDate);
    }
  }

  DateTime? _getFilterDate(String filter) {
    final now = DateTime.now();
    switch (filter) {
      case 'اليوم':
        return now.subtract(const Duration(days: 1));
      case 'هذا الأسبوع':
        return now.subtract(const Duration(days: 7));
      case 'هذا الشهر':
        return now.subtract(const Duration(days: 30));
      default:
        return null;
    }
  }

  Future<void> _loadVolunteers(
    Emitter<VolunteerState> emit,
    DateTime? filterDate,
  ) async {
    try {
      // ✅ جلب المتطوعين من جدول users مع الترتيب حسب النقاط
      var query = _supabaseService.client
          .from('users')
          .select('id, name, avatar_url, points, level')
          .eq('user_type', 'user')
          .eq('is_active', true);

      final response = await query.order('points', ascending: false);

      final volunteers = <VolunteerModel>[];
      for (var i = 0; i < response.length; i++) {
        final item = response[i];
        volunteers.add(VolunteerModel(
          id: item['id'] as String,
          name: item['name'] as String? ?? 'متطوع',
          avatarUrl: item['avatar_url'] as String?,
          points: item['points'] as int? ?? 0,
          level: item['level'] as int? ?? 1,
        ));
      }

      // ✅ جلب ترتيب المستخدم الحالي
      final authUser = await _supabaseService.getCurrentUser();
      UserRankInfo? userRank;

      if (authUser != null) {
        final userIndex = volunteers.indexWhere((v) => v.id == authUser.id);
        final currentRank = userIndex >= 0 ? userIndex + 1 : 0;
        final userPoints =
            volunteers.where((v) => v.id == authUser.id).firstOrNull?.points ??
                0;

        int pointsToNextRank = 0;
        int nextRankPosition = 0;
        double progress = 0.0;

        if (currentRank > 1 && currentRank <= volunteers.length) {
          final nextVolunteer = volunteers[currentRank - 2];
          pointsToNextRank = nextVolunteer.points - userPoints;
          nextRankPosition = currentRank - 1;
          progress = pointsToNextRank > 0
              ? 1 - (pointsToNextRank / (userPoints + pointsToNextRank))
              : 1.0;
        }

        userRank = UserRankInfo(
          currentRank: currentRank,
          totalVolunteers: volunteers.length,
          points: userPoints,
          mealsSaved: 0,
          completedDeliveries: 0,
          completedRequests: 0,
          pointsToNextRank: pointsToNextRank > 0 ? pointsToNextRank : 0,
          nextRankPosition: nextRankPosition,
          progress: progress.clamp(0.0, 1.0),
          badge: _getBadge(userPoints),
          level:
              volunteers.where((v) => v.id == authUser.id).firstOrNull?.level ??
                  1,
        );
      }

      emit(VolunteerLoaded(
        volunteers: volunteers,
        top1: volunteers.isNotEmpty ? volunteers[0] : null,
        top2: volunteers.length > 1 ? volunteers[1] : null,
        top3: volunteers.length > 2 ? volunteers[2] : null,
        userRank: userRank,
        selectedFilter:
            filterDate == null ? 'كل الوقت' : _getFilterName(filterDate),
      ));
    } catch (e) {
      print('❌ Error loading volunteers: $e');
      emit(const VolunteerError('حدث خطأ أثناء تحميل المتطوعين'));
    }
  }

  String _getBadge(int points) {
    if (points >= 5000) return 'diamond';
    if (points >= 2000) return 'platinum';
    if (points >= 1000) return 'gold';
    if (points >= 500) return 'silver';
    return 'beginner';
  }

  String _getFilterName(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays <= 1) return 'اليوم';
    if (diff.inDays <= 7) return 'هذا الأسبوع';
    return 'هذا الشهر';
  }
}
