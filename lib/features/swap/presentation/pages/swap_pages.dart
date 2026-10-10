import 'dart:math' as math;
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:loqma/features/swap/data/swap_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class SwapListingsPage extends StatefulWidget {
  const SwapListingsPage({super.key});
  @override
  State<SwapListingsPage> createState() => _SwapListingsPageState();
}

class _SwapFeed {
  final List<Map<String, dynamic>> nearby;
  final List<Map<String, dynamic>> spotlight;
  final List<Map<String, dynamic>> recent;
  final Set<String> favorites;
  const _SwapFeed(
      {required this.nearby,
      required this.spotlight,
      required this.recent,
      required this.favorites});
}

class _SwapListingsPageState extends State<SwapListingsPage> {
  final _repo = SwapRepository();
  final _search = TextEditingController();
  static const _defaultCategories = [
    'إلكترونيات',
    'موبايلات',
    'كمبيوتر ولابتوب',
    'كاميرات',
    'أثاث',
    'ملابس',
    'أجهزة منزلية',
    'سيارات ومواصلات',
    'كتب وألعاب',
    'رياضة',
    'أخرى'
  ];
  static const _governorates = [
    'القاهرة',
    'الجيزة',
    'الإسكندرية',
    'الدقهلية',
    'الشرقية',
    'القليوبية',
    'الغربية',
    'المنوفية',
    'البحيرة',
    'كفر الشيخ',
    'دمياط',
    'بورسعيد',
    'الإسماعيلية',
    'السويس',
    'الفيوم',
    'بني سويف',
    'المنيا',
    'أسيوط',
    'سوهاج',
    'قنا',
    'الأقصر',
    'أسوان',
    'مطروح',
    'شمال سيناء',
    'جنوب سيناء',
  ];
  late Future<_SwapFeed> _future;
  String? _governorate;
  String? _category;
  bool _showAll = false;
  List<String> _categories = _defaultCategories;

  @override
  void initState() {
    super.initState();
    _future = _load();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final rows = await _repo.listSwapCategories();
      final names = rows
          .map((row) => row['name_ar']?.toString() ?? '')
          .where((name) => name.isNotEmpty)
          .toList();
      if (mounted && names.isNotEmpty) setState(() => _categories = names);
    } catch (_) {
      // نستخدم القائمة الاحتياطية إذا كانت نسخة قديمة من قاعدة البيانات.
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<_SwapFeed> _load() async {
    final rows = await _repo.listOpenListings(
        search: _search.text, governorate: _governorate);
    final nearby = await _repo.listNearbyOpenListings(
        search: _search.text, governorate: _governorate);
    final recent = await _repo.recentlyViewedListings();
    final favorites = await _repo.favoriteListingIds();
    return _SwapFeed(
      nearby: _applyCategory(nearby),
      spotlight: _applyCategory(rows),
      recent: _applyCategory(recent),
      favorites: favorites,
    );
  }

  List<Map<String, dynamic>> _applyCategory(List<Map<String, dynamic>> rows) {
    if (_category == null) return rows;
    return rows.where((row) {
      final categories = (row['categories'] as List? ?? const [])
          .map((value) => value.toString())
          .toSet();
      return categories.contains(_category) ||
          row['category']?.toString() == _category;
    }).toList();
  }

  Future<void> _reload() async {
    final future = _load();
    if (mounted) {
      setState(() {
        _future = future;
      });
    }
    try {
      await future;
    } catch (_) {}
  }

  Future<void> _openListing(Map<String, dynamic> row) async {
    await _repo.recordListingView(row['id'].toString());
    if (!mounted) return;
    await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => SwapDetailsPage(listingId: row['id'].toString())));
    if (mounted) _reload();
  }

  Future<void> _toggleFavorite(_SwapFeed feed, String id) async {
    final next = !feed.favorites.contains(id);
    setState(() {
      if (next) {
        feed.favorites.add(id);
      } else {
        feed.favorites.remove(id);
      }
    });
    try {
      await _repo.toggleFavorite(id, next);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        if (next) {
          feed.favorites.remove(id);
        } else {
          feed.favorites.add(id);
        }
      });
      _toast(context, Exception('تعذر تحديث المفضلة'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('عروض الاستبدال',
              style: TextStyle(fontWeight: FontWeight.w900)),
          actions: [
            IconButton(
              tooltip: 'استبدالاتي',
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const MySwapsPage())),
              icon: const Icon(Icons.swap_horizontal_circle_rounded),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () async {
            final ok = await Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const CreateSwapListingPage()));
            if (ok == true && mounted) _reload();
          },
          icon: const Icon(Icons.add_rounded),
          label: const Text('إضافة استبدال'),
        ),
        body: RefreshIndicator(
          onRefresh: () async => _reload(),
          child: FutureBuilder<_SwapFeed>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting)
                return Center(
                    child: CircularProgressIndicator(color: c.primary));
              if (snap.hasError)
                return ListView(children: [
                  const SizedBox(height: 180),
                  _StateMessage(
                      title: 'تعذر تحميل عروض الاستبدال',
                      onRetry: () {
                        _reload();
                      })
                ]);
              final feed = snap.data ??
                  const _SwapFeed(
                      nearby: [], spotlight: [], recent: [], favorites: {});
              final all = _unique([...feed.nearby, ...feed.spotlight]);
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [c.primary, c.primary.withValues(alpha: .72)],
                        begin: AlignmentDirectional.topStart,
                        end: AlignmentDirectional.bottomEnd,
                      ),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            color: c.onPrimary.withValues(alpha: .16),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.swap_horizontal_circle_rounded,
                              color: c.onPrimary, size: 32),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('استبدل بدل ما تشتريها',
                                  style: TextStyle(
                                      color: c.onPrimary,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900)),
                              const SizedBox(height: 5),
                              Text(
                                  'تواصل مباشرة مع صاحب الإعلان واتفقوا بسهولة',
                                  style: TextStyle(
                                      color: c.onPrimary.withValues(alpha: .82),
                                      height: 1.35)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _search,
                    readOnly: true,
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const SwapSearchPage())),
                    decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search_rounded),
                        hintText: 'ابحث حسب التصنيف أو اسم المنتج'),
                  ),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(
                        child: DropdownButtonFormField<String>(
                      value: _governorate,
                      isExpanded: true,
                      hint: const Text('كل المحافظات'),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.location_on_outlined),
                        labelText: 'المحافظة',
                        suffixIcon: _governorate == null
                            ? null
                            : IconButton(
                                tooltip: 'مسح المحافظة',
                                onPressed: () => _setGovernorate(null),
                                icon: const Icon(Icons.clear_rounded),
                              ),
                      ),
                      items: _governorates
                          .map(
                              (g) => DropdownMenuItem(value: g, child: Text(g)))
                          .toList(),
                      onChanged: _setGovernorate,
                    )),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                        onPressed: () {
                          _showAll = !_showAll;
                          setState(() {});
                        },
                        icon: Icon(_showAll
                            ? Icons.view_carousel_outlined
                            : Icons.grid_view_rounded),
                        tooltip: 'تغيير طريقة العرض'),
                  ]),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 42,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _FilterChip(
                            label: 'الكل',
                            selected: _category == null,
                            onTap: () {
                              _category = null;
                              _reload();
                            }),
                        ..._categories.map((category) => _FilterChip(
                            label: category,
                            selected: _category == category,
                            onTap: () {
                              _category = category;
                              _reload();
                            })),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  if (_showAll) ...[
                    _SectionHeader(
                        title: 'كل عروض الاستبدال', count: all.length),
                    const SizedBox(height: 10),
                    if (all.isEmpty)
                      const _StateMessage(title: 'لا توجد عروض مطابقة للبحث')
                    else
                      _ListingGrid(
                          rows: all,
                          favorites: feed.favorites,
                          onTap: _openListing,
                          onFavorite: (id) => _toggleFavorite(feed, id)),
                  ] else ...[
                    _SwapSection(
                        title: 'عروض قريبة منك',
                        rows: feed.nearby,
                        favorites: feed.favorites,
                        onSeeAll: () {
                          _showAll = true;
                          setState(() {});
                        },
                        onTap: _openListing,
                        onFavorite: (id) => _toggleFavorite(feed, id)),
                    const SizedBox(height: 26),
                    _SwapSection(
                        title: 'عروض مميزة',
                        rows: feed.spotlight.take(12).toList(),
                        favorites: feed.favorites,
                        onSeeAll: () {
                          _showAll = true;
                          setState(() {});
                        },
                        onTap: _openListing,
                        onFavorite: (id) => _toggleFavorite(feed, id)),
                    if (feed.recent.isNotEmpty) ...[
                      const SizedBox(height: 26),
                      _SwapSection(
                          title: 'شاهدتها مؤخرًا',
                          rows: feed.recent,
                          favorites: feed.favorites,
                          onSeeAll: null,
                          onTap: _openListing,
                          onFavorite: (id) => _toggleFavorite(feed, id)),
                    ],
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _unique(List<Map<String, dynamic>> rows) {
    final seen = <String>{};
    return rows.where((row) => seen.add(row['id'].toString())).toList();
  }

  void _setGovernorate(String? value) {
    _governorate = value;
    _reload();
  }
}

class SwapSearchPage extends StatefulWidget {
  const SwapSearchPage({super.key});

  @override
  State<SwapSearchPage> createState() => _SwapSearchPageState();
}

class _SwapSearchPageState extends State<SwapSearchPage> {
  final _repo = SwapRepository();
  late Future<List<Map<String, dynamic>>> _categories;

  @override
  void initState() {
    super.initState();
    _categories = _loadCategories();
  }

  Future<List<Map<String, dynamic>>> _loadCategories() async {
    try {
      final rows = await _repo.listSwapCategories();
      if (rows.isNotEmpty) return rows;
    } catch (_) {}
    return const [
      {'slug': 'electronics', 'name_ar': 'إلكترونيات', 'icon': 'devices'},
      {'slug': 'mobile_phones', 'name_ar': 'موبايلات', 'icon': 'phone_android'},
      {'slug': 'computers', 'name_ar': 'كمبيوتر ولابتوب', 'icon': 'computer'},
      {'slug': 'cameras', 'name_ar': 'كاميرات', 'icon': 'camera_alt'},
      {'slug': 'furniture', 'name_ar': 'أثاث', 'icon': 'chair'},
      {'slug': 'clothing', 'name_ar': 'ملابس', 'icon': 'checkroom'},
      {'slug': 'home_appliances', 'name_ar': 'أجهزة منزلية', 'icon': 'kitchen'},
      {'slug': 'vehicles', 'name_ar': 'سيارات ومواصلات', 'icon': 'directions_car'},
      {'slug': 'books', 'name_ar': 'كتب وألعاب', 'icon': 'menu_book'},
      {'slug': 'sports', 'name_ar': 'رياضة', 'icon': 'sports_soccer'},
      {'slug': 'other', 'name_ar': 'أخرى', 'icon': 'category'},
    ];
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('بحث في الاستبدالات',
              style: TextStyle(fontWeight: FontWeight.w900)),
        ),
        body: FutureBuilder<List<Map<String, dynamic>>>(
          future: _categories,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator(color: c.primary));
            }
            final categories = snapshot.data ?? const <Map<String, dynamic>>[];
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 30),
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [c.primary, c.primary.withValues(alpha: .70)],
                      begin: AlignmentDirectional.topStart,
                      end: AlignmentDirectional.bottomEnd,
                    ),
                    borderRadius: BorderRadius.circular(26),
                  ),
                  child: Row(children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                          color: c.onPrimary.withValues(alpha: .16),
                          shape: BoxShape.circle),
                      child: Icon(Icons.search_rounded,
                          color: c.onPrimary, size: 31),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('اختار مجال البحث',
                                style: TextStyle(
                                    color: c.onPrimary,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900)),
                            const SizedBox(height: 5),
                            Text('اختار التصنيف وشوف كل عروض الاستبدال الخاصة به',
                                style: TextStyle(
                                    color: c.onPrimary.withValues(alpha: .84),
                                    height: 1.35)),
                          ]),
                    ),
                  ]),
                ),
                const SizedBox(height: 24),
                Text('تصنيفات الاستبدال',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 12),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: categories.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.35,
                  ),
                  itemBuilder: (_, index) {
                    final category = categories[index];
                    final name = category['name_ar']?.toString() ?? 'أخرى';
                    return _SwapCategoryTile(
                      name: name,
                      icon: _swapCategoryIcon(category['icon']?.toString()),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SwapCategoryResultsPage(
                            category: name,
                            categorySlug: category['slug']?.toString(),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class SwapCategoryResultsPage extends StatefulWidget {
  final String category;
  final String? categorySlug;
  const SwapCategoryResultsPage(
      {super.key, required this.category, this.categorySlug});

  @override
  State<SwapCategoryResultsPage> createState() => _SwapCategoryResultsPageState();
}

class _SwapCategoryResultsPageState extends State<SwapCategoryResultsPage> {
  final _repo = SwapRepository();
  final _search = TextEditingController();
  late Future<List<Map<String, dynamic>>> _future;
  Set<String> _favorites = <String>{};
  String _query = '';
  String _sort = 'newest';
  String? _cityFilter;
  bool _withImagesOnly = false;
  double? _userLatitude;
  double? _userLongitude;

  @override
  void initState() {
    super.initState();
    _future = _load();
    _search.addListener(() {
      if (mounted) setState(() => _query = _search.text.trim().toLowerCase());
    });
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final rows = await _repo.listOpenListings(
        category: widget.category,
        categorySlug: widget.categorySlug,
        city: _cityFilter,
        withImagesOnly: _withImagesOnly);
    _favorites = await _repo.favoriteListingIds();
    final location = await _repo.currentUserLocation();
    _userLatitude = (location?['latitude'] as num?)?.toDouble();
    _userLongitude = (location?['longitude'] as num?)?.toDouble();
    final availableCities = rows
        .map((row) => row['city']?.toString().trim() ?? '')
        .where((city) => city.isNotEmpty)
        .toSet();
    if (_cityFilter != null && !availableCities.contains(_cityFilter)) {
      _cityFilter = null;
    }
    return rows
        .where((row) => _matchesCategory(
            row, widget.category, widget.categorySlug))
        .toList();
  }

  List<Map<String, dynamic>> _filtered(List<Map<String, dynamic>> rows) {
    final filtered = rows.where((row) {
      final text = [
        row['wanted_title'],
        row['description'],
        row['city'],
        row['governorate'],
      ].map((value) => value?.toString() ?? '').join(' ').toLowerCase();
      return _query.isEmpty || text.contains(_query);
    }).toList();
    filtered.sort((a, b) {
      final aDate = DateTime.tryParse(a['created_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = DateTime.tryParse(b['created_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      if (_sort == 'nearest' &&
          _userLatitude != null &&
          _userLongitude != null) {
        final aDistance = _swapDistanceKm(a, _userLatitude!, _userLongitude!);
        final bDistance = _swapDistanceKm(b, _userLatitude!, _userLongitude!);
        return aDistance.compareTo(bDistance);
      }
      return _sort == 'oldest'
          ? aDate.compareTo(bDate)
          : bDate.compareTo(aDate);
    });
    return filtered;
  }

  List<String> _cities(List<Map<String, dynamic>> rows) => rows
      .map((row) => row['city']?.toString().trim() ?? '')
      .where((city) => city.isNotEmpty)
      .toSet()
      .toList()
    ..sort();

  Future<void> _openListing(Map<String, dynamic> row) async {
    await _repo.recordListingView(row['id'].toString());
    if (!mounted) return;
    await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => SwapDetailsPage(listingId: row['id'].toString())));
    await _reloadResults();
  }

  Future<void> _reloadResults() async {
    final future = _load();
    if (mounted) {
      setState(() {
        _future = future;
      });
    }
    try {
      await future;
    } catch (_) {}
  }

  Future<void> _toggleFavorite(String id) async {
    final next = !_favorites.contains(id);
    setState(() {
      if (next) {
        _favorites.add(id);
      } else {
        _favorites.remove(id);
      }
    });
    try {
      await _repo.toggleFavorite(id, next);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        if (next) {
          _favorites.remove(id);
        } else {
          _favorites.add(id);
        }
      });
      _toast(context, Exception('تعذر تحديث المفضلة'));
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.category,
              style: const TextStyle(fontWeight: FontWeight.w900)),
        ),
        body: RefreshIndicator(
          onRefresh: _reloadResults,
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator(color: c.primary));
              }
              if (snapshot.hasError) {
                return ListView(children: [
                  const SizedBox(height: 180),
                  _StateMessage(
                      title: 'تعذر تحميل عروض التصنيف',
                      onRetry: () {
                        _reloadResults();
                      }),
                ]);
              }
              final rows = _filtered(snapshot.data ?? const []);
              final cities = _cities(snapshot.data ?? const []);
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
                children: [
                  TextField(
                    controller: _search,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search_rounded),
                      hintText: 'ابحث داخل ${widget.category}',
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              onPressed: _search.clear,
                              icon: const Icon(Icons.clear_rounded)),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _sort,
                        decoration: const InputDecoration(
                            labelText: 'ترتيب النتائج',
                            prefixIcon: Icon(Icons.sort_rounded)),
                        items: const [
                          DropdownMenuItem(
                              value: 'newest', child: Text('الأحدث أولًا')),
                          DropdownMenuItem(
                              value: 'oldest', child: Text('الأقدم أولًا')),
                          DropdownMenuItem(
                              value: 'nearest', child: Text('الأقرب أولًا')),
                        ],
                        onChanged: (value) {
                          if (value != null) setState(() => _sort = value);
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    IconButton.filledTonal(
                      tooltip: 'عروض بها صور فقط',
                      onPressed: () {
                        setState(() => _withImagesOnly = !_withImagesOnly);
                        _reloadResults();
                      },
                      icon: Icon(_withImagesOnly
                          ? Icons.photo_rounded
                          : Icons.photo_outlined),
                    ),
                  ]),
                  if (cities.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: _cityFilter,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'المدينة داخل المحافظة',
                        prefixIcon: const Icon(Icons.location_city_rounded),
                        suffixIcon: _cityFilter == null
                            ? null
                            : IconButton(
                                onPressed: () {
                                  setState(() => _cityFilter = null);
                                  _reloadResults();
                                },
                                icon: const Icon(Icons.clear_rounded)),
                      ),
                      hint: const Text('كل المدن'),
                      items: cities
                          .map((city) => DropdownMenuItem(
                              value: city, child: Text(city)))
                          .toList(),
                      onChanged: (value) {
                        setState(() => _cityFilter = value);
                        _reloadResults();
                      },
                    ),
                  ],
                  const SizedBox(height: 18),
                  _SectionHeader(title: 'العروض المتاحة', count: rows.length),
                  const SizedBox(height: 12),
                  if (rows.isEmpty)
                    _StateMessage(
                        title: _query.isEmpty
                            ? 'لا توجد عروض في هذا التصنيف'
                            : 'لا توجد نتائج مطابقة لبحثك')
                  else
                    _ListingGrid(
                      rows: rows,
                      favorites: _favorites,
                      onTap: _openListing,
                      onFavorite: _toggleFavorite,
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SwapCategoryTile extends StatelessWidget {
  final String name;
  final IconData icon;
  final VoidCallback onTap;
  const _SwapCategoryTile(
      {required this.name, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Material(
      color: c.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                  color: c.primaryContainer, shape: BoxShape.circle),
              child: Icon(icon, color: c.onPrimaryContainer, size: 24),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
            Icon(Icons.arrow_back_ios_new_rounded,
                size: 16, color: c.onSurfaceVariant),
          ]),
        ),
      ),
    );
  }
}

bool _matchesCategory(Map<String, dynamic> row, String category,
    String? categorySlug) {
  if (row['category']?.toString() == category ||
      row['category']?.toString() == categorySlug) return true;
  final categories = (row['categories'] as List? ?? const [])
      .map((value) => value.toString())
      .toList();
  return categories.contains(category) ||
      (categorySlug != null && categories.contains(categorySlug));
}

double _swapDistanceKm(
    Map<String, dynamic> row, double userLatitude, double userLongitude) {
  final latitude = (row['latitude'] as num?)?.toDouble();
  final longitude = (row['longitude'] as num?)?.toDouble();
  if (latitude == null || longitude == null) return double.maxFinite;
  const earthRadiusKm = 6371.0;
  final dLat = _toRadians(latitude - userLatitude);
  final dLon = _toRadians(longitude - userLongitude);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_toRadians(userLatitude)) *
          math.cos(_toRadians(latitude)) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);
  return earthRadiusKm * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

double _toRadians(double degrees) => degrees * math.pi / 180;

IconData _swapCategoryIcon(String? icon) {
  switch (icon) {
    case 'devices':
      return Icons.devices_other_rounded;
    case 'phone_android':
      return Icons.phone_android_rounded;
    case 'computer':
      return Icons.computer_rounded;
    case 'camera_alt':
      return Icons.camera_alt_rounded;
    case 'chair':
      return Icons.chair_rounded;
    case 'checkroom':
      return Icons.checkroom_rounded;
    case 'kitchen':
      return Icons.kitchen_rounded;
    case 'directions_car':
      return Icons.directions_car_rounded;
    case 'menu_book':
      return Icons.menu_book_rounded;
    case 'sports_soccer':
      return Icons.sports_soccer_rounded;
    default:
      return Icons.category_rounded;
  }
}

class _SwapSection extends StatelessWidget {
  final String title;
  final List<Map<String, dynamic>> rows;
  final Set<String> favorites;
  final VoidCallback? onSeeAll;
  final Future<void> Function(Map<String, dynamic>) onTap;
  final Future<void> Function(String) onFavorite;
  const _SwapSection(
      {required this.title,
      required this.rows,
      required this.favorites,
      required this.onSeeAll,
      required this.onTap,
      required this.onFavorite});

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(
            child: Text(title,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w900))),
        if (onSeeAll != null)
          TextButton(onPressed: onSeeAll, child: const Text('عرض الكل')),
      ]),
      const SizedBox(height: 8),
      if (rows.isEmpty)
        Container(
            height: 100,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: c.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(18)),
            child: const Text('لا توجد عروض في هذا القسم'))
      else
        SizedBox(
            height: 286,
            child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: rows.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (_, i) => _ListingCard(
                    row: rows[i],
                    isFavorite: favorites.contains(rows[i]['id'].toString()),
                    onTap: () => onTap(rows[i]),
                    onFavorite: () => onFavorite(rows[i]['id'].toString())))),
    ]);
  }
}

class _ListingGrid extends StatelessWidget {
  final List<Map<String, dynamic>> rows;
  final Set<String> favorites;
  final Future<void> Function(Map<String, dynamic>) onTap;
  final Future<void> Function(String) onFavorite;
  const _ListingGrid(
      {required this.rows,
      required this.favorites,
      required this.onTap,
      required this.onFavorite});
  @override
  Widget build(BuildContext context) => GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: rows.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 14,
            childAspectRatio: .64),
        itemBuilder: (_, i) => _ListingCard(
            row: rows[i],
            isFavorite: favorites.contains(rows[i]['id'].toString()),
            onTap: () => onTap(rows[i]),
            onFavorite: () => onFavorite(rows[i]['id'].toString())),
      );
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;
  const _SectionHeader({required this.title, required this.count});
  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(
            child: Text(title,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w900))),
        Text('$count عرض',
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant))
      ]);
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip(
      {required this.label, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: ChoiceChip(
          label: Text(label), selected: selected, onSelected: (_) => onTap()));
}

class CreateSwapListingPage extends StatefulWidget {
  const CreateSwapListingPage({super.key});
  @override
  State<CreateSwapListingPage> createState() => _CreateSwapListingPageState();
}

class _CreateSwapListingPageState extends State<CreateSwapListingPage> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _desc = TextEditingController();
  final _phone = TextEditingController();
  final _whatsapp = TextEditingController();
  final _repo = SwapRepository();
  final _picker = ImagePicker();
  static const _defaultCategories = [
    'إلكترونيات',
    'موبايلات',
    'كمبيوتر ولابتوب',
    'كاميرات',
    'أثاث',
    'ملابس',
    'أجهزة منزلية',
    'سيارات ومواصلات',
    'كتب وألعاب',
    'رياضة',
    'أخرى'
  ];
  final List<XFile> _images = [];
  final Map<String, Future<Uint8List>> _imagePreviewBytes = {};
  String? _governorate;
  String _condition = 'any';
  bool _busy = false;
  List<String> _categories = _defaultCategories;
  final List<String> _selectedCategories = [];

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final rows = await _repo.listSwapCategories();
      final names = rows
          .map((row) => row['name_ar']?.toString() ?? '')
          .where((name) => name.isNotEmpty)
          .toList();
      if (mounted && names.isNotEmpty) setState(() => _categories = names);
    } catch (_) {}
  }

  static const _governorates = [
    'القاهرة',
    'الجيزة',
    'الإسكندرية',
    'الدقهلية',
    'الشرقية',
    'القليوبية',
    'الغربية',
    'المنوفية',
    'البحيرة',
    'كفر الشيخ',
    'دمياط',
    'بورسعيد',
    'الإسماعيلية',
    'السويس',
    'الفيوم',
    'بني سويف',
    'المنيا',
    'أسيوط',
    'سوهاج',
    'قنا',
    'الأقصر',
    'أسوان',
    'مطروح',
    'شمال سيناء',
    'جنوب سيناء',
  ];

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    _phone.dispose();
    _whatsapp.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (_selectedCategories.isEmpty) {
      _toast(context, Exception('اختار تصنيفًا واحدًا على الأقل'));
      return;
    }
    try {
      SwapRepository.validateContactNumbers(
        contactPhone: _phone.text,
        contactWhatsapp: _whatsapp.text,
      );
    } catch (error) {
      _toast(context, error);
      return;
    }
    setState(() => _busy = true);
    final imageUrls = <String>[];
    var createAttempted = false;
    try {
      for (final image in _images) {
        imageUrls.add(await _repo.uploadListingImage(image));
      }
      createAttempted = true;
      await _repo.createListing(
        wantedTitle: _title.text,
        description: _desc.text,
        category: _selectedCategories.first,
        categories: _selectedCategories,
        wantedCondition: _condition,
        contactPhone: _phone.text,
        contactWhatsapp: _whatsapp.text,
        images: imageUrls,
        governorate: _governorate,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      // A known PostgREST rejection means no listing row was accepted. For
      // ambiguous transport failures, keep the files to avoid breaking a row
      // that may have committed before the connection dropped.
      if (!createAttempted || e is PostgrestException) {
        await _repo.removeUploadedListingImages(imageUrls);
      }
      if (mounted) _toast(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickImage() async {
    try {
      final images =
          await _picker.pickMultiImage(imageQuality: 82, maxWidth: 1600);
      if (!mounted || images.isEmpty) return;
      setState(() {
        final selected = images.take(6 - _images.length).toList();
        _images.addAll(selected);
        for (final image in selected) {
          _imagePreviewBytes.putIfAbsent(image.path, image.readAsBytes);
        }
      });
    } catch (error) {
      if (mounted) _toast(context, Exception('تعذر اختيار الصور، حاول مرة أخرى'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('إضافة استبدال')),
        body: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: c.primaryContainer,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Row(
                  children: [
                    Icon(Icons.campaign_rounded,
                        color: c.onPrimaryContainer, size: 34),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('اطلب الشيء الذي تريد الحصول عليه',
                              style: TextStyle(
                                  color: c.onPrimaryContainer,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900)),
                          const SizedBox(height: 5),
                          Text(
                            'اكتب تفاصيل واضحة، وسيتمكن المهتمون من التواصل معك مباشرة عبر الهاتف أو واتساب.',
                            style: TextStyle(
                                color: c.onPrimaryContainer, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              TextFormField(
                controller: _title,
                decoration: const InputDecoration(
                    labelText: 'ما الشيء المطلوب؟',
                    hintText: 'مثال: iPhone 11'),
                validator: (v) => v == null || v.trim().length < 3
                    ? 'اكتب الشيء المطلوب'
                    : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _desc,
                minLines: 4,
                maxLines: 7,
                decoration: const InputDecoration(
                    labelText: 'التفاصيل',
                    hintText:
                        'اشرح ما الذي ستقدمه أو حالة الشيء الذي تريد استبداله...'),
                validator: (v) => v == null || v.trim().length < 10
                    ? 'اكتب تفاصيل أكثر'
                    : null,
              ),
              const SizedBox(height: 14),
              InputDecorator(
                decoration: const InputDecoration(
                    labelText: 'التصنيفات',
                    prefixIcon: Icon(Icons.category_outlined),
                    alignLabelWithHint: true),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _categories
                      .map((category) => FilterChip(
                            label: Text(category),
                            selected: _selectedCategories.contains(category),
                            onSelected: (selected) => setState(() {
                              if (selected) {
                                _selectedCategories.add(category);
                              } else {
                                _selectedCategories.remove(category);
                              }
                            }),
                          ))
                      .toList(),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                    labelText: 'رقم الهاتف للتواصل', hintText: '01012345678'),
                validator: (v) =>
                    v == null || v.trim().length < 8 ? 'أدخل رقم الهاتف' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _whatsapp,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                    labelText: 'رقم واتساب', hintText: '01012345678'),
                validator: (v) => v == null || v.trim().length < 8
                    ? 'أدخل رقم الواتساب'
                    : null,
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                value: _governorate,
                decoration: const InputDecoration(
                    labelText: 'المحافظة',
                    prefixIcon: Icon(Icons.location_on_outlined)),
                items: _governorates
                    .map((value) =>
                        DropdownMenuItem(value: value, child: Text(value)))
                    .toList(),
                onChanged: (value) => setState(() => _governorate = value),
                validator: (value) => value == null ? 'اختار المحافظة' : null,
              ),
              const SizedBox(height: 14),
              InkWell(
                onTap: _busy ? null : _pickImage,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  height: 170,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: Theme.of(context).colorScheme.outline),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _images.isEmpty
                      ? const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                              Icon(Icons.add_a_photo_outlined, size: 38),
                              SizedBox(height: 8),
                              Text(
                                  'إضافة صور للشيء المراد استبداله (حتى 6 صور)'),
                            ])
                      : GridView.builder(
                          padding: const EdgeInsets.all(8),
                          itemCount: _images.length,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  crossAxisSpacing: 8,
                                  mainAxisSpacing: 8),
                          itemBuilder: (_, index) =>
                              Stack(fit: StackFit.expand, children: [
                            FutureBuilder<Uint8List>(
                              future: _imagePreviewBytes.putIfAbsent(
                                _images[index].path,
                                _images[index].readAsBytes,
                              ),
                              builder: (context, snapshot) {
                                if (snapshot.hasData) {
                                  return Image.memory(
                                    snapshot.data!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Center(
                                      child: Icon(Icons.broken_image_outlined),
                                    ),
                                  );
                                }
                                if (snapshot.hasError) {
                                  return const Center(
                                    child: Icon(Icons.broken_image_outlined),
                                  );
                                }
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              },
                            ),
                            Positioned(
                                top: 3,
                                right: 3,
                                child: InkWell(
                                    onTap: () =>
                                        setState(() {
                                          final removed = _images.removeAt(index);
                                          _imagePreviewBytes.remove(removed.path);
                                        }),
                                    child: const CircleAvatar(
                                        radius: 12,
                                        backgroundColor: Colors.black54,
                                        child: Icon(Icons.close,
                                            size: 15, color: Colors.white)))),
                          ]),
                        ),
                ),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                value: _condition,
                decoration: const InputDecoration(labelText: 'الحالة المطلوبة'),
                items: const [
                  DropdownMenuItem(value: 'any', child: Text('أي حالة')),
                  DropdownMenuItem(value: 'new', child: Text('جديد')),
                  DropdownMenuItem(value: 'like_new', child: Text('شبه جديد')),
                  DropdownMenuItem(value: 'good', child: Text('جيد')),
                  DropdownMenuItem(value: 'used', child: Text('مستعمل')),
                ],
                onChanged: (v) => setState(() => _condition = v ?? 'any'),
              ),
              const SizedBox(height: 28),
              FilledButton.icon(
                onPressed: _busy ? null : _save,
                icon: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.publish_rounded),
                label: const Text('نشر الاستبدال'),
                style: FilledButton.styleFrom(backgroundColor: c.primary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SwapDetailsPage extends StatefulWidget {
  final String listingId;
  const SwapDetailsPage({super.key, required this.listingId});
  @override
  State<SwapDetailsPage> createState() => _SwapDetailsPageState();
}

class _SwapDetailsPageState extends State<SwapDetailsPage> {
  final _repo = SwapRepository();
  late Future<Map<String, dynamic>> _future;
  bool _isFavorite = false;

  @override
  void initState() {
    super.initState();
    _future = _repo.getListing(widget.listingId);
    _loadFavorite();
  }

  Future<void> _loadFavorite() async {
    try {
      final ids = await _repo.favoriteListingIds();
      if (mounted) setState(() => _isFavorite = ids.contains(widget.listingId));
    } catch (_) {}
  }

  Future<void> _toggleFavorite() async {
    final next = !_isFavorite;
    setState(() => _isFavorite = next);
    try {
      await _repo.toggleFavorite(widget.listingId, next);
    } catch (_) {
      if (mounted) {
        setState(() => _isFavorite = !next);
        _toast(context, Exception('تعذر تحديث المفضلة'));
      }
    }
  }

  Future<void> _showReportDialog() async {
    final payload = await showModalBottomSheet<_SwapReportPayload>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _SwapReportSheet(),
    );
    if (payload == null || !mounted) return;
    try {
      await _repo.reportListing(
        listingId: widget.listingId,
        reason: payload.reason,
        details: payload.details,
      );
      if (mounted) {
        _toast(context, Exception('تم إرسال البلاغ للمراجعة'));
      }
    } catch (error) {
      if (mounted) {
        _toast(context, Exception(_reportErrorMessage(error)));
      }
    }
  }

  void _openGallery(List<String> images, int initialIndex) {
    if (images.isEmpty) return;
    Navigator.of(context).push(PageRouteBuilder<void>(
      opaque: false,
      barrierColor: Colors.black,
      transitionDuration: const Duration(milliseconds: 360),
      reverseTransitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (_, animation, __) => _FullScreenSwapGallery(
        images: images,
        initialIndex: initialIndex,
        listingId: widget.listingId,
      ),
      transitionsBuilder: (_, animation, __, child) => FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: child,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: c.surface,
        bottomNavigationBar: FutureBuilder<Map<String, dynamic>>(
          future: _future,
          builder: (context, snap) {
            if (!snap.hasData) return const SizedBox.shrink();
            final data = snap.data!;
            final owner = data['owner_id']?.toString() == _repo.currentUserId;
            final phone = data['contact_phone']?.toString();
            final whatsapp = data['contact_whatsapp']?.toString();
            if (owner || data['status'] != 'open' ||
                (phone?.trim().isEmpty ?? true) &&
                    (whatsapp?.trim().isEmpty ?? true)) {
              return const SizedBox.shrink();
            }
            return SafeArea(
              minimum: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              child: _ContactButtons(phone: phone, whatsapp: whatsapp),
            );
          },
        ),
        body: FutureBuilder<Map<String, dynamic>>(
          future: _future,
          builder: (context, snap) {
            if (!snap.hasData) {
              return Center(
                child: snap.hasError
                    ? const _StateMessage(title: 'تعذر تحميل التفاصيل')
                    : CircularProgressIndicator(color: c.primary),
              );
            }
            final r = snap.data!;
            final owner = r['owner_id']?.toString() == _repo.currentUserId;
            final images = (r['images'] as List? ?? [])
                .map((e) => e.toString())
                .where((e) => e.trim().isNotEmpty)
                .toList();
            final listingCategories = ((r['categories'] as List?)
                        ?.map((e) => e.toString())
                        .toList() ??
                    <String>[])
                .where((e) => e.trim().isNotEmpty)
                .toList();
            if (listingCategories.isEmpty && r['category'] != null) {
              listingCategories.add(r['category'].toString());
            }
            final user = r['users'] as Map?;
            final title = r['wanted_title']?.toString() ?? 'عرض استبدال';
            final location = r['city']?.toString().trim().isNotEmpty == true
                ? r['city'].toString()
                : (r['governorate']?.toString() ?? 'الموقع غير محدد');
            return CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverAppBar(
                  expandedHeight: 390,
                  pinned: true,
                  elevation: 0,
                  backgroundColor: c.surface,
                  foregroundColor: Colors.white,
                  leading: _GlassIconButton(
                    icon: Icons.arrow_forward_rounded,
                    onPressed: () => Navigator.pop(context),
                  ),
                  actions: [
                    if (!owner)
                      _GlassIconButton(
                        icon: Icons.flag_outlined,
                        onPressed: _showReportDialog,
                      ),
                    _GlassIconButton(
                      icon: _isFavorite
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      iconColor: _isFavorite ? Colors.redAccent : Colors.white,
                      onPressed: _toggleFavorite,
                    ),
                    const SizedBox(width: 10),
                  ],
                  flexibleSpace: FlexibleSpaceBar(
                    collapseMode: CollapseMode.parallax,
                    background: _DetailHero(
                      images: images,
                      category: r['category']?.toString() ?? 'استبدال',
                      isFavorite: _isFavorite,
                      onFavorite: _toggleFavorite,
                      listingId: widget.listingId,
                      onImageTap: _openGallery,
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: .94, end: 1),
                    duration: const Duration(milliseconds: 520),
                    curve: Curves.easeOutCubic,
                    builder: (_, value, child) => Opacity(
                      opacity: ((value - .94) / .06).clamp(0, 1).toDouble(),
                      child: Transform.translate(
                        offset: Offset(0, 18 * (1 - value) / .06),
                        child: child,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 22, 20, 30),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title,
                              style: const TextStyle(
                                  fontSize: 30,
                                  fontWeight: FontWeight.w900,
                                  height: 1.12)),
                          const SizedBox(height: 10),
                          Row(children: [
                            Icon(Icons.location_on_rounded,
                                size: 20, color: c.primary),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(location,
                                  style: TextStyle(
                                      color: c.onSurfaceVariant,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600)),
                            ),
                            _InfoPill(
                                icon: Icons.swap_horizontal_circle_rounded,
                                label: 'استبدال'),
                          ]),
                          const SizedBox(height: 22),
                          _OwnerCard(user: user, location: location),
                          const SizedBox(height: 24),
                          _DetailsSection(
                            title: 'عن العرض',
                            child: Text(
                              r['description']?.toString() ?? '',
                              style: TextStyle(
                                  color: c.onSurface,
                                  fontSize: 17,
                                  height: 1.65),
                            ),
                          ),
                          _DetailsSection(
                            title: 'الحالة المطلوبة',
                            child: _ConditionBadge(
                                label: _conditionLabel(
                                    r['wanted_condition']?.toString())),
                          ),
                          _DetailsSection(
                            title: 'التصنيف',
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: listingCategories
                                  .map((category) => Chip(
                                        label: Text(category),
                                        avatar: const Icon(
                                            Icons.category_outlined,
                                            size: 17),
                                      ))
                                  .toList(),
                            ),
                          ),
                          if (!owner &&
                              ((r['contact_phone']?.toString().trim().isNotEmpty ??
                                      false) ||
                                  (r['contact_whatsapp']
                                          ?.toString()
                                          .trim()
                                          .isNotEmpty ??
                                      false)))
                            _ContactHint(name: user?['name']?.toString()),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DetailHero extends StatefulWidget {
  final List<String> images;
  final String category;
  final bool isFavorite;
  final VoidCallback onFavorite;
  final String listingId;
  final void Function(List<String>, int) onImageTap;
  const _DetailHero({
    required this.images,
    required this.category,
    required this.isFavorite,
    required this.onFavorite,
    required this.listingId,
    required this.onImageTap,
  });

  @override
  State<_DetailHero> createState() => _DetailHeroState();
}

class _DetailHeroState extends State<_DetailHero> {
  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final images = widget.images;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
      child: Stack(fit: StackFit.expand, children: [
        if (images.isEmpty)
          _fallback(c)
        else
          PageView.builder(
            controller: _controller,
            itemCount: images.length,
            onPageChanged: (value) => setState(() => _index = value),
            itemBuilder: (context, index) => GestureDetector(
              onTap: () => widget.onImageTap(images, index),
              child: Hero(
                tag: 'swap-image-${widget.listingId}-$index',
                child: CachedNetworkImage(
                  imageUrl: images[index],
                  fit: BoxFit.cover,
                  memCacheWidth: 1400,
                  maxWidthDiskCache: 1400,
                  placeholder: (_, __) => Container(
                    color: c.surfaceContainerHighest,
                    alignment: Alignment.center,
                    child: CircularProgressIndicator(color: c.primary),
                  ),
                  errorWidget: (_, __, ___) => _fallback(c),
                ),
              ),
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
                    Colors.black.withValues(alpha: .38),
                    Colors.transparent,
                    Colors.black.withValues(alpha: .70),
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 18,
          bottom: 20,
          child: _HeroPill(
            icon: widget.isFavorite
                ? Icons.favorite_rounded
                : Icons.favorite_border_rounded,
            label: 'المفضلة',
            color: widget.isFavorite ? Colors.redAccent : Colors.white,
            onTap: widget.onFavorite,
          ),
        ),
        Positioned(
          right: 18,
          bottom: 20,
          child: _HeroPill(
            icon: Icons.category_rounded,
            label: widget.category,
            onTap: images.isEmpty
                ? null
                : () => widget.onImageTap(images, _index),
          ),
        ),
        if (images.length > 1)
          Positioned(
            bottom: 78,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                images.length,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: index == _index ? 22 : 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: index == _index ? Colors.white : Colors.white54,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ),
        if (images.isNotEmpty)
          const Positioned(
            top: 78,
            left: 18,
            child: _ImageHint(),
          ),
      ]),
    );
  }

  Widget _fallback(ColorScheme c) => Container(
        color: c.surfaceContainerHighest,
        alignment: Alignment.center,
        child: Icon(Icons.swap_horiz_rounded,
            size: 80, color: c.onSurfaceVariant),
      );
}

class _FullScreenSwapGallery extends StatefulWidget {
  final List<String> images;
  final int initialIndex;
  final String listingId;
  const _FullScreenSwapGallery({
    required this.images,
    required this.initialIndex,
    required this.listingId,
  });

  @override
  State<_FullScreenSwapGallery> createState() => _FullScreenSwapGalleryState();
}

class _FullScreenSwapGalleryState extends State<_FullScreenSwapGallery> {
  late final PageController _controller;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(children: [
          PageView.builder(
            controller: _controller,
            itemCount: widget.images.length,
            onPageChanged: (value) => setState(() => _index = value),
            itemBuilder: (_, index) => Center(
              child: Hero(
                tag: 'swap-image-${widget.listingId}-$index',
                child: InteractiveViewer(
                  minScale: .8,
                  maxScale: 4,
                  child: CachedNetworkImage(
                    imageUrl: widget.images[index],
                    fit: BoxFit.contain,
                    placeholder: (_, __) => const CircularProgressIndicator(
                        color: Colors.white),
                    errorWidget: (_, __, ___) => const Icon(
                        Icons.broken_image_outlined,
                        color: Colors.white54,
                        size: 56),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 12,
            right: 14,
            child: _GlassIconButton(
              icon: Icons.close_rounded,
              onPressed: () => Navigator.pop(context),
            ),
          ),
          Positioned(
            top: 22,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('${_index + 1} / ${widget.images.length}',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w700)),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _ContactButtons extends StatelessWidget {
  final String? phone;
  final String? whatsapp;
  const _ContactButtons({this.phone, this.whatsapp});

  @override
  Widget build(BuildContext context) {
    final hasPhone = phone?.trim().isNotEmpty ?? false;
    final hasWhatsapp = whatsapp?.trim().isNotEmpty ?? false;
    return Row(children: [
      if (hasWhatsapp)
        Expanded(
          child: FilledButton.icon(
            onPressed: () => _launchWhatsapp(context, whatsapp!),
            icon: const Icon(Icons.chat_rounded),
            label: const Text('واتساب'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
              backgroundColor: const Color(0xFF25D366),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18)),
            ),
          ),
        ),
      if (hasWhatsapp && hasPhone) const SizedBox(width: 10),
      if (hasPhone)
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _launchPhone(context, phone!),
            icon: const Icon(Icons.phone_rounded),
            label: const Text('اتصال'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
              foregroundColor: Theme.of(context).colorScheme.primary,
              side: BorderSide(
                  color: Theme.of(context).colorScheme.primary, width: 1.5),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18)),
            ),
          ),
        ),
    ]);
  }
}

class _SwapReportPayload {
  final String reason;
  final String? details;
  const _SwapReportPayload({required this.reason, this.details});
}

class _SwapReportSheet extends StatefulWidget {
  const _SwapReportSheet();

  @override
  State<_SwapReportSheet> createState() => _SwapReportSheetState();
}

class _SwapReportSheetState extends State<_SwapReportSheet> {
  final _details = TextEditingController();
  String _reason = 'fraud';

  static const _reasons = <String, String>{
    'fraud': 'إعلان مضلل أو احتيالي',
    'inappropriate': 'محتوى غير مناسب',
    'wrong_contact': 'رقم التواصل غير صحيح',
    'duplicate': 'إعلان مكرر',
    'other': 'سبب آخر',
  };

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            18, 4, 18, MediaQuery.viewInsetsOf(context).bottom + 18),
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('الإبلاغ عن الإعلان',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text('اختار السبب وسيتم مراجعة البلاغ من الإدارة.',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 16),
            ..._reasons.entries.map((entry) => RadioListTile<String>(
                  value: entry.key,
                  groupValue: _reason,
                  contentPadding: EdgeInsets.zero,
                  title: Text(entry.value),
                  onChanged: (value) {
                    if (value != null) setState(() => _reason = value);
                  },
                )),
            TextField(
              controller: _details,
              maxLines: 3,
              maxLength: 500,
              decoration: const InputDecoration(
                  labelText: 'تفاصيل إضافية (اختياري)',
                  alignLabelWithHint: true),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => Navigator.pop(
                    context,
                    _SwapReportPayload(
                        reason: _reason, details: _details.text)),
                icon: const Icon(Icons.send_rounded),
                label: const Text('إرسال البلاغ'),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

String _reportErrorMessage(Object error) {
  final message = error.toString().toLowerCase();
  if (message.contains('duplicate') || message.contains('unique')) {
    return 'تم إرسال بلاغ على هذا الإعلان من قبل';
  }
  if (message.contains('permission') || message.contains('42501')) {
    return 'لا يمكنك الإبلاغ عن هذا الإعلان حاليًا';
  }
  return 'تعذر إرسال البلاغ، حاول مرة أخرى';
}

class _OwnerCard extends StatelessWidget {
  final Map? user;
  final String location;
  const _OwnerCard({required this.user, required this.location});

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final avatar = user?['avatar_url']?.toString() ?? '';
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: c.primaryContainer.withValues(alpha: .42),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: c.primary.withValues(alpha: .12)),
      ),
      child: Row(children: [
        CircleAvatar(
          radius: 27,
          backgroundColor: c.primary,
          backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
          child: avatar.isEmpty
              ? Icon(Icons.person_rounded, color: c.onPrimary, size: 29)
              : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(user?['name']?.toString() ?? 'صاحب الإعلان',
                style:
                    const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
            const SizedBox(height: 3),
            Text(location,
                style: TextStyle(color: c.onSurfaceVariant, fontSize: 13)),
          ]),
        ),
        Icon(Icons.verified_rounded, color: c.primary, size: 22),
      ]),
    );
  }
}

class _ContactHint extends StatelessWidget {
  final String? name;
  const _ContactHint({this.name});

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surfaceContainerHighest.withValues(alpha: .72),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(children: [
        Icon(Icons.touch_app_rounded, color: c.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'تواصل مع ${name?.isNotEmpty == true ? name : 'صاحب الإعلان'} من الزرين أسفل الشاشة.',
            style: TextStyle(color: c.onSurfaceVariant, height: 1.35),
          ),
        ),
      ]),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
          color: c.primaryContainer, borderRadius: BorderRadius.circular(18)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: c.onPrimaryContainer),
        const SizedBox(width: 5),
        Text(label,
            style: TextStyle(
                color: c.onPrimaryContainer,
                fontSize: 12,
                fontWeight: FontWeight.w800)),
      ]),
    );
  }
}

class _ConditionBadge extends StatelessWidget {
  final String label;
  const _ConditionBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
      decoration: BoxDecoration(
          color: c.secondaryContainer,
          borderRadius: BorderRadius.circular(15)),
      child: Text(label,
          style: TextStyle(
              color: c.onSecondaryContainer,
              fontSize: 16,
              fontWeight: FontWeight.w800)),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final VoidCallback onPressed;
  const _GlassIconButton(
      {required this.icon, required this.onPressed, this.iconColor});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: .38),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, color: iconColor ?? Colors.white, size: 23),
        ),
      ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  const _HeroPill(
      {required this.icon,
      required this.label,
      this.color = Colors.white,
      this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: .58),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: color, size: 21),
            const SizedBox(width: 7),
            Text(label,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w800)),
          ]),
        ),
      ),
    );
  }
}

class _ImageHint extends StatelessWidget {
  const _ImageHint();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: .42),
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.touch_app_rounded, color: Colors.white, size: 16),
          SizedBox(width: 5),
          Text('اضغط لتكبير الصورة',
              style: TextStyle(color: Colors.white, fontSize: 11)),
        ]),
      );
}

class _DetailsSection extends StatelessWidget {
  final String title;
  final Widget child;
  const _DetailsSection({required this.title, required this.child});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 16,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 9),
          child,
        ]),
      );
}

Future<void> _launchPhone(BuildContext context, String value) async {
  final phone = value.replaceAll(RegExp(r'[^0-9+]'), '');
  final uri = Uri.parse('tel:$phone');
  if (!await canLaunchUrl(uri) || !await launchUrl(uri)) {
    if (context.mounted) _toast(context, Exception('تعذر فتح تطبيق الاتصال'));
  }
}

Future<void> _launchWhatsapp(BuildContext context, String value) async {
  var phone = value.replaceAll(RegExp(r'[^0-9]'), '');
  if (phone.startsWith('0')) phone = '20${phone.substring(1)}';
  if (!phone.startsWith('20') && phone.length == 10) phone = '20$phone';
  final uri = Uri.parse('https://wa.me/$phone');
  if (!await canLaunchUrl(uri) ||
      !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
    if (context.mounted) _toast(context, Exception('تعذر فتح واتساب'));
  }
}

class MySwapsPage extends StatefulWidget {
  const MySwapsPage({super.key});
  @override
  State<MySwapsPage> createState() => _MySwapsPageState();
}

class _MySwapsPageState extends State<MySwapsPage>
    with SingleTickerProviderStateMixin {
  final _repo = SwapRepository();
  late final TabController _tabs;
  late Future<List<Map<String, dynamic>>> _listings;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _load();
  }

  void _load() {
    _listings = _repo.myListings();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('استبدالاتي',
              style: TextStyle(fontWeight: FontWeight.w900)),
          bottom: TabBar(
              controller: _tabs,
              tabs: const [Tab(text: 'النشطة'), Tab(text: 'المنتهية')]),
        ),
        body: TabBarView(controller: _tabs, children: [
          _MyListingList(
              future: _listings, ended: false, repo: _repo, reload: _load),
          _MyListingList(
              future: _listings, ended: true, repo: _repo, reload: _load),
        ]),
      ),
    );
  }
}

class _MyListingList extends StatelessWidget {
  final Future<List<Map<String, dynamic>>> future;
  final bool ended;
  final SwapRepository repo;
  final VoidCallback reload;
  const _MyListingList(
      {required this.future,
      required this.ended,
      required this.repo,
      required this.reload});

  bool _isEnded(Map<String, dynamic> row) {
    final expires = DateTime.tryParse(row['expires_at']?.toString() ?? '');
    return row['status'] != 'open' ||
        (expires != null && !expires.isAfter(DateTime.now().toUtc()));
  }

  @override
  Widget build(BuildContext context) =>
      FutureBuilder<List<Map<String, dynamic>>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting)
            return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError)
            return const _StateMessage(title: 'تعذر تحميل استبدالاتك');
          final rows =
              (snapshot.data ?? []).where((r) => _isEnded(r) == ended).toList();
          if (rows.isEmpty)
            return _StateMessage(
                title: ended
                    ? 'لا توجد استبدالات منتهية'
                    : 'لا توجد استبدالات نشطة');
          return GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
            itemCount: rows.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 14,
                childAspectRatio: .54),
            itemBuilder: (context, index) => _MySwapCard(
                row: rows[index], ended: ended, repo: repo, reload: reload),
          );
        },
      );
}

class _MySwapCard extends StatelessWidget {
  final Map<String, dynamic> row;
  final bool ended;
  final SwapRepository repo;
  final VoidCallback reload;
  const _MySwapCard(
      {required this.row,
      required this.ended,
      required this.repo,
      required this.reload});

  Future<bool> _confirm(BuildContext context,
      {required String title,
      required String message,
      required String action}) async {
    return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('رجوع')),
              FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(action)),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final images =
        (row['images'] as List? ?? []).map((e) => e.toString()).toList();
    final title = row['wanted_title']?.toString() ?? 'استبدال';
    final location = row['city']?.toString().trim().isNotEmpty == true
        ? row['city'].toString()
        : (row['governorate']?.toString() ?? 'المحافظة غير محددة');
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: Stack(fit: StackFit.expand, children: [
            images.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: images.first,
                    fit: BoxFit.cover,
                    memCacheWidth: 720,
                    maxWidthDiskCache: 720,
                    placeholder: (_, __) => _fallback(c),
                    errorWidget: (_, __, ___) => _fallback(c))
                : _fallback(c),
            Positioned.fill(
                child: DecoratedBox(
                    decoration: BoxDecoration(
                        gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: .84)
                ])))),
            Positioned(
                top: 9,
                right: 9,
                child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                        color: ended
                            ? Colors.black.withValues(alpha: .62)
                            : const Color(0xFF9BEA65),
                        borderRadius: BorderRadius.circular(20)),
                    child: Text(ended ? 'منتهي' : 'نشط',
                        style: TextStyle(
                            color: ended ? Colors.white : Colors.black,
                            fontSize: 11,
                            fontWeight: FontWeight.w800)))),
            Positioned(
                left: 10,
                right: 10,
                bottom: 10,
                child: Text(title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w900))),
          ]),
        ),
        Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 2),
            child: Text(
                '$location • ${_conditionLabel(row['wanted_condition']?.toString())}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: c.onSurfaceVariant,
                    fontSize: 11,
                    fontWeight: FontWeight.w700))),
        Padding(
            padding: const EdgeInsets.fromLTRB(7, 4, 7, 7),
            child: Row(children: [
              Expanded(
                  child: TextButton.icon(
                      onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => SwapDetailsPage(
                                  listingId: row['id'].toString()))),
                      icon: const Icon(Icons.open_in_new_rounded, size: 16),
                      label: const Text('التفاصيل'),
                      style: TextButton.styleFrom(padding: EdgeInsets.zero))),
              PopupMenuButton<String>(
                tooltip: 'إجراءات',
                onSelected: (value) async {
                  if (value == 'cancel' &&
                      await _confirm(context,
                          title: 'إلغاء الاستبدال؟',
                          message:
                              'سيتم إغلاق الإعلان ولن يستطيع أحد إرسال عرض جديد عليه.',
                          action: 'إلغاء الاستبدال')) {
                    await repo.closeListing(row['id'].toString());
                    reload();
                  }
                  if (value == 'hide' &&
                      await _confirm(context,
                          title: 'إخفاء الاستبدال؟',
                          message:
                              'سيختفي الإعلان من استبدالاتك فقط ولن يتم حذفه من قاعدة البيانات.',
                          action: 'إخفاء')) {
                    await repo.hideListing(row['id'].toString());
                    reload();
                  }
                },
                itemBuilder: (_) => [
                  if (!ended)
                    const PopupMenuItem(
                        value: 'cancel', child: Text('إلغاء الاستبدال')),
                  if (ended)
                    const PopupMenuItem(
                        value: 'hide', child: Text('إخفاء من قائمتي')),
                ],
                icon: const Icon(Icons.more_horiz_rounded),
              ),
            ])),
      ]),
    );
  }

  Widget _fallback(ColorScheme c) => Container(
      color: c.surfaceContainerHighest,
      alignment: Alignment.center,
      child:
          Icon(Icons.swap_horiz_rounded, size: 48, color: c.onSurfaceVariant));
}

Widget _asyncList(Future<List<Map<String, dynamic>>> future,
        Widget Function(Map<String, dynamic>) item) =>
    FutureBuilder<List<Map<String, dynamic>>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError)
          return const _StateMessage(title: 'تعذر تحميل البيانات');
        final rows = snapshot.data ?? [];
        return rows.isEmpty
            ? const _StateMessage(title: 'لا توجد استبدالات هنا')
            : ListView(
                padding: const EdgeInsets.all(16),
                children: rows.map(item).toList());
      },
    );

class _ListingCard extends StatelessWidget {
  final Map<String, dynamic> row;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback onFavorite;
  const _ListingCard(
      {required this.row,
      required this.isFavorite,
      required this.onTap,
      required this.onFavorite});

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final images =
        (row['images'] as List? ?? []).map((e) => e.toString()).toList();
    final user = row['users'] as Map?;
    final title = row['wanted_title']?.toString() ?? 'استبدال جديد';
    final location = row['city']?.toString().trim().isNotEmpty == true
        ? row['city'].toString()
        : (row['governorate']?.toString() ?? 'الموقع غير محدد');
    final condition = _conditionLabel(row['wanted_condition']?.toString());
    return SizedBox(
      width: 184,
      height: 276,
      child: Card(
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
        child: InkWell(
          onTap: onTap,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Stack(fit: StackFit.expand, children: [
                images.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: images.first,
                        fit: BoxFit.cover,
                        memCacheWidth: 720,
                        maxWidthDiskCache: 720,
                        fadeInDuration: const Duration(milliseconds: 120),
                        placeholder: (_, __) => _imageFallback(c),
                        errorWidget: (_, __, ___) => _imageFallback(c))
                    : _imageFallback(c),
                Positioned.fill(
                    child: DecoratedBox(
                        decoration: BoxDecoration(
                            gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: .82)
                    ])))),
                Positioned(
                    top: 10,
                    right: 10,
                    child: Material(
                        color: Colors.black.withValues(alpha: .58),
                        shape: const CircleBorder(),
                        child: InkWell(
                            onTap: onFavorite,
                            customBorder: const CircleBorder(),
                            child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: Icon(
                                    isFavorite
                                        ? Icons.favorite_rounded
                                        : Icons.favorite_border_rounded,
                                    color: isFavorite
                                        ? Colors.redAccent
                                        : Colors.white,
                                    size: 20))))),
                Positioned(
                    left: 10,
                    right: 10,
                    bottom: 10,
                    child: Text(title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 17,
                            height: 1.15))),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 9),
              child: Row(children: [
                CircleAvatar(
                    radius: 13,
                    backgroundImage:
                        (user?['avatar_url']?.toString().isNotEmpty == true)
                            ? NetworkImage(user!['avatar_url'].toString())
                            : null,
                    backgroundColor: c.primaryContainer,
                    child: (user?['avatar_url']?.toString().isNotEmpty == true)
                        ? null
                        : Icon(Icons.person_rounded,
                            size: 15, color: c.onPrimaryContainer)),
                const SizedBox(width: 6),
                Expanded(
                    child: Text('$location • $condition',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: c.onSurfaceVariant,
                            fontSize: 11,
                            fontWeight: FontWeight.w700))),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _imageFallback(ColorScheme c) => Container(
      color: c.surfaceContainerHighest,
      alignment: Alignment.center,
      child:
          Icon(Icons.swap_horiz_rounded, size: 52, color: c.onSurfaceVariant));
}

class _IntroCard extends StatelessWidget {
  final Color color;
  const _IntroCard({required this.color});
  @override
  Widget build(BuildContext context) => Card(
        color: color,
        child: const Padding(
          padding: EdgeInsets.all(20),
          child: Row(children: [
            Icon(Icons.swap_horizontal_circle_rounded,
                color: Colors.white, size: 42),
            SizedBox(width: 14),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('استبدل بدل ما تشتري',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900)),
                  SizedBox(height: 5),
                  Text('انشر ما تريد، واستقبل عروضًا من المجتمع.',
                      style: TextStyle(color: Colors.white70)),
                ])),
          ]),
        ),
      );
}

class _StateMessage extends StatelessWidget {
  final String title;
  final VoidCallback? onRetry;
  const _StateMessage({required this.title, this.onRetry});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(40),
        child: Column(children: [
          Icon(Icons.swap_horizontal_circle_outlined,
              size: 52, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 12),
          Text(title, textAlign: TextAlign.center),
          if (onRetry != null)
            TextButton(onPressed: onRetry, child: const Text('إعادة المحاولة')),
        ]),
      );
}

String _conditionLabel(String? v) =>
    {
      'any': 'أي حالة',
      'new': 'جديد',
      'like_new': 'شبه جديد',
      'good': 'جيد',
      'used': 'مستعمل',
      'needs_repair': 'يحتاج إصلاح'
    }[v] ??
    'غير محدد';
String _statusLabel(Object? v) =>
    {
      'pending': 'في الانتظار',
      'accepted': 'مقبول',
      'rejected': 'مرفوض',
      'withdrawn': 'مسحوب',
      'open': 'مفتوح',
      'closed': 'مغلق',
      'cancelled': 'ملغي',
      'expired': 'منتهي'
    }[v?.toString()] ??
    'غير معروف';
void _toast(BuildContext context, Object e) =>
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
