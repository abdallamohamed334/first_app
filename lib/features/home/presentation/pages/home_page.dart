import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:loqma/features/auth/presentation/pages/login_page.dart';
import 'package:loqma/features/donation/presentation/pages/offer_details_page.dart';
import 'package:loqma/features/home/presentation/pages/all_offers_page.dart';
import 'package:loqma/features/institutions/presentation/pages/institution_offers_section.dart';
import 'package:loqma/features/map/presentation/pages/map_page.dart';
import 'package:loqma/features/offers/domain/entities/food_offer.dart';
import 'package:loqma/features/offers/domain/entities/offer_request_status.dart';
import 'package:loqma/features/profile/presentation/pages/profile_page.dart';
import 'package:loqma/features/community/presentation/pages/add_community_offer_page.dart';
import 'package:loqma/features/community/presentation/pages/community_offers_page.dart';
import 'package:loqma/features/community/presentation/pages/community_tracking_page.dart';
import 'package:loqma/features/community/presentation/pages/community_my_charity_donations_page.dart';
import 'package:loqma/features/charity/presentation/pages/add_charity_donation_page.dart';

import '../widgets/community_home_offers_section.dart';
import 'package:loqma/features/institutions/presentation/pages/institution_offer_requests_page.dart';

import 'package:loqma/features/booking/presentation/pages/my_bookings_page.dart';
import 'package:loqma/core/services/supabase_service.dart';
import 'package:loqma/features/notification/presentation/pages/notifications_page.dart';
import 'package:loqma/features/notification/presentation/bloc/notification_bloc.dart';
import 'package:loqma/features/notification/presentation/bloc/notification_event.dart';

import '../bloc/home_bloc.dart';
import '../bloc/home_event.dart';
import '../bloc/home_state.dart';
import '../widgets/home_impact_counters.dart';
import '../widgets/home_level_progress.dart';
import '../widgets/home_leaderboard.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  late final PageController _pageController;
  late final AnimationController _headerController;
  StreamSubscription? _offersSubscription;
  StreamSubscription? _requestsSubscription;
  StreamSubscription? _notificationSubscription;
  List<Map<String, dynamic>> _userRequests = <Map<String, dynamic>>[];
  HomeLoaded? _lastLoadedState;
  int _unreadNotifications = 0;
  int _currentIndex = 0;

  static const _green = Color(0xFF0B7650);
  static const _darkGreen = Color(0xFF123F31);
  static const _background = Color(0xFFF6FAF8);

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _headerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<HomeBloc>().add(const HomeInitialized());
      _loadUserRequests();
      _loadNotifications();
      _loadUnreadNotifications();
      _subscribeToOfferChanges();
    });
  }

  Future<void> _loadUserRequests() async {
    final client = SupabaseService().client;
    final authUser = client.auth.currentUser;
    if (authUser == null) return;

    try {
      try {
        await client.rpc('expire_overdue_food_bookings');
      } catch (error) {
        debugPrint('⚠️ Home expiry check failed: $error');
      }

      final rows = await client
          .from('offer_requests')
          .select('''
            id,
            offer_id,
            status,
            requested_at,
            updated_at,
            completed_at,
            pickup_token_expires_at,
            food_offers:offer_id (
              id,
              title,
              image,
              business_id,
              pickup_before,
              expiry_time,
              businesses:business_id (name)
            )
          ''')
          .eq('user_id', authUser.id)
          .order('updated_at', ascending: false)
          .limit(5);

      if (!mounted) return;
      setState(() {
        _userRequests = List<Map<String, dynamic>>.from(rows);
      });
    } catch (error) {
      debugPrint('❌ User requests load error: $error');
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
    } catch (error) {
      debugPrint('❌ Unread notifications error: $error');
    }
  }

  void _subscribeToOfferChanges() {
    final client = SupabaseService().client;
    _offersSubscription?.cancel();
    _requestsSubscription?.cancel();
    _notificationSubscription?.cancel();

    _offersSubscription =
        client.from('food_offers').stream(primaryKey: ['id']).listen((_) {
      if (!mounted) return;
      context.read<HomeBloc>().add(const RefreshHome());
    }, onError: (error) {
      debugPrint('Offers realtime error: $error');
    });

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
          }, onError: (error) {
            debugPrint('Notifications realtime error: $error');
          });

      _requestsSubscription = client
          .from('offer_requests')
          .stream(primaryKey: ['id'])
          .eq('user_id', authUser.id)
          .listen((_) {
            if (!mounted) return;
            _loadUserRequests();
            context.read<HomeBloc>().add(const RefreshHome());
          }, onError: (error) {
            debugPrint('Requests realtime error: $error');
          });
    }
  }

  @override
  void dispose() {
    _offersSubscription?.cancel();
    _requestsSubscription?.cancel();
    _notificationSubscription?.cancel();
    _pageController.dispose();
    _headerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: BlocConsumer<HomeBloc, HomeState>(
        listener: (context, state) {
          if (state is HomeUnauthenticated && mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const LoginPage()),
            );
          }
        },
        builder: (context, state) {
          if (state is HomeLoaded) {
            _lastLoadedState = state;
            return _buildScaffold(context, state);
          }

          if (_lastLoadedState != null) {
            return _buildScaffold(
              context,
              _lastLoadedState!,
              isRefreshing: true,
            );
          }

          return _buildLoading();
        },
      ),
    );
  }

  Widget _buildLoading() {
    return const Scaffold(
      backgroundColor: _background,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: _green),
            SizedBox(height: 18),
            Text(
              'بنجهز لك أحدث العروض...',
              style: TextStyle(
                color: _darkGreen,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'ثواني ونجيب لك كل ما هو متاح',
              style: TextStyle(color: Color(0xFF71837C), fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRefreshingBanner() {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: _darkGreen,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(35),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'بنحدّث لك العروض وطلباتك...',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScaffold(
    BuildContext context,
    HomeLoaded state, {
    bool isRefreshing = false,
  }) {
    return Scaffold(
      backgroundColor: _background,
      body: Stack(
        children: [
          PageView(
            controller: _pageController,
            physics: const BouncingScrollPhysics(),
            onPageChanged: (index) {
              if (!mounted) return;
              setState(() => _currentIndex = index);
              context.read<HomeBloc>().add(NavigateToTab(index));
            },
            children: [
              _buildHomeTab(context, state),
              const MapPage(),
              const MyBookingsPage(),
              const CommunityTrackingPage(),
              const InstitutionOfferRequestsPage(),
              const ProfilePage(),
            ],
          ),
          if (isRefreshing)
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 20,
              right: 20,
              child: _buildRefreshingBanner(),
            ),
        ],
      ),
      bottomNavigationBar: _buildBottomNavigation(),
    );
  }

  Widget _buildHomeTab(BuildContext context, HomeLoaded state) {
    return RefreshIndicator(
      color: _green,
      onRefresh: () async {
        context.read<HomeBloc>().add(const RefreshHome());
        await _loadUserRequests();
        _loadNotifications();
        await Future<void>.delayed(const Duration(milliseconds: 500));
      },
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          SliverToBoxAdapter(child: _buildHeader(context, state)),
          SliverToBoxAdapter(child: _buildWelcomeCard(state)),
          SliverToBoxAdapter(child: _buildCommunityContributionCard(context)),
          SliverToBoxAdapter(child: _buildSectionSpacing()),
          const SliverToBoxAdapter(child: CommunityHomeOffersSection()),
          SliverToBoxAdapter(child: _buildSectionSpacing()),
          SliverToBoxAdapter(child: _buildUrgentSection(context, state)),
          SliverToBoxAdapter(child: _buildSectionSpacing()),
          SliverToBoxAdapter(child: _buildAvailableOffers(context, state)),
          SliverToBoxAdapter(child: _buildSectionSpacing()),
          SliverToBoxAdapter(child: _buildBookingTimeline(context, state)),
          SliverToBoxAdapter(child: _buildSectionSpacing()),
          SliverToBoxAdapter(
            child: HomeLevelProgress(user: state.user, stats: state.stats),
          ),
          SliverToBoxAdapter(child: _buildSectionSpacing()),
          SliverToBoxAdapter(
            child: HomeImpactCounters(stats: state.communityStats),
          ),
          SliverToBoxAdapter(child: _buildSectionSpacing()),
          const SliverToBoxAdapter(
            child: HomeLeaderboard(),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 110)),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, HomeLoaded state) {
    final name = state.user.name.trim();
    final avatar = state.user.avatarUrl;

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
        child: Row(
          children: [
            _buildAvatar(name, avatar),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _greeting(),
                    style: const TextStyle(
                      color: Color(0xFF71837C),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    name.isEmpty ? 'مستخدم' : name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _darkGreen,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            _iconButton(
              icon: Icons.notifications_none_rounded,
              onTap: () {
                final user = SupabaseService().client.auth.currentUser;
                if (user == null) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => NotificationsPage(userId: user.id),
                  ),
                ).then((_) {
                  _loadNotifications();
                  _loadUnreadNotifications();
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(String name, String? avatar) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFFDDF3E8),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: _green.withAlpha(35),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipOval(
        child: avatar != null && avatar.isNotEmpty
            ? Image.network(
                avatar,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _avatarLetter(name),
              )
            : _avatarLetter(name),
      ),
    );
  }

  Widget _avatarLetter(String name) {
    return Center(
      child: Text(
        name.isEmpty ? '?' : name.characters.first.toUpperCase(),
        style: const TextStyle(
          color: _green,
          fontWeight: FontWeight.w900,
          fontSize: 19,
        ),
      ),
    );
  }

  Widget _buildWelcomeCard(HomeLoaded state) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0B7650), Color(0xFF1AA66E)],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: _green.withAlpha(45),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'أثرك يبدأ من وجبة',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    'كل حجز ناجح يقلل الهدر ويصنع أثرًا حقيقيًا في مجتمعك.',
                    style: TextStyle(
                      color: Colors.white.withAlpha(220),
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(35),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.eco_rounded,
                color: Colors.white,
                size: 33,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommunityContributionCard(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFDCEBE3)),
          boxShadow: const [
            BoxShadow(
                color: Color(0x0A123F31), blurRadius: 18, offset: Offset(0, 7)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                      color: Color(0xFFDDF3E8), shape: BoxShape.circle),
                  child: const Icon(Icons.add_business_rounded,
                      color: _green, size: 25),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('ساهم بطريقتك',
                          style: TextStyle(
                              color: _darkGreen,
                              fontSize: 18,
                              fontWeight: FontWeight.w900)),
                      SizedBox(height: 4),
                      Text(
                          'اختار طريقة مساهمتك: بيع رمزي أو تبرع مباشر لجمعية.',
                          style: TextStyle(
                              color: Color(0xFF5F786C),
                              fontSize: 11,
                              height: 1.4)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: _homeActionButton(
                    icon: Icons.sell_outlined,
                    title: 'بيع بسعر رمزي',
                    subtitle: 'اعرض الاشياء التى تريد بيعها بسعر مخفض',
                    filled: true,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const AddCommunityOfferPage(),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: _homeActionButton(
                    icon: Icons.volunteer_activism_outlined,
                    title: 'تبرع لجمعية',
                    subtitle: 'أرسل تبرعك مباشرة لجمعية',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const AddCharityDonationPage(),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF6FBF8),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFDCEBE3)),
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              const CommunityMyCharityDonationsPage())),
                  icon: const Icon(Icons.route_rounded, size: 19),
                  label: const Text('متابعة حالة تبرعاتي للجمعيات'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _darkGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const CommunityTrackingPage())),
                icon: const Icon(Icons.shopping_bag_outlined, size: 17),
                label: const Text('متابعة عروض الملابس والأثاث العامة'),
                style: TextButton.styleFrom(foregroundColor: _green),
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const InstitutionOfferRequestsPage(),
                  ),
                ),
                icon: const Icon(Icons.storefront_outlined, size: 17),
                label: const Text('متابعة طلبات عروض المؤسسات'),
                style: TextButton.styleFrom(foregroundColor: _green),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _homeActionButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool filled = false,
  }) {
    final background = filled ? _green : const Color(0xFFF0F8F3);
    final foreground = filled ? Colors.white : _darkGreen;

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 88),
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: filled ? _green : const Color(0xFFCBE4D5),
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: foreground, size: 26),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: foreground,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color:
                            filled ? Colors.white70 : const Color(0xFF71837C),
                        fontSize: 11,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 16,
                color: filled ? Colors.white70 : _green,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUrgentSection(BuildContext context, HomeLoaded state) {
    final urgent = state.offers
        .where(
            (offer) => offer.isAvailable && !offer.isExpired && offer.isUrgent)
        .toList();

    if (urgent.isEmpty) return _buildEmptyUrgentCard();

    final offer = urgent.first;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GestureDetector(
        onTap: () => _showOfferDetails(context, offer),
        child: Container(
          height: 232,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFE28B00).withAlpha(45),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _offerImage(offer),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withAlpha(30),
                      Colors.black.withAlpha(210),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 16,
                right: 16,
                child: _tag('عرض عاجل', const Color(0xFFE28B00)),
              ),
              Positioned(
                left: 18,
                right: 18,
                bottom: 18,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            offer.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            '${offer.businessName}  •  باقي ${offer.timeRemaining}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withAlpha(220),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 15, vertical: 11),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: const Text(
                        'احجز الآن',
                        style: TextStyle(
                          color: _darkGreen,
                          fontSize: 12,
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

  Widget _buildEmptyUrgentCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF7E8),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFFFE0A3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: Color(0xFFFFE9B8),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.notifications_active_rounded,
                color: Color(0xFFB77700),
              ),
            ),
            const SizedBox(width: 13),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'لا توجد عروض عاجلة الآن',
                    style: TextStyle(
                      color: Color(0xFF704C00),
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'ابقَ قريبًا، سنعرض لك أي فرصة عاجلة فور توفرها.',
                    style: TextStyle(
                      color: Color(0xFF8D6B29),
                      fontSize: 12,
                      height: 1.45,
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

  Widget _buildAvailableOffers(BuildContext context, HomeLoaded state) {
    final offers = state.offers
        .where(
          (offer) =>
              offer.isAvailable &&
              !offer.isExpired &&
              offer.status.value != 'completed' &&
              offer.status.value != 'cancelled',
        )
        .toList();

    final regularOffers = offers.isEmpty
        ? _buildEmptyOffersCard()
        : _buildHorizontalSection(
            context: context,
            title: 'عروض متاحة الآن',
            subtitle: '${offers.length} فرصة حقيقية من قاعدة البيانات',
            offers: offers.take(8).toList(),
            state: state,
            urgent: false,
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        regularOffers,
        const SizedBox(height: 18),
        const InstitutionOffersSection(),
      ],
    );
  }

  Widget _buildEmptyOffersCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFDCEBE3)),
        ),
        child: const Column(
          children: [
            Icon(Icons.hourglass_empty_rounded, color: _green, size: 42),
            SizedBox(height: 12),
            Text(
              'ننتظر عرضًا جديدًا لك',
              style: TextStyle(
                color: _darkGreen,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'لا توجد وجبات متاحة حاليًا. سنعرضها هنا فور إضافتها.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF71837C), height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHorizontalSection({
    required BuildContext context,
    required String title,
    required String subtitle,
    required List<FoodOffer> offers,
    required HomeLoaded state,
    required bool urgent,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (urgent) ...[
                          const Icon(
                            Icons.bolt_rounded,
                            color: Color(0xFFE28B00),
                            size: 22,
                          ),
                          const SizedBox(width: 5),
                        ],
                        Text(
                          title,
                          style: const TextStyle(
                            color: _darkGreen,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFF71837C),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => _showAllOffers(context, offers),
                child: const Text(
                  'عرض الكل',
                  style: TextStyle(
                    color: _green,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 13),
        SizedBox(
          height: 275,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            itemCount: offers.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              return _buildOfferCard(context, offers[index], state, urgent);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildOfferCard(
    BuildContext context,
    FoodOffer offer,
    HomeLoaded state,
    bool urgent,
  ) {
    final request = state.offerRequestStatuses[offer.id];

    return GestureDetector(
      onTap: () => _showOfferDetails(context, offer),
      child: Container(
        width: 276,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: urgent ? const Color(0xFFFFE0A3) : const Color(0xFFE2EEE8),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(12),
              blurRadius: 18,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 148,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _offerImageGallery(offer),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: _tag(
                      urgent ? 'عاجل' : 'متاح',
                      urgent ? const Color(0xFFE28B00) : _green,
                    ),
                  ),
                  if (request != null)
                    Positioned(
                      bottom: 12,
                      right: 12,
                      child: _tag(request.displayName, request.color),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    offer.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _darkGreen,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    offer.businessName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF71837C),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.inventory_2_outlined,
                          size: 16, color: _green),
                      const SizedBox(width: 4),
                      Text(
                        'الكمية ${offer.quantity}',
                        style: const TextStyle(
                          color: _green,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      const Icon(Icons.timer_outlined,
                          size: 16, color: Color(0xFF71837C)),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          offer.timeRemaining,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF71837C),
                            fontSize: 11,
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

  // Backward-compatible helper for older call sites in this page.
  // Restaurant cards use the multi-image gallery underneath.
  Widget _offerImage(FoodOffer offer) => _offerImageGallery(offer);

  Widget _offerImageGallery(FoodOffer offer) {
    final urls = offer.displayImages;
    if (urls.isEmpty) {
      return _offerImageFallback();
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          itemCount: urls.length,
          itemBuilder: (_, index) => Image.network(
            urls[index],
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _offerImageFallback(),
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return Stack(
                fit: StackFit.expand,
                children: [
                  _offerImageFallback(),
                  Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white.withAlpha(220),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        if (urls.length > 1)
          Positioned(
            bottom: 10,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                urls.length > 5 ? 5 : urls.length,
                (index) => Container(
                  width: index == 0 ? 16 : 6,
                  height: 5,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color:
                        index == 0 ? Colors.white : Colors.white.withAlpha(150),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _offerImageFallback() {
    return Container(
      color: const Color(0xFFDDF3E8),
      alignment: Alignment.center,
      child: const Icon(Icons.restaurant_rounded, color: _green, size: 48),
    );
  }

  Widget _tag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(235),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _buildBookingTimeline(BuildContext context, HomeLoaded state) {
    final requests = _userRequests
        .where((request) {
          final status = request['status']?.toString().toLowerCase();
          return status != 'cancelled' &&
              status != 'completed' &&
              status != 'expired' &&
              !_isFoodRequestExpired(request);
        })
        .take(3)
        .toList();

    if (requests.isEmpty) return _buildNoBookingCard();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'متابعة طلباتك',
            style: TextStyle(
              color: _darkGreen,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(height: 4),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'بيانات حقيقية من طلباتك الحالية',
            style: TextStyle(color: Color(0xFF71837C), fontSize: 12),
          ),
        ),
        const SizedBox(height: 13),
        ...requests.map((request) => _buildLiveTimelineCard(context, request)),
      ],
    );
  }

  bool _isFoodRequestExpired(Map<String, dynamic> request) {
    final status = request['status']?.toString().toLowerCase();
    if (status == 'expired' || status == 'cancelled' || status == 'completed')
      return true;
    final offer = request['food_offers'] is Map
        ? Map<String, dynamic>.from(request['food_offers'] as Map)
        : <String, dynamic>{};
    final deadline =
        offer['pickup_before'] ?? request['pickup_token_expires_at'];
    final parsed =
        deadline == null ? null : DateTime.tryParse(deadline.toString());
    return parsed != null && parsed.isBefore(DateTime.now().toUtc());
  }

  Widget _buildLiveTimelineCard(
    BuildContext context,
    Map<String, dynamic> request,
  ) {
    final status = (request['status'] ?? 'pending').toString().toLowerCase();
    final offer = request['food_offers'] is Map
        ? Map<String, dynamic>.from(request['food_offers'] as Map)
        : <String, dynamic>{};
    final business = offer['businesses'] is Map
        ? Map<String, dynamic>.from(offer['businesses'] as Map)
        : <String, dynamic>{};
    final title = (offer['title'] ?? 'طلب وجبة').toString();
    final restaurant = (business['name'] ?? 'مطعم').toString();
    final step = _databaseStatusStep(status);
    final statusColor = _databaseStatusColor(status);
    final steps = const [
      ('حجزت', Icons.bookmark_added_rounded),
      ('قبله المطعم', Icons.check_circle_outline_rounded),
      ('جاهز للاستلام', Icons.inventory_2_outlined),
      ('تم التسليم', Icons.verified_rounded),
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      padding: const EdgeInsets.all(21),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2EEE8)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 45,
                height: 45,
                decoration: BoxDecoration(
                  color: const Color(0xFFDDF3E8),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(Icons.restaurant_rounded, color: _green),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: _darkGreen, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 3),
                    Text(restaurant,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Color(0xFF71837C), fontSize: 11)),
                    const SizedBox(height: 3),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Text(_databaseStatusLabel(status),
                            style: TextStyle(
                                color: statusColor,
                                fontSize: 13,
                                fontWeight: FontWeight.w900)),
                        const SizedBox(width: 7),
                        const Text('أنت هنا',
                            style: TextStyle(
                                color: Color(0xFF71837C),
                                fontSize: 10,
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const MyBookingsPage())),
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 16),
                color: _green,
              ),
            ],
          ),
          const SizedBox(height: 17),
          Row(
            children: List.generate(steps.length, (index) {
              final done = index <= step;
              return Expanded(
                child: Row(
                  children: [
                    Column(
                      children: [
                        Icon(steps[index].$2,
                            size: 24,
                            color: done ? _green : const Color(0xFFB8C9C0)),
                        const SizedBox(height: 5),
                        Text(steps[index].$1,
                            style: TextStyle(
                                fontSize: 10,
                                color: done ? _green : const Color(0xFF9BAEA5),
                                fontWeight:
                                    done ? FontWeight.w800 : FontWeight.w500)),
                      ],
                    ),
                    if (index != steps.length - 1)
                      Expanded(
                        child: Container(
                          height: 3,
                          margin: const EdgeInsets.only(
                              bottom: 19, left: 4, right: 4),
                          decoration: BoxDecoration(
                            color:
                                index < step ? _green : const Color(0xFFE3ECE7),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  int _databaseStatusStep(String status) {
    if (status == 'pending') return 0;
    if (status == 'accepted') return 1;
    if (status == 'ready_for_pickup') return 2;
    if (status == 'completed') return 3;
    return 0;
  }

  String _databaseStatusLabel(String status) {
    switch (status) {
      case 'accepted':
        return 'تم قبول الطلب';
      case 'ready_for_pickup':
        return 'الطلب جاهز للاستلام';
      case 'completed':
        return 'تم التسليم بنجاح';
      case 'expired':
        return 'انتهى الطلب';
      case 'cancelled':
        return 'تم إلغاء الطلب';
      default:
        return 'في انتظار رد المطعم';
    }
  }

  Color _databaseStatusColor(String status) {
    if (status == 'completed') return const Color(0xFF208A5A);
    if (status == 'ready_for_pickup') return const Color(0xFFB77700);
    if (status == 'accepted') return const Color(0xFF3679C8);
    if (status == 'cancelled' || status == 'expired')
      return const Color(0xFFD64545);
    return const Color(0xFF8A6B20);
  }

  Widget _buildNoBookingCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFFEFF8F3),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(
          children: [
            Icon(Icons.route_rounded, color: _green, size: 28),
            SizedBox(width: 11),
            Expanded(
              child: Text(
                'احجز وجبة وستظهر هنا رحلة طلبك خطوة بخطوة.',
                style: TextStyle(
                  color: Color(0xFF396653),
                  fontSize: 13,
                  height: 1.45,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionSpacing() => const SizedBox(height: 25);

  Widget _iconButton({required IconData icon, required VoidCallback onTap}) {
    return Container(
      width: 43,
      height: 43,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFE2EEE8)),
      ),
      child: IconButton(
        onPressed: onTap,
        padding: EdgeInsets.zero,
        icon: Icon(icon, color: _green, size: 23),
      ),
    );
  }

  Widget _buildBottomNavigation() {
    const labels = [
      'الرئيسية',
      'الخريطة',
      'طلبات الطعام',
      'تابع طلباتي',
      'طلبات المؤسسات',
      'حسابي',
    ];
    const icons = [
      Icons.home_rounded,
      Icons.map_rounded,
      Icons.restaurant_menu_rounded,
      Icons.volunteer_activism_rounded,
      Icons.storefront_rounded,
      Icons.person_rounded,
    ];

    return SafeArea(
      top: false,
      child: Container(
        height: 72,
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE7F0EB))),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(labels.length, (index) {
            final selected = _currentIndex == index;
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _currentIndex = index);
                  context.read<HomeBloc>().add(NavigateToTab(index));
                  _pageController.animateToPage(
                    index,
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeOutCubic,
                  );
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
                  decoration: BoxDecoration(
                    color:
                        selected ? const Color(0xFFDDF3E8) : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        icons[index],
                        color: selected ? _green : const Color(0xFF9BAEA5),
                        size: 22,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        labels[index],
                        style: TextStyle(
                          color: selected ? _green : const Color(0xFF9BAEA5),
                          fontSize: 10,
                          fontWeight:
                              selected ? FontWeight.w900 : FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'صباح الخير';
    if (hour < 18) return 'مساء الخير';
    return 'مساء الخير';
  }

  void _showAllOffers(BuildContext context, List<FoodOffer> offers) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AllOffersPage(offers: offers)),
    );
  }

  void _showOfferDetails(BuildContext context, FoodOffer offer) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OfferDetailsPage(
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
            'charity_id': offer.charityId,
            'created_at': offer.createdAt.toIso8601String(),
            'updated_at': offer.updatedAt.toIso8601String(),
            'businesses': {
              'name': offer.businessName,
              'logo': offer.businessLogo,
            },
            'images': offer.images ??
                (offer.displayImage != null
                    ? [offer.displayImage!]
                    : <String>[]),
          },
        ),
      ),
    );
  }
}
