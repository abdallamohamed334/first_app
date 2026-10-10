// lib/features/userhome/presentation/pages/user_home_page.dart

import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

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
import 'package:loqma/features/community/presentation/utils/offer_expiry_helper.dart';
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
import 'package:loqma/features/userhome/presentation/pages/category_offers_page.dart';
import 'package:loqma/features/userhome/presentation/pages/sub_categories_page.dart'; // ✅ جديد
import 'package:loqma/features/userhome/presentation/pages/user_all_offers_page.dart';
import 'package:loqma/features/userhome/presentation/pages/user_institution_offers_page.dart';

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

/// التصنيفات الوحيدة المسموح بها داخل كتالوج عروض المؤسسات.
const Set<String> _institutionCatalogSlugs = {
  'grocery',
  'bakery',
  'butcher',
  'meat_shop',
  'poultry_shop',
  'wedding_hall',
  'game_store',
  'hotel',
  'home-restaurants',
  'household-items',
  'home_restaurant',
  'household_goods',
  'home-sweets',
  'home-food',
};

const Set<String> _homeRestaurantInstitutionTypes = {
  'home_restaurant',
  'home-restaurant',
  'home_restaurants',
  'home-restaurants',
};

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

  final PageController _bannerController = PageController(viewportFraction: 1);
  int _bannerIndex = 0;
  Timer? _bannerTimer;

  // ───────── ألوان الديزاين ─────────
  static bool get _isDark => ThemeNotifier.isDarkMode.value;
  static Color get _bg =>
      _isDark ? const Color(0xFF000000) : const Color(0xFFFFFFFF);
  static Color get _card =>
      _isDark ? const Color(0xFF121212) : const Color(0xFFFFFFFF);
  static Color get _cardSoft =>
      _isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF2F2F2);
  static Color get _primaryRed =>
      _isDark ? const Color(0xFFFFFFFF) : const Color(0xFF111111);
  static Color get _primaryRedDark =>
      _isDark ? const Color(0xFFCCCCCC) : const Color(0xFF000000);
  static Color get _textPrimary =>
      _isDark ? const Color(0xFFFFFFFF) : const Color(0xFF111111);
  static Color get _textSecondary =>
      _isDark ? const Color(0xFFB8B8B8) : const Color(0xFF555555);
  static Color get _border =>
      _isDark ? const Color(0x33FFFFFF) : const Color(0x22000000);
  static Color get _orange =>
      _isDark ? const Color(0xFFFFFFFF) : const Color(0xFF333333);
  static Color get _green =>
      _isDark ? const Color(0xFFE0E0E0) : const Color(0xFF222222);
  static Color get _blue =>
      _isDark ? const Color(0xFFFFFFFF) : const Color(0xFF333333);
  static Color get _purple =>
      _isDark ? const Color(0xFFDDDDDD) : const Color(0xFF444444);

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
      _loadInstitutionOffers();
      _loadServiceCategories();

      await _loadUserLocation();
      if (!mounted) return;

      _loadCommunityNeeds();
      _loadNearbySymbolicProviders();
      _loadNearbyCategoryOffers();
    });
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _bannerController.dispose();
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
          .select('latitude, longitude, city')
          .eq('id', authUser.id)
          .maybeSingle();

      if (data == null || !mounted) return;

      final lat = (data['latitude'] as num?)?.toDouble();
      final lng = (data['longitude'] as num?)?.toDouble();
      final city = (data['city'] as String?)?.trim();

      if (lat == null || lng == null) {
        if (mounted) {
          context.go('/map');
        }
        return;
      }

      setState(() {
        _userLat = lat;
        _userLng = lng;
        _userCity =
            (city != null && city.isNotEmpty) ? city : AppConfig.defaultCity;
      });

      debugPrint('✅ [Location] Loaded: city=$_userCity, lat=$lat, lng=$lng');
    } catch (e) {
      debugPrint('❌ [Location] error: $e');
    }
  }

  Future<void> _loadNearbySymbolicProviders() async {
    if (_loadingNearbySymbolicProviders ||
        _userLat == null ||
        _userLng == null) {
      return;
    }
    if (mounted) setState(() => _loadingNearbySymbolicProviders = true);

    try {
      final providers = await _serviceProvidersRepository.listNearbyProviders(
        city: _userCity,
      );
      if (!mounted) return;

      final nearby = providers.where((provider) {
        final lat = provider.latitude;
        final lng = provider.longitude;
        if (lat == null || lng == null) return false;
        return true;
      }).toList();

      nearby.sort((a, b) => _distanceKm(
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
        _nearbyServiceProviders = nearby.take(100).toList();
        _nearbySymbolicProviders =
            nearby.where((p) => p.isSymbolic).take(10).toList();
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
            offer.remainingQuantity <= 0 ||
            !_isAllowedInstitutionOffer(offer)) {
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

  bool _isAllowedInstitutionOffer(InstitutionOffer offer) {
    final type = offer.institutionType?.trim().toLowerCase();
    if (type == 'supermarket') {
      return _institutionCatalogSlugs.contains('grocery');
    }
    return _institutionCatalogSlugs.contains(type);
  }

  bool _isHomeRestaurantOffer(InstitutionOffer offer) {
    final type = offer.institutionType?.trim().toLowerCase();
    return _homeRestaurantInstitutionTypes.contains(type);
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
              .where(
                (category) => _institutionCatalogSlugs.contains(
                  category['slug']?.toString().trim().toLowerCase(),
                ),
              )
              .toList(growable: false);
      if (institutionRoot != null) {
        final institutionOffers = await _userHomeRepository.getOffersByCategory(
          categoryId: institutionRoot['id']?.toString() ?? '',
        );
        final institutionOnly = institutionOffers
            .where((offer) => offer.ownerType == 'institution')
            .toList(growable: false);
        if (institutionOnly.isNotEmpty) {
          grouped[institutionRoot['id']?.toString() ?? ''] = institutionOnly;

          // Each visible child section includes its own offers plus every
          // nested descendant (for example grocery -> bakery -> pastries).
          final childOffers = await Future.wait(
            institutionSubcategories.map((category) async {
              final childId = category['id']?.toString() ?? '';
              if (childId.isEmpty) {
                return const <CategoryOffer>[];
              }
              final treeIds = await _userHomeRepository.getCategoryTreeIds(
                childId,
              );
              final tree = treeIds.toSet();
              return institutionOnly
                  .where((offer) => tree.contains(offer.categoryId))
                  .toList(growable: false);
            }),
          );
          for (var index = 0;
              index < institutionSubcategories.length;
              index++) {
            final childId = institutionSubcategories[index]['id']?.toString();
            if (childId != null && childId.isNotEmpty) {
              grouped[childId] = childOffers[index];
            }
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
      _loadCommunityNeeds(),
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

  void _startBannerAutoPlay(int count) {
    _bannerTimer?.cancel();
    if (count <= 1) return;
    _bannerTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || !_bannerController.hasClients) return;
      final next = (_bannerIndex + 1) % count;
      _bannerController.animateToPage(
        next,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
      );
    });
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
          if (state is UserHomeLoading) return const _LoadingHome();
          if (state is UserHomeUnauthenticated) {
            return _buildUnauthenticated();
          }
          if (state is UserHomeError) return _buildError(state.message);
          if (state is UserHomeLoaded) return _buildLoadedHome(state);
          return const _LoadingHome();
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
                  'أهلًا بيك في وِصلة 👋',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _textPrimary,
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 14),
                Text(
                  'سجّل دخولك علشان تكتشف العروض القريبة منك وتشارك في مجتمع وِصلة.',
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
                    onPressed: () {},
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
        children: [
          _buildHomeContent(state),
          _buildCategoriesContent(state),
          const CommunityNeedsPage(),
          const CommunityTrackingPage(),
          const ProfilePage(),
        ],
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
      if (_isHiddenCategory(c)) return false;
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
                          isServices ? 'خدمات وِصلة' : 'أقسام وِصلة',
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
        child: _homeMode == _HomeMode.buy
            ? _buildBuyContent(state)
            : _buildServicesContent(),
      ),
    );
  }

  Widget _buildBuyContent(UserHomeLoaded state) {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      slivers: [
        SliverToBoxAdapter(child: _buildHeader()),
        SliverToBoxAdapter(child: _buildModeSwitcher()),
        SliverToBoxAdapter(child: _buildLocationRow(state)),
        SliverToBoxAdapter(child: _buildCategoriesGrid(state)),
        SliverToBoxAdapter(child: _buildCompanyOffersSlider()),
        SliverToBoxAdapter(child: _buildInstitutionsHomeSection(state)),
        SliverToBoxAdapter(child: _buildNeedsSection()),
        SliverToBoxAdapter(child: _buildNearbyCategorySections(state)),
        SliverToBoxAdapter(child: SizedBox(height: 120)),
      ],
    );
  }

  Widget _buildServicesContent() {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      slivers: [
        SliverToBoxAdapter(child: _buildHeader()),
        SliverToBoxAdapter(child: _buildModeSwitcher()),
        SliverToBoxAdapter(child: _buildServicesMapPreview()),
        SliverToBoxAdapter(child: _buildServiceCategoriesGrid()),
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
                label: 'شراء',
                subtitle: 'أكل وعروض',
                color: _primaryRed,
              ),
            ),
            SizedBox(width: 4),
            Expanded(
              child: _buildModeTile(
                mode: _HomeMode.services,
                icon: Icons.handyman_rounded,
                label: 'خدمات',
                subtitle: 'سباكة، كهرباء',
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
    final center = LatLng(
      _userLat ?? AppConfig.defaultLat,
      _userLng ?? AppConfig.defaultLng,
    );
    final providers = _nearbyServiceProviders
        .where((p) => p.latitude != null && p.longitude != null)
        .toList(growable: false);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
      child: Material(
        color: _card,
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ServiceProvidersMapPage(
                    providers: providers,
                    latitude: center.latitude,
                    longitude: center.longitude,
                    city: _userCity,
                  ),
                ),
              ),
          child: SizedBox(
            height: 190,
            child: Stack(
              fit: StackFit.expand,
              children: [
                IgnorePointer(
                  child: FlutterMap(
                    options: MapOptions(initialCenter: center, initialZoom: 11.5),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.wasla.app',
                      ),
                      MarkerLayer(
                        markers: providers.take(30).map((provider) {
                          return Marker(
                            point:
                                LatLng(provider.latitude!, provider.longitude!),
                            width: 34,
                            height: 34,
                            child: Container(
                              decoration: BoxDecoration(
                                color: _blue,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              child: Icon(
                                provider.isCompany
                                    ? Icons.business_rounded
                                    : Icons.handyman_rounded,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.58),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 14,
                  bottom: 14,
                  left: 14,
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _blue,
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: const Icon(Icons.map_rounded,
                            color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'مقدمو الخدمات حولك',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              providers.isEmpty
                                  ? 'لا يوجد مقدمو خدمات على الخريطة حاليًا'
                                  : 'اضغط لعرض ${providers.length} مقدم على الخريطة',
                              style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                      if (providers.isNotEmpty)
                        const Icon(Icons.arrow_back_ios_new_rounded,
                            color: Colors.white, size: 17),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildServiceCategoriesGrid() {
    if (_loadingServiceCategories && _serviceCategories.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: CircularProgressIndicator(color: _primaryRed),
        ),
      );
    }

    if (_serviceCategories.isEmpty) {
      return _buildServiceCategoriesEmpty();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                  'كل الخدمات',
                  style: TextStyle(
                    color: _textPrimary,
                    fontSize: 17.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 14),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              childAspectRatio: 0.92,
            ),
            itemCount: _serviceCategories.length,
            itemBuilder: (context, index) {
              return _buildServiceCategoryTile(_serviceCategories[index]);
            },
          ),
        ],
      ),
    );
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'وِصلة',
                  style: TextStyle(
                    color: _textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'كل ما تحتاجه… في مكان واحد',
                  style: TextStyle(
                    color: _textSecondary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _buildHeaderNotificationButton(),
        ],
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
    // السلايدر يظل خفيفًا ويعرض أقرب خمسة عروض انتهاءً فقط.
    // عروض مطاعم البيت لها قسمها المخصص؛ لا تعرضها مرة ثانية هنا.
    final offers = _institutionOffers
        .where((offer) => !_isHomeRestaurantOffer(offer))
        .take(5)
        .toList(growable: false);
    if (_loadingInstitutionOffers && offers.isEmpty) {
      return const SizedBox(
        height: 244,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2.2)),
      );
    }

    if (offers.isEmpty) return const SizedBox.shrink();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _startBannerAutoPlay(offers.length);
    });

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 22),
      child: Column(
        children: [
          SizedBox(
            height: 238,
            child: PageView.builder(
              controller: _bannerController,
              itemCount: offers.length,
              onPageChanged: (index) {
                if (mounted) setState(() => _bannerIndex = index);
              },
              itemBuilder: (_, index) => _buildCompanyOfferCard(offers[index]),
            ),
          ),
          if (offers.length > 1) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(offers.length, (index) {
                final active = index == _bannerIndex;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 240),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: active ? 24 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: active ? _textPrimary : _border,
                    borderRadius: BorderRadius.circular(20),
                  ),
                );
              }),
            ),
          ],
        ],
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
              bottom: 16,
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
          .limit(1);

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
            return _FoodOfferLargeCard(
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
                  return _FoodOfferCard(
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
            return _NearbySymbolicProviderCard(
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

    final subcategories = _institutionSubcategories
        .where((category) => category['id']?.toString().isNotEmpty == true)
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
                'اختار القسم المناسب وشوف عدد العروض المتاحة من المؤسسات',
                style: TextStyle(
                  color: _textSecondary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 14),
              _buildInstitutionSubcategoryStrip(
                  subcategories, offersByCategory),
            ],
          ),
        ),
        ...subcategories.map((category) {
          final id = category['id']?.toString() ?? '';
          final offers = offersByCategory[id] ?? const <CategoryOffer>[];
          if (offers.isEmpty) return const SizedBox.shrink();
          return _buildNearbyCategorySection(
            categoryId: id,
            categoryName: category['name_ar']?.toString() ?? 'عروض المؤسسات',
            categorySlug: category['slug']?.toString() ?? '',
            offers: offers,
          );
        }),
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
      height: 220,
      child: GridView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 2),
        physics: const BouncingScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.2,
        ),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          final id = category['id']?.toString() ?? '';
          final name = category['name_ar']?.toString() ?? 'قسم';
          final slug = category['slug']?.toString() ?? '';
          final offerCount = offersByCategory[id]?.length ?? 0;

          return Material(
            color: _card,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => _openSmartCategory(id, name, slug),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _border),
                  gradient: LinearGradient(
                    colors: [
                      _primaryRed.withValues(alpha: 0.12),
                      _card,
                    ],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _primaryRed.withValues(alpha: 0.14),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _iconFromName(category['icon']?.toString() ?? ''),
                        color: _primaryRed,
                        size: 19,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _textPrimary,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$offerCount عرض',
                      style: TextStyle(
                        color: _textSecondary,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
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
      if (_isHiddenCategory(category)) return false;
      if (category['slug']?.toString() == 'institution-offers') return false;
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
    return Column(
      children: categories.map((category) {
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
                itemBuilder: (context, index) => _HomeCategoryOfferCard(
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
                      return _NeedCard(
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
                  child: _NeedsActionPill(
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
                  child: _NeedsActionPill(
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
            MaterialPageRoute(builder: (_) => const AddCommunityOfferPage()),
          );
        },
        child: Text(
          'أضف عرض',
          style: TextStyle(
            color: _primaryRed,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      child: nearby.isEmpty
          ? _CommunityEmptyCard(
              onAdd: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => const AddCommunityOfferPage()),
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
                  return _CommunityOfferCard(
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
                  _AddActionTile(
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
                  _AddActionTile(
                    icon: Icons.sell_rounded,
                    title: 'أبيع حاجة بسعر رمزي',
                    subtitle: 'عندي حاجة عايز أبيعها بسعر بسيط',
                    color: _orange,
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const AddCommunityOfferPage()),
                      );
                    },
                  ),
                  SizedBox(height: 12),
                  SizedBox(height: 12),
                  _AddActionTile(
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
    return Container(
      decoration: BoxDecoration(
        color: _card,
        border: Border(
          top: BorderSide(color: _border, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 24,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              _BottomNavItem(
                index: 0,
                currentIndex: _currentPage,
                icon: Icons.home_rounded,
                outlinedIcon: Icons.home_outlined,
                label: 'الرئيسية',
                onTap: _selectPage,
              ),
              _BottomNavItem(
                index: 1,
                currentIndex: _currentPage,
                icon: Icons.grid_view_rounded,
                outlinedIcon: Icons.grid_view_rounded,
                label: 'الأقسام',
                onTap: _selectPage,
              ),
              _BottomNavItem(
                index: 2,
                currentIndex: _currentPage,
                icon: Icons.volunteer_activism_rounded,
                outlinedIcon: Icons.volunteer_activism_outlined,
                label: 'الاحتياجات',
                onTap: _selectPage,
              ),
              _BottomNavItem(
                index: 3,
                currentIndex: _currentPage,
                icon: Icons.receipt_long_rounded,
                outlinedIcon: Icons.receipt_long_rounded,
                label: 'الطلبات',
                onTap: _selectPage,
              ),
              _BottomNavItem(
                index: 4,
                currentIndex: _currentPage,
                icon: Icons.person_rounded,
                outlinedIcon: Icons.person_outline_rounded,
                label: 'حسابي',
                onTap: _selectPage,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _selectPage(int index) {
    if (!mounted) return;
    setState(() => _currentPage = index);
  }
}

// ============================================================
// ✅ NEEDS ACTION PILL
// ============================================================
class _NeedsActionPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool filled;
  final VoidCallback onTap;

  const _NeedsActionPill({
    required this.icon,
    required this.label,
    required this.filled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: filled ? Colors.white : Colors.white.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: filled
                ? null
                : Border.all(color: Colors.white.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: filled ? const Color(0xFF3679C8) : Colors.white,
              ),
              SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: filled ? const Color(0xFF3679C8) : Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// ✅ NEED CARD
// ============================================================
class _NeedCard extends StatelessWidget {
  final Map<String, dynamic> need;
  final VoidCallback onTap;

  const _NeedCard({
    required this.need,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final title = need['title']?.toString() ?? 'احتياج';
    final category = need['category_name_ar']?.toString() ?? 'عام';
    final city = need['city']?.toString() ?? '';
    final urgency = need['urgency']?.toString() ?? 'normal';
    final quantity = (need['quantity'] as num?)?.toInt() ?? 1;
    final imageUrl = need['image_url']?.toString();

    final urgencyData = _urgencyData(urgency);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 200,
        decoration: BoxDecoration(
          color: _UserHomePageState._card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _UserHomePageState._border, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.22),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 80,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF3679C8), Color(0xFF6651B5)],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
              ),
              child: Stack(
                children: [
                  if (imageUrl != null && imageUrl.isNotEmpty)
                    Positioned.fill(
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => SizedBox.shrink(),
                      ),
                    ),
                  if (imageUrl != null && imageUrl.isNotEmpty)
                    Positioned.fill(child: Container(color: Colors.black26)),
                  Positioned(
                    left: -20,
                    bottom: -20,
                    child: Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                  ),
                  Positioned(
                    right: -10,
                    top: -15,
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.06),
                      ),
                    ),
                  ),
                  Center(
                    child: Icon(
                      Icons.volunteer_activism_rounded,
                      color: Colors.white,
                      size: 34,
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: urgencyData.$3,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(urgencyData.$1, color: Colors.white, size: 10),
                          SizedBox(width: 3),
                          Text(
                            urgencyData.$2,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _UserHomePageState._textPrimary,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w900,
                      height: 1.3,
                    ),
                  ),
                  SizedBox(height: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _UserHomePageState._cardSoft,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.local_offer_rounded,
                            size: 10, color: _UserHomePageState._textSecondary),
                        SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            category,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: _UserHomePageState._textSecondary,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 6),
                  Row(
                    children: [
                      if (city.isNotEmpty) ...[
                        Icon(
                          Icons.location_on_rounded,
                          size: 11,
                          color: _UserHomePageState._textSecondary
                              .withValues(alpha: 0.7),
                        ),
                        SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            city,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: _UserHomePageState._textSecondary,
                              fontSize: 10.5,
                            ),
                          ),
                        ),
                      ],
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFF3679C8).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'الكمية: $quantity',
                          style: TextStyle(
                            color: Color(0xFF3679C8),
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
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

  (IconData, String, Color) _urgencyData(String urgency) {
    switch (urgency) {
      case 'urgent':
        return (
          Icons.warning_amber_rounded,
          'عاجل جدًا',
          const Color(0xFFB54747)
        );
      case 'high':
        return (Icons.priority_high_rounded, 'مهم', const Color(0xFFE28B00));
      case 'low':
        return (
          Icons.sentiment_satisfied_rounded,
          'عادي',
          const Color(0xFF2E9B5C)
        );
      case 'normal':
      default:
        return (
          Icons.sentiment_neutral_rounded,
          'متوسط',
          const Color(0xFF3679C8)
        );
    }
  }
}

// ============================================================
// ✅ LARGE FOOD CARD — (للأرشيف)
// ============================================================
class _FoodOfferLargeCard extends StatelessWidget {
  final FoodOffer offer;
  final VoidCallback onTap;

  const _FoodOfferLargeCard({
    required this.offer,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 260,
        decoration: BoxDecoration(
          color: _UserHomePageState._card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _UserHomePageState._border, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.28),
              blurRadius: 16,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _FoodImage(
                    url: offer.displayImage,
                    fallback: Icons.restaurant_rounded,
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFFE28B00), Color(0xFFB77700)],
                        ),
                        borderRadius: BorderRadius.circular(100),
                        boxShadow: [
                          BoxShadow(
                            color:
                                const Color(0xFFE28B00).withValues(alpha: 0.4),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Text(
                        'عاجل 🔥',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    offer.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _UserHomePageState._textPrimary,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    offer.businessName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _UserHomePageState._textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.schedule_rounded,
                          size: 13, color: _UserHomePageState._primaryRed),
                      SizedBox(width: 4),
                      Text(
                        offer.timeRemaining,
                        style: TextStyle(
                          color: _UserHomePageState._primaryRed,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
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
}

// ============================================================
// ✅ FOOD CARD — (للأرشيف)
// ============================================================
class _FoodOfferCard extends StatelessWidget {
  final FoodOffer offer;
  final VoidCallback onTap;

  const _FoodOfferCard({
    required this.offer,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 180,
        decoration: BoxDecoration(
          color: _UserHomePageState._card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _UserHomePageState._border, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.22),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 130,
              width: double.infinity,
              child: _FoodImage(
                url: offer.displayImage,
                fallback: Icons.restaurant_rounded,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    offer.priceDisplay,
                    style: TextStyle(
                      color: _UserHomePageState._primaryRed,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    offer.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _UserHomePageState._textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                    ),
                  ),
                  SizedBox(height: 7),
                  Text(
                    offer.businessName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _UserHomePageState._textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (offer.distanceMeters != null) ...[
                    SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(Icons.location_on_rounded,
                            size: 11,
                            color: _UserHomePageState._textSecondary
                                .withValues(alpha: 0.7)),
                        SizedBox(width: 3),
                        Text(
                          offer.distanceDisplay,
                          style: TextStyle(
                            color: _UserHomePageState._textSecondary,
                            fontSize: 10.5,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// FOOD IMAGE
// ============================================================
class _FoodImage extends StatelessWidget {
  final String? url;
  final IconData fallback;

  const _FoodImage({
    required this.url,
    required this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty || url == 'null') {
      return Container(
        color: _UserHomePageState._cardSoft,
        child: Icon(fallback,
            color: _UserHomePageState._textSecondary.withValues(alpha: 0.7),
            size: 36),
      );
    }

    return CachedNetworkImage(
      imageUrl: url!,
      fit: BoxFit.cover,
      placeholder: (_, __) => Container(
        color: _UserHomePageState._cardSoft,
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: _UserHomePageState._primaryRed,
            ),
          ),
        ),
      ),
      errorWidget: (_, __, ___) => Container(
        color: _UserHomePageState._cardSoft,
        child: Icon(fallback,
            color: _UserHomePageState._textSecondary.withValues(alpha: 0.7),
            size: 36),
      ),
    );
  }
}

// ============================================================
// ✅ COMMUNITY CARD
// ============================================================
class _CommunityOfferCard extends StatelessWidget {
  final Map<String, dynamic> offer;
  final VoidCallback onTap;
  final bool fullWidth;

  const _CommunityOfferCard({
    required this.offer,
    required this.onTap,
  }) : fullWidth = false;

  @override
  Widget build(BuildContext context) {
    final title = offer['title']?.toString() ?? 'عرض بسعر رمزي';
    final description = offer['description']?.toString() ?? '';
    final category = offer['category_name_ar']?.toString() ??
        offer['category']?.toString() ??
        'أخرى';
    final price = _formatPrice(offer['price']);
    final distance = _formatDistance(offer['distance_meters']);
    final image = _communityImage(offer);
    final expiresAt = _parseDate(offer['expires_at']);

    if (fullWidth) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: _UserHomePageState._card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _UserHomePageState._border, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.22),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Row(
            children: [
              SizedBox(
                width: 100,
                height: 100,
                child: _CommunityImage(image: image),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        price,
                        style: TextStyle(
                          color: _UserHomePageState._primaryRed,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _UserHomePageState._textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (description.isNotEmpty) ...[
                        SizedBox(height: 3),
                        Text(
                          description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _UserHomePageState._textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                      SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: _UserHomePageState._cardSoft,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              category,
                              style: TextStyle(
                                color: _UserHomePageState._textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (distance != null) ...[
                            SizedBox(width: 8),
                            Text(
                              distance,
                              style: TextStyle(
                                color: _UserHomePageState._textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (expiresAt != null) ...[
                        SizedBox(height: 6),
                        OfferExpiryHelper.buildBadge(
                          expiresAt: expiresAt,
                          compact: true,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 180,
        decoration: BoxDecoration(
          color: _UserHomePageState._card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _UserHomePageState._border, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.22),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 130,
              width: double.infinity,
              child: _CommunityImage(image: image),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    price,
                    style: TextStyle(
                      color: _UserHomePageState._primaryRed,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _UserHomePageState._textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                    ),
                  ),
                  SizedBox(height: 7),
                  Text(
                    category,
                    style: TextStyle(
                      color: _UserHomePageState._textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (distance != null) ...[
                    SizedBox(height: 3),
                    Text(
                      distance,
                      style: TextStyle(
                        color: _UserHomePageState._textSecondary,
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                  if (expiresAt != null) ...[
                    SizedBox(height: 6),
                    OfferExpiryHelper.buildBadge(
                      expiresAt: expiresAt,
                      compact: true,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    if (text.isEmpty || text == 'null') return null;
    return DateTime.tryParse(text);
  }

  static String _formatPrice(dynamic value) {
    final number = value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '') ?? 0;
    if (number <= 0) return 'سعر رمزي';
    return '${number.toStringAsFixed(0)} ج.م';
  }

  static String? _formatDistance(dynamic value) {
    final meters = value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '');
    if (meters == null) return null;
    if (meters < 1000) return '${meters.round()} م';
    return '${(meters / 1000).toStringAsFixed(1)} كم';
  }

  static String? _communityImage(Map<String, dynamic> offer) {
    final values = <dynamic>[
      offer['image'],
      offer['image_url'],
      offer['images'],
      offer['image_urls'],
      offer['offer_images'],
    ];
    for (final value in values) {
      final raw = value is List && value.isNotEmpty ? value.first : value;
      final text = raw?.toString().trim() ?? '';
      if (text.isEmpty || text == 'null' || text == 'undefined') continue;
      if (text.startsWith('http://') || text.startsWith('https://')) {
        return text;
      }
      return AppConfig.storagePublicUrl('community-offers', text);
    }
    return null;
  }
}

// ============================================================
// COMMUNITY IMAGE
// ============================================================
class _CommunityImage extends StatelessWidget {
  final String? image;

  const _CommunityImage({required this.image});

  @override
  Widget build(BuildContext context) {
    if (image == null || image!.isEmpty || image == 'null') {
      return Container(
        color: _UserHomePageState._cardSoft,
        child: Icon(Icons.sell_rounded,
            color: _UserHomePageState._textSecondary.withValues(alpha: 0.7),
            size: 36),
      );
    }

    return CachedNetworkImage(
      imageUrl: image!,
      fit: BoxFit.cover,
      errorWidget: (_, __, ___) => Container(
        color: _UserHomePageState._cardSoft,
        child: Icon(Icons.sell_rounded,
            color: _UserHomePageState._textSecondary.withValues(alpha: 0.7),
            size: 36),
      ),
    );
  }
}

// ============================================================
// COMMUNITY EMPTY
// ============================================================
class _CommunityEmptyCard extends StatelessWidget {
  final VoidCallback onAdd;

  const _CommunityEmptyCard({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: _UserHomePageState._card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _UserHomePageState._border, width: 1),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: _UserHomePageState._primaryRed.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.sell_rounded,
                  color: _UserHomePageState._primaryRed, size: 24),
            ),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ابدأ بيع بسعر رمزي',
                    style: TextStyle(
                      color: _UserHomePageState._textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'عندك حاجة مش محتاجها؟ اعرضها بسعر رمزي.',
                    style: TextStyle(
                      color: _UserHomePageState._textSecondary,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 10),
            ElevatedButton(
              onPressed: onAdd,
              style: ElevatedButton.styleFrom(
                backgroundColor: _UserHomePageState._primaryRed,
                foregroundColor: Colors.white,
                elevation: 0,
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text('أضف', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// ✅ ADD ACTION TILE
// ============================================================
class _AddActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color color;

  const _AddActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _UserHomePageState._cardSoft,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: _UserHomePageState._textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: _UserHomePageState._textSecondary,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_left_rounded,
                color: _UserHomePageState._textSecondary, size: 24),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// ✅ BOTTOM NAV ITEM
// ============================================================
class _BottomNavItem extends StatelessWidget {
  final int index;
  final int currentIndex;
  final IconData icon;
  final IconData outlinedIcon;
  final String label;
  final ValueChanged<int> onTap;

  const _BottomNavItem({
    required this.index,
    required this.currentIndex,
    required this.icon,
    required this.outlinedIcon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final selected = index == currentIndex;

    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(index),
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: selected
                      ? _UserHomePageState._primaryRed.withValues(alpha: 0.14)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(100),
                  border: selected
                      ? Border.all(
                          color: _UserHomePageState._primaryRed
                              .withValues(alpha: 0.4),
                          width: 1,
                        )
                      : null,
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: _UserHomePageState._primaryRed
                                .withValues(alpha: 0.28),
                            blurRadius: 12,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
                child: Icon(
                  selected ? icon : outlinedIcon,
                  size: 20,
                  color: selected
                      ? _UserHomePageState._primaryRed
                      : _UserHomePageState._textSecondary,
                ),
              ),
              SizedBox(height: 3),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                style: TextStyle(
                  color: selected
                      ? _UserHomePageState._primaryRed
                      : _UserHomePageState._textSecondary,
                  fontSize: 9.5,
                  fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
                ),
                child: Text(label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NearbySymbolicProviderCard extends StatelessWidget {
  final ServiceProvider provider;
  final double distanceKm;
  final VoidCallback onTap;

  const _NearbySymbolicProviderCard({
    required this.provider,
    required this.distanceKm,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = provider.profileImageUrl;
    final distanceLabel = distanceKm < 1
        ? '${(distanceKm * 1000).round()} متر'
        : '${distanceKm.toStringAsFixed(1)} كم';

    return SizedBox(
      width: 218,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          decoration: BoxDecoration(
            color: _UserHomePageState._card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _UserHomePageState._border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
                child: SizedBox(
                  height: 102,
                  child: imageUrl == null || imageUrl.isEmpty
                      ? Container(
                          color: _UserHomePageState._cardSoft,
                          child: Icon(
                            Icons.handyman_rounded,
                            color: _UserHomePageState._primaryRed,
                            size: 42,
                          ),
                        )
                      : CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Container(
                            color: _UserHomePageState._cardSoft,
                            child: Icon(
                              Icons.handyman_rounded,
                              color: _UserHomePageState._primaryRed,
                              size: 42,
                            ),
                          ),
                        ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      provider.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _UserHomePageState._textPrimary,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      provider.categoryName ?? 'خدمات متنوعة',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _UserHomePageState._textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    SizedBox(height: 9),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_rounded,
                          color: _UserHomePageState._primaryRed,
                          size: 15,
                        ),
                        SizedBox(width: 3),
                        Text(
                          distanceLabel,
                          style: TextStyle(
                            color: _UserHomePageState._textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        Icon(Icons.star_rounded,
                            color: Color(0xFFFFC107), size: 15),
                        SizedBox(width: 2),
                        Text(
                          provider.ratingAvg > 0
                              ? provider.ratingAvg.toStringAsFixed(1)
                              : 'جديد',
                          style: TextStyle(
                            color: _UserHomePageState._textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 9),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: _UserHomePageState._primaryRed
                            .withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        provider.pricingLabel,
                        style: TextStyle(
                          color: _UserHomePageState._primaryRed,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// LOADING
// ============================================================
class _LoadingHome extends StatelessWidget {
  const _LoadingHome();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _UserHomePageState._bg,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _UserHomePageState._primaryRed,
                    _UserHomePageState._primaryRedDark,
                  ],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color:
                        _UserHomePageState._primaryRed.withValues(alpha: 0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                Icons.volunteer_activism_rounded,
                color: Colors.white,
                size: 34,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: _UserHomePageState._primaryRed,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'وِصلة بتحضرلك الخير...',
              style: TextStyle(
                color: _UserHomePageState._textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeCategoryOfferCard extends StatelessWidget {
  final CategoryOffer offer;
  final VoidCallback onTap;
  const _HomeCategoryOfferCard({required this.offer, required this.onTap});

  String? _storageImageUrl(String? rawValue) {
    final value = rawValue?.trim();
    if (value == null ||
        value.isEmpty ||
        value == 'null' ||
        value == 'undefined') {
      return null;
    }

    final defaultBucket =
        offer.isInstitution ? 'institution-images' : 'community-offers';
    final uri = Uri.tryParse(value);
    if (uri != null && uri.hasScheme && uri.host.isNotEmpty) {
      final segments = uri.pathSegments;
      final objectIndex = segments.indexOf('object');
      if (objectIndex >= 0 && segments.length > objectIndex + 2) {
        final bucket = segments[objectIndex + 2];
        final path = segments.sublist(objectIndex + 3).join('/');
        if (path.isNotEmpty) {
          // Convert expired signed/authenticated URLs to a fresh public URL.
          return AppConfig.storagePublicUrl(bucket, path);
        }
      }
      return value;
    }

    var path = value;
    if (path.startsWith('$defaultBucket/')) {
      path = path.substring(defaultBucket.length + 1);
    }
    return AppConfig.storagePublicUrl(defaultBucket, path);
  }

  String? _imageUrl() {
    return _storageImageUrl(offer.image);
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = _imageUrl();
    final ownerLabel = offer.isInstitution
        ? (offer.ownerName ?? 'مؤسسة')
        : (offer.ownerName ?? 'عرض من المجتمع');
    final typeLabel = offer.isInstitution ? 'مؤسسة' : 'من المجتمع';

    return SizedBox(
      width: 214,
      child: Material(
        color: _UserHomePageState._card,
        borderRadius: BorderRadius.circular(22),
        elevation: 0,
        shadowColor: Colors.black.withValues(alpha: 0.12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 134,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    imageUrl == null
                        ? Container(
                            color: _UserHomePageState._cardSoft,
                            child: Icon(
                              Icons.image_outlined,
                              size: 44,
                              color: _UserHomePageState._primaryRed,
                            ),
                          )
                        : CachedNetworkImage(
                            imageUrl: imageUrl,
                            fit: BoxFit.cover,
                            memCacheWidth: 640,
                            placeholder: (_, __) => Container(
                              color: _UserHomePageState._cardSoft,
                              child: Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: _UserHomePageState._primaryRed,
                                ),
                              ),
                            ),
                            errorWidget: (_, __, ___) => Container(
                              color: _UserHomePageState._cardSoft,
                              child: Icon(
                                Icons.image_not_supported_outlined,
                                color: _UserHomePageState._textSecondary,
                                size: 36,
                              ),
                            ),
                          ),
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.18),
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.42),
                            ],
                            stops: const [0, 0.45, 1],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.94),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          typeLabel,
                          style: TextStyle(
                            color: _UserHomePageState._primaryRed,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                    if (offer.distanceDisplay != null)
                      Positioned(
                        bottom: 9,
                        right: 10,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.location_on_rounded,
                              size: 13,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              offer.distanceDisplay!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        offer.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _UserHomePageState._textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          height: 1.25,
                        ),
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              ownerLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: _UserHomePageState._textSecondary,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: _UserHomePageState._primaryRed.withValues(
                                alpha: 0.10,
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              offer.priceDisplay,
                              style: TextStyle(
                                color: _UserHomePageState._primaryRed,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
