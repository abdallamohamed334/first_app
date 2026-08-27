import 'package:flutter/material.dart';
import 'package:loqma/features/charity/presentation/pages/charity_bottom_nav_bar.dart';
import 'package:loqma/features/charity/presentation/pages/charity_donation_requests_page.dart';
import 'package:loqma/features/institutions/presentation/pages/charity_institution_donations_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:loqma/features/charity/data/repositories/charity_donation_repository_separate.dart';

import 'package:loqma/features/charity/presentation/pages/charity_direct_requests_page.dart';
import 'package:loqma/features/charity/data/repositories/charity_institution_donations_repository.dart';
import 'package:loqma/features/charity/presentation/pages/charity_profile_page.dart';
import 'package:loqma/features/charity/presentation/pages/charity_notifications_page.dart';

import 'package:loqma/features/charity/presentation/pages/charity_volunteers_management_page.dart';
import 'package:loqma/features/charity/presentation/pages/direct_charity_volunteer_tasks_page.dart';

class CharityWorkspacePage extends StatefulWidget {
  const CharityWorkspacePage({super.key});

  @override
  State<CharityWorkspacePage> createState() => _CharityWorkspacePageState();
}

class _CharityWorkspacePageState extends State<CharityWorkspacePage> {
  static const primary = Color(0xFF001E15);
  static const green = Color(0xFF006C48);
  static const mint = Color(0xFF97F2C3);
  static const background = Color(0xFFF8FAFA);

  final _client = Supabase.instance.client;
  final _donationRepository = SeparateCharityDonationRepository();
  final _institutionDonationRepository =
      CharityInstitutionDonationsRepository();
  late Future<_WorkspaceSnapshot> _future;
  int _selectedNavIndex = 0;

  @override
  void initState() {
    super.initState();
    _future = _loadWorkspace();
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
    final userRequestsFuture = _donationRepository.getCharityDonations();
    final institutionDonationsFuture =
        _institutionDonationRepository.listMyDonations();
    final volunteersFuture = _client
        .from('charity_volunteers')
        .select('id, status')
        .eq('charity_id', charityId);

    final userRequests = await userRequestsFuture;
    final institutionDonations = await institutionDonationsFuture;
    final volunteers = await volunteersFuture;

    final rows = List<Map<String, dynamic>>.from(userRequests);
    final institutionRows =
        List<Map<String, dynamic>>.from(institutionDonations);
    final volunteerRows = List<Map<String, dynamic>>.from(volunteers);
    int count(String status) =>
        rows.where((row) => row['status'] == status).length;
    int institutionCount(String status) =>
        institutionRows.where((row) => row['status'] == status).length;

    return _WorkspaceSnapshot(
      charityName: (charity['name'] as String?)?.trim().isNotEmpty == true
          ? charity['name'] as String
          : 'الجمعية',
      verified: charity['is_verified'] == true,
      totalRequests: rows.length,
      pendingRequests: count('pending'),
      institutionRequests: institutionRows.length,
      pendingInstitutionRequests: institutionCount('pending'),
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
    );
  }

  Future<void> _refresh() async {
    final next = _loadWorkspace();
    if (!mounted) return;
    setState(() {
      _future = next;
    });
    await next;
  }

  Future<void> _open(Widget page) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
    if (mounted) await _refresh();
  }

  void _openPickupNotice() {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text(
          'افتحي الطلب أولاً ثم اختاري تحقق من الاستلام لإرسال رقم الطلب والكود بأمان.'),
      behavior: SnackBarBehavior.floating,
    ));
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
            builder: (_, snapshot) => Row(
              children: [
                const CircleAvatar(
                  radius: 20,
                  backgroundColor: primary,
                  child: Text('ل',
                      style: TextStyle(
                          color: mint,
                          fontSize: 21,
                          fontWeight: FontWeight.w900)),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    snapshot.data?.charityName ?? 'مساحة الجمعية',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            IconButton(
              onPressed: () => _open(const CharityNotificationsPage()),
              icon: const Icon(Icons.notifications_none_rounded),
              tooltip: 'إشعارات الجمعية',
            ),
            IconButton(
                onPressed: () {
                  _refresh();
                },
                icon: const Icon(Icons.refresh_rounded),
                tooltip: 'تحديث'),
          ],
        ),
        body: FutureBuilder<_WorkspaceSnapshot>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                  child: CircularProgressIndicator(color: green));
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
          onChanged: (index) {
            _onNavigationChanged(index);
          },
        ),
      ),
    );
  }

  Widget _dashboard(_WorkspaceSnapshot data) {
    return RefreshIndicator(
      color: green,
      onRefresh: _refresh,
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
          const SizedBox(height: 22),
          const Text('متابعة التبرعات',
              style: TextStyle(
                  color: primary, fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          _actionCard(
              Icons.storefront_rounded,
              'متابعة المؤسسات',
              'تابعي تبرعات المطاعم والمؤسسات، القبول، المتطوع، وكود الاستلام',
              () => _open(const CharityInstitutionDonationsPage())),
          const SizedBox(height: 10),
          _actionCard(
              Icons.volunteer_activism_rounded,
              'متابعة الأشخاص المتبرعين',
              'تابعي طلبات المستخدمين وقبولها وتعيين مندوب الجمعية',
              () => _open(const CharityDonationRequestsPage())),
          const SizedBox(height: 18),
          _activity(data),
        ],
      ),
    );
  }

  Widget _welcome(_WorkspaceSnapshot data) => Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [primary, green],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft),
          borderRadius: BorderRadius.circular(26),
          boxShadow: const [
            BoxShadow(
                color: Color(0x24006C48), blurRadius: 18, offset: Offset(0, 8))
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Flexible(
                child: Text('مرحباً، ${data.charityName}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900))),
            const SizedBox(width: 8),
            Icon(
                data.verified ? Icons.verified_rounded : Icons.favorite_rounded,
                color: mint,
                size: 20),
          ]),
          const SizedBox(height: 8),
          Text(
              'لديك ${data.pendingRequests} تبرعات جديدة تحتاج إلى مراجعة وتعيين مندوبين.',
              style: const TextStyle(color: Colors.white70, height: 1.5)),
          const SizedBox(height: 16),
          OutlinedButton.icon(
              onPressed: () => _open(const CharityDonationRequestsPage()),
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('عرض التبرعات الجديدة'),
              style: OutlinedButton.styleFrom(
                  foregroundColor: primary,
                  backgroundColor: mint,
                  side: BorderSide.none)),
        ]),
      );

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

  Widget _metrics(_WorkspaceSnapshot data) => LayoutBuilder(
        builder: (_, constraints) {
          final columns = constraints.maxWidth < 520 ? 2 : 4;
          const gap = 10.0;
          final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
          final cards = [
            _metric('طلبات جديدة', '${data.pendingRequests}',
                Icons.new_releases_rounded, const Color(0xFFBA1A1A)),
            _metric('قيد التنفيذ', '${data.activeRequests}',
                Icons.hourglass_top_rounded, green),
            _metric('المتطوعون', '${data.activeVolunteers}',
                Icons.local_shipping_rounded, const Color(0xFF8055B5)),
            _metric('مكتملة', '${data.completedRequests}',
                Icons.check_circle_rounded, const Color(0xFF2F8F66)),
          ];
          return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: cards
                  .map((card) => SizedBox(width: width, child: card))
                  .toList());
        },
      );

  Widget _metric(String label, String value, IconData icon, Color color) =>
      Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE1E8E4))),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Flexible(
                  child: Text(label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Color(0xFF5E7068),
                          fontSize: 11,
                          fontWeight: FontWeight.w700))),
              CircleAvatar(
                  radius: 15,
                  backgroundColor: color.withAlpha(22),
                  foregroundColor: color,
                  child: Icon(icon, size: 16))
            ]),
            const SizedBox(height: 12),
            Text(value,
                style: const TextStyle(
                    color: primary, fontSize: 23, fontWeight: FontWeight.w900))
          ]));

  Widget _actionCard(
          IconData icon, String title, String subtitle, VoidCallback? onTap,
          {bool disabled = false}) =>
      Opacity(
          opacity: disabled ? .5 : 1,
          child: InkWell(
              onTap: disabled ? null : onTap,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE1E8E4))),
                  child: Row(children: [
                    CircleAvatar(
                        backgroundColor: const Color(0xFFE4F4EC),
                        foregroundColor: green,
                        child: Icon(icon)),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(title,
                              style: const TextStyle(
                                  color: primary,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900)),
                          const SizedBox(height: 4),
                          Text(subtitle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Color(0xFF62786D),
                                  fontSize: 12,
                                  height: 1.35))
                        ])),
                    Icon(
                        disabled
                            ? Icons.lock_outline_rounded
                            : Icons.chevron_left_rounded,
                        color: green)
                  ]))));

  Widget _activity(_WorkspaceSnapshot data) => Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE1E8E4))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('آخر التحديثات',
            style: TextStyle(
                color: primary, fontSize: 18, fontWeight: FontWeight.w900)),
        const SizedBox(height: 14),
        _activityLine(Icons.receipt_long_rounded,
            'إجمالي التبرعات المرتبطة بالجمعية: ${data.totalRequests}'),
        _activityLine(Icons.groups_rounded,
            'المتطوعون النشطون: ${data.activeVolunteers} من ${data.volunteers}')
      ]));

  Widget _activityLine(IconData icon, String text) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(children: [
        Icon(icon, color: green, size: 19),
        const SizedBox(width: 9),
        Expanded(
            child: Text(text,
                style: const TextStyle(
                    color: Color(0xFF44574F),
                    fontSize: 12,
                    fontWeight: FontWeight.w700)))
      ]));

  Widget _errorState(String message) => Center(
      child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.error_outline_rounded,
                color: Colors.red, size: 48),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: primary, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            FilledButton(
                onPressed: () {
                  _refresh();
                },
                child: const Text('إعادة المحاولة'))
          ])));

  Widget _blockedState(String message) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline_rounded, color: green, size: 54),
              const SizedBox(height: 14),
              Text(message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: primary, fontWeight: FontWeight.w800)),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('العودة'),
              ),
            ],
          ),
        ),
      );
}

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
  final bool isBlocked;
  final String? blockedMessage;

  const _WorkspaceSnapshot(
      {required this.charityName,
      required this.verified,
      required this.totalRequests,
      required this.pendingRequests,
      required this.institutionRequests,
      required this.pendingInstitutionRequests,
      required this.activeRequests,
      required this.completedRequests,
      required this.volunteers,
      required this.activeVolunteers})
      : isBlocked = false,
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
        isBlocked = true;
}
