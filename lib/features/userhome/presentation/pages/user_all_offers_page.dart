// lib/features/userhome/presentation/pages/user_all_offers_page.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:loqma/core/services/supabase_service.dart';
import 'package:loqma/features/charity/presentation/pages/person_offer_details_page.dart';
import 'package:loqma/features/notification/presentation/bloc/notification_bloc.dart';
import 'package:loqma/features/notification/presentation/bloc/notification_state.dart';
import 'package:loqma/features/notification/presentation/pages/notifications_page.dart';
import 'package:loqma/features/offers/domain/entities/food_offer.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:loqma/features/userhome/data/repositories/userhome_repository.dart';
import 'package:loqma/features/userhome/presentation/bloc/userhome_bloc.dart';
import 'package:loqma/features/userhome/presentation/bloc/userhome_state.dart';
import 'package:loqma/features/userhome/presentation/pages/my_restaurant_requests_tab.dart';

class UserAllOffersPage extends StatefulWidget {
  final List<FoodOffer>? offers;

  const UserAllOffersPage({super.key, this.offers});

  @override
  State<UserAllOffersPage> createState() => _UserAllOffersPageState();
}

class _UserAllOffersPageState extends State<UserAllOffersPage>
    with SingleTickerProviderStateMixin {
  // ✅ TabController? (nullable) — مضمونة تشتغل
  TabController? _tabController;

  late final TextEditingController _searchController;

  String _query = '';
  String _category = 'الكل';

  List<FoodOffer> _restaurantOffers = [];
  bool _isLoading = true;
  StreamSubscription<UserHomeState>? _blocSubscription;

  static const _categories = <String>[
    'الكل',
    'وجبات',
    'مخبوزات',
    'حلويات',
    'فواكه',
    'مشروبات',
  ];

  // ───────── نفس هوية التطبيق (Home/Offers Hub) ─────────
  static const Color _bg = Color(0xFF0F0F0F);
  static const Color _card = Color(0xFF1C1C1E);
  static const Color _cardSoft = Color(0xFF2C2C2E);
  static const Color _primaryRed = Color(0xFFE31C25);
  static const Color _textPrimary = Colors.white;
  static const Color _textSecondary = Color(0xFFAAAAAA);
  static const Color _orange = Color(0xFFE28B00);

  @override
  void initState() {
    super.initState();

    // ✅ 1) TabController أول حاجة
    _tabController = TabController(length: 2, vsync: this);

    // ✅ 2) بعدين TextEditingController
    _searchController = TextEditingController()..addListener(_onSearchChanged);

    // ✅ 3) بعدين postFrameCallback
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      await _loadOffers();
      _listenToBloc();
    });
  }

  @override
  void dispose() {
    _blocSubscription?.cancel();
    _tabController?.dispose();
    _searchController
      ..removeListener(_onSearchChanged)
      ..dispose();
    super.dispose();
  }

  // ============================================================
  // Listen to UserHomeBloc
  // ============================================================

  void _listenToBloc() {
    try {
      final bloc = context.read<UserHomeBloc>();

      // ✅ نلغي أي اشتراك قديم قبل ما نعمل واحد جديد، عشان منجمعش
      // أكتر من listener مع كل دخول وخروج من الصفحة.
      _blocSubscription?.cancel();
      _blocSubscription = bloc.stream.listen((state) {
        if (!mounted) return;

        if (state is UserHomeLoaded) {
          _loadOffersFromState(state);
        }
      });
    } catch (_) {
      // الـ Bloc مش موجود
    }
  }

  // ============================================================
  // Load Offers From State
  // ============================================================

  void _loadOffersFromState(UserHomeLoaded state) {
    final restaurants = state.restaurantOffers
        .where((o) => o.isAvailable && !o.isExpired)
        .toList();

    if (!mounted) return;

    setState(() {
      _restaurantOffers = restaurants;
      _isLoading = false;
    });
  }

  // ============================================================
  // تحميل العروض
  // ============================================================

  Future<void> _loadOffers({bool reload = false}) async {
    if (mounted) {
      setState(() => _isLoading = true);
    }

    if (reload) {
      await _reloadFromRepository();
      return;
    }

    // ✅ الأولوية دايمًا لحالة الـ Bloc الحيّة — هي نفس المصدر اللي
    // الريفريش بيستخدمه، فلو استخدمناها الأول من غير ما ننتظر،
    // الصفحة هتعرض نفس البيانات الصح من أول فتح، مش بعد الريفريش بس.
    try {
      final state = context.read<UserHomeBloc>().state;
      if (state is UserHomeLoaded) {
        _loadOffersFromState(state);
        return;
      }
    } catch (_) {
      // الـ Bloc مش جاهز لسه، نكمل على القايمة اللي جايه من الصفحة
    }

    // ✅ لو الـ Bloc لسه مش جاهز، استخدم القايمة الجايه من الصفحة
    // كعرض مبدئي بس (placeholder) لحد ما الـ Bloc يبعت الداتا الصح
    // عن طريق _listenToBloc().
    if (widget.offers != null && widget.offers!.isNotEmpty) {
      final restaurants = widget.offers!
          .where((o) => _isRestaurantOffer(o))
          .where((o) => o.isAvailable && !o.isExpired)
          .toList();

      if (!mounted) return;

      if (restaurants.isNotEmpty) {
        setState(() {
          _restaurantOffers = restaurants;
          _isLoading = false;
        });
        return;
      }
    }

    await _loadFromBloc();
  }

  Future<void> _reloadFromRepository() async {
    try {
      final state = context.read<UserHomeBloc>().state;

      if (state is! UserHomeLoaded) {
        await _loadFromBloc();
        await Future<void>.delayed(const Duration(milliseconds: 400));
        return;
      }

      final latitude = state.userLatitude;
      final longitude = state.userLongitude;

      if (latitude == null || longitude == null) {
        await _loadFromBloc();
        await Future<void>.delayed(const Duration(milliseconds: 400));
        return;
      }

      final repository = UserHomeRepository(
        supabaseService: SupabaseService(),
      );

      final offers = await repository.getNearbyRestaurantOffers(
        latitude: latitude,
        longitude: longitude,
      );

      if (!mounted) return;

      setState(() {
        _restaurantOffers =
            offers.where((o) => o.isAvailable && !o.isExpired).toList();
        _isLoading = false;
      });

      try {
        context.read<UserHomeBloc>().add(const UserHomeRefreshed());
      } catch (_) {}
    } catch (e) {
      debugPrint('⚠️ reload error: $e');

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });
    }

    await Future<void>.delayed(const Duration(milliseconds: 300));
  }

  Future<void> _loadFromBloc() async {
    try {
      final state = context.read<UserHomeBloc>().state;

      if (state is UserHomeLoaded) {
        _loadOffersFromState(state);
        return;
      }
    } catch (_) {}

    if (!mounted) return;

    setState(() {
      _restaurantOffers = [];
      _isLoading = false;
    });
  }

  bool _isRestaurantOffer(FoodOffer offer) {
    if (offer.source == 'restaurant') return true;

    final type = offer.businessType.trim().toLowerCase();
    if (type == 'restaurant') return true;

    if (type.isEmpty) return true;

    return false;
  }

  void _onSearchChanged() {
    final next = _searchController.text.trim();
    if (next == _query || !mounted) return;
    setState(() => _query = next);
  }

  List<FoodOffer> get _filteredOffers {
    final query = _query.toLowerCase();

    return _restaurantOffers.where((offer) {
      if (!offer.isAvailable || offer.isExpired) return false;

      if (_category != 'الكل') {
        final matches = _categoryMatches(offer.foodType, _category);
        if (!matches) return false;
      }

      if (query.isEmpty) return true;

      final haystack = [
        offer.title,
        offer.businessName,
        offer.foodType,
        offer.description,
      ].join(' ').toLowerCase();

      return haystack.contains(query);
    }).toList(growable: false);
  }

  bool _categoryMatches(String foodType, String category) {
    final ft = foodType.trim().toLowerCase();
    final cat = category.trim().toLowerCase();

    if (ft.isEmpty) return false;

    switch (cat) {
      case 'وجبات':
        return ft.contains('meal') ||
            ft.contains('وجبة') ||
            ft.contains('وجبات') ||
            ft.contains('food') ||
            ft.contains('طعام');

      case 'مخبوزات':
        return ft.contains('bread') ||
            ft.contains('bakery') ||
            ft.contains('خبز') ||
            ft.contains('مخبوز');

      case 'حلويات':
        return ft.contains('dessert') ||
            ft.contains('sweet') ||
            ft.contains('حلو') ||
            ft.contains('حلويات');

      case 'فواكه':
        return ft.contains('fruit') || ft.contains('فاكهة');

      case 'مشروبات':
        return ft.contains('drink') ||
            ft.contains('beverage') ||
            ft.contains('مشروب');

      default:
        return ft.contains(cat);
    }
  }

  // ============================================================
  // Build
  // ============================================================
  //
  // ✅ ملفوفة بنفس Theme الغامق اللي في باقي التطبيق (بدل الاعتماد
  // على الـ Theme المحيطة)، عشان الصفحة تبقى متطابقة بصريًا مع
  // الرئيسية وصفحة العروض حتى لو اتفتحت من مكان تاني.
  // ============================================================

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
        child: Scaffold(
          backgroundColor: _bg,
          appBar: _buildAppBarWithTabs(context),
          body: TabBarView(
            controller: _tabController,
            children: [
              // ✅ Tab 1: عروض المطاعم
              _buildOffersTabContent(),

              // ✅ Tab 2: طلباتي على المطاعم
              const MyRestaurantRequestsTab(),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // AppBar مع Tabs
  // ============================================================

  PreferredSizeWidget _buildAppBarWithTabs(BuildContext context) {
    final userId = SupabaseService().client.auth.currentUser?.id;

    return AppBar(
      backgroundColor: _bg,
      surfaceTintColor: _bg,
      elevation: 0,
      centerTitle: true,
      leading: IconButton(
        onPressed: () => Navigator.of(context).maybePop(),
        icon: const Icon(Icons.arrow_back_rounded, color: _textPrimary),
      ),
      title: const Text(
        'المطاعم',
        style: TextStyle(
          color: _textPrimary,
          fontSize: 19,
          fontWeight: FontWeight.w900,
        ),
      ),
      actions: [
        BlocBuilder<NotificationBloc, NotificationState>(
          builder: (context, state) => Stack(
            children: [
              IconButton(
                tooltip: 'الإشعارات',
                onPressed: userId == null
                    ? null
                    : () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => NotificationsPage(userId: userId),
                          ),
                        ),
                icon: const Icon(
                  Icons.notifications_none_rounded,
                  color: _textSecondary,
                ),
              ),
              if (state.unreadCount > 0)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: const BoxDecoration(
                      color: _primaryRed,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 4),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(14),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: _primaryRed,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: _primaryRed.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: Colors.white,
              unselectedLabelColor: _textSecondary,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 12.5,
              ),
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12.5,
              ),
              tabs: const [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.restaurant_rounded, size: 16),
                      SizedBox(width: 6),
                      Text('عروض المطاعم'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.receipt_long_rounded, size: 16),
                      SizedBox(width: 6),
                      Text('طلباتي'),
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

  // ============================================================
  // TAB 1 CONTENT — عروض المطاعم
  // ============================================================

  Widget _buildOffersTabContent() {
    final offers = _filteredOffers;
    final hasOffers = _restaurantOffers.isNotEmpty;

    return RefreshIndicator(
      color: _primaryRed,
      backgroundColor: _card,
      displacement: 40,
      strokeWidth: 2.5,
      onRefresh: () async {
        await _loadOffers(reload: true);
      },
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            sliver: SliverToBoxAdapter(
              child: Column(
                children: [
                  _buildSearchBar(),
                  const SizedBox(height: 14),
                  _buildCategoryChips(),
                  const SizedBox(height: 14),
                  _buildStatisticsCards(),
                ],
              ),
            ),
          ),
          if (offers.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _buildEmptyState(),
            )
          else ...[
            if (hasOffers)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                sliver: SliverToBoxAdapter(
                  child: _EntranceAnimation(
                    index: 0,
                    child: _buildFeaturedOffer(offers.first),
                  ),
                ),
              ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final offer = offers[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _EntranceAnimation(
                        index: index,
                        child: _offerCard(offer),
                      ),
                    );
                  },
                  childCount: offers.length,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ============================================================
  // Search Bar
  // ============================================================

  Widget _buildSearchBar() {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: TextField(
        controller: _searchController,
        textInputAction: TextInputAction.search,
        style: const TextStyle(color: _textPrimary, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'ابحث عن وجبة أو مطعم...',
          hintStyle: const TextStyle(color: _textSecondary, fontSize: 13.5),
          prefixIcon:
              const Icon(Icons.search_rounded, color: _primaryRed, size: 22),
          suffixIcon: _query.isEmpty
              ? null
              : IconButton(
                  onPressed: _searchController.clear,
                  icon: const Icon(Icons.close_rounded,
                      color: _textSecondary, size: 20),
                ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  // ============================================================
  // Category Chips
  // ============================================================

  Widget _buildCategoryChips() {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final category = _categories[index];
          final selected = category == _category;
          return ChoiceChip(
            label: Text(category),
            selected: selected,
            onSelected: (_) => setState(() => _category = category),
            selectedColor: _primaryRed,
            backgroundColor: _card,
            showCheckmark: false,
            labelStyle: TextStyle(
              color: selected ? Colors.white : _textSecondary,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              fontSize: 12,
            ),
            side: BorderSide(
              color:
                  selected ? _primaryRed : Colors.white.withValues(alpha: 0.08),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(100),
            ),
          );
        },
      ),
    );
  }

  // ============================================================
  // Statistics Cards
  // ============================================================

  Widget _buildStatisticsCards() {
    final available =
        _restaurantOffers.where((o) => o.isAvailable && !o.isExpired);
    final urgent = available.where((o) => o.isUrgent).length;
    final total = available.length;

    return Row(
      children: [
        Expanded(
          child: _statCard(
            icon: Icons.restaurant_rounded,
            label: 'عروض المطاعم',
            value: '$total',
            color: _primaryRed,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _statCard(
            icon: Icons.local_fire_department_rounded,
            label: 'عروض عاجلة',
            value: '$urgent',
            color: _orange,
          ),
        ),
      ],
    );
  }

  Widget _statCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 19),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    color: color,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // Featured Offer
  // ============================================================

  Widget _buildFeaturedOffer(FoodOffer offer) {
    final imageUrl = offer.displayImage;

    return InkWell(
      onTap: () => _navigateToDetails(offer),
      borderRadius: BorderRadius.circular(22),
      child: Ink(
        height: 185,
        decoration: BoxDecoration(
          color: _cardSoft,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
          image: imageUrl == null
              ? null
              : DecorationImage(
                  image: NetworkImage(imageUrl),
                  fit: BoxFit.cover,
                  colorFilter: const ColorFilter.mode(
                    Color(0xB3000000),
                    BlendMode.darken,
                  ),
                ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: offer.isUrgent ? _orange : _primaryRed,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  offer.isUrgent ? 'عرض عاجل' : 'متاح الآن',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                offer.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${offer.businessName}  •  ${offer.timeRemaining}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // Offer Card
  // ============================================================

  Widget _offerCard(FoodOffer offer) {
    final sale = offer.salePrice;
    final orig = offer.originalPrice;
    final hasDiscount = sale != null && orig != null && orig > sale;
    final discount = hasDiscount ? ((1 - sale / orig) * 100).round() : 0;

    // ⚠️ TODO: حاليًا مفيش مصدر بيانات في الصفحة دي يوضح إن المستخدم
    // "قدّم على العرض ده وبعدين لغى طلبه" — ده تفصيل مرتبط بطلبات
    // المستخدم (my requests / bookings) مش بحالة العرض نفسه. سيبت
    // الـ hook هنا جاهز (_isCancelledByMe) عشان يوصل بسهولة لما تبعتلي
    // كود صفحة الطلبات أو تفاصيل العرض اللي فيها منطق الإلغاء.
    final cancelledByMe = _isCancelledByMe(offer);

    return Material(
      color: _card,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: cancelledByMe ? null : () => _navigateToDetails(offer),
        child: Opacity(
          opacity: cancelledByMe ? 0.55 : 1,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: cancelledByMe
                    ? _primaryRed.withValues(alpha: 0.25)
                    : Colors.white.withValues(alpha: 0.05),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ✅ صورة كبيرة فوق الكارت + شارات فوقها
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                      child: SizedBox(
                        height: 150,
                        width: double.infinity,
                        child: ColorFiltered(
                          colorFilter: cancelledByMe
                              ? const ColorFilter.mode(
                                  Colors.black45, BlendMode.saturation)
                              : const ColorFilter.mode(
                                  Colors.transparent, BlendMode.multiply),
                          child: _offerImageSlider(offer),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        height: 56,
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.zero,
                          ),
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.45),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (!cancelledByMe)
                      Positioned(
                        top: 10,
                        right: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: offer.isUrgent ? _orange : _primaryRed,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: (offer.isUrgent ? _orange : _primaryRed)
                                    .withValues(alpha: 0.4),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            offer.isUrgent ? 'عاجل 🔥' : 'متاح الآن',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    if (cancelledByMe)
                      Positioned(
                        top: 10,
                        right: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: _primaryRed.withValues(alpha: 0.6)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.block_rounded,
                                  color: _primaryRed, size: 12),
                              SizedBox(width: 4),
                              Text(
                                'ملغي',
                                style: TextStyle(
                                  color: _primaryRed,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    Positioned(
                      bottom: 10,
                      right: 12,
                      child: Row(
                        children: [
                          Icon(
                            Icons.schedule_rounded,
                            size: 12,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            offer.timeRemaining,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.95),
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // ✅ محتوى الكارت
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        offer.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _textPrimary,
                          fontSize: 15.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.storefront_rounded,
                              size: 12, color: _textSecondary),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              offer.businessName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _textSecondary,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          if (sale != null && sale > 0)
                            Text(
                              '${sale.toStringAsFixed(0)} ج.م',
                              style: const TextStyle(
                                color: _primaryRed,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            )
                          else
                            const Text(
                              '🎁 مجاني',
                              style: TextStyle(
                                color: _primaryRed,
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          if (hasDiscount) ...[
                            const SizedBox(width: 6),
                            Text(
                              '${orig.toStringAsFixed(0)} ج.م',
                              style: TextStyle(
                                color: _textSecondary.withValues(alpha: 0.8),
                                fontSize: 11.5,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: _orange.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(7),
                              ),
                              child: Text(
                                'وفر $discount%',
                                style: const TextStyle(
                                  color: _orange,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                          const Spacer(),
                          if (cancelledByMe)
                            const Text(
                              'مش متاح للتقديم',
                              style: TextStyle(
                                color: _primaryRed,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            )
                          else
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Text(
                                  'التفاصيل',
                                  style: TextStyle(
                                    color: _primaryRed,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Icon(Icons.chevron_left_rounded,
                                    color: _primaryRed, size: 18),
                              ],
                            ),
                        ],
                      ),
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

  // ⚠️ Placeholder: يرجع false دايمًا لحد ما توصلني بيانات طلبات
  // المستخدم (booking/request) عشان أربطها صح. راجع الرد اللي بعد
  // الكود لتفاصيل أكتر.
  bool _isCancelledByMe(FoodOffer offer) {
    return false;
  }

  // ============================================================
  // Offer Image
  // ============================================================

  Widget _offerImageSlider(FoodOffer offer) {
    final imageUrls = <String>{
      ...?offer.images,
      if (offer.displayImage != null && offer.displayImage!.isNotEmpty)
        offer.displayImage!,
    }.toList(growable: false);

    if (imageUrls.isEmpty) {
      return Container(
        color: _primaryRed.withValues(alpha: 0.1),
        child: const Icon(Icons.restaurant_rounded, color: _primaryRed),
      );
    }

    return CachedNetworkImage(
      imageUrl: imageUrls.first,
      fit: BoxFit.cover,
      placeholder: (context, url) => Container(
        color: _primaryRed.withValues(alpha: 0.1),
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: _primaryRed,
            ),
          ),
        ),
      ),
      errorWidget: (context, url, error) => Container(
        color: _primaryRed.withValues(alpha: 0.1),
        child: const Icon(Icons.restaurant_rounded, color: _primaryRed),
      ),
    );
  }

  // ============================================================
  // Empty State
  // ============================================================

  Widget _buildEmptyState() {
    final filtered = _query.isNotEmpty || _category != 'الكل';
    final hasOffers = _restaurantOffers.isNotEmpty;

    if (_isLoading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: _primaryRed),
              const SizedBox(height: 18),
              const Text(
                'جاري تحميل عروض المطاعم...',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (!hasOffers) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 84,
                height: 84,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _primaryRed.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.restaurant_rounded,
                  color: _primaryRed,
                  size: 38,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'مفيش عروض مطاعم حاليًا',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'اسحب للأسفل عشان تحدّث',
                textAlign: TextAlign.center,
                style: TextStyle(color: _textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: () async {
                  await _loadOffers(reload: true);
                },
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('إعادة المحاولة'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _primaryRed,
                  side: const BorderSide(color: _primaryRed),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (filtered) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 84,
                height: 84,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _primaryRed.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.search_off_rounded,
                  color: _primaryRed,
                  size: 38,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'مفيش نتائج مطابقة',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'جرّب تغيير البحث أو اختيار تصنيف آخر.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => setState(() {
                  _query = '';
                  _category = 'الكل';
                  _searchController.clear();
                }),
                style: FilledButton.styleFrom(
                  backgroundColor: _primaryRed,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('مسح الفلاتر'),
              ),
            ],
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  // ============================================================
  // Navigate to Details
  // ============================================================

  void _navigateToDetails(FoodOffer offer) {
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
            'images': offer.images ??
                (offer.displayImage == null
                    ? <String>[]
                    : <String>[offer.displayImage!]),
          },
        ),
      ),
    );
  }
}

// ============================================================
// ✅ ENTRANCE ANIMATION — فيد + سحب لأعلى لطيف لكل كارت
// أول ما يتبني وهو بيظهر في الشاشة أثناء السكرول، مع تأخير بسيط
// متدرج حسب ترتيبه (stagger) عشان الكروت تظهر واحد ورا التاني
// بدل ما تطلع كلها مرة واحدة.
// ============================================================
class _EntranceAnimation extends StatefulWidget {
  final int index;
  final Widget child;

  const _EntranceAnimation({
    required this.index,
    required this.child,
  });

  @override
  State<_EntranceAnimation> createState() => _EntranceAnimationState();
}

class _EntranceAnimationState extends State<_EntranceAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    // ✅ تأخير بسيط متدرج حسب رقم الكارت، بحد أقصى عشان القايمة
    // الطويلة متاخدش وقت كبير قبل ما تبدأ تظهر
    final delay = Duration(milliseconds: (widget.index * 45).clamp(0, 300));
    Future.delayed(delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: widget.child,
      ),
    );
  }
}
