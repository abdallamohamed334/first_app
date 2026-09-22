// lib/features/userhome/presentation/bloc/userhome_state.dart

import 'package:equatable/equatable.dart';
import 'package:loqma/core/models/community_stats.dart';
import 'package:loqma/core/models/nearby_place.dart';
import 'package:loqma/features/offers/domain/entities/food_offer.dart';
import 'package:loqma/features/userhome/domain/entities/category_offer.dart';
import 'package:loqma/features/userhome/presentation/widgets/home_banner_carousel.dart';
import 'package:loqma/features/userhome/presentation/widgets/home_delivery_donations.dart';

abstract class UserHomeState extends Equatable {
  const UserHomeState();

  @override
  List<Object?> get props => [];
}

// ============================================================
// LOADING
// ============================================================

class UserHomeLoading extends UserHomeState {
  const UserHomeLoading();
}

// ============================================================
// LOADED
// ============================================================

class UserHomeLoaded extends UserHomeState {
  // ----------------------------------------------------------
  // Food offers
  // ----------------------------------------------------------

  final List<FoodOffer> offers;
  final List<FoodOffer> filteredOffers;
  final List<FoodOffer> nearbyOffers;
  final List<FoodOffer> allOffers;
  final List<FoodOffer> restaurantOffers;
  final List<FoodOffer> institutionOffers;

  // ----------------------------------------------------------
  // Community offers
  // ----------------------------------------------------------

  final List<Map<String, dynamic>> communityOffers;

  // ----------------------------------------------------------
  // Marketplace Categories
  // ----------------------------------------------------------

  /// كل التصنيفات الرئيسية القادمة من `marketplace_categories`.
  final List<Map<String, dynamic>> categories;

  /// هل التصنيفات في حالة تحميل؟
  final bool categoriesLoading;

  /// التصنيف المختار حاليًا (null لو مفيش اختيار).
  final String? selectedCategoryId;

  /// اسم التصنيف المختار (للعرض في الـ AppBar).
  final String? selectedCategoryName;

  /// العروض الخاصة بالتصنيف المختار
  /// (community + institution مدمجين).
  final List<CategoryOffer> categoryOffers;

  /// هل عروض التصنيف في حالة تحميل؟
  final bool categoryOffersLoading;

  // ----------------------------------------------------------
  // User location
  // ----------------------------------------------------------

  final String? userCity;
  final double? userLatitude;
  final double? userLongitude;

  // ----------------------------------------------------------
  // Delivery / charity
  // ----------------------------------------------------------

  final List<Map<String, dynamic>> deliveryTasks;
  final List<DeliveryDonation> deliveryDonations;

  // ----------------------------------------------------------
  // Community information
  // ----------------------------------------------------------

  final CommunityStats communityStats;
  final List<NearbyPlace> nearbyPlaces;

  // ----------------------------------------------------------
  // Home banners
  // ----------------------------------------------------------

  final List<HomeBanner> banners;

  const UserHomeLoaded({
    required this.offers,
    required this.filteredOffers,
    this.userCity,
    this.userLatitude,
    this.userLongitude,
    required this.deliveryTasks,
    required this.deliveryDonations,
    required this.communityStats,
    required this.nearbyPlaces,
    required this.banners,
    required this.nearbyOffers,
    required this.allOffers,
    required this.restaurantOffers,
    required this.institutionOffers,
    required this.communityOffers,
    this.categories = const [],
    this.categoriesLoading = false,
    this.selectedCategoryId,
    this.selectedCategoryName,
    this.categoryOffers = const [],
    this.categoryOffersLoading = false,
  });

  UserHomeLoaded copyWith({
    List<FoodOffer>? offers,
    List<FoodOffer>? filteredOffers,
    String? userCity,
    double? userLatitude,
    double? userLongitude,
    List<Map<String, dynamic>>? deliveryTasks,
    List<DeliveryDonation>? deliveryDonations,
    CommunityStats? communityStats,
    List<NearbyPlace>? nearbyPlaces,
    List<HomeBanner>? banners,
    List<FoodOffer>? nearbyOffers,
    List<FoodOffer>? allOffers,
    List<FoodOffer>? restaurantOffers,
    List<FoodOffer>? institutionOffers,
    List<Map<String, dynamic>>? communityOffers,
    List<Map<String, dynamic>>? categories,
    bool? categoriesLoading,
    String? selectedCategoryId,
    String? selectedCategoryName,
    List<CategoryOffer>? categoryOffers,
    bool? categoryOffersLoading,
    bool clearSelectedCategory = false,
  }) {
    return UserHomeLoaded(
      offers: offers ?? this.offers,
      filteredOffers: filteredOffers ?? this.filteredOffers,
      userCity: userCity ?? this.userCity,
      userLatitude: userLatitude ?? this.userLatitude,
      userLongitude: userLongitude ?? this.userLongitude,
      deliveryTasks: deliveryTasks ?? this.deliveryTasks,
      deliveryDonations: deliveryDonations ?? this.deliveryDonations,
      communityStats: communityStats ?? this.communityStats,
      nearbyPlaces: nearbyPlaces ?? this.nearbyPlaces,
      banners: banners ?? this.banners,
      nearbyOffers: nearbyOffers ?? this.nearbyOffers,
      allOffers: allOffers ?? this.allOffers,
      restaurantOffers: restaurantOffers ?? this.restaurantOffers,
      institutionOffers: institutionOffers ?? this.institutionOffers,
      communityOffers: communityOffers ?? this.communityOffers,
      categories: categories ?? this.categories,
      categoriesLoading: categoriesLoading ?? this.categoriesLoading,
      selectedCategoryId: clearSelectedCategory
          ? null
          : (selectedCategoryId ?? this.selectedCategoryId),
      selectedCategoryName: clearSelectedCategory
          ? null
          : (selectedCategoryName ?? this.selectedCategoryName),
      categoryOffers: categoryOffers ?? this.categoryOffers,
      categoryOffersLoading:
          categoryOffersLoading ?? this.categoryOffersLoading,
    );
  }

  // ----------------------------------------------------------
  // Convenience getters
  // ----------------------------------------------------------

  int get availableOffersCount {
    return offers.where((offer) {
      return offer.isAvailable && !offer.isExpired;
    }).length;
  }

  int get urgentOffersCount {
    return offers.where((offer) {
      return offer.isUrgent;
    }).length;
  }

  int get communityOffersCount {
    return communityOffers.length;
  }

  bool get hasSelectedCategory =>
      selectedCategoryId != null && selectedCategoryId!.isNotEmpty;

  // ----------------------------------------------------------
  // Equatable
  // ----------------------------------------------------------

  @override
  List<Object?> get props => [
        offers,
        filteredOffers,
        userCity,
        userLatitude,
        userLongitude,
        deliveryTasks,
        deliveryDonations,
        communityStats,
        nearbyPlaces,
        banners,
        nearbyOffers,
        allOffers,
        restaurantOffers,
        institutionOffers,
        communityOffers,
        categories,
        categoriesLoading,
        selectedCategoryId,
        selectedCategoryName,
        categoryOffers,
        categoryOffersLoading,
      ];
}

// ============================================================
// ERROR
// ============================================================

class UserHomeError extends UserHomeState {
  final String message;

  const UserHomeError(this.message);

  @override
  List<Object?> get props => [message];
}

// ============================================================
// UNAUTHENTICATED
// ============================================================

class UserHomeUnauthenticated extends UserHomeState {
  const UserHomeUnauthenticated();
}
