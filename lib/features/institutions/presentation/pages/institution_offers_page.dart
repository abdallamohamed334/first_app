// lib/features/institutions/presentation/pages/institution_offers_page.dart

import 'package:flutter/material.dart';

import 'package:loqma/core/constants/egypt_locations.dart';
import '../../data/repositories/institution_offers_repository.dart';
import '../../domain/entities/institution_offer.dart';
import 'institution_offer_details_page.dart';

enum _OfferFilter { active, expired, soldOut }

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
  static const Set<String> _allowedInstitutionTypes = {
    'grocery',
    'supermarket',
    'bakery',
    'butcher',
    'meat_shop',
    'poultry_shop',
    'wedding_hall',
    'game_store',
    'hotel',
  };
  late final InstitutionOffersRepository _repository;
  late Future<List<InstitutionOffer>> _future;
  String _query = '';
  String? _selectedGovernorate;
  String? _selectedInstitutionId;
  _OfferFilter _filter = _OfferFilter.active;

  // ─── ألوان هوية وِصلة ───
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
    if (!mounted || governorate == null) return;
    if (EgyptLocations.names.contains(governorate)) {
      setState(() => _selectedGovernorate = governorate);
    }
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
    return true;
  }

  bool _isAllowedInstitutionOffer(InstitutionOffer offer) {
    return _allowedInstitutionTypes.contains(
      offer.institutionType?.trim().toLowerCase(),
    );
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
                .where(_isAllowedInstitutionOffer)
                .toList(growable: false);
            final locationOffers = _locationFilteredOffers(allOffers);
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
                      const Expanded(
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
                              'اختيارات مفيدة بسعر رمزي',
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

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: widget.onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFEEF3F0)),
            boxShadow: [
              BoxShadow(
                color: _ink.withValues(alpha: 0.06),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ═══════════════════════════════════════════
              // Image section
              // ═══════════════════════════════════════════
              SizedBox(
                height: 200,
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
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) return child;
                            return _imageLoading();
                          },
                          errorBuilder: (_, __, ___) => _imageFallback(),
                        ),
                      ),

                    // ── Gradient
                    Positioned.fill(
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.35),
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.5),
                              ],
                              stops: const [0, 0.5, 1],
                            ),
                          ),
                        ),
                      ),
                    ),

                    // ── Status badge (top-right)
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.95),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _statusIcon,
                              size: 13,
                              color: _statusColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _statusLabel,
                              style: TextStyle(
                                color: _statusColor,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // ── Discount badge (top-left)
                    if (_hasDiscount)
                      Positioned(
                        top: 12,
                        left: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [_red, Color(0xFFB83838)],
                              begin: Alignment.topRight,
                              end: Alignment.bottomLeft,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: _red.withValues(alpha: 0.4),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Text(
                            '${offer.discountPercent!.round()}% خصم',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),

                    // ── Image counter (bottom-left)
                    if (images.length > 1)
                      Positioned(
                        bottom: 12,
                        left: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.15),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.photo_library_rounded,
                                color: Colors.white,
                                size: 10,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${_currentImage + 1}/${images.length}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // ── Dots (bottom-center)
                    if (images.length > 1)
                      Positioned(
                        bottom: 16,
                        left: 0,
                        right: 0,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            images.length,
                            (index) => AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: const EdgeInsets.symmetric(
                                horizontal: 2.5,
                              ),
                              width: _currentImage == index ? 20 : 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: _currentImage == index
                                    ? Colors.white
                                    : Colors.white.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // ═══════════════════════════════════════════
              // Details section
              // ═══════════════════════════════════════════
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Title
                    Text(
                      offer.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // ── Institution
                    Row(
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: const Icon(
                            Icons.storefront_rounded,
                            color: _primary,
                            size: 12,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            offer.institutionName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _inkSoft,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (offer.institutionType != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _primary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              const {
                                    'grocery': 'بقالة وسوبر ماركت',
                                    'supermarket': 'بقالة وسوبر ماركت',
                                    'bakery': 'مخبز',
                                    'butcher': 'لحوم',
                                    'meat_shop': 'لحوم',
                                    'poultry_shop': 'دواجن',
                                    'hotel': 'فندق',
                                    'wedding_hall': 'قاعة أفراح',
                                    'game_store': 'متجر ألعاب',
                                  }[offer.institutionType!.trim().toLowerCase()] ??
                                  offer.institutionType!,
                              style: const TextStyle(
                                color: _primary,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 14),
                    Divider(
                      height: 1,
                      color: const Color(0xFFEEF3F0),
                    ),
                    const SizedBox(height: 14),

                    // ── Price + Quantity
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // ── Price
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(5),
                                    decoration: BoxDecoration(
                                      color: _gold.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(7),
                                    ),
                                    child: const Icon(
                                      Icons.local_offer_rounded,
                                      color: _gold,
                                      size: 11,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Text(
                                    'السعر الرمزي',
                                    style: TextStyle(
                                      color: _inkSoft,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text(
                                    offer.symbolicPrice.toStringAsFixed(0),
                                    style: const TextStyle(
                                      color: _primary,
                                      fontSize: 26,
                                      fontWeight: FontWeight.w900,
                                      height: 1,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Text(
                                    'ج.م',
                                    style: TextStyle(
                                      color: _primary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  if (_hasDiscount) ...[
                                    const SizedBox(width: 8),
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 2),
                                      child: Text(
                                        '${offer.originalPrice!.toStringAsFixed(0)} ج.م',
                                        style: const TextStyle(
                                          color: _inkSoft,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          decoration:
                                              TextDecoration.lineThrough,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),

                        // ── Quantity badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: offer.remainingQuantity > 0
                                ? _primary.withValues(alpha: 0.08)
                                : _red.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: offer.remainingQuantity > 0
                                  ? _primary.withValues(alpha: 0.2)
                                  : _red.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.inventory_2_rounded,
                                color: offer.remainingQuantity > 0
                                    ? _primary
                                    : _red,
                                size: 16,
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${offer.remainingQuantity}',
                                style: TextStyle(
                                  color: offer.remainingQuantity > 0
                                      ? _primary
                                      : _red,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  height: 1,
                                ),
                              ),
                              Text(
                                'متبقي',
                                style: TextStyle(
                                  color: offer.remainingQuantity > 0
                                      ? _primary
                                      : _red,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // ── CTA Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: widget.onTap,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'شاهد التفاصيل',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              width: 24,
                              height: 24,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.arrow_back_rounded,
                                color: Colors.white,
                                size: 14,
                              ),
                            ),
                          ],
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
