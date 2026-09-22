// lib/features/charity/presentation/pages/charity_workspace_page.dart

import 'package:flutter/material.dart';
import 'package:loqma/features/charity/presentation/pages/charity_bottom_nav_bar.dart';
import 'package:loqma/features/charity/presentation/pages/charity_donation_requests_page.dart';
import 'package:loqma/features/institutions/presentation/pages/charity_institution_donations_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:loqma/features/charity/data/repositories/charity_donation_repository_separate.dart';
import 'package:loqma/features/charity/data/repositories/charity_institution_donations_repository.dart';
import 'package:loqma/features/charity/presentation/pages/charity_profile_page.dart';
import 'package:loqma/features/charity/presentation/pages/charity_notifications_page.dart';
import 'package:loqma/features/charity/presentation/pages/charity_volunteers_management_page.dart';
import 'package:loqma/features/charity/presentation/pages/charity_restaurant_donations_page.dart';

class CharityWorkspacePage extends StatefulWidget {
  const CharityWorkspacePage({super.key});

  @override
  State<CharityWorkspacePage> createState() => _CharityWorkspacePageState();
}

class _CharityWorkspacePageState extends State<CharityWorkspacePage>
    with SingleTickerProviderStateMixin {
  static const primary = Color(0xFF001E15);
  static const green = Color(0xFF006C48);
  static const greenLight = Color(0xFF2BAA76);
  static const mint = Color(0xFF97F2C3);
  static const background = Color(0xFFF8FAFA);
  static const purple = Color(0xFF6651B5);
  static const orange = Color(0xFFE28B00);
  static const red = Color(0xFFB54747);

  final _client = Supabase.instance.client;
  final _donationRepository = SeparateCharityDonationRepository();
  final _institutionDonationRepository =
      CharityInstitutionDonationsRepository();
  late Future<_WorkspaceSnapshot> _future;
  int _selectedNavIndex = 0;

  late AnimationController _fadeController;

  @override
  void initState() {
    super.initState();
    _future = _loadWorkspace();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<_WorkspaceSnapshot> _loadWorkspace() async {
    final authId = _client.auth.currentUser?.id;
    if (authId == null || authId.isEmpty) {
      return const _WorkspaceSnapshot.blocked(
        'انتهت الجلسة الحالية، يرجى تسجيل الدخول مرة أخرى.',
      );
    }

    final user = await _client
        .from('users')
        .select('user_type')
        .eq('id', authId)
        .maybeSingle();
    final role = user?['user_type']?.toString().trim().toLowerCase();
    if (role != 'charity') {
      return const _WorkspaceSnapshot.blocked(
        'هذه المساحة متاحة لحسابات الجمعيات فقط.',
      );
    }

    final charity = await _client
        .from('charities')
        .select('id, name, status, is_verified')
        .eq('user_id', authId)
        .maybeSingle();
    if (charity == null) {
      return const _WorkspaceSnapshot.blocked(
        'لا توجد جمعية مرتبطة بهذا الحساب. استخدم مساحة الحساب الصحيحة.',
      );
    }

    final charityId = charity['id'].toString();

    // ✅ جلب البيانات بالتوازي
    final results = await Future.wait([
      _donationRepository.getCharityDonations(),
      _institutionDonationRepository.listMyDonations(),
      _client
          .from('charity_volunteers')
          .select('id, status')
          .eq('charity_id', charityId),
    ]);

    final rows = List<Map<String, dynamic>>.from(results[0] as List);
    final institutionRows = List<Map<String, dynamic>>.from(results[1] as List);
    final volunteerRows = List<Map<String, dynamic>>.from(results[2] as List);

    // ✅ عدّادات
    int count(String status) =>
        rows.where((row) => row['status'] == status).length;
    int instCount(String status) =>
        institutionRows.where((row) => row['status'] == status).length;

    return _WorkspaceSnapshot(
      charityName: (charity['name'] as String?)?.trim().isNotEmpty == true
          ? charity['name'] as String
          : 'الجمعية',
      verified: charity['is_verified'] == true,
      totalRequests: rows.length,
      pendingRequests: count('pending'),
      institutionRequests: institutionRows.length,
      pendingInstitutionRequests: instCount('pending'),
      activeRequests: rows
          .where((row) => !{
                'completed',
                'rejected',
                'cancelled',
                'expired',
              }.contains(row['status']))
          .length,
      completedRequests: count('completed'),
      volunteers: volunteerRows.length,
      activeVolunteers:
          volunteerRows.where((row) => row['status'] == 'active').length,
      // ✅ جديد
      volunteerNeededRequests: count('volunteer_needed'),
      inProgressRequests: count('accepted') +
          count('donor_ready') +
          count('volunteer_assigned') +
          count('picked_up_from_donor') +
          count('in_transit'),
    );
  }

  Future<void> _refresh() async {
    final next = _loadWorkspace();
    if (!mounted) return;
    setState(() => _future = next);
    await next;
  }

  Future<void> _open(Widget page) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
    if (mounted) await _refresh();
  }

  Future<void> _onNavigationChanged(int index) async {
    if (!mounted || index == _selectedNavIndex) return;
    if (index == 0) {
      setState(() => _selectedNavIndex = 0);
      return;
    }

    final page = switch (index) {
      1 => const CharityInstitutionDonationsPage(),
      2 => const CharityDonationRequestsPage(),
      3 => const CharityVolunteersManagementPage(),
      4 => const CharityProfilePage(),
      _ => null,
    };
    if (page == null) return;

    setState(() => _selectedNavIndex = index);
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
    if (mounted) {
      setState(() => _selectedNavIndex = 0);
      await _refresh();
    }
  }

  // ═══════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: background,
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: primary,
          surfaceTintColor: Colors.white,
          elevation: 0,
          title: FutureBuilder<_WorkspaceSnapshot>(
            future: _future,
            builder: (_, snapshot) {
              final name = snapshot.data?.charityName ?? 'مساحة الجمعية';
              final verified = snapshot.data?.verified == true;
              return Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [primary, green],
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'ل',
                      style: TextStyle(
                        color: mint,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        if (verified)
                          Row(
                            children: [
                              Icon(Icons.verified_rounded,
                                  color: green, size: 11),
                              const SizedBox(width: 3),
                              const Text(
                                'حساب موثق',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: green,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          actions: [
            IconButton(
              onPressed: () => _open(const CharityNotificationsPage()),
              icon: const Icon(Icons.notifications_none_rounded),
              tooltip: 'إشعارات الجمعية',
            ),
            IconButton(
              onPressed: _refresh,
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'تحديث',
            ),
          ],
        ),
        body: FutureBuilder<_WorkspaceSnapshot>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _loadingState();
            }
            if (snapshot.hasError) {
              return _errorState('تعذر تحميل مساحة الجمعية حاليًا');
            }
            final data = snapshot.data!;
            if (data.isBlocked) {
              return _blockedState(data.blockedMessage!);
            }
            return _dashboard(data);
          },
        ),
        bottomNavigationBar: CharityBottomNavBar(
          currentIndex: _selectedNavIndex,
          onChanged: _onNavigationChanged,
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // LOADING STATE
  // ═══════════════════════════════════════════════════════════

  Widget _loadingState() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
      children: [
        // Skeleton Hero
        Container(
          height: 180,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                primary.withValues(alpha: 0.05),
                green.withValues(alpha: 0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(26),
          ),
        ),
        const SizedBox(height: 16),
        // Skeleton Metrics
        Row(
          children: List.generate(
            2,
            (i) => Expanded(
              child: Container(
                height: 90,
                margin: EdgeInsets.only(right: i == 0 ? 0 : 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Container(
          height: 80,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  // DASHBOARD
  // ═══════════════════════════════════════════════════════════

  Widget _dashboard(_WorkspaceSnapshot data) {
    _fadeController.forward();

    return RefreshIndicator(
      color: green,
      onRefresh: _refresh,
      child: FadeTransition(
        opacity: _fadeController,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics()),
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
          children: [
            _welcome(data),
            const SizedBox(height: 16),
            _metrics(data),
            const SizedBox(height: 14),
            _sourceSummary(data),
            // ✅ Action Alert للتبرعات المفتوحة
            if (data.volunteerNeededRequests > 0) ...[
              const SizedBox(height: 16),
              _volunteerNeededAlert(data),
            ],
            const SizedBox(height: 22),
            _sectionTitle(
                'متابعة التبرعات', Icons.dashboard_customize_outlined),
            const SizedBox(height: 10),
            _actionCard(
              Icons.restaurant_rounded,
              'تبرعات المطاعم',
              'اعرضي التبرعات الواردة من المطاعم وتابعي القبول والمتطوع والاستلام والتسليم',
              () => _open(const CharityRestaurantDonationsPage()),
            ),
            const SizedBox(height: 10),
            _actionCard(
              Icons.storefront_rounded,
              'متابعة المؤسسات',
              'تابعي تبرعات المؤسسات والقبول والمتطوع وكود الاستلام',
              () => _open(const CharityInstitutionDonationsPage()),
            ),
            const SizedBox(height: 10),
            _actionCard(
              Icons.volunteer_activism_rounded,
              'متابعة الأشخاص المتبرعين',
              'تابعي طلبات المستخدمين وقبولها وتعيين مندوب الجمعية',
              () => _open(const CharityDonationRequestsPage()),
            ),
            const SizedBox(height: 18),
            _activity(data),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title, IconData icon) => Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: green, size: 17),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: const TextStyle(
              color: primary,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      );

  // ═══════════════════════════════════════════════════════════
  // WELCOME CARD
  // ═══════════════════════════════════════════════════════════

  Widget _welcome(_WorkspaceSnapshot data) => Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [primary, green],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ),
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: green.withValues(alpha: 0.3),
              blurRadius: 24,
              offset: const Offset(0, 10),
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              'مرحباً، ${data.charityName}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          if (data.verified) ...[
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.verified_rounded,
                              color: mint,
                              size: 18,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        data.pendingRequests > 0
                            ? 'لديك ${data.pendingRequests} تبرع جديد يحتاج إلى مراجعة'
                            : 'كل التبرعات تحت السيطرة ✨',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (data.pendingRequests > 0) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => _open(const CharityDonationRequestsPage()),
                icon: const Icon(Icons.arrow_back_rounded, size: 18),
                label: const Text(
                  'عرض التبرعات الجديدة',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: primary,
                  backgroundColor: mint,
                  side: BorderSide.none,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ],
        ),
      );

  // ═══════════════════════════════════════════════════════════
  // VOLUNTEER NEEDED ALERT
  // ═══════════════════════════════════════════════════════════

  Widget _volunteerNeededAlert(_WorkspaceSnapshot data) => InkWell(
        onTap: () => _open(const CharityDonationRequestsPage()),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                purple.withValues(alpha: 0.08),
                purple.withValues(alpha: 0.02),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: purple.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: purple.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.people_alt_rounded,
                  color: purple,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${data.volunteerNeededRequests} تبرع مفتوح للمتطوعين',
                      style: const TextStyle(
                        color: purple,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'في انتظار متطوعين مستقلين يوصلوهم',
                      style: TextStyle(
                        color: purple,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: purple,
                size: 16,
              ),
            ],
          ),
        ),
      );

  // ═══════════════════════════════════════════════════════════
  // SOURCE SUMMARY
  // ═══════════════════════════════════════════════════════════

  Widget _sourceSummary(_WorkspaceSnapshot data) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE1E8E4)),
        ),
        child: Row(
          children: [
            Expanded(
              child: _sourceMetric(
                icon: Icons.person_outline_rounded,
                title: 'طلبات المستخدمين',
                value: '${data.totalRequests}',
                pending: data.pendingRequests,
              ),
            ),
            Container(width: 1, height: 48, color: const Color(0xFFE1E8E4)),
            Expanded(
              child: _sourceMetric(
                icon: Icons.storefront_rounded,
                title: 'تبرعات المؤسسات',
                value: '${data.institutionRequests}',
                pending: data.pendingInstitutionRequests,
              ),
            ),
          ],
        ),
      );

  Widget _sourceMetric({
    required IconData icon,
    required String title,
    required String value,
    required int pending,
  }) =>
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          children: [
            Icon(icon, color: green, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF5E7068),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$value إجمالي • $pending جديد',
                    style: const TextStyle(
                      color: primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  // ═══════════════════════════════════════════════════════════
  // METRICS
  // ═══════════════════════════════════════════════════════════

  Widget _metrics(_WorkspaceSnapshot data) => LayoutBuilder(
        builder: (_, constraints) {
          final columns = constraints.maxWidth < 520 ? 2 : 4;
          const gap = 10.0;
          final width = (constraints.maxWidth - gap * (columns - 1)) / columns;

          final cards = [
            _metric(
              'طلبات جديدة',
              '${data.pendingRequests}',
              Icons.new_releases_rounded,
              red,
            ),
            _metric(
              'قيد التنفيذ',
              '${data.inProgressRequests}',
              Icons.hourglass_top_rounded,
              orange,
            ),
            if (data.volunteerNeededRequests > 0)
              _metric(
                'مفتوح للمتطوعين',
                '${data.volunteerNeededRequests}',
                Icons.people_alt_rounded,
                purple,
              ),
            _metric(
              'المتطوعون',
              '${data.activeVolunteers}',
              Icons.local_shipping_rounded,
              const Color(0xFF8055B5),
            ),
            _metric(
              'مكتملة',
              '${data.completedRequests}',
              Icons.check_circle_rounded,
              green,
            ),
          ];

          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: cards
                .map((card) => SizedBox(width: width, child: card))
                .toList(),
          );
        },
      );

  Widget _metric(String label, String value, IconData icon, Color color) =>
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE1E8E4)),
          boxShadow: [
            BoxShadow(
              color: primary.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF5E7068),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                CircleAvatar(
                  radius: 15,
                  backgroundColor: color.withValues(alpha: 0.1),
                  foregroundColor: color,
                  child: Icon(icon, size: 16),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 23,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      );

  // ═══════════════════════════════════════════════════════════
  // ACTION CARD
  // ═══════════════════════════════════════════════════════════

  Widget _actionCard(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback? onTap, {
    bool disabled = false,
    Color? accentColor,
  }) =>
      Opacity(
        opacity: disabled ? 0.5 : 1,
        child: InkWell(
          onTap: disabled ? null : onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE1E8E4)),
              boxShadow: [
                BoxShadow(
                  color: primary.withValues(alpha: 0.03),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: (accentColor ?? green).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    icon,
                    color: accentColor ?? green,
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
                        style: const TextStyle(
                          color: primary,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF62786D),
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  disabled
                      ? Icons.lock_outline_rounded
                      : Icons.chevron_left_rounded,
                  color: accentColor ?? green,
                ),
              ],
            ),
          ),
        ),
      );

  // ═══════════════════════════════════════════════════════════
  // ACTIVITY
  // ═══════════════════════════════════════════════════════════

  Widget _activity(_WorkspaceSnapshot data) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE1E8E4)),
          boxShadow: [
            BoxShadow(
              color: primary.withValues(alpha: 0.03),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.insights_rounded,
                    color: green,
                    size: 17,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'آخر التحديثات',
                  style: TextStyle(
                    color: primary,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _activityLine(
              Icons.receipt_long_rounded,
              'إجمالي التبرعات المرتبطة بالجمعية: ${data.totalRequests}',
              green,
            ),
            const SizedBox(height: 10),
            _activityLine(
              Icons.groups_rounded,
              'المتطوعون النشطون: ${data.activeVolunteers} من ${data.volunteers}',
              purple,
            ),
            if (data.volunteerNeededRequests > 0) ...[
              const SizedBox(height: 10),
              _activityLine(
                Icons.people_alt_rounded,
                '${data.volunteerNeededRequests} تبرع مفتوح للمتطوعين',
                purple,
              ),
            ],
          ],
        ),
      );

  Widget _activityLine(IconData icon, String text, Color color) => Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xFF44574F),
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      );

  // ═══════════════════════════════════════════════════════════
  // ERROR / BLOCKED
  // ═══════════════════════════════════════════════════════════

  Widget _errorState(String message) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: red.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.error_outline_rounded,
                    color: red, size: 40),
              ),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: primary,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _refresh,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('إعادة المحاولة'),
                style: FilledButton.styleFrom(
                  backgroundColor: green,
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

  Widget _blockedState(String message) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 90,
                height: 90,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: green.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lock_outline_rounded,
                    color: green, size: 44),
              ),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: primary,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.arrow_back_rounded, size: 18),
                label: const Text('العودة'),
                style: FilledButton.styleFrom(
                  backgroundColor: green,
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
// WORKSPACE SNAPSHOT MODEL
// ═══════════════════════════════════════════════════════════

class _WorkspaceSnapshot {
  final String charityName;
  final bool verified;
  final int totalRequests;
  final int pendingRequests;
  final int institutionRequests;
  final int pendingInstitutionRequests;
  final int activeRequests;
  final int completedRequests;
  final int volunteers;
  final int activeVolunteers;
  final int volunteerNeededRequests; // ✅ جديد
  final int inProgressRequests; // ✅ جديد
  final bool isBlocked;
  final String? blockedMessage;

  const _WorkspaceSnapshot({
    required this.charityName,
    required this.verified,
    required this.totalRequests,
    required this.pendingRequests,
    required this.institutionRequests,
    required this.pendingInstitutionRequests,
    required this.activeRequests,
    required this.completedRequests,
    required this.volunteers,
    required this.activeVolunteers,
    required this.volunteerNeededRequests,
    required this.inProgressRequests,
  })  : isBlocked = false,
        blockedMessage = null;

  const _WorkspaceSnapshot.blocked(this.blockedMessage)
      : charityName = 'مساحة الجمعية',
        verified = false,
        totalRequests = 0,
        pendingRequests = 0,
        institutionRequests = 0,
        pendingInstitutionRequests = 0,
        activeRequests = 0,
        completedRequests = 0,
        volunteers = 0,
        activeVolunteers = 0,
        volunteerNeededRequests = 0,
        inProgressRequests = 0,
        isBlocked = true;
}
