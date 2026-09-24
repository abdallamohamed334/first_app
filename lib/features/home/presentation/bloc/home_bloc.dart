// lib/features/home/presentation/bloc/home_bloc.dart

import 'package:bloc/bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:loqma/core/models/community_stats.dart';
import 'package:loqma/core/models/user_model.dart';
import 'package:loqma/core/services/supabase_service.dart';
import 'package:loqma/features/offers/domain/entities/food_offer.dart';
import 'package:loqma/features/offers/domain/entities/offer_request_status.dart';
import 'package:loqma/features/institutions/domain/entities/institution_offer.dart';

import 'home_event.dart';
import 'home_state.dart';

@injectable
class HomeBloc extends Bloc<HomeEvent, HomeState> {
  final SupabaseService _supabaseService;

  HomeBloc()
      : _supabaseService = SupabaseService(),
        super(const HomeInitial()) {
    on<HomeInitialized>(_onInitialized);
    on<NavigateToTab>(_onNavigateToTab);
    on<RefreshHome>(_onRefreshHome);
  }

  Future<void> _onInitialized(
    HomeInitialized event,
    Emitter<HomeState> emit,
  ) async {
    emit(const HomeLoading());

    try {
      // ✅ نجيب المستخدم الحالي من auth
      final authUser = await _supabaseService.getCurrentUser();
      if (authUser == null) {
        emit(const HomeUnauthenticated());
        return;
      }

      // ✅ نجيب بيانات المستخدم من جدول users بالـ id
      final user = await _supabaseService.getUserById(authUser.id);
      if (user == null) {
        emit(const HomeUnauthenticated());
        return;
      }

      // ✅ الأدوار المدعومة (كل الأدوار الحالية بتستخدم نفس الـ home)
      final role = user.type.value.toLowerCase();
      const supportedRoles = {'user', 'provider', 'institution', 'admin'};
      if (!supportedRoles.contains(role)) {
        emit(const HomeUnauthenticated());
        return;
      }

      final results = await Future.wait<dynamic>([
        _getUserStats(user.id),
        _supabaseService.getCommunityStats(),
        _loadOffers(),
        _loadInstitutionOffers(),
        _getOfferRequestStatuses(user.id),
      ]);

      emit(HomeLoaded(
        user: user,
        stats: results[0] as UserStats,
        communityStats: results[1] as CommunityStats,
        offers: results[2] as List<FoodOffer>,
        institutionOffers: results[3] as List<InstitutionOffer>,
        offerRequestStatuses: results[4] as Map<String, OfferRequestStatus>,
      ));
    } catch (e) {
      emit(const HomeError('تعذر تحميل بيانات الصفحة الرئيسية حاليًا'));
    }
  }

  Future<List<FoodOffer>> _loadOffers() async {
    final response = await _supabaseService.getFoodOffers();
    final offers = <FoodOffer>[];

    for (final item in response) {
      try {
        offers.add(FoodOffer.fromJson(Map<String, dynamic>.from(item)));
      } catch (_) {
        // Ignore malformed rows and keep valid offers visible.
      }
    }

    return offers;
  }

  Future<List<InstitutionOffer>> _loadInstitutionOffers() async {
    try {
      final response = await _supabaseService.client
          .from('institution_offers_core')
          .select('''
            *,
            institutions:institution_id (
              id,
              name,
              logo,
              address,
              phone
            )
          ''')
          .eq('status', 'active')
          .order('created_at', ascending: false);

      return response
          .map((json) =>
              InstitutionOffer.fromJson(Map<String, dynamic>.from(json)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  void _onNavigateToTab(
    NavigateToTab event,
    Emitter<HomeState> emit,
  ) {
    final index = event.index.clamp(0, 4).toInt();
    final current = state;

    if (current is HomeLoaded) {
      emit(current.copyWith(currentIndex: index));
    } else {
      emit(HomeTabChanged(index));
    }
  }

  Future<void> _onRefreshHome(
    RefreshHome event,
    Emitter<HomeState> emit,
  ) async {
    await _onInitialized(const HomeInitialized(), emit);
  }

  Future<Map<String, OfferRequestStatus>> _getOfferRequestStatuses(
    String userId,
  ) async {
    try {
      final response = await _supabaseService.client
          .from('offer_requests')
          .select('offer_id, status')
          .eq('user_id', userId);

      final statuses = <String, OfferRequestStatus>{};
      for (final rawItem in response) {
        final item = Map<String, dynamic>.from(rawItem);
        final offerId = item['offer_id']?.toString();
        final status = item['status']?.toString();
        if (offerId == null || offerId.isEmpty || status == null) continue;
        statuses[offerId] = OfferRequestStatusExtension.fromString(status);
      }
      return statuses;
    } catch (_) {
      return <String, OfferRequestStatus>{};
    }
  }

  Future<UserStats> _getUserStats(String userId) async {
    try {
      final userData = await _supabaseService.client
          .from('users')
          .select('points')
          .eq('id', userId)
          .maybeSingle();

      final points = _asInt(userData?['points']);
      final mealsResponse = await _supabaseService.client
          .from('offer_requests')
          .select('id')
          .eq('user_id', userId)
          .eq('status', 'completed');

      final mealsSaved = mealsResponse.length;
      return UserStats(
        points: points,
        mealsSaved: mealsSaved,
        tasksCompleted: mealsSaved,
      );
    } catch (_) {
      return const UserStats();
    }
  }

  int _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
