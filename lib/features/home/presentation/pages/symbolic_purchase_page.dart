// lib/features/home/presentation/pages/symbolic_purchase_page.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:loqma/core/services/supabase_service.dart';
import 'package:loqma/features/community/data/repositories/community_offer_repository.dart';
import 'package:loqma/features/community/presentation/pages/community_offer_details_page.dart';

class SymbolicPurchasePage extends StatefulWidget {
  const SymbolicPurchasePage({super.key});

  @override
  State<SymbolicPurchasePage> createState() => _SymbolicPurchasePageState();
}

class _SymbolicPurchasePageState extends State<SymbolicPurchasePage> {
  final SupabaseClient _client = SupabaseService().client;

  final CommunityOfferRepository _communityRepository =
      CommunityOfferRepository();

  final TextEditingController _search = TextEditingController();

  List<Map<String, dynamic>> _offers = [];

  bool _loading = true;

  String _filter = 'الكل';
  String _query = '';

  static const List<String> filters = [
    'الكل',
    'ملابس',
    'أثاث',
    'إلكترونيات',
    'أخرى',
  ];

  // ============================================================
  // Lifecycle
  // ============================================================

  @override
  void initState() {
    super.initState();

    _search.addListener(_onSearchChanged);

    _loadOffers();
  }

  @override
  void dispose() {
    _search.removeListener(_onSearchChanged);
    _search.dispose();

    super.dispose();
  }

  void _onSearchChanged() {
    if (!mounted) {
      return;
    }

    setState(() {
      _query = _search.text.trim();
    });
  }

  // ============================================================
  // Arabic normalization
  // ============================================================

  String _norm(String value) {
    return value
        .toLowerCase()
        .trim()
        .replaceAll(
          RegExp('[أإآٱ]'),
          'ا',
        )
        .replaceAll(
          'ى',
          'ي',
        )
        .replaceAll(
          'ة',
          'ه',
        );
  }

  // ============================================================
  // Load Offers
  // ============================================================

  Future<void> _loadOffers() async {
    if (mounted) {
      setState(() {
        _loading = true;
      });
    }

    try {
      // Community عندنا = symbolic_sale فقط.
      //
      // لا نرسل listingType هنا لأن الـRepository
      // أصبح مسؤولًا عن فرض symbolic_sale.
      final rows = await _personOffers();

      rows.sort(
        (a, b) => _date(b).compareTo(
          _date(a),
        ),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _offers = rows;
        _loading = false;
      });
    } catch (error) {
      debugPrint(
        '[SymbolicPurchase] load error: $error',
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _offers = [];
        _loading = false;
      });
    }
  }

  // ============================================================
  // Person Offers
  // ============================================================

  Future<List<Map<String, dynamic>>> _personOffers() async {
    try {
      final rows = await _communityRepository.getOffers();

      return rows
          .map(
            (raw) {
              final row = Map<String, dynamic>.from(
                raw,
              );

              // --------------------------------------------------
              // Owner
              // --------------------------------------------------

              final owner = row['users'] is Map
                  ? Map<String, dynamic>.from(
                      row['users'] as Map,
                    )
                  : <String, dynamic>{};

              row['_type'] = 'أشخاص';

              row['_owner'] = owner['name']?.toString().trim() ?? '';

              // Repository قد يكون بالفعل رجع بيانات الاتصال
              // لذلك نحتفظ بها لو موجودة.
              final existingPhone = row['phone']?.toString().trim() ?? '';

              final existingWhatsapp = row['whatsapp']?.toString().trim() ?? '';

              row['phone'] = existingPhone.isNotEmpty
                  ? existingPhone
                  : owner['phone']?.toString().trim() ?? '';

              row['whatsapp'] = existingWhatsapp.isNotEmpty
                  ? existingWhatsapp
                  : owner['whatsapp']?.toString().trim() ?? '';

              // --------------------------------------------------
              // Price
              // --------------------------------------------------

              row['_price'] = _toDouble(
                row['price'],
              );

              // --------------------------------------------------
              // Images
              // --------------------------------------------------

              final image = _firstImage(
                'community-offers',
                row['image'],
                row['images'],
              );

              row['_image'] = image;

              // لا نمسح الصور الأصلية.
              // فقط نضيف الصورة الأولى لو موجودة.
              if (image != null && image.isNotEmpty) {
                final existingImages = _extractImages(
                  row['images'],
                );

                if (existingImages.isEmpty) {
                  row['images'] = <String>[image];
                }
              }

              return row;
            },
          )
          .where(_isLive)
          .where(_hasRemaining)
          .toList(
            growable: false,
          );
    } catch (error) {
      debugPrint(
        '[SymbolicPurchase] person error: $error',
      );

      return [];
    }
  }

  // ============================================================
  // Remaining Quantity
  // ============================================================

  bool _hasRemaining(
    Map<String, dynamic> row,
  ) {
    final remaining = row['remaining_quantity'];

    if (remaining is num) {
      return remaining > 0;
    }

    final quantity = _toDouble(
      row['quantity'],
    );

    if (quantity != null) {
      final reserved = _toDouble(
        row['reserved_quantity'],
      );

      return quantity - (reserved ?? 0) > 0;
    }

    // لو مفيش أعمدة كمية في البيانات
    // نعتبر العرض متاح.
    return true;
  }

  // ============================================================
  // Live Offer
  // ============================================================

  bool _isLive(
    Map<String, dynamic> row,
  ) {
    final status = row['status']?.toString().toLowerCase().trim();

    if (status == 'paused' ||
        status == 'expired' ||
        status == 'completed' ||
        status == 'cancelled' ||
        status == 'sold_out') {
      return false;
    }

    final rawExpiry = row['expires_at'] ?? row['expiry_time'];

    if (rawExpiry == null) {
      return true;
    }

    final expiry = DateTime.tryParse(
      rawExpiry.toString(),
    );

    if (expiry == null) {
      return true;
    }

    return expiry.toUtc().isAfter(
          DateTime.now().toUtc(),
        );
  }

  // ============================================================
  // Date
  // ============================================================

  DateTime _date(
    Map<String, dynamic> row,
  ) {
    return DateTime.tryParse(
          row['created_at']?.toString() ?? '',
        ) ??
        DateTime.fromMillisecondsSinceEpoch(
          0,
          isUtc: true,
        );
  }

  // ============================================================
  // Images
  // ============================================================

  List<String> _extractImages(
    dynamic many,
  ) {
    if (many is! List) {
      return [];
    }

    return many
        .map(
          (item) => item?.toString().trim() ?? '',
        )
        .where(
          (item) => item.isNotEmpty && item != 'null',
        )
        .toList(
          growable: false,
        );
  }

  String? _firstImage(
    String? bucket,
    dynamic one,
    dynamic many,
  ) {
    final values = <dynamic>[
      if (one != null) one,
      if (many is List) ...many,
    ];

    for (final value in values) {
      final text = value?.toString().trim() ?? '';

      if (text.isEmpty || text == 'null') {
        continue;
      }

      // Full URL
      if (text.startsWith('http://') || text.startsWith('https://')) {
        return text;
      }

      if (bucket != null) {
        try {
          final path = text.replaceFirst(
            RegExp(r'^/+'),
            '',
          );

          return _client.storage.from(bucket).getPublicUrl(path);
        } catch (error) {
          debugPrint(
            '[SymbolicPurchase] image url error: $error',
          );

          continue;
        }
      }

      return text;
    }

    return null;
  }

  // ============================================================
  // Numeric Helpers
  // ============================================================

  double? _toDouble(
    dynamic value,
  ) {
    if (value == null) {
      return null;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
      value.toString(),
    );
  }

  String _formatPrice(
    dynamic value,
  ) {
    final price = _toDouble(value) ?? 0;

    if (price == price.roundToDouble()) {
      return '${price.toStringAsFixed(0)} جنيه';
    }

    return '${price.toStringAsFixed(2)} جنيه';
  }

  // ============================================================
  // Visible Offers
  // ============================================================

  List<Map<String, dynamic>> get _visibleOffers {
    final normalizedQuery = _norm(_query);

    return _offers.where(
      (row) {
        final category = _categoryArabic(
          row,
        );

        if (_filter != 'الكل') {
          if (!_categoryMatchesFilter(
            row,
            _filter,
          )) {
            return false;
          }
        }

        if (normalizedQuery.isEmpty) {
          return true;
        }

        final owner = row['_owner']?.toString() ?? '';

        final title = row['title']?.toString() ?? '';

        final description = row['description']?.toString() ?? '';

        final location = row['pickup_location']?.toString() ?? '';

        final categorySlug = row['category']?.toString() ?? '';

        final haystack = _norm(
          [
            title,
            description,
            category,
            categorySlug,
            owner,
            location,
            'أشخاص',
            'شراء بسعر رمزي',
          ].join(' '),
        );

        return haystack.contains(
          normalizedQuery,
        );
      },
    ).toList(
      growable: false,
    );
  }

  // ============================================================
  // Category
  // ============================================================

  String _categoryArabic(
    Map<String, dynamic> row,
  ) {
    final nested = row['community_categories'];

    if (nested is Map) {
      final name = nested['name_ar']?.toString().trim() ?? '';

      if (name.isNotEmpty) {
        return name;
      }
    }

    final direct = row['category_name_ar']?.toString().trim() ?? '';

    if (direct.isNotEmpty) {
      return direct;
    }

    final slug = row['category']?.toString().trim().toLowerCase() ?? '';

    switch (slug) {
      case 'clothing':
        return 'ملابس';

      case 'furniture':
        return 'أثاث';

      case 'electronics':
        return 'إلكترونيات';

      default:
        return 'أخرى';
    }
  }

  bool _categoryMatchesFilter(
    Map<String, dynamic> row,
    String filter,
  ) {
    final category = _norm(
      _categoryArabic(row),
    );

    final normalizedFilter = _norm(filter);

    if (normalizedFilter == 'ملابس') {
      return category == 'ملابس';
    }

    if (normalizedFilter == 'اثاث') {
      return category == 'اثاث';
    }

    if (normalizedFilter == 'الكترونيات') {
      return category == 'الكترونيات';
    }

    if (normalizedFilter == 'اخري') {
      return category == 'اخري';
    }

    return true;
  }

  // ============================================================
  // Build
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    final colors = Theme.of(context).colorScheme;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    final visible = _visibleOffers;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: colors.surface,
        appBar: AppBar(
          title: const Text(
            'شراء بسعر رمزي',
            style: TextStyle(
              fontWeight: FontWeight.w900,
            ),
          ),
          centerTitle: true,
          backgroundColor: isDark ? const Color(0xFF1F1F1F) : Colors.white,
          foregroundColor: colors.onSurface,
          elevation: 0,
          scrolledUnderElevation: 0,
          actions: [
            IconButton(
              onPressed: _loading ? null : _loadOffers,
              tooltip: 'تحديث',
              icon: const Icon(
                Icons.refresh_rounded,
              ),
            ),
          ],
        ),
        body: _loading
            ? Center(
                child: CircularProgressIndicator(
                  color: colors.primary,
                ),
              )
            : RefreshIndicator(
                color: colors.primary,
                onRefresh: _loadOffers,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  padding: const EdgeInsets.fromLTRB(
                    16,
                    16,
                    16,
                    32,
                  ),
                  children: [
                    _hero(colors),
                    const SizedBox(
                      height: 14,
                    ),
                    _searchBox(
                      colors,
                      isDark,
                    ),
                    const SizedBox(
                      height: 12,
                    ),
                    _filterBar(
                      colors,
                      isDark,
                    ),
                    const SizedBox(
                      height: 18,
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'العروض المتاحة',
                            style: TextStyle(
                              color: colors.onSurface,
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        Text(
                          '${visible.length} عرض',
                          style: TextStyle(
                            color: colors.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(
                      height: 10,
                    ),
                    if (visible.isEmpty)
                      _empty(colors)
                    else
                      ...visible.map(
                        (
                          row,
                        ) =>
                            Padding(
                          padding: const EdgeInsets.only(
                            bottom: 12,
                          ),
                          child: _OfferCard(
                            row: row,
                            onTap: () => _openDetails(
                              row,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
      ),
    );
  }

  // ============================================================
  // Hero
  // ============================================================

  Widget _hero(
    ColorScheme colors,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colors.primary,
            colors.primary.withAlpha(180),
          ],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(
          26,
        ),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withAlpha(35),
            blurRadius: 18,
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
                Text(
                  'اختار اللي يناسبك',
                  style: TextStyle(
                    color: colors.onPrimary,
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(
                  height: 7,
                ),
                Text(
                  'حاجات من أشخاص حقيقيين بأسعار رمزية، قريبة منك وتستحق فرصة جديدة.',
                  style: TextStyle(
                    color: colors.onPrimary.withAlpha(210),
                    fontSize: 12,
                    height: 1.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(
            width: 12,
          ),
          Icon(
            Icons.shopping_bag_rounded,
            color: colors.onPrimary,
            size: 42,
          ),
        ],
      ),
    );
  }

  // ============================================================
  // Search
  // ============================================================

  Widget _searchBox(
    ColorScheme colors,
    bool isDark,
  ) {
    return TextField(
      controller: _search,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'ابحث عن عرض أو تصنيف...',
        hintStyle: TextStyle(
          color: colors.onSurfaceVariant,
          fontSize: 12,
        ),
        prefixIcon: Icon(
          Icons.search_rounded,
          color: colors.primary,
        ),
        suffixIcon: _query.isEmpty
            ? null
            : IconButton(
                onPressed: _search.clear,
                icon: Icon(
                  Icons.close_rounded,
                  color: colors.onSurfaceVariant,
                ),
              ),
        filled: true,
        fillColor: isDark
            ? const Color(
                0xFF1F1F1F,
              )
            : Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(
            17,
          ),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(
            17,
          ),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(
            17,
          ),
          borderSide: BorderSide(
            color: colors.primary.withAlpha(100),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // Filters
  // ============================================================

  Widget _filterBar(
    ColorScheme colors,
    bool isDark,
  ) {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(
          width: 8,
        ),
        itemBuilder: (_, index) {
          final value = filters[index];

          final selected = value == _filter;

          return ChoiceChip(
            label: Text(value),
            selected: selected,
            onSelected: (_) {
              setState(() {
                _filter = value;
              });
            },
            selectedColor: colors.primary,
            backgroundColor: isDark
                ? const Color(
                    0xFF1F1F1F,
                  )
                : Colors.white,
            labelStyle: TextStyle(
              color: selected ? colors.onPrimary : colors.onSurface,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
            side: BorderSide(
              color: selected ? colors.primary : colors.outlineVariant,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(
                20,
              ),
            ),
          );
        },
      ),
    );
  }

  // ============================================================
  // Empty
  // ============================================================

  Widget _empty(
    ColorScheme colors,
  ) {
    return Padding(
      padding: const EdgeInsets.only(
        top: 70,
      ),
      child: Column(
        children: [
          Container(
            width: 78,
            height: 78,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.primary.withAlpha(18),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.search_off_rounded,
              size: 40,
              color: colors.primary,
            ),
          ),
          const SizedBox(
            height: 14,
          ),
          Text(
            'لا توجد عروض مطابقة',
            style: TextStyle(
              color: colors.onSurface,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(
            height: 6,
          ),
          Text(
            'غيّر التصنيف أو جرّب كلمة بحث أخرى.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
          const SizedBox(
            height: 16,
          ),
          OutlinedButton.icon(
            onPressed: () {
              setState(() {
                _filter = 'الكل';
                _search.clear();
              });
            },
            icon: const Icon(
              Icons.refresh_rounded,
              size: 17,
            ),
            label: const Text(
              'عرض الكل',
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: colors.primary,
              side: BorderSide(
                color: colors.primary,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                  13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // Details
  // ============================================================

  void _openDetails(
    Map<String, dynamic> row,
  ) {
    final allImages = <String>[];

    final firstImage = row['_image']?.toString().trim() ?? '';

    if (firstImage.isNotEmpty && firstImage != 'null') {
      allImages.add(
        firstImage,
      );
    }

    final images = _extractImages(
      row['images'],
    );

    for (final image in images) {
      if (!allImages.contains(image)) {
        allImages.add(image);
      }
    }

    final owner = row['users'] is Map
        ? Map<String, dynamic>.from(
            row['users'] as Map,
          )
        : <String, dynamic>{};

    final ownerName = row['_owner']?.toString().trim() ??
        owner['name']?.toString().trim() ??
        '';

    final ownerPhone = row['phone']?.toString().trim() ??
        owner['phone']?.toString().trim() ??
        '';

    final ownerWhatsapp = row['whatsapp']?.toString().trim() ??
        owner['whatsapp']?.toString().trim() ??
        '';

    final detailsOffer = <String, dynamic>{
      ...row,

      // Community = symbolic_sale
      'listing_type': 'symbolic_sale',

      'images': allImages.toSet().toList(),

      'owner_name': ownerName,

      'phone': ownerPhone,

      'whatsapp': ownerWhatsapp,
    };

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CommunityOfferDetailsPage(
          offer: detailsOffer,
        ),
      ),
    );
  }
}

// ============================================================================
// OFFER CARD
// ============================================================================

class _OfferCard extends StatelessWidget {
  final Map<String, dynamic> row;
  final VoidCallback onTap;

  const _OfferCard({
    required this.row,
    required this.onTap,
  });

  // ============================================================
  // Helpers
  // ============================================================

  double _price() {
    final value = row['_price'] ?? row['price'];

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
          value?.toString() ?? '',
        ) ??
        0.0;
  }

  String _formatPrice() {
    final price = _price();

    if (price == price.roundToDouble()) {
      return '${price.toStringAsFixed(0)} جنيه';
    }

    return '${price.toStringAsFixed(2)} جنيه';
  }

  String _categoryArabic() {
    final nested = row['community_categories'];

    if (nested is Map) {
      final name = nested['name_ar']?.toString().trim() ?? '';

      if (name.isNotEmpty) {
        return name;
      }
    }

    final direct = row['category_name_ar']?.toString().trim() ?? '';

    if (direct.isNotEmpty) {
      return direct;
    }

    final slug = row['category']?.toString().trim().toLowerCase() ?? '';

    switch (slug) {
      case 'clothing':
        return 'ملابس';

      case 'furniture':
        return 'أثاث';

      case 'electronics':
        return 'إلكترونيات';

      case 'mobile_phones':
        return 'موبايلات';

      case 'home_appliances':
        return 'أجهزة منزلية';

      case 'shoes':
        return 'أحذية';

      case 'bags':
        return 'شنط';

      case 'books':
        return 'كتب';

      case 'toys':
        return 'ألعاب';

      case 'kids':
        return 'أطفال';

      case 'home_items':
        return 'أدوات منزلية';

      case 'tools':
        return 'أدوات';

      case 'sports':
        return 'رياضة';

      case 'car_accessories':
        return 'إكسسوارات سيارات';

      case 'collectibles':
        return 'مقتنيات';

      case 'musical_instruments':
        return 'آلات موسيقية';

      case 'office_supplies':
        return 'مستلزمات مكتبية';

      default:
        return 'أخرى';
    }
  }

  String _conditionLabel() {
    final value = row['item_condition']?.toString().trim() ?? 'good';

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

  String? _location() {
    final value = row['pickup_location']?.toString().trim() ?? '';

    return value.isEmpty ? null : value;
  }

  String _owner() {
    final owner = row['_owner']?.toString().trim() ?? '';

    if (owner.isNotEmpty) {
      return owner;
    }

    return 'مستخدم من المجتمع';
  }

  String? _expiryLabel() {
    final raw = row['expires_at'] ?? row['expiry_time'];

    if (raw == null) {
      return null;
    }

    final expiry = DateTime.tryParse(
      raw.toString(),
    );

    if (expiry == null) {
      return null;
    }

    final remaining = expiry.toUtc().difference(
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
  // Images
  // ============================================================

  String? _image() {
    final direct = row['_image']?.toString().trim() ?? '';

    if (direct.isNotEmpty && direct != 'null') {
      return direct;
    }

    final image = row['image']?.toString().trim() ?? '';

    if (image.isNotEmpty && image != 'null') {
      return image;
    }

    final images = row['images'];

    if (images is List) {
      for (final item in images) {
        final value = item?.toString().trim() ?? '';

        if (value.isNotEmpty && value != 'null') {
          return value;
        }
      }
    }

    return null;
  }

  // ============================================================
  // Build
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    final colors = Theme.of(context).colorScheme;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    final image = _image();

    final title = row['title']?.toString().trim() ?? '';

    final remaining = row['remaining_quantity'];

    final quantity = row['quantity'];

    final location = _location();

    final expiry = _expiryLabel();

    return Material(
      color: isDark
          ? const Color(
              0xFF1F1F1F,
            )
          : Colors.white,
      borderRadius: BorderRadius.circular(
        22,
      ),
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ----------------------------------------------------
            // Image
            // ----------------------------------------------------

            SizedBox(
              height: 175,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (image == null || image.isEmpty)
                    Container(
                      color: colors.primary.withAlpha(
                        18,
                      ),
                      child: Icon(
                        Icons.shopping_bag_rounded,
                        color: colors.primary,
                        size: 52,
                      ),
                    )
                  else
                    Image.network(
                      image,
                      fit: BoxFit.cover,
                      errorBuilder: (
                        _,
                        __,
                        ___,
                      ) {
                        return Container(
                          color: colors.primary.withAlpha(
                            18,
                          ),
                          child: Icon(
                            Icons.shopping_bag_rounded,
                            color: colors.primary,
                            size: 52,
                          ),
                        );
                      },
                      loadingBuilder: (
                        context,
                        child,
                        progress,
                      ) {
                        if (progress == null) {
                          return child;
                        }

                        return Container(
                          color: colors.primary.withAlpha(
                            10,
                          ),
                          alignment: Alignment.center,
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colors.primary,
                            ),
                          ),
                        );
                      },
                    ),

                  // ------------------------------------------------
                  // Person badge
                  // ------------------------------------------------

                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(
                                0xEE1F1F1F,
                              )
                            : const Color(
                                0xEEFFFFFF,
                              ),
                        borderRadius: BorderRadius.circular(
                          12,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.person_outline_rounded,
                            size: 14,
                            color: colors.primary,
                          ),
                          const SizedBox(
                            width: 4,
                          ),
                          Text(
                            'أشخاص',
                            style: TextStyle(
                              color: colors.primary,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ------------------------------------------------
                  // Price
                  // ------------------------------------------------

                  Positioned(
                    bottom: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: colors.primary,
                        borderRadius: BorderRadius.circular(
                          12,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(
                              35,
                            ),
                            blurRadius: 8,
                            offset: const Offset(
                              0,
                              3,
                            ),
                          ),
                        ],
                      ),
                      child: Text(
                        _formatPrice(),
                        style: TextStyle(
                          color: colors.onPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ------------------------------------------------------
            // Content
            // ------------------------------------------------------

            Padding(
              padding: const EdgeInsets.fromLTRB(
                15,
                13,
                15,
                15,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          title.isNotEmpty ? title : 'عرض متاح',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.onSurface,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            height: 1.25,
                          ),
                        ),
                      ),
                      const SizedBox(
                        width: 8,
                      ),
                      Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 17,
                        color: colors.primary,
                      ),
                    ],
                  ),

                  const SizedBox(
                    height: 7,
                  ),

                  // ------------------------------------------------
                  // Owner
                  // ------------------------------------------------

                  Row(
                    children: [
                      Icon(
                        Icons.person_outline_rounded,
                        size: 14,
                        color: colors.onSurfaceVariant,
                      ),
                      const SizedBox(
                        width: 4,
                      ),
                      Expanded(
                        child: Text(
                          _owner(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.onSurfaceVariant,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
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
                        _categoryArabic(),
                        colors.primary.withAlpha(
                          20,
                        ),
                        colors.primary,
                      ),
                      _tag(
                        _conditionLabel(),
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
                    height: 9,
                  ),

                  // ------------------------------------------------
                  // Quantity + Location
                  // ------------------------------------------------

                  Row(
                    children: [
                      if (remaining is num || quantity != null)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.inventory_2_outlined,
                              size: 14,
                              color: colors.onSurfaceVariant,
                            ),
                            const SizedBox(
                              width: 4,
                            ),
                            Text(
                              remaining is num
                                  ? 'المتاح: $remaining'
                                  : 'الكمية: $quantity',
                              style: TextStyle(
                                color: colors.onSurfaceVariant,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      if (remaining is num || quantity != null)
                        const SizedBox(
                          width: 10,
                        ),
                      if (location != null)
                        Expanded(
                          child: Row(
                            children: [
                              Icon(
                                Icons.location_on_outlined,
                                size: 14,
                                color: colors.onSurfaceVariant,
                              ),
                              const SizedBox(
                                width: 3,
                              ),
                              Expanded(
                                child: Text(
                                  location,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: colors.onSurfaceVariant,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
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
        borderRadius: BorderRadius.circular(
          20,
        ),
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
}
