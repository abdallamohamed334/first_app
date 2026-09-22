// lib/features/userhome/presentation/pages/user_home_page.dart

import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:loqma/core/services/supabase_service.dart';

import 'package:loqma/features/booking/presentation/pages/my_bookings_page.dart';
import 'package:loqma/features/charity/presentation/pages/add_charity_donation_page.dart';
import 'package:loqma/features/charity/presentation/pages/person_offer_details_page.dart';
import 'package:loqma/features/community/presentation/pages/add_community_offer_page.dart';
import 'package:loqma/features/community/presentation/pages/add_community_need_page.dart';
import 'package:loqma/features/community/presentation/pages/community_needs_page.dart';
import 'package:loqma/features/community/presentation/pages/community_offer_details_page.dart';
import 'package:loqma/features/community/presentation/pages/community_tracking_page.dart';
import 'package:loqma/features/community/presentation/pages/my_community_needs_page.dart';
import 'package:loqma/features/community/presentation/utils/offer_expiry_helper.dart';
import 'package:loqma/features/home/presentation/pages/all_open_volunteer_donations_page.dart';
import 'package:loqma/features/institutions/data/repositories/institution_offers_repository.dart';
import 'package:loqma/features/institutions/domain/entities/institution_offer.dart';
import 'package:loqma/features/notification/presentation/pages/notifications_page.dart';
import 'package:loqma/features/offers/domain/entities/food_offer.dart';
import 'package:loqma/features/offers/domain/entities/food_offer_status.dart';
import 'package:loqma/features/profile/presentation/pages/profile_page.dart';
import 'package:loqma/features/userhome/presentation/bloc/userhome_bloc.dart';
import 'package:loqma/features/userhome/presentation/bloc/userhome_state.dart';
import 'package:loqma/features/userhome/presentation/pages/category_offers_page.dart';
import 'package:loqma/features/userhome/presentation/pages/user_all_offers_page.dart';
import 'package:loqma/features/userhome/presentation/pages/user_institution_offers_page.dart';

class UserHomePage extends StatefulWidget {
  const UserHomePage({super.key});

  @override
  State<UserHomePage> createState() => _UserHomePageState();
}

enum _HomeMode { discover, rescue }

class _UserHomePageState extends State<UserHomePage> {
  final TextEditingController _searchController = TextEditingController();
  final InstitutionOffersRepository _institutionOffersRepository =
      InstitutionOffersRepository();

  _HomeMode _mode = _HomeMode.discover;
  int _currentPage = 0;
  List<InstitutionOffer> _institutionOffers = [];
  bool _loadingInstitutionOffers = false;

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
  static const Color _border = Color(0x14FFFFFF); // white 8%
  static const Color _orange = Color(0xFFE28B00);
  static const Color _green = Color(0xFF2E9B5C);

  static const Set<String> _hiddenCategoryKeys = {};

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<UserHomeBloc>().add(const UserHomeStarted());
      _loadInstitutionOffers();
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

  Future<void> _loadInstitutionOffers() async {
    if (_loadingInstitutionOffers) return;
    if (mounted) setState(() => _loadingInstitutionOffers = true);

    try {
      final offers = await _institutionOffersRepository.listAvailableOffers();
      if (!mounted) return;
      setState(() => _institutionOffers = offers);
      debugPrint('✅ Loaded institutionOffers: ${offers.length}');
    } catch (e) {
      debugPrint('❌ loadInstitutionOffers error: $e');
      if (!mounted) return;
      setState(() => _institutionOffers = []);
    } finally {
      if (!mounted) return;
      setState(() => _loadingInstitutionOffers = false);
    }
  }

  Future<void> _refresh() async {
    context.read<UserHomeBloc>().add(const UserHomeRefreshed());
    await _loadInstitutionOffers();
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
          const CommunityNeedsPage(),
          const CommunityTrackingPage(),
          const ProfilePage(),
        ],
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
      floatingActionButton: _currentPage == 0 ? _buildAddButton() : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  Widget _buildHomeContent(UserHomeLoaded state) {
    return SafeArea(
      child: RefreshIndicator(
        color: _primaryRed,
        backgroundColor: _card,
        onRefresh: _refresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            SliverToBoxAdapter(child: _buildTopTabs()),
            SliverToBoxAdapter(child: _buildSearchBar()),
            SliverToBoxAdapter(child: _buildLocationRow(state)),
            SliverToBoxAdapter(child: _buildHeroBanner(state)),
            SliverToBoxAdapter(child: _buildCategoriesGrid(state)),
            SliverToBoxAdapter(child: _buildModeSwitch()),
            if (_mode == _HomeMode.discover) ...[
              SliverToBoxAdapter(
                  child: _buildUrgentSection(state.restaurantOffers)),
              SliverToBoxAdapter(
                  child: _buildRestaurantSection(state.restaurantOffers)),
              SliverToBoxAdapter(
                  child: _buildCommunitySection(state.communityOffers)),
            ],
            if (_mode == _HomeMode.rescue) ...[
              SliverToBoxAdapter(child: _buildRescueHero()),
              SliverToBoxAdapter(child: _buildNeedsSection()),
              SliverToBoxAdapter(child: _buildDeliveryDonationsSection(state)),
              SliverToBoxAdapter(child: _buildVolunteerTasksSection(state)),
            ],
            const SliverToBoxAdapter(child: SizedBox(height: 120)),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // ✅ Top Tabs — تصميم Pill حديث
  // ═══════════════════════════════════════════════════════════
  Widget _buildTopTabs() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Row(
        children: [
          // Logo Pill
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
          const SizedBox(width: 10),
          // Discover Tab
          Expanded(
            child: _TopTabPill(
              label: 'اكتشف',
              icon: Icons.explore_rounded,
              selected: _mode == _HomeMode.discover,
              onTap: () => setState(() => _mode = _HomeMode.discover),
            ),
          ),
          const SizedBox(width: 8),
          // Rescue Tab
          Expanded(
            child: _TopTabPill(
              label: 'إنقاذ',
              icon: Icons.favorite_rounded,
              selected: _mode == _HomeMode.rescue,
              onTap: () => setState(() => _mode = _HomeMode.rescue),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // ✅ Search Bar — تصميم أنعم
  // ═══════════════════════════════════════════════════════════
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
  // ✅ Location — Chip style
  // ═══════════════════════════════════════════════════════════
  Widget _buildLocationRow(UserHomeLoaded state) {
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
                  state.userCity?.isNotEmpty == true
                      ? state.userCity!
                      : 'اختر موقعك',
                  style: const TextStyle(
                    color: _textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.keyboard_arrow_down_rounded,
                    color: _textSecondary, size: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // ✅ Hero Banner — تصميم أعمق
  // ═══════════════════════════════════════════════════════════
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
        // Decorative circles
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
        Positioned(
          right: 90,
          top: 30,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.08),
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

  // ═══════════════════════════════════════════════════════════
  // ✅ Categories Grid
  // ═══════════════════════════════════════════════════════════
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

  // ═══════════════════════════════════════════════════════════
  // ✅ Open Category — التوجيه حسب التصنيف
  // ═══════════════════════════════════════════════════════════
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

    debugPrint('═══════════════════════════════════');
    debugPrint('📂 _openCategory: $name');
    debugPrint('   slug: $slug | id: $id');
    debugPrint('   isRestaurant: $isRestaurant | isGrocery: $isGrocery');
    debugPrint('   _institutionOffers count: ${_institutionOffers.length}');
    debugPrint('═══════════════════════════════════');

    if (isRestaurant) {
      final filtered = _institutionOffers
          .where((o) => (o.marketplaceCategoryId ?? '').trim() == id)
          .toList(growable: false);

      debugPrint('🍽️ Restaurant filtered: ${filtered.length}');

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

      debugPrint('🍽️ Restaurant IDs to exclude: $restaurantIds');

      final filtered = _institutionOffers.where((o) {
        final catId = (o.marketplaceCategoryId ?? '').trim();
        return catId.isNotEmpty && !restaurantIds.contains(catId);
      }).toList(growable: false);

      debugPrint('🛒 Grocery filtered: ${filtered.length}');

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

  FoodOffer _institutionToFoodOffer(
    InstitutionOffer o, {
    String businessType = 'restaurant',
  }) {
    return FoodOffer(
      id: o.id,
      title: o.title,
      description: o.description,
      quantity: o.remainingQuantity > 0 ? o.remainingQuantity : o.quantity,
      foodType: o.foodType ?? o.category,
      expiryTime: o.expiresAt,
      pickupBefore: o.pickupBefore ?? o.expiresAt,
      pickupLocation: o.pickupLocation ?? 'موقع غير محدد',
      latitude: 30.0444,
      longitude: 31.2357,
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

  // ═══════════════════════════════════════════════════════════
  // ✅ Mode Switch — Segmented Control
  // ═══════════════════════════════════════════════════════════
  Widget _buildModeSwitch() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border, width: 1),
        ),
        child: Row(
          children: [
            Expanded(
              child: _ModeButton(
                label: 'اكتشف العروض',
                icon: Icons.storefront_rounded,
                selected: _mode == _HomeMode.discover,
                onTap: () => setState(() => _mode = _HomeMode.discover),
              ),
            ),
            Expanded(
              child: _ModeButton(
                label: 'إنقاذ ومساعدة',
                icon: Icons.volunteer_activism_rounded,
                selected: _mode == _HomeMode.rescue,
                onTap: () => setState(() => _mode = _HomeMode.rescue),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // Sections
  // ═══════════════════════════════════════════════════════════
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

  Widget _buildNeedsSection() {
    return _section(
      title: 'الناس محتاجه ؟',
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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Container(
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
      ),
    );
  }

  Widget _buildRescueHero() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 22),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              _primaryRed.withValues(alpha: 0.15),
              _primaryRed.withValues(alpha: 0.05),
            ],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _primaryRed.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: const BoxDecoration(
                color: _primaryRed,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.volunteer_activism_rounded,
                  color: Colors.white, size: 26),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'خلينا ننقذ أكتر ❤️',
                    style: TextStyle(
                      color: _textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'ساهم في توصيل التبرعات أو ساعد حد قريب منك.',
                    style: TextStyle(
                      color: _textSecondary,
                      fontSize: 12,
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

  Widget _buildDeliveryDonationsSection(UserHomeLoaded state) {
    final donations = state.deliveryDonations.take(5).toList(growable: false);

    return _section(
      title: 'تبرعات محتاجة توصيل 🚚',
      trailing: GestureDetector(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
                builder: (_) => const AllOpenVolunteerDonationsPage()),
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
      child: donations.isEmpty
          ? _emptyMini(Icons.volunteer_activism_outlined,
              'مفيش تبرعات محتاجة متطوعين دلوقتي')
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  for (int i = 0; i < donations.length; i++) ...[
                    _DonationMiniCard(
                      title: donations[i].title,
                      subtitle: donations[i].description,
                    ),
                    if (i != donations.length - 1) const SizedBox(height: 10),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildVolunteerTasksSection(UserHomeLoaded state) {
    final tasks = state.deliveryTasks.take(5).toList();

    return _section(
      title: 'مهام تطوع 🤲',
      trailing: null,
      child: tasks.isEmpty
          ? _emptyMini(
              Icons.handshake_outlined, 'لا توجد مهام تطوع متاحة حاليًا')
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  for (int i = 0; i < tasks.length; i++) ...[
                    _VolunteerTaskCard(task: tasks[i]),
                    if (i != tasks.length - 1) const SizedBox(height: 10),
                  ],
                ],
              ),
            ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // ✅ Section — تصميم أحدث
  // ═══════════════════════════════════════════════════════════
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
              decoration: BoxDecoration(
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
    return BottomAppBar(
      color: _card,
      elevation: 0,
      shape: const CircularNotchedRectangle(),
      notchMargin: 10,
      height: 72,
      padding: EdgeInsets.zero,
      child: Container(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: _border, width: 1),
          ),
        ),
        child: SizedBox(
          height: 72,
          child: Row(
            children: [
              _BottomNavItem(
                index: 0,
                currentIndex: _currentPage,
                icon: Icons.home_rounded,
                label: 'الرئيسية',
                onTap: _selectPage,
              ),
              _BottomNavItem(
                index: 1,
                currentIndex: _currentPage,
                icon: Icons.back_hand_rounded,
                label: 'الاحتياجات',
                onTap: _selectPage,
              ),
              const SizedBox(width: 68),
              _BottomNavItem(
                index: 2,
                currentIndex: _currentPage,
                icon: Icons.add_chart,
                label: 'الطلبات',
                onTap: _selectPage,
              ),
              _BottomNavItem(
                index: 3,
                currentIndex: _currentPage,
                icon: Icons.person_outline_rounded,
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
// ✅ Top Tab Pill
// ============================================================
class _TopTabPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _TopTabPill({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? _UserHomePageState._primaryRed
              : _UserHomePageState._cardSoft,
          borderRadius: BorderRadius.circular(14),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color:
                        _UserHomePageState._primaryRed.withValues(alpha: 0.3),
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
              size: 16,
              color:
                  selected ? Colors.white : _UserHomePageState._textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color:
                    selected ? Colors.white : _UserHomePageState._textPrimary,
                fontSize: 13.5,
                fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// NEEDS ACTION PILL
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
// SEGMENT BUTTON (مش مستخدم حاليًا — محتفظين بيها للتوافق)
// ============================================================
class _SegmentButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _SegmentButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? _UserHomePageState._primaryRed : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color:
                  selected ? Colors.white : _UserHomePageState._textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color:
                    selected ? Colors.white : _UserHomePageState._textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// ✅ MODE BUTTON — تصميم أحدث
// ============================================================
class _ModeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ModeButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(
                  colors: [
                    _UserHomePageState._primaryRed,
                    _UserHomePageState._primaryRedDark,
                  ],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                )
              : null,
          color: selected ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color:
                        _UserHomePageState._primaryRed.withValues(alpha: 0.3),
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
              size: 15,
              color:
                  selected ? Colors.white : _UserHomePageState._textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color:
                    selected ? Colors.white : _UserHomePageState._textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
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
    this.fullWidth = false,
  });

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
// ✅ DONATION CARD
// ============================================================
class _DonationMiniCard extends StatelessWidget {
  final String title;
  final String subtitle;

  const _DonationMiniCard({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _UserHomePageState._card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _UserHomePageState._border, width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _UserHomePageState._primaryRed.withValues(alpha: 0.18),
                  _UserHomePageState._primaryRed.withValues(alpha: 0.06),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.volunteer_activism_rounded,
                color: _UserHomePageState._primaryRed, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _UserHomePageState._textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _UserHomePageState._textSecondary,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// ✅ VOLUNTEER TASK
// ============================================================
class _VolunteerTaskCard extends StatelessWidget {
  final Map<String, dynamic> task;

  const _VolunteerTaskCard({required this.task});

  @override
  Widget build(BuildContext context) {
    final title = task['title']?.toString() ?? 'مهمة توصيل';
    final status = task['status']?.toString() ?? 'pending';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _UserHomePageState._card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _UserHomePageState._border, width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _UserHomePageState._cardSoft,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.local_shipping_rounded,
                color: _UserHomePageState._primaryRed, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _UserHomePageState._textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  status,
                  style: const TextStyle(
                    color: _UserHomePageState._textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
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
// ✅ ADD ACTION TILE — بألوان مخصصة
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
  final String label;
  final ValueChanged<int> onTap;

  const _BottomNavItem({
    required this.index,
    required this.currentIndex,
    required this.icon,
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: selected
                    ? _UserHomePageState._primaryRed.withValues(alpha: 0.15)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(100),
              ),
              child: Icon(
                icon,
                size: 22,
                color: selected
                    ? _UserHomePageState._primaryRed
                    : _UserHomePageState._textSecondary,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: selected
                    ? _UserHomePageState._primaryRed
                    : _UserHomePageState._textSecondary,
                fontSize: 10,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ],
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
