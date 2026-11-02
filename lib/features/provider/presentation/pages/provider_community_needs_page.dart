import 'dart:async';

import 'package:flutter/material.dart';
import 'package:loqma/core/constants/egypt_locations.dart';
import 'package:loqma/core/services/supabase_service.dart';
import 'package:loqma/features/community/data/repositories/community_needs_repository.dart';
import 'package:loqma/features/community/presentation/pages/community_need_details_page.dart';

class ProviderCommunityNeedsPage extends StatefulWidget {
  final String? initialGovernorate;

  const ProviderCommunityNeedsPage({
    super.key,
    this.initialGovernorate,
  });

  @override
  State<ProviderCommunityNeedsPage> createState() =>
      _ProviderCommunityNeedsPageState();
}

class _ProviderCommunityNeedsPageState
    extends State<ProviderCommunityNeedsPage> {
  static const _pageSize = 30;
  static const _primary = Color(0xFF0B7650);

  final _needsRepository = CommunityNeedsRepository();
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  String? _selectedGovernorate;
  String? _selectedCategory;
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _needs = [];
  Timer? _searchDebounce;
  int _page = 0;
  int _loadGeneration = 0;
  bool _loading = false;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialGovernorate?.trim();
    if (initial != null && EgyptLocations.governorates.containsKey(initial)) {
      _selectedGovernorate = initial;
    }
    _scrollController.addListener(_onScroll);
    _loadCategories();
    if (_selectedGovernorate != null) _loadNeeds(refresh: true);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 220) {
      _loadNeeds();
    }
  }

  Future<void> _loadCategories() async {
    try {
      final rows = await SupabaseService()
          .client
          .from('service_categories')
          .select('slug, name_ar, icon')
          .eq('is_active', true)
          .order('sort_order')
          .limit(100);
      if (!mounted) return;
      setState(() {
        _categories = List<Map<String, dynamic>>.from(rows);
      });
    } catch (error) {
      debugPrint('[ProviderNeeds] category load failed: $error');
    }
  }

  Future<void> _loadNeeds({bool refresh = false}) async {
    final governorate = _selectedGovernorate;
    if (governorate == null || governorate.isEmpty) {
      if (mounted) {
        setState(() {
          _needs = [];
          _loading = false;
          _loadingMore = false;
          _hasMore = false;
          _error = null;
        });
      }
      return;
    }
    if (!refresh && (_loading || _loadingMore || !_hasMore)) return;

    final generation = refresh ? ++_loadGeneration : _loadGeneration;
    final page = refresh ? 0 : _page;
    if (mounted) {
      setState(() {
        if (refresh) {
          _loading = true;
          _loadingMore = false;
          _error = null;
          _hasMore = true;
          _page = 0;
        } else {
          _loadingMore = true;
        }
      });
    }

    try {
      final rows = await _needsRepository.listProviderNeedsByGovernorate(
        governorate: governorate,
        categorySlug: _selectedCategory,
        search: _searchController.text.trim().isEmpty
            ? null
            : _searchController.text.trim(),
        limit: _pageSize,
        offset: page * _pageSize,
      );
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _needs = refresh ? rows : [..._needs, ...rows];
        _page = page + 1;
        _hasMore = rows.length == _pageSize;
        _loading = false;
        _loadingMore = false;
        _error = null;
      });
    } catch (error) {
      debugPrint('[ProviderNeeds] list load failed: $error');
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
        _error = 'تعذر تحميل الاحتياجات. اسحب لإعادة المحاولة.';
      });
    }
  }

  void _onSearchChanged(String _) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 450), () {
      if (mounted) _loadNeeds(refresh: true);
    });
  }

  Future<void> _openNeed(Map<String, dynamic> need) async {
    final needId = need['id']?.toString();
    if (needId == null || needId.isEmpty) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => CommunityNeedDetailsPage(needId: needId),
      ),
    );
    if (mounted) _loadNeeds(refresh: true);
  }

  void _selectGovernorate(String? value) {
    if (value == _selectedGovernorate) return;
    setState(() {
      _selectedGovernorate = value;
      _needs = [];
      _page = 0;
      _hasMore = value != null;
    });
    if (value != null) _loadNeeds(refresh: true);
  }

  void _selectCategory(String? value) {
    if (value == _selectedCategory) return;
    setState(() {
      _selectedCategory = value;
      _needs = [];
    });
    _loadNeeds(refresh: true);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: scheme.surface,
        appBar: AppBar(
          backgroundColor: scheme.surface,
          foregroundColor: scheme.onSurface,
          elevation: 0,
          title: const Text(
            'احتياجات محافظتك',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          actions: [
            IconButton(
              tooltip: 'تحديث',
              onPressed: _selectedGovernorate == null
                  ? null
                  : () => _loadNeeds(refresh: true),
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        body: RefreshIndicator(
          color: _primary,
          onRefresh: () => _loadNeeds(refresh: true),
          child: ListView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            children: [
              _buildIntro(),
              const SizedBox(height: 14),
              _buildGovernoratePicker(scheme),
              if (_selectedGovernorate != null) ...[
                const SizedBox(height: 12),
                _buildSearchField(scheme),
                const SizedBox(height: 10),
                _buildCategoryPicker(scheme),
                const SizedBox(height: 12),
                if (_loading && _needs.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 48),
                    child: Center(
                      child: CircularProgressIndicator(color: _primary),
                    ),
                  )
                else if (_error != null && _needs.isEmpty)
                  _buildMessageCard(scheme, _error!, Icons.cloud_off_rounded)
                else if (_needs.isEmpty)
                  _buildMessageCard(
                    scheme,
                    'مفيش احتياجات منشورة في $_selectedGovernorate حاليًا.',
                    Icons.inbox_outlined,
                  )
                else ...[
                  for (final need in _needs) _buildNeedCard(need, scheme),
                  if (_loadingMore)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 18),
                      child: Center(
                        child: CircularProgressIndicator(color: _primary),
                      ),
                    ),
                  if (_error != null && _needs.isNotEmpty)
                    TextButton.icon(
                      onPressed: _loadNeeds,
                      icon: const Icon(Icons.refresh_rounded),
                      label: Text(_error!),
                    ),
                ],
              ] else ...[
                const SizedBox(height: 18),
                _buildMessageCard(
                  scheme,
                  'اختار المحافظة علشان تشوف احتياجات الناس المنشورة فيها.',
                  Icons.location_on_outlined,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIntro() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_primary, Color(0xFF075B3D)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          const Icon(Icons.handyman_rounded, color: Colors.white, size: 30),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'طلبات خدمة من المستخدمين',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _selectedGovernorate == null
                      ? 'اختار المحافظة لعرض الطلبات المنشورة فيها'
                      : 'طلبات نشطة في $_selectedGovernorate',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGovernoratePicker(ColorScheme scheme) {
    return _filterCard(
      scheme,
      child: DropdownButtonFormField<String>(
        value: _selectedGovernorate,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: 'المحافظة',
          prefixIcon: const Icon(Icons.location_on_outlined),
          border: InputBorder.none,
          labelStyle: TextStyle(color: scheme.onSurfaceVariant),
        ),
        hint: const Text('اختار المحافظة'),
        items: [
          for (final governorate in EgyptLocations.names)
            DropdownMenuItem(
              value: governorate,
              child: Text(governorate),
            ),
        ],
        onChanged: _selectGovernorate,
      ),
    );
  }

  Widget _buildSearchField(ColorScheme scheme) {
    return _filterCard(
      scheme,
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'ابحث عن خدمة أو احتياج...',
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: _searchController.text.isEmpty
              ? null
              : IconButton(
                  onPressed: () {
                    _searchController.clear();
                    _loadNeeds(refresh: true);
                    setState(() {});
                  },
                  icon: const Icon(Icons.close_rounded),
                ),
          border: InputBorder.none,
          hintStyle: TextStyle(color: scheme.onSurfaceVariant),
        ),
      ),
    );
  }

  Widget _buildCategoryPicker(ColorScheme scheme) {
    return _filterCard(
      scheme,
      child: DropdownButtonFormField<String>(
        value: _selectedCategory,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: 'نوع الخدمة',
          prefixIcon: const Icon(Icons.category_outlined),
          border: InputBorder.none,
          labelStyle: TextStyle(color: scheme.onSurfaceVariant),
        ),
        items: [
          const DropdownMenuItem<String>(
            value: null,
            child: Text('كل الخدمات'),
          ),
          for (final category in _categories)
            DropdownMenuItem<String>(
              value: category['slug']?.toString(),
              child: Text(category['name_ar']?.toString() ?? 'خدمة'),
            ),
        ],
        onChanged: _selectCategory,
      ),
    );
  }

  Widget _filterCard(ColorScheme scheme, {required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: child,
    );
  }

  Widget _buildNeedCard(Map<String, dynamic> need, ColorScheme scheme) {
    final title = need['title']?.toString().trim() ?? 'احتياج خدمة';
    final category = need['category_name_ar']?.toString() ?? 'خدمة';
    final city = need['city']?.toString().trim() ?? '';
    final requester = need['requester_name']?.toString().trim() ?? 'مستخدم';
    final urgency = need['urgency']?.toString() ?? 'normal';
    final urgencyColor = switch (urgency) {
      'urgent' => scheme.error,
      'high' => const Color(0xFFC27A15),
      'low' => _primary,
      _ => scheme.secondary,
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Material(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: () => _openNeed(need),
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.45)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: _primary.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        category,
                        style: const TextStyle(
                          color: _primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Icon(Icons.priority_high_rounded, size: 15, color: urgencyColor),
                    const SizedBox(width: 2),
                    Text(
                      _urgencyLabel(urgency),
                      style: TextStyle(
                        color: urgencyColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 9),
                Row(
                  children: [
                    Icon(Icons.person_outline_rounded, size: 15, color: scheme.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        requester.isEmpty ? 'مستخدم' : requester,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
                      ),
                    ),
                    if (city.isNotEmpty) ...[
                      Icon(Icons.location_on_outlined, size: 15, color: scheme.onSurfaceVariant),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          city,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
                        ),
                      ),
                    ],
                  ],
                ),
                if ((need['description']?.toString().trim().isNotEmpty ?? false)) ...[
                  const SizedBox(height: 9),
                  Text(
                    need['description'].toString().trim(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 12,
                      height: 1.45,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      'عرض التفاصيل والتواصل',
                      style: TextStyle(
                        color: _primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(width: 5),
                    const Icon(Icons.arrow_back_rounded, color: _primary, size: 16),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessageCard(ColorScheme scheme, String message, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.45)),
      ),
      child: Column(
        children: [
          Icon(icon, color: _primary, size: 36),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontSize: 13,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }

  String _urgencyLabel(String urgency) => switch (urgency) {
        'urgent' => 'عاجل جدًا',
        'high' => 'مهم',
        'low' => 'عادي',
        _ => 'متوسط',
      };
}
