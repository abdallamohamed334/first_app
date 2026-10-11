import 'package:flutter/material.dart';
import 'package:loqma/features/community/data/repositories/community_offer_repository.dart';
import 'package:loqma/features/community/presentation/pages/add_community_offer_page.dart';

class CommunityOfferCategorySelectionPage extends StatefulWidget {
  const CommunityOfferCategorySelectionPage({super.key});

  @override
  State<CommunityOfferCategorySelectionPage> createState() =>
      _CommunityOfferCategorySelectionPageState();
}

class _CommunityOfferCategorySelectionPageState
    extends State<CommunityOfferCategorySelectionPage> {
  final _repository = CommunityOfferRepository();
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _categories = [];
  bool _loading = true;
  String? _error;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final categories = await _repository.getCategories();
      if (!mounted) return;
      setState(() {
        _categories = categories;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'تعذر تحميل التصنيفات. تحقق من الاتصال وحاول مرة أخرى.';
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _visibleCategories {
    final byId = <String, Map<String, dynamic>>{
      for (final category in _categories)
        if ((category['id']?.toString() ?? '').isNotEmpty)
          category['id'].toString(): category,
    };
    final query = _query.trim().toLowerCase();
    final items = _categories.where((category) {
      if (query.isEmpty) return true;
      final parent = byId[category['parent_id']?.toString()];
      final name = category['name_ar']?.toString() ?? '';
      final slug = category['slug']?.toString() ?? '';
      final parentName = parent?['name_ar']?.toString() ?? '';
      return name.toLowerCase().contains(query) ||
          slug.toLowerCase().contains(query) ||
          parentName.toLowerCase().contains(query);
    }).toList();
    items.sort((a, b) {
      final parentA =
          byId[a['parent_id']?.toString()]?['name_ar']?.toString() ?? '';
      final parentB =
          byId[b['parent_id']?.toString()]?['name_ar']?.toString() ?? '';
      final groupOrder = parentA.compareTo(parentB);
      if (groupOrder != 0) return groupOrder;
      final orderA = (a['sort_order'] as num?)?.toInt() ?? 0;
      final orderB = (b['sort_order'] as num?)?.toInt() ?? 0;
      if (orderA != orderB) return orderA.compareTo(orderB);
      return (a['name_ar']?.toString() ?? '').compareTo(
        b['name_ar']?.toString() ?? '',
      );
    });
    return items;
  }

  IconData _categoryIcon(Map<String, dynamic> category) {
    final value = '${category['icon'] ?? ''} ${category['slug'] ?? ''}'
        .toLowerCase();
    if (value.contains('car') || value.contains('vehicle')) {
      return Icons.directions_car_rounded;
    }
    if (value.contains('phone') || value.contains('electronic')) {
      return Icons.devices_rounded;
    }
    if (value.contains('cloth') || value.contains('fashion')) {
      return Icons.checkroom_rounded;
    }
    if (value.contains('book')) return Icons.menu_book_rounded;
    if (value.contains('food') ||
        value.contains('restaurant') ||
        value.contains('cake')) {
      return Icons.restaurant_rounded;
    }
    if (value.contains('furniture') || value.contains('home')) {
      return Icons.chair_rounded;
    }
    if (value.contains('real-estate') || value.contains('property')) {
      return Icons.apartment_rounded;
    }
    if (value.contains('toy')) return Icons.toys_rounded;
    return Icons.category_rounded;
  }

  void _openForm(Map<String, dynamic> category) {
    final categoryId = category['id']?.toString().trim() ?? '';
    if (categoryId.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddCommunityOfferPage(initialCategoryId: categoryId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final categories = _visibleCategories;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF111714)
          : const Color(0xFFF5F8F6),
      appBar: AppBar(
        title: const Text('اختيار تصنيف العرض'),
        centerTitle: true,
        backgroundColor: isDark
            ? const Color(0xFF111714)
            : const Color(0xFFF5F8F6),
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      colors.primary,
                      colors.primary.withValues(alpha: 0.82),
                    ],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'هتضيف إيه للبيع؟',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 7),
                    Text(
                      'اختار التصنيف، وبعدها هنجهز لك نموذج مناسب للمنتج.',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _query = value),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'ابحث عن تصنيف… مثل موبايل أو ملابس',
                  prefixIcon: const Icon(Icons.search_rounded),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF1D2722) : Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? _MessageState(
                      message: _error!,
                      actionLabel: 'إعادة المحاولة',
                      onPressed: _loadCategories,
                    )
                  : categories.isEmpty
                  ? const _MessageState(
                      message: 'لا توجد تصنيفات متاحة حاليًا.',
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                      itemCount: categories.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final category = categories[index];
                        final parent = _categories.where(
                          (candidate) =>
                              candidate['id']?.toString() ==
                              category['parent_id']?.toString(),
                        );
                        final parentName = parent.isEmpty
                            ? null
                            : parent.first['name_ar']?.toString();
                        return Material(
                          color: isDark
                              ? const Color(0xFF1D2722)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          child: InkWell(
                            onTap: () => _openForm(category),
                            borderRadius: BorderRadius.circular(18),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 15,
                                vertical: 13,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: colors.primary.withValues(
                                        alpha: 0.1,
                                      ),
                                      borderRadius: BorderRadius.circular(15),
                                    ),
                                    child: Icon(
                                      _categoryIcon(category),
                                      color: colors.primary,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 13),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (parentName != null &&
                                            parentName.isNotEmpty) ...[
                                          Text(
                                            parentName,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: colors.onSurfaceVariant,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                        ],
                                        Text(
                                          category['name_ar']?.toString() ??
                                              'تصنيف',
                                          style: TextStyle(
                                            color: colors.onSurface,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 15,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    Icons.arrow_forward_ios_rounded,
                                    size: 16,
                                    color: colors.primary,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  final String message;
  final String? actionLabel;
  final VoidCallback? onPressed;

  const _MessageState({
    required this.message,
    this.actionLabel,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.category_outlined, size: 42),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            if (actionLabel != null && onPressed != null) ...[
              const SizedBox(height: 14),
              FilledButton(onPressed: onPressed, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
