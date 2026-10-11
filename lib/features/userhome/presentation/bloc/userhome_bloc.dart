// lib/features/userhome/presentation/bloc/userhome_bloc.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:loqma/core/models/community_stats.dart';
import 'package:loqma/core/models/nearby_place.dart';
import 'package:loqma/features/community/data/repositories/community_offer_repository.dart';
import 'package:loqma/features/offers/domain/entities/food_offer.dart';
import 'package:loqma/features/map/data/repositories/map_repository.dart';
import 'package:loqma/features/userhome/data/repositories/userhome_repository.dart';
import 'package:loqma/features/userhome/presentation/bloc/userhome_state.dart';
import 'package:loqma/features/userhome/presentation/widgets/home_banner_carousel.dart';
import 'package:loqma/features/userhome/presentation/widgets/home_delivery_donations.dart';

// ============================================================
// EVENTS
// ============================================================

abstract class UserHomeEvent {
  const UserHomeEvent();
}

/// تحميل الصفحة لأول مرة.
class UserHomeStarted extends UserHomeEvent {
  const UserHomeStarted();
}

/// إعادة تحميل كل بيانات الصفحة.
class UserHomeRefreshed extends UserHomeEvent {
  const UserHomeRefreshed();
}

/// البحث.
class SearchOffers extends UserHomeEvent {
  final String query;

  const SearchOffers(this.query);
}

/// فلترة حسب نوع الطعام/التصنيف.
class FilterByCategory extends UserHomeEvent {
  final String category;

  const FilterByCategory(this.category);
}

/// فلترة حسب الهدف: buy / sell / donate
class FilterByIntent extends UserHomeEvent {
  final String intent;

  const FilterByIntent(this.intent);
}

/// تحميل التصنيفات الرئيسية من `marketplace_categories`.
class LoadMainCategories extends UserHomeEvent {
  const LoadMainCategories();
}

/// اختيار تصنيف معين → جلب عروضه.
class SelectCategory extends UserHomeEvent {
  final String categoryId;
  final String categoryName;
  final String? categorySlug;

  const SelectCategory({
    required this.categoryId,
    required this.categoryName,
    this.categorySlug,
  });
}

/// إلغاء التصنيف المختار (العودة للـ Home العادي).
class ClearCategorySelection extends UserHomeEvent {
  const ClearCategorySelection();
}

// ============================================================
// BLOC
// ============================================================

class UserHomeBloc extends Bloc<UserHomeEvent, UserHomeState> {
  int _loadGeneration = 0;

  final UserHomeRepository repository;
  final MapRepository _mapRepository;
  final CommunityOfferRepository _communityRepository;

  // ----------------------------------------------------------
  // Current filters
  // ----------------------------------------------------------

  String _currentCategory = 'الكل';
  String _currentIntent = 'buy';
  String _searchQuery = '';

  // ----------------------------------------------------------
  // Constructor
  // ----------------------------------------------------------

  UserHomeBloc({
    required this.repository,
    required MapRepository mapRepository,
    CommunityOfferRepository? communityRepository,
  })  : _mapRepository = mapRepository,
        _communityRepository =
            communityRepository ?? CommunityOfferRepository(),
        super(const UserHomeLoading()) {
    on<UserHomeStarted>(_onStarted);
    on<UserHomeRefreshed>(_onRefreshed);
    on<SearchOffers>(_onSearchOffers);
    on<FilterByCategory>(_onFilterByCategory);
    on<FilterByIntent>(_onFilterByIntent);
    on<LoadMainCategories>(_onLoadMainCategories);
    on<SelectCategory>(_onSelectCategory);
    on<ClearCategorySelection>(_onClearCategorySelection);
  }

  // ==========================================================
  // START / LOAD
  // ==========================================================

  Future<void> _onStarted(
    UserHomeStarted event,
    Emitter<UserHomeState> emit,
  ) async {
    final generation = ++_loadGeneration;
    emit(const UserHomeLoading());

    try {
      final currentUser = await repository.getCurrentUser();
      if (generation != _loadGeneration || emit.isDone) return;

      if (currentUser == null) {
        emit(const UserHomeUnauthenticated());
        return;
      }

      // ------------------------------------------------------
      // User data / location
      // ------------------------------------------------------

      final userData = await repository.getUserData();
      if (generation != _loadGeneration || emit.isDone) return;

      double? userLatitude;
      double? userLongitude;
      String? userCity;

      if (userData != null) {
        final rawLatitude = userData['latitude'];
        final rawLongitude = userData['longitude'];
        final rawCity = userData['city'];

        if (rawLatitude is num) {
          userLatitude = rawLatitude.toDouble();
        }

        if (rawLongitude is num) {
          userLongitude = rawLongitude.toDouble();
        }

        if (rawCity != null) {
          final city = rawCity.toString().trim();

          if (city.isNotEmpty) {
            userCity = city;
          }
        }
      }

      // ------------------------------------------------------
      // Load base food offers
      // كل مصادر الـHome مستقلة؛ تشغيلها بالتوازي يقلل زمن فتح الصفحة بشكل
      // واضح مقارنة بالانتظار على كل استعلام قبل بدء التالي.
      final hasLocation = userLatitude != null && userLongitude != null;
      final results = await Future.wait<dynamic>([
        repository.getOffers(),
        hasLocation
            ? _mapRepository.getNearbyOffers(
                latitude: userLatitude!,
                longitude: userLongitude!,
                radiusMeters: 10000,
              )
            : Future.value(<FoodOffer>[]),
        hasLocation
            ? _mapRepository.getAllOffers(
                latitude: userLatitude!,
                longitude: userLongitude!,
                limit: 50,
                offset: 0,
              )
            : Future.value(<FoodOffer>[]),
        hasLocation
            ? _communityRepository.getNearbyOffers(
                latitude: userLatitude!,
                longitude: userLongitude!,
                limit: 50,
                offset: 0,
              )
            : Future.value(<Map<String, dynamic>>[]),
        hasLocation
            ? repository.getDeliveryTasks(
                latitude: userLatitude!,
                longitude: userLongitude!,
              )
            : Future.value(<Map<String, dynamic>>[]),
        repository.getDeliveryDonations(),
        repository.getCommunityStats(),
        repository.getNearbyPlaces(),
        repository.getHomeBanners(),
      ]);

      if (generation != _loadGeneration || emit.isDone) return;

      final foodOffers = results[0] as List<FoodOffer>;
      final nearbyOffers = results[1] as List<FoodOffer>;
      final allInstitutionOffers = results[2] as List<FoodOffer>;
      final communityOffers = results[3] as List<Map<String, dynamic>>;

      final deliveryTasks = results[4] as List<Map<String, dynamic>>;
      final deliveryDonations = results[5] as List<DeliveryDonation>;
      final communityStats = results[6] as CommunityStats;
      final nearbyPlaces = results[7] as List<NearbyPlace>;
      final banners = results[8] as List<HomeBanner>;

      // ------------------------------------------------------
      // Build unique all offers
      // ------------------------------------------------------

      final uniqueOffers = _uniqueFoodOffers([
        ...foodOffers,
        ...allInstitutionOffers,
      ]);

      final uniqueNearbyOffers = _uniqueFoodOffers(
        nearbyOffers,
      );

      // ------------------------------------------------------
      // Rebuild restaurant/institution lists from unique data
      // ------------------------------------------------------

      final uniqueRestaurantOffers = uniqueOffers.where((offer) {
        return offer.businessType.trim().toLowerCase() == 'restaurant';
      }).map((offer) {
        return offer.copyWith(source: 'restaurant');
      }).toList(growable: false);

      final uniqueInstitutionOffers = uniqueOffers.where((offer) {
        return offer.businessType.trim().toLowerCase() != 'restaurant';
      }).map((offer) {
        return offer.copyWith(source: 'institution');
      }).toList(growable: false);

      // ------------------------------------------------------
      // Apply current filters
      // ------------------------------------------------------

      final filteredOffers = _applyFilters(uniqueOffers);

      // ------------------------------------------------------
      // Emit initial loaded state FIRST (UI unblocks)
      // ------------------------------------------------------

      emit(
        UserHomeLoaded(
          offers: uniqueOffers,
          filteredOffers: filteredOffers,
          userCity: userCity,
          userLatitude: userLatitude,
          userLongitude: userLongitude,
          deliveryTasks: deliveryTasks,
          deliveryDonations: deliveryDonations,
          communityStats: communityStats,
          nearbyPlaces: nearbyPlaces,
          banners: banners,
          nearbyOffers: uniqueNearbyOffers,
          allOffers: allInstitutionOffers,
          restaurantOffers: uniqueRestaurantOffers,
          institutionOffers: uniqueInstitutionOffers,
          communityOffers: communityOffers,
        ),
      );

      // ------------------------------------------------------
      // THEN preload main categories in background
      // ------------------------------------------------------

      unawaited(_preloadCategories(generation));
    } catch (error) {
      if (generation != _loadGeneration || emit.isDone) return;
      emit(
        UserHomeError(
          _friendlyError(error),
        ),
      );
    }
  }

  // ==========================================================
  // PRELOAD CATEGORIES (background)
  // ==========================================================

  Future<void> _preloadCategories(int generation) async {
    try {
      debugPrint('🔥 Loading categories...');

      final categories = await repository.getMainCategories();
      if (generation != _loadGeneration || isClosed) return;

      debugPrint('🔥 Categories loaded: ${categories.length}');

      if (categories.isEmpty) {
        debugPrint('🔥 No categories returned from repository');
        return;
      }

      debugPrint('🔥 First category: ${categories.first}');

      final currentState = state;

      if (currentState is! UserHomeLoaded) {
        debugPrint('🔥 State is not Loaded, cannot attach categories');
        return;
      }

      emit(
        currentState.copyWith(categories: categories),
      );

      debugPrint('🔥 Categories emitted to state');
    } catch (e) {
      debugPrint('🔥 Categories ERROR: $e');
    }
  }

  // ==========================================================
  // REFRESH
  // ==========================================================

  Future<void> _onRefreshed(
    UserHomeRefreshed event,
    Emitter<UserHomeState> emit,
  ) async {
    await _onStarted(
      const UserHomeStarted(),
      emit,
    );
  }

  // ==========================================================
  // SEARCH
  // ==========================================================

  void _onSearchOffers(
    SearchOffers event,
    Emitter<UserHomeState> emit,
  ) {
    _searchQuery = event.query.trim();

    final currentState = state;

    if (currentState is! UserHomeLoaded) {
      return;
    }

    emit(
      currentState.copyWith(
        filteredOffers: _applyFilters(currentState.offers),
      ),
    );
  }

  // ==========================================================
  // CATEGORY FILTER
  // ==========================================================

  void _onFilterByCategory(
    FilterByCategory event,
    Emitter<UserHomeState> emit,
  ) {
    _currentCategory =
        event.category.trim().isEmpty ? 'الكل' : event.category.trim();

    final currentState = state;

    if (currentState is! UserHomeLoaded) {
      return;
    }

    emit(
      currentState.copyWith(
        filteredOffers: _applyFilters(currentState.offers),
      ),
    );
  }

  // ==========================================================
  // INTENT FILTER
  // ==========================================================

  void _onFilterByIntent(
    FilterByIntent event,
    Emitter<UserHomeState> emit,
  ) {
    _currentIntent =
        event.intent.trim().isEmpty ? 'buy' : event.intent.trim().toLowerCase();

    final currentState = state;

    if (currentState is! UserHomeLoaded) {
      return;
    }

    emit(
      currentState.copyWith(
        filteredOffers: _applyFilters(currentState.offers),
      ),
    );
  }

  // ==========================================================
  // LOAD MAIN CATEGORIES (explicit event)
  // ==========================================================

  Future<void> _onLoadMainCategories(
    LoadMainCategories event,
    Emitter<UserHomeState> emit,
  ) async {
    final currentState = state;

    if (currentState is! UserHomeLoaded) {
      return;
    }

    if (currentState.categories.isNotEmpty) {
      return;
    }

    emit(currentState.copyWith(categoriesLoading: true));

    try {
      debugPrint('🔥 _onLoadMainCategories: fetching...');

      final categories = await repository.getMainCategories();

      debugPrint('🔥 _onLoadMainCategories: got ${categories.length}');

      emit(
        currentState.copyWith(
          categories: categories,
          categoriesLoading: false,
        ),
      );
    } catch (e) {
      debugPrint('❌ _onLoadMainCategories error: $e');

      emit(
        currentState.copyWith(
          categoriesLoading: false,
        ),
      );
    }
  }

  // ==========================================================
  // SELECT CATEGORY
  // ==========================================================

  Future<void> _onSelectCategory(
    SelectCategory event,
    Emitter<UserHomeState> emit,
  ) async {
    final currentState = state;

    if (currentState is! UserHomeLoaded) {
      return;
    }

    emit(
      currentState.copyWith(
        selectedCategoryId: event.categoryId,
        selectedCategoryName: event.categoryName,
        categoryOffers: const [],
        categoryOffersLoading: true,
      ),
    );

    try {
      final offers = await repository.getOffersByCategory(
        categoryId: event.categoryId,
        latitude: currentState.userLatitude,
        longitude: currentState.userLongitude,
        radiusKm: 10,
      );

      final latest = state;
      if (latest is! UserHomeLoaded ||
          latest.selectedCategoryId != event.categoryId) {
        return;
      }

      emit(
        latest.copyWith(
          categoryOffers: offers,
          categoryOffersLoading: false,
        ),
      );
    } catch (e) {
      debugPrint('❌ _onSelectCategory error: $e');

      final latest = state;
      if (latest is UserHomeLoaded &&
          latest.selectedCategoryId == event.categoryId) {
        emit(
          latest.copyWith(
            categoryOffers: const [],
            categoryOffersLoading: false,
          ),
        );
      }
    }
  }

  // ==========================================================
  // CLEAR CATEGORY SELECTION
  // ==========================================================

  void _onClearCategorySelection(
    ClearCategorySelection event,
    Emitter<UserHomeState> emit,
  ) {
    final currentState = state;

    if (currentState is! UserHomeLoaded) {
      return;
    }

    emit(
      currentState.copyWith(
        clearSelectedCategory: true,
        categoryOffers: const [],
        categoryOffersLoading: false,
      ),
    );
  }

  // ==========================================================
  // FILTER ENGINE
  // ==========================================================

  List<FoodOffer> _applyFilters(
    List<FoodOffer> source,
  ) {
    final query = _searchQuery.toLowerCase();

    return source.where((offer) {
      if (!offer.isAvailable || offer.isExpired) {
        return false;
      }

      switch (_currentIntent) {
        case 'donate':
          if (offer.hasPrice) {
            return false;
          }
          break;

        case 'sell':
          if (!offer.hasPrice) {
            return false;
          }
          break;

        case 'buy':
        default:
          break;
      }

      if (!_categoryMatches(
        offer.foodType,
        _currentCategory,
      )) {
        return false;
      }

      if (query.isEmpty) {
        return true;
      }

      final haystack = [
        offer.title,
        offer.description,
        offer.foodType,
        offer.businessName,
        offer.displayLocation,
      ].join(' ').toLowerCase();

      return haystack.contains(query);
    }).toList(growable: false);
  }

  bool _categoryMatches(
    String foodType,
    String category,
  ) {
    if (category == 'الكل') {
      return true;
    }

    final value = foodType.trim().toLowerCase();
    final target = category.trim().toLowerCase();

    if (value.contains(target)) {
      return true;
    }

    const aliases = <String, List<String>>{
      'وجبات': ['meal', 'meals', 'food', 'وجبة', 'وجبات', 'طعام'],
      'مخبوزات': ['bread', 'bakery', 'مخبوز', 'مخبوزات', 'خبز'],
      'حلويات': ['dessert', 'sweet', 'sweets', 'حلويات', 'حلو'],
      'فواكه': ['fruit', 'fruits', 'فاكهة', 'فواكه'],
      'مشروبات': [
        'drink',
        'drinks',
        'beverage',
        'beverages',
        'مشروب',
        'مشروبات'
      ],
    };

    final possibleValues = aliases[target];

    if (possibleValues == null) {
      return false;
    }

    return possibleValues.any(value.contains);
  }

  // ==========================================================
  // UNIQUE FOOD OFFERS
  // ==========================================================

  List<FoodOffer> _uniqueFoodOffers(
    Iterable<FoodOffer> offers,
  ) {
    final map = <String, FoodOffer>{};

    for (final offer in offers) {
      final id = offer.id.trim();

      if (id.isEmpty) {
        continue;
      }

      map[id] = offer;
    }

    return map.values.toList(growable: false);
  }

  // ==========================================================
  // FRIENDLY ERROR
  // ==========================================================

  String _friendlyError(
    Object error,
  ) {
    final message = error.toString();

    if (message.contains('SocketException') ||
        message.contains('Failed host lookup') ||
        message.contains('network')) {
      return 'تعذر الاتصال بالإنترنت. تأكد من الاتصال وحاول مرة أخرى.';
    }

    if (message.contains('JWT') ||
        message.contains('auth') ||
        message.contains('session')) {
      return 'انتهت جلسة تسجيل الدخول. يرجى تسجيل الدخول مرة أخرى.';
    }

    return 'حدث خطأ أثناء تحميل الصفحة. حاول مرة أخرى.';
  }
}
