// lib/features/institutions/presentation/pages/institution_offers_page.dart

import 'package:flutter/material.dart';
import 'dart:math' as math;

import 'package:loqma/core/constants/egypt_locations.dart';
import '../../data/repositories/institution_offers_repository.dart';
import '../../domain/entities/institution_offer.dart';
import '../../domain/institution_offer_policy.dart';
import 'institution_offer_details_page.dart';

enum _OfferFilter { active, expired, soldOut }
enum _OfferSection { symbolicSale, institutionSurplus }

class InstitutionOffersPage extends StatefulWidget {
  final InstitutionOffersRepository? repository;
  final List<InstitutionOffer> initialOffers;

  const InstitutionOffersPage({
    super.key,
    this.repository,
    required this.initialOffers,
  });

  @override
  State<InstitutionOffersPage> createState() => _InstitutionOffersPageState();
}

class _InstitutionOffersPageState extends State<InstitutionOffersPage> {
  late final InstitutionOffersRepository _repository;
  late Future<List<InstitutionOffer>> _future;
  String _query = '';
  String? _selectedGovernorate;
  String? _selectedInstitutionId;
  double? _userLatitude;
  double? _userLongitude;
  double _radiusKm = 25;
  _OfferFilter _filter = _OfferFilter.active;
  _OfferSection _section = _OfferSection.symbolicSale;

  // ─── ألوان هوية Khedma ───
  static const Color _primary = Color(0xFF0B7650);
  static const Color _primaryLight = Color(0xFF25B77C);
  static const Color _primaryDark = Color(0xFF054D34);
  static const Color _cream = Color(0xFFF7FAF8);
  static const Color _ink = Color(0xFF0F2E23);
  static const Color _inkSoft = Color(0xFF61756D);
  static const Color _gold = Color(0xFFD4A843);
  static const Color _orange = Color(0xFFE28B00);
  static const Color _blue = Color(0xFF3679C8);
  static const Color _purple = Color(0xFF7B5EC7);
  static const Color _red = Color(0xFFDC4C4C);

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? InstitutionOffersRepository();
    _future = _repository.listAvailableOffers();
    _loadUserGovernorate();
  }

  Future<void> _loadUserGovernorate() async {
    final governorate = await _repository.getCurrentUserGovernorate();
    final location = await _repository.getCurrentUserLocation();
    if (!mounted) return;
    setState(() {
      if (governorate != null && EgyptLocations.names.contains(governorate)) {
        _selectedGovernorate = governorate;
      }
      _userLatitude = location?.latitude;
      _userLongitude = location?.longitude;
    });
  }

  Future<void> _reload() async {
    final future = _repository.listAvailableOffers();
    if (mounted) setState(() => _future = future);
    try {
      await future;
    } catch (_) {}
  }

  // ═══════════════════════════════════════════════════════════
  // تصنيف العرض
  // ═══════════════════════════════════════════════════════════
  _OfferFilter _offerCategory(InstitutionOffer offer) {
    if (offer.remainingQuantity <= 0) return _OfferFilter.soldOut;
    if (!offer.isActive) return _OfferFilter.expired;
    // لو العرض منتهي الصلاحية
    if (offer.expiresAt.isBefore(DateTime.now())) {
      return _OfferFilter.expired;
    }
    return _OfferFilter.active;
  }

  List<InstitutionOffer> _filteredOffers(List<InstitutionOffer> offers) {
    final query = _query.trim().toLowerCase();

    return offers.where((offer) {
      if (!_matchesSection(offer)) return false;
      if (!_matchesLocationFilters(offer)) return false;

      // ── فلتر الحالة
      final category = _offerCategory(offer);
      if (category != _filter) return false;

      // ── فلتر البحث
      if (query.isEmpty) return true;
      return offer.title.toLowerCase().contains(query) ||
          offer.institutionName.toLowerCase().contains(query);
      }).toList(growable: false);
  }

  bool _matchesSection(InstitutionOffer offer) {
    final surplus = InstitutionOfferPolicy.isSurplus(offer.institutionType);
    return _section == _OfferSection.institutionSurplus ? surplus : !surplus;
  }

  String? _offerGovernorate(InstitutionOffer offer) {
    final explicit = offer.institutionGovernorate?.trim();
    if (explicit != null && explicit.isNotEmpty) return explicit;

    final city = offer.institutionCity?.trim();
    if (city == null || city.isEmpty) return null;
    for (final entry in EgyptLocations.governorates.entries) {
      if (entry.value.any((item) => item == city)) return entry.key;
    }
    return null;
  }

  bool _matchesLocationFilters(InstitutionOffer offer) {
    if (_selectedGovernorate != null &&
        _offerGovernorate(offer) != _selectedGovernorate) {
      return false;
    }
    if (_selectedInstitutionId != null &&
        offer.institutionId != _selectedInstitutionId) {
      return false;
    }
    if (_radiusKm > 0 &&
        _userLatitude != null &&
        _userLongitude != null &&
        offer.latitude != null &&
        offer.longitude != null &&
        _distanceKm(
              _userLatitude!,
              _userLongitude!,
              offer.latitude!,
              offer.longitude!,
            ) >
            _radiusKm) {
      return false;
    }
    return true;
  }

  double _distanceKm(double lat1, double lon1, double lat2, double lon2) {
    const earthRadius = 6371.0;
    final dLat = (lat2 - lat1) * math.pi / 180;
    final dLon = (lon2 - lon1) * math.pi / 180;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180) *
            math.cos(lat2 * math.pi / 180) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return earthRadius * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  bool _matchesLocationFiltersWithoutInstitution(InstitutionOffer offer) {
    return _offerGovernorate(offer) == _selectedGovernorate;
  }

  List<InstitutionOffer> _locationFilteredOffers(
    List<InstitutionOffer> offers,
  ) {
    return offers.where(_matchesLocationFilters).toList(growable: false);
  }

  int _countByFilter(List<InstitutionOffer> offers, _OfferFilter filter) {
    return offers.where((o) => _offerCategory(o) == filter).length;
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _cream,
        body: FutureBuilder<List<InstitutionOffer>>(
          future: _future,
          builder: (context, snapshot) {
            final allOffers = (snapshot.data ?? const <InstitutionOffer>[])
                .where((offer) => InstitutionOfferPolicy.canPublishOffers(
                      offer.institutionType,
                    ))
                .toList(growable: false);
            final sectionOffers = allOffers.where(_matchesSection).toList(growable: false);
            final locationOffers = _locationFilteredOffers(sectionOffers);
            final activeCount = _countByFilter(locationOffers, _OfferFilter.active);
            final expiredCount =
                _countByFilter(locationOffers, _OfferFilter.expired);
            final soldOutCount =
                _countByFilter(locationOffers, _OfferFilter.soldOut);

            return CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // ═══════════════════════════════════════════════
                // SLIVER APP BAR
                // ═══════════════════════════════════════════════
                SliverAppBar(
                  expandedHeight: 200,
                  pinned: true,
                  stretch: true,
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  scrolledUnderElevation: 0,
                  leading: IconButton(
                    onPressed: () => Navigator.maybePop(context),
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 20,
                    ),
                  ),
                  actions: [
                    IconButton(
                      tooltip: 'تحديث',
                      onPressed: _reload,
                      icon: const Icon(Icons.refresh_rounded),
                    ),
                    const SizedBox(width: 8),
                  ],
                  flexibleSpace: FlexibleSpaceBar(
                    stretchModes: const [StretchMode.zoomBackground],
                    background: _buildHeroHeader(allOffers.length, activeCount),
                  ),
                ),

                // ═══════════════════════════════════════════════
                // SEARCH + FILTERS
                // ═══════════════════════════════════════════════
                SliverToBoxAdapter(
                  child: Transform.translate(
                    offset: const Offset(0, -20),
                    child: Container(
                      decoration: const BoxDecoration(
                        color: _cream,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(28),
                        ),
                      ),
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                      child: Column(
                        children: [
                          _buildSearchField(),
                          const SizedBox(height: 14),
                          _buildSectionSelector(),
                          const SizedBox(height: 12),
                          _buildFilters(
                            activeCount: activeCount,
                            expiredCount: expiredCount,
                            soldOutCount: soldOutCount,
                          ),
                          const SizedBox(height: 12),
                          _buildLocationFilters(allOffers),
                        ],
                      ),
                    ),
                  ),
                ),

                // ═══════════════════════════════════════════════
                // CONTENT
                // ═══════════════════════════════════════════════
                if (snapshot.connectionState == ConnectionState.waiting)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: CircularProgressIndicator(color: _primary),
                    ),
                  )
                else if (snapshot.hasError)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _buildError(),
                  )
                else
                  _buildOffersList(allOffers),

                const SliverToBoxAdapter(child: SizedBox(height: 40)),
              ],
            );
          },
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // HERO HEADER
  // ═══════════════════════════════════════════════════════════
  Widget _buildHeroHeader(int total, int active) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_primaryDark, _primary, _primaryLight],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
      ),
      child: Stack(
        children: [
          // ── Decorative circles
          Positioned(
            top: -50,
            left: -40,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          Positioned(
            bottom: -60,
            right: -30,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.04),
              ),
            ),
          ),
          Positioned(
            top: 30,
            right: 20,
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.15),
                          ),
                        ),
                        child: const Icon(
                          Icons.local_offer_rounded,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'عروض المؤسسات',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                height: 1.1,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              _section == _OfferSection.institutionSurplus
                                  ? 'فائض طازج من الفنادق وقاعات الأفراح'
                                  : 'عروض بقالة ومخبوزات ولحوم بسعر رمزي',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // ── Stats pills
                  Row(
                    children: [
                      _heroStatPill(
                        icon: Icons.inventory_2_rounded,
                        label: '$total عرض',
                        color: _gold,
                      ),
                      const SizedBox(width: 8),
                      _heroStatPill(
                        icon: Icons.check_circle_rounded,
                        label: '$active نشط',
                        color: _primaryLight,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroStatPill({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // SEARCH FIELD
  // ═══════════════════════════════════════════════════════════
  Widget _buildSearchField() {
    return Container(
      height: 54,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFEEF3F0)),
        boxShadow: [
          BoxShadow(
            color: _ink.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: TextField(
        onChanged: (value) => setState(() => _query = value),
        textInputAction: TextInputAction.search,
        style: const TextStyle(
          color: _ink,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          hintText: 'ابحث باسم العرض أو المؤسسة...',
          hintStyle: TextStyle(
            color: _inkSoft.withValues(alpha: 0.6),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
          prefixIcon:
              const Icon(Icons.search_rounded, color: _primary, size: 22),
          suffixIcon: _query.isEmpty
              ? null
              : IconButton(
                  onPressed: () => setState(() => _query = ''),
                  icon: const Icon(Icons.close_rounded, size: 20),
                ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 18),
        ),
      ),
    );
  }

  Widget _buildLocationFilters(List<InstitutionOffer> allOffers) {
    final institutionsSource = _selectedGovernorate == null
        ? allOffers
        : allOffers.where(_matchesLocationFiltersWithoutInstitution);
    final institutions = <String, String>{};
    for (final offer in institutionsSource) {
      if (offer.institutionId.trim().isNotEmpty) {
        institutions[offer.institutionId] = offer.institutionName;
      }
    }
    final institutionItems = institutions.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    final selectedInstitution = institutionItems.any(
      (entry) => entry.key == _selectedInstitutionId,
    )
        ? _selectedInstitutionId
        : null;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildDropdown<String>(
                value: EgyptLocations.names.contains(_selectedGovernorate)
                    ? _selectedGovernorate
                    : null,
                hint: 'كل المحافظات',
                icon: Icons.location_on_outlined,
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('كل المحافظات'),
                  ),
                  ...EgyptLocations.names.map(
                    (name) => DropdownMenuItem<String>(
                      value: name,
                      child: Text(name, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ],
                onChanged: (value) => setState(() {
                  _selectedGovernorate = value;
                  _selectedInstitutionId = null;
                }),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildDropdown<String>(
                value: selectedInstitution,
                hint: _selectedGovernorate == null
                    ? 'كل المؤسسات'
                    : 'كل مؤسسات المحافظة',
                icon: Icons.storefront_outlined,
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('كل المؤسسات'),
                  ),
                  ...institutionItems.map(
                    (entry) => DropdownMenuItem<String>(
                      value: entry.key,
                      child: Text(
                        entry.value,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
                onChanged: institutionItems.isEmpty
                    ? null
                    : (value) => setState(
                          () => _selectedInstitutionId = value,
                        ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Padding(
                padding: EdgeInsetsDirectional.only(end: 4),
                child: Text(
                  'النطاق:',
                  style: TextStyle(
                    color: _inkSoft,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              for (final radius in <double>[5, 15, 25, 50, 0])
                ChoiceChip(
                  label: Text(radius == 0 ? 'كل المسافات' : '${radius.toInt()} كم'),
                  selected: _radiusKm == radius,
                  onSelected: (_) => setState(() => _radiusKm = radius),
                  selectedColor: _primary.withValues(alpha: 0.16),
                  labelStyle: TextStyle(
                    color: _radiusKm == radius ? _primaryDark : _inkSoft,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                  side: BorderSide(
                    color: _radiusKm == radius ? _primary : const Color(0xFFE2EAE5),
                  ),
                ),
            ],
          ),
        ),
        if (_selectedGovernorate != null || _selectedInstitutionId != null)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => setState(() {
                _selectedGovernorate = null;
                _selectedInstitutionId = null;
              }),
              icon: const Icon(Icons.clear_all_rounded, size: 17),
              label: const Text('مسح فلاتر المكان'),
              style: TextButton.styleFrom(
                foregroundColor: _primary,
                padding: const EdgeInsets.symmetric(horizontal: 4),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDropdown<T>({
    required T? value,
    required String hint,
    required IconData icon,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?>? onChanged,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      isExpanded: true,
      icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
      onChanged: onChanged,
      items: items,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: _primary, size: 19),
        hintText: hint,
        hintStyle: const TextStyle(
          color: _inkSoft,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFEEF3F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFEEF3F0)),
        ),
      ),
      style: const TextStyle(
        color: _ink,
        fontSize: 11,
        fontWeight: FontWeight.w800,
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // FILTERS
  // ═══════════════════════════════════════════════════════════
  Widget _buildSectionSelector() {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F0EC),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildSectionTab(
              section: _OfferSection.symbolicSale,
              label: 'شراء رمزي',
              subtitle: 'بقالة • سوبر ماركت • مخبز • جزارة',
              icon: Icons.shopping_basket_rounded,
            ),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: _buildSectionTab(
              section: _OfferSection.institutionSurplus,
              label: 'فائض مؤسسات',
              subtitle: 'فنادق • قاعات أفراح',
              icon: Icons.volunteer_activism_rounded,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTab({
    required _OfferSection section,
    required String label,
    required String subtitle,
    required IconData icon,
  }) {
    final selected = _section == section;
    return InkWell(
      onTap: () => setState(() {
        _section = section;
        _selectedInstitutionId = null;
        _filter = _OfferFilter.active;
      }),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: selected
              ? const [BoxShadow(color: Color(0x16000000), blurRadius: 8)]
              : null,
        ),
        child: Row(
          children: [
            Icon(icon, size: 21, color: selected ? _primary : _inkSoft),
            const SizedBox(width: 7),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(color: selected ? _ink : _inkSoft, fontSize: 11, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 2),
                  Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: selected ? _primary : _inkSoft, fontSize: 8.5, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters({
    required int activeCount,
    required int expiredCount,
    required int soldOutCount,
  }) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFEEF3F0)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildFilterTab(
              filter: _OfferFilter.active,
              label: 'نشطة',
              icon: Icons.check_circle_rounded,
              count: activeCount,
              color: _primary,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _buildFilterTab(
              filter: _OfferFilter.expired,
              label: 'منتهية',
              icon: Icons.timer_off_rounded,
              count: expiredCount,
              color: _orange,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _buildFilterTab(
              filter: _OfferFilter.soldOut,
              label: 'خلصت',
              icon: Icons.inventory_2_rounded,
              count: soldOutCount,
              color: _red,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTab({
    required _OfferFilter filter,
    required String label,
    required IconData icon,
    required int count,
    required Color color,
  }) {
    final selected = _filter == filter;

    return GestureDetector(
      onTap: () => setState(() => _filter = filter),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          gradient: selected
              ? LinearGradient(
                  colors: [color, color.withValues(alpha: 0.75)],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                )
              : null,
          color: selected ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.3),
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
              color: selected ? Colors.white : color,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected ? Colors.white : _ink,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 1,
                ),
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white.withValues(alpha: 0.25)
                      : color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    color: selected ? Colors.white : color,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // OFFERS LIST
  // ═══════════════════════════════════════════════════════════
  Widget _buildOffersList(List<InstitutionOffer> allOffers) {
    final offers = _filteredOffers(allOffers);

    if (offers.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: _buildEmpty(),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      sliver: SliverList.builder(
        itemCount: offers.length,
        itemBuilder: (context, index) {
          final offer = offers[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _InstitutionOfferCard(
              offer: offer,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => InstitutionOfferDetailsPage(
                    offer: offer,
                    repository: _repository,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // ERROR / EMPTY
  // ═══════════════════════════════════════════════════════════
  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 90,
              height: 90,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _red.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.cloud_off_rounded,
                color: _red,
                size: 40,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'تعذر تحميل العروض',
              style: TextStyle(
                color: _ink,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'تأكد من اتصال الإنترنت وحاول مرة أخرى',
              textAlign: TextAlign.center,
              style: TextStyle(color: _inkSoft, fontSize: 13),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _reload,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text(
                'إعادة المحاولة',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: _primary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 12,
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

  Widget _buildEmpty() {
    final filterInfo = _filterLabel();

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 120,
              height: 120,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    filterInfo.color.withValues(alpha: 0.1),
                    filterInfo.color.withValues(alpha: 0.04),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: Container(
                width: 84,
                height: 84,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: filterInfo.color.withValues(alpha: 0.15),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Icon(
                  filterInfo.icon,
                  size: 40,
                  color: filterInfo.color,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _query.isNotEmpty
                  ? 'لا توجد نتائج مطابقة'
                  : filterInfo.emptyTitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _ink,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _query.isNotEmpty
                  ? 'جرّب البحث باسم مختلف'
                  : filterInfo.emptySubtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _inkSoft,
                fontSize: 13,
                height: 1.6,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  ({String emptyTitle, String emptySubtitle, Color color, IconData icon})
      _filterLabel() {
    switch (_filter) {
      case _OfferFilter.active:
        return (
          emptyTitle: 'مفيش عروض نشطة',
          emptySubtitle: 'لما تضيف عرض جديد هيظهر هنا',
          color: _primary,
          icon: Icons.inventory_2_outlined,
        );
      case _OfferFilter.expired:
        return (
          emptyTitle: 'مفيش عروض منتهية',
          emptySubtitle: 'كل عروضك لسه شغالة',
          color: _orange,
          icon: Icons.timer_off_rounded,
        );
      case _OfferFilter.soldOut:
        return (
          emptyTitle: 'مفيش عروض مكتملة',
          emptySubtitle: 'لما الكمية تخلص، العرض هيظهر هنا',
          color: _red,
          icon: Icons.shopping_bag_outlined,
        );
    }
  }
}

// ═══════════════════════════════════════════════════════════
// INSTITUTION OFFER CARD
// ═══════════════════════════════════════════════════════════
class _InstitutionOfferCard extends StatefulWidget {
  final InstitutionOffer offer;
  final VoidCallback onTap;

  const _InstitutionOfferCard({
    required this.offer,
    required this.onTap,
  });

  @override
  State<_InstitutionOfferCard> createState() => _InstitutionOfferCardState();
}

class _InstitutionOfferCardState extends State<_InstitutionOfferCard> {
  late final PageController _pageController;
  int _currentImage = 0;

  static const Color _primary = Color(0xFF0B7650);
  static const Color _primaryLight = Color(0xFF25B77C);
  static const Color _ink = Color(0xFF0F2E23);
  static const Color _inkSoft = Color(0xFF61756D);
  static const Color _gold = Color(0xFFD4A843);
  static const Color _orange = Color(0xFFE28B00);
  static const Color _red = Color(0xFFDC4C4C);
  static const Color _blue = Color(0xFF3679C8);

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  List<String> get _images {
    final values = <String>[];
    for (final value in widget.offer.images) {
      final url = value.trim();
      if (url.isNotEmpty && !values.contains(url)) values.add(url);
    }
    final first = widget.offer.firstImage?.trim();
    if (values.isEmpty && first != null && first.isNotEmpty) values.add(first);
    return values;
  }

  bool get _hasDiscount {
    final o = widget.offer;
    return o.originalPrice != null && o.originalPrice! > o.symbolicPrice;
  }

  bool get _isActive =>
      widget.offer.isActive &&
      widget.offer.remainingQuantity > 0 &&
      widget.offer.expiresAt.isAfter(DateTime.now());

  bool get _isSoldOut => widget.offer.remainingQuantity <= 0;

  String get _statusLabel {
    if (_isSoldOut) return 'خلصت الكمية';
    if (!_isActive) return 'منتهي';
    return 'نشط';
  }

  Color get _statusColor {
    if (_isSoldOut) return _red;
    if (!_isActive) return _orange;
    return _primary;
  }

  IconData get _statusIcon {
    if (_isSoldOut) return Icons.inventory_2_rounded;
    if (!_isActive) return Icons.timer_off_rounded;
    return Icons.check_circle_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final offer = widget.offer;
    final images = _images;
    final location = [
      offer.institutionGovernorate,
      offer.institutionCity,
    ].where((value) => value != null && value.trim().isNotEmpty).join('، ');

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: widget.onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFEEF3F0)),
            boxShadow: [
              BoxShadow(
                color: _ink.withValues(alpha: 0.07),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 142,
                height: 190,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (images.isEmpty)
                        _imageFallback()
                      else
                        PageView.builder(
                          controller: _pageController,
                          itemCount: images.length,
                          onPageChanged: (i) => setState(() => _currentImage = i),
                          itemBuilder: (_, i) => Image.network(
                            images[i],
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _imageFallback(),
                          ),
                        ),
                      Positioned.fill(
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black.withValues(alpha: 0.28),
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.42),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.94),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(_statusIcon, size: 12, color: _statusColor),
                              const SizedBox(width: 3),
                              Text(_statusLabel, style: TextStyle(color: _statusColor, fontSize: 9, fontWeight: FontWeight.w900)),
                            ],
                          ),
                        ),
                      ),
                      if (_hasDiscount)
                        Positioned(
                          bottom: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                            decoration: BoxDecoration(color: _red, borderRadius: BorderRadius.circular(12)),
                            child: Text('${offer.discountPercent!.round()}% خصم', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900)),
                          ),
                        ),
                      if (images.length > 1)
                        Positioned(
                          bottom: 8,
                          left: 8,
                          child: Text('${_currentImage + 1}/${images.length}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              offer.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: _ink, fontSize: 16, fontWeight: FontWeight.w900, height: 1.25),
                            ),
                          ),
                          const SizedBox(width: 5),
                          const Icon(Icons.chevron_left_rounded, color: _primary, size: 20),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        offer.description.trim().isEmpty ? 'عرض متاح من المؤسسة' : offer.description.trim(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: _inkSoft, fontSize: 11.5, height: 1.45),
                      ),
                      const SizedBox(height: 9),
                      _detailLine(Icons.storefront_rounded, offer.institutionName),
                      if (location.isNotEmpty) ...[
                        const SizedBox(height: 5),
                        _detailLine(Icons.location_on_outlined, location),
                      ],
                      if ((offer.pickupLocation ?? '').trim().isNotEmpty) ...[
                        const SizedBox(height: 5),
                        _detailLine(Icons.pin_drop_outlined, offer.pickupLocation!.trim()),
                      ],
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Text('${offer.symbolicPrice.toStringAsFixed(0)} ج.م', style: const TextStyle(color: _primary, fontSize: 18, fontWeight: FontWeight.w900)),
                          if (_hasDiscount) ...[
                            const SizedBox(width: 5),
                            Text('${offer.originalPrice!.toStringAsFixed(0)} ج.م', style: const TextStyle(color: _inkSoft, fontSize: 10, decoration: TextDecoration.lineThrough)),
                          ],
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                            decoration: BoxDecoration(color: offer.remainingQuantity > 0 ? _primary.withValues(alpha: 0.09) : _red.withValues(alpha: 0.09), borderRadius: BorderRadius.circular(10)),
                            child: Text('${offer.remainingQuantity} متبقي', style: TextStyle(color: offer.remainingQuantity > 0 ? _primary : _red, fontSize: 10, fontWeight: FontWeight.w900)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 9),
                      SizedBox(
                        width: double.infinity,
                        height: 34,
                        child: ElevatedButton(
                          onPressed: widget.onTap,
                          style: ElevatedButton.styleFrom(backgroundColor: _primary, foregroundColor: Colors.white, elevation: 0, padding: EdgeInsets.zero, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11))),
                          child: const Text('شاهد التفاصيل', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900)),
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
    );
  }

  Widget _detailLine(IconData icon, String value) {
    return Row(
      children: [
        Icon(icon, color: _primary, size: 14),
        const SizedBox(width: 5),
        Expanded(child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _inkSoft, fontSize: 10.5, fontWeight: FontWeight.w700))),
      ],
    );
  }

  Widget _imageLoading() {
    return Container(
      color: _primary.withValues(alpha: 0.05),
      alignment: Alignment.center,
      child: const SizedBox(
        width: 26,
        height: 26,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          color: _primary,
        ),
      ),
    );
  }

  Widget _imageFallback() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _primary.withValues(alpha: 0.15),
            _primaryLight.withValues(alpha: 0.08),
          ],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.storefront_rounded,
        color: _primary.withValues(alpha: 0.5),
        size: 60,
      ),
    );
  }
}
