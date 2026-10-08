// lib/features/community/presentation/pages/community_my_offers_page.dart

import 'package:flutter/material.dart';
import 'package:loqma/core/services/supabase_service.dart';
import 'package:loqma/features/community/presentation/pages/community_offer_details_page.dart';
import 'package:loqma/features/community/presentation/pages/add_community_offer_page.dart';
import 'package:loqma/features/community/presentation/utils/offer_expiry_helper.dart';
import '../../data/repositories/community_my_offers_repository.dart';

class CommunityMyOffersPage extends StatefulWidget {
  const CommunityMyOffersPage({super.key});

  @override
  State<CommunityMyOffersPage> createState() => _CommunityMyOffersPageState();
}

class _CommunityMyOffersPageState extends State<CommunityMyOffersPage>
    with SingleTickerProviderStateMixin {
  final _repository = CommunityMyOffersRepository();
  final _searchController = TextEditingController();
  final SupabaseService _supabase = SupabaseService();

  late TabController _tabController;

  bool _loading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _offers = [];
  String? _busyOfferId;

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: 2, vsync: this);

    _searchController.addListener(() {
      if (mounted) setState(() {});
    });

    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // ============================================================
  // ✅ LOAD
  // ============================================================

  Future<void> _load() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final allOffers = await _repository.getMyOffers();

      // ✅ فلترة client-side — استبعد cancelled
      final offers = allOffers.where((offer) {
        final status = (offer['status'] ?? '').toString().toLowerCase();
        return status != 'cancelled';
      }).toList();

      // جلب الصور لكل عرض
      for (var i = 0; i < offers.length; i++) {
        final offerId = offers[i]['id'].toString();
        try {
          final image = await _repository.getOfferImage(offerId);
          offers[i]['image'] = image;
          offers[i]['images'] = image != null ? [image] : [];
        } catch (e) {
          offers[i]['images'] = [];
          offers[i]['image'] = null;
        }
      }

      if (!mounted) return;

      setState(() {
        _offers = offers;
        _loading = false;
      });
    } catch (error) {
      debugPrint('❌ getMyOffers error: $error');

      if (!mounted) return;

      setState(() {
        _loading = false;
        _errorMessage = 'تعذر تحميل عروضك حاليًا. حاول مرة أخرى.';
      });
    }
  }

  // ============================================================
  // ✅ DELETE OFFER (Optimistic UI + Rollback)
  // ============================================================

  Future<void> _deleteOffer(String offerId) async {
    final colors = Theme.of(context).colorScheme;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text('إلغاء العرض'),
        content: const Text(
          'هل أنت متأكد من إلغاء هذا العرض؟ لا يمكن التراجع عن هذا الإجراء.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('رجوع'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: colors.error,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('تأكيد الإلغاء'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final previousOffers = List<Map<String, dynamic>>.from(_offers);

    setState(() {
      _busyOfferId = offerId;
      _offers = _offers
          .where((o) => o['id'].toString() != offerId)
          .toList(growable: false);
    });

    try {
      await _repository.deleteOffer(offerId);

      if (!mounted) return;

      _showMessage('✅ تم إلغاء العرض بنجاح', success: true);

      await _load();
    } catch (error) {
      debugPrint('❌ deleteOffer error: $error');

      if (mounted) {
        setState(() {
          _offers = previousOffers;
        });

        _showMessage('⚠️ تعذر إلغاء العرض. حاول مرة أخرى.');
      }
    } finally {
      if (mounted) {
        setState(() => _busyOfferId = null);
      }
    }
  }

  // ============================================================
  // ✅ EDIT OFFER
  // ============================================================

  Future<void> _editOffer(Map<String, dynamic> offer) async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => AddCommunityOfferPage(
          offerId: offer['id']?.toString(),
          initialData: offer,
        ),
      ),
    );

    if (result != null && mounted) {
      await _load();
      if (mounted) {
        _showMessage('✅ تم تحديث العرض بنجاح', success: true);
      }
    }
  }

  // ============================================================
  // ✅ MARK AS COMPLETED (تم البيع)
  // ============================================================

  Future<void> _markAsCompleted(Map<String, dynamic> offer) async {
    final colors = Theme.of(context).colorScheme;
    final offerId = offer['id'].toString();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        icon: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: colors.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.check_circle_rounded,
            color: colors.primary,
            size: 32,
          ),
        ),
        title: const Text(
          'تم البيع؟',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        content: const Text(
          'هل أنت متأكد أن هذا العرض تم بيعه؟ هيتم إخفاء العرض من المستخدمين ومش هيظهر تاني، ومش هتقدر تعدله بعد كده.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            style: TextButton.styleFrom(
              foregroundColor: colors.onSurfaceVariant,
            ),
            child: const Text(
              'رجوع',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: colors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'تم البيع',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _busyOfferId = offerId;
    });

    try {
      await _repository.markOfferAsCompleted(offerId);

      if (!mounted) return;

      _showMessage('🎉 مبروك! تم تحديد العرض كـ "تم البيع"', success: true);

      await _load();
    } catch (error) {
      debugPrint('❌ markAsCompleted error: $error');

      if (mounted) {
        _showMessage('⚠️ تعذر تحديد العرض كـ "تم البيع". حاول مرة أخرى.');
      }
    } finally {
      if (mounted) {
        setState(() => _busyOfferId = null);
      }
    }
  }

  // ============================================================
  // ✅ RENEW OFFER (تجديد)
  // ============================================================

  Future<void> _renewOffer(Map<String, dynamic> offer) async {
    final colors = Theme.of(context).colorScheme;
    final offerId = offer['id'].toString();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        icon: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: colors.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.refresh_rounded,
            color: colors.primary,
            size: 32,
          ),
        ),
        title: const Text(
          'تجديد العرض',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        content: const Text(
          'هيتم تجديد العرض لمدة 7 أيام إضافية، وهيرجع يظهر للمستخدمين تاني.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            style: TextButton.styleFrom(
              foregroundColor: colors.onSurfaceVariant,
            ),
            child: const Text(
              'رجوع',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: colors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'تجديد',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _busyOfferId = offerId;
    });

    try {
      final newExpiry = await _repository.renewOffer(offerId, days: 7);

      if (!mounted) return;

      if (newExpiry != null) {
        _showMessage('✅ تم تجديد العرض بنجاح', success: true);
      } else {
        _showMessage('⚠️ تعذر تجديد العرض. حاول مرة أخرى.');
      }

      await _load();
    } catch (error) {
      debugPrint('❌ renewOffer error: $error');

      if (mounted) {
        _showMessage('⚠️ تعذر تجديد العرض. حاول مرة أخرى.');
      }
    } finally {
      if (mounted) {
        setState(() => _busyOfferId = null);
      }
    }
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(String message, {bool success = false}) {
    final colors = Theme.of(context).colorScheme;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, textDirection: TextDirection.rtl),
        backgroundColor: success ? colors.primary : colors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  // ============================================================
  // تصنيف العروض (نشط / منتهي)
  // ============================================================

  List<Map<String, dynamic>> get _activeOffers {
    return _offers.where((offer) {
      final status = (offer['status'] ?? '').toString().toLowerCase();

      // ✅ النشط: available أو active بس
      if (status != 'available' && status != 'active') return false;

      final expiresAt = _parseDate(offer['expires_at']);
      return expiresAt == null || expiresAt.isAfter(DateTime.now());
    }).toList();
  }

  /// ✅ العروض المنتهية (expired) — بس مش completed
  List<Map<String, dynamic>> get _expiredOnlyOffers {
    return _offers.where((offer) {
      final status = (offer['status'] ?? '').toString().toLowerCase();

      // ✅ expired
      if (status == 'expired') return true;

      // ✅ available بس expires_at فات → منتهي
      if (status == 'available' || status == 'active') {
        final expiresAt = _parseDate(offer['expires_at']);
        return expiresAt != null && !expiresAt.isAfter(DateTime.now());
      }

      return false;
    }).toList();
  }

  /// ✅ العروض المبيعة (completed)
  List<Map<String, dynamic>> get _completedOffers {
    return _offers.where((offer) {
      final status = (offer['status'] ?? '').toString().toLowerCase();
      return status == 'completed';
    }).toList();
  }

  /// ✅ كل العروض المنتهية (expired + completed)
  List<Map<String, dynamic>> get _allInactiveOffers {
    return [
      ..._expiredOnlyOffers,
      ..._completedOffers,
    ];
  }

  // ============================================================
  // فلترة حسب البحث
  // ============================================================

  List<Map<String, dynamic>> _applySearch(List<Map<String, dynamic>> list) {
    final query = _searchController.text.trim().toLowerCase();

    if (query.isEmpty) return list;

    return list.where((offer) {
      final title = (offer['title'] ?? '').toString().toLowerCase();
      final description = (offer['description'] ?? '').toString().toLowerCase();

      return title.contains(query) || description.contains(query);
    }).toList();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor:
            isDark ? const Color(0xFF141414) : const Color(0xFFF6F7F8),
        appBar: AppBar(
          backgroundColor:
              isDark ? const Color(0xFF1F1F1F) : Colors.transparent,
          elevation: 0,
          centerTitle: true,
          title: Text(
            'عروضي',
            style: TextStyle(
              color: colors.onSurface,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          automaticallyImplyLeading: false,
        ),
        body: _body(),
      ),
    );
  }

  // ============================================================
  // BODY
  // ============================================================

  Widget _body() {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_loading) {
      return Center(
        child: CircularProgressIndicator(
          color: colors.primary,
          strokeWidth: 3,
        ),
      );
    }

    if (_errorMessage != null) {
      return _buildEmptyState(
        icon: Icons.cloud_off_rounded,
        title: 'تعذر تحميل عروضك',
        subtitle: _errorMessage,
        actionLabel: 'إعادة المحاولة',
        onAction: _load,
      );
    }

    if (_offers.isEmpty) {
      return _buildEmptyState(
        icon: Icons.inventory_2_outlined,
        title: 'لم تضف أي عرض بعد',
        subtitle: 'عندما تضيف ملابس أو أثاثًا ستظهر عروضك هنا.',
      );
    }

    final activeCount = _activeOffers.length;
    final expiredCount = _allInactiveOffers.length;

    return Column(
      children: [
        // ✅ شريط البحث
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
          child: _buildSearchBar(colors, isDark),
        ),

        // ✅ التابين
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF1F1F1F)
                : colors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(14),
          ),
          child: TabBar(
            controller: _tabController,
            indicator: BoxDecoration(
              color: colors.primary,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: colors.primary.withValues(alpha: 0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Colors.transparent,
            labelColor: Colors.white,
            unselectedLabelColor: colors.onSurfaceVariant,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
            unselectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
            tabs: [
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.check_circle_rounded, size: 16),
                    const SizedBox(width: 6),
                    Text('نشط ($activeCount)'),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.timer_off_rounded, size: 16),
                    const SizedBox(width: 6),
                    Text('منتهي ($expiredCount)'),
                  ],
                ),
              ),
            ],
          ),
        ),

        // ✅ المحتوى
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildOffersList(
                _applySearch(_activeOffers),
                colors,
                isDark,
                emptyMessage: 'مفيش عروض نشطة',
              ),
              _buildOffersList(
                _applySearch(_allInactiveOffers),
                colors,
                isDark,
                emptyMessage: 'مفيش عروض منتهية',
                isExpired: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================
  // OFFERS LIST
  // ============================================================

  Widget _buildOffersList(
    List<Map<String, dynamic>> offers,
    ColorScheme colors,
    bool isDark, {
    required String emptyMessage,
    bool isExpired = false,
  }) {
    if (offers.isEmpty) {
      return RefreshIndicator(
        color: colors.primary,
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 60),
            Center(
              child: Column(
                children: [
                  Icon(
                    isExpired
                        ? Icons.timer_off_rounded
                        : Icons.inventory_2_outlined,
                    color: colors.onSurfaceVariant,
                    size: 56,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    emptyMessage,
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: colors.primary,
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 60),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: offers.length,
        itemBuilder: (context, index) => _buildOfferCard(
          offers[index],
          colors,
          isDark,
          isExpired: isExpired,
        ),
      ),
    );
  }

  // ============================================================
  // SEARCH BAR
  // ============================================================

  Widget _buildSearchBar(ColorScheme colors, bool isDark) {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F1F1F) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? Colors.transparent
              : colors.outlineVariant.withValues(alpha: 0.6),
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
      ),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Icon(
              Icons.search_rounded,
              color: colors.primary,
              size: 20,
            ),
          ),
          Expanded(
            child: TextField(
              controller: _searchController,
              textDirection: TextDirection.rtl,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'ابحث في عروضي...',
                hintStyle: TextStyle(
                  color: colors.onSurfaceVariant,
                  fontSize: 13,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          if (_searchController.text.isNotEmpty)
            IconButton(
              onPressed: _searchController.clear,
              icon: Icon(
                Icons.close_rounded,
                color: colors.onSurfaceVariant,
                size: 18,
              ),
            ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }

  // ============================================================
  // OFFER CARD
  // ============================================================

  Widget _buildOfferCard(
    Map<String, dynamic> offer,
    ColorScheme colors,
    bool isDark, {
    bool isExpired = false,
  }) {
    final images = offer['images'] as List? ?? [];
    final image = images.isNotEmpty
        ? images.first.toString()
        : (offer['image']?.toString() ?? '');
    final title = (offer['title'] ?? 'عرض مجتمعي').toString();
    final description = (offer['description'] ?? '').toString();
    final price = (offer['price'] as num?)?.toDouble() ?? 0;
    final category = (offer['category'] ?? 'أخرى').toString();
    final itemCondition = (offer['item_condition'] ?? 'good').toString();
    final quantity = (offer['quantity'] as num?)?.toInt() ?? 1;
    final status = (offer['status'] ?? 'available').toString();
    final createdAt = offer['created_at']?.toString() ?? '';
    final pickupLocation = (offer['pickup_location'] ?? '').toString();
    final offerId = offer['id'].toString();
    final busy = _busyOfferId == offerId;

    final expiresAt = _parseDate(offer['expires_at']);

    // ✅ هل العرض "تم البيع" (completed)؟
    final isCompleted = status.toLowerCase() == 'completed';

    const editColor = Color(0xFF3679C8);
    const completeColor = Color(0xFF0B9B63);
    const renewColor = Color(0xFFE28B00);
    final deleteColor = colors.error;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CommunityOfferDetailsPage(offer: offer),
          ),
        );
      },
      child: Opacity(
        opacity: isExpired && !busy ? 0.92 : 1,
        child: Container(
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1D1D1D) : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : colors.outlineVariant.withValues(alpha: 0.5),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ✅ الصورة + شارات فوقها
              Stack(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 150,
                    child: image.isNotEmpty
                        ? Image.network(
                            image,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Container(
                                color: colors.primary.withValues(alpha: 0.08),
                                child: Center(
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: colors.primary,
                                      strokeWidth: 2,
                                    ),
                                  ),
                                ),
                              );
                            },
                            errorBuilder: (_, __, ___) => Container(
                              color: colors.primary.withValues(alpha: 0.08),
                              child: Icon(
                                Icons.checkroom_rounded,
                                color: colors.primary,
                                size: 34,
                              ),
                            ),
                          )
                        : Container(
                            color: colors.primary.withValues(alpha: 0.08),
                            child: Icon(
                              Icons.checkroom_rounded,
                              color: colors.primary,
                              size: 34,
                            ),
                          ),
                  ),

                  // تظليل خفيف أسفل الصورة لوضوح الشارات
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      height: 46,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.35),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),

                  // شارة الحالة (أعلى يمين)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: _getStatusColor(status),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color:
                                _getStatusColor(status).withValues(alpha: 0.4),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        _getStatusLabel(status),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),

                  // السعر (أعلى شمال)
                  if (price > 0)
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          '$price ج.م',
                          style: TextStyle(
                            color: colors.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),

                  // المدة المتبقية (أسفل يمين على الصورة)
                  Positioned(
                    bottom: 8,
                    right: 10,
                    child: OfferExpiryHelper.buildBadge(
                      expiresAt: expiresAt,
                      compact: true,
                    ),
                  ),
                ],
              ),

              // ✅ محتوى الكارت
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // العنوان + الوقت
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colors.onSurface,
                              fontSize: 15.5,
                              fontWeight: FontWeight.w800,
                              height: 1.3,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.schedule_rounded,
                              size: 12,
                              color: colors.onSurfaceVariant,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              _formatDate(createdAt),
                              style: TextStyle(
                                color: colors.onSurfaceVariant,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
                          fontSize: 11.5,
                          height: 1.3,
                        ),
                      ),
                    ],

                    const SizedBox(height: 10),

                    // ✅ التصنيف + الحالة + الكمية
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _buildTag(
                          category,
                          colors.primary,
                          colors.primary.withValues(alpha: 0.08),
                        ),
                        _buildTag(
                          _getConditionLabel(itemCondition),
                          colors.onSurfaceVariant,
                          colors.onSurfaceVariant.withValues(alpha: 0.08),
                        ),
                        _buildTag(
                          'الكمية: $quantity',
                          const Color(0xFFB5690A),
                          const Color(0xFFB5690A).withValues(alpha: 0.08),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // ✅ مكان الاستلام
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 13,
                          color: colors.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            pickupLocation.isEmpty
                                ? 'مكان الاستلام غير محدد'
                                : pickupLocation,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colors.onSurfaceVariant,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ✅ خط فاصل خفيف قبل شريط الأزرار
              Divider(
                height: 1,
                thickness: 1,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : colors.outlineVariant.withValues(alpha: 0.5),
              ),

              // ✅ شريط الأزرار
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: busy
                    ? const SizedBox(
                        height: 40,
                        child: Center(
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      )
                    : Row(
                        children: [
                          // ══════════════════════════════════════
                          // ✅ عرض نشط → تم البيع + تعديل + حذف
                          // ══════════════════════════════════════
                          if (!isExpired) ...[
                            Expanded(
                              child: _buildActionButton(
                                label: 'تم البيع',
                                icon: Icons.check_circle_rounded,
                                color: completeColor,
                                onTap: () => _markAsCompleted(offer),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildActionButton(
                                label: 'تعديل',
                                icon: Icons.edit_rounded,
                                color: editColor,
                                onTap: () => _editOffer(offer),
                              ),
                            ),
                            const SizedBox(width: 8),
                            _buildIconOnlyButton(
                              icon: Icons.delete_rounded,
                              color: deleteColor,
                              onTap: () => _deleteOffer(offerId),
                              tooltip: 'إلغاء العرض',
                            ),
                          ]

                          // ══════════════════════════════════════
                          // ✅ عرض منتهي (expired) → تجديد + حذف
                          // ══════════════════════════════════════
                          else if (!isCompleted) ...[
                            Expanded(
                              child: _buildActionButton(
                                label: 'تجديد',
                                icon: Icons.refresh_rounded,
                                color: renewColor,
                                onTap: () => _renewOffer(offer),
                              ),
                            ),
                            const SizedBox(width: 8),
                            _buildIconOnlyButton(
                              icon: Icons.delete_rounded,
                              color: deleteColor,
                              onTap: () => _deleteOffer(offerId),
                              tooltip: 'إلغاء العرض',
                            ),
                          ]

                          // ══════════════════════════════════════
                          // ✅ عرض مبيع (completed) → حذف بس (بعرض كامل)
                          // ══════════════════════════════════════
                          else ...[
                            Expanded(
                              child: _buildActionButton(
                                label: 'حذف العرض',
                                icon: Icons.delete_rounded,
                                color: deleteColor,
                                onTap: () => _deleteOffer(offerId),
                              ),
                            ),
                          ],
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // TAG (شارة صغيرة للتصنيف/الحالة/الكمية)
  // ============================================================

  Widget _buildTag(String text, Color foreground, Color background) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: foreground,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  // ============================================================
  // زر إجراء رئيسي (بخلفية لونية + أيقونة + نص)
  // ============================================================

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 17),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // زر إجراء بأيقونة فقط (مربّع)
  // ============================================================

  Widget _buildIconOnlyButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    String? tooltip,
  }) {
    final button = Material(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
      ),
    );

    if (tooltip == null) return button;
    return Tooltip(message: tooltip, child: button);
  }

  // ============================================================
  // EMPTY STATE
  // ============================================================

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    String? subtitle,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final colors = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: colors.primary, size: 48),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: TextStyle(
                color: colors.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colors.onSurfaceVariant,
                  fontSize: 13,
                ),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              FilledButton(
                onPressed: onAction,
                style: FilledButton.styleFrom(
                  backgroundColor: colors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(actionLabel),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ============================================================
  // HELPERS
  // ============================================================

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    if (text.isEmpty || text == 'null') return null;
    return DateTime.tryParse(text);
  }

  String _formatDate(String date) {
    if (date.isEmpty) return '--';

    try {
      final parsed = DateTime.parse(date);
      final now = DateTime.now();
      final diff = now.difference(parsed);

      if (diff.inDays > 0) return 'منذ ${diff.inDays} يوم';
      if (diff.inHours > 0) return 'منذ ${diff.inHours} ساعة';
      if (diff.inMinutes > 0) return 'منذ ${diff.inMinutes} دقيقة';

      return 'الآن';
    } catch (_) {
      return date.substring(0, 10);
    }
  }

  String _getConditionLabel(String condition) {
    switch (condition) {
      case 'new':
        return 'جديد';
      case 'very_good':
        return 'ممتاز';
      case 'good':
        return 'جيد';
      case 'needs_repair':
        return 'يحتاج إصلاح';
      case 'used':
        return 'مستعمل';
      default:
        return 'غير محدد';
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'available':
        return 'متاح';
      case 'active':
        return 'نشط';
      case 'sold':
        return 'تم البيع';
      case 'pending':
        return 'في الانتظار';
      case 'accepted':
        return 'مقبول';
      case 'completed':
        return 'تم البيع';
      case 'rejected':
        return 'مرفوض';
      case 'ready_for_pickup':
        return 'جاهز';
      case 'picked_up':
        return 'تم الاستلام';
      case 'cancelled':
        return 'ملغي';
      case 'expired':
        return 'منتهي';
      default:
        return 'متاح';
    }
  }

  Color _getStatusColor(String status) {
    final colors = Theme.of(context).colorScheme;

    switch (status) {
      case 'available':
      case 'active':
        return colors.primary;
      case 'sold':
      case 'completed':
        return const Color(0xFF0B7650);
      case 'pending':
        return const Color(0xFFE28B00);
      case 'accepted':
        return const Color(0xFF3679C8);
      case 'rejected':
        return colors.error;
      case 'ready_for_pickup':
        return colors.primary;
      case 'picked_up':
        return const Color(0xFF6651B5);
      case 'cancelled':
        return colors.error;
      case 'expired':
        return const Color(0xFF71837C);
      default:
        return colors.primary;
    }
  }
}
