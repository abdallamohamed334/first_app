// lib/features/userhome/presentation/pages/user_home_page.dart

import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:loqma/core/config/app_config.dart';
import 'package:loqma/core/services/supabase_service.dart';
import 'package:loqma/core/theme/theme_notifier.dart';

import 'package:loqma/features/booking/presentation/pages/my_bookings_page.dart';
import 'package:loqma/features/charity/presentation/pages/add_charity_donation_page.dart';
import 'package:loqma/features/charity/presentation/pages/person_offer_details_page.dart';
import 'package:loqma/features/community/data/repositories/community_needs_repository.dart';
import 'package:loqma/features/community/presentation/pages/add_community_offer_page.dart';
import 'package:loqma/features/community/presentation/pages/add_community_need_page.dart';
import 'package:loqma/features/community/presentation/pages/community_need_details_page.dart';
import 'package:loqma/features/community/presentation/pages/community_needs_page.dart';
import 'package:loqma/features/community/presentation/pages/community_offer_details_page.dart';
import 'package:loqma/features/community/presentation/pages/community_tracking_page.dart';
import 'package:loqma/features/community/presentation/pages/my_community_needs_page.dart';
import 'package:loqma/features/institutions/data/repositories/institution_offers_repository.dart';
import 'package:loqma/features/institutions/domain/entities/institution_offer.dart';
import 'package:loqma/features/institutions/presentation/pages/institution_offer_details_page.dart';
import 'package:loqma/features/notification/presentation/pages/notifications_page.dart';
import 'package:loqma/features/offers/domain/entities/food_offer.dart';
import 'package:loqma/features/offers/domain/entities/food_offer_status.dart';
import 'package:loqma/features/profile/presentation/pages/profile_page.dart';
// ✅ خدمات
import 'package:loqma/features/services/data/repositories/service_categories_repository.dart';
import 'package:loqma/features/services/data/repositories/service_providers_repository.dart';
import 'package:loqma/features/services/domain/entities/service_category.dart';
import 'package:loqma/features/services/domain/entities/service_provider.dart';
import 'package:loqma/features/services/presentation/pages/service_category_page.dart';
import 'package:loqma/features/services/presentation/pages/service_provider_details_page.dart';
import 'package:loqma/features/services/presentation/pages/service_providers_map_page.dart';
import 'package:loqma/features/userhome/presentation/bloc/userhome_bloc.dart';
import 'package:loqma/features/userhome/presentation/bloc/userhome_state.dart';
import 'package:loqma/features/userhome/data/repositories/userhome_repository.dart';
import 'package:loqma/features/userhome/domain/entities/category_offer.dart';
import 'package:loqma/features/userhome/domain/user_home_policy.dart';
import 'package:loqma/features/userhome/presentation/pages/category_offers_page.dart';
import 'package:loqma/features/userhome/presentation/pages/sub_categories_page.dart'; // ✅ جديد
import 'package:loqma/features/userhome/presentation/pages/user_all_offers_page.dart';
import 'package:loqma/features/userhome/presentation/pages/user_institution_offers_page.dart';
import 'package:loqma/features/userhome/presentation/widgets/home_auxiliary_widgets.dart';
import 'package:loqma/features/userhome/presentation/widgets/home_banner_carousel.dart';
import 'package:loqma/features/userhome/presentation/widgets/home_palette.dart';
import 'package:loqma/features/userhome/presentation/widgets/home_need_widgets.dart';
import 'package:loqma/features/userhome/presentation/widgets/home_offer_widgets.dart';
import 'package:loqma/features/userhome/presentation/widgets/user_home_navigation_widgets.dart';
import 'package:loqma/routes/app_router.dart';

// ═══════════════════════════════════════════════════════════
// ✅ FEATURE FLAGS — تحكم في إظهار الميزات
// ═══════════════════════════════════════════════════════════
class _AppFeatures {
  // Food offers are published by restaurants, hotels, bakeries, cafes,
  // groceries, supermarkets, and any approved institution—not restaurants
  // only. Keep the legacy flag name for compatibility with older code.
  static const bool showRestaurants = false;
  static const bool showUrgentSection = true;

  /// نطاق المحافظة التقريبي حول موقع المستخدم (الغربية من طنطا)
  static const double nearbyRadiusKm = 70.0;
}

const Set<String> _homeRestaurantInstitutionTypes = {
  'home_restaurant',
  'home-restaurant',
  'home_restaurants',
  'home-restaurants',
};

/// Slugs used by the institution category browser; nearby offers search all types.
const Set<String> _institutionCatalogSlugs = UserHomePolicy.institutionCatalogSlugs;
const Set<String> _institutionHomeCategorySlugs = {
  'grocery',
  'supermarket',
  'bakery',
  'butcher',
  'meat_shop',
};
const Set<String> _institutionSurplusSlugs = {'hotel', 'wedding_hall'};

enum _HomeMode { buy, services }

class UserHomePage extends StatefulWidget {
  const UserHomePage({super.key});

  @override
  State<UserHomePage> createState() => _UserHomePageState();
}

class _UserHomePageState extends State<UserHomePage> {
  final InstitutionOffersRepository _institutionOffersRepository =
      InstitutionOffersRepository();
  final UserHomeRepository _userHomeRepository = UserHomeRepository(
    supabaseService: SupabaseService(),
  );
  final CommunityNeedsRepository _needsRepository = CommunityNeedsRepository();
  final ServiceCategoriesRepository _serviceCategoriesRepository =
      ServiceCategoriesRepository();
  final ServiceProvidersRepository _serviceProvidersRepository =
      ServiceProvidersRepository();
  int _currentPage = 0;
  List<InstitutionOffer> _institutionOffers = [];
  bool _loadingInstitutionOffers = false;

  // ✅ الاحتياجات
  List<Map<String, dynamic>> _communityNeeds = [];
  bool _loadingNeeds = false;

  // ✅ وضع الهوم + كاتيجوريز الخدمات
  _HomeMode _homeMode = _HomeMode.buy;
  List<ServiceCategory> _serviceCategories = [];
  bool _loadingServiceCategories = false;
  List<ServiceProvider> _nearbySymbolicProviders = [];
  List<ServiceProvider> _nearbyServiceProviders = [];
  bool _loadingNearbySymbolicProviders = false;
  final Map<String, List<CategoryOffer>> _nearbyCategoryOffers = {};
  List<Map<String, dynamic>> _nearbyMainCategories = [];
  List<Map<String, dynamic>> _institutionSubcategories = [];
  bool _loadingNearbyCategoryOffers = false;

  // ✅ موقع المستخدم
  double? _userLat;
  double? _userLng;
  String _userCity = AppConfig.defaultCity;
  String? _userGovernorate;
  bool _locationUnavailable = false;
  final Set<int> _visitedPages = {0};

  // ───────── ألوان الديزاين ─────────
  static bool get _isDark => ThemeNotifier.isDarkMode.value;
  static Color get _bg => HomePalette.bg;
  static Color get _card => HomePalette.card;
  static Color get _cardSoft => HomePalette.cardSoft;
  static Color get _primaryRed => HomePalette.primaryRed;
  static Color get _primaryRedDark => HomePalette.primaryRedDark;
  static Color get _textPrimary => HomePalette.textPrimary;
  static Color get _textSecondary => HomePalette.textSecondary;
  static Color get _border => HomePalette.border;
  static Color get _orange => const Color(0xFFFF9B45);
  static Color get _green => const Color(0xFF18B7A0);
  static Color get _blue => const Color(0xFF4C8DFF);
  static Color get _purple => const Color(0xFF7B61FF);

  static const Set<String> _hiddenCategoryKeys = {};
  bool _openingCategory = false;

  static bool get restaurantsEnabled => _AppFeatures.showRestaurants;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      // ابدأ تحميل الـHome المستقل فورًا؛ قراءة الموقع لا يجب أن تحجب أول
      // إطار أو تجعل المستخدم ينتظر قبل ظهور المحتوى الأساسي.
      context.read<UserHomeBloc>().add(const UserHomeStarted());
      _loadServiceCategories();

      await _loadUserLocation();
      if (!mounted) return;

      _loadInstitutionOffers();
      _loadNearbySymbolicProviders();
      _loadNearbyCategoryOffers();
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════
  // قراءة موقع المستخدم
  // ═══════════════════════════════════════════════════════════
  Future<void> _loadUserLocation() async {
    try {
      final authUser = SupabaseService().client.auth.currentUser;
      if (authUser == null) {
        debugPrint('⚠️ [Location] No authenticated user');
        return;
      }

      final data = await SupabaseService()
          .client
          .from('users')
          .select('latitude, longitude, city, governorate')
          .eq('id', authUser.id)
          .maybeSingle()
          .timeout(const Duration(seconds: 6));

      if (data == null || !mounted) {
        if (mounted) setState(() => _locationUnavailable = true);
        return;
      }

      final lat = (data['latitude'] as num?)?.toDouble();
      final lng = (data['longitude'] as num?)?.toDouble();
      final city = (data['city'] as String?)?.trim();
      final governorate = (data['governorate'] as String?)?.trim();

      if (lat == null || lng == null) {
        setState(() => _locationUnavailable = true);
        return;
      }

      setState(() {
        _userLat = lat;
        _userLng = lng;
        _userCity =
            (city != null && city.isNotEmpty) ? city : AppConfig.defaultCity;
        _userGovernorate =
            (governorate != null && governorate.isNotEmpty)
                ? governorate
                : null;
        _locationUnavailable = false;
      });

      debugPrint('✅ [Location] Loaded: city=$_userCity, lat=$lat, lng=$lng');
    } catch (e) {
      debugPrint('❌ [Location] error: $e');
      if (mounted) setState(() => _locationUnavailable = true);
    }
  }

  Future<void> _loadNearbySymbolicProviders() async {
    if (_loadingNearbySymbolicProviders || _userGovernorate == null) {
      return;
    }
    if (mounted) setState(() => _loadingNearbySymbolicProviders = true);

    try {
      final providers = await _serviceProvidersRepository.listNearbyProviders(
        city: _userCity,
        governorate: _userGovernorate,
      );
      if (!mounted) return;

      final sameGovernorate = providers
          .where((provider) =>
              _userGovernorate != null &&
              provider.governorate?.trim() == _userGovernorate)
          .toList();

      sameGovernorate.sort((a, b) {
        final byRating = b.ratingAvg.compareTo(a.ratingAvg);
        if (byRating != 0) return byRating;
        return b.totalReviews.compareTo(a.totalReviews);
      });

      final nearbyForMap = sameGovernorate.where((provider) {
        final lat = provider.latitude;
        final lng = provider.longitude;
        if (lat == null ||
            lng == null ||
            _userLat == null ||
            _userLng == null) {
          return false;
        }
        return _distanceKm(_userLat!, _userLng!, lat, lng) <=
            _AppFeatures.nearbyRadiusKm;
      }).toList()
        ..sort((a, b) => _distanceKm(
              _userLat!,
              _userLng!,
              a.latitude!,
              a.longitude!,
            ).compareTo(_distanceKm(
              _userLat!,
              _userLng!,
              b.latitude!,
              b.longitude!,
            )));

      setState(() {
        _nearbyServiceProviders = sameGovernorate;
        _nearbySymbolicProviders = nearbyForMap
            .where((provider) => provider.isSymbolic)
            .take(10)
            .toList();
      });
    } catch (e) {
      debugPrint('❌ [Home] nearby symbolic providers error: $e');
    } finally {
      if (mounted) setState(() => _loadingNearbySymbolicProviders = false);
    }
  }

  // ═══════════════════════════════════════════════════════════
  // حساب المسافة (Haversine)
  // ═══════════════════════════════════════════════════════════
  double _distanceKm(double lat1, double lng1, double lat2, double lng2) {
    const p = 0.017453292519943295;
    final a = 0.5 -
        math.cos((lat2 - lat1) * p) / 2 +
        math.cos(lat1 * p) *
            math.cos(lat2 * p) *
            (1 - math.cos((lng2 - lng1) * p)) /
            2;
    return 12742 * math.asin(math.sqrt(a));
  }

  (double?, double?) _extractLatLng(InstitutionOffer o) {
    try {
      final json = o.toJson();
      final lat = (json['latitude'] as num?)?.toDouble() ??
          (json['lat'] as num?)?.toDouble() ??
          (json['business_latitude'] as num?)?.toDouble();
      final lng = (json['longitude'] as num?)?.toDouble() ??
          (json['lng'] as num?)?.toDouble() ??
          (json['business_longitude'] as num?)?.toDouble();
      return (lat, lng);
    } catch (_) {
      return (null, null);
    }
  }

  // ✅ استخراج lat/lng من عرض community
  (double?, double?) _extractCommunityLatLng(Map<String, dynamic> offer) {
    final lat = (offer['latitude'] as num?)?.toDouble();
    final lng = (offer['longitude'] as num?)?.toDouble();
    return (lat, lng);
  }

  List<InstitutionOffer> _sortByDistance(List<InstitutionOffer> offers) {
    if (_userLat == null || _userLng == null || offers.isEmpty) {
      return const <InstitutionOffer>[];
    }

    final withDist = <MapEntry<InstitutionOffer, double>>[];
    for (final o in offers) {
      final (lat, lng) = _extractLatLng(o);
      if (lat == null || lng == null) continue;
      final d = _distanceKm(_userLat!, _userLng!, lat, lng);
      if (d > _AppFeatures.nearbyRadiusKm) continue;
      withDist.add(MapEntry(o, d));
    }

    if (withDist.isEmpty) return const <InstitutionOffer>[];

    withDist.sort((a, b) => a.value.compareTo(b.value));
    return withDist.map((e) => e.key).toList(growable: false);
  }

  // ✅ ترتيب وفلترة عروض community حسب القرب
  List<Map<String, dynamic>> _filterCommunityByProximity(
    List<Map<String, dynamic>> offers,
  ) {
    // لو مفيش موقع → نرجع الكل
    if (_userLat == null || _userLng == null || offers.isEmpty) {
      return offers;
    }

    final withDist = <MapEntry<Map<String, dynamic>, double>>[];

    for (final offer in offers) {
      final (lat, lng) = _extractCommunityLatLng(offer);

      if (lat == null || lng == null) {
        continue;
      }

      final d = _distanceKm(_userLat!, _userLng!, lat, lng);

      // ✅ فلترة: بس العروض اللي جوه النطاق
      if (d <= _AppFeatures.nearbyRadiusKm) {
        withDist.add(MapEntry(offer, d));
      }
    }

    withDist.sort((a, b) => a.value.compareTo(b.value));

    // ✅ حد أقصى 10 عروض
    final result = withDist.take(10).map((e) => e.key).toList(growable: false);

    debugPrint(
      '📍 [Proximity] Filtered ${offers.length} → ${result.length} offers '
      '(radius=${_AppFeatures.nearbyRadiusKm}km)',
    );

    return result;
  }

  Future<void> _loadInstitutionOffers() async {
    if (_loadingInstitutionOffers) return;
    if (mounted) setState(() => _loadingInstitutionOffers = true);

    try {
      final offers = await _institutionOffersRepository.listAvailableOffers();
      if (!mounted) return;

      final offersById = <String, InstitutionOffer>{};
      for (final offer in offers) {
        final id = offer.id.trim();
        if (id.isEmpty ||
            !offer.isActive ||
            offer.remainingQuantity <= 0) {
          continue;
        }
        offersById.putIfAbsent(id, () => offer);
      }

      final sorted = offersById.values.toList(growable: false)
        // الأولوية للعروض التي ستنتهي قريبًا، ثم الأحدث عند التساوي.
        ..sort((a, b) {
          final expiry = a.expiresAt.compareTo(b.expiresAt);
          return expiry != 0 ? expiry : b.createdAt.compareTo(a.createdAt);
        });

      setState(() => _institutionOffers = sorted);
      debugPrint('✅ Loaded institutionOffers: ${sorted.length}');
    } catch (e) {
      debugPrint('❌ loadInstitutionOffers error: $e');
      if (!mounted) return;
      setState(() => _institutionOffers = []);
    } finally {
      if (!mounted) return;
      setState(() => _loadingInstitutionOffers = false);
    }
  }


  bool _isHomeRestaurantOffer(InstitutionOffer offer) {
    final type = offer.institutionType?.trim().toLowerCase();
    return _homeRestaurantInstitutionTypes.contains(type);
  }

  bool _isVisibleInstitutionOffer(InstitutionOffer offer) {
    return UserHomePolicy.isVisibleInstitutionType(offer.institutionType);
  }

  Future<void> _loadCommunityNeeds() async {
    if (_loadingNeeds) return;
    if (mounted) setState(() => _loadingNeeds = true);

    try {
      final needs = await _needsRepository.listNeeds(
        limit: 10,
        latitude: _userLat,
        longitude: _userLng,
        radiusKm: _AppFeatures.nearbyRadiusKm,
      );
      if (!mounted) return;
      setState(() => _communityNeeds = needs);
      debugPrint('✅ Loaded communityNeeds: ${needs.length}');
    } catch (e) {
      debugPrint('❌ loadCommunityNeeds error: $e');
      if (!mounted) return;
      setState(() => _communityNeeds = []);
    } finally {
      if (!mounted) return;
      setState(() => _loadingNeeds = false);
    }
  }

  Future<void> _loadServiceCategories() async {
    if (_loadingServiceCategories) return;
    if (mounted) setState(() => _loadingServiceCategories = true);

    try {
      final cats = await _serviceCategoriesRepository.listCategories();
      if (!mounted) return;
      setState(() => _serviceCategories = cats);
    } catch (e) {
      debugPrint('❌ loadServiceCategories error: $e');
      if (!mounted) return;
      setState(() => _serviceCategories = []);
    } finally {
      if (!mounted) return;
      setState(() => _loadingServiceCategories = false);
    }
  }

  Future<void> _loadNearbyCategoryOffers() async {
    if (_loadingNearbyCategoryOffers) return;
    if (mounted) setState(() => _loadingNearbyCategoryOffers = true);
    try {
      final results = await Future.wait([
        _userHomeRepository.getMainCategories(),
        if (_userLat != null && _userLng != null)
          _userHomeRepository.getNearbyMainCategoryOffers(
            latitude: _userLat!,
            longitude: _userLng!,
            radiusKm: _AppFeatures.nearbyRadiusKm,
            limitPerCategory: 8,
          )
        else
          Future.value(<String, List<CategoryOffer>>{}),
      ]);
      final categories = results[0] as List<Map<String, dynamic>>;
      final grouped = results[1] as Map<String, List<CategoryOffer>>;
      final institutionRoot =
          categories.cast<Map<String, dynamic>?>().firstWhere(
                (category) =>
                    category?['slug']?.toString() == 'institution-offers',
                orElse: () => null,
              );
      final institutionSubcategories = institutionRoot == null
          ? <Map<String, dynamic>>[]
              : (await _userHomeRepository.getSubCategories(
                institutionRoot['id']?.toString() ?? '',
              ))
              .where((category) {
                return _institutionCatalogSlugs.contains(
                  category['slug']?.toString().trim().toLowerCase(),
                );
              })
              .toList(growable: false);
      if (institutionRoot != null) {
        // The category RPC is now the single source of truth for nearby
        // marketplace offers. Do not issue a second category query here: the
        // previous getOffersByCategory call duplicated the same institution
        // rows and made Home opening noticeably slower.
        final rootId = institutionRoot['id']?.toString() ?? '';
        var institutionOnly = (grouped[rootId] ?? const <CategoryOffer>[])
            .where((offer) => offer.ownerType == 'institution')
            .toList(growable: false);

        if (institutionOnly.isEmpty) {
          final fallback = await _userHomeRepository.getOffersByCategory(
            categoryId: rootId,
            latitude: _userLat,
            longitude: _userLng,
            radiusKm: _AppFeatures.nearbyRadiusKm,
          );
          institutionOnly = fallback
              .where((offer) => offer.ownerType == 'institution')
              .toList(growable: false);
        }

        if (institutionOnly.isNotEmpty) {
          grouped[rootId] = institutionOnly;

          // Reuse the one RPC result for child sections. The category tree is
          // cached in the repository, so this performs no extra offer reads.
          for (final category in institutionSubcategories) {
            final childId = category['id']?.toString() ?? '';
            if (childId.isEmpty) continue;
            final treeIds = await _userHomeRepository.getCategoryTreeIds(childId);
            final tree = treeIds.toSet();
            grouped[childId] = institutionOnly
                .where((offer) => tree.contains(offer.categoryId))
                .toList(growable: false);
          }
        }
      }
      if (mounted) {
        setState(() {
          _nearbyMainCategories = categories;
          _institutionSubcategories = institutionSubcategories;
          _nearbyCategoryOffers
            ..clear()
            ..addAll(grouped);
        });
      }
    } catch (e) {
      debugPrint('❌ nearby category offers error: $e');
      if (mounted) setState(() => _nearbyCategoryOffers.clear());
    } finally {
      if (mounted) setState(() => _loadingNearbyCategoryOffers = false);
    }
  }

  Future<void> _refresh() async {
    context.read<UserHomeBloc>().add(const UserHomeRefreshed());
    await _loadUserLocation();
    await Future.wait([
      _loadInstitutionOffers(),
      _loadServiceCategories(),
      _loadNearbySymbolicProviders(),
      _loadNearbyCategoryOffers(),
    ]);
  }

  bool _isHiddenCategory(Map<String, dynamic> category) {
    final slug = (category['slug'] ?? '').toString().trim().toLowerCase();
    final name = (category['name_ar'] ?? '').toString().trim().toLowerCase();
    return _hiddenCategoryKeys.contains(slug) ||
        _hiddenCategoryKeys.contains(name);
  }

  bool _isGroceryOrSupermarketCategory(Map<String, dynamic> category) {
    final slug = (category['slug'] ?? '')
        .toString()
        .trim()
        .toLowerCase()
        .replaceAll('_', '-')
        .replaceAll(' ', '-');
    final name = (category['name_ar'] ?? '').toString().trim().toLowerCase();
    const excludedSlugs = {
      'grocery',
      'supermarket',
      'groceries',
      'grocery-supermarket',
      'grocery-and-supermarket',
    };
    return excludedSlugs.contains(slug) ||
        name.contains('بقال') ||
        (name.contains('سوبر') && name.contains('ماركت'));
  }

  bool _isRestaurantCategory(Map<String, dynamic> category) {
    final slug = (category['slug'] ?? '').toString().trim().toLowerCase();
    final name = (category['name_ar'] ?? '').toString().trim();
    if (slug == 'home-restaurants' || name.contains('مطاعم منزلية')) {
      return false;
    }
    return slug == 'food' ||
        name.contains('مطعم') ||
        name.contains('مطاعم') ||
        name.contains('أطعمة') ||
        name.contains('مأكولات') ||
        name.contains('اكل') ||
        name.contains('أكل');
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: BlocConsumer<UserHomeBloc, UserHomeState>(
        listener: (context, state) {
          if (state is UserHomeError) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: _card,
                  behavior: SnackBarBehavior.floating,
                  margin: const EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              );
          }
        },
        builder: (context, state) {
          if (state is UserHomeLoading) return const HomeLoading();
          if (state is UserHomeUnauthenticated) {
            return _buildUnauthenticated();
          }
          if (state is UserHomeError) return _buildError(state.message);
          if (state is UserHomeLoaded) return _buildLoadedHome(state);
          return const HomeLoading();
        },
      ),
    );
  }

  Widget _buildUnauthenticated() {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [_primaryRed, _primaryRedDark],
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _primaryRed.withValues(alpha: 0.4),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Icon(Icons.lock_outline_rounded,
                      size: 44, color: Colors.white),
                ),
                SizedBox(height: 32),
                Text(
                  'أهلًا بيك في Khedma 👋',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _textPrimary,
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 14),
                Text(
                  'سجّل دخولك علشان تكتشف العروض القريبة منك وتشارك في مجتمع Khedma.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _textSecondary,
                    fontSize: 14.5,
                    height: 1.6,
                  ),
                ),
                SizedBox(height: 36),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () => context.go(AppRouter.login),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryRed,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      'تسجيل الدخول',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildError(String message) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 92,
                  height: 92,
                  decoration: BoxDecoration(
                    color: _card,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.cloud_off_rounded,
                      size: 42, color: _primaryRed),
                ),
                SizedBox(height: 28),
                Text(
                  'حصلت مشكلة بسيطة',
                  style: TextStyle(
                    color: _textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _textSecondary,
                    height: 1.6,
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: () {
                    context.read<UserHomeBloc>().add(const UserHomeStarted());
                  },
                  icon: Icon(Icons.refresh_rounded),
                  label: Text('إعادة المحاولة'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryRed,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 26, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadedHome(UserHomeLoaded state) {
    return Scaffold(
      backgroundColor: _bg,
      body: IndexedStack(
        index: _currentPage,
        children: List<Widget>.generate(5, (index) {
          if (!_visitedPages.contains(index)) {
            return const SizedBox.shrink();
          }
          switch (index) {
            case 0:
              return _buildHomeContent(state);
            case 1:
              return _buildCategoriesContent(state);
            case 2:
              return const CommunityNeedsPage();
            case 3:
              return const CommunityTrackingPage();
            case 4:
              return const ProfilePage();
            default:
              return const SizedBox.shrink();
          }
        }),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
      floatingActionButton: _currentPage == 0
          ? Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _buildAddButton(),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildCategoriesContent(UserHomeLoaded state) {
    final bool isServices = _homeMode == _HomeMode.services;

    final buyCategories = state.categories.where((c) {
      if (_isHiddenCategory(c) || _isGroceryOrSupermarketCategory(c)) return false;
      if (!_AppFeatures.showRestaurants && _isRestaurantCategory(c)) {
        return false;
      }
      return true;
    }).toList();

    final serviceCats = _serviceCategories;

    return SafeArea(
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 14),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isServices
                            ? [_blue, _purple]
                            : [_primaryRed, _primaryRedDark],
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: (isServices ? _blue : _primaryRed)
                              .withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Icon(
                      isServices
                          ? Icons.handyman_rounded
                          : Icons.grid_view_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          isServices ? 'خدمات Khedma' : 'أقسام Khedma',
                          style: TextStyle(
                            color: _textPrimary,
                            fontSize: 21,
                            fontWeight: FontWeight.w900,
                            height: 1.1,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          isServices
                              ? 'محترفين في كل المجالات'
                              : 'تصفح كل فئات الشراء',
                          style: TextStyle(
                            color: _textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: _card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _border, width: 1),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildCategoriesSwitcherTile(
                        mode: _HomeMode.buy,
                        iconAsset: 'assets/icons/flaticon/shopping-basket.png',
                        label: 'أقسام الشراء',
                        count: buyCategories.length,
                        color: _primaryRed,
                      ),
                    ),
                    SizedBox(width: 4),
                    Expanded(
                      child: _buildCategoriesSwitcherTile(
                        mode: _HomeMode.services,
                        iconAsset: 'assets/icons/flaticon/repair-shop.png',
                        label: 'أقسام الخدمات',
                        count: serviceCats.length,
                        color: _blue,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (isServices)
            serviceCats.isEmpty
                ? SliverFillRemaining(
                    hasScrollBody: false,
                    child: _buildServiceCategoriesEmpty(),
                  )
                : SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
                    sliver: SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: 14,
                        crossAxisSpacing: 14,
                        childAspectRatio: 0.92,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          return _buildServiceCategoryTile(serviceCats[index]);
                        },
                        childCount: serviceCats.length,
                      ),
                    ),
                  )
          else
            buyCategories.isEmpty
                ? SliverFillRemaining(
                    hasScrollBody: false,
                    child: _buildCategoriesEmpty(),
                  )
                : SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
                    sliver: SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: 14,
                        crossAxisSpacing: 14,
                        childAspectRatio: 0.92,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          return _buildCategoryTile(
                              buyCategories[index], state);
                        },
                        childCount: buyCategories.length,
                      ),
                    ),
                  ),
          if (isServices)
            SliverToBoxAdapter(child: _buildNearbyServiceProvidersSection()),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _buildCategoriesSwitcherTile({
    required _HomeMode mode,
    required String iconAsset,
    required String label,
    required int count,
    required Color color,
  }) {
    final selected = _homeMode == mode;

    return GestureDetector(
      onTap: () {
        if (_homeMode != mode) {
          setState(() => _homeMode = mode);
        }
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          gradient: selected
              ? LinearGradient(
                  colors: [color, color.withValues(alpha: 0.75)],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                )
              : null,
          color: selected ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              iconAsset,
              width: 22,
              height: 22,
              fit: BoxFit.contain,
            ),
            SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: selected ? Colors.white : _textPrimary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                  ),
                ),
                SizedBox(height: 1),
                Text(
                  '$count قسم',
                  style: TextStyle(
                    color: selected
                        ? Colors.white.withValues(alpha: 0.85)
                        : _textSecondary,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoriesEmpty() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 84,
            height: 84,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _card,
              shape: BoxShape.circle,
              border: Border.all(color: _border, width: 1),
            ),
            child: Icon(
              Icons.grid_view_rounded,
              color: _textSecondary.withValues(alpha: 0.7),
              size: 36,
            ),
          ),
          SizedBox(height: 18),
          Text(
            'مفيش أقسام متاحة دلوقتي',
            style: TextStyle(
              color: _textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'جرّب تحدّث الصفحة بعد شوية',
            style: TextStyle(color: _textSecondary, fontSize: 12.5),
          ),
        ],
      ),
    );
  }

  Widget _buildHomeContent(UserHomeLoaded state) {
    return SafeArea(
      child: RefreshIndicator(
        color: _primaryRed,
        backgroundColor: _card,
        onRefresh: _refresh,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.025),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          ),
          child: KeyedSubtree(
            key: ValueKey<_HomeMode>(_homeMode),
            child: _homeMode == _HomeMode.buy
                ? _buildBuyContent(state)
                : _buildServicesContent(),
          ),
        ),
      ),
    );
  }

  Widget _buildBuyContent(UserHomeLoaded state) {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      slivers: [
        if (_locationUnavailable)
          SliverToBoxAdapter(child: _buildLocationUnavailableNotice()),
        SliverToBoxAdapter(child: _buildHeader()),
        SliverToBoxAdapter(child: _buildModeSwitcher()),
        if (state.banners.isNotEmpty)
          SliverToBoxAdapter(child: HomeBannerCarousel(banners: state.banners)),
        SliverToBoxAdapter(child: _buildStoreCategoriesTitle()),
        SliverToBoxAdapter(child: _buildMarketplaceCategoriesStrip(state)),
        SliverToBoxAdapter(child: _buildInstitutionsHomeSection(state)),
        SliverToBoxAdapter(child: _buildInstitutionSurplusHomeSection(state)),
        SliverToBoxAdapter(child: _buildOffersTitle()),
        SliverToBoxAdapter(child: _buildNearbyCategorySections(state)),
        SliverToBoxAdapter(child: SizedBox(height: 120)),
      ],
    );
  }

  Widget _buildLocationUnavailableNotice() {
    return UserHomeLocationNotice(
      cardColor: _card,
      orangeColor: _orange,
      textPrimaryColor: _textPrimary,
      primaryColor: _primaryRed,
      onChooseLocation: () => context.go('/map'),
    );
  }

  Widget _buildServicesContent() {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      slivers: [
        if (_locationUnavailable)
          SliverToBoxAdapter(child: _buildLocationUnavailableNotice()),
        SliverToBoxAdapter(child: _buildHeader()),
        SliverToBoxAdapter(child: _buildModeSwitcher()),
        SliverToBoxAdapter(child: _buildServicesMapPreview()),
        SliverToBoxAdapter(child: _buildHomeServiceCategoriesCarousel()),
        SliverToBoxAdapter(child: _buildAutoTopRatedServiceCategorySections()),
        SliverToBoxAdapter(child: SizedBox(height: 120)),
      ],
    );
  }

  Widget _buildModeSwitcher() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _border, width: 1),
        ),
        child: Row(
          children: [
            Expanded(
              child: _buildModeTile(
                mode: _HomeMode.buy,
                icon: Icons.shopping_bag_rounded,
                label: 'أقسام الشراء',
                subtitle: 'تصفح المنتجات والعروض',
                color: _primaryRed,
              ),
            ),
            SizedBox(width: 4),
            Expanded(
              child: _buildModeTile(
                mode: _HomeMode.services,
                icon: Icons.handyman_rounded,
                label: 'الخدمات',
                subtitle: 'الأقسام ومقدمو الخدمة',
                color: _blue,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeTile({
    required _HomeMode mode,
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
  }) {
    final selected = _homeMode == mode;

    return GestureDetector(
      onTap: () {
        if (_homeMode != mode) {
          setState(() => _homeMode = mode);
        }
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          gradient: selected
              ? LinearGradient(
                  colors: [color, color.withValues(alpha: 0.75)],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                )
              : null,
          color: selected ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: selected ? Colors.white : _textSecondary,
            ),
            SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: selected ? Colors.white : _textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                  ),
                ),
                SizedBox(height: 1),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: selected
                        ? Colors.white.withValues(alpha: 0.85)
                        : _textSecondary,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServicesMapPreview() {
    final providers = _nearbyServiceProviders
        .where((provider) =>
            provider.latitude != null && provider.longitude != null)
        .toList(growable: false);
    final center = _serviceProvidersMapCenter(providers);
    final zoom = _serviceProvidersMapZoom(providers);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'مقدمو الخدمات على الخريطة',
                      style: TextStyle(
                        color: _textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _userGovernorate ?? 'مقدمو الخدمة في منطقتك',
                      style: TextStyle(
                        color: _textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: _blue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _blue.withValues(alpha: 0.22)),
                ),
                child: Text(
                  '${providers.length} مقدم',
                  style: TextStyle(
                    color: _blue,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Material(
            color: _card,
            borderRadius: BorderRadius.circular(24),
            clipBehavior: Clip.antiAlias,
            child: Container(
              height: 236,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: _border),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  FlutterMap(
                    options: MapOptions(
                      initialCenter: center,
                      initialZoom: zoom,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.khedma.app',
                      ),
                      MarkerLayer(
                        markers: providers.map((provider) {
                          return Marker(
                            point: LatLng(provider.latitude!, provider.longitude!),
                            width: 42,
                            height: 54,
                            child: GestureDetector(
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => ServiceProviderDetailsPage(
                                    provider: provider,
                                  ),
                                ),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: provider.isCompany ? _primaryRed : _blue,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 2.5,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.22),
                                          blurRadius: 7,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      provider.isCompany
                                          ? Icons.business_rounded
                                          : Icons.handyman_rounded,
                                      color: Colors.white,
                                      size: 17,
                                    ),
                                  ),
                                  Icon(
                                    Icons.arrow_drop_down_rounded,
                                    color: provider.isCompany ? _primaryRed : _blue,
                                    size: 16,
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(growable: false),
                      ),
                    ],
                  ),
                  Positioned(
                    top: 11,
                    right: 11,
                    child: _mapOverlayPill(
                      icon: Icons.location_on_rounded,
                      label: _userGovernorate ?? _userCity,
                    ),
                  ),
                  if (_loadingNearbySymbolicProviders)
                    Positioned(
                      top: 11,
                      left: 11,
                      child: _mapOverlayPill(
                        icon: Icons.sync_rounded,
                        label: 'جاري تحميل مقدمي الخدمة',
                      ),
                    ),
                  if (providers.isEmpty && !_loadingNearbySymbolicProviders)
                    Center(
                      child: Container(
                        margin: const EdgeInsets.all(52),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: _card.withValues(alpha: 0.94),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: _border),
                        ),
                        child: Text(
                          'لا يوجد مقدمو خدمة بموقع مسجل في المحافظة حاليًا',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _textPrimary,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  if (providers.isNotEmpty)
                    Positioned(
                      bottom: 11,
                      left: 11,
                      child: Material(
                        color: _card,
                        borderRadius: BorderRadius.circular(13),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(13),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ServiceProvidersMapPage(
                                providers: providers,
                                latitude: center.latitude,
                                longitude: center.longitude,
                                city: _userGovernorate ?? _userCity,
                              ),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 11,
                              vertical: 9,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.open_in_full_rounded,
                                    color: _blue, size: 15),
                                const SizedBox(width: 6),
                                Text(
                                  'افتح الخريطة',
                                  style: TextStyle(
                                    color: _textPrimary,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _mapOverlayPill({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: _card.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: _blue, size: 14),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: _textPrimary,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  LatLng _serviceProvidersMapCenter(List<ServiceProvider> providers) {
    final located = providers
        .where((provider) => provider.latitude != null && provider.longitude != null)
        .toList(growable: false);
    if (located.isEmpty) {
      return LatLng(
        _userLat ?? AppConfig.defaultLat,
        _userLng ?? AppConfig.defaultLng,
      );
    }

    var minLat = located.first.latitude!;
    var maxLat = minLat;
    var minLng = located.first.longitude!;
    var maxLng = minLng;
    for (final provider in located.skip(1)) {
      minLat = minLat < provider.latitude! ? minLat : provider.latitude!;
      maxLat = maxLat > provider.latitude! ? maxLat : provider.latitude!;
      minLng = minLng < provider.longitude! ? minLng : provider.longitude!;
      maxLng = maxLng > provider.longitude! ? maxLng : provider.longitude!;
    }
    return LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2);
  }

  double _serviceProvidersMapZoom(List<ServiceProvider> providers) {
    final located = providers
        .where((provider) => provider.latitude != null && provider.longitude != null)
        .toList(growable: false);
    if (located.length < 2) return 12.5;

    var minLat = located.first.latitude!;
    var maxLat = minLat;
    var minLng = located.first.longitude!;
    var maxLng = minLng;
    for (final provider in located.skip(1)) {
      minLat = minLat < provider.latitude! ? minLat : provider.latitude!;
      maxLat = maxLat > provider.latitude! ? maxLat : provider.latitude!;
      minLng = minLng < provider.longitude! ? minLng : provider.longitude!;
      maxLng = maxLng > provider.longitude! ? maxLng : provider.longitude!;
    }
    final span = (maxLat - minLat) > (maxLng - minLng)
        ? maxLat - minLat
        : maxLng - minLng;
    if (span > 2.0) return 7.0;
    if (span > 1.0) return 8.0;
    if (span > 0.55) return 9.0;
    if (span > 0.30) return 10.0;
    if (span > 0.15) return 11.0;
    if (span > 0.07) return 12.0;
    return 13.0;
  }

  Widget _buildHomeServiceCategoriesCarousel() {
    if (_loadingServiceCategories && _serviceCategories.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_serviceCategories.isEmpty) return _buildServiceCategoriesEmpty();

    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Text(
              'أقسام الخدمات',
              style: TextStyle(
                color: _textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 122,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: _serviceCategories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) =>
                  _buildHomeServiceCategoryCarouselTile(
                _serviceCategories[index],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHomeServiceCategoryCarouselTile(ServiceCategory category) {
    return SizedBox(
      width: 155,
      child: Material(
        color: _card,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _openServiceCategory(category),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _border),
              gradient: LinearGradient(
                colors: [_blue.withValues(alpha: 0.12), _card],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: _blue.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _serviceIconFromSlug(category.slug),
                    color: _blue,
                    size: 23,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  category.nameAr,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _textPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAutoTopRatedServiceCategorySections() {
    if (_userGovernorate == null) {
      return _section(
        title: 'مقدمو الخدمات الأعلى تقييمًا',
        child: _emptyMini(
          Icons.location_city_rounded,
          'أضف محافظتك في الملف الشخصي لعرض مقدمي الخدمة منها',
        ),
      );
    }
    if (_loadingServiceCategories && _serviceCategories.isEmpty) {
      return _section(
        title: 'مقدمو الخدمات في $_userGovernorate',
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      );
    }

    final providersByCategory = <String, List<ServiceProvider>>{};
    for (final provider in _nearbyServiceProviders) {
      if (provider.governorate?.trim() != _userGovernorate) continue;
      providersByCategory
          .putIfAbsent(provider.categoryId, () => <ServiceProvider>[])
          .add(provider);
    }
    for (final providers in providersByCategory.values) {
      providers.sort((a, b) {
        final byRating = b.ratingAvg.compareTo(a.ratingAvg);
        if (byRating != 0) return byRating;
        return b.totalReviews.compareTo(a.totalReviews);
      });
    }

    // Keep the home service sections focused on the requested trades.
    const requestedOrder = [
      'plumbing',
      'satellite',
      'electrical',
      'painting',
      'cooling',
      'tiles',
    ];
    final requestedCategories = <ServiceCategory>[];
    for (final key in requestedOrder) {
      for (final category in _serviceCategories) {
        if (_homeServiceCategoryGroup(category) == key) {
          requestedCategories.add(category);
          break;
        }
      }
    }

    if (requestedCategories.isEmpty) {
      return _section(
        title: 'مقدمو الخدمات في $_userGovernorate',
        child: _emptyMini(
          Icons.handyman_rounded,
          'الأقسام المطلوبة مش متاحة حاليًا',
        ),
      );
    }
    if (_loadingNearbySymbolicProviders && _nearbyServiceProviders.isEmpty) {
      return _section(
        title: 'أفضل مقدمي الخدمة في $_userGovernorate',
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      );
    }

    return Column(
      children: requestedCategories.map((category) {
        final providers = providersByCategory[category.id] ??
            const <ServiceProvider>[];
        return _section(
          title: 'الأعلى تقييمًا في ${category.nameAr}',
          trailing: Text(
            _userGovernorate!,
            style: TextStyle(
              color: _textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          child: providers.isEmpty
              ? _emptyMini(
                  Icons.handyman_rounded,
                  'لا يوجد مقدمو خدمة في المحافظة دي حاليًا',
                )
              : _buildServiceProviderCards(providers.take(10).toList()),
        );
      }).toList(growable: false),
    );
  }

  String? _homeServiceCategoryGroup(ServiceCategory category) {
    final slug = category.slug.trim().toLowerCase().replaceAll('_', '-');
    final name = category.nameAr.trim().toLowerCase();

    if (slug.contains('plumb') ||
        name.contains('سباك') ||
        name.contains('أدوات صحية')) {
      return 'plumbing';
    }
    if (slug.contains('satellite') ||
        slug.contains('receiver') ||
        slug.contains('dish') ||
        name.contains('دش') ||
        name.contains('رسيفر') ||
        name.contains('ريسيفر')) {
      return 'satellite';
    }
    if (slug.contains('electric') ||
        name.contains('كهربا') ||
        name.contains('كهرباء')) {
      return 'electrical';
    }
    if (slug.contains('paint') ||
        name.contains('دهان') ||
        name.contains('نقاش')) {
      return 'painting';
    }
    if (slug.contains('air-condition') ||
        slug.contains('aircondition') ||
        slug.contains('cooling') ||
        slug.contains('refrigerat') ||
        slug.contains('hvac') ||
        name.contains('تكييف') ||
        name.contains('تبريد')) {
      return 'cooling';
    }
    if (slug.contains('ceramic') ||
        slug.contains('tile') ||
        slug.contains('flooring') ||
        name.contains('سيراميك') ||
        name.contains('بلاط')) {
      return 'tiles';
    }
    return null;
  }

  Widget _buildServiceCategoryTile(ServiceCategory cat) {
    return Material(
      color: _card,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _openServiceCategory(cat),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _border, width: 1),
          ),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _blue.withValues(alpha: 0.18),
                      _blue.withValues(alpha: 0.06),
                    ],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _serviceIconFromSlug(cat.slug),
                  color: _blue,
                  size: 22,
                ),
              ),
              SizedBox(height: 9),
              Flexible(
                child: Text(
                  cat.nameAr,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _textPrimary,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildServiceCategoriesEmpty() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 60),
      child: Column(
        children: [
          Container(
            width: 84,
            height: 84,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _card,
              shape: BoxShape.circle,
              border: Border.all(color: _border, width: 1),
            ),
            child: Icon(
              Icons.handyman_rounded,
              color: _textSecondary.withValues(alpha: 0.7),
              size: 36,
            ),
          ),
          SizedBox(height: 18),
          Text(
            'مفيش خدمات متاحة دلوقتي',
            style: TextStyle(
              color: _textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'جرّب تحدّث الصفحة بعد شوية',
            style: TextStyle(color: _textSecondary, fontSize: 12.5),
          ),
        ],
      ),
    );
  }

  void _openServiceCategory(ServiceCategory cat) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ServiceCategoryPage(category: cat),
      ),
    );
  }

  IconData _serviceIconFromSlug(String slug) {
    switch (slug.trim().toLowerCase()) {
      case 'plumbing':
        return Icons.plumbing_rounded;
      case 'electricity':
        return Icons.electrical_services_rounded;
      case 'painting':
        return Icons.format_paint_rounded;
      case 'carpentry':
        return Icons.handyman_rounded;
      case 'aluminum':
        return Icons.window_rounded;
      case 'air_conditioning':
        return Icons.ac_unit_rounded;
      case 'appliances':
        return Icons.kitchen_rounded;
      case 'water_heaters':
        return Icons.water_drop_rounded;
      case 'satellite':
        return Icons.satellite_alt_rounded;
      case 'locks':
        return Icons.lock_rounded;
      case 'moving':
      case 'transportation':
      case 'delivery':
      case 'packaging':
        return Icons.local_shipping_rounded;
      case 'furniture_assembly':
        return Icons.chair_rounded;
      case 'cleaning':
      case 'professional_cleaning':
        return Icons.cleaning_services_rounded;
      case 'pest_control':
        return Icons.bug_report_rounded;
      case 'gardening':
      case 'agriculture':
        return Icons.grass_rounded;
      case 'waterproofing':
      case 'construction':
        return Icons.construction_rounded;
      case 'gypsum_board':
      case 'interior_design':
      case 'decoration':
        return Icons.architecture_rounded;
      case 'tiles':
        return Icons.grid_view_rounded;
      case 'welding':
        return Icons.local_fire_department_rounded;
      case 'car_mechanic':
      case 'car_bodywork':
      case 'car_inspection':
        return Icons.build_rounded;
      case 'car_electrician':
        return Icons.battery_charging_full_rounded;
      case 'car_ac':
        return Icons.ac_unit_rounded;
      case 'car_wash':
        return Icons.local_car_wash_rounded;
      case 'tires':
        return Icons.tire_repair_rounded;
      case 'car':
      case 'real_estate':
        return Icons.directions_car_rounded;
      case 'mobile_repair':
        return Icons.smartphone_rounded;
      case 'computer_repair':
      case 'software_services':
      case 'networking':
        return Icons.computer_rounded;
      case 'cameras_security':
      case 'photography':
        return Icons.camera_alt_rounded;
      case 'graphic_design':
        return Icons.brush_rounded;
      case 'beauty_salon':
        return Icons.spa_rounded;
      case 'barber':
        return Icons.content_cut_rounded;
      case 'tailoring':
        return Icons.checkroom_rounded;
      case 'laundry':
        return Icons.local_laundry_service_rounded;
      case 'massage':
        return Icons.self_improvement_rounded;
      case 'fitness':
        return Icons.fitness_center_rounded;
      case 'nutrition':
      case 'catering':
        return Icons.restaurant_rounded;
      case 'private_tutoring':
        return Icons.menu_book_rounded;
      case 'languages':
      case 'translation':
        return Icons.translate_rounded;
      case 'accounting':
        return Icons.receipt_long_rounded;
      case 'legal_consulting':
        return Icons.gavel_rounded;
      case 'business_consulting':
        return Icons.business_center_rounded;
      case 'marketing':
        return Icons.campaign_rounded;
      case 'recruitment':
        return Icons.groups_rounded;
      case 'event_planning':
        return Icons.celebration_rounded;
      case 'printing':
        return Icons.print_rounded;
      case 'pet_care':
      case 'veterinary':
        return Icons.pets_rounded;
      case 'security':
      case 'insurance':
        return Icons.shield_rounded;
      case 'other':
        return Icons.add_circle_outline_rounded;
      case 'maintenance':
      case 'it':
      case 'garden':
      case 'tutoring':
      case 'beauty':
      case 'ac':
      case 'electrical':
        return Icons.handyman_rounded;
      default:
        return Icons.handyman_rounded;
    }
  }

  Widget _buildHeader() {
    final metadata = SupabaseService().client.auth.currentUser?.userMetadata ?? const <String, dynamic>{};
    final displayName = (metadata['full_name'] ?? metadata['name'] ?? 'Abdalla Mohamed').toString();
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
      child: Row(
        children: [
          _headerIconButton(Icons.bookmark_border_rounded, () {}),
          const SizedBox(width: 10),
          _buildHeaderNotificationButton(),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: _textPrimary, fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text('أهلاً بيك في Khedma', style: TextStyle(color: _textSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 42,
            height: 42,
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(color: _cardSoft, shape: BoxShape.circle, border: Border.all(color: _border)),
            child: Image.asset('assets/images/khedma_icon.png', fit: BoxFit.cover),
          ),
        ],
      ),
    );
  }

  Widget _headerIconButton(IconData icon, VoidCallback onTap) {
    return Material(
      color: _card,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: SizedBox(width: 48, height: 48, child: Icon(icon, color: _textPrimary, size: 24)),
      ),
    );
  }
  Widget _buildHeaderNotificationButton() {
    return Material(
      color: _card,
      borderRadius: BorderRadius.circular(17),
      child: InkWell(
        borderRadius: BorderRadius.circular(17),
        onTap: () {
          final user = SupabaseService().client.auth.currentUser;
          if (user == null) return;
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => NotificationsPage(userId: user.id),
            ),
          );
        },
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(17),
            border: Border.all(color: _border),
            boxShadow: [
              BoxShadow(
                color: _primaryRed.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Icon(
            Icons.notifications_none_rounded,
            color: _textPrimary,
            size: 23,
          ),
        ),
      ),
    );
  }

  Widget _buildCompanySectionTitle() => _referenceSectionTitle('عروض مؤسسات قريبة منك', 'عرض الكل');
  Widget _buildStoreCategoriesTitle() => _referenceSectionTitle('أقسام الشراء', null);
  Widget _buildOffersTitle() => _referenceSectionTitle('العروض', 'عرض الكل');

  Widget _referenceSectionTitle(String title, String? action) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 10),
      child: Row(
        children: [
          if (action != null) Text(action, style: TextStyle(color: _primaryRed, fontSize: 13, fontWeight: FontWeight.w800)),
          const Spacer(),
          Text(title, style: TextStyle(color: _textPrimary, fontSize: 20, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  Widget _buildMarketplaceCategoriesStrip(UserHomeLoaded state) {
    final categories = state.categories.where((c) {
      if (_isHiddenCategory(c) || _isGroceryOrSupermarketCategory(c)) return false;
      if (!_AppFeatures.showRestaurants && _isRestaurantCategory(c)) return false;
      return true;
    }).take(10).toList(growable: false);
    if (categories.isEmpty) return const SizedBox(height: 16);
    return SizedBox(
      height: 112,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final category = categories[index];
          final color = [ _orange, _primaryRed, _purple, _green, _blue ][index % 5];
          return GestureDetector(
            onTap: () => _openCategory(category),
            child: SizedBox(
              width: 74,
              child: Column(
                children: [
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(color: color.withValues(alpha: .18), borderRadius: BorderRadius.circular(19)),
                    child: Icon(_iconFromName(category['icon']?.toString() ?? ''), color: color, size: 30),
                  ),
                  const SizedBox(height: 7),
                  Text(category['name_ar']?.toString() ?? 'قسم', maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: TextStyle(color: _textPrimary, fontSize: 11, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLocationRow(UserHomeLoaded state) {
    final hasLocation = _userLat != null && _userLng != null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(100),
              border: Border.all(color: _border, width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.location_on_rounded, color: _primaryRed, size: 15),
                SizedBox(width: 6),
                Text(
                  _userCity,
                  style: TextStyle(
                    color: _textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (hasLocation) ...[
                  SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _green.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(
                        color: _green.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.near_me_rounded, color: _green, size: 10),
                        SizedBox(width: 3),
                        Text(
                          'قريب منك',
                          style: TextStyle(
                            color: _green,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompanyOffersSlider() {
    // كروت أفقية مضغوطة بدل بانر رأسي كبير حتى يظهر محتوى أكبر في الشاشة.
    // عروض مطاعم البيت لها قسمها المخصص؛ لا تعرضها مرة ثانية هنا.
    final offers = _institutionOffers
        .where((offer) =>
            !_isHomeRestaurantOffer(offer) && _isVisibleInstitutionOffer(offer))
        .take(8)
        .toList(growable: false);
    if (_loadingInstitutionOffers && offers.isEmpty) {
      return const SizedBox(
        height: 196,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2.2)),
      );
    }

    if (offers.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
      child: SizedBox(
        height: 190,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          itemCount: offers.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (_, index) => SizedBox(
            width: 258,
            child: _buildCompanyOfferCard(offers[index]),
          ),
        ),
      ),
    );
  }

  Widget _buildCompanyOfferCard(InstitutionOffer offer) {
    return Material(
      color: _card,
      borderRadius: BorderRadius.circular(28),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => InstitutionOfferDetailsPage(offer: offer),
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (offer.firstImage != null)
              CachedNetworkImage(
                imageUrl: offer.firstImage!,
                fit: BoxFit.cover,
                memCacheWidth: 1080,
                maxWidthDiskCache: 1080,
                errorWidget: (_, __, ___) => _buildCompanyOfferBackdrop(),
              )
            else
              _buildCompanyOfferBackdrop(),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.08),
                    Colors.black.withValues(alpha: 0.18),
                    Colors.black.withValues(alpha: 0.9),
                  ],
                  stops: const [0, 0.42, 1],
                ),
              ),
            ),
            Positioned(
              top: 14,
              right: 14,
              child: _offerGlassPill(Icons.campaign_rounded, 'عرض من مؤسسة'),
            ),
            Positioned(
              top: 14,
              left: 14,
              child:
                  _offerGlassPill(Icons.schedule_rounded, offer.timeRemaining),
            ),
            Positioned(
              left: 18,
              right: 18,
              bottom: 14,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    offer.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 21,
                      height: 1.08,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                        backgroundImage: offer.institutionLogoUrl != null
                            ? CachedNetworkImageProvider(
                                offer.institutionLogoUrl!)
                            : null,
                        child: offer.institutionLogoUrl == null
                            ? const Icon(Icons.business_rounded,
                                color: Colors.white, size: 16)
                            : null,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          offer.institutionName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      _offerPricePill(offer),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompanyOfferBackdrop() {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [_textPrimary, _cardSoft],
        ),
      ),
      child: Icon(
        Icons.storefront_rounded,
        size: 86,
        color: _textSecondary.withValues(alpha: 0.35),
      ),
    );
  }

  Widget _offerGlassPill(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.36),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _offerPricePill(InstitutionOffer offer) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        offer.symbolicPrice <= 0
            ? 'مجاني'
            : '${offer.symbolicPrice.toStringAsFixed(0)} ج.م',
        style: const TextStyle(
          color: Colors.black,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _buildCategoriesGrid(UserHomeLoaded state) {
    if (state.categoriesLoading && state.categories.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 30),
        child: Center(
          child: CircularProgressIndicator(color: _primaryRed),
        ),
      );
    }

    final sourceCategories =
        state.categories.isNotEmpty ? state.categories : _nearbyMainCategories;
    final categories = sourceCategories.where((c) {
      if (_isHiddenCategory(c)) return false;
      if (!_AppFeatures.showRestaurants && _isRestaurantCategory(c)) {
        return false;
      }
      return true;
    }).toList();

    if (categories.isEmpty) {
      return SizedBox.shrink();
    }

    final isScrollable = categories.length > 9;

    if (!isScrollable) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 22),
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            childAspectRatio: 0.95,
          ),
          itemCount: categories.length,
          itemBuilder: (context, index) {
            return _buildCategoryTile(categories[index], state);
          },
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: SizedBox(
        height: 240,
        child: GridView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          physics: const BouncingScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            childAspectRatio: 0.9,
          ),
          itemCount: categories.length,
          itemBuilder: (context, index) {
            return SizedBox(
              width: 115,
              child: _buildCategoryTile(categories[index], state),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCategoryTile(
    Map<String, dynamic> category,
    UserHomeLoaded state,
  ) {
    final id = category['id']?.toString() ?? '';
    final name = category['name_ar']?.toString() ?? 'تصنيف';
    final iconName = category['icon']?.toString() ?? '';

    if (id.isEmpty) return SizedBox.shrink();

    return Material(
      color: _card,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _openCategory(category),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _border, width: 1),
          ),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _primaryRed.withValues(alpha: 0.18),
                      _primaryRed.withValues(alpha: 0.06),
                    ],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _iconFromName(iconName),
                  color: _primaryRed,
                  size: 22,
                ),
              ),
              SizedBox(height: 9),
              Flexible(
                child: Text(
                  name,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _textPrimary,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // ✅ فتح تصنيف
  // ═══════════════════════════════════════════════════════════
  void _openCategory(
    Map<String, dynamic> category,
  ) {
    final id = (category['id']?.toString() ?? '').trim();
    final name = category['name_ar']?.toString() ?? '';
    final slug = (category['slug']?.toString() ?? '').trim();

    if (id.isEmpty) return;
    FocusManager.instance.primaryFocus?.unfocus();

    final isRestaurant = _isRestaurantCategory(category);

    // ─── مطعم ───
    if (isRestaurant) {
      if (!_AppFeatures.showRestaurants) return;

      final filtered = _institutionOffers
          .where((o) => (o.marketplaceCategoryId ?? '').trim() == id)
          .toList(growable: false);

      final foodOffers = filtered
          .map((o) => _institutionToFoodOffer(o, businessType: 'restaurant'))
          .toList(growable: false);

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => UserAllOffersPage(offers: foodOffers),
        ),
      );
      return;
    }

    // ─── تصنيف عادي → فحص الفروع أول ───
    _openSmartCategory(id, name, slug);
  }

  // ✅ دالة ذكية: تتحقق من وجود فروع
  Future<void> _openSmartCategory(
    String id,
    String name,
    String slug,
  ) async {
    if (_openingCategory || id.isEmpty) return;
    _openingCategory = true;
    bool hasChildren = false;
    try {
      final response = await SupabaseService()
          .client
          .from('marketplace_categories')
          .select('id')
          .eq('parent_id', id)
          .eq('is_active', true)
          .limit(1)
          .timeout(const Duration(seconds: 6));

      hasChildren = (response as List).isNotEmpty;
    } catch (e) {
      debugPrint('❌ [openSmartCategory] error: $e');
      hasChildren = false;
    }

    if (!mounted) return;

    if (hasChildren) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => SubCategoriesPage(
            parentId: id,
            parentName: name,
            parentSlug: slug,
          ),
        ),
      );
    } else {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CategoryOffersPage(
            categoryId: id,
            categoryName: name,
            categorySlug: slug,
          ),
        ),
      );
    }
    if (mounted) _openingCategory = false;
  }

  FoodOffer _institutionToFoodOffer(
    InstitutionOffer o, {
    String businessType = 'restaurant',
  }) {
    final (offerLat, offerLng) = _extractLatLng(o);

    final lat = offerLat ?? _userLat ?? 30.7865;
    final lng = offerLng ?? _userLng ?? 31.0004;

    return FoodOffer(
      id: o.id,
      title: o.title,
      description: o.description,
      quantity: o.remainingQuantity > 0 ? o.remainingQuantity : o.quantity,
      foodType: o.foodType ?? o.category,
      expiryTime: o.expiresAt,
      pickupBefore: o.pickupBefore ?? o.expiresAt,
      pickupLocation: o.pickupLocation ?? 'موقع غير محدد',
      latitude: lat,
      longitude: lng,
      image: o.firstImage,
      status: FoodOfferStatus.fromString(o.status),
      businessId: o.institutionId,
      charityId: null,
      createdAt: o.createdAt,
      updatedAt: o.updatedAt,
      business: {
        'name': o.institutionName,
        'logo': o.institutionLogoUrl,
        'business_type': businessType,
        'address': o.pickupLocation,
      },
      images: o.images,
      foodCondition: o.foodCondition,
      requiresRefrigeration: o.requiresRefrigeration ?? false,
      isHalal: o.isHalal ?? true,
      isVegetarian: o.isVegetarian ?? false,
      pickupNotes: o.pickupNotes,
      contactPhone: o.contactPhone,
      salePrice: o.symbolicPrice > 0 ? o.symbolicPrice : null,
      originalPrice: o.originalPrice,
      source: businessType,
      details: o.toJson(),
    );
  }

  IconData _iconFromName(String name) {
    switch (name) {
      case 'restaurant':
        return Icons.restaurant_rounded;
      case 'checkroom':
        return Icons.checkroom_rounded;
      case 'shoe':
        return Icons.hiking_rounded;
      case 'shopping_bag':
        return Icons.shopping_bag_rounded;
      case 'tv':
        return Icons.tv_rounded;
      case 'computer':
        return Icons.computer_rounded;
      case 'smartphone':
        return Icons.smartphone_rounded;
      case 'devices_other':
        return Icons.devices_other_rounded;
      case 'chair':
        return Icons.chair_rounded;
      case 'kitchen':
        return Icons.kitchen_rounded;
      case 'home':
        return Icons.home_rounded;
      case 'toys':
        return Icons.toys_rounded;
      case 'menu_book':
        return Icons.menu_book_rounded;
      case 'sports_soccer':
        return Icons.sports_soccer_rounded;
      case 'build':
        return Icons.build_rounded;
      case 'directions_car':
        return Icons.directions_car_rounded;
      case 'music_note':
        return Icons.music_note_rounded;
      case 'business_center':
        return Icons.business_center_rounded;
      case 'collections':
        return Icons.collections_rounded;
      case 'man':
        return Icons.man_rounded;
      case 'woman':
        return Icons.woman_rounded;
      case 'child_care':
        return Icons.child_care_rounded;
      case 'fitness_center':
        return Icons.fitness_center_rounded;
      case 'ac_unit':
        return Icons.ac_unit_rounded;
      case 'laptop':
        return Icons.laptop_rounded;
      case 'desktop_windows':
        return Icons.desktop_windows_rounded;
      case 'keyboard':
        return Icons.keyboard_rounded;
      case 'cable':
        return Icons.cable_rounded;
      case 'monitor':
        return Icons.monitor_rounded;
      case 'shopping_cart':
        return Icons.shopping_cart_rounded;
      case 'local_cafe':
        return Icons.local_cafe_rounded;
      case 'cleaning_services':
        return Icons.cleaning_services_rounded;
      case 'spa':
        return Icons.spa_rounded;
      case 'category':
      default:
        return Icons.category_rounded;
    }
  }

  Widget _buildUrgentSection(List<FoodOffer> offers) {
    final urgent = offers
        .where((o) => o.isAvailable && !o.isExpired && o.isUrgent)
        .take(6)
        .toList(growable: false);

    if (urgent.isEmpty) return SizedBox.shrink();

    return _section(
      title: 'محتاجين سرعة 🔥',
      trailing: null,
      child: SizedBox(
        height: 240,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          scrollDirection: Axis.horizontal,
          itemCount: urgent.length,
          separatorBuilder: (_, __) => SizedBox(width: 12),
          itemBuilder: (context, index) {
            final offer = urgent[index];
            return HomeFoodOfferLargeCard(
              offer: offer,
              onTap: () => _openFoodOffer(offer),
            );
          },
        ),
      ),
    );
  }

  Widget _buildRestaurantSection(List<FoodOffer> offers) {
    final visible = offers
        .where((o) => o.isAvailable && !o.isExpired)
        .take(10)
        .toList(growable: false);

    return _section(
      title: 'من المطاعم 🍽️',
      trailing: visible.isEmpty
          ? null
          : GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => UserAllOffersPage(offers: offers),
                  ),
                );
              },
              child: Text(
                'عرض الكل',
                style: TextStyle(
                  color: _primaryRed,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
      child: visible.isEmpty
          ? _emptyMini(
              Icons.restaurant_outlined, 'مفيش عروض مطاعم قريبة دلوقتي')
          : SizedBox(
              height: 260,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: visible.length,
                separatorBuilder: (_, __) => SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final offer = visible[index];
                  return HomeFoodOfferCard(
                    offer: offer,
                    onTap: () => _openFoodOffer(offer),
                  );
                },
              ),
            ),
    );
  }

  Widget _buildNearbySymbolicProviders() {
    if (_loadingNearbySymbolicProviders && _nearbySymbolicProviders.isEmpty) {
      return _section(
        title: 'خدمات قريبة بسعر رمزي 🛠️',
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 28),
          child: Center(
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              color: _primaryRed,
            ),
          ),
        ),
      );
    }
    if (_nearbySymbolicProviders.isEmpty) return SizedBox.shrink();

    return _section(
      title: 'ناس قريبة تساعدك بسعر رمزي 🛠️',
      trailing: Text(
        _userCity,
        style: TextStyle(
          color: _textSecondary.withValues(alpha: 0.9),
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
      child: SizedBox(
        height: 248,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          scrollDirection: Axis.horizontal,
          itemCount: _nearbySymbolicProviders.length,
          separatorBuilder: (_, __) => SizedBox(width: 12),
          itemBuilder: (context, index) {
            final provider = _nearbySymbolicProviders[index];
            final distance = _distanceKm(
              _userLat!,
              _userLng!,
              provider.latitude!,
              provider.longitude!,
            );
            return HomeNearbySymbolicProviderCard(
              provider: provider,
              distanceKm: distance,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ServiceProviderDetailsPage(
                    provider: provider,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildNearbyInstitutionsOffers(UserHomeLoaded state) {
    final sourceCategories = _nearbyMainCategories.isNotEmpty
        ? _nearbyMainCategories
        : state.categories;
    final root = sourceCategories.cast<Map<String, dynamic>?>().firstWhere(
          (category) => category?['slug']?.toString() == 'institution-offers',
          orElse: () => null,
        );
    final rootId = root?['id']?.toString() ?? '';
    final offers = rootId.isEmpty
        ? const <CategoryOffer>[]
        : (_nearbyCategoryOffers[rootId] ?? const <CategoryOffer>[])
            .where((offer) => offer.ownerType == 'institution')
            .toList(growable: false);

    if (_loadingNearbyCategoryOffers && offers.isEmpty) {
      return _section(
        title: 'عروض مؤسسات قريبة منك',
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(child: CircularProgressIndicator(strokeWidth: 2.2)),
        ),
      );
    }
    if (offers.isEmpty) {
      return _section(
        title: 'عروض مؤسسات قريبة منك',
        child: _emptyMini(
          Icons.storefront_rounded,
          _userLat == null || _userLng == null
              ? 'حدد موقعك عشان نعرض عروض المؤسسات القريبة منك'
              : 'مفيش عروض مؤسسات قريبة متاحة دلوقتي',
        ),
      );
    }

    return _section(
      title: 'عروض مؤسسات قريبة منك',
      trailing: Text(
        _userCity,
        style: TextStyle(
          color: _textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
      child: SizedBox(
        height: 290,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          scrollDirection: Axis.horizontal,
          itemCount: offers.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (context, index) => HomeCategoryOfferCard(
            offer: offers[index],
            onTap: () => _openHomeCategoryOffer(offers[index]),
          ),
        ),
      ),
    );
  }

  Widget _buildNearbyServiceProvidersSection() {
    final providers = _nearbyServiceProviders
        .where((provider) => provider.latitude != null && provider.longitude != null)
        .take(20)
        .toList(growable: false);

    return _section(
      title: 'مقدمو الخدمات في محافظتك',
      trailing: _loadingNearbySymbolicProviders
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(
              '${providers.length} مقدم',
              style: TextStyle(
                color: _textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
      child: providers.isEmpty
          ? _emptyMini(
              Icons.handyman_rounded,
              'لا يوجد مقدمو خدمات متاحون في محافظتك حاليًا',
            )
          : _buildServiceProviderCards(providers),
    );
  }

  Widget _buildServiceProviderCards(List<ServiceProvider> providers) {
    return SizedBox(
      height: 232,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: providers.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) =>
            _buildServiceProviderCard(providers[index]),
      ),
    );
  }

  Widget _buildServiceProviderCard(ServiceProvider provider) {
    final profileImage = provider.profileImageUrl?.trim();
    final location = [
      provider.city?.trim(),
      provider.governorate?.trim() ?? _userGovernorate,
    ].whereType<String>().where((part) => part.isNotEmpty).toSet().join('، ');

    return SizedBox(
      width: 276,
      child: Material(
        color: _card,
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => ServiceProviderDetailsPage(provider: provider),
          )),
          child: Ink(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_blue.withValues(alpha: 0.10), _card, _card],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                stops: const [0, 0.45, 1],
              ),
              border: Border.all(color: _border),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _blue.withValues(alpha: 0.55),
                            width: 1.5,
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 25,
                          backgroundColor: _blue.withValues(alpha: 0.16),
                          backgroundImage: profileImage?.isNotEmpty == true
                              ? CachedNetworkImageProvider(profileImage!)
                              : null,
                          child: profileImage?.isNotEmpty == true
                              ? null
                              : Icon(
                                  provider.isCompany
                                      ? Icons.business_rounded
                                      : Icons.handyman_rounded,
                                  color: _blue,
                                  size: 23,
                                ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              provider.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: _textPrimary,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Row(
                              children: [
                                Icon(
                                  Icons.handyman_rounded,
                                  color: _blue.withValues(alpha: 0.9),
                                  size: 13,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    provider.categoryName ??
                                        provider.categorySlug ??
                                        'خدمات',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: _textSecondary,
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _orange.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _orange.withValues(alpha: 0.24),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.star_rounded, color: _orange, size: 15),
                            const SizedBox(width: 3),
                            Text(
                              provider.ratingAvg.toStringAsFixed(1),
                              style: TextStyle(
                                color: _textPrimary,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Divider(height: 1, color: _border),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_rounded,
                        color: _blue,
                        size: 16,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          location.isEmpty ? _userGovernorate ?? _userCity : location,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _textSecondary,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        constraints: const BoxConstraints(maxWidth: 106),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _green.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Text(
                          provider.pricingLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _green,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      if (provider.phone?.trim().isNotEmpty == true)
                        Expanded(
                          child: _providerContactButton(
                            icon: Icons.phone_rounded,
                            label: 'اتصل',
                            color: _green,
                            onTap: () => _callProvider(provider.phone!),
                          ),
                        ),
                      if (provider.phone?.trim().isNotEmpty == true &&
                          provider.whatsapp?.trim().isNotEmpty == true)
                        const SizedBox(width: 8),
                      if (provider.whatsapp?.trim().isNotEmpty == true)
                        Expanded(
                          child: _providerContactButton(
                            icon: Icons.chat_rounded,
                            label: 'واتساب',
                            color: const Color(0xFF25D366),
                            onTap: () => _whatsappProvider(provider.whatsapp!),
                          ),
                        ),
                    ],
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Icon(
                        provider.isCompany
                            ? Icons.business_rounded
                            : Icons.verified_user_rounded,
                        color: _blue.withValues(alpha: 0.9),
                        size: 14,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        provider.isCompany ? 'مؤسسة خدمات' : 'مقدم خدمة',
                        style: TextStyle(
                          color: _textSecondary,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'عرض الملف',
                        style: TextStyle(
                          color: _blue,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.arrow_forward_ios_rounded,
                          color: _blue, size: 11),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _providerContactButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _callProvider(String phone) async {
    final cleaned = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri.parse('tel:$cleaned');
    try {
      if (await canLaunchUrl(uri)) await launchUrl(uri);
    } catch (error) {
      debugPrint('❌ provider call error: $error');
    }
  }

  Future<void> _whatsappProvider(String phone) async {
    var cleaned = phone.replaceAll(RegExp(r'[^\d]'), '');
    if (cleaned.startsWith('0')) {
      cleaned = '20${cleaned.substring(1)}';
    } else if (!cleaned.startsWith('20') && cleaned.length == 10) {
      cleaned = '20$cleaned';
    }
    final uri = Uri.parse('https://wa.me/$cleaned');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (error) {
      debugPrint('❌ provider whatsapp error: $error');
    }
  }

  Widget _buildInstitutionsHomeSection(UserHomeLoaded state) {
    final sourceCategories = _nearbyMainCategories.isNotEmpty
        ? _nearbyMainCategories
        : state.categories;
    final root = sourceCategories.cast<Map<String, dynamic>?>().firstWhere(
          (category) => category?['slug']?.toString() == 'institution-offers',
          orElse: () => null,
        );
    if (root == null) return const SizedBox.shrink();

    final rootId = root['id']?.toString() ?? '';
    final rootOffers =
        (_nearbyCategoryOffers[rootId] ?? const <CategoryOffer>[])
            .where((offer) => offer.ownerType == 'institution')
            .toList(growable: false);
    final offersByCategory = <String, List<CategoryOffer>>{};
    for (final offer in rootOffers) {
      final categoryId = offer.categoryId?.trim();
      if (categoryId == null || categoryId.isEmpty) continue;
      offersByCategory.putIfAbsent(categoryId, () => []).add(offer);
    }

    final seenCategoryKeys = <String>{};
    final subcategories = _institutionSubcategories
        .where((category) {
          final id = category['id']?.toString() ?? '';
          final slug = category['slug']?.toString().trim().toLowerCase() ?? '';
          return id.isNotEmpty &&
              _institutionHomeCategorySlugs.contains(slug);
        })
        .where((category) {
          final slug = category['slug']?.toString().trim().toLowerCase() ?? '';
          final key = slug == 'meat_shop' ? 'butcher' : slug;
          return seenCategoryKeys.add(key);
        })
        .toList(growable: false);

    if (_loadingNearbyCategoryOffers && subcategories.isEmpty) {
      return _section(
        title: 'عروض المؤسسات',
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 28),
          child: Center(child: CircularProgressIndicator(strokeWidth: 2.4)),
        ),
      );
    }

    // Keep the four institution types visible even when one currently has no
    // nearby offers. Tapping a category still opens its full catalog page.
    final visibleSubcategories = subcategories;

    return Column(
      children: [
        _section(
          title: 'عروض المؤسسات',
          trailing: Text(
            _userCity,
            style: TextStyle(
              color: _textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'اختار القسم المناسب وشوف عروض المؤسسات المتاحة',
                style: TextStyle(
                  color: _textSecondary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 14),
              _buildInstitutionSubcategoryStrip(
                  visibleSubcategories, offersByCategory),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInstitutionSurplusHomeSection(UserHomeLoaded state) {
    final sourceCategories = _nearbyMainCategories.isNotEmpty
        ? _nearbyMainCategories
        : state.categories;
    final root = sourceCategories.cast<Map<String, dynamic>?>().firstWhere(
          (category) => category?['slug']?.toString() == 'institution-offers',
          orElse: () => null,
        );
    if (root == null) return const SizedBox.shrink();

    final rootId = root['id']?.toString() ?? '';
    final offersByCategory = <String, List<CategoryOffer>>{};
    for (final offer in (_nearbyCategoryOffers[rootId] ??
            const <CategoryOffer>[])
        .where((offer) => offer.ownerType == 'institution')) {
      final categoryId = offer.categoryId?.trim();
      if (categoryId == null || categoryId.isEmpty) continue;
      offersByCategory.putIfAbsent(categoryId, () => []).add(offer);
    }

    final surplusCategories = _institutionSubcategories.where((category) {
      final slug = category['slug']?.toString().trim().toLowerCase() ?? '';
      return _institutionSurplusSlugs.contains(slug);
    }).toList(growable: false);
    if (_loadingNearbyCategoryOffers && surplusCategories.isEmpty) {
      return _section(
        title: 'فائض مؤسسات للبيع',
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(child: CircularProgressIndicator(strokeWidth: 2.2)),
        ),
      );
    }
    if (surplusCategories.isEmpty) return const SizedBox.shrink();

    final surplusOffers = <CategoryOffer>[
      for (final category in surplusCategories)
        ...(offersByCategory[category['id']?.toString() ?? ''] ??
            const <CategoryOffer>[]),
    ];

    return Column(
      children: [
        _section(
          title: 'فائض مؤسسات للبيع',
          trailing: Text(
            'فنادق وقاعات أفراح',
            style: TextStyle(
              color: _textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'فائض الطعام المتاح من الفنادق وقاعات الأفراح بسعر رمزي',
                style: TextStyle(
                  color: _textSecondary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 14),
              _buildInstitutionSubcategoryStrip(
                surplusCategories,
                offersByCategory,
              ),
              if (!_loadingNearbyCategoryOffers && surplusOffers.isEmpty) ...[
                const SizedBox(height: 12),
                _emptyMini(
                  Icons.hotel_rounded,
                  'لا توجد عروض فائض متاحة حاليًا',
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInstitutionSubcategoryStrip(
    List<Map<String, dynamic>> categories,
    Map<String, List<CategoryOffer>> offersByCategory,
  ) {
    if (categories.isEmpty) {
      return _emptyMini(
        Icons.account_balance_rounded,
        'جاري تجهيز أقسام المؤسسات',
      );
    }

    return SizedBox(
      height: 142,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 2),
        physics: const BouncingScrollPhysics(),
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final category = categories[index];
          final id = category['id']?.toString() ?? '';
          final name = category['name_ar']?.toString() ?? 'قسم';
          final slug = category['slug']?.toString() ?? '';
          final offerCount = offersByCategory[id]?.length ?? 0;
          final accent = [_primaryRed, _orange, _green, _blue, _purple][index % 5];

          return SizedBox(
            width: 158,
            child: Material(
              color: _card,
              borderRadius: BorderRadius.circular(18),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => _openSmartCategory(id, name, slug),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: _border),
                  gradient: LinearGradient(
                    colors: [
                      accent.withValues(alpha: 0.18),
                      _card,
                    ],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.16),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _iconFromName(category['icon']?.toString() ?? ''),
                        color: accent,
                        size: 23,
                      ),
                    ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              color: _textPrimary,
                              fontSize: 12.5,
                              height: 1.15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      '$offerCount عرض',
                      style: TextStyle(
                        color: _textSecondary,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildNearbyCategorySections(UserHomeLoaded state) {
    final sourceCategories =
        state.categories.isNotEmpty ? state.categories : _nearbyMainCategories;
    final categories = sourceCategories.where((category) {
      if (_isHiddenCategory(category) ||
          _isGroceryOrSupermarketCategory(category)) {
        return false;
      }
      final slug = category['slug']?.toString().toLowerCase() ?? '';
      if (slug == 'institution-offers') return false;
      return _AppFeatures.showRestaurants || !_isRestaurantCategory(category);
    }).toList(growable: false);
    if (_loadingNearbyCategoryOffers && _nearbyCategoryOffers.isEmpty) {
      return _section(
        title: 'عروض قريبة منك',
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 28),
          child: Center(child: CircularProgressIndicator(strokeWidth: 2.4)),
        ),
      );
    }
    if (categories.isEmpty) return const SizedBox.shrink();
    final visibleCategories = _loadingNearbyCategoryOffers
        ? categories
        : categories.where((category) {
            final id = category['id']?.toString() ?? '';
            return (_nearbyCategoryOffers[id] ?? const <CategoryOffer>[])
                .isNotEmpty;
          }).toList(growable: false);
    if (!_loadingNearbyCategoryOffers && visibleCategories.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      children: visibleCategories.map((category) {
        final id = category['id']?.toString() ?? '';
        final name = category['name_ar']?.toString() ?? 'عروض قريبة';
        final slug = category['slug']?.toString() ?? '';
        return _buildNearbyCategorySection(
          categoryId: id,
          categoryName: name,
          categorySlug: slug,
          offers: _nearbyCategoryOffers[id] ?? const <CategoryOffer>[],
        );
      }).toList(growable: false),
    );
  }

  Widget _buildNearbyCategorySection({
    required String categoryId,
    required String categoryName,
    required String categorySlug,
    required List<CategoryOffer> offers,
  }) {
    return _section(
      title: categoryName,
      trailing: GestureDetector(
        onTap: () => _openSmartCategory(categoryId, categoryName, categorySlug),
        child: Text(
          'عرض الكل',
          style: TextStyle(
            color: _primaryRed,
            fontSize: 13,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      child: offers.isEmpty
          ? _emptyMini(Icons.inventory_2_outlined, 'لا توجد عروض قريبة حاليًا')
          : SizedBox(
              height: 252,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: offers.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) => HomeCategoryOfferCard(
                  offer: offers[index],
                  onTap: () => _openHomeCategoryOffer(offers[index]),
                ),
              ),
            ),
    );
  }

  void _openHomeCategoryOffer(CategoryOffer offer) {
    if (offer.isCommunity) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CommunityOfferDetailsPage(offer: offer.raw),
        ),
      );
      return;
    }
    try {
      final institutionOffer = InstitutionOffer.fromJson(offer.raw);
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => InstitutionOfferDetailsPage(offer: institutionOffer),
        ),
      );
    } catch (e) {
      debugPrint('❌ Could not open category offer: $e');
      _openSmartCategory(
        offer.categoryId ?? '',
        offer.categoryName ?? 'العروض',
        '',
      );
    }
  }

  Widget _buildNeedsSection() {
    final visible = _communityNeeds.take(10).toList(growable: false);

    return _section(
      title: 'الناس محتاجة 🙏',
      trailing: GestureDetector(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const CommunityNeedsPage(),
            ),
          );
        },
        child: Text(
          'عرض الكل',
          style: TextStyle(
            color: _primaryRed,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      child: _loadingNeeds && visible.isEmpty
          ? Padding(
              padding: EdgeInsets.symmetric(vertical: 30),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: _primaryRed,
                  ),
                ),
              ),
            )
          : visible.isEmpty
              ? _buildNeedsEmptyCard()
              : SizedBox(
                  height: 230,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    scrollDirection: Axis.horizontal,
                    itemCount: visible.length,
                    separatorBuilder: (_, __) => SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final need = visible[index];
                      return HomeNeedCard(
                        need: need,
                        onTap: () {
                          final id = need['id']?.toString() ?? '';
                          if (id.isEmpty) return;
                          Navigator.of(context)
                              .push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      CommunityNeedDetailsPage(needId: id),
                                ),
                              )
                              .then((_) => _loadCommunityNeeds());
                        },
                      );
                    },
                  ),
                ),
    );
  }

  Widget _buildNeedsEmptyCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF3679C8), Color(0xFF6651B5)],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF3679C8).withValues(alpha: 0.3),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.volunteer_activism_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'شوف الناس محتاجة إيه',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'ممكن تكون عندك الحاجة اللي بتدور عليها',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: HomeNeedsActionPill(
                    icon: Icons.search_rounded,
                    label: 'تصفح الاحتياجات',
                    filled: true,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const CommunityNeedsPage(),
                        ),
                      );
                    },
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: HomeNeedsActionPill(
                    icon: Icons.assignment_outlined,
                    label: 'احتياجاتي',
                    filled: false,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const MyCommunityNeedsPage(),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // ✅ قسم "شراء بسعر رمزي" — بيعرض العروض القريبة بس
  // ═══════════════════════════════════════════════════════════
  Widget _buildCommunitySection(List<Map<String, dynamic>> offers) {
    // ✅ فلترة: available + قريبة
    final available = offers
        .where((o) => o['status']?.toString() == 'available')
        .toList(growable: false);

    // ✅ نفلتر حسب القرب من المستخدم
    final nearby = _filterCommunityByProximity(available);

    return _section(
      title: 'شراء بسعر رمزي 💰',
      trailing: GestureDetector(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const AddCommunityOfferPage(),
            ),
          );
        },
        child: Text(
          'أضف شيئًا للبيع',
          style: TextStyle(
            color: _primaryRed,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      child: nearby.isEmpty
          ? HomeCommunityEmptyCard(
              onAdd: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const AddCommunityOfferPage(),
                  ),
                );
              },
            )
          : SizedBox(
              height: 290,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: nearby.length,
                separatorBuilder: (_, __) => SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final offer = nearby[index];
                  return HomeCommunityOfferCard(
                    offer: offer,
                    onTap: () => _openCommunityOffer(offer),
                  );
                },
              ),
            ),
    );
  }

  Widget _section({
    required String title,
    required Widget child,
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 22,
                  margin: const EdgeInsets.only(left: 10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [_primaryRed, _primaryRedDark],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: _textPrimary,
                      fontSize: 17.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                if (trailing != null) trailing,
              ],
            ),
          ),
          SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _emptyMini(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _border, width: 1),
        ),
        child: Column(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: _cardSoft,
                shape: BoxShape.circle,
              ),
              child: Icon(icon,
                  color: _textSecondary.withValues(alpha: 0.7), size: 26),
            ),
            SizedBox(height: 14),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _textSecondary,
                fontSize: 13,
                height: 1.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openFoodOffer(FoodOffer offer) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PersonOfferDetailsPage(
          offer: {
            'id': offer.id,
            'title': offer.title,
            'description': offer.description,
            'quantity': offer.quantity,
            'food_type': offer.foodType,
            'expiry_time': offer.expiryTime.toIso8601String(),
            'pickup_before': offer.pickupBefore.toIso8601String(),
            'pickup_location': offer.pickupLocation,
            'latitude': offer.latitude,
            'longitude': offer.longitude,
            'image': offer.displayImage,
            'status': offer.status.value,
            'business_id': offer.businessId,
            'restaurant_id': offer.businessId,
            'charity_id': offer.charityId,
            'created_at': offer.createdAt.toIso8601String(),
            'updated_at': offer.updatedAt.toIso8601String(),
            'businesses': {
              'name': offer.businessName,
              'logo': offer.businessLogo,
            },
            'restaurants': {'name': offer.businessName},
            'images': offer.displayImages,
          },
        ),
      ),
    );
  }

  void _openCommunityOffer(Map<String, dynamic> offer) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CommunityOfferDetailsPage(offer: offer),
      ),
    );
  }

  Widget _buildAddButton() {
    final isDark = _isDark;
    final shellColor = isDark ? const Color(0xFF171717) : Colors.white;
    final selectedColor = isDark
        ? const Color(0xFF3E315B)
        : const Color(0xFFE9E0F6);
    final selectedText = isDark ? Colors.white : const Color(0xFF57408E);
    return Hero(
      tag: 'loqma_home_add_button',
      child: Material(
        color: shellColor,
        borderRadius: BorderRadius.circular(24),
        elevation: 0,
        child: InkWell(
          onTap: _showAddSheet,
          borderRadius: BorderRadius.circular(24),
          child: Ink(
            width: 178,
            height: 60,
            decoration: BoxDecoration(
              color: shellColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.12)
                    : const Color(0xFFE8E4EE),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.12),
                  blurRadius: 20,
                  offset: const Offset(0, 7),
                ),
              ],
            ),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 10),
                decoration: BoxDecoration(
                  color: selectedColor,
                  borderRadius: BorderRadius.circular(21),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_rounded, color: selectedText, size: 22),
                    const SizedBox(width: 7),
                    Text(
                      'أضف مشاركة',
                      style: TextStyle(
                        color: selectedText,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                  ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showAddSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: _textSecondary.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  SizedBox(height: 18),
                  Text(
                    'إنت عايز تعمل إيه؟',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                      color: _textPrimary,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'اختار من الخيارات',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: _textSecondary,
                    ),
                  ),
                  SizedBox(height: 22),
                  HomeAddActionTile(
                    icon: Icons.volunteer_activism_rounded,
                    title: 'أتبرع بحاجة',
                    subtitle: 'عندي حاجة عايز أتبرع بيها لجمعية',
                    color: _green,
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const AddCharityDonationPage()),
                      );
                    },
                  ),
                  SizedBox(height: 12),
                  HomeAddActionTile(
                    icon: Icons.sell_rounded,
                    title: 'أضيف حاجة للبيع',
                    subtitle: 'عندي حاجة عايز أبيعها',
                    color: _orange,
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              const AddCommunityOfferPage(),
                        ),
                      );
                    },
                  ),
                  SizedBox(height: 12),
                  HomeAddActionTile(
                    icon: Icons.volunteer_activism_outlined,
                    title: 'أنا محتاج حاجة',
                    subtitle: 'محتاج حاجة معينة، ياريت حد يساعدني',
                    color: _primaryRed,
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const AddCommunityNeedPage()),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomNavigationBar() {
    return UserHomeBottomNavigationBar(
      currentIndex: _currentPage,
      cardColor: _card,
      borderColor: _border,
      isDark: _isDark,
      onTap: _selectPage,
    );
  }

  void _selectPage(int index) {
    if (!mounted) return;
    setState(() {
      _visitedPages.add(index);
      _currentPage = index;
    });
  }
}

// ============================================================
// ✅ NEEDS ACTION PILL
// ============================================================
