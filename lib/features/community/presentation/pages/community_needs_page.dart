// lib/features/community/presentation/pages/community_needs_page.dart

import 'package:flutter/material.dart';
import 'package:loqma/core/services/supabase_service.dart';
import 'package:loqma/features/community/data/repositories/community_needs_repository.dart';
import 'package:loqma/features/community/presentation/pages/community_need_details_page.dart';
import 'package:loqma/features/community/presentation/pages/add_community_need_page.dart';

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
  static const _green = Color(0xFF0B7650);
  static const _darkGreen = Color(0xFF0F2E23);
  static const _background = Color(0xFFF5F9F7);
  static const _orange = Color(0xFFE28B00);
  static const _red = Color(0xFFB54747);
  static const _purple = Color(0xFF6651B5);
  static const _blue = Color(0xFF3679C8);

  // ─────────────── الحالة ───────────────
  bool _loading = true;
  bool _loadingMore = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _needs = [];
  int _currentPage = 0;
  bool _hasMore = true;

  // ─────────────── الفلاتر ───────────────
  String? _selectedCategoryId;
  List<Map<String, dynamic>> _categories = [];

  @override
  void initState() {
    super.initState();
    _loadCategories();
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
  // LOAD CATEGORIES
  // ═══════════════════════════════════════════════════════════

  Future<void> _loadCategories() async {
    try {
      final rows = await SupabaseService()
          .client
          .from('community_categories')
          .select('id, slug, name_ar')
          .eq('is_active', true)
          .order('sort_order');

      if (!mounted) return;

      setState(() {
        _categories = List<Map<String, dynamic>>.from(rows);
      });
    } catch (e) {
      debugPrint('❌ loadCategories error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════
  // LOAD NEEDS
  // ═══════════════════════════════════════════════════════════

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
    await _loadNeeds(refresh: true);
  }

  // ═══════════════════════════════════════════════════════════
  // SEARCH DEBOUNCE
  // ═══════════════════════════════════════════════════════════

  void _onSearchChanged() {
    setState(() {});
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted && _searchController.text == _searchController.text) {
        _loadNeeds(refresh: true);
      }
    });
  }

  // ═══════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _background,
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: _darkGreen,
          elevation: 0,
          centerTitle: true,
          title: const Text(
            ' الناس محتاجه!  ',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 15.5,
            ),
          ),
          actions: [
            IconButton(
              onPressed: _refresh,
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'تحديث',
            ),
          ],
        ),
        body: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildBody()),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const AddCommunityNeedPage(),
              ),
            );
            if (result == true && mounted) {
              _refresh();
            }
          },
          backgroundColor: _green,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add_rounded),
          label: const Text(
            'أضف احتياجك',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // HEADER
  // ═══════════════════════════════════════════════════════════

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      color: Colors.white,
      child: Column(
        children: [
          // Search
          Container(
            height: 46,
            decoration: BoxDecoration(
              color: _background,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE0EBE5)),
            ),
            child: Row(
              children: [
                const SizedBox(width: 12),
                const Icon(Icons.search_rounded, color: _green, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    textDirection: TextDirection.rtl,
                    style: const TextStyle(fontSize: 13),
                    onChanged: (_) => _onSearchChanged(),
                    decoration: const InputDecoration(
                      hintText: 'ابحث في الاحتياجات...',
                      hintStyle: TextStyle(
                        color: Color(0xFF71837C),
                        fontSize: 13,
                      ),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                if (_searchController.text.isNotEmpty)
                  IconButton(
                    onPressed: () {
                      _searchController.clear();
                      _loadNeeds(refresh: true);
                    },
                    icon: const Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: Color(0xFF71837C),
                    ),
                  ),
              ],
            ),
          ),

          // Categories chips
          if (_categories.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _categories.length + 1,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  if (i == 0) {
                    final isAll = _selectedCategoryId == null;
                    return GestureDetector(
                      onTap: () {
                        setState(() => _selectedCategoryId = null);
                        _loadNeeds(refresh: true);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isAll ? _green : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isAll ? _green : const Color(0xFFE0EBE5),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            'الكل',
                            style: TextStyle(
                              color: isAll ? Colors.white : _darkGreen,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    );
                  }

                  final cat = _categories[i - 1];
                  final catId = cat['id']?.toString() ?? '';
                  final catName = cat['name_ar']?.toString() ?? '';
                  final isSelected = _selectedCategoryId == catId;

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedCategoryId = isSelected ? null : catId;
                      });
                      _loadNeeds(refresh: true);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected ? _green : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? _green : const Color(0xFFE0EBE5),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          catName,
                          style: TextStyle(
                            color: isSelected ? Colors.white : _darkGreen,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // BODY
  // ═══════════════════════════════════════════════════════════

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: _green),
      );
    }

    if (_errorMessage != null) {
      return _buildErrorState();
    }

    if (_needs.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      color: _green,
      onRefresh: _refresh,
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        itemCount: _needs.length + (_loadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _needs.length) {
            return const Padding(
              padding: EdgeInsets.all(20),
              child: Center(
                child: CircularProgressIndicator(color: _green),
              ),
            );
          }

          return _buildNeedCard(_needs[index]);
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // NEED CARD
  // ═══════════════════════════════════════════════════════════

  Widget _buildNeedCard(Map<String, dynamic> need) {
    final id = need['id']?.toString() ?? '';
    final title = need['title']?.toString() ?? 'احتياج';
    final description = need['description']?.toString() ?? '';
    final categoryName = need['category_name_ar']?.toString() ?? 'عام';
    final urgency = need['urgency']?.toString() ?? 'normal';
    final city = need['city']?.toString() ?? '';
    final requesterName = need['requester_name']?.toString() ?? 'مستخدم';
    final requesterAvatar = need['requester_avatar']?.toString();
    final contactCount = (need['contact_count'] as num?)?.toInt() ?? 0;
    final expiresAt = _parseDate(need['expires_at']);
    final quantity = (need['quantity'] as num?)?.toInt() ?? 1;

    final urgencyData = _urgencyData(urgency);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CommunityNeedDetailsPage(needId: id),
              ),
            ).then((_) => _refresh());
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE8F1EC)),
              boxShadow: [
                BoxShadow(
                  color: _darkGreen.withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: _green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.category_rounded,
                            color: _green,
                            size: 12,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            categoryName,
                            style: const TextStyle(
                              color: _green,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: urgencyData.$3.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            urgencyData.$1,
                            color: urgencyData.$3,
                            size: 11,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            urgencyData.$2,
                            style: TextStyle(
                              color: urgencyData.$3,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _orange.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.access_time_rounded,
                            color: _orange,
                            size: 10,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            _remainingText(expiresAt),
                            style: const TextStyle(
                              color: _orange,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _darkGreen,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    height: 1.3,
                  ),
                ),

                if (description.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF71837C),
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],

                const SizedBox(height: 12),

                // Bottom row
                Row(
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _green.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child:
                          requesterAvatar != null && requesterAvatar.isNotEmpty
                              ? ClipOval(
                                  child: Image.network(
                                    requesterAvatar,
                                    width: 26,
                                    height: 26,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Icon(
                                      Icons.person_rounded,
                                      color: _green,
                                      size: 14,
                                    ),
                                  ),
                                )
                              : const Icon(
                                  Icons.person_rounded,
                                  color: _green,
                                  size: 14,
                                ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        requesterName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF71837C),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (city.isNotEmpty) ...[
                      const Icon(
                        Icons.location_on_outlined,
                        color: Color(0xFF71837C),
                        size: 12,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        city,
                        style: const TextStyle(
                          color: Color(0xFF71837C),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (contactCount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _blue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.people_alt_rounded,
                              color: _blue,
                              size: 11,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              '$contactCount',
                              style: const TextStyle(
                                color: _blue,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FBF9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'الكمية: $quantity',
                        style: const TextStyle(
                          color: Color(0xFF71837C),
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // EMPTY / ERROR
  // ═══════════════════════════════════════════════════════════

  Widget _buildEmptyState() {
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
                color: _green.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.search_off_rounded,
                color: _green,
                size: 42,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'مفيش احتياجات دلوقتي',
              style: TextStyle(
                color: _darkGreen,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'لما حد يحتاج حاجة هتظهر هنا',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF71837C),
                fontSize: 13,
                height: 1.5,
              ),
            ),
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
              width: 80,
              height: 80,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _red.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.cloud_off_rounded,
                color: _red,
                size: 38,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'تعذر التحميل',
              style: TextStyle(
                color: _darkGreen,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? '',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF71837C),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _refresh,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('إعادة المحاولة'),
              style: FilledButton.styleFrom(
                backgroundColor: _green,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    if (text.isEmpty || text == 'null') return null;
    return DateTime.tryParse(text);
  }

  String _remainingText(DateTime? expiresAt) {
    if (expiresAt == null) return '--';
    final diff = expiresAt.difference(DateTime.now());
    if (diff.isNegative) return 'منتهي';
    if (diff.inDays > 0) return 'متبقي ${diff.inDays} يوم';
    if (diff.inHours > 0) return 'متبقي ${diff.inHours} ساعة';
    return 'متبقي ${diff.inMinutes} دقيقة';
  }

  (IconData, String, Color) _urgencyData(String urgency) {
    switch (urgency) {
      case 'urgent':
        return (Icons.warning_amber_rounded, 'عاجل جدًا', _red);
      case 'high':
        return (Icons.priority_high_rounded, 'مهم', _orange);
      case 'low':
        return (Icons.sentiment_satisfied_rounded, 'عادي', _green);
      case 'normal':
      default:
        return (Icons.sentiment_neutral_rounded, 'متوسط', _blue);
    }
  }
}
