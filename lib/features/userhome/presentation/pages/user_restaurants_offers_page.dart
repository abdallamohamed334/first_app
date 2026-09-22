// lib/features/userhome/presentation/pages/user_restaurants_offers_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:loqma/core/services/supabase_service.dart';
import 'package:loqma/features/charity/presentation/pages/person_offer_details_page.dart';
import 'package:loqma/features/map/presentation/pages/map_page.dart';
import 'package:loqma/features/notification/presentation/bloc/notification_bloc.dart';
import 'package:loqma/features/notification/presentation/bloc/notification_state.dart';
import 'package:loqma/features/notification/presentation/pages/notifications_page.dart';
import 'package:loqma/features/offers/domain/entities/food_offer.dart';
import 'package:loqma/features/userhome/presentation/bloc/userhome_bloc.dart';
import 'package:loqma/features/userhome/presentation/bloc/userhome_state.dart';

class UserRestaurantsOffersPage extends StatefulWidget {
  final List<FoodOffer>? offers;

  const UserRestaurantsOffersPage({super.key, this.offers});

  @override
  State<UserRestaurantsOffersPage> createState() =>
      _UserRestaurantsOffersPageState();
}

class _UserRestaurantsOffersPageState extends State<UserRestaurantsOffersPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  List<FoodOffer> _allOffers = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadOffers();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _loadOffers() {
    if (widget.offers != null && widget.offers!.isNotEmpty) {
      final filtered =
          widget.offers!.where((o) => o.source == 'restaurant').toList();
      setState(() {
        _allOffers = filtered;
      });
      return;
    }

    final state = context.read<UserHomeBloc>().state;
    if (state is UserHomeLoaded) {
      final filtered =
          state.offers.where((o) => o.source == 'restaurant').toList();
      setState(() {
        _allOffers = filtered;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: colorScheme.surface,
        appBar: _buildAppBar(context, colorScheme, isDark),
        body: Column(
          children: [
            // ✅ TabBar
            _buildTabBar(colorScheme, isDark),
            // ✅ TabBarView
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // ✅ Tab 1: عروض المطاعم
                  _RestaurantsOffersView(
                    offers: _allOffers,
                    onRefresh: () {
                      _loadOffers();
                      if (mounted) setState(() {});
                    },
                    onNavigateToDetails: _navigateToDetails,
                  ),
                  // ✅ Tab 2: طلباتي على المطاعم
                  const _MyRestaurantRequestsView(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // TAB BAR
  // ============================================================

  Widget _buildTabBar(ColorScheme colorScheme, bool isDark) {
    return Container(
      color: isDark ? const Color(0xFF1F1F1F) : Colors.white,
      child: TabBar(
        controller: _tabController,
        indicatorColor: colorScheme.primary,
        indicatorWeight: 3,
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: colorScheme.primary,
        unselectedLabelColor: colorScheme.onSurfaceVariant,
        labelStyle: const TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: 13,
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
        tabs: const [
          Tab(
            icon: Icon(Icons.restaurant_rounded, size: 20),
            text: 'عروض المطاعم',
          ),
          Tab(
            icon: Icon(Icons.receipt_long_rounded, size: 20),
            text: 'طلباتي',
          ),
        ],
      ),
    );
  }

  // ============================================================
  // APPBAR
  // ============================================================

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    ColorScheme colorScheme,
    bool isDark,
  ) {
    final userId = SupabaseService().client.auth.currentUser?.id;

    return AppBar(
      backgroundColor: isDark ? const Color(0xFF1F1F1F) : Colors.white,
      surfaceTintColor: isDark ? const Color(0xFF1F1F1F) : Colors.transparent,
      elevation: 0,
      leading: IconButton(
        onPressed: () => Navigator.of(context).maybePop(),
        icon: Icon(Icons.arrow_back_rounded, color: colorScheme.onSurface),
      ),
      title: Text(
        'المطاعم',
        style: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 20,
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
                icon: Icon(
                  Icons.notifications_none_rounded,
                  color: colorScheme.primary,
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
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================
  // NAVIGATION
  // ============================================================

  void _navigateToDetails(BuildContext context, FoodOffer offer) {
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

// ============================================================================
// TAB 1: RESTAURANTS OFFERS VIEW
// ============================================================================

class _RestaurantsOffersView extends StatelessWidget {
  final List<FoodOffer> offers;
  final VoidCallback onRefresh;
  final void Function(BuildContext, FoodOffer) onNavigateToDetails;

  const _RestaurantsOffersView({
    required this.offers,
    required this.onRefresh,
    required this.onNavigateToDetails,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (offers.isEmpty) {
      return _buildEmptyState(context, colorScheme);
    }

    return RefreshIndicator(
      color: colorScheme.primary,
      onRefresh: () async {
        onRefresh();
        await Future<void>.delayed(const Duration(milliseconds: 400));
      },
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          SliverToBoxAdapter(
            child: _buildHeroHeader(context, colorScheme, offers.length),
          ),
          SliverToBoxAdapter(
            child: _buildStatsRow(context, offers, colorScheme),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.7,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final offer = offers[index];
                  return _RestaurantOfferCard(
                    offer: offer,
                    onTap: () => onNavigateToDetails(context, offer),
                  );
                },
                childCount: offers.length,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroHeader(
    BuildContext context,
    ColorScheme colorScheme,
    int count,
  ) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primary,
            colorScheme.primary.withValues(alpha: 0.7),
          ],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withAlpha(40),
            blurRadius: 20,
            offset: const Offset(0, 8),
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
                  '🍽️ عروض المطاعم',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$count عرض متاح',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(30),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: const Text(
                    '🔥 عروض حصرية من أقرب المطاعم',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(20),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.restaurant_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(
    BuildContext context,
    List<FoodOffer> offers,
    ColorScheme colorScheme,
  ) {
    final available = offers.where((o) => o.isAvailable && !o.isExpired);
    final urgent = available.where((o) => o.isUrgent).length;
    final total = available.length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _statChip(
              context,
              icon: Icons.restaurant_rounded,
              label: 'متاح',
              value: '$total',
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _statChip(
              context,
              icon: Icons.local_fire_department_rounded,
              label: 'عاجل',
              value: '$urgent',
              color: const Color(0xFFE28B00),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _statChip(
              context,
              icon: Icons.star_rounded,
              label: 'مطاعم',
              value: '${offers.map((o) => o.businessId).toSet().length}',
              color: const Color(0xFF8A5BB7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statChip(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F1F1F) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: colors.onSurfaceVariant,
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, ColorScheme colorScheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.restaurant_rounded,
                color: colorScheme.primary,
                size: 56,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'لا توجد عروض مطاعم',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colorScheme.onSurface,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'حاليًا لا توجد عروض من المطاعم\nحاول مرة أخرى لاحقًا',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('تحديث'),
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.primary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// TAB 2: MY RESTAURANT REQUESTS VIEW
// ============================================================================

class _MyRestaurantRequestsView extends StatefulWidget {
  const _MyRestaurantRequestsView();

  @override
  State<_MyRestaurantRequestsView> createState() =>
      _MyRestaurantRequestsViewState();
}

class _MyRestaurantRequestsViewState extends State<_MyRestaurantRequestsView> {
  late Future<List<Map<String, dynamic>>> _future;
  String _filter = 'all';
  String? _busyId;

  @override
  void initState() {
    super.initState();
    _future = _loadRequests();
  }

  Future<List<Map<String, dynamic>>> _loadRequests() async {
    final user = SupabaseService().client.auth.currentUser;
    if (user == null) {
      throw Exception('يجب تسجيل الدخول أولًا');
    }

    final response = await SupabaseService().client.rpc(
          'user_list_my_food_requests',
        );

    if (response is! List) return <Map<String, dynamic>>[];

    return response
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  Future<void> _refresh() async {
    final next = _loadRequests();
    setState(() => _future = next);
    await next;
  }

  Future<void> _cancel(String requestId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('إلغاء الطلب؟'),
          content: const Text(
            'سيتم إلغاء طلبك على الوجبة. هل أنت متأكد؟',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('رجوع'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFB54747),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('إلغاء الطلب'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    setState(() => _busyId = requestId);

    try {
      await SupabaseService().client.rpc(
        'update_food_offer_request_status',
        params: {
          'p_request_id': requestId,
          'p_next_status': 'cancelled',
        },
      );

      if (!mounted) return;
      _showMessage('تم إلغاء الطلب', success: true);
      await _refresh();
    } catch (error) {
      if (!mounted) return;
      _showMessage('تعذر إلغاء الطلب: $error');
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _showPickupQr(Map<String, dynamic> request) async {
    final token = request['pickup_token']?.toString() ?? '';

    if (token.isEmpty) {
      _showMessage('كود الاستلام غير متاح. حاول مرة أخرى.');
      return;
    }

    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Dialog(
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'كود الاستلام',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'اعرض QR أو الكود النصي للمطعم عند الاستلام.',
                    textAlign: TextAlign.right,
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: QrImageView(
                      data: token,
                      size: 220,
                      backgroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2F7F4),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFD7E9DF)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: SelectableText(
                            token,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 16,
                              letterSpacing: 1.2,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF123F31),
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'نسخ الكود',
                          onPressed: () async {
                            await Clipboard.setData(
                              ClipboardData(text: token),
                            );
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                const SnackBar(
                                  content: Text('تم نسخ الكود'),
                                ),
                              );
                            }
                          },
                          icon: const Icon(
                            Icons.copy_rounded,
                            color: Color(0xFF0B7650),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'لا تشارك الكود قبل وصولك واستلام الطلب.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF71837C),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('إغلاق'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showMessage(String message, {bool success = false}) {
    if (!mounted) return;

    final colorScheme = Theme.of(context).colorScheme;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, textDirection: TextDirection.rtl),
        backgroundColor:
            success ? colorScheme.primary : const Color(0xFFB54747),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(color: colorScheme.primary),
          );
        }

        if (snapshot.hasError) {
          return _messageState(
            context,
            icon: Icons.cloud_off_rounded,
            title: 'تعذر تحميل طلباتك',
            onRetry: _refresh,
          );
        }

        final all = snapshot.data ?? const <Map<String, dynamic>>[];
        final requests = all.where(_matchesFilter).toList();

        return RefreshIndicator(
          color: colorScheme.primary,
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              _buildFilters(colorScheme),
              const SizedBox(height: 14),
              if (requests.isEmpty)
                _messageState(
                  context,
                  icon: Icons.receipt_long_rounded,
                  title: 'لا توجد طلبات بهذا الفلتر',
                  onRetry: _refresh,
                )
              else
                ...requests.map((r) => _buildRequestCard(context, r)),
            ],
          ),
        );
      },
    );
  }

  bool _matchesFilter(Map<String, dynamic> row) {
    if (_filter == 'all') return true;
    return row['status']?.toString() == _filter;
  }

  Widget _buildFilters(ColorScheme colorScheme) {
    final filters = {
      'all': 'الكل',
      'pending': 'في الانتظار',
      'accepted': 'مقبول',
      'ready_for_pickup': 'جاهز للاستلام',
      'completed': 'مكتمل',
      'cancelled': 'ملغي',
    };

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, index) {
          final key = filters.keys.elementAt(index);
          final active = _filter == key;

          return FilterChip(
            selected: active,
            onSelected: (_) => setState(() => _filter = key),
            label: Text(filters[key]!),
            selectedColor: colorScheme.primary.withValues(alpha: 0.15),
            backgroundColor: colorScheme.surface,
            checkmarkColor: colorScheme.primary,
            labelStyle: TextStyle(
              color:
                  active ? colorScheme.primary : colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w800,
              fontSize: 11,
            ),
            side: BorderSide(
              color: active ? colorScheme.primary : colorScheme.outlineVariant,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRequestCard(BuildContext context, Map<String, dynamic> request) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final id = request['id']?.toString() ?? '';
    final status = request['status']?.toString() ?? 'pending';
    final busy = _busyId == id;

    final offerTitle = request['offer_title']?.toString() ?? 'وجبة';
    final offerImage = request['offer_image']?.toString();
    final offerType = request['offer_food_type']?.toString() ?? '';
    final price = (request['offer_sale_price'] as num?)?.toDouble() ?? 0.0;
    final originalPrice = (request['offer_original_price'] as num?)?.toDouble();

    final businessName = request['business_name']?.toString() ?? 'مطعم';
    final businessLogo = request['business_logo']?.toString();
    final businessAddress = request['business_address']?.toString() ?? '';

    final quantity = (request['quantity'] as num?)?.toInt() ?? 1;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F1F1F) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.3)
                : Colors.black.withAlpha(8),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Header: صورة الوجبة + المطعم ───
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // صورة الوجبة
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(
                    width: 72,
                    height: 72,
                    child: offerImage != null && offerImage.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: offerImage,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(
                              color: colorScheme.primary.withValues(alpha: 0.1),
                            ),
                            errorWidget: (_, __, ___) => Container(
                              color: colorScheme.primary.withValues(alpha: 0.1),
                              child: Icon(
                                Icons.restaurant_rounded,
                                color: colorScheme.primary,
                              ),
                            ),
                          )
                        : Container(
                            color: colorScheme.primary.withValues(alpha: 0.1),
                            child: Icon(
                              Icons.restaurant_rounded,
                              color: colorScheme.primary,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                // التفاصيل
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        offerTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      // المطعم
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 9,
                            backgroundColor:
                                colorScheme.primary.withValues(alpha: 0.12),
                            backgroundImage: (businessLogo != null &&
                                    businessLogo.isNotEmpty)
                                ? NetworkImage(businessLogo)
                                : null,
                            child:
                                (businessLogo == null || businessLogo.isEmpty)
                                    ? Icon(
                                        Icons.storefront_rounded,
                                        size: 10,
                                        color: colorScheme.primary,
                                      )
                                    : null,
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              businessName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: colorScheme.onSurfaceVariant,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // السعر + الكمية
                      Row(
                        children: [
                          if (price > 0)
                            Text(
                              '${price.toStringAsFixed(0)} ج.م',
                              style: TextStyle(
                                color: colorScheme.primary,
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          if (originalPrice != null &&
                              originalPrice > price) ...[
                            const SizedBox(width: 5),
                            Text(
                              '${originalPrice.toStringAsFixed(0)}',
                              style: TextStyle(
                                color: colorScheme.onSurfaceVariant,
                                fontSize: 10,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                          ],
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'الكمية: $quantity',
                              style: TextStyle(
                                color: colorScheme.primary,
                                fontSize: 9,
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

          // ─── Timeline ───
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest
                  .withValues(alpha: isDark ? 0.3 : 0.5),
              border: Border(
                top: BorderSide(color: colorScheme.outlineVariant),
                bottom: BorderSide(color: colorScheme.outlineVariant),
              ),
            ),
            child: _buildTimeline(context, status),
          ),

          // ─── Footer: العنوان ───
          if (businessAddress.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              child: Row(
                children: [
                  Icon(
                    Icons.location_on_rounded,
                    size: 13,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      businessAddress,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // ─── Actions ───
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                if (status == 'ready_for_pickup')
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: busy ? null : () => _showPickupQr(request),
                      icon: const Icon(Icons.qr_code_2_rounded, size: 18),
                      label: const Text('عرض كود الاستلام'),
                      style: FilledButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                if (status == 'pending' || status == 'accepted')
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: busy ? null : () => _cancel(id),
                      icon: const Icon(Icons.cancel_outlined, size: 18),
                      label: const Text('إلغاء الطلب'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFB54747),
                        side: const BorderSide(color: Color(0xFFE7B9B9)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                if (status == 'completed' || status == 'expired')
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        status == 'completed'
                            ? '✅ تم استلام الطلب'
                            : '⏳ انتهت صلاحية الطلب',
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                if (status == 'cancelled' || status == 'rejected')
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFBE4E4),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        status == 'cancelled'
                            ? '🚫 تم إلغاء الطلب'
                            : '❌ تم رفض الطلب',
                        style: const TextStyle(
                          color: Color(0xFFB54747),
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
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
  // TIMELINE
  // ============================================================

  Widget _buildTimeline(BuildContext context, String status) {
    final colorScheme = Theme.of(context).colorScheme;

    // الخطوات
    const steps = [
      'pending',
      'accepted',
      'ready_for_pickup',
      'completed',
    ];

    const labels = {
      'pending': 'في الانتظار',
      'accepted': 'مقبول',
      'ready_for_pickup': 'جاهز',
      'completed': 'مكتمل',
    };

    // لو ملغي أو مرفوض أو منتهي
    final isTerminated =
        status == 'cancelled' || status == 'rejected' || status == 'expired';

    final currentIndex = isTerminated ? -1 : steps.indexOf(status);

    return Row(
      children: List.generate(steps.length, (index) {
        final isActive = index <= currentIndex;
        final isLast = index == steps.length - 1;

        return Expanded(
          child: Row(
            children: [
              // الدائرة
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isActive
                      ? colorScheme.primary
                      : colorScheme.outlineVariant,
                  shape: BoxShape.circle,
                ),
                child: isActive
                    ? const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 14,
                      )
                    : null,
              ),
              // الخط
              if (!isLast)
                Expanded(
                  child: Container(
                    height: 2,
                    color: index < currentIndex
                        ? colorScheme.primary
                        : colorScheme.outlineVariant,
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }

  // ============================================================
  // MESSAGE STATE
  // ============================================================

  Widget _messageState(
    BuildContext context, {
    required IconData icon,
    required String title,
    required Future<void> Function() onRetry,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 80),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: colorScheme.primary, size: 56),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('تحديث'),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// RESTAURANT OFFER CARD
// ============================================================================

class _RestaurantOfferCard extends StatelessWidget {
  final FoodOffer offer;
  final VoidCallback onTap;

  const _RestaurantOfferCard({
    required this.offer,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sale = offer.salePrice;
    final orig = offer.originalPrice;
    final hasDiscount = sale != null && orig != null && orig > sale;
    final discount = hasDiscount ? ((1 - sale / orig) * 100).round() : 0;
    final imageUrl = offer.displayImage;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1F1F1F) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.3)
                  : colors.primary.withAlpha(12),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ─── الصورة ───
            Stack(
              children: [
                SizedBox(
                  height: 130,
                  width: double.infinity,
                  child: imageUrl != null && imageUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: colors.primary.withValues(alpha: 0.1),
                            child: Icon(
                              Icons.restaurant_rounded,
                              color: colors.primary,
                              size: 40,
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: colors.primary.withValues(alpha: 0.1),
                            child: Icon(
                              Icons.restaurant_rounded,
                              color: colors.primary,
                              size: 40,
                            ),
                          ),
                        )
                      : Container(
                          color: colors.primary.withValues(alpha: 0.1),
                          child: Icon(
                            Icons.restaurant_rounded,
                            color: colors.primary,
                            size: 40,
                          ),
                        ),
                ),
                if (offer.isUrgent)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE28B00),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        '🔥 عاجل',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  bottom: 8,
                  left: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.store_rounded,
                          color: Colors.white,
                          size: 12,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            offer.businessName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (offer.businessRating > 0) ...[
                          const Icon(
                            Icons.star_rounded,
                            color: Color(0xFFE28B00),
                            size: 12,
                          ),
                          Text(
                            offer.businessRating.toStringAsFixed(1),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // ─── المحتوى ───
            Flexible(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      offer.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.onSurface,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: colors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            offer.foodType,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colors.primary,
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '📦 ${offer.quantity}',
                          style: TextStyle(
                            color: colors.onSurfaceVariant,
                            fontSize: 9,
                          ),
                        ),
                        const Spacer(),
                        const Icon(
                          Icons.schedule_rounded,
                          color: Color(0xFFB77700),
                          size: 10,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          offer.timeRemaining,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFFB77700),
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Flexible(
                          child: Wrap(
                            spacing: 3,
                            runSpacing: 2,
                            alignment: WrapAlignment.start,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              if (sale != null && sale > 0)
                                Text(
                                  '${sale.toStringAsFixed(0)} ج.م',
                                  style: TextStyle(
                                    color: colors.primary,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              if (hasDiscount) ...[
                                Text(
                                  '${orig.toStringAsFixed(0)} ج.م',
                                  style: TextStyle(
                                    color: colors.onSurfaceVariant,
                                    fontSize: 9,
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFE9B8),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'وفر $discount%',
                                    style: const TextStyle(
                                      color: Color(0xFFB77700),
                                      fontSize: 7,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                              if (sale == null || sale == 0)
                                Text(
                                  '🎁 مجاني',
                                  style: TextStyle(
                                    color: colors.primary,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: colors.primary,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'احجز',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.w800,
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
    );
  }
}
