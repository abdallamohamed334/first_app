import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:loqma/features/community/data/repositories/community_offer_repository.dart';
import 'package:loqma/features/community/presentation/pages/community_offer_details_page.dart';

class CommunityOffersPage extends StatefulWidget {
  const CommunityOffersPage({super.key});

  @override
  State<CommunityOffersPage> createState() => _CommunityOffersPageState();
}

class _CommunityOffersPageState extends State<CommunityOffersPage> {
  final CommunityOfferRepository _repository = CommunityOfferRepository();

  late Future<List<Map<String, dynamic>>> _future;

  String _categoryId = 'all';

  static const Color _green = Color(0xFF0B7650);
  static const Color _darkGreen = Color(0xFF123F31);
  static const Color _background = Color(0xFFF6FAF8);

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  // ============================================================
  // Data
  // ============================================================

  Future<List<Map<String, dynamic>>> _load() {
    return _repository.getOffers(
      categoryId: _categoryId == 'all' ? null : _categoryId,
    );
  }

  void _applyFilters({
    String? categoryId,
  }) {
    if (!mounted) {
      return;
    }

    setState(() {
      if (categoryId != null) {
        _categoryId = categoryId;
      }

      _future = _load();
    });
  }

  Future<void> _refresh() async {
    final future = _load();

    if (!mounted) {
      await future;
      return;
    }

    setState(() {
      _future = future;
    });

    await future;
  }

  void _resetFilters() {
    _applyFilters(
      categoryId: 'all',
    );
  }

  // ============================================================
  // Build
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _background,
        appBar: AppBar(
          title: const Text(
            'شراء بسعر رمزي',
            style: TextStyle(
              fontWeight: FontWeight.w900,
            ),
          ),
          centerTitle: true,
          backgroundColor: _background,
          foregroundColor: _darkGreen,
          elevation: 0,
          scrolledUnderElevation: 0,
          actions: [
            IconButton(
              onPressed: _refresh,
              icon: const Icon(
                Icons.refresh_rounded,
              ),
              tooltip: 'تحديث',
            ),
          ],
        ),
        body: FutureBuilder<List<Map<String, dynamic>>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const _LoadingState();
            }

            if (snapshot.hasError) {
              return _ErrorState(
                message: _cleanErrorMessage(
                  snapshot.error,
                ),
                onRetry: _refresh,
              );
            }

            final offers = snapshot.data ?? const <Map<String, dynamic>>[];

            return RefreshIndicator(
              color: _green,
              backgroundColor: Colors.white,
              onRefresh: _refresh,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                slivers: [
                  SliverToBoxAdapter(
                    child: _buildIntro(),
                  ),
                  SliverToBoxAdapter(
                    child: _buildFilters(),
                  ),
                  SliverToBoxAdapter(
                    child: _buildResultsHeader(
                      offers.length,
                    ),
                  ),
                  if (offers.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _EmptyState(
                        onReset: _resetFilters,
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(
                        20,
                        4,
                        20,
                        32,
                      ),
                      sliver: SliverList.separated(
                        itemCount: offers.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 14),
                        itemBuilder: (_, index) {
                          final offer = offers[index];

                          return _OfferCard(
                            offer: offer,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => CommunityOfferDetailsPage(
                                    offer: offer,
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // ============================================================
  // Intro
  // ============================================================

  Widget _buildIntro() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        20,
        8,
        20,
        14,
      ),
      child: Container(
        padding: const EdgeInsets.all(19),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              Color(0xFF0B7650),
              Color(0xFF2BAA76),
            ],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: _green.withAlpha(30),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'حاجات تستحق فرصة جديدة',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                      height: 1.2,
                    ),
                  ),
                  SizedBox(height: 7),
                  Text(
                    'اشتري حاجات قريبة منك بسعر رمزي، وساعد في إعادة استخدامها بدل ما تترمي.',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 12),
            Icon(
              Icons.recycling_rounded,
              color: Colors.white,
              size: 42,
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // Filters
  // ============================================================

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        20,
        0,
        20,
        4,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'التصنيف',
            style: TextStyle(
              color: _darkGreen,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 9),
          _buildCategoryFilters(),
        ],
      ),
    );
  }

  Widget _buildCategoryFilters() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _repository.getActiveCategories(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 42,
            child: Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: _green,
                ),
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3F3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFF0D2D2),
              ),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  size: 17,
                  color: Color(0xFFB54747),
                ),
                SizedBox(width: 7),
                Expanded(
                  child: Text(
                    'تعذر تحميل التصنيفات',
                    style: TextStyle(
                      color: Color(0xFFB54747),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        final categories = snapshot.data ?? const <Map<String, dynamic>>[];

        final values = <(String, String, IconData)>[
          (
            'all',
            'الكل',
            Icons.grid_view_rounded,
          ),
        ];

        for (final category in categories) {
          final id = category['id']?.toString().trim();

          if (id == null || id.isEmpty) {
            continue;
          }

          final nameAr = category['name_ar']?.toString().trim() ?? '';

          if (nameAr.isEmpty) {
            continue;
          }

          final slug = category['slug']?.toString().trim() ?? 'other';

          values.add(
            (
              id,
              nameAr,
              _categoryIcon(slug),
            ),
          );
        }

        return _chips(
          values,
          _categoryId,
          (value) {
            _applyFilters(
              categoryId: value,
            );
          },
        );
      },
    );
  }

  Widget _chips(
    List<(String, String, IconData)> values,
    String selected,
    ValueChanged<String> onSelected,
  ) {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, index) {
          final item = values[index];

          final active = selected == item.$1;

          return FilterChip(
            selected: active,
            onSelected: (_) {
              onSelected(item.$1);
            },
            avatar: Icon(
              item.$3,
              size: 16,
              color: active ? _green : const Color(0xFF71837C),
            ),
            label: Text(
              item.$2,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            labelStyle: TextStyle(
              color: active ? _green : const Color(0xFF5F786C),
              fontSize: 11,
              fontWeight: active ? FontWeight.w900 : FontWeight.w700,
            ),
            backgroundColor: Colors.white,
            selectedColor: const Color(0xFFDDF3E8),
            checkmarkColor: _green,
            side: BorderSide(
              color: active ? _green : const Color(0xFFE0EBE5),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          );
        },
      ),
    );
  }

  // ============================================================
  // Results Header
  // ============================================================

  Widget _buildResultsHeader(int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        20,
        13,
        20,
        8,
      ),
      child: Row(
        children: [
          const Icon(
            Icons.sell_outlined,
            size: 17,
            color: _green,
          ),
          const SizedBox(width: 6),
          Text(
            count == 0
                ? 'لا توجد عروض'
                : '$count ${count == 1 ? 'عرض متاح' : 'عروض متاحة'}',
            style: const TextStyle(
              color: _darkGreen,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const Spacer(),
          if (_categoryId != 'all')
            TextButton(
              onPressed: _resetFilters,
              style: TextButton.styleFrom(
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'مسح الفلتر',
                style: TextStyle(
                  color: _green,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ============================================================
  // Category Icons
  // ============================================================

  IconData _categoryIcon(String slug) {
    switch (slug) {
      case 'clothing':
        return Icons.checkroom_rounded;

      case 'furniture':
        return Icons.chair_rounded;

      case 'electronics':
        return Icons.devices_rounded;

      case 'mobile_phones':
        return Icons.phone_android_rounded;

      case 'home_appliances':
        return Icons.kitchen_rounded;

      case 'shoes':
        return Icons.directions_walk_rounded;

      case 'bags':
        return Icons.shopping_bag_rounded;

      case 'books':
        return Icons.menu_book_rounded;

      case 'toys':
        return Icons.toys_rounded;

      case 'kids':
        return Icons.child_friendly_rounded;

      case 'home_items':
        return Icons.home_rounded;

      case 'tools':
        return Icons.handyman_rounded;

      case 'sports':
        return Icons.sports_soccer_rounded;

      case 'car_accessories':
        return Icons.directions_car_rounded;

      case 'collectibles':
        return Icons.collections_rounded;

      case 'musical_instruments':
        return Icons.music_note_rounded;

      case 'office_supplies':
        return Icons.business_center_rounded;

      case 'other':
      default:
        return Icons.category_rounded;
    }
  }

  String _cleanErrorMessage(Object? error) {
    if (error == null) {
      return 'حدث خطأ غير معروف أثناء تحميل العروض.';
    }

    final message = error
        .toString()
        .replaceFirst(
          'Exception: ',
          '',
        )
        .trim();

    if (message.isEmpty) {
      return 'حدث خطأ أثناء تحميل العروض.';
    }

    return message;
  }
}

// ============================================================
// Offer Card
// ============================================================

class _OfferCard extends StatelessWidget {
  static const Color _green = Color(0xFF0B7650);
  static const Color _darkGreen = Color(0xFF123F31);

  final Map<String, dynamic> offer;
  final VoidCallback onTap;

  const _OfferCard({
    required this.offer,
    required this.onTap,
  });

  // ============================================================
  // Images
  // ============================================================

  List<String> _getImages() {
    final images = <String>[];

    final imagesList = offer['images'];

    if (imagesList is List) {
      for (final item in imagesList) {
        final url = item.toString().trim();

        if (url.isNotEmpty && url != 'null') {
          images.add(url);
        }
      }
    }

    if (images.isEmpty) {
      final single = offer['image']?.toString().trim() ?? '';

      if (single.isNotEmpty && single != 'null') {
        images.add(single);
      }
    }

    return images;
  }

  // ============================================================
  // Text Helpers
  // ============================================================

  String _text(
    String key,
    String fallback,
  ) {
    final value = offer[key];

    if (value == null) {
      return fallback;
    }

    final text = value.toString().trim();

    return text.isEmpty ? fallback : text;
  }

  String _categoryName() {
    final direct = offer['category_name_ar']?.toString().trim();

    if (direct != null && direct.isNotEmpty && direct != 'null') {
      return direct;
    }

    final category = offer['community_categories'];

    if (category is Map) {
      final name = category['name_ar']?.toString().trim();

      if (name != null && name.isNotEmpty) {
        return name;
      }
    }

    return 'أخرى';
  }

  String _categorySlug() {
    final direct = offer['category_slug']?.toString().trim();

    if (direct != null && direct.isNotEmpty && direct != 'null') {
      return direct;
    }

    final category = offer['community_categories'];

    if (category is Map) {
      final slug = category['slug']?.toString().trim();

      if (slug != null && slug.isNotEmpty) {
        return slug;
      }
    }

    return 'other';
  }

  double _price() {
    final value = offer['price'];

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
          value?.toString() ?? '',
        ) ??
        0.0;
  }

  String _formatPrice(double price) {
    if (price == price.roundToDouble()) {
      return '${price.toStringAsFixed(0)} جنيه';
    }

    return '${price.toStringAsFixed(2)} جنيه';
  }

  String _conditionLabel(String value) {
    switch (value) {
      case 'new':
        return 'جديد';

      case 'very_good':
        return 'جيد جدًا';

      case 'good':
        return 'جيد';

      case 'needs_repair':
        return 'يحتاج إصلاح';

      default:
        return 'حالة جيدة';
    }
  }

  String? _expiryLabel() {
    final raw = offer['expires_at'];

    if (raw == null) {
      return null;
    }

    final expiresAt = DateTime.tryParse(
      raw.toString(),
    );

    if (expiresAt == null) {
      return null;
    }

    final remaining = expiresAt.toUtc().difference(
          DateTime.now().toUtc(),
        );

    if (remaining.isNegative || remaining.inSeconds <= 0) {
      return null;
    }

    if (remaining.inDays >= 1) {
      return 'متبقي ${remaining.inDays} يوم';
    }

    final hours = remaining.inHours;

    if (hours >= 1) {
      return 'متبقي $hours ساعة';
    }

    return 'ينتهي قريبًا';
  }

  // ============================================================
  // Build
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final title = _text(
      'title',
      'عرض جديد',
    );

    final categoryName = _categoryName();

    final categorySlug = _categorySlug();

    final condition = _text(
      'item_condition',
      'good',
    );

    final location = _text(
      'pickup_location',
      'مكان الاستلام غير محدد',
    );

    final price = _price();

    final images = _getImages();

    final expiry = _expiryLabel();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: const Color(
                0xFFE1ECE6,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(9),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildImages(
                images: images,
                categorySlug: categorySlug,
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ------------------------------------------------
                    // Title + Arrow
                    // ------------------------------------------------

                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _darkGreen,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              height: 1.25,
                            ),
                          ),
                        ),
                        const SizedBox(
                          width: 8,
                        ),
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFFE8F5EE,
                            ),
                            borderRadius: BorderRadius.circular(
                              50,
                            ),
                          ),
                          child: const Icon(
                            Icons.arrow_forward_ios_rounded,
                            color: _green,
                            size: 13,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(
                      height: 9,
                    ),

                    // ------------------------------------------------
                    // Tags
                    // ------------------------------------------------

                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _tag(
                          categoryName,
                          const Color(
                            0xFFE8F5EE,
                          ),
                          _green,
                        ),
                        _tag(
                          _formatPrice(
                            price,
                          ),
                          const Color(
                            0xFFFFF0DA,
                          ),
                          const Color(
                            0xFFB36B12,
                          ),
                        ),
                        _tag(
                          _conditionLabel(
                            condition,
                          ),
                          const Color(
                            0xFFE3F0FF,
                          ),
                          const Color(
                            0xFF1A6CB5,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(
                      height: 10,
                    ),

                    // ------------------------------------------------
                    // Location
                    // ------------------------------------------------

                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 15,
                          color: Color(
                            0xFF71837C,
                          ),
                        ),
                        const SizedBox(
                          width: 4,
                        ),
                        Expanded(
                          child: Text(
                            location,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(
                                0xFF71837C,
                              ),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),

                    // ------------------------------------------------
                    // Expiry
                    // ------------------------------------------------

                    if (expiry != null) ...[
                      const SizedBox(
                        height: 7,
                      ),
                      Row(
                        children: [
                          const Icon(
                            Icons.schedule_outlined,
                            size: 14,
                            color: Color(
                              0xFF9A6B1E,
                            ),
                          ),
                          const SizedBox(
                            width: 4,
                          ),
                          Text(
                            expiry,
                            style: const TextStyle(
                              color: Color(
                                0xFF9A6B1E,
                              ),
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
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
      ),
    );
  }

  // ============================================================
  // Images
  // ============================================================

  Widget _buildImages({
    required List<String> images,
    required String categorySlug,
  }) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(22),
      ),
      child: SizedBox(
        height: 200,
        width: double.infinity,
        child: images.isEmpty
            ? _emptyImage(
                categorySlug,
              )
            : Stack(
                children: [
                  CarouselSlider.builder(
                    itemCount: images.length,
                    itemBuilder: (
                      context,
                      index,
                      realIndex,
                    ) {
                      return Container(
                        width: double.infinity,
                        color: const Color(
                          0xFFF5F9F7,
                        ),
                        child: Image.network(
                          images[index],
                          fit: BoxFit.contain,
                          width: double.infinity,
                          loadingBuilder: (
                            context,
                            child,
                            loadingProgress,
                          ) {
                            if (loadingProgress == null) {
                              return child;
                            }

                            return const Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: _green,
                              ),
                            );
                          },
                          errorBuilder: (
                            _,
                            __,
                            ___,
                          ) {
                            return _emptyImage(
                              categorySlug,
                            );
                          },
                        ),
                      );
                    },
                    options: CarouselOptions(
                      height: 200,
                      viewportFraction: 1.0,
                      autoPlay: images.length > 1,
                      autoPlayInterval: const Duration(
                        seconds: 4,
                      ),
                      enableInfiniteScroll: images.length > 1,
                      pauseAutoPlayOnTouch: true,
                      enlargeCenterPage: false,
                    ),
                  ),

                  // --------------------------------------------------
                  // Image Count
                  // --------------------------------------------------

                  if (images.length > 1)
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withAlpha(175),
                          borderRadius: BorderRadius.circular(
                            14,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.image_rounded,
                              color: Colors.white,
                              size: 14,
                            ),
                            const SizedBox(
                              width: 4,
                            ),
                            Text(
                              '${images.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // --------------------------------------------------
                  // Image Indicator
                  // --------------------------------------------------

                  if (images.length > 1)
                    Positioned(
                      bottom: 10,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          images.length > 5 ? 5 : images.length,
                          (index) {
                            return Container(
                              width: index == 0 ? 20 : 7,
                              height: 4,
                              margin: const EdgeInsets.symmetric(
                                horizontal: 3,
                              ),
                              decoration: BoxDecoration(
                                color: index == 0
                                    ? Colors.white
                                    : Colors.white.withAlpha(
                                        150,
                                      ),
                                borderRadius: BorderRadius.circular(
                                  10,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _emptyImage(
    String categorySlug,
  ) {
    return Container(
      color: const Color(
        0xFFE8F5EE,
      ),
      child: Center(
        child: Icon(
          _categoryIcon(
            categorySlug,
          ),
          color: _green,
          size: 50,
        ),
      ),
    );
  }

  // ============================================================
  // Tag
  // ============================================================

  Widget _tag(
    String text,
    Color background,
    Color foreground,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: foreground,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  // ============================================================
  // Category Icon
  // ============================================================

  IconData _categoryIcon(
    String slug,
  ) {
    switch (slug) {
      case 'clothing':
        return Icons.checkroom_rounded;

      case 'furniture':
        return Icons.chair_rounded;

      case 'electronics':
        return Icons.devices_rounded;

      case 'mobile_phones':
        return Icons.phone_android_rounded;

      case 'home_appliances':
        return Icons.kitchen_rounded;

      case 'shoes':
        return Icons.directions_walk_rounded;

      case 'bags':
        return Icons.shopping_bag_rounded;

      case 'books':
        return Icons.menu_book_rounded;

      case 'toys':
        return Icons.toys_rounded;

      case 'kids':
        return Icons.child_friendly_rounded;

      case 'home_items':
        return Icons.home_rounded;

      case 'tools':
        return Icons.handyman_rounded;

      case 'sports':
        return Icons.sports_soccer_rounded;

      case 'car_accessories':
        return Icons.directions_car_rounded;

      case 'collectibles':
        return Icons.collections_rounded;

      case 'musical_instruments':
        return Icons.music_note_rounded;

      case 'office_supplies':
        return Icons.business_center_rounded;

      case 'other':
      default:
        return Icons.category_rounded;
    }
  }
}

// ============================================================
// Loading State
// ============================================================

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  static const Color _green = Color(0xFF0B7650);

  @override
  Widget build(
    BuildContext context,
  ) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(
            color: _green,
          ),
          SizedBox(height: 14),
          Text(
            'جاري تحميل العروض...',
            style: TextStyle(
              color: Color(
                0xFF71837C,
              ),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Empty State
// ============================================================

class _EmptyState extends StatelessWidget {
  final VoidCallback onReset;

  const _EmptyState({
    required this.onReset,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 76,
              height: 76,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: Color(
                  0xFFE8F5EE,
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.search_off_rounded,
                color: Color(
                  0xFF0B7650,
                ),
                size: 38,
              ),
            ),
            const SizedBox(
              height: 16,
            ),
            const Text(
              'لا توجد عروض بهذا التصنيف',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(
                  0xFF123F31,
                ),
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(
              height: 7,
            ),
            const Text(
              'جرّب اختيار تصنيف آخر أو ارجع لعرض كل العروض المتاحة.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(
                  0xFF71837C,
                ),
                fontSize: 12,
                height: 1.5,
              ),
            ),
            const SizedBox(
              height: 17,
            ),
            OutlinedButton.icon(
              onPressed: onReset,
              icon: const Icon(
                Icons.grid_view_rounded,
                size: 17,
              ),
              label: const Text(
                'عرض كل العروض',
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(
                  0xFF0B7650,
                ),
                side: const BorderSide(
                  color: Color(
                    0xFF0B7650,
                  ),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// Error State
// ============================================================

class _ErrorState extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _ErrorState({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 76,
              height: 76,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: Color(
                  0xFFFFEEEE,
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.cloud_off_rounded,
                color: Color(
                  0xFFB54747,
                ),
                size: 38,
              ),
            ),
            const SizedBox(
              height: 14,
            ),
            const Text(
              'تعذر تحميل العروض',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(
                  0xFF123F31,
                ),
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(
              height: 8,
            ),
            Text(
              message,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(
                  0xFF71837C,
                ),
                fontSize: 11,
                height: 1.4,
              ),
            ),
            const SizedBox(
              height: 16,
            ),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(
                Icons.refresh_rounded,
                size: 17,
              ),
              label: const Text(
                'إعادة المحاولة',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(
                  0xFF0B7650,
                ),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
