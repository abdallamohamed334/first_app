// lib/features/community/presentation/pages/community_needs_page.dart

import 'package:flutter/material.dart';
import 'package:wasla/core/services/supabase_service.dart';
import 'package:wasla/features/community/data/repositories/community_needs_repository.dart';
import 'package:wasla/features/community/presentation/pages/community_need_details_page.dart';
import 'package:wasla/features/community/presentation/pages/add_community_need_page.dart';

class CommunityNeedsPage extends StatefulWidget {
  const CommunityNeedsPage({super.key});

  @override
  State<CommunityNeedsPage> createState() => _CommunityNeedsPageState();
}

class _CommunityNeedsPageState extends State<CommunityNeedsPage> {
  final _repository = CommunityNeedsRepository();
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  // ─────────────── الألوان ───────────────
  static const _green = Color(0xFF191919);
  static const _greenSoft = Color(0xFFF0ECF7);
  static const _greenLight = Color(0xFF4A4A4A);
  static const _darkGreen = Color(0xFF050505);
  static const _background = Color(0xFFF8F7FA);
  static const _orange = Color(0xFFC27A15);
  static const _red = Color(0xFFD94B55);
  static const _purple = Color(0xFF6C4DB3);
  static const _blue = Color(0xFF6C4DB3);
  static const _muted = Color(0xFF77727D);

  Color _pageBackground(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF101010)
          : _background;

  Color _surface(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF181818)
          : Colors.white;

  Color _surfaceSoft(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF28212F)
          : _greenSoft;

  Color _primaryText(BuildContext context) =>
      Theme.of(context).colorScheme.onSurface;

  Color _secondaryText(BuildContext context) =>
      Theme.of(context).colorScheme.onSurfaceVariant;

  Color _divider(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF303030)
          : const Color(0xFFE9E6ED);

  // ─────────────── الحالة ───────────────
  bool _loading = true;
  bool _loadingMore = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _needs = [];
  int _currentPage = 0;
  bool _hasMore = true;

  // ─────────────── الفلاتر ───────────────
  String? _selectedCategoryId;
  String? _selectedCity;
  List<Map<String, dynamic>> _categories = [];
  List<String> _availableCities = [];

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _loadCities();
    _loadNeeds(refresh: true);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!_loadingMore && _hasMore && !_loading) {
        _loadNeeds();
      }
    }
  }

  // ═══════════════════════════════════════════════════════════
  // DATA LOADERS
  // ═══════════════════════════════════════════════════════════
  Future<void> _loadCities() async {
    try {
      final rows = await SupabaseService()
          .client
          .from('community_needs')
          .select('city')
          .not('city', 'is', null);

      final citiesSet = <String>{};
      for (final row in rows) {
        final c = row['city']?.toString().trim() ?? '';
        if (c.isNotEmpty && c != 'null') citiesSet.add(c);
      }

      final sorted = citiesSet.toList()..sort();
      debugPrint('✅ Loaded ${sorted.length} cities');

      if (!mounted) return;
      setState(() => _availableCities = sorted);
    } catch (e) {
      debugPrint('❌ loadCities error: $e');
    }
  }

  Future<void> _loadCategories() async {
    try {
      final rows = await SupabaseService()
          .client
          .from('community_need_categories')
          .select('slug, name_ar, icon')
          .eq('is_active', true)
          .order('sort_order');

      if (!mounted) return;
      setState(() => _categories = List<Map<String, dynamic>>.from(rows));
    } catch (e) {
      debugPrint('❌ loadCategories error: $e');
    }
  }

  Future<void> _loadNeeds({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _loading = true;
        _errorMessage = null;
        _currentPage = 0;
        _hasMore = true;
      });
    } else {
      setState(() => _loadingMore = true);
    }

    try {
      final page = refresh ? 0 : _currentPage;
      final offset = page * 20;

      final rows = await _repository.listNeeds(
        categoryId: _selectedCategoryId,
        search: _searchController.text.trim().isEmpty
            ? null
            : _searchController.text.trim(),
        city: _selectedCity,
        limit: 20,
        offset: offset,
      );

      if (!mounted) return;
      setState(() {
        if (refresh) {
          _needs = rows;
        } else {
          _needs = [..._needs, ...rows];
        }
        _currentPage = page + 1;
        _hasMore = rows.length == 20;
        _loading = false;
        _loadingMore = false;
      });
    } catch (e) {
      debugPrint('❌ loadNeeds error: $e');
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMore = false;
          _errorMessage = 'تعذر تحميل الاحتياجات';
        });
      }
    }
  }

  Future<void> _refresh() async {
    await Future.wait([_loadNeeds(refresh: true), _loadCities()]);
  }

  void _onSearchChanged() {
    setState(() {});
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _loadNeeds(refresh: true);
    });
  }

  Future<void> _openCityPicker() async {
    final picked = await showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (_) => _CityPickerSheet(
        cities: _availableCities,
        selected: _selectedCity,
      ),
    );

    if (!mounted || picked == null) return;

    setState(() => _selectedCity = picked.isEmpty ? null : picked);
    _loadNeeds(refresh: true);
  }

  // ═══════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _pageBackground(context),
        body: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            // ═══════════════════════════════════════════════
            // MODERN APP BAR
            // ═══════════════════════════════════════════════
            SliverAppBar(
              expandedHeight: 148,
              pinned: true,
              stretch: true,
              backgroundColor: _green,
              foregroundColor: Colors.white,
              elevation: 0,
              flexibleSpace: FlexibleSpaceBar(
                stretchModes: const [StretchMode.zoomBackground],
                background: _buildHeroHeader(),
              ),
              leading: IconButton(
                onPressed: () => Navigator.maybePop(context),
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
              ),
              actions: [
                IconButton(
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh_rounded),
                ),
                const SizedBox(width: 4),
              ],
            ),

            // ═══════════════════════════════════════════════
            // SEARCH BAR — ثابت تحت الهيدر
            // ═══════════════════════════════════════════════
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: _buildSearchBar(),
              ),
            ),

            // ═══════════════════════════════════════════════
            // CATEGORY CHIPS
            // ═══════════════════════════════════════════════
            if (_categories.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: _buildCategoryChips(),
                ),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 14)),

            // ═══════════════════════════════════════════════
            // CONTENT
            // ═══════════════════════════════════════════════
            _buildContentSliver(),

            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
        floatingActionButton: _buildFab(),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // HERO HEADER
  // ═══════════════════════════════════════════════════════════
  Widget _buildHeroHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_darkGreen, _green],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -40,
            left: -40,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            right: -30,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.04),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.favorite_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'احتياجات المجتمع',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                height: 1.1,
                              ),
                            ),
                            SizedBox(height: 3),
                            Text(
                              'ساعد باهتمام، وخلّي أثرَك يوصل',
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
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.bolt_rounded,
                          color: Colors.white,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _loading
                              ? 'جاري التحميل...'
                              : '${_needs.length} احتياج متاح',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // SEARCH BAR
  // ═══════════════════════════════════════════════════════════
  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: _surface(context),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: _darkGreen.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Icon(Icons.search_rounded, color: _green, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      textDirection: TextDirection.rtl,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _primaryText(context),
                      ),
                      onChanged: (_) => _onSearchChanged(),
                      decoration: InputDecoration(
                        hintText: 'ابحث عن احتياج...',
                        hintStyle: TextStyle(
                          color: _secondaryText(context),
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  if (_searchController.text.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        _searchController.clear();
                        _loadNeeds(refresh: true);
                      },
                      child: Container(
                        width: 22,
                        height: 22,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _muted.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.close_rounded,
                          size: 13,
                          color: _secondaryText(context),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Container(
            width: 1,
            height: 26,
            color: _divider(context),
          ),
          _buildCityButton(),
        ],
      ),
    );
  }

  Widget _buildCityButton() {
    final hasCity = _selectedCity != null && _selectedCity!.isNotEmpty;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _openCityPicker,
        borderRadius: const BorderRadius.horizontal(
          left: Radius.circular(18),
        ),
        child: Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: hasCity ? _green : _greenSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.location_on_rounded,
                  color: hasCity ? Colors.white : _green,
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 70),
                child: Text(
                  hasCity ? _selectedCity! : 'المدينة',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: hasCity ? _green : _primaryText(context),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (hasCity)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _selectedCity = null);
                      _loadNeeds(refresh: true);
                    },
                    child: Container(
                      width: 18,
                      height: 18,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _green.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        size: 11,
                        color: _green,
                      ),
                    ),
                  ),
                )
              else
                Padding(
                  padding: EdgeInsets.only(right: 4),
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: _secondaryText(context),
                    size: 18,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // CATEGORY CHIPS
  // ═══════════════════════════════════════════════════════════
  Future<void> _openCategoryPicker() async {
    // The sheet can still be reversing its close animation after the Future
    // completes. Keep the search value local instead of disposing a controller
    // while the TextField is still attached to the widget tree.
    var query = '';
    await showModalBottomSheet<void>(
      context: context, isScrollControlled: true, useSafeArea: true, backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(builder: (context, setSheetState) {
        final normalizedQuery = query.trim().toLowerCase();
        final filtered = _categories.where((cat) => (cat['name_ar']?.toString() ?? '').toLowerCase().contains(normalizedQuery)).toList();
        return Container(
          height: MediaQuery.of(context).size.height * .7,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          decoration: BoxDecoration(color: _surface(context), borderRadius: const BorderRadius.vertical(top: Radius.circular(28))),
          child: Column(children: [
            Container(width: 42, height: 4, decoration: BoxDecoration(color: _muted.withValues(alpha: .3), borderRadius: BorderRadius.circular(4))),
            const SizedBox(height: 16),
            Text('فلترة حسب التصنيف', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _primaryText(context))),
            const SizedBox(height: 12),
            TextField(autofocus: true, onChanged: (value) => setSheetState(() => query = value), decoration: InputDecoration(prefixIcon: const Icon(Icons.search_rounded, color: _green), hintText: 'ابحث عن تصنيف...', filled: true, fillColor: _surfaceSoft(context), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none))),
            const SizedBox(height: 10),
            Expanded(child: ListView.separated(itemCount: filtered.length + 1, separatorBuilder: (_, __) => const Divider(height: 1), itemBuilder: (_, index) {
              if (index == 0) return Material(color: Colors.transparent, child: ListTile(title: const Text('كل التصنيفات', style: TextStyle(fontWeight: FontWeight.w800)), trailing: _selectedCategoryId == null ? const Icon(Icons.check_circle_rounded, color: _green) : null, onTap: () { setState(() => _selectedCategoryId = null); Navigator.pop(sheetContext); _loadNeeds(refresh: true); }));
              final cat = filtered[index - 1]; final id = cat['slug']?.toString() ?? ''; final name = cat['name_ar']?.toString() ?? '';
              return Material(color: Colors.transparent, child: ListTile(title: Text(name, style: TextStyle(fontWeight: FontWeight.w800)), trailing: _selectedCategoryId == id ? const Icon(Icons.check_circle_rounded, color: _green) : null, onTap: () { setState(() => _selectedCategoryId = id); Navigator.pop(sheetContext); _loadNeeds(refresh: true); }));
            }))
          ]),
        );
      }),
    );
  }

  Widget _buildCategoryChips() {
    String? selected;
    for (final category in _categories) {
      if (category['slug']?.toString() == _selectedCategoryId) {
        selected = category['name_ar']?.toString();
        break;
      }
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: OutlinedButton.icon(
        onPressed: _openCategoryPicker,
        icon: const Icon(Icons.tune_rounded, size: 18),
        label: Text(selected == null ? 'اختار التصنيف للفلترة' : 'التصنيف: $selected'),
        style: OutlinedButton.styleFrom(foregroundColor: _green, backgroundColor: _surface(context), side: BorderSide(color: selected == null ? _divider(context) : _green), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // FAB
  // ═══════════════════════════════════════════════════════════
  Widget _buildFab() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: _green.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddCommunityNeedPage()),
          );
          if (result == true && mounted) _refresh();
        },
        backgroundColor: _green,
        foregroundColor: Colors.white,
        elevation: 0,
        highlightElevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        icon: const Icon(Icons.add_rounded, size: 22),
        label: const Text(
          'أضف احتياج',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // CONTENT SLIVER
  // ═══════════════════════════════════════════════════════════
  Widget _buildContentSliver() {
    if (_loading) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: Padding(
          padding: EdgeInsets.only(top: 40),
          child: Center(child: CircularProgressIndicator(color: _green)),
        ),
      );
    }

    if (_errorMessage != null) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: _buildErrorState(),
      );
    }

    if (_needs.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: _buildEmptyState(),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(12, 2, 12, 0),
      sliver: SliverList.builder(
        itemCount: _needs.length + (_loadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _needs.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(
                    color: _green,
                    strokeWidth: 2.5,
                  ),
                ),
              ),
            );
          }
          return _NeedCard(
            need: _needs[index],
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CommunityNeedDetailsPage(
                    needId: _needs[index]['id']?.toString() ?? '',
                  ),
                ),
              ).then((_) => _refresh());
            },
          );
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // EMPTY / ERROR
  // ═══════════════════════════════════════════════════════════
  Widget _buildEmptyState() {
    final hasFilters = _selectedCity != null ||
        _selectedCategoryId != null ||
        _searchController.text.isNotEmpty;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 110,
              height: 110,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: _greenSoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.search_off_rounded,
                color: _green,
                size: 48,
              ),
            ),
            const SizedBox(height: 22),
            Text(
              hasFilters ? 'مفيش نتائج' : 'مفيش احتياجات دلوقتي',
              style: TextStyle(
                color: _primaryText(context),
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hasFilters
                  ? 'جرّب تغيّر الفلاتر أو ابحث بكلمة تانية'
                  : 'لما حد يحتاج حاجة هتظهر هنا',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _secondaryText(context),
                fontSize: 13,
                height: 1.6,
              ),
            ),
            if (hasFilters) ...[
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _selectedCity = null;
                    _selectedCategoryId = null;
                    _searchController.clear();
                  });
                  _loadNeeds(refresh: true);
                },
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('مسح الفلاتر'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _green,
                  side: const BorderSide(color: _green),
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
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
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
              child: const Icon(Icons.cloud_off_rounded, color: _red, size: 40),
            ),
            const SizedBox(height: 22),
            Text(
              'تعذر التحميل',
              style: TextStyle(
                color: _primaryText(context),
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? '',
              textAlign: TextAlign.center,
              style: TextStyle(color: _secondaryText(context), fontSize: 13),
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: _refresh,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('إعادة المحاولة'),
              style: FilledButton.styleFrom(
                backgroundColor: _green,
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
}

// ═══════════════════════════════════════════════════════════
// NEED CARD — compact horizontal design
// ═══════════════════════════════════════════════════════════
class _NeedCard extends StatelessWidget {
  final Map<String, dynamic> need;
  final VoidCallback onTap;

  static const _ink = Color(0xFF171717);
  static const _muted = Color(0xFF777777);
  static const _soft = Color(0xFFF1EFF5);
  static const _lavender = Color(0xFF6C4DB3);
  static const _urgent = Color(0xFFD94B55);
  static const _important = Color(0xFFC27A15);

  const _NeedCard({required this.need, required this.onTap});

  IconData _categoryIcon(String? name) {
    final value = (name ?? '').toLowerCase();
    if (value.contains('طعام') || value.contains('أكل')) return Icons.restaurant_rounded;
    if (value.contains('ملابس')) return Icons.checkroom_rounded;
    if (value.contains('دواء') || value.contains('صحة')) return Icons.medical_services_rounded;
    if (value.contains('أثاث')) return Icons.chair_rounded;
    if (value.contains('تعليم') || value.contains('كتب')) return Icons.menu_book_rounded;
    if (value.contains('سكن') || value.contains('بيت')) return Icons.home_rounded;
    return Icons.category_rounded;
  }

  ({Color color, String label, IconData icon}) _urgency(String value) {
    switch (value) {
      case 'urgent':
        return (color: _urgent, label: 'عاجل', icon: Icons.bolt_rounded);
      case 'high':
        return (color: _important, label: 'مهم', icon: Icons.priority_high_rounded);
      default:
        return (color: _lavender, label: 'عادي', icon: Icons.flag_rounded);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF181818) : Colors.white;
    final border = isDark ? const Color(0xFF303030) : const Color(0xFFE9E6ED);
    final title = need['title']?.toString().trim().isNotEmpty == true
        ? need['title'].toString()
        : 'احتياج جديد';
    final description = need['description']?.toString() ?? '';
    final category = need['category_name_ar']?.toString() ?? 'عام';
    final city = need['city']?.toString() ?? '';
    final requester = need['requester_name']?.toString() ?? 'مستخدم';
    final avatar = need['requester_avatar']?.toString();
    final image = need['image_url']?.toString();
    final quantity = (need['quantity'] as num?)?.toInt() ?? 1;
    final contacts = (need['contact_count'] as num?)?.toInt() ?? 0;
    final urgency = _urgency(need['urgency']?.toString() ?? 'normal');
    final icon = _categoryIcon(category);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? .2 : .045),
                  blurRadius: 16,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: SizedBox(
                    width: 92,
                    height: 112,
                    child: image != null && image.isNotEmpty
                        ? Image.network(image, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _fallback(icon, isDark))
                        : _fallback(icon, isDark),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 112,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                category,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: isDark ? Colors.white70 : _muted, fontSize: 11, fontWeight: FontWeight.w800),
                              ),
                            ),
                            _badge(urgency.icon, urgency.label, urgency.color),
                          ],
                        ),
                        const SizedBox(height: 7),
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: isDark ? Colors.white : _ink, fontSize: 15, height: 1.25, fontWeight: FontWeight.w900),
                        ),
                        if (description.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: isDark ? Colors.white54 : _muted, fontSize: 11.5, height: 1.35),
                          ),
                        ],
                        const Spacer(),
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 11,
                              backgroundColor: isDark ? const Color(0xFF303030) : _soft,
                              backgroundImage: avatar != null && avatar.isNotEmpty ? NetworkImage(avatar) : null,
                              child: avatar == null || avatar.isEmpty ? Icon(Icons.person_rounded, size: 13, color: isDark ? Colors.white70 : _lavender) : null,
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                '${requester.isEmpty ? 'مستخدم' : requester}${city.isEmpty ? '' : ' • $city'}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: isDark ? Colors.white60 : _muted, fontSize: 10.5, fontWeight: FontWeight.w700),
                              ),
                            ),
                            _miniStat(Icons.inventory_2_outlined, '$quantity'),
                            if (contacts > 0) ...[
                              const SizedBox(width: 5),
                              _miniStat(Icons.people_outline_rounded, '$contacts'),
                            ],
                            const SizedBox(width: 6),
                            Icon(Icons.arrow_back_ios_new_rounded, size: 13, color: isDark ? Colors.white54 : _muted),
                          ],
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
    );
  }

  Widget _fallback(IconData icon, bool isDark) {
    return Container(
      color: isDark ? const Color(0xFF28212F) : _soft,
      alignment: Alignment.center,
      child: Icon(icon, color: isDark ? Colors.white70 : _lavender, size: 32),
    );
  }

  Widget _badge(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: .1), borderRadius: BorderRadius.circular(9)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 11, color: color),
        const SizedBox(width: 3),
        Text(label, style: TextStyle(color: color, fontSize: 9.5, fontWeight: FontWeight.w900)),
      ]),
    );
  }

  Widget _miniStat(IconData icon, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(color: _soft, borderRadius: BorderRadius.circular(7)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 11, color: _lavender),
        const SizedBox(width: 3),
        Text(value, style: const TextStyle(color: _lavender, fontSize: 10, fontWeight: FontWeight.w900)),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// City Picker Bottom Sheet
// ═══════════════════════════════════════════════════════════
class _CityPickerSheet extends StatefulWidget {
  final List<String> cities;
  final String? selected;

  const _CityPickerSheet({required this.cities, required this.selected});

  @override
  State<_CityPickerSheet> createState() => _CityPickerSheetState();
}

class _CityPickerSheetState extends State<_CityPickerSheet> {
  static const _green = Color(0xFF0B7650);
  static const _greenSoft = Color(0xFFE7F5EE);
  static const _darkGreen = Color(0xFF0F2E23);
  static const _muted = Color(0xFF8A9D95);

  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF1A2821) : Colors.white;
    final softSurface = isDark ? const Color(0xFF24372E) : _greenSoft;
    final primaryText = Theme.of(context).colorScheme.onSurface;
    final secondaryText = Theme.of(context).colorScheme.onSurfaceVariant;
    final border = isDark ? const Color(0xFF30463B) : const Color(0xFFEFF5F1);
    final filtered = widget.cities
        .where((c) => c.toLowerCase().contains(_query.toLowerCase()))
        .toList();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.85,
          ),
          child: Padding(
            padding: EdgeInsets.only(bottom: bottomInset),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 10),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDDE8E2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 18),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: softSurface,
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Icon(
                          Icons.location_on_rounded,
                          color: _green,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'اختار المدينة',
                              style: TextStyle(
                                color: primaryText,
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.cities.isEmpty
                                  ? 'مفيش مدن متاحة'
                                  : '${widget.cities.length} مدينة متاحة',
                              style: TextStyle(
                                color: secondaryText,
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context, null),
                        icon: const Icon(Icons.close_rounded),
                        color: primaryText,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Divider(height: 1, color: border),
                const SizedBox(height: 12),
                if (widget.cities.length > 5)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: softSurface,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(width: 12),
                          Icon(
                            Icons.search_rounded,
                            color: _green,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              textDirection: TextDirection.rtl,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: primaryText,
                              ),
                              onChanged: (v) => setState(() => _query = v),
                              decoration: InputDecoration(
                                hintText: 'ابحث عن مدينة...',
                                hintStyle: TextStyle(
                                  color: secondaryText,
                                  fontSize: 13,
                                ),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                Flexible(
                  child: widget.cities.isEmpty
                      ? _buildNoCitiesMessage()
                      : filtered.isEmpty
                          ? _buildNoMatchesMessage()
                          : ListView(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                              shrinkWrap: true,
                              children: [
                                _buildCityTile(
                                  label: 'كل المدن',
                                  icon: Icons.public_rounded,
                                  selected: widget.selected == null,
                                  onTap: () => Navigator.pop(context, ''),
                                ),
                                ...filtered.map(
                                  (city) => _buildCityTile(
                                    label: city,
                                    icon: Icons.location_city_rounded,
                                    selected: widget.selected == city,
                                    onTap: () => Navigator.pop(context, city),
                                  ),
                                ),
                              ],
                            ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNoCitiesMessage() {
    final primaryText = Theme.of(context).colorScheme.onSurface;
    final secondaryText = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.location_off_rounded, color: secondaryText, size: 52),
          SizedBox(height: 14),
          Text(
            'مفيش مدن متاحة دلوقتي',
            style: TextStyle(
              color: primaryText,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoMatchesMessage() {
    final primaryText = Theme.of(context).colorScheme.onSurface;
    final secondaryText = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, color: secondaryText, size: 52),
          const SizedBox(height: 14),
          Text(
            'مفيش نتائج',
            style: TextStyle(
              color: primaryText,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'مفيش مدينة مطابقة لـ "$_query"',
            style: TextStyle(color: secondaryText, fontSize: 12),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          TextButton.icon(
            onPressed: () {
              _searchController.clear();
              setState(() => _query = '');
            },
            icon: const Icon(Icons.clear_rounded, size: 16),
            label: Text('مسح البحث'),
            style: TextButton.styleFrom(foregroundColor: _green),
          ),
        ],
      ),
    );
  }

  Widget _buildCityTile({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final softSurface = isDark ? const Color(0xFF24372E) : _greenSoft;
    final primaryText = Theme.of(context).colorScheme.onSurface;
    final border = isDark ? const Color(0xFF30463B) : const Color(0xFFEFF5F1);
    return Material(
      color: selected ? softSurface : Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? _green.withValues(alpha: 0.3)
                  : border,
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? _green : _greenSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: selected ? Colors.white : _green,
                  size: 17,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: selected ? _green : primaryText,
                    fontSize: 13.5,
                    fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                  ),
                ),
              ),
              if (selected)
                Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _green,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
