// lib/features/userhome/presentation/pages/user_institution_offers_page.dart

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:loqma/features/userhome/presentation/widgets/home_palette.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:loqma/core/services/supabase_service.dart';
import 'package:loqma/core/constants/egypt_locations.dart';
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

  /// `commercial` = grocery/supermarket/bakery/pastry_shop,
  /// `surplus` = hotels/wedding halls.
  final String? institutionSection;

  UserInstitutionOffersPage({
    super.key,
    this.offers,
    this.institutionSection,
  });

  @override
  State<UserInstitutionOffersPage> createState() =>
      _UserInstitutionOffersPageState();
}

class _UserInstitutionOffersPageState extends State<UserInstitutionOffersPage> {
  List<FoodOffer> _allOffers = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  static int _pageSize = 20;
  String? _userGovernorate;
  String? _selectedGovernorate;
  int _offset = 0;
  String _selectedInstitutionType = 'all';

  // ───────── نفس هوية التطبيق (Home/Offers Hub) ─────────
  static Color get _bg => HomePalette.bg;
  static Color get _card => HomePalette.card;
  static Color get _primaryRed => HomePalette.primaryRed;
  static Color get _textPrimary => HomePalette.textPrimary;
  static Color get _textSecondary => HomePalette.textSecondary;
  static Color _orange = Color(0xFFE28B00);

  @override
  void initState() {
    super.initState();
    _loadOffers();
  }

  Future<void> _loadOffers() async {
    await _loadUserGovernorate();
    if (widget.offers != null && widget.offers!.isNotEmpty) {
      // ✅ تصفية: المصدر يحدد عروض المؤسسات، حتى لو كان نوع المؤسسة restaurant.
      final filtered = widget.offers!
          .where((offer) => offer.source == 'institution')
          .toList();
      setState(() {
        _allOffers = filtered;
        _isLoading = false;
        _hasMore = false;
      });
      return;
    }

    await _fetchInstitutionOffers(reset: true);
  }

  Future<void> _loadUserGovernorate() async {
    try {
      final userId = SupabaseService().client.auth.currentUser?.id;
      if (userId == null || userId.isEmpty) return;
      final row = await SupabaseService()
          .client
          .from('users')
          .select('governorate')
          .eq('id', userId)
          .maybeSingle();
      final value = row?['governorate']?.toString().trim();
      if (!mounted || value == null || value.isEmpty) return;
      final normalized = EgyptLocations.names.firstWhere(
        (name) => name == value,
        orElse: () => '',
      );
      if (normalized.isEmpty) return;
      setState(() {
        _userGovernorate = normalized;
        _selectedGovernorate ??= normalized;
      });
    } catch (e) {
      debugPrint('Error loading user governorate: $e');
    }
  }

  Future<void> _fetchInstitutionOffers({bool reset = false}) async {
    try {
      if (reset) {
        setState(() {
          _isLoading = true;
          _isLoadingMore = false;
          _offset = 0;
          _hasMore = true;
          _allOffers = [];
        });
      } else {
        setState(() => _isLoadingMore = true);
      }

      final client = SupabaseService().client;
      final now = DateTime.now().toUtc().toIso8601String();

      var query = client
          .from('institution_offers')
          .select('''
            id, institution_id, title, description, category, quantity,
            remaining_quantity, symbolic_price, original_price, images,
            pickup_location, expires_at, pickup_before, pickup_start, pickup_end,
            status, created_at, updated_at, food_type, is_halal, is_vegetarian,
            food_condition, requires_refrigeration, pickup_notes, contact_phone,
            pickup_time, product_expiry_at, storage_condition,
            product_subcategory, meat_cut, product_weight, product_prepared_at,
            min_booking_quantity, max_booking_quantity, is_bookable, deleted_at,
            marketplace_category_id,
            institutions:institution_id!inner (
              id,
              name,
              institution_type,
              logo_url,
              address,
              phone,
              city,
              latitude,
              longitude
            )
          ''')
          .eq('status', 'active')
          .gt('expires_at', now)
          .filter('deleted_at', 'is', 'null')
          .inFilter(
            'institutions.city',
            EgyptLocations.citiesFor(_selectedGovernorate),
          )
          .order('created_at', ascending: false)
          .range(_offset, _offset + _pageSize - 1);

      // "كل المحافظات" is an explicit choice, not the default.
      if (_selectedGovernorate == null) {
        query = client
            .from('institution_offers')
            .select('''
            id, institution_id, title, description, category, quantity,
            remaining_quantity, symbolic_price, original_price, images,
            pickup_location, expires_at, pickup_before, pickup_start, pickup_end,
            status, created_at, updated_at, food_type, is_halal, is_vegetarian,
            food_condition, requires_refrigeration, pickup_notes, contact_phone,
            pickup_time, product_expiry_at, storage_condition,
            product_subcategory, meat_cut, product_weight, product_prepared_at,
            min_booking_quantity, max_booking_quantity, is_bookable, deleted_at,
            marketplace_category_id,
            institutions:institution_id (
              id, name, institution_type, logo_url, address, phone,
              city, latitude, longitude
            )
          ''')
            .eq('status', 'active')
            .gt('expires_at', now)
            .filter('deleted_at', 'is', 'null')
            .order('created_at', ascending: false)
            .range(_offset, _offset + _pageSize - 1);
      }

      final response = await query;

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
          'city': institutionData['city']?.toString(),
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
              : DateTime.now().add(Duration(days: 7)),
          pickupBefore: item['pickup_before'] != null
              ? DateTime.parse(item['pickup_before'].toString())
              : DateTime.now().add(Duration(days: 7)),
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
          _allOffers = reset ? offers : [..._allOffers, ...offers];
          _isLoading = false;
          _isLoadingMore = false;
          _offset += offers.length;
          _hasMore = offers.length == _pageSize;
        });
      }
    } catch (e) {
      debugPrint('Error loading institution offers: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
          _hasMore = false;
        });
      }
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    await _fetchInstitutionOffers();
  }

  // ============================================================
  // Build
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final offers = _filteredOffers;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Theme(
        data: Theme.of(context).copyWith(
          scaffoldBackgroundColor: _bg,
          colorScheme: Theme.of(context).colorScheme.copyWith(
                primary: _primaryRed,
                surface: _bg,
                onSurface: _textPrimary,
              ),
        ),
        child: Scaffold(
          backgroundColor: _bg,
          appBar: _buildAppBar(context),
          body: _isLoading
              ? Center(
                  child: CircularProgressIndicator(color: _primaryRed),
                )
              : RefreshIndicator(
                  color: _primaryRed,
                  backgroundColor: _card,
                  onRefresh: () async {
                    await _fetchInstitutionOffers(reset: true);
                  },
                  child: CustomScrollView(
                    physics: BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    slivers: [
                      SliverToBoxAdapter(child: _buildHeroHeader()),
                      SliverToBoxAdapter(
                        child: _buildGovernorateSelector(),
                      ),
                      SliverToBoxAdapter(
                        child: _buildInstitutionTypeFilters(),
                      ),
                      SliverToBoxAdapter(child: _buildStatsRow(offers)),
                      if (offers.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: _buildEmptyState(
                            message: 'لا توجد عروض في هذا النوع حاليًا',
                          ),
                        )
                      else
                        SliverPadding(
                          padding: EdgeInsets.fromLTRB(16, 8, 16, 100),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final offer = offers[index];
                                return Padding(
                                  padding: EdgeInsets.only(bottom: 14),
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
                      if (_hasMore && offers.isNotEmpty)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(16, 4, 16, 100),
                            child: OutlinedButton.icon(
                              onPressed: _isLoadingMore ? null : _loadMore,
                              icon: _isLoadingMore
                                  ? SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    )
                                  : Icon(Icons.expand_more_rounded),
                              label: Text(_isLoadingMore
                                  ? 'جاري التحميل...'
                                  : 'تحميل المزيد'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: _textPrimary,
                                side: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.2)),
                              ),
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
        icon: Icon(Icons.arrow_back_rounded, color: _textPrimary),
      ),
      title: Text(
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
                icon: Icon(
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
                    decoration: BoxDecoration(
                      color: _primaryRed,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
        SizedBox(width: 4),
      ],
    );
  }

  // ============================================================
  // Hero Header
  // ============================================================

  Widget _buildHeroHeader() {
    return Container(
      margin: EdgeInsets.fromLTRB(16, 8, 16, 16),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_primaryRed, Color(0xFF8E0F14)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _primaryRed.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: Offset(0, 8),
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
                    Text(
                      '🏪 عروض المؤسسات',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '${_allOffers.length} عرض متاح',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 12),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2)),
                      ),
                      child: Text(
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
                child: Icon(
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
      padding: EdgeInsets.symmetric(horizontal: 16),
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
          SizedBox(width: 10),
          Expanded(
            child: _statChip(
              icon: Icons.local_fire_department_rounded,
              label: 'عاجل',
              value: '$urgent',
              color: _orange,
            ),
          ),
          SizedBox(width: 10),
          Expanded(
            child: _statChip(
              icon: Icons.verified_rounded,
              label: 'مؤسسات',
              value: '$institutions',
              color: Color(0xFF3679C8),
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
      padding: EdgeInsets.symmetric(vertical: 12),
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
          SizedBox(height: 6),
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
            style: TextStyle(
              color: _textSecondary,
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  List<FoodOffer> get _filteredOffers {
    final sectionOffers = _allOffers.where((offer) {
      final type = offer.businessType.trim().toLowerCase();
      final offerCity = offer.business?['city']?.toString().trim();
      final cities = EgyptLocations.citiesFor(_selectedGovernorate);
      if (_selectedGovernorate != null &&
          (offerCity == null ||
              offerCity.isEmpty ||
              !cities.contains(offerCity))) {
        return false;
      }
      if (widget.institutionSection == 'commercial') {
        return {
          'grocery',
          'supermarket',
          'bakery',
          'pastry_shop',
        }.contains(type);
      }
      if (widget.institutionSection == 'surplus') {
        return type == 'hotel' || type == 'wedding_hall';
      }
      return true;
    });

    if (_selectedInstitutionType == 'all')
      return sectionOffers.toList(growable: false);
    return sectionOffers
        .where((offer) => _matchesInstitutionType(
              offer.businessType,
              _selectedInstitutionType,
            ))
        .toList(growable: false);
  }

  Widget _buildGovernorateSelector() {
    final selected = _selectedGovernorate;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 2),
      child: DropdownButtonFormField<String>(
        value: selected,
        isExpanded: true,
        dropdownColor: _card,
        icon: Icon(Icons.keyboard_arrow_down_rounded, color: _textSecondary),
        decoration: InputDecoration(
          labelText: _userGovernorate == null
              ? 'اختار المحافظة'
              : 'المحافظة الحالية: $_userGovernorate',
          labelStyle: TextStyle(color: _textSecondary, fontSize: 11),
          prefixIcon: Icon(Icons.location_on_outlined, color: _primaryRed),
          filled: true,
          fillColor: _card,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          ),
        ),
        style: TextStyle(
            color: _textPrimary, fontSize: 12, fontWeight: FontWeight.w800),
        items: [
          DropdownMenuItem<String>(value: null, child: Text('كل المحافظات')),
          ...EgyptLocations.names.map(
            (name) => DropdownMenuItem<String>(value: name, child: Text(name)),
          ),
        ],
        onChanged: (value) async {
          if (value == _selectedGovernorate) return;
          setState(() => _selectedGovernorate = value);
          if (widget.offers == null || widget.offers!.isEmpty) {
            await _fetchInstitutionOffers(reset: true);
          }
        },
      ),
    );
  }

  bool _matchesInstitutionType(String? rawType, String selected) {
    final type = (rawType ?? '').trim().toLowerCase();
    if (selected == 'hotel') return type == 'hotel';
    if (selected == 'grocery') {
      return type == 'grocery' || type == 'supermarket';
    }
    if (selected == 'other') {
      return type != 'hotel' && type != 'grocery' && type != 'supermarket';
    }
    return true;
  }

  Widget _buildInstitutionTypeFilters() {
    final filters = <(String, String, IconData)>[
      ('all', 'كل المؤسسات', Icons.storefront_rounded),
      ('hotel', 'فنادق', Icons.hotel_rounded),
      ('grocery', 'بقالات', Icons.shopping_cart_rounded),
      ('other', 'مؤسسات أخرى', Icons.business_rounded),
    ];
    return SizedBox(
      height: 58,
      child: ListView.separated(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, __) => SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = filters[index];
          final selected = _selectedInstitutionType == filter.$1;
          return ChoiceChip(
            selected: selected,
            onSelected: (_) => setState(
              () => _selectedInstitutionType = filter.$1,
            ),
            avatar: Icon(
              filter.$3,
              size: 17,
              color: selected ? Colors.white : _textSecondary,
            ),
            label: Text(filter.$2),
            labelStyle: TextStyle(
              color: selected ? Colors.white : _textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
            selectedColor: _primaryRed,
            backgroundColor: _card,
            side: BorderSide(color: Colors.white.withValues(alpha: 0.10)),
          );
        },
      ),
    );
  }

  // ============================================================
  // Empty State
  // ============================================================

  Widget _buildEmptyState({String? message}) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(28),
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
              child: Icon(
                Icons.storefront_rounded,
                color: _primaryRed,
                size: 50,
              ),
            ),
            SizedBox(height: 24),
            Text(
              'لا توجد عروض مؤسسات',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _textPrimary,
                fontSize: 19,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 8),
            Text(
              message ??
                  'حاليًا لا توجد عروض من المؤسسات\nحاول مرة أخرى لاحقًا',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _textSecondary,
                fontSize: 13.5,
                height: 1.5,
              ),
            ),
            SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () {
                _fetchInstitutionOffers();
              },
              icon: Icon(Icons.refresh_rounded, size: 18),
              label: Text('تحديث'),
              style: FilledButton.styleFrom(
                backgroundColor: _primaryRed,
                padding: EdgeInsets.symmetric(
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
      'remaining_quantity':
          (offer.details?['remaining_quantity'] as num?)?.toInt() ??
              offer.quantity,
      'symbolic_price': offer.salePrice,
      'original_price': offer.originalPrice,
      'images': offer.images,
      'pickup_location': offer.pickupLocation,
      'expires_at': offer.expiryTime.toIso8601String(),
      'status': institutionStatus, // ✅ 'active' بدل 'available'
      'is_bookable': offer.details?['is_bookable'] ?? true,
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

  _InstitutionOfferCard({
    required this.offer,
    required this.index,
    required this.onTap,
  });

  @override
  State<_InstitutionOfferCard> createState() => _InstitutionOfferCardState();
}

class _InstitutionOfferCardState extends State<_InstitutionOfferCard>
    with SingleTickerProviderStateMixin {
  static Color get _card => HomePalette.card;
  static Color get _primaryRed => HomePalette.primaryRed;
  static Color get _textPrimary => HomePalette.textPrimary;
  static Color get _textSecondary => HomePalette.textSecondary;
  static Color _orange = _UserInstitutionOffersPageState._orange;

  late AnimationController _controller;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(milliseconds: 420),
      vsync: this,
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: Offset(0, 0.08),
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

  Widget _buildOfferHighlights(FoodOffer offer) {
    final raw = offer.details ?? const <String, dynamic>{};
    final chips = <String>[];
    final isBookable = raw['is_bookable']?.toString().toLowerCase() != 'false';
    final storage = raw['storage_condition']?.toString();
    final storageLabel = switch (storage) {
      'needs_refrigeration' => 'يحتاج تبريد',
      'needs_freezing' => 'يحتاج تجميد',
      'no_cooling' => 'لا يحتاج تبريد',
      _ => (offer.requiresRefrigeration == true ? 'يحتاج تبريد' : null),
    };
    if (storageLabel != null) chips.add(storageLabel);

    final subcategory = raw['product_subcategory']?.toString().trim();
    final meatCut = raw['meat_cut']?.toString().trim();
    final weight = raw['product_weight'];
    if (subcategory != null && subcategory.isNotEmpty) {
      chips.add(subcategory);
    }
    if (meatCut != null && meatCut.isNotEmpty) {
      chips.add(meatCut);
    }
    if (weight is num && weight > 0) {
      chips.add('${weight.toString()} كجم');
    }

    final preparedAt = raw['product_prepared_at']?.toString();
    if (preparedAt != null && preparedAt.isNotEmpty) {
      try {
        final date = DateTime.parse(preparedAt);
        chips.add('تجهيز ${date.day}/${date.month}');
      } catch (_) {}
    }

    final pickupStart = raw['pickup_start']?.toString();
    final pickupEnd = raw['pickup_end']?.toString();
    if (isBookable &&
        pickupStart != null &&
        pickupStart.isNotEmpty &&
        pickupEnd != null &&
        pickupEnd.isNotEmpty) {
      try {
        final start = DateTime.parse(pickupStart);
        final end = DateTime.parse(pickupEnd);
        chips.add('استلام ${start.day}/${start.month}–${end.day}/${end.month}');
      } catch (_) {}
    }

    if (isBookable) {
      final min = raw['min_booking_quantity'] is num
          ? (raw['min_booking_quantity'] as num).toInt()
          : 1;
      final max = raw['max_booking_quantity'] is num
          ? (raw['max_booking_quantity'] as num).toInt()
          : null;
      chips.add(max == null ? 'حد أدنى $min' : 'حجز $min–$max');
    } else {
      chips.add('عرض عادي · مشاهدة فقط');
    }

    final productExpiry = raw['product_expiry_at']?.toString();
    if (productExpiry != null && productExpiry.isNotEmpty) {
      try {
        final date = DateTime.parse(productExpiry);
        chips.add('صلاحية ${date.day}/${date.month}');
      } catch (_) {}
    }

    if (chips.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 24,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 5),
        itemBuilder: (_, index) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
          decoration: BoxDecoration(
            color: _primaryRed.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            chips[index],
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: _textSecondary,
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
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
                    offset: Offset(0, 6),
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
                                  child: Center(
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
                                  child: Icon(
                                    Icons.storefront_rounded,
                                    color: _primaryRed,
                                    size: 36,
                                  ),
                                ),
                              )
                            : Container(
                                color: _primaryRed.withValues(alpha: 0.08),
                                child: Icon(
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
                            padding: EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _orange,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: _orange.withValues(alpha: 0.4),
                                  blurRadius: 6,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Text(
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
                      padding: EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // اسم المؤسسة + توثيق
                          Row(
                            children: [
                              Icon(
                                Icons.store_rounded,
                                size: 13,
                                color: _textSecondary,
                              ),
                              SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  institutionName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: _textSecondary,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.verified_rounded,
                                size: 14,
                                color: _primaryRed,
                              ),
                            ],
                          ),
                          SizedBox(height: 6),

                          // العنوان
                          Text(
                            widget.offer.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: _textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              height: 1.3,
                            ),
                          ),
                          SizedBox(height: 10),

                          // السعر والخصم
                          Row(
                            children: [
                              Text(
                                '${price.toStringAsFixed(0)} ج.م',
                                style: TextStyle(
                                  color: _primaryRed,
                                  fontSize: 19,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              if (hasDiscount) ...[
                                SizedBox(width: 6),
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
                            SizedBox(height: 4),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: _orange.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(7),
                              ),
                              child: Text(
                                'وفر $discount%',
                                style: TextStyle(
                                  color: _orange,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                          SizedBox(height: 10),

                          // الكمية والوقت
                          Row(
                            children: [
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _primaryRed.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '📦 ${widget.offer.quantity}',
                                  style: TextStyle(
                                    color: _primaryRed,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              SizedBox(width: 6),
                              Icon(
                                Icons.schedule_rounded,
                                size: 13,
                                color: _orange,
                              ),
                              SizedBox(width: 3),
                              Expanded(
                                child: Text(
                                  widget.offer.timeRemaining,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: _orange,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          _buildOfferHighlights(widget.offer),
                          SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: Container(
                              padding: EdgeInsets.symmetric(vertical: 9),
                              decoration: BoxDecoration(
                                color: _primaryRed,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                    color: _primaryRed.withValues(alpha: 0.3),
                                    blurRadius: 8,
                                    offset: Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    widget.offer.details?['is_bookable'] ==
                                            false
                                        ? 'عرض التفاصيل'
                                        : 'احجز الآن',
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
