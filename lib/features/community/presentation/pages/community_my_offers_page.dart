// lib/features/community/presentation/pages/community_my_offers_page.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:loqma/core/services/supabase_service.dart';
import 'package:loqma/features/community/presentation/pages/OfferDetailsMyOffersPage.dart';
import 'package:loqma/features/community/presentation/pages/user_profile_page.dart';
import '../../data/repositories/community_my_offers_repository.dart';

class CommunityMyOffersPage extends StatefulWidget {
  const CommunityMyOffersPage({super.key});

  @override
  State<CommunityMyOffersPage> createState() => _CommunityMyOffersPageState();
}

class _CommunityMyOffersPageState extends State<CommunityMyOffersPage> {
  final _repository = CommunityMyOffersRepository();
  final _searchController = TextEditingController();
  final SupabaseService _supabase = SupabaseService();
  bool _loading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _offers = [];
  String _filter = 'all';
  String? _busyRequestId;
  StreamSubscription? _realtimeSubscription;

  static const Color _primary = Color(0xFF005B3C);
  static const Color _primaryContainer = Color(0xFF0B7650);
  static const Color _secondaryContainer = Color(0xFFBEEDD8);
  static const Color _onSecondaryContainer = Color(0xFF426D5D);
  static const Color _surface = Color(0xFFF7FAF9);
  static const Color _surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color _surfaceContainerHigh = Color(0xFFE6E9E8);
  static const Color _surfaceVariant = Color(0xFFE0E3E2);
  static const Color _onSurface = Color(0xFF181C1C);
  static const Color _onSurfaceVariant = Color(0xFF3F4942);
  static const Color _errorColor = Color(0xFFBA1A1A);
  static const Color _errorContainer = Color(0xFFFFDAD6);
  static const Color _onErrorContainer = Color(0xFF93000A);
  static const Color _outlineVariant = Color(0xFFBEC9C0);
  static const Color _onPrimary = Color(0xFFFFFFFF);

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      if (mounted) setState(() {});
    });
    _load();
    _subscribeToRealtime();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _realtimeSubscription?.cancel();
    super.dispose();
  }

  void _subscribeToRealtime() {
    _realtimeSubscription = _supabase.client
        .from('community_offers')
        .stream(primaryKey: ['id']).listen((_) {
      if (mounted) {
        _load();
      }
    }, onError: (error) {
      debugPrint('❌ Realtime error: $error');
    });
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final offers = await _repository.getMyOffersWithRequests();

      for (var i = 0; i < offers.length; i++) {
        final offerId = offers[i]['id'].toString();
        try {
          final images = await _supabase.getOfferImages(offerId);
          offers[i]['images'] = images;
          offers[i]['image'] = images.isNotEmpty ? images.first : null;
        } catch (e) {
          print('❌ Error loading images for offer $offerId: $e');
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
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = 'تعذر تحميل عروضك حاليًا. حاول مرة أخرى.';
      });
    }
  }

  List<Map<String, dynamic>> get _visibleOffers {
    final query = _searchController.text.trim().toLowerCase();
    return _offers.where((offer) {
      final requests = _requests(offer);
      final matchesFilter = _filter == 'all' ||
          requests.any((request) => request['status'] == _filter);
      if (!matchesFilter) return false;
      if (query.isEmpty) return true;
      final title = (offer['title'] ?? '').toString().toLowerCase();
      final description = (offer['description'] ?? '').toString().toLowerCase();
      final requestText = requests
          .map((request) => request['requester']?['name']?.toString() ?? '')
          .join(' ')
          .toLowerCase();
      return title.contains(query) ||
          description.contains(query) ||
          requestText.contains(query);
    }).toList();
  }

  List<Map<String, dynamic>> _requests(Map<String, dynamic> offer) {
    final raw = offer['requests'];
    if (raw is! List) return [];
    return raw.map((row) => Map<String, dynamic>.from(row as Map)).toList();
  }

  Future<void> _changeStatus(String requestId, String status) async {
    setState(() => _busyRequestId = requestId);
    try {
      await _repository.updateRequestStatus(
        requestId: requestId,
        status: status,
      );
      if (!mounted) return;
      _showMessage(
        status == 'accepted' ? '✅ تم قبول الطلب بنجاح' : '❌ تم رفض الطلب',
        success: status == 'accepted',
      );
      await _load();
    } catch (error) {
      if (mounted) _showMessage('⚠️ تعذر تحديث الطلب، حاول مرة أخرى');
    } finally {
      if (mounted) setState(() => _busyRequestId = null);
    }
  }

  Future<void> _confirmReject(String requestId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: _errorColor),
            SizedBox(width: 8),
            Text('رفض الطلب'),
          ],
        ),
        content: const Text('هل أنت متأكد من رفض طلب هذا المستخدم؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            style: TextButton.styleFrom(
              foregroundColor: _onSurfaceVariant,
            ),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: _errorColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('رفض الطلب'),
          ),
        ],
      ),
    );
    if (confirmed == true) await _changeStatus(requestId, 'rejected');
  }

  void _showMessage(String message, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, textDirection: TextDirection.rtl),
        backgroundColor: success ? _primary : _errorColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _surface,
        appBar: _buildAppBar(),
        body: _body(),
        bottomNavigationBar: _buildBottomNav(),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white.withOpacity(0.85),
      elevation: 0,
      titleSpacing: 0,
      toolbarHeight: 72,
      title: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: _primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'ل',
                    style: TextStyle(
                      color: _onPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'لقمة',
                  style: TextStyle(
                    color: _primary,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: _secondaryContainer,
                    borderRadius: BorderRadius.circular(9999),
                  ),
                  child: const Text(
                    'عروضي',
                    style: TextStyle(
                      color: _onSecondaryContainer,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _secondaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    onPressed: () {},
                    icon: const Icon(
                      Icons.notifications_none_rounded,
                      color: _primary,
                      size: 24,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(
          color: _primaryContainer,
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
        subtitle: 'عندما تضيف ملابس أو أثاثًا ستظهر طلباته هنا.',
      );
    }

    return RefreshIndicator(
      color: _primaryContainer,
      onRefresh: _load,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  _buildSearchBar(),
                  const SizedBox(height: 16),
                  _buildStatsCard(),
                  const SizedBox(height: 16),
                  _buildFilters(),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          if (_visibleOffers.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Center(
                  child: Text('لا توجد نتائج مطابقة للبحث'),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _buildOfferCard(_visibleOffers[index]),
                  childCount: _visibleOffers.length,
                ),
              ),
            ),
          const SliverToBoxAdapter(
            child: SizedBox(height: 100),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: _surfaceContainerLowest,
        borderRadius: BorderRadius.circular(9999),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: _surfaceVariant),
      ),
      child: Row(
        children: [
          const Padding(
            padding: EdgeInsets.only(right: 16),
            child: Icon(
              Icons.search_rounded,
              color: _primary,
              size: 24,
            ),
          ),
          Expanded(
            child: TextField(
              controller: _searchController,
              textDirection: TextDirection.rtl,
              decoration: const InputDecoration(
                hintText: 'البحث في عروضي...',
                hintStyle: TextStyle(
                  color: _onSurfaceVariant,
                  fontSize: 16,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          if (_searchController.text.isNotEmpty)
            IconButton(
              onPressed: _searchController.clear,
              icon: const Icon(
                Icons.close_rounded,
                color: _onSurfaceVariant,
                size: 20,
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildStatsCard() {
    final totalOffers = _offers.length;
    final totalRequests = _offers.expand((offer) => _requests(offer)).length;
    final pending = _offers
        .expand((offer) => _requests(offer))
        .where((request) => request['status'] == 'pending')
        .length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0B7650), Color(0xFF005B3C)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _primaryContainer.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'إحصائياتي',
            style: TextStyle(
              color: _onPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildStatItem(
                icon: Icons.inventory_2_rounded,
                value: '$totalOffers',
                label: 'العروض',
              ),
              _buildStatItem(
                icon: Icons.pending_actions_rounded,
                value: '$totalRequests',
                label: 'الطلبات',
              ),
              _buildStatItem(
                icon: Icons.auto_awesome_rounded,
                value: '$pending',
                label: 'جديد',
                showBadge: pending > 0,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
    bool showBadge = false,
  }) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Stack(
          children: [
            if (showBadge)
              Positioned(
                top: -4,
                right: -4,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: const BoxDecoration(
                    color: _errorColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            Column(
              children: [
                Icon(icon, color: _onPrimary, size: 28),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: _onPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    color: _onPrimary.withOpacity(0.8),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters() {
    final filters = [
      {'key': 'all', 'label': 'الكل', 'count': _offers.length},
      {
        'key': 'pending',
        'label': 'جديد',
        'count': _offers
            .expand((offer) => _requests(offer))
            .where((r) => r['status'] == 'pending')
            .length
      },
      {
        'key': 'accepted',
        'label': 'مقبول',
        'count': _offers
            .expand((offer) => _requests(offer))
            .where((r) => r['status'] == 'accepted')
            .length
      },
      {'key': 'completed', 'label': 'مكتمل', 'count': 0},
      {'key': 'rejected', 'label': 'مرفوض', 'count': 0},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((filter) {
          final isSelected = _filter == filter['key'];
          final count = filter['count'] as int;
          return Padding(
            padding: const EdgeInsets.only(left: 8),
            child: GestureDetector(
              onTap: () => setState(() => _filter = filter['key'] as String),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? _primary : _surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(9999),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: _primary.withOpacity(0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  children: [
                    Text(
                      filter['label'] as String,
                      style: TextStyle(
                        color: isSelected ? _onPrimary : _onSurfaceVariant,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (count > 0) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.white.withOpacity(0.2)
                              : _primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(9999),
                        ),
                        child: Text(
                          '$count',
                          style: TextStyle(
                            color: isSelected ? _onPrimary : _primary,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildOfferCard(Map<String, dynamic> offer) {
    final requests = _requests(offer);
    final totalRequests = requests.length;
    final pending = requests.where((r) => r['status'] == 'pending').length;
    final accepted = requests.where((r) => r['status'] == 'accepted').length;
    final completed = requests.where((r) => r['status'] == 'completed').length;
    final rejected = requests.where((r) => r['status'] == 'rejected').length;

    final images = offer['images'] as List? ?? [];
    final image = images.isNotEmpty
        ? images.first.toString()
        : (offer['image']?.toString() ?? '');

    final title = (offer['title'] ?? 'عرض مجتمعي').toString();
    final status = (offer['status'] ?? 'available').toString();
    final createdAt = offer['created_at']?.toString() ?? '';

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OfferDetailsMyOffersPage(
              offer: offer,
              onOfferUpdated: () {
                _load();
              },
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _surfaceContainerLowest,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: _primaryContainer.withOpacity(0.04),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: _surfaceVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        width: 80,
                        height: 80,
                        color: _secondaryContainer,
                        child: image.isNotEmpty
                            ? Image.network(
                                image,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(
                                  Icons.checkroom_rounded,
                                  color: _primaryContainer,
                                  size: 32,
                                ),
                              )
                            : const Icon(
                                Icons.checkroom_rounded,
                                color: _primaryContainer,
                                size: 32,
                              ),
                      ),
                    ),
                    Positioned(
                      bottom: -4,
                      left: -4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getStatusColor(status),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _getStatusLabel(status),
                          style: const TextStyle(
                            color: _onPrimary,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
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
                          color: _onSurface,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(
                            Icons.schedule_rounded,
                            size: 14,
                            color: _onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatDate(createdAt),
                            style: const TextStyle(
                              color: _onSurfaceVariant,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            width: 3,
                            height: 3,
                            decoration: const BoxDecoration(
                              color: _outlineVariant,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '$totalRequests طلب',
                            style: const TextStyle(
                              color: _onSurfaceVariant,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // ✅ إحصائيات الطلبات
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          if (pending > 0)
                            _buildStatBadge(
                                '⏳ جديد', pending, const Color(0xFFB36B12)),
                          if (accepted > 0)
                            _buildStatBadge(
                                '✅ مقبول', accepted, const Color(0xFF3679C8)),
                          if (completed > 0)
                            _buildStatBadge('🎉 مكتمل', completed, _primary),
                          if (rejected > 0)
                            _buildStatBadge('❌ مرفوض', rejected, _errorColor),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (requests.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(color: _surfaceVariant, height: 1),
              const SizedBox(height: 8),
              // ✅ عرض الطلبات بشكل أنيق
              ...requests.take(2).map((request) => _buildRequestTile(request)),
              if (requests.length > 2)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: TextButton(
                    onPressed: () {
                      // TODO: فتح صفحة كل الطلبات
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('📋 عرض كل الطلبات'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    child: Text(
                      'عرض جميع الطلبات (${requests.length})',
                      style: const TextStyle(
                        color: _primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatBadge(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 2),
          Text(
            '$count',
            style: TextStyle(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestTile(Map<String, dynamic> request) {
    final status = (request['status'] ?? 'pending').toString();
    final requester = request['requester'] as Map? ?? {};
    final name = requester['name']?.toString() ?? 'مستخدم';
    final avatar = requester['avatar_url']?.toString() ?? '';
    final requestId = request['id'].toString();
    final busy = _busyRequestId == requestId;
    final isPending = status == 'pending';

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => UserProfilePage(
              userId: request['user_id']?.toString() ?? '',
              userName: name,
              userAvatar: avatar,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color:
                isPending ? const Color(0xFFFFF0DA) : const Color(0xFFE8EEE9),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => UserProfilePage(
                      userId: request['user_id']?.toString() ?? '',
                      userName: name,
                      userAvatar: avatar,
                    ),
                  ),
                );
              },
              child: CircleAvatar(
                radius: 18,
                backgroundColor: _secondaryContainer,
                backgroundImage:
                    avatar.isNotEmpty ? NetworkImage(avatar) : null,
                child: avatar.isEmpty
                    ? const Icon(
                        Icons.person_outline_rounded,
                        color: _primaryContainer,
                        size: 18,
                      )
                    : null,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          color: _onSurface,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (isPending) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF0DA),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'جديد',
                            style: TextStyle(
                              color: Color(0xFFB36B12),
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Row(
                    children: [
                      Icon(
                        isPending
                            ? Icons.auto_awesome_rounded
                            : Icons.schedule_rounded,
                        size: 12,
                        color:
                            isPending ? _primaryContainer : _onSurfaceVariant,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        isPending ? 'طلب جديد' : _getStatusLabel(status),
                        style: TextStyle(
                          color: isPending ? _primary : _onSurfaceVariant,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (isPending) ...[
              Row(
                children: [
                  GestureDetector(
                    onTap: busy
                        ? null
                        : () => _changeStatus(requestId, 'accepted'),
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: const BoxDecoration(
                        color: _primary,
                        shape: BoxShape.circle,
                      ),
                      child: busy
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: _onPrimary,
                              ),
                            )
                          : const Icon(
                              Icons.check_rounded,
                              color: _onPrimary,
                              size: 16,
                            ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: busy ? null : () => _confirmReject(requestId),
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: const BoxDecoration(
                        color: _errorContainer,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        color: _onErrorContainer,
                        size: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: _surface,
        boxShadow: [
          BoxShadow(
            color: _primaryContainer.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(Icons.home_rounded, 'الرئيسية', false),
          _buildNavItem(Icons.local_offer_rounded, 'عروضي', true),
          _buildNavItem(Icons.chat_bubble_outline_rounded, 'المحادثات', false),
          _buildNavItem(Icons.person_outline_rounded, 'حسابي', false),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, bool isSelected) {
    return GestureDetector(
      onTap: () {},
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? _secondaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(9999),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? _onSecondaryContainer : _onSurfaceVariant,
              size: 24,
            ),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? _onSecondaryContainer : _onSurfaceVariant,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    String? subtitle,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _secondaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: _primaryContainer, size: 48),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: const TextStyle(
                color: _onSurface,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _onSurfaceVariant,
                  fontSize: 14,
                ),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              FilledButton(
                onPressed: onAction,
                style: FilledButton.styleFrom(
                  backgroundColor: _primaryContainer,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(9999),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: Text(actionLabel),
              ),
            ],
          ],
        ),
      ),
    );
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

  String _getStatusLabel(String status) {
    switch (status) {
      case 'available':
        return 'متاح';
      case 'pending':
        return 'جديد';
      case 'accepted':
        return 'مقبول';
      case 'completed':
        return 'مكتمل';
      case 'rejected':
        return 'مرفوض';
      case 'ready_for_pickup':
        return 'جاهز';
      case 'picked_up':
        return 'تم الاستلام';
      default:
        return 'متاح';
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'available':
        return _primaryContainer;
      case 'pending':
        return const Color(0xFFB36B12);
      case 'accepted':
        return const Color(0xFF3679C8);
      case 'completed':
        return _primary;
      case 'rejected':
        return _errorColor;
      case 'ready_for_pickup':
        return const Color(0xFF0B7650);
      case 'picked_up':
        return const Color(0xFF6651B5);
      default:
        return _primaryContainer;
    }
  }
}
