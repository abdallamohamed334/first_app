// lib/features/home/presentation/pages/home_page.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:loqma/features/auth/presentation/pages/login_page.dart';
import 'package:loqma/features/donation/presentation/pages/offer_details_page.dart';
import 'package:loqma/features/home/presentation/pages/Open%20volunteer%20donations%20home%20section.dart';
import 'package:loqma/features/home/presentation/pages/all_offers_page.dart';
import 'package:loqma/features/home/presentation/pages/all_open_volunteer_donations_page.dart';
import 'package:loqma/features/home/presentation/pages/symbolic_purchase_page.dart';
import 'package:loqma/features/institutions/domain/entities/institution_offer.dart';
import 'package:loqma/features/institutions/presentation/pages/institution_offer_details_page.dart';
import 'package:loqma/features/offers/domain/entities/food_offer.dart';
import 'package:loqma/features/profile/presentation/pages/profile_page.dart';
import 'package:loqma/features/community/presentation/pages/add_community_offer_page.dart';
import 'package:loqma/features/community/presentation/pages/community_tracking_page.dart';
import 'package:loqma/features/charity/presentation/pages/add_charity_donation_page.dart';
import '../widgets/community_home_offers_section.dart';
import 'package:loqma/features/booking/presentation/pages/my_bookings_page.dart';
import 'package:loqma/core/services/supabase_service.dart';
import 'package:loqma/features/notification/presentation/pages/notifications_page.dart';
import 'package:loqma/features/notification/presentation/bloc/notification_bloc.dart';
import 'package:loqma/features/notification/presentation/bloc/notification_event.dart';

import '../bloc/home_bloc.dart';
import '../bloc/home_event.dart';
import '../bloc/home_state.dart';

// ============================================================
// ✅ ثوابت على مستوى الفايل
// ============================================================
const _green = Color(0xFF0B7650);
const _darkGreen = Color(0xFF123F31);
const _background = Color(0xFFF6FAF8);

enum _HomeMode { shop, rescue }

enum _HomeCategory { restaurants, grocery, symbolicBuy, rescueDonations }

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  StreamSubscription? _offersSubscription;
  StreamSubscription? _institutionOffersSubscription;
  StreamSubscription? _requestsSubscription;
  StreamSubscription? _notificationSubscription;
  List<Map<String, dynamic>> _userRequests = [];
  HomeLoaded? _lastLoadedState;
  int _unreadNotifications = 0;
  int _currentPage = 0;
  _HomeMode _mode = _HomeMode.shop;
  String _query = '';
  final _searchCtrl = TextEditingController();

  // ============================================================
  // Lifecycle
  // ============================================================
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<HomeBloc>().add(const HomeInitialized());
      _loadUserRequests();
      _loadNotifications();
      _loadUnreadNotifications();
      _subscribeToChanges();
    });
  }

  Future<void> _loadUserRequests() async {
    final client = SupabaseService().client;
    final authUser = client.auth.currentUser;
    if (authUser == null) return;
    try {
      try {
        await client.rpc('expire_overdue_food_bookings');
      } catch (_) {}

      final rows = await client
          .from('offer_requests')
          .select('''
        id, status, updated_at,
        food_offers:offer_id (title, pickup_before, businesses:business_id (name))
      ''')
          .eq('user_id', authUser.id)
          .inFilter('status', ['pending', 'accepted', 'ready_for_pickup'])
          .order('updated_at', ascending: false)
          .limit(5);

      if (!mounted) return;
      setState(() => _userRequests = List<Map<String, dynamic>>.from(rows));
    } catch (e) {
      debugPrint('User requests load error: $e');
    }
  }

  void _loadNotifications() {
    final authUser = SupabaseService().client.auth.currentUser;
    if (authUser == null || !mounted) return;
    context.read<NotificationBloc>().add(LoadNotifications(authUser.id));
  }

  Future<void> _loadUnreadNotifications() async {
    final client = SupabaseService().client;
    final authUser = client.auth.currentUser;
    if (authUser == null) return;
    try {
      final rows = await client
          .from('notifications')
          .select('id')
          .eq('user_id', authUser.id)
          .eq('is_read', false);
      if (!mounted) return;
      setState(() => _unreadNotifications = rows.length);
    } catch (e) {
      debugPrint('Unread notifications error: $e');
    }
  }

  void _subscribeToChanges() {
    final client = SupabaseService().client;
    _offersSubscription?.cancel();
    _institutionOffersSubscription?.cancel();
    _requestsSubscription?.cancel();
    _notificationSubscription?.cancel();

    void refresh() {
      if (mounted) context.read<HomeBloc>().add(const RefreshHome());
    }

    _offersSubscription = client
        .from('food_offers')
        .stream(primaryKey: ['id']).listen((_) => refresh());
    _institutionOffersSubscription = client
        .from('institution_offers_core')
        .stream(primaryKey: ['id']).listen((_) => refresh());

    final authUser = client.auth.currentUser;
    if (authUser != null) {
      _notificationSubscription = client
          .from('notifications')
          .stream(primaryKey: ['id'])
          .eq('user_id', authUser.id)
          .listen((_) {
            if (!mounted) return;
            _loadUnreadNotifications();
            _loadNotifications();
          });
      _requestsSubscription = client
          .from('offer_requests')
          .stream(primaryKey: ['id'])
          .eq('user_id', authUser.id)
          .listen((_) {
            if (!mounted) return;
            _loadUserRequests();
            refresh();
          });
    }
  }

  @override
  void dispose() {
    _offersSubscription?.cancel();
    _institutionOffersSubscription?.cancel();
    _requestsSubscription?.cancel();
    _notificationSubscription?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ============================================================
  // Helpers
  // ============================================================
  static String _norm(String s) => s
      .toLowerCase()
      .trim()
      .replaceAll(RegExp('[أإآٱ]'), 'ا')
      .replaceAll('ى', 'ي')
      .replaceAll('ة', 'ه');

  static num? _numField(Object? obj, String field) {
    if (obj == null) return null;
    try {
      return (obj as dynamic)[field] as num?;
    } catch (_) {
      return null;
    }
  }

  static double? _distanceKm(FoodOffer offer, HomeLoaded state) {
    final lat1 = _numField(state.user, 'latitude')?.toDouble();
    final lng1 = _numField(state.user, 'longitude')?.toDouble();
    if (lat1 == null || lng1 == null) return null;
    const r = 6371.0;
    final dLat = (offer.latitude - lat1) * 3.14159265 / 180;
    final dLng = (offer.longitude - lng1) * 3.14159265 / 180;
    final a = (0.5 - 0.5 * (dLat).abs() / 3.14159265 * 2).abs();
    return null;
  }

  List<FoodOffer> _sortedByUrgency(List<FoodOffer> offers) {
    final list = [...offers];
    list.sort((a, b) => a.pickupBefore.compareTo(b.pickupBefore));
    return list;
  }

  List<FoodOffer> _visibleOffers(HomeLoaded state) {
    final live = state.offers.where((o) =>
        o.isAvailable &&
        !o.isExpired &&
        o.status.value != 'completed' &&
        o.status.value != 'cancelled');
    final q = _norm(_query);
    final filtered = q.isEmpty
        ? live
        : live.where((o) =>
            _norm('${o.title} ${o.businessName} ${o.foodType}').contains(q));
    return _sortedByUrgency(filtered.toList());
  }

  // ✅ جلب عروض المؤسسات من الـ state
  List<InstitutionOffer> _getInstitutionOffers(HomeLoaded state) {
    final offers = state.institutionOffers ?? [];
    return offers.where((o) => o.status == 'active').toList();
  }

  List<FoodOffer> _topSavings(List<FoodOffer> offers) {
    final withDiscount = offers.where((o) {
      final sale = o.salePrice;
      final orig = o.originalPrice;
      return sale != null && orig != null && orig > sale;
    }).toList();
    withDiscount.sort((a, b) {
      final dA = a.originalPrice! - a.salePrice!;
      final dB = b.originalPrice! - b.salePrice!;
      return dB.compareTo(dA);
    });
    return withDiscount.take(5).toList();
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    return hour < 12 ? 'صباح الخير' : 'مساء الخير';
  }

  // ============================================================
  // Build
  // ============================================================
  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: BlocConsumer<HomeBloc, HomeState>(
        listener: (context, state) {
          if (state is HomeUnauthenticated && mounted) {
            Navigator.pushReplacement(
                context, MaterialPageRoute(builder: (_) => const LoginPage()));
          }
        },
        builder: (context, state) {
          if (state is HomeLoaded) _lastLoadedState = state;
          final loaded = _lastLoadedState;
          if (loaded == null) {
            return const Scaffold(
              backgroundColor: _background,
              body: Center(child: CircularProgressIndicator(color: _green)),
            );
          }
          return _buildScaffold(context, loaded);
        },
      ),
    );
  }

  Widget _buildScaffold(BuildContext context, HomeLoaded state) {
    return Scaffold(
      backgroundColor: _background,
      body: IndexedStack(
        index: _currentPage,
        children: [
          _buildHomeTab(context, state),
          AllOffersPage(offers: state.offers),
          const CommunityTrackingPage(),
          const ProfilePage(),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ============================================================
  // ✅ HOME TAB — مع عروض المؤسسات
  // ============================================================
  Widget _buildHomeTab(BuildContext context, HomeLoaded state) {
    final offers = _visibleOffers(state);
    final institutionOffers = _getInstitutionOffers(state);
    final savings = _topSavings(offers);
    final shopMode = _mode == _HomeMode.shop;

    return RefreshIndicator(
      color: _green,
      onRefresh: () async {
        context.read<HomeBloc>().add(const RefreshHome());
        await _loadUserRequests();
        _loadNotifications();
      },
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          SliverToBoxAdapter(child: _buildHeader(state)),
          SliverToBoxAdapter(child: _buildSearch()),
          SliverToBoxAdapter(child: _buildCategories()),
          SliverToBoxAdapter(child: _buildActionSwitch()),
          SliverToBoxAdapter(child: _buildBookingBand()),
          const SliverToBoxAdapter(child: SizedBox(height: 18)),

          // ✅ عروض المؤسسات - تظهر في الوضعين
          if (institutionOffers.isNotEmpty)
            SliverToBoxAdapter(
                child: _buildInstitutionOffersRow(
              title: '🏪 عروض المؤسسات',
              subtitle: '${institutionOffers.length} عرض بأسعار رمزية',
              offers: institutionOffers.take(8).toList(),
            )),

          // ===== وضع الشراء =====
          if (shopMode && offers.isNotEmpty) ...[
            SliverToBoxAdapter(
                child: _buildOffersRow(
              title: '🔥 عروض قريبة منك',
              subtitle: '${offers.length} عرض متاح دلوقتي',
              offers: offers.take(8).toList(),
              state: state,
            )),
            if (savings.isNotEmpty)
              SliverToBoxAdapter(
                  child: Padding(
                padding: const EdgeInsets.only(top: 20),
                child: _buildOffersRow(
                  title: '💰 أكبر توفير',
                  subtitle:
                      'وفر لحد ${(savings.first.originalPrice! - savings.first.salePrice!).toStringAsFixed(0)} جنيه',
                  offers: savings,
                  state: state,
                ),
              )),
          ],

          // ===== وضع الإنقاذ =====
          if (!shopMode) ...[
            const SliverToBoxAdapter(
                child: OpenVolunteerDonationsHomeSection()),
            const SliverToBoxAdapter(child: SizedBox(height: 20)),
            const SliverToBoxAdapter(child: CommunityHomeOffersSection()),
          ],

          // ===== فرص الإنقاذ تظهر في الوضعين =====
          if (shopMode) ...[
            const SliverToBoxAdapter(child: SizedBox(height: 20)),
            const SliverToBoxAdapter(
                child: OpenVolunteerDonationsHomeSection()),
          ],

          // ===== أماكن قريبة =====
          if (offers.isNotEmpty) ...[
            const SliverToBoxAdapter(child: SizedBox(height: 20)),
            SliverToBoxAdapter(child: _buildBusinessesRow(offers)),
          ],

          if (offers.isEmpty && institutionOffers.isEmpty && shopMode)
            const SliverToBoxAdapter(child: _EmptyHome()),

          const SliverToBoxAdapter(child: SizedBox(height: 110)),
        ],
      ),
    );
  }

  // ============================================================
  // ✅ عروض المؤسسات
  // ============================================================
  Widget _buildInstitutionOffersRow({
    required String title,
    required String subtitle,
    required List<InstitutionOffer> offers,
  }) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(children: [
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(title,
                    style: const TextStyle(
                        color: _darkGreen,
                        fontSize: 18,
                        fontWeight: FontWeight.w900)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: const TextStyle(
                        color: Color(0xFF71837C), fontSize: 11)),
              ])),
          TextButton(
            onPressed: () => _showAllInstitutionOffers(context, offers),
            child: const Text('عرض الكل',
                style: TextStyle(
                    color: _green, fontWeight: FontWeight.w800, fontSize: 12)),
          ),
        ]),
      ),
      const SizedBox(height: 11),
      SizedBox(
        height: 260,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          scrollDirection: Axis.horizontal,
          itemCount: offers.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (_, i) => _InstitutionOfferCard(
            offer: offers[i],
            onTap: () => _showInstitutionOfferDetails(context, offers[i]),
          ),
        ),
      ),
    ]);
  }

  void _showAllInstitutionOffers(
      BuildContext context, List<InstitutionOffer> offers) {
    // TODO: فتح صفحة كل عروض المؤسسات
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('📋 عرض كل عروض المؤسسات'),
          behavior: SnackBarBehavior.floating),
    );
  }

  void _showInstitutionOfferDetails(
      BuildContext context, InstitutionOffer offer) {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => InstitutionOfferDetailsPage(offer: offer)),
    );
  }

  // ============================================================
  // Header
  // ============================================================
  Widget _buildHeader(HomeLoaded state) {
    final name = state.user.name.trim();
    final city = (() {
          try {
            return (state.user as dynamic).city as String?;
          } catch (_) {
            return null;
          }
        })() ??
        'طنطا، الغربية';

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
        child: Row(
          children: [
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${_greeting()} يا ${name.isEmpty ? 'صديقنا' : name}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: _darkGreen,
                            fontSize: 17,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.location_on_rounded,
                          size: 14, color: _green),
                      const SizedBox(width: 3),
                      Text(city,
                          style: const TextStyle(
                              color: Color(0xFF71837C),
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                      const Icon(Icons.keyboard_arrow_down_rounded,
                          size: 15, color: Color(0xFF71837C)),
                    ]),
                  ]),
            ),
            GestureDetector(
              onTap: () {
                final user = SupabaseService().client.auth.currentUser;
                if (user == null) return;
                Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => NotificationsPage(userId: user.id)))
                    .then((_) {
                  _loadNotifications();
                  _loadUnreadNotifications();
                });
              },
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFE2EEE8)),
                ),
                child: Stack(alignment: Alignment.center, children: [
                  const Icon(Icons.notifications_none_rounded,
                      color: _green, size: 20),
                  if (_unreadNotifications > 0)
                    Positioned(
                        top: 9,
                        left: 10,
                        child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                                color: Color(0xFFE24A4A),
                                shape: BoxShape.circle))),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // Search
  // ============================================================
  Widget _buildSearch() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: TextField(
        controller: _searchCtrl,
        onChanged: (v) => setState(() => _query = v),
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'بتدور على إيه؟',
          hintStyle: const TextStyle(color: Color(0xFF91A39A), fontSize: 13),
          prefixIcon: const Icon(Icons.search_rounded, color: _green, size: 20),
          suffixIcon: _query.isEmpty
              ? null
              : GestureDetector(
                  onTap: () {
                    _searchCtrl.clear();
                    setState(() => _query = '');
                  },
                  child: const Icon(Icons.close_rounded,
                      size: 18, color: Color(0xFF71837C)),
                ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 13),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFDCEBE3))),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFDCEBE3))),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: _green, width: 1.3)),
        ),
      ),
    );
  }

  // ============================================================
  // الخانات الأربع
  // ============================================================
  Widget _buildCategories() {
    const items = [
      (_HomeCategory.restaurants, Icons.restaurant_rounded, 'المطاعم'),
      (
        _HomeCategory.grocery,
        Icons.shopping_basket_rounded,
        'البقاله والمحلات'
      ),
      (_HomeCategory.symbolicBuy, Icons.sell_rounded, 'شراء رمزي'),
      (
        _HomeCategory.rescueDonations,
        Icons.volunteer_activism_rounded,
        'تبرعات محتاجاك'
      ),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          for (final (cat, icon, label) in items) ...[
            Expanded(
              child: GestureDetector(
                onTap: () => _onCategory(cat),
                child: Column(children: [
                  Container(
                    width: 62,
                    height: 62,
                    decoration: BoxDecoration(
                        color: const Color(0xFFDDF3E8),
                        borderRadius: BorderRadius.circular(18)),
                    child: Icon(icon, color: _green, size: 27),
                  ),
                  const SizedBox(height: 7),
                  Text(label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: _darkGreen,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          height: 1.3)),
                ]),
              ),
            ),
            if (cat != _HomeCategory.rescueDonations) const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  // ============================================================
  // Action Switch
  // ============================================================
  Widget _buildActionSwitch() {
    Widget card(_HomeMode mode, IconData icon, String title, String sub) {
      final active = _mode == mode;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _mode = mode),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 15),
            decoration: BoxDecoration(
              color: active ? _green : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                  color: active ? _green : const Color(0xFFDCEBE3), width: 1.3),
            ),
            child: Column(children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                    color: active
                        ? Colors.white.withAlpha(40)
                        : const Color(0xFFDDF3E8),
                    shape: BoxShape.circle),
                child:
                    Icon(icon, color: active ? Colors.white : _green, size: 22),
              ),
              const SizedBox(height: 9),
              Text(title,
                  style: TextStyle(
                      color: active ? Colors.white : _darkGreen,
                      fontSize: 13,
                      fontWeight: FontWeight.w900)),
              const SizedBox(height: 3),
              Text(sub,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: active
                          ? Colors.white.withAlpha(220)
                          : const Color(0xFF71837C),
                      fontSize: 10.5,
                      height: 1.35)),
            ]),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('أنت عايز تعمل إيه؟',
            style: TextStyle(
                color: _darkGreen, fontSize: 15, fontWeight: FontWeight.w900)),
        const SizedBox(height: 10),
        Row(children: [
          card(_HomeMode.shop, Icons.shopping_bag_outlined, 'أشتري فائض',
              'وفر فلوس وأنقذ أكل'),
          const SizedBox(width: 10),
          card(_HomeMode.rescue, Icons.volunteer_activism_rounded,
              'أساعد في إنقاذ وجبة', 'تبرع أو ساعد في التوصيل'),
        ]),
        const SizedBox(height: 8),
        Text(
          _mode == _HomeMode.shop
              ? 'هنركّز لك على أقوى العروض والتوفير القريب منك'
              : 'هنركّز لك على التبرعات وفرص التوصيل القريبة منك',
          textAlign: TextAlign.center,
          style: const TextStyle(
              color: Color(0xFF71837C),
              fontSize: 11.5,
              fontWeight: FontWeight.w600),
        ),
      ]),
    );
  }

  // ============================================================
  // شريط الحالة
  // ============================================================
  Widget _buildBookingBand() {
    final active = _userRequests.where((r) {
      final offer = r['food_offers'] is Map
          ? Map<String, dynamic>.from(r['food_offers'])
          : {};
      final deadline =
          DateTime.tryParse(offer['pickup_before']?.toString() ?? '');
      return deadline == null || deadline.isAfter(DateTime.now());
    }).toList();

    if (active.isEmpty) return const SizedBox.shrink();

    active.sort((a, b) {
      final da = DateTime.tryParse(
              a['food_offers']['pickup_before']?.toString() ?? '') ??
          DateTime(2100);
      final db = DateTime.tryParse(
              b['food_offers']['pickup_before']?.toString() ?? '') ??
          DateTime(2100);
      return da.compareTo(db);
    });
    final r = active.first;
    final offer = Map<String, dynamic>.from(r['food_offers']);
    final biz = offer['businesses'] is Map
        ? offer['businesses']['name']?.toString() ?? ''
        : '';
    final status = r['status']?.toString() ?? 'pending';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: GestureDetector(
        onTap: () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => const MyBookingsPage())),
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: const Color(0xFFE7F6EE),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFBFE5D2)),
          ),
          child: Row(children: [
            const Icon(Icons.check_circle_rounded, color: _green, size: 22),
            const SizedBox(width: 9),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(
                      status == 'ready_for_pickup'
                          ? 'طلبك جاهز للاستلام'
                          : status == 'accepted'
                              ? 'المطعم قبل طلبك'
                              : 'طلبك قيد التأكيد',
                      style: const TextStyle(
                          color: _darkGreen,
                          fontSize: 13,
                          fontWeight: FontWeight.w800)),
                  Text('${offer['title'] ?? ''} · $biz',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Color(0xFF396653), fontSize: 11)),
                ])),
            if (active.length > 1)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFBFE5D2))),
                child: Text('+${active.length - 1} في النشاط',
                    style: const TextStyle(
                        color: _green,
                        fontSize: 10,
                        fontWeight: FontWeight.w800)),
              ),
            const Icon(Icons.arrow_back_ios_new_rounded,
                size: 13, color: _green),
          ]),
        ),
      ),
    );
  }

  // ============================================================
  // صف عروض أفقي
  // ============================================================
  Widget _buildOffersRow({
    required String title,
    required String subtitle,
    required List<FoodOffer> offers,
    required HomeLoaded state,
  }) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(children: [
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(title,
                    style: const TextStyle(
                        color: _darkGreen,
                        fontSize: 18,
                        fontWeight: FontWeight.w900)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: const TextStyle(
                        color: Color(0xFF71837C), fontSize: 11)),
              ])),
          TextButton(
            onPressed: () => _showAllOffers(context, offers),
            child: const Text('عرض الكل',
                style: TextStyle(
                    color: _green, fontWeight: FontWeight.w800, fontSize: 12)),
          ),
        ]),
      ),
      const SizedBox(height: 11),
      SizedBox(
        height: 268,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          scrollDirection: Axis.horizontal,
          itemCount: offers.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (_, i) => _CompactOfferCard(
            offer: offers[i],
            distance: _distanceKm(offers[i], state),
            onTap: () => _showOfferDetails(context, offers[i]),
          ),
        ),
      ),
    ]);
  }

  // ============================================================
  // أماكن قريبة منك
  // ============================================================
  Widget _buildBusinessesRow(List<FoodOffer> offers) {
    final map = <String, Map<String, dynamic>>{};
    for (final o in offers) {
      final key = o.businessId ?? o.businessName;
      final e = map.putIfAbsent(
          key,
          () => {
                'name': o.businessName,
                'logo': o.businessLogo,
                'count': 0,
              });
      e['count'] = (e['count'] as int) + 1;
    }
    final businesses = map.entries.take(6).toList();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: Text('📍 أماكن قريبة منك',
            style: TextStyle(
                color: _darkGreen, fontSize: 18, fontWeight: FontWeight.w900)),
      ),
      const SizedBox(height: 11),
      SizedBox(
        height: 128,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          scrollDirection: Axis.horizontal,
          itemCount: businesses.length,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (_, i) {
            final b = businesses[i].value;
            final name = b['name'] as String;
            final logo = b['logo'] as String?;
            final count = b['count'] as int;
            return GestureDetector(
              onTap: () => _showAllOffers(
                  context,
                  offers
                      .where((o) =>
                          (o.businessId ?? o.businessName) == businesses[i].key)
                      .toList()),
              child: Container(
                width: 132,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFDCEBE4))),
                child: Column(children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: const Color(0xFFDDF3E8),
                    backgroundImage: logo != null && logo.isNotEmpty
                        ? NetworkImage(logo)
                        : null,
                    child: (logo == null || logo.isEmpty)
                        ? Text(name.isEmpty ? '?' : name[0],
                            style: const TextStyle(
                                color: _green,
                                fontWeight: FontWeight.w900,
                                fontSize: 18))
                        : null,
                  ),
                  const SizedBox(height: 7),
                  Text(name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: _darkGreen,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800)),
                  Text('$count عروض متاحة',
                      style: const TextStyle(
                          color: Color(0xFF71837C), fontSize: 9.5)),
                ]),
              ),
            );
          },
        ),
      ),
    ]);
  }

  // ============================================================
  // Bottom Nav
  // ============================================================
  Widget _buildBottomNav() {
    const items = [
      (Icons.home_rounded, 'الرئيسية'),
      (Icons.explore_rounded, 'استكشاف'),
      (Icons.list_alt_rounded, 'النشاط'),
      (Icons.person_rounded, 'حسابي'),
    ];

    return SafeArea(
      top: false,
      child: Container(
        height: 66,
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE7F0EB))),
        ),
        child: Row(children: [
          for (int slot = 0; slot < 5; slot++) ...[
            if (slot == 2)
              GestureDetector(
                onTap: _openAddSheet,
                child: Container(
                  width: 50,
                  height: 50,
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    color: _green,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 4),
                    boxShadow: [
                      BoxShadow(
                          color: _green.withAlpha(60),
                          blurRadius: 12,
                          offset: const Offset(0, 4))
                    ],
                  ),
                  child: const Icon(Icons.add_rounded,
                      color: Colors.white, size: 26),
                ),
              )
            else
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(
                      () => _currentPage = slot >= 2 ? slot - 1 : slot),
                  child: Builder(builder: (_) {
                    final page = slot >= 2 ? slot - 1 : slot;
                    final selected = _currentPage == page;
                    return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(items[page].$1,
                              size: 21,
                              color:
                                  selected ? _green : const Color(0xFF9BAEA5)),
                          const SizedBox(height: 2),
                          Text(items[page].$2,
                              style: TextStyle(
                                  color: selected
                                      ? _green
                                      : const Color(0xFF9BAEA5),
                                  fontSize: 9.5,
                                  fontWeight: selected
                                      ? FontWeight.w800
                                      : FontWeight.w600)),
                        ]);
                  }),
                ),
              ),
          ],
        ]),
      ),
    );
  }

  void _openAddSheet() {
    showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (_) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 10),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('ماذا تريد أن تضيف؟',
                    style: TextStyle(
                        color: _darkGreen,
                        fontSize: 17,
                        fontWeight: FontWeight.w900)),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(
                    child: _addOption(Icons.sell_rounded, 'بيع بسعر رمزي', () {
                      Navigator.pop(context);
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const AddCommunityOfferPage()));
                    }),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _addOption(
                        Icons.volunteer_activism_rounded, 'تبرع لجمعية', () {
                      Navigator.pop(context);
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const AddCharityDonationPage()));
                    }),
                  ),
                ]),
                const SizedBox(height: 8),
              ]),
            ),
          );
        });
  }

  Widget _addOption(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
            color: const Color(0xFFF3F8F5),
            borderRadius: BorderRadius.circular(18)),
        child: Column(children: [
          Container(
            width: 46,
            height: 46,
            decoration: const BoxDecoration(
                color: Color(0xFFDDF3E8), shape: BoxShape.circle),
            child: Icon(icon, color: _green, size: 23),
          ),
          const SizedBox(height: 8),
          Text(label,
              style: const TextStyle(
                  color: _darkGreen,
                  fontSize: 12,
                  fontWeight: FontWeight.w800)),
        ]),
      ),
    );
  }

  // ============================================================
  // Navigation
  // ============================================================
  void _onCategory(_HomeCategory c) {
    final all = _visibleOffers(_lastLoadedState!);
    switch (c) {
      case _HomeCategory.restaurants:
        _showAllOffers(
            context, all.where((o) => o.businessType == 'restaurant').toList());
      case _HomeCategory.grocery:
        _showAllOffers(
            context, all.where((o) => o.businessType != 'restaurant').toList());
      case _HomeCategory.symbolicBuy:
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const SymbolicPurchasePage()));
      case _HomeCategory.rescueDonations:
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => const AllOpenVolunteerDonationsPage()));
    }
  }

  void _showAllOffers(BuildContext context, List<FoodOffer> offers) {
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => AllOffersPage(offers: offers)));
  }

  // ============================================================
  // ✅ التفاصيل — مطعم ولا مؤسسة؟
  // ============================================================
  void _showOfferDetails(BuildContext context, FoodOffer offer) {
    if (offer.source == 'institution' && offer.details != null) {
      Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => InstitutionOfferDetailsPage(
                offer: InstitutionOffer.fromJson(offer.details!)),
          ));
      return;
    }

    Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OfferDetailsPage(offer: {
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
            'charity_id': offer.charityId,
            'created_at': offer.createdAt.toIso8601String(),
            'updated_at': offer.updatedAt.toIso8601String(),
            'businesses': {
              'name': offer.businessName,
              'logo': offer.businessLogo
            },
            'images': offer.images ??
                (offer.displayImage != null
                    ? [offer.displayImage!]
                    : <String>[]),
          }),
        ));
  }
}

// ============================================================
// ✅ كارت عرض المؤسسة
// ============================================================
class _InstitutionOfferCard extends StatelessWidget {
  final InstitutionOffer offer;
  final VoidCallback onTap;

  const _InstitutionOfferCard({
    required this.offer,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final image = offer.images.isNotEmpty ? offer.images.first : null;
    final price = offer.symbolicPrice;
    final originalPrice = offer.originalPrice;
    final hasDiscount = originalPrice != null && originalPrice > price;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 168,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFDCEBE4)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            height: 106,
            width: double.infinity,
            child: Stack(fit: StackFit.expand, children: [
              Container(
                  color: const Color(0xFFDDF3E8),
                  child: const Icon(Icons.storefront_rounded,
                      color: _green, size: 32)),
              if (image != null && image.isNotEmpty)
                Image.network(image,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox()),
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                      color: _green, borderRadius: BorderRadius.circular(8)),
                  child: const Text('🏪 مؤسسة',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 8.5,
                          fontWeight: FontWeight.w800)),
                ),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 9, 10, 10),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(
                    child: Text(offer.institutionName ?? 'مؤسسة',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Color(0xFF71837C),
                            fontSize: 10,
                            fontWeight: FontWeight.w700))),
                const SizedBox(width: 3),
                const Icon(Icons.verified_rounded, size: 12, color: _green),
              ]),
              const SizedBox(height: 2),
              Text(offer.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: _darkGreen,
                      fontSize: 13,
                      fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    if (hasDiscount)
                      Text('${originalPrice.toStringAsFixed(0)} ',
                          style: const TextStyle(
                              color: Color(0xFF9BAEA5),
                              fontSize: 10,
                              decoration: TextDecoration.lineThrough)),
                    Text('${price.toStringAsFixed(0)} ج',
                        style: const TextStyle(
                            color: _green,
                            fontSize: 14,
                            fontWeight: FontWeight.w900)),
                    if (hasDiscount) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                            color: const Color(0xFFFFE9B8),
                            borderRadius: BorderRadius.circular(7)),
                        child: Text(
                            'خصم ${((1 - price / originalPrice) * 100).toStringAsFixed(0)}%',
                            style: const TextStyle(
                                color: Color(0xFFB77700),
                                fontSize: 8.5,
                                fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ]),
              const SizedBox(height: 5),
              Row(children: [
                Text('${offer.remainingQuantity} متاح',
                    style: const TextStyle(
                        color: Color(0xFF71837C), fontSize: 9.5)),
                const Spacer(),
                Text(offer.status == 'active' ? 'متاح' : 'غير متاح',
                    style: TextStyle(
                        color: offer.status == 'active'
                            ? _green
                            : const Color(0xFFB77700),
                        fontSize: 8.5,
                        fontWeight: FontWeight.w700)),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ============================================================
// ✅ الكارت المختصر — مطاعم
// ============================================================
class _CompactOfferCard extends StatelessWidget {
  final FoodOffer offer;
  final double? distance;
  final VoidCallback onTap;
  const _CompactOfferCard(
      {required this.offer, this.distance, required this.onTap});

  String? get _image {
    final raw = offer.displayImage;
    if (raw == null || raw.isEmpty || raw == 'null') return null;
    if (raw.startsWith('http')) return raw;
    try {
      return SupabaseService()
          .client
          .storage
          .from('restaurant-offers')
          .getPublicUrl(raw.replaceFirst(RegExp(r'^/+'), ''));
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final sale = offer.salePrice;
    final orig = offer.originalPrice;
    final hasDiscount = sale != null && orig != null && orig > sale;
    final discount = hasDiscount ? (1 - sale / orig) * 100 : 0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 168,
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFDCEBE4))),
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            height: 106,
            width: double.infinity,
            child: Stack(fit: StackFit.expand, children: [
              Container(
                  color: const Color(0xFFDDF3E8),
                  child: const Icon(Icons.restaurant_rounded,
                      color: _green, size: 32)),
              if (_image != null)
                Image.network(_image!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox()),
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                      color: offer.isUrgent ? const Color(0xFFE28B00) : _green,
                      borderRadius: BorderRadius.circular(8)),
                  child: Text(offer.isUrgent ? '🔥 عاجل' : 'متاح الآن',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8.5,
                          fontWeight: FontWeight.w800)),
                ),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 9, 10, 10),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(
                    child: Text(offer.businessName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Color(0xFF71837C),
                            fontSize: 10,
                            fontWeight: FontWeight.w700))),
                const SizedBox(width: 3),
                const Icon(Icons.verified_rounded, size: 12, color: _green),
              ]),
              const SizedBox(height: 2),
              Text(offer.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: _darkGreen,
                      fontSize: 13,
                      fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    if (hasDiscount)
                      Text('${orig.toStringAsFixed(0)} ',
                          style: const TextStyle(
                              color: Color(0xFF9BAEA5),
                              fontSize: 10,
                              decoration: TextDecoration.lineThrough)),
                    Text(
                        sale != null && sale > 0
                            ? '${sale.toStringAsFixed(0)} ج'
                            : 'مجاني',
                        style: const TextStyle(
                            color: _green,
                            fontSize: 14,
                            fontWeight: FontWeight.w900)),
                    if (hasDiscount) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                            color: const Color(0xFFFFE9B8),
                            borderRadius: BorderRadius.circular(7)),
                        child: Text('خصم ${discount.toStringAsFixed(0)}%',
                            style: const TextStyle(
                                color: Color(0xFFB77700),
                                fontSize: 8.5,
                                fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ]),
              const SizedBox(height: 5),
              Row(children: [
                if (distance != null)
                  Text(
                      distance! < 1
                          ? '${(distance! * 1000).toStringAsFixed(0)} م'
                          : '${distance!.toStringAsFixed(1)} كم',
                      style: const TextStyle(
                          color: Color(0xFF71837C), fontSize: 9.5)),
                const Spacer(),
                Text('${offer.quantity} متاح · ${offer.timeRemaining}',
                    style: const TextStyle(
                        color: Color(0xFFB77700),
                        fontSize: 8.5,
                        fontWeight: FontWeight.w700)),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ============================================================
// Empty state
// ============================================================
class _EmptyHome extends StatelessWidget {
  const _EmptyHome();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(40, 48, 40, 20),
      child: Column(children: [
        Text('هدوء حواليك دلوقتي',
            style: TextStyle(
                color: _darkGreen, fontSize: 17, fontWeight: FontWeight.w900)),
        SizedBox(height: 6),
        Text('أول ما يظهر فائض قريب منك هنقولك فورًا',
            textAlign: TextAlign.center,
            style:
                TextStyle(color: Color(0xFF71837C), fontSize: 13, height: 1.5)),
      ]),
    );
  }
}
