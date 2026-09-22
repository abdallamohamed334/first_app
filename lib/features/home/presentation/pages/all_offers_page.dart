// lib/features/home/presentation/pages/all_offers_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:loqma/core/services/supabase_service.dart';
import 'package:loqma/features/booking/presentation/pages/my_bookings_page.dart';
import 'package:loqma/features/charity/presentation/pages/person_offer_details_page.dart';
import 'package:loqma/features/userhome/presentation/bloc/userhome_bloc.dart'; // ✅ استبدال الاستيراد
import 'package:loqma/features/map/presentation/pages/map_page.dart';
import 'package:loqma/features/notification/presentation/bloc/notification_bloc.dart';
import 'package:loqma/features/notification/presentation/bloc/notification_state.dart';
import 'package:loqma/features/notification/presentation/pages/notifications_page.dart';
import 'package:loqma/features/offers/domain/entities/food_offer.dart';
import 'package:loqma/features/profile/presentation/pages/profile_page.dart';
import 'package:loqma/features/userhome/presentation/bloc/userhome_state.dart';

class AllOffersPage extends StatefulWidget {
  final List<FoodOffer>? offers;

  const AllOffersPage({super.key, this.offers});

  @override
  State<AllOffersPage> createState() => _AllOffersPageState();
}

class _AllOffersPageState extends State<AllOffersPage> {
  static const _green = Color(0xFF0B7650);
  static const _darkGreen = Color(0xFF123F31);
  static const _background = Color(0xFFF8FAFA);

  late final TextEditingController _searchController;
  String _query = '';
  String _category = 'الكل';
  final int _selectedTab = 2;
  List<FoodOffer> _allOffers = [];

  static const _categories = <String>[
    'الكل',
    'وجبات',
    'مخبوزات',
    'حلويات',
    'فواكه',
    'مشروبات',
    'ملابس',
    'أثاث',
    'إلكترونيات',
  ];

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController()..addListener(_onSearchChanged);

    // ✅ استدعاء UserHomeStarted لجلب العروض
    context.read<UserHomeBloc>().add(const UserHomeStarted());

    _loadOffers();
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_onSearchChanged)
      ..dispose();
    super.dispose();
  }

  void _loadOffers() {
    if (widget.offers != null && widget.offers!.isNotEmpty) {
      setState(() {
        _allOffers = widget.offers!;
      });
      return;
    }

    // ✅ استخدام UserHomeLoaded بدلاً من HomeLoaded
    final state = context.read<UserHomeBloc>().state;
    if (state is UserHomeLoaded) {
      setState(() {
        _allOffers = state.offers;
      });
    }
  }

  void _onSearchChanged() {
    final next = _searchController.text.trim();
    if (next == _query || !mounted) return;
    setState(() => _query = next);
  }

  List<FoodOffer> get _filteredOffers {
    final query = _query.toLowerCase();
    return _allOffers.where((offer) {
      final available = offer.isAvailable && !offer.isExpired;
      if (!available) return false;

      final categoryMatches = _category == 'الكل' ||
          _categoryText(offer.foodType).contains(_category) ||
          _categoryMatchesFoodType(offer.foodType, _category);
      if (!categoryMatches) return false;

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

  bool _categoryMatchesFoodType(String foodType, String category) {
    final ft = foodType.toLowerCase();
    final cat = category.toLowerCase();

    if (cat == 'ملابس') {
      return ft.contains('ملابس') ||
          ft.contains('clothing') ||
          ft.contains('ثياب');
    }
    if (cat == 'أثاث') {
      return ft.contains('أثاث') ||
          ft.contains('furniture') ||
          ft.contains('كرسي') ||
          ft.contains('طاولة');
    }
    if (cat == 'إلكترونيات') {
      return ft.contains('إلكترونيات') ||
          ft.contains('electronics') ||
          ft.contains('لابتوب') ||
          ft.contains('موبايل');
    }
    return false;
  }

  String _categoryText(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized.contains('ملابس') || normalized.contains('clothing')) {
      return 'ملابس';
    }
    if (normalized.contains('أثاث') || normalized.contains('furniture')) {
      return 'أثاث';
    }
    if (normalized.contains('إلكترونيات') ||
        normalized.contains('electronics')) {
      return 'إلكترونيات';
    }
    if (normalized.contains('bread') || normalized.contains('bakery')) {
      return 'مخبوزات';
    }
    if (normalized.contains('dessert') || normalized.contains('sweet')) {
      return 'حلويات';
    }
    if (normalized.contains('fruit')) return 'فواكه';
    if (normalized.contains('drink') || normalized.contains('beverage')) {
      return 'مشروبات';
    }
    return 'وجبات';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final offers = _filteredOffers;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _background,
        appBar: _buildAppBar(context, colorScheme),
        body: offers.isEmpty
            ? _buildEmptyState(context, colorScheme)
            : RefreshIndicator(
                color: _green,
                onRefresh: () async {
                  _loadOffers();
                  if (mounted) setState(() {});
                },
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 100),
                  children: [
                    _buildSearchBar(colorScheme),
                    const SizedBox(height: 14),
                    _buildCategoryChips(colorScheme),
                    const SizedBox(height: 16),
                    _buildStatisticsCards(colorScheme),
                    if (offers.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _buildFeaturedOffer(context, colorScheme, offers.first),
                      const SizedBox(height: 16),
                    ],
                    _buildOffersList(context, colorScheme, offers),
                  ],
                ),
              ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const MapPage()),
          ),
          backgroundColor: const Color(0xFFEF9900),
          foregroundColor: Colors.white,
          icon: const Icon(Icons.map_rounded),
          label: const Text('الخريطة'),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    ColorScheme colorScheme,
  ) {
    final userId = SupabaseService().client.auth.currentUser?.id;

    return AppBar(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      leading: IconButton(
        onPressed: () => Navigator.of(context).maybePop(),
        icon: const Icon(Icons.arrow_back_rounded),
      ),
      title: Text(
        'العروض المتاحة',
        style: TextStyle(
          color: colorScheme.primary,
          fontSize: 21,
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

  Widget _buildSearchBar(ColorScheme colorScheme) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: TextField(
        controller: _searchController,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'ابحث عن وجبة أو مطعم...',
          prefixIcon: Icon(Icons.search_rounded, color: colorScheme.primary),
          suffixIcon: _query.isEmpty
              ? null
              : IconButton(
                  onPressed: _searchController.clear,
                  icon: const Icon(Icons.close_rounded),
                ),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(color: colorScheme.outlineVariant),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(color: colorScheme.outlineVariant),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: _green, width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryChips(ColorScheme colorScheme) {
    return SizedBox(
      height: 40,
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
            selectedColor: _green,
            backgroundColor: Colors.white,
            labelStyle: TextStyle(
              color: selected ? Colors.white : _darkGreen,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
            side: BorderSide(
              color: selected ? _green : colorScheme.outlineVariant,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(100),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatisticsCards(ColorScheme colorScheme) {
    final available = _allOffers.where((o) => o.isAvailable && !o.isExpired);
    final urgent = available.where((o) => o.isUrgent).length;
    final total = available.length;

    return Row(
      children: [
        Expanded(
          child: _statCard(
            colorScheme,
            icon: Icons.restaurant_rounded,
            label: 'العروض المتاحة',
            value: '$total',
            color: _green,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _statCard(
            colorScheme,
            icon: Icons.local_fire_department_rounded,
            label: 'عروض عاجلة',
            value: '$urgent',
            color: const Color(0xFFD66D00),
          ),
        ),
      ],
    );
  }

  Widget _statCard(
    ColorScheme colorScheme, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: color.withAlpha(24),
            foregroundColor: color,
            child: Icon(icon, size: 19),
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
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
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

  Widget _buildFeaturedOffer(
    BuildContext context,
    ColorScheme colorScheme,
    FoodOffer offer,
  ) {
    final imageUrl = offer.displayImage;

    return InkWell(
      onTap: () => _navigateToDetails(context, offer),
      borderRadius: BorderRadius.circular(22),
      child: Ink(
        height: 185,
        decoration: BoxDecoration(
          color: _darkGreen,
          borderRadius: BorderRadius.circular(22),
          image: imageUrl == null
              ? null
              : DecorationImage(
                  image: NetworkImage(imageUrl),
                  fit: BoxFit.cover,
                  colorFilter: const ColorFilter.mode(
                    Color(0x99000000),
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
                  color: offer.isUrgent ? const Color(0xFFE28B00) : _green,
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

  Widget _buildOffersList(
    BuildContext context,
    ColorScheme colorScheme,
    List<FoodOffer> offers,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'كل العروض',
          style: TextStyle(
            color: colorScheme.primary,
            fontSize: 19,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 10),
        ...offers.map((offer) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _offerCard(context, colorScheme, offer),
            )),
      ],
    );
  }

  Widget _offerCard(
    BuildContext context,
    ColorScheme colorScheme,
    FoodOffer offer,
  ) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _navigateToDetails(context, offer),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  width: 92,
                  height: 92,
                  child: _offerImageSlider(offer),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      offer.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _darkGreen,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      offer.businessName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.schedule_rounded,
                            size: 14, color: colorScheme.primary),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            offer.timeRemaining,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colorScheme.primary,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${offer.quantity} متاح',
                          style: TextStyle(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_left_rounded, color: _green),
            ],
          ),
        ),
      ),
    );
  }

  Widget _offerImageSlider(FoodOffer offer) {
    final imageUrls = <String>{
      ...?offer.images,
      if (offer.displayImage != null && offer.displayImage!.isNotEmpty)
        offer.displayImage!,
    }.toList(growable: false);

    if (imageUrls.isEmpty) {
      return Container(
        color: const Color(0xFFE6F2EC),
        child: const Icon(Icons.restaurant_rounded, color: _green),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          itemCount: imageUrls.length,
          itemBuilder: (_, index) => Image.network(
            imageUrls[index],
            fit: BoxFit.cover,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return Container(
                color: const Color(0xFFE6F2EC),
                child: const Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _green,
                  ),
                ),
              );
            },
            errorBuilder: (_, __, ___) => Container(
              color: const Color(0xFFE6F2EC),
              child: const Icon(Icons.restaurant_rounded, color: _green),
            ),
          ),
        ),
        if (imageUrls.length > 1)
          Positioned(
            bottom: 5,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                imageUrls.length,
                (_) => Container(
                  width: 5,
                  height: 5,
                  margin: const EdgeInsets.symmetric(horizontal: 1.5),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context, ColorScheme colorScheme) {
    final filtered = _query.isNotEmpty || _category != 'الكل';
    final hasOffers = _allOffers.isNotEmpty;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              hasOffers ? Icons.search_off_rounded : Icons.restaurant_rounded,
              color: _green,
              size: 64,
            ),
            const SizedBox(height: 18),
            Text(
              hasOffers
                  ? (filtered
                      ? 'لا توجد نتائج مطابقة'
                      : 'لا توجد عروض متاحة حاليًا')
                  : 'جاري تحميل العروض...',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colorScheme.onSurface,
                fontSize: 19,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hasOffers
                  ? (filtered
                      ? 'جرّب تغيير البحث أو اختيار تصنيف آخر.'
                      : 'سنخبرك فور إضافة عروض جديدة.')
                  : 'برجاء الانتظار لتحميل العروض',
              textAlign: TextAlign.center,
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            if (hasOffers && filtered)
              FilledButton(
                onPressed: () => setState(() {
                  _query = '';
                  _category = 'الكل';
                  _searchController.clear();
                }),
                child: const Text('مسح الفلاتر'),
              )
            else if (!hasOffers)
              ElevatedButton(
                onPressed: _loadOffers,
                child: const Text('إعادة المحاولة'),
              )
            else
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('العودة'),
              ),
          ],
        ),
      ),
    );
  }

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
