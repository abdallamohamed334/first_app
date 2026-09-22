// lib/features/userhome/presentation/pages/user_institution_offers_page.dart

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:loqma/core/services/supabase_service.dart';
import 'package:loqma/features/institutions/domain/entities/institution_offer.dart';
import 'package:loqma/features/institutions/presentation/pages/institution_offer_details_page.dart';
import 'package:loqma/features/notification/presentation/bloc/notification_bloc.dart';
import 'package:loqma/features/notification/presentation/bloc/notification_state.dart';
import 'package:loqma/features/notification/presentation/pages/notifications_page.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:loqma/features/offers/domain/entities/food_offer.dart';
import 'package:loqma/features/offers/domain/entities/food_offer_status.dart';

class UserInstitutionOffersPage extends StatefulWidget {
  final List<FoodOffer>? offers;

  const UserInstitutionOffersPage({super.key, this.offers});

  @override
  State<UserInstitutionOffersPage> createState() =>
      _UserInstitutionOffersPageState();
}

class _UserInstitutionOffersPageState extends State<UserInstitutionOffersPage> {
  List<FoodOffer> _allOffers = [];
  bool _isLoading = true;

  // ───────── نفس هوية التطبيق (Home/Offers Hub) ─────────
  static const Color _bg = Color(0xFF0F0F0F);
  static const Color _card = Color(0xFF1C1C1E);
  static const Color _primaryRed = Color(0xFFE31C25);
  static const Color _textPrimary = Colors.white;
  static const Color _textSecondary = Color(0xFFAAAAAA);
  static const Color _orange = Color(0xFFE28B00);

  @override
  void initState() {
    super.initState();
    _loadOffers();
  }

  void _loadOffers() {
    if (widget.offers != null && widget.offers!.isNotEmpty) {
      // ✅ تصفية: فقط عروض المؤسسات (business_type != restaurant)
      final filtered = widget.offers!
          .where((offer) => offer.businessType.toLowerCase() != 'restaurant')
          .toList();
      setState(() {
        _allOffers = filtered;
        _isLoading = false;
      });
      return;
    }

    _fetchInstitutionOffers();
  }

  Future<void> _fetchInstitutionOffers() async {
    try {
      setState(() => _isLoading = true);

      final client = SupabaseService().client;
      final now = DateTime.now().toUtc().toIso8601String();

      final response = await client
          .from('institution_offers')
          .select('''
            *,
            institutions:institution_id (
              id,
              name,
              institution_type,
              logo_url,
              address,
              phone,
              latitude,
              longitude
            )
          ''')
          .eq('status', 'active')
          .gt('expires_at', now)
          .order('created_at', ascending: false);

      final offers = <FoodOffer>[];

      for (final item in response) {
        final institutionId = item['institution_id']?.toString() ?? '';
        final institutionData = item['institutions'] as Map? ?? {};

        final businessMap = {
          'id': institutionId,
          'name': institutionData['name']?.toString() ?? 'مؤسسة',
          'institution_type':
              institutionData['institution_type']?.toString() ?? 'grocery',
          'logo_url': institutionData['logo_url']?.toString(),
          'address': institutionData['address']?.toString(),
          'phone': institutionData['phone']?.toString(),
          'latitude': institutionData['latitude'] as double?,
          'longitude': institutionData['longitude'] as double?,
          'business_type':
              institutionData['institution_type']?.toString() ?? 'grocery',
        };

        List<String> images = [];
        try {
          final imagesData = item['images'];
          if (imagesData is List) {
            images = List<String>.from(imagesData);
          } else if (imagesData is String && imagesData.isNotEmpty) {
            try {
              final decoded = jsonDecode(imagesData);
              if (decoded is List) {
                images = List<String>.from(decoded);
              }
            } catch (_) {
              images = [imagesData];
            }
          }
        } catch (_) {}

        final offer = FoodOffer(
          id: item['id']?.toString() ?? '',
          title: item['title']?.toString() ?? 'عرض',
          description: item['description']?.toString() ?? '',
          quantity: (item['quantity'] as num?)?.toInt() ?? 0,
          foodType: item['food_type']?.toString() ?? 'مواد غذائية',
          expiryTime: item['expires_at'] != null
              ? DateTime.parse(item['expires_at'].toString())
              : DateTime.now().add(const Duration(days: 7)),
          pickupBefore: item['pickup_before'] != null
              ? DateTime.parse(item['pickup_before'].toString())
              : DateTime.now().add(const Duration(days: 7)),
          pickupLocation: item['pickup_location']?.toString() ?? '',
          latitude:
              (institutionData['latitude'] as num?)?.toDouble() ?? 30.0444,
          longitude:
              (institutionData['longitude'] as num?)?.toDouble() ?? 31.2357,
          image: images.isNotEmpty ? images.first : null,
          status: FoodOfferStatus.fromString(
              item['status']?.toString() ?? 'available'),
          businessId: institutionId,
          charityId: null,
          createdAt: item['created_at'] != null
              ? DateTime.parse(item['created_at'].toString())
              : DateTime.now(),
          updatedAt: item['updated_at'] != null
              ? DateTime.parse(item['updated_at'].toString())
              : DateTime.now(),
          business: businessMap,
          images: images,
          requiresRefrigeration:
              item['requires_refrigeration'] as bool? ?? false,
          isHalal: item['is_halal'] as bool? ?? true,
          isVegetarian: item['is_vegetarian'] as bool? ?? false,
          salePrice: (item['symbolic_price'] as num?)?.toDouble() ?? 0,
          originalPrice: (item['original_price'] as num?)?.toDouble(),
          source: 'institution',
          details: Map<String, dynamic>.from(item),
        );

        offers.add(offer);
      }

      if (mounted) {
        setState(() {
          _allOffers = offers;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading institution offers: $e');
      if (mounted) {
        setState(() {
          _allOffers = [];
          _isLoading = false;
        });
      }
    }
  }

  // ============================================================
  // Build
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final offers = _allOffers;

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
          appBar: _buildAppBar(context),
          body: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: _primaryRed),
                )
              : offers.isEmpty
                  ? _buildEmptyState()
                  : RefreshIndicator(
                      color: _primaryRed,
                      backgroundColor: _card,
                      onRefresh: () async {
                        await _fetchInstitutionOffers();
                      },
                      child: CustomScrollView(
                        physics: const BouncingScrollPhysics(
                          parent: AlwaysScrollableScrollPhysics(),
                        ),
                        slivers: [
                          SliverToBoxAdapter(child: _buildHeroHeader()),
                          SliverToBoxAdapter(child: _buildStatsRow(offers)),
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  final offer = offers[index];
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 14),
                                    child: _InstitutionOfferCard(
                                      offer: offer,
                                      index: index,
                                      onTap: () =>
                                          _navigateToDetails(context, offer),
                                    ),
                                  );
                                },
                                childCount: offers.length,
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

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    final userId = SupabaseService().client.auth.currentUser?.id;

    return AppBar(
      backgroundColor: _bg,
      surfaceTintColor: _bg,
      elevation: 0,
      leading: IconButton(
        onPressed: () => Navigator.of(context).maybePop(),
        icon: const Icon(Icons.arrow_back_rounded, color: _textPrimary),
      ),
      title: const Text(
        'عروض المؤسسات',
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
    );
  }

  // ============================================================
  // Hero Header
  // ============================================================

  Widget _buildHeroHeader() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_primaryRed, Color(0xFF8E0F14)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _primaryRed.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            left: -24,
            bottom: -30,
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '🏪 عروض المؤسسات',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_allOffers.length} عرض متاح',
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
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2)),
                      ),
                      child: const Text(
                        '🏷️ بأسعار رمزية من المؤسسات',
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
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.storefront_rounded,
                  color: Colors.white,
                  size: 30,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // Stats Row
  // ============================================================

  Widget _buildStatsRow(List<FoodOffer> offers) {
    final total = offers.length;
    final urgent = offers.where((o) => o.isUrgent).length;
    final institutions = offers.map((o) => o.businessId).toSet().length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _statChip(
              icon: Icons.storefront_rounded,
              label: 'متاح',
              value: '$total',
              color: _primaryRed,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _statChip(
              icon: Icons.local_fire_department_rounded,
              label: 'عاجل',
              value: '$urgent',
              color: _orange,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _statChip(
              icon: Icons.verified_rounded,
              label: 'مؤسسات',
              value: '$institutions',
              color: const Color(0xFF3679C8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statChip({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 15),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              color: _textSecondary,
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // Empty State
  // ============================================================

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                color: _primaryRed.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.storefront_rounded,
                color: _primaryRed,
                size: 50,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'لا توجد عروض مؤسسات',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _textPrimary,
                fontSize: 19,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'حاليًا لا توجد عروض من المؤسسات\nحاول مرة أخرى لاحقًا',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _textSecondary,
                fontSize: 13.5,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () {
                _fetchInstitutionOffers();
              },
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('تحديث'),
              style: FilledButton.styleFrom(
                backgroundColor: _primaryRed,
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

  // ============================================================
  // ✅ Navigate to Details (مع تحويل الحالة الصح)
  // ============================================================

  void _navigateToDetails(BuildContext context, FoodOffer offer) {
    // ✅ تحويل FoodOfferStatus → InstitutionOffer status string
    final institutionStatus = _foodStatusToInstitutionStatus(offer.status);

    final institutionOffer = InstitutionOffer.fromJson({
      'id': offer.id,
      'title': offer.title,
      'description': offer.description,
      'quantity': offer.quantity,
      'remaining_quantity': offer.quantity,
      'symbolic_price': offer.salePrice,
      'original_price': offer.originalPrice,
      'images': offer.images,
      'pickup_location': offer.pickupLocation,
      'expires_at': offer.expiryTime.toIso8601String(),
      'status': institutionStatus, // ✅ 'active' بدل 'available'
      'created_at': offer.createdAt.toIso8601String(),
      'updated_at': offer.updatedAt.toIso8601String(),
      'institution_id': offer.businessId,
      'institutions': {
        'name': offer.businessName,
        'institution_type': offer.businessType,
        'logo_url': offer.businessLogo,
      },
      'food_type': offer.foodType,
      'is_halal': offer.isHalal,
      'is_vegetarian': offer.isVegetarian,
    });

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => InstitutionOfferDetailsPage(offer: institutionOffer),
      ),
    );
  }

  // ✅ تحويل FoodOfferStatus → status string المتوافق مع InstitutionOffer
  String _foodStatusToInstitutionStatus(FoodOfferStatus status) {
    switch (status) {
      case FoodOfferStatus.available:
        return 'active'; // ← المفتاح: 'active' مش 'available'
      case FoodOfferStatus.reserved:
        return 'reserved';
      case FoodOfferStatus.completed:
        return 'completed';
      case FoodOfferStatus.cancelled:
        return 'cancelled';
      case FoodOfferStatus.expired:
        return 'expired';
    }
  }
}

// ============================================================
// ✅ كارد عرض المؤسسة — دارك موود متطابق مع هوية التطبيق
// + أنيميشن دخول متدرج (stagger) حسب ترتيب الكارت
// ============================================================
class _InstitutionOfferCard extends StatefulWidget {
  final FoodOffer offer;
  final int index;
  final VoidCallback onTap;

  const _InstitutionOfferCard({
    required this.offer,
    required this.index,
    required this.onTap,
  });

  @override
  State<_InstitutionOfferCard> createState() => _InstitutionOfferCardState();
}

class _InstitutionOfferCardState extends State<_InstitutionOfferCard>
    with SingleTickerProviderStateMixin {
  static const Color _card = _UserInstitutionOffersPageState._card;
  static const Color _primaryRed = _UserInstitutionOffersPageState._primaryRed;
  static const Color _textPrimary =
      _UserInstitutionOffersPageState._textPrimary;
  static const Color _textSecondary =
      _UserInstitutionOffersPageState._textSecondary;
  static const Color _orange = _UserInstitutionOffersPageState._orange;

  late AnimationController _controller;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 420),
      vsync: this,
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    // ✅ تأخير بسيط متدرج حسب ترتيب الكارت
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
    final price = widget.offer.salePrice ?? 0;
    final originalPrice = widget.offer.originalPrice;
    final hasDiscount = originalPrice != null && originalPrice > price;
    final discount =
        hasDiscount ? ((1 - price / originalPrice) * 100).round() : 0;
    final image = widget.offer.displayImage;
    final institutionName = widget.offer.businessName;

    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: Material(
          color: _card,
          borderRadius: BorderRadius.circular(20),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: widget.onTap,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.28),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ✅ الصورة (جانبية) + شارة الاستعجال فوقها
                  Stack(
                    children: [
                      SizedBox(
                        width: 128,
                        height: 168,
                        child: image != null && image.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: image,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(
                                  color: _primaryRed.withValues(alpha: 0.08),
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
                                  color: _primaryRed.withValues(alpha: 0.08),
                                  child: const Icon(
                                    Icons.storefront_rounded,
                                    color: _primaryRed,
                                    size: 36,
                                  ),
                                ),
                              )
                            : Container(
                                color: _primaryRed.withValues(alpha: 0.08),
                                child: const Icon(
                                  Icons.storefront_rounded,
                                  color: _primaryRed,
                                  size: 36,
                                ),
                              ),
                      ),
                      if (widget.offer.isUrgent)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _orange,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: _orange.withValues(alpha: 0.4),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Text(
                              'عاجل 🔥',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),

                  // ✅ المحتوى
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // اسم المؤسسة + توثيق
                          Row(
                            children: [
                              const Icon(
                                Icons.store_rounded,
                                size: 13,
                                color: _textSecondary,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  institutionName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: _textSecondary,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const Icon(
                                Icons.verified_rounded,
                                size: 14,
                                color: _primaryRed,
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),

                          // العنوان
                          Text(
                            widget.offer.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 10),

                          // السعر والخصم
                          Row(
                            children: [
                              Text(
                                '${price.toStringAsFixed(0)} ج.م',
                                style: const TextStyle(
                                  color: _primaryRed,
                                  fontSize: 19,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              if (hasDiscount) ...[
                                const SizedBox(width: 6),
                                Text(
                                  '${originalPrice.toStringAsFixed(0)} ج.م',
                                  style: TextStyle(
                                    color:
                                        _textSecondary.withValues(alpha: 0.8),
                                    fontSize: 11.5,
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          if (hasDiscount) ...[
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
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
                          const SizedBox(height: 10),

                          // الكمية والوقت
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _primaryRed.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '📦 ${widget.offer.quantity}',
                                  style: const TextStyle(
                                    color: _primaryRed,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(
                                Icons.schedule_rounded,
                                size: 13,
                                color: _orange,
                              ),
                              const SizedBox(width: 3),
                              Expanded(
                                child: Text(
                                  widget.offer.timeRemaining,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: _orange,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 9),
                              decoration: BoxDecoration(
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
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'احجز الآن',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  SizedBox(width: 4),
                                  Icon(Icons.arrow_back_ios_new_rounded,
                                      color: Colors.white, size: 11),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
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
}
