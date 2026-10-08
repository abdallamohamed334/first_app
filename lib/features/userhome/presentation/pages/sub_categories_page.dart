// lib/features/userhome/presentation/pages/sub_categories_page.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:loqma/features/userhome/presentation/pages/category_offers_page.dart';

class SubCategoriesPage extends StatefulWidget {
  final String parentId;
  final String parentName;
  final String? parentSlug;

  const SubCategoriesPage({
    super.key,
    required this.parentId,
    required this.parentName,
    this.parentSlug,
  });

  @override
  State<SubCategoriesPage> createState() => _SubCategoriesPageState();
}

class _SubCategoriesPageState extends State<SubCategoriesPage> {
  static const Set<String> _institutionCatalogSlugs = {
    'grocery',
    'bakery',
    'butcher',
    'meat_shop',
    'poultry_shop',
    'wedding_hall',
    'game_store',
    'hotel',
    'home-restaurants',
    'household-items',
    'home-sweets',
    'home-food',
  };
  static const Color _bg = Color(0xFF0F0F0F);
  static const Color _card = Color(0xFF1C1C1E);
  static const Color _primaryRed = Color(0xFFE31C25);
  static const Color _primaryRedDark = Color(0xFF8E0F14);
  static const Color _textPrimary = Colors.white;
  static const Color _textSecondary = Color(0xFFAAAAAA);
  static const Color _border = Color(0x14FFFFFF);

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _children = [];
  bool _openingCategory = false;

  @override
  void initState() {
    super.initState();
    _loadChildren();
  }

  Future<void> _loadChildren() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final response = await Supabase.instance.client
          .from('marketplace_categories')
          .select('id, slug, name_ar, name_en, icon, sort_order, parent_id')
          .eq('parent_id', widget.parentId)
          .eq('is_active', true)
          .order('sort_order', ascending: true);

      if (!mounted) return;

      final rows = (response as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .where(
            (row) => widget.parentSlug != 'institution-offers' ||
                _institutionCatalogSlugs.contains(
                  row['slug']?.toString().trim().toLowerCase(),
                ),
          )
          .toList();

      setState(() {
        _children = rows;
        _loading = false;
      });

      debugPrint(
        '🟣 [SubCategories] Loaded ${rows.length} children for '
        'parentId=${widget.parentId}',
      );
    } catch (e) {
      debugPrint('❌ [SubCategories] error: $e');
      if (!mounted) return;
      setState(() {
        _error = 'تعذر تحميل الأقسام الفرعية';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Theme(
        data: ThemeData.dark().copyWith(
          scaffoldBackgroundColor: _bg,
          colorScheme: const ColorScheme.dark(
            primary: _primaryRed,
            surface: _bg,
            onSurface: _textPrimary,
          ),
        ),
        child: Scaffold(
          backgroundColor: _bg,
          appBar: AppBar(
            backgroundColor: _bg,
            surfaceTintColor: _bg,
            elevation: 0,
            centerTitle: true,
            iconTheme: const IconThemeData(color: _textPrimary),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.parentName,
                  style: const TextStyle(
                    color: _textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (!_loading && _children.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    '${_children.length} قسم فرعي',
                    style: const TextStyle(
                      color: _textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          body: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: _primaryRed),
      );
    }

    if (_error != null) {
      return _buildError();
    }

    if (_children.isEmpty) {
      return _buildEmpty();
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      physics: const BouncingScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 0.92,
      ),
      itemCount: _children.length,
      itemBuilder: (context, index) => _buildTile(_children[index]),
    );
  }

  Widget _buildTile(Map<String, dynamic> category) {
    final id = category['id']?.toString() ?? '';
    final name = category['name_ar']?.toString() ?? 'قسم';
    final slug = category['slug']?.toString() ?? '';
    final iconName = category['icon']?.toString() ?? '';

    if (id.isEmpty) return const SizedBox.shrink();

    return Material(
      color: _card,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _openSubCategory(id, name, slug),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _border, width: 1),
          ),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _primaryRed.withValues(alpha: 0.18),
                      _primaryRed.withValues(alpha: 0.06),
                    ],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _iconFromName(iconName),
                  color: _primaryRed,
                  size: 22,
                ),
              ),
              const SizedBox(height: 9),
              Flexible(
                child: Text(
                  name,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _textPrimary,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openSubCategory(String id, String name, String slug) async {
    if (_openingCategory || id.isEmpty) return;
    _openingCategory = true;
    // ✅ نشوف لو الفرع ده عنده فروع تانية
    bool hasChildren = false;
    try {
      final response = await Supabase.instance.client
          .from('marketplace_categories')
          .select('id')
          .eq('parent_id', id)
          .eq('is_active', true)
          .limit(1);

      hasChildren = (response as List).isNotEmpty;
    } catch (_) {
      hasChildren = false;
    }

    if (!mounted) return;

    if (hasChildren) {
      // ✅ عنده فروع → SubCategoriesPage تانية
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => SubCategoriesPage(
            parentId: id,
            parentName: name,
            parentSlug: slug,
          ),
        ),
      );
    } else {
      // ✅ مفيش فروع → CategoryOffersPage
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CategoryOffersPage(
            categoryId: id,
            categoryName: name,
            categorySlug: slug,
          ),
        ),
      );
    }
    if (mounted) _openingCategory = false;
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _card,
                shape: BoxShape.circle,
                border: Border.all(color: _border, width: 1),
              ),
              child: Icon(
                Icons.category_outlined,
                color: _textSecondary.withValues(alpha: 0.7),
                size: 36,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'مفيش أقسام فرعية',
              style: TextStyle(
                color: _textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'هنعرضلك العروض على طول',
              style: TextStyle(color: _textSecondary, fontSize: 12.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _card,
                shape: BoxShape.circle,
                border: Border.all(color: _border, width: 1),
              ),
              child: const Icon(
                Icons.cloud_off_rounded,
                color: _primaryRed,
                size: 36,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              _error ?? 'حصل خطأ',
              style: const TextStyle(
                color: _textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: _loadChildren,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('حاول مرة أخرى'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryRed,
                foregroundColor: Colors.white,
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

  IconData _iconFromName(String name) {
    switch (name) {
      case 'restaurant':
        return Icons.restaurant_rounded;
      case 'checkroom':
        return Icons.checkroom_rounded;
      case 'shoe':
        return Icons.hiking_rounded;
      case 'shopping_bag':
        return Icons.shopping_bag_rounded;
      case 'tv':
        return Icons.tv_rounded;
      case 'computer':
        return Icons.computer_rounded;
      case 'smartphone':
        return Icons.smartphone_rounded;
      case 'devices_other':
        return Icons.devices_other_rounded;
      case 'chair':
        return Icons.chair_rounded;
      case 'kitchen':
        return Icons.kitchen_rounded;
      case 'home':
        return Icons.home_rounded;
      case 'toys':
        return Icons.toys_rounded;
      case 'menu_book':
        return Icons.menu_book_rounded;
      case 'sports_soccer':
        return Icons.sports_soccer_rounded;
      case 'build':
        return Icons.build_rounded;
      case 'directions_car':
        return Icons.directions_car_rounded;
      case 'music_note':
        return Icons.music_note_rounded;
      case 'business_center':
        return Icons.business_center_rounded;
      case 'collections':
        return Icons.collections_rounded;
      case 'man':
        return Icons.man_rounded;
      case 'woman':
        return Icons.woman_rounded;
      case 'child_care':
        return Icons.child_care_rounded;
      case 'fitness_center':
        return Icons.fitness_center_rounded;
      case 'ac_unit':
        return Icons.ac_unit_rounded;
      case 'laptop':
        return Icons.laptop_rounded;
      case 'desktop_windows':
        return Icons.desktop_windows_rounded;
      case 'keyboard':
        return Icons.keyboard_rounded;
      case 'cable':
        return Icons.cable_rounded;
      case 'monitor':
        return Icons.monitor_rounded;
      case 'shopping_cart':
        return Icons.shopping_cart_rounded;
      case 'local_cafe':
        return Icons.local_cafe_rounded;
      case 'cleaning_services':
        return Icons.cleaning_services_rounded;
      case 'spa':
        return Icons.spa_rounded;
      case 'headphones':
        return Icons.headphones_rounded;
      case 'tablet':
        return Icons.tablet_rounded;
      case 'watch':
        return Icons.watch_rounded;
      case 'battery_charging_full':
        return Icons.battery_charging_full_rounded;
      case 'shield':
        return Icons.shield_rounded;
      case 'lightbulb':
        return Icons.lightbulb_rounded;
      case 'category':
      default:
        return Icons.category_rounded;
    }
  }
}
