// lib/features/community/presentation/pages/community_my_charity_donations_page.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:loqma/features/charity/data/repositories/charity_donation_repository_separate.dart';
import 'package:loqma/features/community/presentation/pages/community_charity_donation_details_page.dart';

class CommunityMyCharityDonationsPage extends StatefulWidget {
  const CommunityMyCharityDonationsPage({super.key});

  @override
  State<CommunityMyCharityDonationsPage> createState() =>
      _CommunityMyCharityDonationsPageState();
}

class _CommunityMyCharityDonationsPageState
    extends State<CommunityMyCharityDonationsPage>
    with TickerProviderStateMixin {
  final _repository = SeparateCharityDonationRepository();
  late Future<List<Map<String, dynamic>>> _future;
  String _filter = 'all';
  bool _loadingCode = false;
  StreamSubscription<List<Map<String, dynamic>>>? _donationSubscription;
  final Map<String, String> _knownStatuses = <String, String>{};

  // ─────────────── الألوان ───────────────
  static const _green = Color(0xFF0B7650);
  static const _greenLight = Color(0xFF2BAA76);
  static const _darkGreen = Color(0xFF0F2E23);
  static const _background = Color(0xFFF5F9F7);
  static const _cardBg = Colors.white;
  static const _red = Color(0xFFB54747);
  static const _orange = Color(0xFFE28B00);
  static const _blue = Color(0xFF3679C8);
  static const _purple = Color(0xFF6651B5);

  @override
  void initState() {
    super.initState();
    _future = _repository.getMyDonations();
    _subscribeToDonationUpdates();
  }

  void _subscribeToDonationUpdates() {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) return;

    _donationSubscription = Supabase.instance.client
        .from('charity_donation_requests')
        .stream(primaryKey: ['id']).listen((allRows) {
      final rows = allRows
          .where((row) => row['donor_id']?.toString() == userId)
          .toList();
      for (final row in rows) {
        final id = row['id']?.toString();
        final status = row['status']?.toString();
        if (id == null || status == null) continue;
        final previous = _knownStatuses[id];
        _knownStatuses[id] = status;
        if (previous != null && previous != status && mounted) {
          _message(_statusLabel(status));
        }
      }
      if (mounted) {
        setState(() {
          _future = _repository.getMyDonations();
        });
      }
    }, onError: (error) {
      debugPrint('DIRECT CHARITY TRACKING REALTIME ERROR: $error');
    });
  }

  @override
  void dispose() {
    _donationSubscription?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    final next = _repository.getMyDonations();
    if (!mounted) return;
    setState(() {
      _future = next;
    });
    try {
      await next;
    } catch (_) {}
  }

  Future<void> _showPickupCode(String requestId) async {
    if (_loadingCode) return;
    setState(() => _loadingCode = true);
    try {
      final code = await _repository.getPickupCode(requestId);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Row(
            children: [
              Icon(Icons.qr_code_2_rounded, color: _green),
              SizedBox(width: 8),
              Text('كود تسليم التبرع'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'اعرض هذا الكود للمندوب فقط عند استلام التبرع. لا ترسله لأي شخص آخر.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 18,
                ),
                decoration: BoxDecoration(
                  color: _green.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _green.withValues(alpha: 0.25),
                    width: 1.5,
                  ),
                ),
                child: SelectableText(
                  code,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _green,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.access_time_rounded,
                    size: 14,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'الكود صالح لمدة 7 أيام',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                style: FilledButton.styleFrom(
                  backgroundColor: _green,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'تم',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      );
    } catch (error) {
      if (mounted) _message(_friendlyError(error), error: true);
    } finally {
      if (mounted) setState(() => _loadingCode = false);
    }
  }

  /// ✅ استخدام RPC الجديدة
  Future<void> _markDonorReady(String requestId) async {
    try {
      await _repository.markDonorReadyV2(requestId);
      if (mounted) {
        _message('✅ تم تأكيد جاهزيتك للتسليم');
        await _refresh();
      }
    } catch (e) {
      if (mounted) _message('❌ فشل تأكيد الجاهزية: $e', error: true);
    }
  }

  bool _matches(Map<String, dynamic> row) {
    final status = row['status']?.toString() ?? 'pending';
    if (_filter == 'all') return true;
    return status == _filter;
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
        body: FutureBuilder<List<Map<String, dynamic>>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: _green),
              );
            }
            if (snapshot.hasError) {
              return _buildErrorState(_friendlyError(snapshot.error!));
            }

            final all = snapshot.data ?? const <Map<String, dynamic>>[];
            final rows = all.where(_matches).toList();

            final pending =
                all.where((r) => r['status']?.toString() == 'pending').length;

            // ✅ قيد التنفيذ (بيشمل volunteer_needed)
            final active = all
                .where((r) => {
                      'accepted',
                      'volunteer_needed',
                      'donor_ready',
                      'volunteer_assigned',
                      'picked_up_from_donor',
                      'in_transit'
                    }.contains(r['status']?.toString()))
                .length;

            final assigned = all
                .where((r) => {
                      'volunteer_assigned',
                      'picked_up_from_donor',
                      'in_transit'
                    }.contains(r['status']?.toString()))
                .length;

            final completed =
                all.where((r) => r['status']?.toString() == 'completed').length;

            // ✅ يظهر "يحتاج إجراء" لو:
            // 1. accepted → يعلن جاهزيته
            // 2. volunteer_needed → يعلن جاهزيته
            // 3. volunteer_assigned → يعرض الكود
            final actionRows = all
                .where((r) => {
                      'accepted',
                      'volunteer_needed',
                      'volunteer_assigned'
                    }.contains(r['status']?.toString()))
                .take(2)
                .toList();

            return RefreshIndicator(
              color: _green,
              onRefresh: _refresh,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                slivers: [
                  _buildSliverAppBar(),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        _buildHeroCard(pending),
                        const SizedBox(height: 18),
                        _buildStatsGrid(
                          pending: pending,
                          active: active,
                          assigned: assigned,
                          completed: completed,
                        ),
                        if (actionRows.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          _buildSectionHeader(
                            'يحتاج إلى إجراء',
                            '${actionRows.length}',
                            Icons.flash_on_rounded,
                            _orange,
                          ),
                          const SizedBox(height: 12),
                          ...actionRows.map(_buildActionCard),
                        ],
                        const SizedBox(height: 24),
                        _buildSectionHeader(
                          'تصفية التبرعات',
                          null,
                          Icons.filter_list_rounded,
                          _green,
                        ),
                        const SizedBox(height: 12),
                        _buildFilters(),
                        const SizedBox(height: 16),
                        if (rows.isEmpty)
                          _buildEmptyState()
                        else
                          ...rows.map(_buildDonationCard),
                      ]),
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

  // ═══════════════════════════════════════════════════════════
  // SLIVER APP BAR
  // ═══════════════════════════════════════════════════════════

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 90,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: _darkGreen,
      surfaceTintColor: Colors.transparent,
      title: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              'ل',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            'جُود',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          onPressed: _refresh,
          icon: const Icon(Icons.refresh_rounded, color: Colors.white),
          tooltip: 'تحديث',
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  // HERO CARD
  // ═══════════════════════════════════════════════════════════

  Widget _buildHeroCard(int pending) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_darkGreen, _green],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _darkGreen.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.volunteer_activism_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'مرحباً بك',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'متبرع الخير',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.15),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  pending > 0
                      ? Icons.notifications_active_rounded
                      : Icons.auto_awesome_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    pending > 0
                        ? 'لديك $pending تبرع يحتاج إلى متابعة'
                        : 'شكراً لمساهمتك في إيصال الخير',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // STATS GRID
  // ═══════════════════════════════════════════════════════════

  Widget _buildStatsGrid({
    required int pending,
    required int active,
    required int assigned,
    required int completed,
  }) {
    final stats = [
      _StatItem(
        label: 'طلبات جديدة',
        value: pending,
        icon: Icons.new_releases_rounded,
        color: _red,
        bg: _red.withValues(alpha: 0.08),
      ),
      _StatItem(
        label: 'قيد التنفيذ',
        value: active,
        icon: Icons.hourglass_top_rounded,
        color: _green,
        bg: _green.withValues(alpha: 0.08),
      ),
      _StatItem(
        label: 'في انتظار مندوب',
        value: assigned,
        icon: Icons.local_shipping_rounded,
        color: _blue,
        bg: _blue.withValues(alpha: 0.08),
      ),
      _StatItem(
        label: 'مكتملة',
        value: completed,
        icon: Icons.check_circle_rounded,
        color: const Color(0xFF496B5E),
        bg: const Color(0xFFE4EDEA),
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: stats.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.55,
      ),
      itemBuilder: (_, i) => _buildStatCard(stats[i]),
    );
  }

  Widget _buildStatCard(_StatItem stat) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(18),
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  stat.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF52645C),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: stat.bg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(stat.icon, color: stat.color, size: 16),
              ),
            ],
          ),
          Text(
            '${stat.value}',
            style: TextStyle(
              color: stat.color,
              fontSize: 28,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // SECTION HEADER
  // ═══════════════════════════════════════════════════════════

  Widget _buildSectionHeader(
    String title,
    String? count,
    IconData icon,
    Color color,
  ) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 17),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: _darkGreen,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        if (count != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              count,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  // ACTION CARD
  // ═══════════════════════════════════════════════════════════

  Widget _buildActionCard(Map<String, dynamic> row) {
    final status = row['status']?.toString() ?? 'pending';
    final deliveryType =
        row['delivery_type']?.toString() ?? 'charity_volunteer';
    final isIndependent = deliveryType == 'independent_volunteer';

    // ✅ لون وأيقونة حسب الحالة
    Color accentColor;
    IconData actionIcon;

    if (status == 'volunteer_assigned') {
      accentColor = _orange;
      actionIcon = Icons.qr_code_2_rounded;
    } else if (status == 'volunteer_needed') {
      accentColor = _purple;
      actionIcon = Icons.people_alt_rounded;
    } else {
      accentColor = _blue;
      actionIcon = Icons.front_hand_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border(
          right: BorderSide(color: accentColor, width: 4),
        ),
        boxShadow: [
          BoxShadow(
            color: _darkGreen.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(actionIcon, color: accentColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        row['title']?.toString() ?? 'تبرع مباشر',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _darkGreen,
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    if (isIndependent)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _purple.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'متطوعين',
                          style: TextStyle(
                            color: _purple,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _statusLabel(status),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: accentColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: accentColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      CommunityCharityDonationDetailsPage(donation: row),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Text(
                      'التفاصيل',
                      style: TextStyle(
                        color: accentColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: accentColor,
                      size: 11,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // FILTERS
  // ═══════════════════════════════════════════════════════════

  Widget _buildFilters() {
    // ✅ الفلاتر الجديدة (مع volunteer_needed + rejected)
    const filters = <String, String>{
      'all': 'الكل',
      'pending': 'في الانتظار',
      'accepted': 'مقبول',
      'volunteer_needed': 'مفتوح للمتطوعين',
      'donor_ready': 'جاهز للتسليم',
      'volunteer_assigned': 'تم تعيين المندوب',
      'in_transit': 'في الطريق',
      'completed': 'وصل للجمعية',
      'rejected': 'مرفوض',
    };

    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, index) {
          final key = filters.keys.elementAt(index);
          final active = _filter == key;

          // ✅ لون مخصص للـ volunteer_needed
          final activeColor = key == 'volunteer_needed' ? _purple : _green;

          return GestureDetector(
            onTap: () => setState(() => _filter = key),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: active ? activeColor : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: active ? activeColor : const Color(0xFFE0EBE5),
                ),
                boxShadow: active
                    ? [
                        BoxShadow(
                          color: activeColor.withValues(alpha: 0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: Text(
                  filters[key]!,
                  style: TextStyle(
                    color: active ? Colors.white : _darkGreen,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // DONATION CARD
  // ═══════════════════════════════════════════════════════════

  Widget _buildDonationCard(Map<String, dynamic> row) {
    final charity = row['charities'] is Map
        ? Map<String, dynamic>.from(row['charities'] as Map)
        : <String, dynamic>{};
    final status = row['status']?.toString() ?? 'pending';
    final deliveryType =
        row['delivery_type']?.toString() ?? 'charity_volunteer';
    final isIndependent = deliveryType == 'independent_volunteer';

    final images = row['images'] is List
        ? List<dynamic>.from(row['images'] as List)
        : <dynamic>[];
    final image = images.isNotEmpty ? images.first.toString() : '';
    final title = row['title']?.toString() ?? 'تبرع مباشر';
    final charityName = charity['name']?.toString() ?? 'جمعية موثقة';
    final volunteer = row['volunteer_name']?.toString();
    final isCurrentUserVolunteer = row['volunteer_id']?.toString() ==
        Supabase.instance.client.auth.currentUser?.id;

    // ✅ إظهار الأزرار حسب الحالة
    final showCode =
        (status == 'volunteer_assigned' || status == 'donor_ready') &&
            isCurrentUserVolunteer;
    final showDonorReady = status == 'accepted' || status == 'volunteer_needed';

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: _cardBg,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  CommunityCharityDonationDetailsPage(donation: row),
            ),
          ),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE8F1EC)),
              boxShadow: [
                BoxShadow(
                  color: _darkGreen.withValues(alpha: 0.04),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: SizedBox(
                        width: 72,
                        height: 72,
                        child: image.isEmpty
                            ? Container(
                                color: _green.withValues(alpha: 0.08),
                                child: const Icon(
                                  Icons.volunteer_activism_rounded,
                                  color: _green,
                                  size: 30,
                                ),
                              )
                            : Image.network(
                                image,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  color: _green.withValues(alpha: 0.08),
                                  child: const Icon(
                                    Icons.volunteer_activism_rounded,
                                    color: _green,
                                    size: 30,
                                  ),
                                ),
                              ),
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
                              fontWeight: FontWeight.w900,
                              fontSize: 14.5,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(
                                Icons.favorite_rounded,
                                color: _green,
                                size: 13,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  charityName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: _green,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 11.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              _buildStatusBadge(status),
                              if (isIndependent) ...[
                                const SizedBox(width: 6),
                                _buildDeliveryBadge(),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (volunteer != null && volunteer.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: (isIndependent ? _purple : _blue)
                          .withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isIndependent
                              ? Icons.person_rounded
                              : Icons.badge_outlined,
                          color: isIndependent ? _purple : _blue,
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            isIndependent
                                ? 'المتطوع: $volunteer'
                                : 'مندوب الجمعية: $volunteer',
                            style: TextStyle(
                              color: isIndependent ? _purple : _blue,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                _buildTimeline(status, isIndependent: isIndependent),
                if (showDonorReady) ...[
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => _markDonorReady(row['id'].toString()),
                      icon: const Icon(
                        Icons.check_circle_outline_rounded,
                        size: 18,
                      ),
                      label: const Text(
                        'أنا جاهز للتسليم',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: _green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
                if (showCode) ...[
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _loadingCode
                          ? null
                          : () => _showPickupCode(row['id'].toString()),
                      icon: const Icon(Icons.qr_code_2_rounded, size: 18),
                      label: Text(
                        _loadingCode
                            ? 'جار تجهيز الكود...'
                            : 'اعرض كود الاستلام للمندوب',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: _green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              _statusLabel(status),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// ✅ Badge جديد للمسار
  Widget _buildDeliveryBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _purple.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _purple.withValues(alpha: 0.2)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.people_alt_rounded, color: _purple, size: 10),
          SizedBox(width: 4),
          Text(
            'متطوعين',
            style: TextStyle(
              color: _purple,
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // TIMELINE
  // ═══════════════════════════════════════════════════════════

  Widget _buildTimeline(String status, {bool isIndependent = false}) {
    // ✅ خطوات ديناميكية حسب المسار
    final steps = <(String, String, IconData)>[
      ('pending', 'أرسلت', Icons.send_rounded),
      if (isIndependent) ...[
        ('volunteer_needed', 'متطوعين', Icons.people_alt_rounded),
      ] else ...[
        ('accepted', 'راجع', Icons.fact_check_outlined),
      ],
      ('donor_ready', 'جاهز', Icons.front_hand_rounded),
      ('volunteer_assigned', 'مندوب', Icons.badge_outlined),
      ('picked_up_from_donor', 'استلم', Icons.verified_user_outlined),
      ('completed', 'وصل', Icons.done_all_rounded),
    ];

    // ✅ تحديد الـ index الحالي
    int activeIndex;
    if (isIndependent) {
      activeIndex = switch (status) {
        'pending' => 0,
        'volunteer_needed' => 1,
        'accepted' => 2, // مش المفروض يحصل، بس احتياطي
        'donor_ready' => 2,
        'volunteer_assigned' => 3,
        'picked_up_from_donor' || 'in_transit' => 4,
        'completed' => 5,
        _ => 0,
      };
    } else {
      activeIndex = switch (status) {
        'pending' => 0,
        'accepted' => 1,
        'volunteer_needed' => 1, // مش المفروض يحصل، بس احتياطي
        'donor_ready' => 2,
        'volunteer_assigned' => 3,
        'picked_up_from_donor' || 'in_transit' => 4,
        'completed' => 5,
        _ => 0,
      };
    }

    final activeColor = _statusColor(status);

    return Row(
      children: List.generate(steps.length, (index) {
        final active = index <= activeIndex;
        final isLast = index == steps.length - 1;

        return Expanded(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: active ? activeColor : const Color(0xFFE5EEE9),
                        shape: BoxShape.circle,
                        boxShadow: active
                            ? [
                                BoxShadow(
                                  color: activeColor.withValues(alpha: 0.3),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Icon(
                        steps[index].$3,
                        color: active ? Colors.white : const Color(0xFF9AACA3),
                        size: 14,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      steps[index].$2,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: active ? _darkGreen : const Color(0xFF98A9A1),
                        fontSize: 9,
                        fontWeight: active ? FontWeight.w800 : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    height: 2,
                    margin: const EdgeInsets.only(bottom: 20),
                    color: index < activeIndex
                        ? activeColor
                        : const Color(0xFFE5EEE9),
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // EMPTY / ERROR STATES
  // ═══════════════════════════════════════════════════════════

  Widget _buildEmptyState() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 30),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE8F1EC)),
      ),
      child: Column(
        children: [
          Container(
            width: 70,
            height: 70,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _green.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.volunteer_activism_outlined,
              color: _green,
              size: 34,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'لا توجد تبرعات',
            style: TextStyle(
              color: _darkGreen,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'لم تقم بأي تبرع بهذا الفلتر بعد.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF71837C),
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String message) {
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
              'تعذر تحميل التبرعات',
              style: TextStyle(
                color: _darkGreen,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF71837C),
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _refresh,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('إعادة المحاولة'),
              style: FilledButton.styleFrom(
                backgroundColor: _green,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
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

  String _statusLabel(String status) =>
      <String, String>{
        'pending': 'في انتظار مراجعة الجمعية',
        'accepted': 'وافقت الجمعية — أعلن جاهزيتك',
        'volunteer_needed': 'مفتوح للمتطوعين — أعلن جاهزيتك',
        'donor_ready': 'أعلنت جاهزيتك — في انتظار المندوب',
        'volunteer_assigned': 'تم تعيين المندوب',
        'picked_up_from_donor': 'تم استلامه من المتبرع',
        'in_transit': 'التبرع في الطريق',
        'completed': 'وصل التبرع للجمعية',
        'rejected': 'لم تقبل الجمعية التبرع',
        'cancelled': 'تم إلغاء التبرع',
        'expired': 'انتهت مهلة التبرع',
      }[status] ??
      'جار تحديث الحالة';

  Color _statusColor(String status) {
    if (status == 'rejected' || status == 'cancelled' || status == 'expired') {
      return _red;
    }
    if (status == 'completed') return _green;
    if (status == 'volunteer_needed') return _purple;
    if (status == 'volunteer_assigned') return _orange;
    if (status == 'accepted') return _blue;
    if (status == 'donor_ready') return _blue;
    if (status == 'picked_up_from_donor' || status == 'in_transit') {
      return _orange;
    }
    return _green;
  }

  String _friendlyError(Object error) {
    final text = error.toString().toLowerCase();
    if (text.contains('permission') || text.contains('42501')) {
      return 'لا توجد صلاحية لقراءة تبرعاتك. سجّل الدخول مرة أخرى.';
    }
    if (text.contains('network') || text.contains('timeout')) {
      return 'تعذر الاتصال بالإنترنت.';
    }
    return 'تعذر تحميل تبرعاتك. حاول مرة أخرى.';
  }

  void _message(String text, {bool error = false}) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(text, textDirection: TextDirection.rtl),
          backgroundColor: error ? _red : _green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
}

// ═══════════════════════════════════════════════════════════
// STAT ITEM MODEL
// ═══════════════════════════════════════════════════════════

class _StatItem {
  final String label;
  final int value;
  final IconData icon;
  final Color color;
  final Color bg;

  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.bg,
  });
}
