// lib/features/community/presentation/pages/my_community_needs_page.dart

import 'package:flutter/material.dart';
import 'package:loqma/features/community/data/repositories/community_needs_repository.dart';
import 'package:loqma/features/community/presentation/pages/community_need_details_page.dart';
import 'package:loqma/features/community/presentation/pages/add_community_need_page.dart';

enum _NeedSort { newest, oldest, urgent }

class MyCommunityNeedsPage extends StatefulWidget {
  const MyCommunityNeedsPage({super.key});

  @override
  State<MyCommunityNeedsPage> createState() => _MyCommunityNeedsPageState();
}

class _MyCommunityNeedsPageState extends State<MyCommunityNeedsPage>
    with SingleTickerProviderStateMixin {
  final _repository = CommunityNeedsRepository();
  late TabController _tabController;

  // ─────────────── الألوان ───────────────
  static const _green = Color(0xFF0B7650);
  static const _greenSoft = Color(0xFFE8F5EE);
  static const _darkGreen = Color(0xFF0F2E23);
  static const _background = Color(0xFFF5F9F7);
  static const _red = Color(0xFFB54747);
  static const _blue = Color(0xFF3679C8);
  static const _orange = Color(0xFFE28B00);
  static const _muted = Color(0xFF71837C);
  static const _border = Color(0xFFE8F1EC);

  // ─────────────── الحالة ───────────────
  bool _loading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _needs = [];

  // ✅ الترتيب
  _NeedSort _sort = _NeedSort.newest;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadNeeds();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════
  // LOAD
  // ═══════════════════════════════════════════════════════════

  Future<void> _loadNeeds() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final rows = await _repository.getMyNeeds();
      if (!mounted) return;
      setState(() {
        _needs = rows;
        _loading = false;
      });
    } catch (e) {
      debugPrint('❌ loadMyNeeds error: $e');
      if (mounted) {
        setState(() {
          _loading = false;
          _errorMessage = 'تعذر تحميل احتياجاتك';
        });
      }
    }
  }

  // ═══════════════════════════════════════════════════════════
  // ✅ EDIT NEED
  // ═══════════════════════════════════════════════════════════

  Future<void> _editNeed(Map<String, dynamic> need) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddCommunityNeedPage(
          needId: need['id']?.toString(),
          initialData: need,
        ),
      ),
    );

    if (result == true && mounted) {
      await _loadNeeds();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '✅ تم تحديث الاحتياج بنجاح',
              textDirection: TextDirection.rtl,
            ),
            backgroundColor: _green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // ═══════════════════════════════════════════════════════════
  // ✅ CANCEL NEED
  // ═══════════════════════════════════════════════════════════

  Future<void> _cancelNeed(Map<String, dynamic> need) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: _red),
            SizedBox(width: 8),
            Text('إلغاء الاحتياج'),
          ],
        ),
        content: const Text(
          'هل أنت متأكد؟ الاحتياج مش هيتعرض تاني.',
          style: TextStyle(fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('رجوع'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('تأكيد الإلغاء'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await _repository.cancelNeed(need['id'].toString());
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '✅ تم إلغاء الاحتياج',
            textDirection: TextDirection.rtl,
          ),
          backgroundColor: _green,
          behavior: SnackBarBehavior.floating,
        ),
      );

      await _loadNeeds();
    } catch (e) {
      debugPrint('❌ cancelNeed error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'تعذر إلغاء الاحتياج',
              textDirection: TextDirection.rtl,
            ),
            backgroundColor: _red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // ═══════════════════════════════════════════════════════════
  // ✅ DISMISS NEED (إخفاء من عند اليوزر بس)
  // ═══════════════════════════════════════════════════════════
  //
  // ⚠️ الاحتياج **مش بيتحذف** من الـ DB — بس بيتخفي من عند اليوزر
  //    البيانات تفضل محفوظة للأدلة والمراجعة.
  // ═══════════════════════════════════════════════════════════
  Future<void> _dismissNeed(Map<String, dynamic> need) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Row(
          children: [
            Icon(Icons.visibility_off_rounded, color: _red),
            SizedBox(width: 8),
            Text('إخفاء من عندي'),
          ],
        ),
        content: const Text(
          'هيتشال من عندك بس — لكن هيفضل محفوظ في قاعدة البيانات '
          'للأدلة والمراجعة.\n\n'
          'مش هتقدر تشوفه تاني.',
          style: TextStyle(fontSize: 13, height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('رجوع'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('إخفاء'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await _repository.dismissNeed(need['id'].toString());
      if (!mounted) return;

      // ✅ إزالة من القائمة مباشرة (تجربة أسرع)
      setState(() {
        _needs
            .removeWhere((n) => n['id']?.toString() == need['id']?.toString());
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '✅ تم الإخفاء من عندك',
            textDirection: TextDirection.rtl,
          ),
          backgroundColor: _green,
          behavior: SnackBarBehavior.floating,
        ),
      );

      await _loadNeeds();
    } catch (e) {
      debugPrint('❌ dismissNeed error: $e');
      if (mounted) {
        final msg = e.toString().replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              msg.isNotEmpty ? msg : 'تعذر إخفاء الاحتياج',
              textDirection: TextDirection.rtl,
            ),
            backgroundColor: _red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // ═══════════════════════════════════════════════════════════
  // ✅ SORT
  // ═══════════════════════════════════════════════════════════

  List<Map<String, dynamic>> _sortedNeeds(List<Map<String, dynamic>> items) {
    final list = List<Map<String, dynamic>>.from(items);

    switch (_sort) {
      case _NeedSort.newest:
        list.sort((a, b) {
          final aDate = _parseDate(a['created_at']) ?? DateTime(2000);
          final bDate = _parseDate(b['created_at']) ?? DateTime(2000);
          return bDate.compareTo(aDate);
        });
        break;

      case _NeedSort.oldest:
        list.sort((a, b) {
          final aDate = _parseDate(a['created_at']) ?? DateTime(2000);
          final bDate = _parseDate(b['created_at']) ?? DateTime(2000);
          return aDate.compareTo(bDate);
        });
        break;

      case _NeedSort.urgent:
        list.sort((a, b) {
          return _urgencyWeight(b['urgency'])
              .compareTo(_urgencyWeight(a['urgency']));
        });
        break;
    }

    return list;
  }

  int _urgencyWeight(dynamic urgency) {
    switch (urgency?.toString()) {
      case 'urgent':
        return 4;
      case 'high':
        return 3;
      case 'normal':
        return 2;
      case 'low':
        return 1;
      default:
        return 0;
    }
  }

  // ═══════════════════════════════════════════════════════════
  // FILTERS
  // ═══════════════════════════════════════════════════════════

  List<Map<String, dynamic>> get _activeNeeds {
    final filtered = _needs.where((n) {
      final status = n['status']?.toString() ?? 'active';
      return status == 'active' || status == 'matched';
    }).toList();

    return _sortedNeeds(filtered);
  }

  List<Map<String, dynamic>> get _inactiveNeeds {
    final filtered = _needs.where((n) {
      final status = n['status']?.toString() ?? 'active';
      return status == 'fulfilled' ||
          status == 'cancelled' ||
          status == 'expired';
    }).toList();

    return _sortedNeeds(filtered);
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
          scrolledUnderElevation: 0.5,
          centerTitle: true,
          title: const Text(
            'احتياجاتي',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 17,
            ),
          ),
          // ✅ قائمة الترتيب
          actions: [
            PopupMenuButton<_NeedSort>(
              icon: const Icon(Icons.sort_rounded),
              tooltip: 'ترتيب',
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              onSelected: (value) => setState(() => _sort = value),
              itemBuilder: (_) => [
                _buildSortItem(
                  value: _NeedSort.newest,
                  icon: Icons.access_time_rounded,
                  label: 'الأحدث',
                ),
                _buildSortItem(
                  value: _NeedSort.oldest,
                  icon: Icons.history_rounded,
                  label: 'الأقدم',
                ),
                _buildSortItem(
                  value: _NeedSort.urgent,
                  icon: Icons.priority_high_rounded,
                  label: 'الأولوية',
                ),
              ],
            ),
          ],
        ),
        body: _buildBody(),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const AddCommunityNeedPage(),
              ),
            );
            if (result == true && mounted) {
              _loadNeeds();
            }
          },
          backgroundColor: _green,
          foregroundColor: Colors.white,
          elevation: 3,
          icon: const Icon(Icons.add_rounded),
          label: const Text(
            'احتياج جديد',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ),
    );
  }

  PopupMenuItem<_NeedSort> _buildSortItem({
    required _NeedSort value,
    required IconData icon,
    required String label,
  }) {
    final selected = _sort == value;

    return PopupMenuItem<_NeedSort>(
      value: value,
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: selected ? _green : _muted,
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              color: selected ? _green : _darkGreen,
              fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
              fontSize: 13,
            ),
          ),
          if (selected) ...[
            const Spacer(),
            const Icon(Icons.check_rounded, size: 16, color: _green),
          ],
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _green));
    }

    if (_errorMessage != null) {
      return _buildErrorState();
    }

    if (_needs.isEmpty) {
      return _buildEmptyState();
    }

    final active = _activeNeeds;
    final inactive = _inactiveNeeds;

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _border),
          ),
          child: TabBar(
            controller: _tabController,
            indicator: BoxDecoration(
              color: _green,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: _green.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Colors.transparent,
            labelColor: Colors.white,
            unselectedLabelColor: _darkGreen,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 12.5,
            ),
            unselectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 12.5,
            ),
            tabs: [
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.check_circle_rounded, size: 15),
                    const SizedBox(width: 6),
                    Text('نشط (${active.length})'),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.timer_off_rounded, size: 15),
                    const SizedBox(width: 6),
                    Text('منتهي (${inactive.length})'),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildList(active, isActive: true),
              _buildList(inactive, isActive: false),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildList(
    List<Map<String, dynamic>> items, {
    required bool isActive,
  }) {
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isActive
                    ? Icons.volunteer_activism_outlined
                    : Icons.timer_off_outlined,
                color: _green.withValues(alpha: 0.4),
                size: 60,
              ),
              const SizedBox(height: 16),
              Text(
                isActive ? 'مفيش احتياجات نشطة' : 'مفيش احتياجات منتهية',
                style: const TextStyle(
                  color: _darkGreen,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: _green,
      onRefresh: _loadNeeds,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        itemCount: items.length,
        itemBuilder: (context, i) =>
            _buildNeedCard(items[i], isActive: isActive),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // NEED CARD
  // ═══════════════════════════════════════════════════════════

  Widget _buildNeedCard(
    Map<String, dynamic> need, {
    required bool isActive,
  }) {
    final id = need['id']?.toString() ?? '';
    final title = need['title']?.toString() ?? 'احتياج';
    final categoryName = need['category_name_ar']?.toString() ?? 'عام';
    final urgency = need['urgency']?.toString() ?? 'normal';
    final status = need['status']?.toString() ?? 'active';
    final contactCount = (need['contact_count'] as num?)?.toInt() ?? 0;
    final phoneCount = (need['phone_count'] as num?)?.toInt() ?? 0;
    final whatsappCount = (need['whatsapp_count'] as num?)?.toInt() ?? 0;
    final expiresAt = _parseDate(need['expires_at']);
    final isLive = status == 'active' || status == 'matched';

    final urgencyData = _urgencyData(urgency);
    final statusData = _statusData(status);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
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
            ).then((_) => _loadNeeds());
          },
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _border),
              boxShadow: [
                BoxShadow(
                  color: _darkGreen.withValues(alpha: 0.05),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: urgencyData.$3.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          urgencyData.$1,
                          color: urgencyData.$3,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _darkGreen,
                                fontSize: 15.5,
                                fontWeight: FontWeight.w900,
                                height: 1.3,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Icons.local_offer_rounded,
                                    size: 12, color: _muted),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    categoryName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: _muted,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // ✅ أزرار (تعديل + إلغاء) للاحتياج النشط
                      if (isActive) ...[
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () => _editNeed(need),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: _green.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: _green.withValues(alpha: 0.2),
                              ),
                            ),
                            child: const Icon(
                              Icons.edit_rounded,
                              color: _green,
                              size: 16,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () => _cancelNeed(need),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: _red.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: _red.withValues(alpha: 0.2),
                              ),
                            ),
                            child: const Icon(
                              Icons.delete_outline_rounded,
                              color: _red,
                              size: 16,
                            ),
                          ),
                        ),
                      ]
                      // ✅ زر الإخفاء للاحتياج المنتهي
                      else ...[
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () => _dismissNeed(need),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: _red.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: _red.withValues(alpha: 0.25),
                              ),
                            ),
                            child: const Icon(
                              Icons.visibility_off_rounded,
                              color: _red,
                              size: 18,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _buildStatusPill(statusData.$1, statusData.$3),
                      _buildTagPill(
                        icon: urgencyData.$1,
                        label: urgencyData.$2,
                        color: urgencyData.$3,
                      ),
                      if (isLive)
                        _buildTagPill(
                          icon: Icons.access_time_rounded,
                          label: _remainingText(expiresAt),
                          color: _orange,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Divider(height: 1, color: _border.withValues(alpha: 0.8)),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: contactCount > 0
                      ? Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _blue.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: _blue.withValues(alpha: 0.15)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: _blue.withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.people_alt_rounded,
                                  color: _blue,
                                  size: 17,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  '$contactCount شخص تواصلوا معاك',
                                  style: const TextStyle(
                                    color: _blue,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              _buildContactCounter(
                                icon: Icons.phone_rounded,
                                color: _green,
                                value: phoneCount,
                              ),
                              const SizedBox(width: 8),
                              _buildContactCounter(
                                icon: Icons.chat_rounded,
                                color: const Color(0xFF25D366),
                                value: whatsappCount,
                              ),
                            ],
                          ),
                        )
                      : Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FBF9),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: _muted.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.people_outline_rounded,
                                  color: _muted,
                                  size: 17,
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Text(
                                  'لسه محدش تواصل معاك',
                                  style: TextStyle(
                                    color: _muted,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const Icon(Icons.chevron_left_rounded,
                                  color: _muted, size: 18),
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

  Widget _buildStatusPill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTagPill({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactCounter({
    required IconData icon,
    required Color color,
    required int value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 13),
          const SizedBox(width: 4),
          Text(
            '$value',
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
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
                color: _greenSoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.volunteer_activism_outlined,
                color: _green,
                size: 42,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'مفيش احتياجات لسه',
              style: TextStyle(
                color: _darkGreen,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'ابدأ بنشر احتياجك الأول',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _muted,
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
            Text(
              _errorMessage ?? 'تعذر التحميل',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _darkGreen,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _loadNeeds,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('إعادة المحاولة'),
              style: FilledButton.styleFrom(
                backgroundColor: _green,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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

  (String, String, Color) _statusData(String status) {
    switch (status) {
      case 'active':
        return ('نشط', 'نشط', _green);
      case 'matched':
        return ('تم التواصل', 'تم التواصل', _blue);
      case 'fulfilled':
        return ('اتوفر', 'اتوفر', _green);
      case 'cancelled':
        return ('ملغي', 'ملغي', _red);
      case 'expired':
        return ('منتهي', 'منتهي', _muted);
      default:
        return ('نشط', 'نشط', _green);
    }
  }
}
