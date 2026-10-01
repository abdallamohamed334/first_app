import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:loqma/features/swap/data/swap_repository.dart';
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
  const _SwapFeed({required this.nearby, required this.spotlight, required this.recent, required this.favorites});
}

class _SwapListingsPageState extends State<SwapListingsPage> {
  final _repo = SwapRepository();
  final _search = TextEditingController();
  static const _defaultCategories = ['إلكترونيات', 'موبايلات', 'كمبيوتر ولابتوب', 'كاميرات', 'أثاث', 'ملابس', 'أجهزة منزلية', 'سيارات ومواصلات', 'كتب وألعاب', 'رياضة', 'أخرى'];
  static const _governorates = [
    'القاهرة', 'الجيزة', 'الإسكندرية', 'الدقهلية', 'الشرقية', 'القليوبية',
    'الغربية', 'المنوفية', 'البحيرة', 'كفر الشيخ', 'دمياط', 'بورسعيد',
    'الإسماعيلية', 'السويس', 'الفيوم', 'بني سويف', 'المنيا', 'أسيوط',
    'سوهاج', 'قنا', 'الأقصر', 'أسوان', 'مطروح', 'شمال سيناء', 'جنوب سيناء',
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
      final names = rows.map((row) => row['name_ar']?.toString() ?? '').where((name) => name.isNotEmpty).toList();
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
    final rows = await _repo.listOpenListings(search: _search.text, governorate: _governorate);
    final nearby = await _repo.listNearbyOpenListings(search: _search.text, governorate: _governorate);
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
      final categories = (row['categories'] as List? ?? const []).map((value) => value.toString()).toSet();
      return categories.contains(_category) || row['category']?.toString() == _category;
    }).toList();
  }

  void _reload() => setState(() => _future = _load());

  Future<void> _openListing(Map<String, dynamic> row) async {
    await _repo.recordListingView(row['id'].toString());
    if (!mounted) return;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => SwapDetailsPage(listingId: row['id'].toString())));
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
          title: const Text('عروض الاستبدال', style: TextStyle(fontWeight: FontWeight.w900)),
          actions: [
            IconButton(
              tooltip: 'استبدالاتي',
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MySwapsPage())),
              icon: const Icon(Icons.swap_horizontal_circle_rounded),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () async {
            final ok = await Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateSwapListingPage()));
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
              if (snap.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator(color: c.primary));
              if (snap.hasError) return ListView(children: [const SizedBox(height: 180), _StateMessage(title: 'تعذر تحميل عروض الاستبدال', onRetry: _reload)]);
              final feed = snap.data ?? const _SwapFeed(nearby: [], spotlight: [], recent: [], favorites: {});
              final all = _unique([...feed.nearby, ...feed.spotlight]);
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
                children: [
                  Text('استبدلها بدل ما تشتريها', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 5),
                  Text('اكتشف عروضًا قريبة منك وقدم عرضك بسهولة', style: TextStyle(color: c.onSurfaceVariant)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _search,
                    onSubmitted: (_) => _reload(),
                    textInputAction: TextInputAction.search,
                    decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'ابحث عن المنتج أو الشيء المطلوب'),
                  ),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: DropdownButtonFormField<String>(
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
                      items: _governorates.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                      onChanged: _setGovernorate,
                    )),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(onPressed: () { _showAll = !_showAll; setState(() {}); }, icon: Icon(_showAll ? Icons.view_carousel_outlined : Icons.grid_view_rounded), tooltip: 'تغيير طريقة العرض'),
                  ]),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 42,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _FilterChip(label: 'الكل', selected: _category == null, onTap: () { _category = null; _reload(); }),
                        ..._categories.map((category) => _FilterChip(label: category, selected: _category == category, onTap: () { _category = category; _reload(); })),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  if (_showAll) ...[
                    _SectionHeader(title: 'كل عروض الاستبدال', count: all.length),
                    const SizedBox(height: 10),
                    if (all.isEmpty) const _StateMessage(title: 'لا توجد عروض مطابقة للبحث') else _ListingGrid(rows: all, favorites: feed.favorites, onTap: _openListing, onFavorite: (id) => _toggleFavorite(feed, id)),
                  ] else ...[
                    _SwapSection(title: 'عروض قريبة منك', rows: feed.nearby, favorites: feed.favorites, onSeeAll: () { _showAll = true; setState(() {}); }, onTap: _openListing, onFavorite: (id) => _toggleFavorite(feed, id)),
                    const SizedBox(height: 26),
                    _SwapSection(title: 'عروض مميزة', rows: feed.spotlight.take(12).toList(), favorites: feed.favorites, onSeeAll: () { _showAll = true; setState(() {}); }, onTap: _openListing, onFavorite: (id) => _toggleFavorite(feed, id)),
                    if (feed.recent.isNotEmpty) ...[
                      const SizedBox(height: 26),
                      _SwapSection(title: 'شاهدتها مؤخرًا', rows: feed.recent, favorites: feed.favorites, onSeeAll: null, onTap: _openListing, onFavorite: (id) => _toggleFavorite(feed, id)),
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
    setState(() {
      _governorate = value;
      _future = _load();
    });
  }
}

class _SwapSection extends StatelessWidget {
  final String title;
  final List<Map<String, dynamic>> rows;
  final Set<String> favorites;
  final VoidCallback? onSeeAll;
  final Future<void> Function(Map<String, dynamic>) onTap;
  final Future<void> Function(String) onFavorite;
  const _SwapSection({required this.title, required this.rows, required this.favorites, required this.onSeeAll, required this.onTap, required this.onFavorite});

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900))),
        if (onSeeAll != null) TextButton(onPressed: onSeeAll, child: const Text('عرض الكل')),
      ]),
      const SizedBox(height: 8),
      if (rows.isEmpty)
        Container(height: 100, alignment: Alignment.center, decoration: BoxDecoration(color: c.surfaceContainerHighest, borderRadius: BorderRadius.circular(18)), child: const Text('لا توجد عروض في هذا القسم'))
      else
        SizedBox(height: 286, child: ListView.separated(scrollDirection: Axis.horizontal, itemCount: rows.length, separatorBuilder: (_, __) => const SizedBox(width: 12), itemBuilder: (_, i) => _ListingCard(row: rows[i], isFavorite: favorites.contains(rows[i]['id'].toString()), onTap: () => onTap(rows[i]), onFavorite: () => onFavorite(rows[i]['id'].toString())))),
    ]);
  }
}

class _ListingGrid extends StatelessWidget {
  final List<Map<String, dynamic>> rows;
  final Set<String> favorites;
  final Future<void> Function(Map<String, dynamic>) onTap;
  final Future<void> Function(String) onFavorite;
  const _ListingGrid({required this.rows, required this.favorites, required this.onTap, required this.onFavorite});
  @override
  Widget build(BuildContext context) => GridView.builder(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    itemCount: rows.length,
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 14, childAspectRatio: .64),
    itemBuilder: (_, i) => _ListingCard(row: rows[i], isFavorite: favorites.contains(rows[i]['id'].toString()), onTap: () => onTap(rows[i]), onFavorite: () => onFavorite(rows[i]['id'].toString())),
  );
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;
  const _SectionHeader({required this.title, required this.count});
  @override
  Widget build(BuildContext context) => Row(children: [Expanded(child: Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900))), Text('$count عرض', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant))]);
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsetsDirectional.only(end: 8), child: ChoiceChip(label: Text(label), selected: selected, onSelected: (_) => onTap()));
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
  static const _defaultCategories = ['إلكترونيات', 'موبايلات', 'كمبيوتر ولابتوب', 'كاميرات', 'أثاث', 'ملابس', 'أجهزة منزلية', 'سيارات ومواصلات', 'كتب وألعاب', 'رياضة', 'أخرى'];
  final List<XFile> _images = [];
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
      final names = rows.map((row) => row['name_ar']?.toString() ?? '').where((name) => name.isNotEmpty).toList();
      if (mounted && names.isNotEmpty) setState(() => _categories = names);
    } catch (_) {}
  }

  static const _governorates = [
    'القاهرة', 'الجيزة', 'الإسكندرية', 'الدقهلية', 'الشرقية', 'القليوبية',
    'الغربية', 'المنوفية', 'البحيرة', 'كفر الشيخ', 'دمياط', 'بورسعيد',
    'الإسماعيلية', 'السويس', 'الفيوم', 'بني سويف', 'المنيا', 'أسيوط',
    'سوهاج', 'قنا', 'الأقصر', 'أسوان', 'مطروح', 'شمال سيناء', 'جنوب سيناء',
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
    setState(() => _busy = true);
    try {
      final imageUrls = <String>[];
      for (final image in _images) {
        imageUrls.add(await _repo.uploadListingImage(image));
      }
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
      if (mounted) _toast(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickImage() async {
    final images = await _picker.pickMultiImage(imageQuality: 82, maxWidth: 1600);
    if (!mounted || images.isEmpty) return;
    setState(() => _images.addAll(images.take(6 - _images.length)));
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
              const Text('اطلب الشيء الذي تريد الحصول عليه', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              const Text('مثال: أريد استبدال لابتوب قديم بآيفون 11. سيظهر إعلانك لكل المستخدمين.'),
              const SizedBox(height: 22),
              TextFormField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'ما الشيء المطلوب؟', hintText: 'مثال: iPhone 11'),
                validator: (v) => v == null || v.trim().length < 3 ? 'اكتب الشيء المطلوب' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _desc,
                minLines: 4,
                maxLines: 7,
                decoration: const InputDecoration(labelText: 'التفاصيل', hintText: 'اشرح ما الذي ستقدمه أو حالة الشيء الذي تريد استبداله...'),
                validator: (v) => v == null || v.trim().length < 10 ? 'اكتب تفاصيل أكثر' : null,
              ),
              const SizedBox(height: 14),
              InputDecorator(
                decoration: const InputDecoration(labelText: 'التصنيفات', prefixIcon: Icon(Icons.category_outlined), alignLabelWithHint: true),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _categories.map((category) => FilterChip(
                    label: Text(category),
                    selected: _selectedCategories.contains(category),
                    onSelected: (selected) => setState(() {
                      if (selected) {
                        _selectedCategories.add(category);
                      } else {
                        _selectedCategories.remove(category);
                      }
                    }),
                  )).toList(),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'رقم الهاتف للتواصل', hintText: '01012345678'),
                validator: (v) => v == null || v.trim().length < 8 ? 'أدخل رقم الهاتف' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _whatsapp,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'رقم واتساب', hintText: '01012345678'),
                validator: (v) => v == null || v.trim().length < 8 ? 'أدخل رقم الواتساب' : null,
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                value: _governorate,
                decoration: const InputDecoration(labelText: 'المحافظة', prefixIcon: Icon(Icons.location_on_outlined)),
                items: _governorates.map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(),
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
                    border: Border.all(color: Theme.of(context).colorScheme.outline),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _images.isEmpty
                      ? const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(Icons.add_a_photo_outlined, size: 38),
                          SizedBox(height: 8),
                          Text('إضافة صور للشيء المراد استبداله (حتى 6 صور)'),
                        ])
                      : GridView.builder(
                          padding: const EdgeInsets.all(8),
                          itemCount: _images.length,
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8),
                          itemBuilder: (_, index) => Stack(fit: StackFit.expand, children: [
                            Image.file(File(_images[index].path), fit: BoxFit.cover),
                            Positioned(top: 3, right: 3, child: InkWell(onTap: () => setState(() => _images.removeAt(index)), child: const CircleAvatar(radius: 12, backgroundColor: Colors.black54, child: Icon(Icons.close, size: 15, color: Colors.white)))),
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
                icon: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.publish_rounded),
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

  void _reload() => setState(() => _future = _repo.getListing(widget.listingId));

  Future<void> _addProposal() async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ProposalSheet(listingId: widget.listingId, repo: _repo),
    );
    if (ok == true) _reload();
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          leading: IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
          actions: [
            IconButton(onPressed: () {}, icon: const Icon(Icons.flag_outlined)),
            IconButton(onPressed: () {}, icon: const Icon(Icons.ios_share_rounded)),
          ],
        ),
        bottomNavigationBar: FutureBuilder<Map<String, dynamic>>(
          future: _future,
          builder: (context, snap) {
            if (!snap.hasData) return const SizedBox.shrink();
            final owner = snap.data!['owner_id']?.toString() == _repo.currentUserId;
            if (owner || snap.data!['status'] != 'open') return const SizedBox.shrink();
            return SafeArea(
              minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(children: [
                Expanded(child: FilledButton(onPressed: _addProposal, style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(58), backgroundColor: const Color(0xFF9BEA65), foregroundColor: Colors.black), child: const Text('تبديل', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)))),
                const SizedBox(width: 10),
                IconButton.filledTonal(onPressed: () => _ContactCard.showContact(context, phone: snap.data!['contact_phone']?.toString(), whatsapp: snap.data!['contact_whatsapp']?.toString()), icon: const Icon(Icons.forum_outlined), style: IconButton.styleFrom(minimumSize: const Size(58, 58))),
              ]),
            );
          },
        ),
        body: FutureBuilder<Map<String, dynamic>>(
          future: _future,
          builder: (context, snap) {
            if (!snap.hasData) return Center(child: snap.hasError ? const Text('تعذر تحميل التفاصيل') : CircularProgressIndicator(color: c.primary));
            final r = snap.data!;
            final proposals = (r['proposals'] as List? ?? []).cast<Map<String, dynamic>>();
            final owner = r['owner_id']?.toString() == _repo.currentUserId;
            final images = (r['images'] as List? ?? []).map((e) => e.toString()).toList();
            final listingCategories = ((r['categories'] as List?)?.map((e) => e.toString()).toList() ?? <String>[]);
            if (listingCategories.isEmpty && r['category'] != null) listingCategories.add(r['category'].toString());
            final user = r['users'] as Map?;
            final title = r['wanted_title']?.toString() ?? 'عرض استبدال';
            final location = r['city']?.toString().trim().isNotEmpty == true ? r['city'].toString() : (r['governorate']?.toString() ?? 'الموقع غير محدد');
            return ListView(
              padding: const EdgeInsets.only(bottom: 22),
              children: [
                _DetailHero(images: images, category: r['category']?.toString() ?? 'إلكترونيات', isFavorite: _isFavorite, onFavorite: _toggleFavorite),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, height: 1.1)),
                    const SizedBox(height: 8),
                    Row(children: [Icon(Icons.location_on_outlined, size: 19, color: c.onSurfaceVariant), const SizedBox(width: 4), Text('$location • على بعد 5 كم', style: TextStyle(color: c.onSurfaceVariant, fontSize: 16))]),
                    const SizedBox(height: 18),
                    Card(
                      color: c.surface,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(children: [
                          Row(children: [
                            CircleAvatar(radius: 27, backgroundColor: c.primary, backgroundImage: (user?['avatar_url']?.toString().isNotEmpty == true) ? NetworkImage(user!['avatar_url'].toString()) : null, child: (user?['avatar_url']?.toString().isNotEmpty == true) ? null : Icon(Icons.person_rounded, color: c.onPrimary, size: 30)),
                            const SizedBox(width: 12),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(user?['name']?.toString() ?? 'صاحب الإعلان', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)), Text(location, style: TextStyle(color: c.onSurfaceVariant))])),
                            Icon(Icons.chevron_left_rounded, color: c.onSurfaceVariant),
                          ]),
                          if (!owner) ...[
                            const SizedBox(height: 14),
                            Align(alignment: AlignmentDirectional.centerStart, child: Text('مراسلة ${user?['name']?.toString() ?? 'صاحب الإعلان'}', style: TextStyle(color: c.onSurfaceVariant, fontWeight: FontWeight.w700))),
                            const SizedBox(height: 8),
                            InkWell(onTap: () => _ContactCard.showContact(context, phone: r['contact_phone']?.toString(), whatsapp: r['contact_whatsapp']?.toString()), borderRadius: BorderRadius.circular(26), child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9), decoration: BoxDecoration(border: Border.all(color: c.outlineVariant), borderRadius: BorderRadius.circular(26)), child: Row(children: [Expanded(child: Text('أهلًا، المنتج ده لسه موجود؟ 👋', style: TextStyle(color: c.onSurface, fontSize: 15))), Container(width: 38, height: 38, decoration: const BoxDecoration(color: Color(0xFF9BEA65), shape: BoxShape.circle), child: const Icon(Icons.arrow_back_rounded, color: Colors.black))]))),
                            const SizedBox(height: 7),
                            Align(alignment: AlignmentDirectional.centerStart, child: Text('ابدأ محادثة مع ${user?['name']?.toString() ?? 'صاحب الإعلان'}', style: TextStyle(color: c.onSurfaceVariant, fontSize: 12))),
                          ],
                        ]),
                      ),
                    ),
                    const SizedBox(height: 22),
                    _DetailsSection(title: 'وصف المنتج', child: Text(r['description']?.toString() ?? '', style: const TextStyle(fontSize: 17, height: 1.55))),
                    _DetailsSection(title: 'حالة المنتج', child: Text(_conditionLabel(r['wanted_condition']?.toString()), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
                    _DetailsSection(title: 'القسم', child: Wrap(spacing: 8, runSpacing: 8, children: [
                      ...listingCategories.map((category) => Chip(label: Text(category), avatar: const Icon(Icons.category_outlined, size: 17))),
                      const Chip(label: Text('استبدال'), avatar: Icon(Icons.swap_horiz_rounded, size: 17)),
                    ])),
                    if (r['contact_phone'] != null || r['contact_whatsapp'] != null) _ContactCard(phone: r['contact_phone']?.toString(), whatsapp: r['contact_whatsapp']?.toString()),
                    const SizedBox(height: 18),
                    Text('العروض المقترحة (${proposals.length})', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 8),
                    if (proposals.isEmpty) const _StateMessage(title: 'لم يضف أحد عرضًا مقابلًا بعد') else ...proposals.map((p) => _ProposalCard(proposal: p, isOwner: owner, repo: _repo, onChanged: _reload)),
                  ]),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DetailHero extends StatelessWidget {
  final List<String> images;
  final String category;
  final bool isFavorite;
  final VoidCallback onFavorite;
  const _DetailHero({required this.images, required this.category, required this.isFavorite, required this.onFavorite});

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
      child: SizedBox(
        height: 390,
        child: Stack(fit: StackFit.expand, children: [
        images.isNotEmpty
            ? CachedNetworkImage(imageUrl: images.first, fit: BoxFit.cover, memCacheWidth: 1200, maxWidthDiskCache: 1200, placeholder: (_, __) => Center(child: CircularProgressIndicator(color: c.primary)), errorWidget: (_, __, ___) => _fallback(c))
            : _fallback(c),
        Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black.withValues(alpha: .28), Colors.transparent, Colors.black.withValues(alpha: .55)])))),
        Positioned(left: 18, bottom: 18, child: Material(color: Colors.black.withValues(alpha: .60), borderRadius: BorderRadius.circular(22), child: InkWell(onTap: onFavorite, borderRadius: BorderRadius.circular(22), child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9), child: Row(children: [Icon(isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: isFavorite ? Colors.redAccent : Colors.white, size: 24), const SizedBox(width: 8), const Text('المفضلة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700))]))))),
        Positioned(bottom: 18, right: 18, child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9), decoration: BoxDecoration(color: Colors.black.withValues(alpha: .58), borderRadius: BorderRadius.circular(22)), child: Text(category, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)))),
        if (images.length > 1) Positioned(bottom: 64, right: 20, child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: Colors.black.withValues(alpha: .58), borderRadius: BorderRadius.circular(20)), child: Text('1 / ${images.length}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)))),
        ]),
      ),
    );
  }

  Widget _fallback(ColorScheme c) => Container(color: c.surfaceContainerHighest, alignment: Alignment.center, child: Icon(Icons.swap_horiz_rounded, size: 70, color: c.onSurfaceVariant));
}

class _SwapImageStrip extends StatelessWidget {
  final List<String> images;
  const _SwapImageStrip({required this.images});

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: CachedNetworkImage(
          imageUrl: images.first,
          height: 300,
          width: double.infinity,
          fit: BoxFit.cover,
          memCacheWidth: 1080,
          maxWidthDiskCache: 1080,
          fadeInDuration: const Duration(milliseconds: 150),
          placeholder: (_, __) => const Center(child: CircularProgressIndicator()),
          errorWidget: (_, __, ___) => const Center(child: Icon(Icons.image_not_supported_outlined, size: 42)),
        ),
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  final String? phone;
  final String? whatsapp;
  const _ContactCard({this.phone, this.whatsapp});

  static Future<void> showContact(BuildContext context, {String? phone, String? whatsapp}) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(child: Padding(padding: const EdgeInsets.all(18), child: _ContactCard(phone: phone, whatsapp: whatsapp))),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final hasPhone = phone != null && phone!.trim().isNotEmpty;
    final hasWhatsapp = whatsapp != null && whatsapp!.trim().isNotEmpty;
    if (!hasPhone && !hasWhatsapp) return const SizedBox.shrink();
    return Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('تواصل مع صاحب الإعلان', style: TextStyle(color: c.onSurface, fontWeight: FontWeight.w800)),
      const SizedBox(height: 10),
      Wrap(spacing: 8, runSpacing: 8, children: [
        if (hasPhone) OutlinedButton.icon(onPressed: () => _launchPhone(phone!), icon: const Icon(Icons.phone_rounded), label: Text(phone!)),
        if (hasWhatsapp) FilledButton.icon(onPressed: () => _launchWhatsapp(whatsapp!), icon: const Icon(Icons.chat_rounded), label: Text('واتساب ${whatsapp!}')),
      ]),
    ])));
  }
}

class _DetailsSection extends StatelessWidget {
  final String title;
  final Widget child;
  const _DetailsSection({required this.title, required this.child});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 16, fontWeight: FontWeight.w700)),
      const SizedBox(height: 7),
      child,
    ]),
  );
}

Future<void> _launchPhone(String value) async {
  final phone = value.replaceAll(RegExp(r'[^0-9+]'), '');
  final uri = Uri.parse('tel:$phone');
  if (await canLaunchUrl(uri)) await launchUrl(uri);
}

Future<void> _launchWhatsapp(String value) async {
  var phone = value.replaceAll(RegExp(r'[^0-9]'), '');
  if (phone.startsWith('0')) phone = '20${phone.substring(1)}';
  if (!phone.startsWith('20') && phone.length == 10) phone = '20$phone';
  final uri = Uri.parse('https://wa.me/$phone');
  if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
}

class _ProposalSheet extends StatefulWidget {
  final String listingId;
  final SwapRepository repo;
  const _ProposalSheet({required this.listingId, required this.repo});
  @override
  State<_ProposalSheet> createState() => _ProposalSheetState();
}

class _ProposalSheetState extends State<_ProposalSheet> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _desc = TextEditingController();
  String _condition = 'good';
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await widget.repo.createProposal(
        listingId: widget.listingId,
        offeredTitle: _title.text,
        offeredDescription: _desc.text,
        offeredCondition: _condition,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) _toast(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('ماذا ستقدم في المقابل؟', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 14),
            TextFormField(controller: _title, decoration: const InputDecoration(labelText: 'اسم الشيء'), validator: (v) => v == null || v.trim().length < 3 ? 'مطلوب' : null),
            const SizedBox(height: 10),
            TextFormField(controller: _desc, minLines: 3, maxLines: 5, decoration: const InputDecoration(labelText: 'تفاصيل الشيء وحالته'), validator: (v) => v == null || v.trim().length < 10 ? 'اكتب تفاصيل أكثر' : null),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _condition,
              items: const [
                DropdownMenuItem(value: 'new', child: Text('جديد')),
                DropdownMenuItem(value: 'like_new', child: Text('شبه جديد')),
                DropdownMenuItem(value: 'good', child: Text('جيد')),
                DropdownMenuItem(value: 'used', child: Text('مستعمل')),
                DropdownMenuItem(value: 'needs_repair', child: Text('يحتاج إصلاح')),
              ],
              onChanged: (v) => setState(() => _condition = v ?? 'good'),
            ),
            const SizedBox(height: 16),
            SizedBox(width: double.infinity, child: FilledButton(onPressed: _busy ? null : _send, child: Text(_busy ? 'جارٍ الإرسال...' : 'إرسال العرض'))),
          ],
        ),
      ),
    );
  }
}

class MySwapsPage extends StatefulWidget {
  const MySwapsPage({super.key});
  @override State<MySwapsPage> createState() => _MySwapsPageState();
}

class _MySwapsPageState extends State<MySwapsPage> with SingleTickerProviderStateMixin {
  final _repo = SwapRepository();
  late final TabController _tabs;
  late Future<List<Map<String, dynamic>>> _proposals;
  late Future<List<Map<String, dynamic>>> _listings;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _load();
  }

  void _load() {
    _proposals = _repo.myProposals();
    _listings = _repo.myListings();
    if (mounted) setState(() {});
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('استبدالاتي', style: TextStyle(fontWeight: FontWeight.w900)),
          bottom: TabBar(controller: _tabs, tabs: const [Tab(text: 'عروضي'), Tab(text: 'النشطة'), Tab(text: 'المنتهية')]),
        ),
        body: TabBarView(controller: _tabs, children: [
          _ProposalList(future: _proposals, repo: _repo, reload: _load),
          _MyListingList(future: _listings, ended: false, repo: _repo, reload: _load),
          _MyListingList(future: _listings, ended: true, repo: _repo, reload: _load),
        ]),
      ),
    );
  }
}

class _ProposalList extends StatelessWidget {
  final Future<List<Map<String, dynamic>>> future;
  final SwapRepository repo;
  final VoidCallback reload;
  const _ProposalList({required this.future, required this.repo, required this.reload});

  @override
  Widget build(BuildContext context) => _asyncList(future, (r) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    child: ListTile(
      leading: CircleAvatar(backgroundColor: Theme.of(context).colorScheme.primaryContainer, child: const Icon(Icons.call_made_rounded)),
      title: Text(r['offered_title']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text('على: ${(r['swap_listings'] as Map?)?['wanted_title'] ?? ''}\n${_statusLabel(r['status'])}'),
      isThreeLine: true,
      trailing: r['status'] == 'pending' ? IconButton(onPressed: () async { await repo.updateProposalStatus(proposalId: r['id'].toString(), status: 'withdrawn'); reload(); }, icon: const Icon(Icons.cancel_outlined)) : null,
    ),
  ));
}

class _MyListingList extends StatelessWidget {
  final Future<List<Map<String, dynamic>>> future;
  final bool ended;
  final SwapRepository repo;
  final VoidCallback reload;
  const _MyListingList({required this.future, required this.ended, required this.repo, required this.reload});

  bool _isEnded(Map<String, dynamic> row) {
    final expires = DateTime.tryParse(row['expires_at']?.toString() ?? '');
    return row['status'] != 'open' || (expires != null && !expires.isAfter(DateTime.now().toUtc()));
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Map<String, dynamic>>>(
    future: future,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
      if (snapshot.hasError) return const _StateMessage(title: 'تعذر تحميل استبدالاتك');
      final rows = (snapshot.data ?? []).where((r) => _isEnded(r) == ended).toList();
      if (rows.isEmpty) return _StateMessage(title: ended ? 'لا توجد استبدالات منتهية' : 'لا توجد استبدالات نشطة');
      return GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
        itemCount: rows.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 14, childAspectRatio: .54),
        itemBuilder: (context, index) => _MySwapCard(row: rows[index], ended: ended, repo: repo, reload: reload),
      );
    },
  );
}

class _MySwapCard extends StatelessWidget {
  final Map<String, dynamic> row;
  final bool ended;
  final SwapRepository repo;
  final VoidCallback reload;
  const _MySwapCard({required this.row, required this.ended, required this.repo, required this.reload});

  Future<bool> _confirm(BuildContext context, {required String title, required String message, required String action}) async {
    return await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('رجوع')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(action)),
        ],
      ),
    ) ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final images = (row['images'] as List? ?? []).map((e) => e.toString()).toList();
    final title = row['wanted_title']?.toString() ?? 'استبدال';
    final location = row['city']?.toString().trim().isNotEmpty == true ? row['city'].toString() : (row['governorate']?.toString() ?? 'المحافظة غير محددة');
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: Stack(fit: StackFit.expand, children: [
            images.isNotEmpty
                ? CachedNetworkImage(imageUrl: images.first, fit: BoxFit.cover, memCacheWidth: 720, maxWidthDiskCache: 720, placeholder: (_, __) => _fallback(c), errorWidget: (_, __, ___) => _fallback(c))
                : _fallback(c),
            Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black.withValues(alpha: .84)])))),
            Positioned(top: 9, right: 9, child: Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5), decoration: BoxDecoration(color: ended ? Colors.black.withValues(alpha: .62) : const Color(0xFF9BEA65), borderRadius: BorderRadius.circular(20)), child: Text(ended ? 'منتهي' : 'نشط', style: TextStyle(color: ended ? Colors.white : Colors.black, fontSize: 11, fontWeight: FontWeight.w800)))),
            Positioned(left: 10, right: 10, bottom: 10, child: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900))),
          ]),
        ),
        Padding(padding: const EdgeInsets.fromLTRB(10, 8, 10, 2), child: Text('$location • ${_conditionLabel(row['wanted_condition']?.toString())}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.onSurfaceVariant, fontSize: 11, fontWeight: FontWeight.w700))),
        Padding(padding: const EdgeInsets.fromLTRB(7, 4, 7, 7), child: Row(children: [
          Expanded(child: TextButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SwapDetailsPage(listingId: row['id'].toString()))), icon: const Icon(Icons.open_in_new_rounded, size: 16), label: const Text('التفاصيل'), style: TextButton.styleFrom(padding: EdgeInsets.zero))),
          PopupMenuButton<String>(
            tooltip: 'إجراءات',
            onSelected: (value) async {
              if (value == 'cancel' && await _confirm(context, title: 'إلغاء الاستبدال؟', message: 'سيتم إغلاق الإعلان ولن يستطيع أحد إرسال عرض جديد عليه.', action: 'إلغاء الاستبدال')) {
                await repo.closeListing(row['id'].toString());
                reload();
              }
              if (value == 'hide' && await _confirm(context, title: 'إخفاء الاستبدال؟', message: 'سيختفي الإعلان من استبدالاتك فقط ولن يتم حذفه من قاعدة البيانات.', action: 'إخفاء')) {
                await repo.hideListing(row['id'].toString());
                reload();
              }
            },
            itemBuilder: (_) => [
              if (!ended) const PopupMenuItem(value: 'cancel', child: Text('إلغاء الاستبدال')),
              if (ended) const PopupMenuItem(value: 'hide', child: Text('إخفاء من قائمتي')),
            ],
            icon: const Icon(Icons.more_horiz_rounded),
          ),
        ])),
      ]),
    );
  }

  Widget _fallback(ColorScheme c) => Container(color: c.surfaceContainerHighest, alignment: Alignment.center, child: Icon(Icons.swap_horiz_rounded, size: 48, color: c.onSurfaceVariant));
}

Widget _asyncList(Future<List<Map<String, dynamic>>> future, Widget Function(Map<String, dynamic>) item) => FutureBuilder<List<Map<String, dynamic>>>(
  future: future,
  builder: (context, snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
    if (snapshot.hasError) return const _StateMessage(title: 'تعذر تحميل البيانات');
    final rows = snapshot.data ?? [];
    return rows.isEmpty ? const _StateMessage(title: 'لا توجد استبدالات هنا') : ListView(padding: const EdgeInsets.all(16), children: rows.map(item).toList());
  },
);

class _ProposalCard extends StatelessWidget {
  final Map<String, dynamic> proposal;
  final bool isOwner;
  final SwapRepository repo;
  final VoidCallback onChanged;
  const _ProposalCard({required this.proposal, required this.isOwner, required this.repo, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final user = proposal['users'] as Map?;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(proposal['offered_title']?.toString() ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          Text(proposal['offered_description']?.toString() ?? ''),
          const SizedBox(height: 6),
          Text('من: ${user?['name'] ?? 'مستخدم'} • ${_statusLabel(proposal['status'])}', style: TextStyle(color: c.onSurfaceVariant)),
          if (isOwner && proposal['status'] == 'pending')
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              TextButton(onPressed: () async { await repo.updateProposalStatus(proposalId: proposal['id'].toString(), status: 'rejected'); onChanged(); }, child: const Text('رفض')),
              FilledButton(onPressed: () async { await repo.updateProposalStatus(proposalId: proposal['id'].toString(), status: 'accepted'); onChanged(); }, child: const Text('قبول')),
            ]),
        ]),
      ),
    );
  }
}

class _ListingCard extends StatelessWidget {
  final Map<String, dynamic> row;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback onFavorite;
  const _ListingCard({required this.row, required this.isFavorite, required this.onTap, required this.onFavorite});

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final images = (row['images'] as List? ?? []).map((e) => e.toString()).toList();
    final user = row['users'] as Map?;
    final title = row['wanted_title']?.toString() ?? 'استبدال جديد';
    final location = row['city']?.toString().trim().isNotEmpty == true ? row['city'].toString() : (row['governorate']?.toString() ?? 'الموقع غير محدد');
    final condition = _conditionLabel(row['wanted_condition']?.toString());
    return SizedBox(
      width: 184,
      height: 276,
      child: Card(
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
        child: InkWell(
          onTap: onTap,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Stack(fit: StackFit.expand, children: [
                images.isNotEmpty
                    ? CachedNetworkImage(imageUrl: images.first, fit: BoxFit.cover, memCacheWidth: 720, maxWidthDiskCache: 720, fadeInDuration: const Duration(milliseconds: 120), placeholder: (_, __) => _imageFallback(c), errorWidget: (_, __, ___) => _imageFallback(c))
                    : _imageFallback(c),
                Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black.withValues(alpha: .82)])))),
                Positioned(top: 10, right: 10, child: Material(color: Colors.black.withValues(alpha: .58), shape: const CircleBorder(), child: InkWell(onTap: onFavorite, customBorder: const CircleBorder(), child: Padding(padding: const EdgeInsets.all(8), child: Icon(isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: isFavorite ? Colors.redAccent : Colors.white, size: 20))))),
                Positioned(left: 10, right: 10, bottom: 10, child: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 17, height: 1.15))),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 9),
              child: Row(children: [
                CircleAvatar(radius: 13, backgroundImage: (user?['avatar_url']?.toString().isNotEmpty == true) ? NetworkImage(user!['avatar_url'].toString()) : null, backgroundColor: c.primaryContainer, child: (user?['avatar_url']?.toString().isNotEmpty == true) ? null : Icon(Icons.person_rounded, size: 15, color: c.onPrimaryContainer)),
                const SizedBox(width: 6),
                Expanded(child: Text('$location • $condition', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.onSurfaceVariant, fontSize: 11, fontWeight: FontWeight.w700))),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _imageFallback(ColorScheme c) => Container(color: c.surfaceContainerHighest, alignment: Alignment.center, child: Icon(Icons.swap_horiz_rounded, size: 52, color: c.onSurfaceVariant));
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
        Icon(Icons.swap_horizontal_circle_rounded, color: Colors.white, size: 42),
        SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('استبدل بدل ما تشتري', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
          SizedBox(height: 5),
          Text('انشر ما تريد، واستقبل عروضًا من المجتمع.', style: TextStyle(color: Colors.white70)),
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
      Icon(Icons.swap_horizontal_circle_outlined, size: 52, color: Theme.of(context).colorScheme.outline),
      const SizedBox(height: 12),
      Text(title, textAlign: TextAlign.center),
      if (onRetry != null) TextButton(onPressed: onRetry, child: const Text('إعادة المحاولة')),
    ]),
  );
}

String _conditionLabel(String? v) => {'any': 'أي حالة', 'new': 'جديد', 'like_new': 'شبه جديد', 'good': 'جيد', 'used': 'مستعمل', 'needs_repair': 'يحتاج إصلاح'}[v] ?? 'غير محدد';
String _statusLabel(Object? v) => {'pending': 'في الانتظار', 'accepted': 'مقبول', 'rejected': 'مرفوض', 'withdrawn': 'مسحوب', 'open': 'مفتوح', 'closed': 'مغلق', 'cancelled': 'ملغي', 'expired': 'منتهي'}[v?.toString()] ?? 'غير معروف';
void _toast(BuildContext context, Object e) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
