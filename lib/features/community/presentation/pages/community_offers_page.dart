import 'package:flutter/material.dart';
import 'package:loqma/features/community/data/repositories/community_offer_repository.dart';
import 'package:loqma/features/community/presentation/pages/community_offer_details_page.dart';

class CommunityOffersPage extends StatefulWidget {
  const CommunityOffersPage({super.key});

  @override
  State<CommunityOffersPage> createState() => _CommunityOffersPageState();
}

class _CommunityOffersPageState extends State<CommunityOffersPage> {
  final _repository = CommunityOfferRepository();
  late Future<List<Map<String, dynamic>>> _future;
  String _category = 'all';
  String _listingType = 'all';

  static const _green = Color(0xFF0B7650);
  static const _darkGreen = Color(0xFF123F31);
  static const _background = Color(0xFFF6FAF8);

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() {
    return _repository.getOffers(
        category: _category, listingType: _listingType);
  }

  void _applyFilters({String? category, String? listingType}) {
    setState(() {
      if (category != null) _category = category;
      if (listingType != null) _listingType = listingType;
      _future = _load();
    });
  }

  Future<void> _refresh() async {
    final future = _load();
    setState(() => _future = future);
    await future;
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _background,
        appBar: AppBar(
          title: const Text('ملابس وأثاث'),
          centerTitle: true,
          backgroundColor: _background,
          foregroundColor: _darkGreen,
          elevation: 0,
          actions: [
            IconButton(
                onPressed: _refresh, icon: const Icon(Icons.refresh_rounded)),
          ],
        ),
        body: FutureBuilder<List<Map<String, dynamic>>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                  child: CircularProgressIndicator(color: _green));
            }
            if (snapshot.hasError) {
              return _ErrorState(
                  message: snapshot.error.toString(), onRetry: _refresh);
            }
            final offers = snapshot.data ?? const <Map<String, dynamic>>[];
            return RefreshIndicator(
              color: _green,
              onRefresh: _refresh,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics()),
                slivers: [
                  SliverToBoxAdapter(child: _buildIntro()),
                  SliverToBoxAdapter(child: _buildFilters()),
                  if (offers.isEmpty)
                    SliverFillRemaining(
                        hasScrollBody: false,
                        child: _EmptyState(onReset: _resetFilters))
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                      sliver: SliverList.separated(
                        itemCount: offers.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 14),
                        itemBuilder: (_, index) => _OfferCard(
                          offer: offers[index],
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => CommunityOfferDetailsPage(
                                      offer: offers[index]))),
                        ),
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

  Widget _buildIntro() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Container(
        padding: const EdgeInsets.all(19),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Color(0xFF0B7650), Color(0xFF2BAA76)],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft),
          borderRadius: BorderRadius.circular(24),
        ),
        child: const Row(children: [
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('حاجات تستحق فرصة جديدة',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w900)),
                SizedBox(height: 5),
                Text('تبرع أو اشتري ملابس وأثاث بحالة جيدة بسعر بسيط.',
                    style: TextStyle(
                        color: Colors.white70, fontSize: 12, height: 1.4))
              ])),
          SizedBox(width: 12),
          Icon(Icons.recycling_rounded, color: Colors.white, size: 42),
        ]),
      ),
    );
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('نوع العرض',
            style: TextStyle(
                color: _darkGreen, fontSize: 14, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        _chips([
          ('all', 'الكل', Icons.apps_rounded),
          ('donation', 'تبرع مجاني', Icons.favorite_rounded),
          ('symbolic_sale', 'بيع رمزي', Icons.sell_rounded),
          ('charity_donation', 'للجمعيات', Icons.volunteer_activism_rounded),
        ], _listingType, (value) => _applyFilters(listingType: value)),
        const SizedBox(height: 13),
        const Text('التصنيف',
            style: TextStyle(
                color: _darkGreen, fontSize: 14, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        _chips([
          ('all', 'الكل', Icons.grid_view_rounded),
          ('clothing', 'ملابس', Icons.checkroom_rounded),
          ('furniture', 'أثاث', Icons.chair_rounded),
        ], _category, (value) => _applyFilters(category: value)),
      ]),
    );
  }

  Widget _chips(List<(String, String, IconData)> values, String selected,
      ValueChanged<String> onSelected) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, index) {
          final item = values[index];
          final active = selected == item.$1;
          return FilterChip(
            selected: active,
            onSelected: (_) => onSelected(item.$1),
            avatar: Icon(item.$3,
                size: 16, color: active ? _green : const Color(0xFF71837C)),
            label: Text(item.$2),
            labelStyle: TextStyle(
                color: active ? _green : const Color(0xFF5F786C),
                fontSize: 11,
                fontWeight: active ? FontWeight.w900 : FontWeight.w700),
            backgroundColor: Colors.white,
            selectedColor: const Color(0xFFDDF3E8),
            checkmarkColor: _green,
            side: BorderSide(color: active ? _green : const Color(0xFFE0EBE5)),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          );
        },
      ),
    );
  }

  void _resetFilters() {
    _applyFilters(category: 'all', listingType: 'all');
  }
}

class _OfferCard extends StatelessWidget {
  final Map<String, dynamic> offer;
  final VoidCallback onTap;

  const _OfferCard({required this.offer, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final title = _text('title', 'عرض جديد');
    final category = _text('category', 'clothing');
    final type = _text('listing_type', 'donation');
    final condition = _text('item_condition', 'good');
    final location = _text('pickup_location', 'مكان الاستلام غير محدد');
    final price = (offer['price'] as num?)?.toDouble() ?? 0;
    final image = _imageUrl();
    final isSale = type == 'symbolic_sale';
    final isCharity = type == 'charity_donation';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Ink(
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFE1ECE6)),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withAlpha(9),
                  blurRadius: 14,
                  offset: const Offset(0, 5))
            ]),
        child: Row(children: [
          ClipRRect(
              borderRadius:
                  const BorderRadius.horizontal(right: Radius.circular(22)),
              child: SizedBox(
                  width: 118,
                  height: 155,
                  child: image == null
                      ? Container(
                          color: const Color(0xFFE8F5EE),
                          child: Icon(
                              category == 'furniture'
                                  ? Icons.chair_rounded
                                  : Icons.checkroom_rounded,
                              color: const Color(0xFF0B7650),
                              size: 40))
                      : Image.network(image,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                              color: const Color(0xFFE8F5EE),
                              child: const Icon(
                                  Icons.image_not_supported_outlined,
                                  color: Color(0xFF0B7650),
                                  size: 32))))),
          Expanded(
              child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Expanded(
                              child: Text(title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      color: Color(0xFF123F31),
                                      fontSize: 15,
                                      fontWeight: FontWeight.w900))),
                          const Icon(Icons.arrow_back_ios_new_rounded,
                              color: Color(0xFF0B7650), size: 15)
                        ]),
                        const SizedBox(height: 8),
                        Wrap(spacing: 5, runSpacing: 5, children: [
                          _tag(_categoryLabel(category),
                              const Color(0xFFE8F5EE), const Color(0xFF0B7650)),
                          _tag(
                              isCharity
                                  ? 'تبرع لجمعية'
                                  : isSale
                                      ? '${price.toStringAsFixed(0)} جنيه'
                                      : 'تبرع مجاني',
                              isSale
                                  ? const Color(0xFFFFF0DA)
                                  : const Color(0xFFE8F5EE),
                              isSale
                                  ? const Color(0xFFB36B12)
                                  : const Color(0xFF0B7650))
                        ]),
                        const SizedBox(height: 9),
                        Row(children: [
                          const Icon(Icons.check_circle_outline_rounded,
                              size: 15, color: Color(0xFF71837C)),
                          const SizedBox(width: 4),
                          Expanded(
                              child: Text(_conditionLabel(condition),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      color: Color(0xFF71837C), fontSize: 11)))
                        ]),
                        const SizedBox(height: 6),
                        Row(children: [
                          const Icon(Icons.location_on_outlined,
                              size: 15, color: Color(0xFF71837C)),
                          const SizedBox(width: 4),
                          Expanded(
                              child: Text(location,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      color: Color(0xFF71837C), fontSize: 11)))
                        ]),
                      ]))),
        ]),
      ),
    );
  }

  String _text(String key, String fallback) =>
      (offer[key] ?? fallback).toString();

  String? _imageUrl() {
    final direct = offer['image']?.toString();
    if (direct != null && direct.isNotEmpty) return direct;
    final images = offer['images'];
    if (images is List && images.isNotEmpty) return images.first?.toString();
    return null;
  }

  Widget _tag(String text, Color background, Color foreground) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
          color: background, borderRadius: BorderRadius.circular(20)),
      child: Text(text,
          style: TextStyle(
              color: foreground, fontSize: 10, fontWeight: FontWeight.w900)));

  String _categoryLabel(String value) =>
      value == 'furniture' ? 'أثاث' : 'ملابس';
  String _conditionLabel(String value) =>
      {
        'new': 'جديد أو شبه جديد',
        'very_good': 'جيد جدًا',
        'good': 'جيد',
        'needs_repair': 'يحتاج إصلاحًا بسيطًا'
      }[value] ??
      'حالة جيدة';
}

class _LegacyCommunityOfferDetailsPage extends StatelessWidget {
  final Map<String, dynamic> offer;

  const _LegacyCommunityOfferDetailsPage({required this.offer});

  @override
  Widget build(BuildContext context) {
    final title = (offer['title'] ?? 'عرض').toString();
    final description = (offer['description'] ?? 'لا يوجد وصف').toString();
    final image = offer['image']?.toString();
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF6FAF8),
        appBar: AppBar(
            title: const Text('تفاصيل العرض'),
            centerTitle: true,
            backgroundColor: const Color(0xFFF6FAF8),
            foregroundColor: const Color(0xFF123F31),
            elevation: 0),
        body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
            children: [
              ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: SizedBox(
                      height: 250,
                      child: image == null || image.isEmpty
                          ? Container(
                              color: const Color(0xFFE8F5EE),
                              child: const Icon(
                                  Icons.volunteer_activism_rounded,
                                  color: Color(0xFF0B7650),
                                  size: 70))
                          : Image.network(image,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                  color: const Color(0xFFE8F5EE),
                                  child: const Icon(
                                      Icons.image_not_supported_outlined,
                                      color: Color(0xFF0B7650),
                                      size: 48))))),
              const SizedBox(height: 18),
              Text(title,
                  style: const TextStyle(
                      color: Color(0xFF123F31),
                      fontSize: 24,
                      fontWeight: FontWeight.w900)),
              const SizedBox(height: 10),
              Text(description,
                  style: const TextStyle(
                      color: Color(0xFF5F786C), fontSize: 14, height: 1.6)),
              const SizedBox(height: 22),
              Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18)),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('الخطوة التالية',
                            style: TextStyle(
                                color: Color(0xFF123F31),
                                fontSize: 16,
                                fontWeight: FontWeight.w900)),
                        const SizedBox(height: 7),
                        Text(
                            'سيتم تفعيل طلب العرض والتواصل مع صاحبه في الخطوة التالية.',
                            style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                                fontSize: 12,
                                height: 1.5))
                      ])),
            ]),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onReset;
  const _EmptyState({required this.onReset});

  @override
  Widget build(BuildContext context) => Center(
      child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
                width: 76,
                height: 76,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                    color: Color(0xFFE8F5EE), shape: BoxShape.circle),
                child: const Icon(Icons.search_off_rounded,
                    color: Color(0xFF0B7650), size: 38)),
            const SizedBox(height: 16),
            const Text('لا توجد عروض بهذا الفلتر',
                style: TextStyle(
                    color: Color(0xFF123F31),
                    fontSize: 17,
                    fontWeight: FontWeight.w900)),
            const SizedBox(height: 7),
            const Text('جرّب اختيار فلتر آخر أو ارجع لكل العروض.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF71837C), fontSize: 12)),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onReset, child: const Text('عرض الكل'))
          ])));
}

class _ErrorState extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
      child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.cloud_off_rounded,
                color: Color(0xFFB54747), size: 48),
            const SizedBox(height: 12),
            const Text('تعذر تحميل العروض',
                style: TextStyle(
                    color: Color(0xFF123F31),
                    fontSize: 17,
                    fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text(message,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF71837C), fontSize: 11)),
            const SizedBox(height: 15),
            ElevatedButton(
                onPressed: onRetry, child: const Text('إعادة المحاولة'))
          ])));
}
