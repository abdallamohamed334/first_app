// lib/features/userhome/presentation/pages/user_home_page.dart

import 'dart:async';
import 'dart:math' as math; // ✅ جديد: لحساب المسافة

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:loqma/core/config/app_config.dart';
import 'package:loqma/core/services/supabase_service.dart';

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
import 'package:loqma/features/home/presentation/pages/all_open_volunteer_donations_page.dart';
import 'package:loqma/features/home/presentation/widgets/home_leaderboard.dart';
import 'package:loqma/features/institutions/data/repositories/institution_offers_repository.dart';
import 'package:loqma/features/institutions/domain/entities/institution_offer.dart';
import 'package:loqma/features/notification/presentation/pages/notifications_page.dart';
import 'package:loqma/features/offers/domain/entities/food_offer.dart';
import 'package:loqma/features/offers/domain/entities/food_offer_status.dart';
import 'package:loqma/features/profile/presentation/pages/profile_page.dart';
// ✅ خدمات
import 'package:loqma/features/services/data/repositories/service_categories_repository.dart';
import 'package:loqma/features/services/domain/entities/service_category.dart';
import 'package:loqma/features/services/presentation/pages/service_category_page.dart';
import 'package:loqma/features/userhome/presentation/bloc/userhome_bloc.dart';
import 'package:loqma/features/userhome/presentation/bloc/userhome_state.dart';
import 'package:loqma/features/userhome/presentation/pages/category_offers_page.dart';
import 'package:loqma/features/userhome/presentation/pages/user_all_offers_page.dart';
import 'package:loqma/features/userhome/presentation/pages/user_institution_offers_page.dart';

// ✅ وضع الهوم: شراء أو خدمات
enum _HomeMode { buy, services }

class UserHomePage extends StatefulWidget {
  const UserHomePage({super.key});

  @override
  State<UserHomePage> createState() => _UserHomePageState();
}

class _UserHomePageState extends State<UserHomePage> {
  final TextEditingController _searchController = TextEditingController();
  final InstitutionOffersRepository _institutionOffersRepository =
      InstitutionOffersRepository();
  final CommunityNeedsRepository _needsRepository = CommunityNeedsRepository();
  final ServiceCategoriesRepository _serviceCategoriesRepository =
      ServiceCategoriesRepository();

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

  // ✅ جديد: موقع المستخدم الفعلي
  double? _userLat;
  double? _userLng;
  String _userCity = AppConfig.defaultCity;

  final PageController _bannerController = PageController(viewportFraction: 1);
  int _bannerIndex = 0;
  Timer? _bannerTimer;

  // ───────── ألوان الديزاين ─────────
  static const Color _bg = Color(0xFF0F0F0F);
  static const Color _card = Color(0xFF1C1C1E);
  static const Color _cardSoft = Color(0xFF2C2C2E);
  static const Color _primaryRed = Color(0xFFE31C25);
  static const Color _primaryRedDark = Color(0xFF8E0F14);
  static const Color _textPrimary = Colors.white;
  static const Color _textSecondary = Color(0xFFAAAAAA);
  static const Color _border = Color(0x14FFFFFF);
  static const Color _orange = Color(0xFFE28B00);
  static const Color _green = Color(0xFF2E9B5C);
  static const Color _blue = Color(0xFF3679C8);
  static const Color _purple = Color(0xFF6651B5);

  static const Set<String> _hiddenCategoryKeys = {};

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      // ✅ 1. نجيب موقع المستخدم الأول
      await _loadUserLocation();
      if (!mounted) return;

      // ✅ 2. نحمل البيانات بالترتيب
      context.read<UserHomeBloc>().add(const UserHomeStarted());
      _loadInstitutionOffers();
      _loadCommunityNeeds();
      _loadServiceCategories();
    });
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_onSearchChanged)
      ..dispose();
    _bannerTimer?.cancel();
    _bannerController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (!mounted) return;
    context.read<UserHomeBloc>().add(SearchOffers(_searchController.text));
    setState(() {});
  }

  // ═══════════════════════════════════════════════════════════
  // ✅ جديد: قراءة موقع المستخدم من Supabase
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
          .select('lat, lng, city')
          .eq('id', authUser.id)
          .maybeSingle();

      if (data == null || !mounted) return;

      final lat = (data['lat'] as num?)?.toDouble();
      final lng = (data['lng'] as num?)?.toDouble();
      final city = (data['city'] as String?)?.trim();

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

  // ═══════════════════════════════════════════════════════════
  // ✅ جديد: حساب المسافة (Haversine)
  // ═══════════════════════════════════════════════════════════
  double _distanceKm(double lat1, double lng1, double lat2, double lng2) {
    const p = 0.017453292519943295; // pi / 180
    final a = 0.5 -
        math.cos((lat2 - lat1) * p) / 2 +
        math.cos(lat1 * p) *
            math.cos(lat2 * p) *
            (1 - math.cos((lng2 - lng1) * p)) /
            2;
    return 12742 * math.asin(math.sqrt(a));
  }

  // ✅ جديد: استخراج lat/lng من InstitutionOffer
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

  // ✅ جديد: ترتيب العروض حسب المسافة
  List<InstitutionOffer> _sortByDistance(List<InstitutionOffer> offers) {
    if (_userLat == null || _userLng == null || offers.isEmpty) {
      return offers;
    }

    final withDist = <MapEntry<InstitutionOffer, double>>[];
    for (final o in offers) {
      final (lat, lng) = _extractLatLng(o);
      if (lat == null || lng == null) continue;
      final d = _distanceKm(_userLat!, _userLng!, lat, lng);
      withDist.add(MapEntry(o, d));
    }

    if (withDist.isEmpty) return offers;

    withDist.sort((a, b) => a.value.compareTo(b.value));
    return withDist.map((e) => e.key).toList(growable: false);
  }

  Future<void> _loadInstitutionOffers() async {
    if (_loadingInstitutionOffers) return;
    if (mounted) setState(() => _loadingInstitutionOffers = true);

    try {
      final offers = await _institutionOffersRepository.listAvailableOffers();
      if (!mounted) return;

      // ✅ نرتب حسب المسافة
      final sorted = _sortByDistance(offers);

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

  Future<void> _loadCommunityNeeds() async {
    if (_loadingNeeds) return;
    if (mounted) setState(() => _loadingNeeds = true);

    try {
      final needs = await _needsRepository.listNeeds(limit: 10);
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

  Future<void> _refresh() async {
    context.read<UserHomeBloc>().add(const UserHomeRefreshed());
    await _loadUserLocation();
    await Future.wait([
      _loadInstitutionOffers(),
      _loadCommunityNeeds(),
      _loadServiceCategories(),
    ]);
  }

  bool _isHiddenCategory(Map<String, dynamic> category) {
    final slug = (category['slug'] ?? '').toString().trim().toLowerCase();
    final name = (category['name_ar'] ?? '').toString().trim().toLowerCase();
    return _hiddenCategoryKeys.contains(slug) ||
        _hiddenCategoryKeys.contains(name);
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
      child: Theme(
        data: ThemeData.dark().copyWith(
          scaffoldBackgroundColor: _bg,
          colorScheme: const ColorScheme.dark(
            primary: _primaryRed,
            surface: _bg,
            onSurface: _textPrimary,
          ),
        ),
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
                    gradient: const LinearGradient(
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
                  child: const Icon(Icons.lock_outline_rounded,
                      size: 44, color: Colors.white),
                ),
                const SizedBox(height: 32),
                const Text(
                  'أهلًا بيك في لقمة 👋',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _textPrimary,
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'سجّل دخولك علشان تكتشف العروض القريبة منك وتشارك في مجتمع لقمة.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _textSecondary,
                    fontSize: 14.5,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 36),
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
                    child: const Text(
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
                  decoration: const BoxDecoration(
                    color: _card,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.cloud_off_rounded,
                      size: 42, color: _primaryRed),
                ),
                const SizedBox(height: 28),
                const Text(
                  'حصلت مشكلة بسيطة',
                  style: TextStyle(
                    color: _textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _textSecondary,
                    height: 1.6,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: () {
                    context.read<UserHomeBloc>().add(const UserHomeStarted());
                  },
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('إعادة المحاولة'),
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

    final buyCategories =
        state.categories.where((c) => !_isHiddenCategory(c)).toList();

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
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          isServices ? 'خدمات لقمة' : 'أقسام لقمة',
                          style: const TextStyle(
                            color: _textPrimary,
                            fontSize: 21,
                            fontWeight: FontWeight.w900,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          isServices
                              ? 'محترفين في كل المجالات'
                              : 'تصفح كل فئات الشراء',
                          style: const TextStyle(
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
                        icon: Icons.shopping_bag_rounded,
                        label: 'أقسام الشراء',
                        count: buyCategories.length,
                        color: _primaryRed,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: _buildCategoriesSwitcherTile(
                        mode: _HomeMode.services,
                        icon: Icons.handyman_rounded,
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
    required IconData icon,
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
            Icon(
              icon,
              size: 18,
              color: selected ? Colors.white : _textSecondary,
            ),
            const SizedBox(width: 8),
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
                const SizedBox(height: 1),
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
          const SizedBox(height: 18),
          const Text(
            'مفيش أقسام متاحة دلوقتي',
            style: TextStyle(
              color: _textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
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
        SliverToBoxAdapter(child: _buildSearchBar()),
        SliverToBoxAdapter(child: _buildLocationRow(state)),
        SliverToBoxAdapter(child: _buildHeroBanner(state)),
        SliverToBoxAdapter(child: _buildCategoriesGrid(state)),
        SliverToBoxAdapter(child: _buildUrgentSection(state.restaurantOffers)),
        SliverToBoxAdapter(
            child: _buildRestaurantSection(state.restaurantOffers)),
        SliverToBoxAdapter(child: _buildNeedsSection()),
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.only(bottom: 26),
            child: HomeLeaderboard(),
          ),
        ),
        SliverToBoxAdapter(
            child: _buildCommunitySection(state.communityOffers)),
        const SliverToBoxAdapter(child: SizedBox(height: 120)),
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
        SliverToBoxAdapter(child: _buildServicesSearchBar()),
        SliverToBoxAdapter(child: _buildServicesHeroBanner()),
        SliverToBoxAdapter(child: _buildServiceCategoriesGrid()),
        const SliverToBoxAdapter(child: SizedBox(height: 120)),
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
            const SizedBox(width: 4),
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
            const SizedBox(width: 8),
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
                const SizedBox(height: 1),
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

  Widget _buildServicesSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border, width: 1),
        ),
        child: TextField(
          style: const TextStyle(color: _textPrimary, fontSize: 14.5),
          decoration: InputDecoration(
            hintText: 'دور على سباك، كهربائي، نجار...',
            hintStyle: TextStyle(
              color: _textSecondary.withValues(alpha: 0.7),
              fontSize: 13.5,
            ),
            prefixIcon: const Icon(
              Icons.search_rounded,
              color: _textSecondary,
              size: 22,
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      ),
    );
  }

  Widget _buildServicesHeroBanner() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 22),
      child: Container(
        height: 150,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF3679C8), Color(0xFF6651B5)],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF3679C8).withValues(alpha: 0.35),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Positioned(
              left: -30,
              bottom: -40,
              child: Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
            ),
            Positioned(
              right: -20,
              top: -40,
              child: Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.06),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 22, vertical: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Icon(Icons.handyman_rounded,
                          color: Colors.white, size: 16),
                      SizedBox(width: 6),
                      Text(
                        'خدمات لقمة',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 6),
                  Text(
                    'محترفين قريبين منك 🔧',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                      height: 1.15,
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    'سباكة، كهرباء، نجارة، وأكتر',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 11.5,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceCategoriesGrid() {
    if (_loadingServiceCategories && _serviceCategories.isEmpty) {
      return const Padding(
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
                  gradient: const LinearGradient(
                    colors: [_primaryRed, _primaryRedDark],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const Expanded(
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
          const SizedBox(height: 14),
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
                  _serviceIconFromName(cat.icon ?? ''),
                  color: _blue,
                  size: 22,
                ),
              ),
              const SizedBox(height: 9),
              Flexible(
                child: Text(
                  cat.nameAr,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
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
          const SizedBox(height: 18),
          const Text(
            'مفيش خدمات متاحة دلوقتي',
            style: TextStyle(
              color: _textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
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

  IconData _serviceIconFromName(String name) {
    switch (name) {
      case 'plumbing':
        return Icons.plumbing_rounded;
      case 'electrical':
        return Icons.electrical_services_rounded;
      case 'carpentry':
        return Icons.handyman_rounded;
      case 'painting':
        return Icons.format_paint_rounded;
      case 'ac':
        return Icons.ac_unit_rounded;
      case 'appliances':
        return Icons.kitchen_rounded;
      case 'car':
        return Icons.directions_car_rounded;
      case 'maintenance':
        return Icons.build_rounded;
      case 'cleaning':
        return Icons.cleaning_services_rounded;
      case 'tutoring':
        return Icons.menu_book_rounded;
      case 'barber':
        return Icons.content_cut_rounded;
      case 'beauty':
        return Icons.spa_rounded;
      case 'it':
        return Icons.computer_rounded;
      case 'lock':
        return Icons.lock_rounded;
      case 'garden':
        return Icons.grass_rounded;
      case 'moving':
        return Icons.local_shipping_rounded;
      case 'construction':
        return Icons.construction_rounded;
      case 'other':
      default:
        return Icons.handyman_rounded;
    }
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_primaryRed, _primaryRedDark],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: _primaryRed.withValues(alpha: 0.35),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.restaurant_rounded, color: Colors.white, size: 16),
                SizedBox(width: 6),
                Text(
                  'لقمة',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'اكتشف اللي حواليك',
                  style: TextStyle(
                    color: _textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'عروض مطاعم، بقالة، وحاجات الناس',
                  style: TextStyle(
                    color: _textSecondary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                color: _card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _border, width: 1),
              ),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: _textPrimary, fontSize: 14.5),
                decoration: InputDecoration(
                  hintText: 'دور على وجبة، محل، أو حاجة...',
                  hintStyle: TextStyle(
                    color: _textSecondary.withValues(alpha: 0.7),
                    fontSize: 13.5,
                  ),
                  prefixIcon: const Icon(Icons.search_rounded,
                      color: _textSecondary, size: 22),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          onPressed: _searchController.clear,
                          icon: const Icon(Icons.close_rounded,
                              color: _textSecondary, size: 20),
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _border, width: 1),
            ),
            child: IconButton(
              onPressed: () {
                final user = SupabaseService().client.auth.currentUser;
                if (user == null) return;
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => NotificationsPage(userId: user.id),
                  ),
                );
              },
              icon: const Icon(Icons.notifications_none_rounded,
                  color: _primaryRed, size: 22),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // ✅ Location Row — بتعرض مدينة المستخدم الفعلية
  // ═══════════════════════════════════════════════════════════
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
                const Icon(Icons.location_on_rounded,
                    color: _primaryRed, size: 15),
                const SizedBox(width: 6),
                Text(
                  _userCity, // ✅ مدينة المستخدم الفعلية
                  style: const TextStyle(
                    color: _textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (hasLocation) ...[
                  const SizedBox(width: 8),
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
                    child: const Row(
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

  Widget _buildHeroBanner(UserHomeLoaded state) {
    final banners = state.banners;
    final hasBanners = banners.isNotEmpty;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _startBannerAutoPlay(banners.length);
    });

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 22),
      child: Column(
        children: [
          Container(
            height: 172,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: hasBanners
                ? PageView.builder(
                    controller: _bannerController,
                    itemCount: banners.length,
                    onPageChanged: (i) => setState(() => _bannerIndex = i),
                    itemBuilder: (context, index) {
                      return _BannerImage(banner: banners[index]);
                    },
                  )
                : _buildFallbackBanner(),
          ),
          if (hasBanners && banners.length > 1) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(banners.length, (i) {
                final active = i == _bannerIndex;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: active ? 22 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: active
                        ? _primaryRed
                        : _textSecondary.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: active
                        ? [
                            BoxShadow(
                              color: _primaryRed.withValues(alpha: 0.5),
                              blurRadius: 8,
                            ),
                          ]
                        : null,
                  ),
                );
              }),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFallbackBanner() {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [_primaryRed, _primaryRedDark],
            ),
          ),
        ),
        Positioned(
          left: -40,
          bottom: -50,
          child: Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.07),
            ),
          ),
        ),
        Positioned(
          right: -20,
          top: -50,
          child: Container(
            width: 130,
            height: 130,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.05),
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Icon(Icons.auto_awesome_rounded,
                      color: Colors.white, size: 18),
                  SizedBox(width: 6),
                  Text(
                    'أهلًا بيك',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10),
              Text(
                'لقمة بتجمعنا 🤝',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                  height: 1.2,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'اكتشف أكل وفرص قريبة منك\nوساعد في تقليل الهدر',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCategoriesGrid(UserHomeLoaded state) {
    if (state.categoriesLoading && state.categories.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 30),
        child: Center(
          child: CircularProgressIndicator(color: _primaryRed),
        ),
      );
    }

    final categories =
        state.categories.where((c) => !_isHiddenCategory(c)).toList();

    if (categories.isEmpty) {
      return const SizedBox.shrink();
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

    if (id.isEmpty) return const SizedBox.shrink();

    return Material(
      color: _card,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _openCategory(category, state),
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
              const SizedBox(height: 9),
              Flexible(
                child: Text(
                  name,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
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

  void _openCategory(
    Map<String, dynamic> category,
    UserHomeLoaded state,
  ) {
    final id = (category['id']?.toString() ?? '').trim();
    final name = category['name_ar']?.toString() ?? '';
    final slug = (category['slug']?.toString() ?? '').trim();

    final isRestaurant = slug == 'food' ||
        name.contains('مطعم') ||
        name.contains('مطاعم') ||
        name.contains('أطعمة') ||
        name.contains('مأكولات') ||
        name.contains('اكل') ||
        name.contains('أكل');

    final isGrocery = slug.startsWith('grocery') ||
        name.contains('بقال') ||
        name.contains('سوبرماركت');

    if (isRestaurant) {
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

    if (isGrocery) {
      final restaurantIds = state.categories
          .where((c) {
            final cSlug = (c['slug'] ?? '').toString().trim();
            final cName = (c['name_ar'] ?? '').toString();
            return cSlug == 'food' ||
                cName.contains('مطعم') ||
                cName.contains('مطاعم') ||
                cName.contains('أطعمة') ||
                cName.contains('مأكولات') ||
                cName.contains('اكل') ||
                cName.contains('أكل');
          })
          .map((c) => (c['id']?.toString() ?? '').trim())
          .where((cid) => cid.isNotEmpty)
          .toSet();

      final filtered = _institutionOffers.where((o) {
        final catId = (o.marketplaceCategoryId ?? '').trim();
        return catId.isNotEmpty && !restaurantIds.contains(catId);
      }).toList(growable: false);

      final foodOffers = filtered
          .map((o) => _institutionToFoodOffer(o, businessType: 'grocery'))
          .toList(growable: false);

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => UserInstitutionOffersPage(offers: foodOffers),
        ),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CategoryOffersPage(
          categoryId: id,
          categoryName: name,
          categorySlug: slug,
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // ✅ معدّل: نستخدم إحداثيات المؤسسة الحقيقية
  // ═══════════════════════════════════════════════════════════
  FoodOffer _institutionToFoodOffer(
    InstitutionOffer o, {
    String businessType = 'restaurant',
  }) {
    final (offerLat, offerLng) = _extractLatLng(o);

    // ✅ fallback لإحداثيات المستخدم لو المؤسسة ملهاش إحداثيات
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
      latitude: lat, // ✅ من المؤسسة الحقيقية
      longitude: lng, // ✅
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

    if (urgent.isEmpty) return const SizedBox.shrink();

    return _section(
      title: 'محتاجين سرعة 🔥',
      trailing: null,
      child: SizedBox(
        height: 240,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          scrollDirection: Axis.horizontal,
          itemCount: urgent.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
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
              child: const Text(
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
                separatorBuilder: (_, __) => const SizedBox(width: 12),
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
        child: const Text(
          'عرض الكل',
          style: TextStyle(
            color: _primaryRed,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      child: _loadingNeeds && visible.isEmpty
          ? const Padding(
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
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
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
          gradient: const LinearGradient(
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
                  child: const Icon(
                    Icons.volunteer_activism_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
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
            const SizedBox(height: 18),
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
                const SizedBox(width: 10),
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

  Widget _buildCommunitySection(List<Map<String, dynamic>> offers) {
    final visible = offers
        .where((o) => o['status']?.toString() == 'available')
        .take(10)
        .toList(growable: false);

    return _section(
      title: 'شراء بسعر رمزي 💰',
      trailing: GestureDetector(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AddCommunityOfferPage()),
          );
        },
        child: const Text(
          'أضف عرض',
          style: TextStyle(
            color: _primaryRed,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      child: visible.isEmpty
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
                itemCount: visible.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final offer = visible[index];
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
                    gradient: const LinearGradient(
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
                    style: const TextStyle(
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
          const SizedBox(height: 14),
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
              decoration: const BoxDecoration(
                color: _cardSoft,
                shape: BoxShape.circle,
              ),
              child: Icon(icon,
                  color: _textSecondary.withValues(alpha: 0.7), size: 26),
            ),
            const SizedBox(height: 14),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(
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
    return FloatingActionButton(
      heroTag: 'loqma_home_add_button',
      onPressed: _showAddSheet,
      backgroundColor: _primaryRed,
      foregroundColor: Colors.white,
      elevation: 8,
      shape: const CircleBorder(),
      child: Container(
        width: 60,
        height: 60,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: _primaryRed.withValues(alpha: 0.4),
              blurRadius: 12,
            ),
          ],
        ),
        child: const Icon(Icons.add_rounded, size: 30),
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
                  const SizedBox(height: 18),
                  const Text(
                    'إنت عايز تعمل إيه؟',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                      color: _textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'اختار من الخيارات',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: _textSecondary,
                    ),
                  ),
                  const SizedBox(height: 22),
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
                  const SizedBox(height: 12),
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
                  const SizedBox(height: 12),
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
        border: const Border(
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
              const SizedBox(width: 6),
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
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF3679C8), Color(0xFF6651B5)],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
              ),
              child: Stack(
                children: [
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
                  const Center(
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
                          const SizedBox(width: 3),
                          Text(
                            urgencyData.$2,
                            style: const TextStyle(
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
                    style: const TextStyle(
                      color: _UserHomePageState._textPrimary,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w900,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 8),
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
                        const Icon(Icons.local_offer_rounded,
                            size: 10, color: _UserHomePageState._textSecondary),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            category,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _UserHomePageState._textSecondary,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (city.isNotEmpty) ...[
                        Icon(
                          Icons.location_on_rounded,
                          size: 11,
                          color: _UserHomePageState._textSecondary
                              .withValues(alpha: 0.7),
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            city,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
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
                          style: const TextStyle(
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
// ✅ LARGE FOOD CARD
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
                        gradient: const LinearGradient(
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
                      child: const Text(
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
                    style: const TextStyle(
                      color: _UserHomePageState._textPrimary,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    offer.businessName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _UserHomePageState._textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.schedule_rounded,
                          size: 13, color: _UserHomePageState._primaryRed),
                      const SizedBox(width: 4),
                      Text(
                        offer.timeRemaining,
                        style: const TextStyle(
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
// ✅ FOOD CARD
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
                    style: const TextStyle(
                      color: _UserHomePageState._primaryRed,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    offer.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _UserHomePageState._textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    offer.businessName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _UserHomePageState._textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (offer.distanceMeters != null) ...[
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(Icons.location_on_rounded,
                            size: 11,
                            color: _UserHomePageState._textSecondary
                                .withValues(alpha: 0.7)),
                        const SizedBox(width: 3),
                        Text(
                          offer.distanceDisplay,
                          style: const TextStyle(
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
        child: const Center(
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
                        style: const TextStyle(
                          color: _UserHomePageState._primaryRed,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _UserHomePageState._textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (description.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _UserHomePageState._textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                      const SizedBox(height: 6),
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
                              style: const TextStyle(
                                color: _UserHomePageState._textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (distance != null) ...[
                            const SizedBox(width: 8),
                            Text(
                              distance,
                              style: const TextStyle(
                                color: _UserHomePageState._textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (expiresAt != null) ...[
                        const SizedBox(height: 6),
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
                    style: const TextStyle(
                      color: _UserHomePageState._primaryRed,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _UserHomePageState._textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    category,
                    style: const TextStyle(
                      color: _UserHomePageState._textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (distance != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      distance,
                      style: const TextStyle(
                        color: _UserHomePageState._textSecondary,
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                  if (expiresAt != null) ...[
                    const SizedBox(height: 6),
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
    final image = offer['image']?.toString();
    if (image != null && image.isNotEmpty && image != 'null') return image;

    final images = offer['images'];
    if (images is List && images.isNotEmpty) {
      final first = images.first?.toString();
      if (first != null && first.isNotEmpty && first != 'null') return first;
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
              child: const Icon(Icons.sell_rounded,
                  color: _UserHomePageState._primaryRed, size: 24),
            ),
            const SizedBox(width: 14),
            const Expanded(
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
            const SizedBox(width: 10),
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
              child: const Text('أضف',
                  style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// BANNER IMAGE
// ============================================================
class _BannerImage extends StatelessWidget {
  final dynamic banner;

  const _BannerImage({required this.banner});

  @override
  Widget build(BuildContext context) {
    String? imageUrl;
    try {
      final json = (banner as dynamic).toJson();
      imageUrl = json['image_url']?.toString();
    } catch (_) {}

    if (imageUrl == null || imageUrl.isEmpty || imageUrl == 'null') {
      return Container(
        color: _UserHomePageState._cardSoft,
        child: const Center(
          child: Icon(Icons.restaurant_menu_rounded,
              color: _UserHomePageState._textSecondary, size: 42),
        ),
      );
    }

    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: BoxFit.cover,
      errorWidget: (_, __, ___) => Container(
        color: _UserHomePageState._cardSoft,
        child: const Center(
          child: Icon(Icons.restaurant_menu_rounded,
              color: _UserHomePageState._textSecondary, size: 42),
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
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: _UserHomePageState._textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: _UserHomePageState._textSecondary,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_left_rounded,
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
              const SizedBox(height: 3),
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
                gradient: const LinearGradient(
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
              child: const Icon(Icons.volunteer_activism_rounded,
                  color: Colors.white, size: 34),
            ),
            const SizedBox(height: 24),
            const SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: _UserHomePageState._primaryRed,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'لقمة بتحضرلك الخير...',
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
