import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'charity_donation_requests_page.dart';

class CharityHomePage extends StatefulWidget {
  const CharityHomePage({super.key});

  @override
  State<CharityHomePage> createState() => _CharityHomePageState();
}

class _CharityHomePageState extends State<CharityHomePage> {
  static const _green = Color(0xFF087A52);
  static const _deepGreen = Color(0xFF123D31);
  static const _background = Color(0xFFF5F8F6);

  final _client = Supabase.instance.client;
  int _tab = 0;
  late Future<_CharitySummary> _summaryFuture;

  @override
  void initState() {
    super.initState();
    _summaryFuture = _loadSummary();
  }

  Future<_CharitySummary> _loadSummary() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null || uid.isEmpty) {
      throw StateError('انتهت جلسة الجمعية، يرجى تسجيل الدخول مرة أخرى');
    }

    final charity = await _client
        .from('charities')
        .select('id, name, image_url, logo_url, status')
        .eq('user_id', uid)
        .maybeSingle();
    if (charity == null) {
      throw StateError('لم يتم العثور على بيانات الجمعية المرتبطة بهذا الحساب');
    }

    final charityId = charity['id'] as String;
    final requests = await _client
        .from('charity_donation_requests')
        .select('id, status')
        .eq('charity_id', charityId);
    final volunteers = await _client
        .from('charity_volunteers')
        .select('id')
        .eq('charity_id', charityId)
        .eq('status', 'active');

    return _CharitySummary(
      name: (charity['name'] as String?)?.trim().isNotEmpty == true
          ? charity['name'] as String
          : 'الجمعية',
      imageUrl:
          (charity['image_url'] as String?) ?? (charity['logo_url'] as String?),
      requestsCount: (requests as List).length,
      activeRequests: (requests as List)
          .where((row) => !{'completed', 'rejected', 'cancelled', 'expired'}
              .contains((row['status'] as String?)?.toLowerCase()))
          .length,
      volunteersCount: (volunteers as List).length,
    );
  }

  void _openRequests() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CharityDonationRequestsPage()),
    );
  }

  Future<void> _refresh() async {
    final next = _loadSummary();
    setState(() => _summaryFuture = next);
    await next;
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _background,
        body: SafeArea(
          child: FutureBuilder<_CharitySummary>(
            future: _summaryFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(color: _green));
              }
              if (snapshot.hasError) {
                return _errorState(snapshot.error.toString());
              }
              final summary = snapshot.data!;
              return IndexedStack(
                index: _tab,
                children: [
                  _dashboard(summary),
                  _requestsTab(summary),
                  _profileTab(summary),
                ],
              );
            },
          ),
        ),
        bottomNavigationBar: _bottomNavigation(),
      ),
    );
  }

  Widget _dashboard(_CharitySummary summary) {
    return RefreshIndicator(
      color: _green,
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('مرحباً بكِ',
                        style:
                            TextStyle(color: Color(0xFF71817A), fontSize: 14)),
                    const SizedBox(height: 5),
                    Text(summary.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: _deepGreen,
                            fontSize: 22,
                            fontWeight: FontWeight.w900)),
                  ],
                ),
              ),
              _avatar(summary.imageUrl),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient:
                  const LinearGradient(colors: [_green, Color(0xFF22A875)]),
              borderRadius: BorderRadius.circular(26),
              boxShadow: const [
                BoxShadow(
                    color: Color(0x24087A52),
                    blurRadius: 18,
                    offset: Offset(0, 9))
              ],
            ),
            child: Row(
              children: [
                const Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text('التبرعات الواردة',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w900)),
                      SizedBox(height: 7),
                      Text('تابعي الطلبات وحددي خطوة الاستلام التالية',
                          style: TextStyle(color: Colors.white70, height: 1.4)),
                    ])),
                CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.white24,
                    child: Text('${summary.activeRequests}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 21,
                            fontWeight: FontWeight.w900))),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Row(children: [
            Expanded(
                child: _statCard(Icons.inventory_2_outlined, 'كل الطلبات',
                    '${summary.requestsCount}', _green)),
            const SizedBox(width: 10),
            Expanded(
                child: _statCard(
                    Icons.volunteer_activism_outlined,
                    'قيد المتابعة',
                    '${summary.activeRequests}',
                    const Color(0xFFE28A22))),
            const SizedBox(width: 10),
            Expanded(
                child: _statCard(Icons.groups_2_outlined, 'المتطوعون',
                    '${summary.volunteersCount}', const Color(0xFF8055B5))),
          ]),
          const SizedBox(height: 22),
          _sectionTitle('الإجراءات السريعة'),
          const SizedBox(height: 10),
          _actionCard(Icons.receipt_long_rounded, 'طلبات التبرع',
              'راجعي الطلبات القادمة من المستخدمين والمطاعم', _openRequests),
          const SizedBox(height: 12),
          _actionCard(
              Icons.qr_code_scanner_rounded,
              'تأكيد الاستلام',
              'افتحي الطلب ثم استخدمي كود الاستلام الموجود داخله',
              _openRequests),
        ],
      ),
    );
  }

  Widget _requestsTab(_CharitySummary summary) {
    return Column(children: [
      _pageHeader('طلبات التبرع', 'كل التبرعات المرتبطة بـ ${summary.name}',
          Icons.receipt_long_rounded),
      const Expanded(child: CharityDonationRequestsPage()),
    ]);
  }

  Widget _profileTab(_CharitySummary summary) {
    return ListView(padding: const EdgeInsets.all(18), children: [
      _pageHeader('ملف الجمعية', 'بيانات الجمعية الحالية',
          Icons.account_balance_rounded),
      const SizedBox(height: 18),
      Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(24)),
          child: Column(children: [
            _avatar(summary.imageUrl, radius: 42),
            const SizedBox(height: 14),
            Text(summary.name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: _deepGreen,
                    fontSize: 20,
                    fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            const Text('حساب جمعية موثق',
                style: TextStyle(color: Color(0xFF71817A))),
          ])),
    ]);
  }

  Widget _pageHeader(String title, String subtitle, IconData icon) => Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
        child: Row(children: [
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(title,
                    style: const TextStyle(
                        color: _deepGreen,
                        fontSize: 24,
                        fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Color(0xFF71817A)))
              ])),
          CircleAvatar(
              backgroundColor: const Color(0xFFE4F4EC),
              foregroundColor: _green,
              child: Icon(icon)),
        ]),
      );

  Widget _statCard(IconData icon, String label, String value, Color color) =>
      Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(19)),
          child: Column(children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(value,
                style: TextStyle(
                    color: color, fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 3),
            Text(label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xFF71817A), fontSize: 11))
          ]));

  Widget _actionCard(
          IconData icon, String title, String subtitle, VoidCallback onTap) =>
      InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE1ECE6))),
              child: Row(children: [
                CircleAvatar(
                    backgroundColor: const Color(0xFFE4F4EC),
                    foregroundColor: _green,
                    child: Icon(icon)),
                const SizedBox(width: 13),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(title,
                          style: const TextStyle(
                              color: _deepGreen,
                              fontSize: 16,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text(subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Color(0xFF71817A),
                              fontSize: 12,
                              height: 1.35))
                    ])),
                const Icon(Icons.chevron_left_rounded, color: _green)
              ])));

  Widget _sectionTitle(String title) => Text(title,
      style: const TextStyle(
          color: _deepGreen, fontSize: 18, fontWeight: FontWeight.w900));

  Widget _avatar(String? url, {double radius = 25}) => CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFFE4F4EC),
      backgroundImage: url != null && url.isNotEmpty ? NetworkImage(url) : null,
      child: url == null || url.isEmpty
          ? Icon(Icons.account_balance_rounded, color: _green, size: radius)
          : null);

  Widget _bottomNavigation() => NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: (value) => setState(() => _tab = value),
          backgroundColor: Colors.white,
          indicatorColor: const Color(0xFFD9F0E4),
          destinations: const [
            NavigationDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard_rounded),
                label: 'الرئيسية'),
            NavigationDestination(
                icon: Icon(Icons.receipt_long_outlined),
                selectedIcon: Icon(Icons.receipt_long_rounded),
                label: 'التبرعات'),
            NavigationDestination(
                icon: Icon(Icons.person_outline_rounded),
                selectedIcon: Icon(Icons.person_rounded),
                label: 'حسابي')
          ]);

  Widget _errorState(String message) => Center(
      child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.error_outline_rounded,
                color: Colors.red, size: 46),
            const SizedBox(height: 12),
            Text(message.replaceFirst('Bad state: ', ''),
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: _deepGreen, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            FilledButton(
                onPressed: _refresh, child: const Text('إعادة المحاولة'))
          ])));
}

class _CharitySummary {
  final String name;
  final String? imageUrl;
  final int requestsCount;
  final int activeRequests;
  final int volunteersCount;

  const _CharitySummary(
      {required this.name,
      required this.imageUrl,
      required this.requestsCount,
      required this.activeRequests,
      required this.volunteersCount});
}
