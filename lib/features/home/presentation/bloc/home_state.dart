import 'package:equatable/equatable.dart';
import 'package:loqma/core/models/community_stats.dart';
import 'package:loqma/core/models/user_model.dart';
import 'package:loqma/features/offers/domain/entities/food_offer.dart';
import 'package:loqma/features/offers/domain/entities/offer_request_status.dart';
import 'package:loqma/features/institutions/domain/entities/institution_offer.dart'; // ✅ أضف الـ import

abstract class HomeState extends Equatable {
  const HomeState();

  @override
  List<Object?> get props => const [];
}

class HomeInitial extends HomeState {
  const HomeInitial();
}

class HomeLoading extends HomeState {
  const HomeLoading();
}

class HomeLoaded extends HomeState {
  final UserModel user;
  final UserStats stats;
  final List<FoodOffer> offers;
  final List<InstitutionOffer> institutionOffers; // ✅ أضف ده
  final CommunityStats communityStats;
  final Map<String, OfferRequestStatus> offerRequestStatuses;
  final int currentIndex;

  const HomeLoaded({
    required this.user,
    required this.stats,
    required this.offers,
    required this.institutionOffers, // ✅ أضف ده
    required this.communityStats,
    this.offerRequestStatuses = const <String, OfferRequestStatus>{},
    this.currentIndex = 0,
  });

  HomeLoaded copyWith({
    UserModel? user,
    UserStats? stats,
    List<FoodOffer>? offers,
    List<InstitutionOffer>? institutionOffers, // ✅ أضف ده
    CommunityStats? communityStats,
    Map<String, OfferRequestStatus>? offerRequestStatuses,
    int? currentIndex,
  }) {
    return HomeLoaded(
      user: user ?? this.user,
      stats: stats ?? this.stats,
      offers: offers ?? this.offers,
      institutionOffers:
          institutionOffers ?? this.institutionOffers, // ✅ أضف ده
      communityStats: communityStats ?? this.communityStats,
      offerRequestStatuses: offerRequestStatuses ?? this.offerRequestStatuses,
      currentIndex: currentIndex ?? this.currentIndex,
    );
  }

  @override
  List<Object?> get props => [
        user,
        stats,
        offers,
        institutionOffers, // ✅ أضف ده
        communityStats,
        offerRequestStatuses,
        currentIndex,
      ];
}

class HomeUnauthenticated extends HomeState {
  const HomeUnauthenticated();
}

class HomeError extends HomeState {
  final String message;

  const HomeError(this.message);

  @override
  List<Object?> get props => [message];
}

class HomeTabChanged extends HomeState {
  final int tabIndex;

  const HomeTabChanged(this.tabIndex);

  @override
  List<Object?> get props => [tabIndex];
}
