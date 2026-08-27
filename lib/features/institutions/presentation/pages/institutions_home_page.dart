import 'package:flutter/material.dart';
import 'package:loqma/core/services/supabase_service.dart';
import 'package:loqma/features/auth/presentation/pages/login_page.dart';

import '../../data/repositories/institutions_repository.dart';
import '../../domain/entities/institution.dart';
import 'institution_add_donation_page.dart';
import 'institution_add_offer_page.dart';
import 'institution_donation_details_page.dart';
import 'institution_notifications_page.dart';
import 'institution_offer_details_page.dart';
import 'institution_offer_requests_management_page.dart';
import '../../domain/entities/institution_offer.dart';
import 'institution_profile_page.dart';

class InstitutionsHomePage extends StatefulWidget {
  const InstitutionsHomePage({super.key});

  @override
  State<InstitutionsHomePage> createState() => _InstitutionsHomePageState();
}

class _InstitutionsHomePageState extends State<InstitutionsHomePage> {
  static const ink = Color(0xFF00261A);
  static const forest = Color(0xFF0F3D2E);
  static const green = Color(0xFF2D7656);
  static const ivory = Color(0xFFFCF9F2);
  static const muted = Color(0xFF66736D);
  static const gold = Color(0xFF7D562D);

  final _repository = InstitutionsRepository();
  Institution? _institution;
  List<Map<String, dynamic>> _offers = const [];
  List<Map<String, dynamic>> _donations = const [];
  bool _loading = true;
  String? _error;
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    debugPrint(
        '[InstitutionHomeDebug] initState: InstitutionsHomePage started');
    debugPrint('[InstitutionHomeDebug] repository: ${_repository.runtimeType}');
    _load();
  }

  Future<void> _load() async {
    debugPrint('[InstitutionHomeDebug] load: started');
    debugPrint(
      '[InstitutionHomeDebug] auth.uid=${SupabaseService().client.auth.currentUser?.id ?? 'null'}',
    );
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      debugPrint('[InstitutionHomeDebug] load: calling getMine()');
      final institution = await _repository.getMine();
      debugPrint(
        '[InstitutionHomeDebug] getMine: success id=${institution.id}, name=${institution.name}, type=${institution.type}, status=${institution.status}',
      );

      debugPrint(
        '[InstitutionHomeDebug] load: calling listMyOffers(${institution.id})',
      );
      final offers = await _repository.listMyOffers(institution.id);
      debugPrint('[InstitutionHomeDebug] listMyOffers: count=${offers.length}');

      debugPrint(
        '[InstitutionHomeDebug] load: calling listMyCharityDonations(${institution.id})',
      );
      final donations =
          await _repository.listMyCharityDonations(institution.id);
      debugPrint(
        '[InstitutionHomeDebug] listMyCharityDonations: count=${donations.length}',
      );

      if (!mounted) {
        debugPrint(
            '[InstitutionHomeDebug] load: widget unmounted before setState');
        return;
      }
      setState(() {
        _institution = institution;
        _offers = offers;
        _donations = donations;
        _loading = false;
      });
      debugPrint('[InstitutionHomeDebug] load: completed successfully');
    } catch (error, stackTrace) {
      debugPrint('[InstitutionHomeDebug] load: FAILED error=$error');
      debugPrintStack(
        label: '[InstitutionHomeDebug] stack trace',
        stackTrace: stackTrace,
      );
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'تعذر تحميل بيانات المؤسسة. راجع Terminal لمعرفة السبب.';
      });
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('تسجيل الخروج'),
        content: const Text('هل تريد تسجيل الخروج من حساب المؤسسة؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('تسجيل الخروج'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await SupabaseService().client.auth.signOut();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (_) => false,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر تسجيل الخروج. حاول مرة أخرى')),
      );
    }
  }

  Future<void> _openProfile() async {
    final institution = _institution;
    if (institution == null) return;
    final updated = await Navigator.of(context).push<Institution>(
      MaterialPageRoute(
        builder: (_) => InstitutionProfilePage(institution: institution),
      ),
    );
    if (mounted && updated != null) setState(() => _institution = updated);
  }

  Future<void> _openAdd(WidgetBuilder builder) async {
    if (_institution == null) return;
    await Navigator.of(context).push(MaterialPageRoute(builder: builder));
    if (mounted) await _load();
  }

  Future<void> _openNotifications() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const InstitutionNotificationsPage()),
    );
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Theme(
        data: Theme.of(context).copyWith(
          scaffoldBackgroundColor: ivory,
          colorScheme: Theme.of(context).colorScheme.copyWith(
                primary: ink,
                secondary: gold,
                surface: Colors.white,
              ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final desktop = constraints.maxWidth >= 900;
            return Scaffold(
              backgroundColor: ivory,
              appBar: desktop ? null : _mobileAppBar(),
              body: _loading
                  ? const _LoadingView()
                  : _error != null
                      ? _ErrorView(message: _error!, onRetry: _load)
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (desktop) _DesktopSidebar(onLogout: _logout),
                            Expanded(child: _body(desktop)),
                          ],
                        ),
              bottomNavigationBar: desktop ? null : _mobileNavigation(),
            );
          },
        ),
      ),
    );
  }

  PreferredSizeWidget _mobileAppBar() {
    final institution = _institution;
    return AppBar(
      elevation: 0,
      backgroundColor: ivory,
      surfaceTintColor: Colors.transparent,
      titleSpacing: 16,
      title: Row(
        children: [
          _Avatar(url: institution?.logoUrl, size: 42),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('لقمة للمؤسسات',
                    style: TextStyle(
                        color: ink, fontSize: 18, fontWeight: FontWeight.w800)),
                Text(institution?.name ?? 'مساحة مؤسستك',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: muted, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
            onPressed: _openNotifications,
            tooltip: 'الإشعارات',
            icon: const Icon(Icons.notifications_none_rounded, color: ink)),
        PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'profile') _openProfile();
            if (value == 'logout') _logout();
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'profile', child: Text('الملف الشخصي')),
            PopupMenuItem(value: 'logout', child: Text('تسجيل الخروج')),
          ],
          icon: const Icon(Icons.more_vert_rounded, color: ink),
        ),
      ],
    );
  }

  Widget _body(bool desktop) {
    if (_tab == 1)
      return _listTab('إدارة العروض', _offers, Icons.sell_outlined);
    if (_tab == 2)
      return _listTab(
          'سجل التبرعات', _donations, Icons.volunteer_activism_outlined);
    if (_tab == 3) {
      final institutionId = _institution?.id;
      if (institutionId == null || institutionId.isEmpty) {
        return const Center(child: Text('لا توجد مؤسسة مرتبطة بالحساب'));
      }
      return InstitutionOfferRequestsManagementPage(
        institutionId: institutionId,
        repository: _repository,
      );
    }
    final institution = _institution!;
    return RefreshIndicator(
      color: green,
      onRefresh: _load,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
            desktop ? 42 : 16, desktop ? 42 : 12, desktop ? 42 : 16, 32),
        children: [
          _WelcomeHeader(
              institution: institution, onNotifications: _openNotifications),
          const SizedBox(height: 24),
          _ProfileHero(institution: institution, onTap: _openProfile),
          const SizedBox(height: 28),
          const _SectionTitle(
              title: 'ساهم بطريقتك',
              subtitle: 'حوّل فائض مؤسستك إلى أثر حقيقي'),
          const SizedBox(height: 14),
          _ActionGrid(
            onOffer: () => _openAdd(
                (_) => InstitutionAddOfferPage(institutionId: institution.id)),
            onDonation: () => _openAdd((_) =>
                InstitutionAddDonationPage(institutionId: institution.id)),
          ),
          const SizedBox(height: 28),
          _StatsGrid(offers: _offers, donations: _donations),
          const SizedBox(height: 28),
          _RecentSection(
            rows: [
              ..._offers.map((e) => {...e, '_kind': 'offer'}),
              ..._donations.map((e) => {...e, '_kind': 'donation'}),
            ]..sort((a, b) => _dateOf(b).compareTo(_dateOf(a))),
            onOpen: (row) async {
              final map = Map<String, dynamic>.from(row);
              final isOffer = map['_kind'] == 'offer';
              map.remove('_kind');
              await Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => isOffer
                    ? InstitutionOfferDetailsPage(
                        offer: InstitutionOffer.fromJson(map),
                      )
                    : InstitutionDonationDetailsPage(donation: map),
              ));
              if (mounted) await _load();
            },
          ),
        ],
      ),
    );
  }

  Widget _listTab(
      String title, List<Map<String, dynamic>> rows, IconData icon) {
    final isOffers = _tab == 1;
    return RefreshIndicator(
      color: green,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
        children: [
          Text(title,
              style: const TextStyle(
                  color: ink, fontSize: 28, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(
              isOffers
                  ? 'تابع عروضك المنشورة وحالتها الحالية.'
                  : 'تابع تبرعاتك من لحظة الإرسال حتى الوصول.',
              style: const TextStyle(color: muted, fontSize: 14)),
          const SizedBox(height: 18),
          if (rows.isEmpty)
            const _EmptyView(message: 'لا توجد بيانات حتى الآن')
          else
            ...rows.map((row) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _ActivityCard(
                    row: row,
                    icon: icon,
                    isOffer: isOffers,
                    onTap: () async {
                      await Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => isOffers
                            ? InstitutionOfferDetailsPage(
                                offer: InstitutionOffer.fromJson(row),
                              )
                            : InstitutionDonationDetailsPage(donation: row),
                      ));
                      if (mounted) await _load();
                    },
                  ),
                )),
        ],
      ),
    );
  }

  Widget _mobileNavigation() => NavigationBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        selectedIndex: _tab,
        onDestinationSelected: (value) => setState(() => _tab = value),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard),
              label: 'الرئيسية'),
          NavigationDestination(
              icon: Icon(Icons.sell_outlined),
              selectedIcon: Icon(Icons.sell),
              label: 'عروضي'),
          NavigationDestination(
              icon: Icon(Icons.volunteer_activism_outlined),
              selectedIcon: Icon(Icons.volunteer_activism),
              label: 'تبرعاتي'),
          NavigationDestination(
              icon: Icon(Icons.people_outline),
              selectedIcon: Icon(Icons.people),
              label: 'طلبات العملاء'),
        ],
      );

  static DateTime _dateOf(Map<String, dynamic> row) =>
      DateTime.tryParse(
          (row['created_at'] ?? row['updated_at'])?.toString() ?? '') ??
      DateTime(1970);
}

class _DesktopSidebar extends StatelessWidget {
  final VoidCallback onLogout;
  const _DesktopSidebar({required this.onLogout});

  @override
  Widget build(BuildContext context) => Container(
        width: 286,
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(left: BorderSide(color: Color(0xFFE5EAE6))),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(22),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Row(children: [
                _BrandMark(),
                SizedBox(width: 10),
                Text('لقمة للمؤسسات',
                    style: TextStyle(
                        color: Color(0xFF00261A),
                        fontSize: 20,
                        fontWeight: FontWeight.w800))
              ]),
              const SizedBox(height: 36),
              const _SidebarIdentity(),
              const SizedBox(height: 28),
              const _SidebarItem(
                  icon: Icons.dashboard_outlined,
                  label: 'لوحة التحكم',
                  selected: true),
              const _SidebarItem(
                  icon: Icons.storefront_outlined, label: 'إدارة العروض'),
              const _SidebarItem(
                  icon: Icons.history_rounded, label: 'سجل التبرعات'),
              const _SidebarItem(
                  icon: Icons.query_stats_rounded, label: 'إحصائيات المؤسسة'),
              const _SidebarItem(
                  icon: Icons.settings_outlined, label: 'الإعدادات'),
              const Spacer(),
              const Divider(color: Color(0xFFE5EAE6)),
              ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.logout_rounded,
                      color: Color(0xFF66736D)),
                  title: const Text('تسجيل الخروج',
                      style: TextStyle(color: Color(0xFF66736D))),
                  onTap: onLogout),
            ]),
          ),
        ),
      );
}

class _SidebarIdentity extends StatelessWidget {
  const _SidebarIdentity();
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: const Color(0xFFF3F4F1),
            borderRadius: BorderRadius.circular(16)),
        child: const Row(children: [
          _BrandMark(size: 38),
          SizedBox(width: 10),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('مؤسستك',
                    style: TextStyle(
                        color: Color(0xFF00261A), fontWeight: FontWeight.w800)),
                Text('إدارة آمنة وموثوقة',
                    style: TextStyle(color: Color(0xFF66736D), fontSize: 12))
              ])),
        ]),
      );
}

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  const _SidebarItem(
      {required this.icon, required this.label, this.selected = false});
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(
            color: selected ? const Color(0xFFBEEDD7).withOpacity(.45) : null,
            borderRadius: BorderRadius.circular(12),
            border: selected
                ? const Border(
                    right: BorderSide(color: Color(0xFF00261A), width: 4))
                : null),
        child: ListTile(
            dense: true,
            leading: Icon(icon,
                color: selected
                    ? const Color(0xFF00261A)
                    : const Color(0xFF66736D)),
            title: Text(label,
                style: TextStyle(
                    color: selected
                        ? const Color(0xFF00261A)
                        : const Color(0xFF66736D),
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w500)),
            onTap: () {}),
      );
}

class _WelcomeHeader extends StatelessWidget {
  final Institution institution;
  final VoidCallback onNotifications;
  const _WelcomeHeader(
      {required this.institution, required this.onNotifications});
  @override
  Widget build(BuildContext context) =>
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('لوحة التحكم',
              style: TextStyle(
                  color: Color(0xFF00261A),
                  fontSize: 34,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 5),
          Text('مرحباً بك مجدداً في إدارة ${institution.name}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFF66736D), fontSize: 15))
        ])),
        const SizedBox(width: 12),
        IconButton.filledTonal(
            onPressed: onNotifications,
            tooltip: 'الإشعارات',
            icon: const Icon(Icons.notifications_none_rounded)),
      ]);
}

class _ProfileHero extends StatelessWidget {
  final Institution institution;
  final VoidCallback onTap;
  const _ProfileHero({required this.institution, required this.onTap});
  @override
  Widget build(BuildContext context) => Material(
      color: const Color(0xFF064E3B),
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Padding(
              padding: const EdgeInsets.all(22),
              child: Row(children: [
                _Avatar(url: institution.logoUrl, size: 68, light: true),
                const SizedBox(width: 16),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(institution.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(height: 6),
                      Text(_typeName(institution.type),
                          style: const TextStyle(color: Colors.white70))
                    ])),
                if (institution.isVerified)
                  const Icon(Icons.verified_rounded,
                      color: Color(0xFFB8E8C8), size: 26),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_left_rounded, color: Colors.white70),
              ]))));

  static String _typeName(String value) =>
      const {
        'bakery': 'مخبز وحلويات',
        'grocery': 'بقالة',
        'game_store': 'محل ألعاب',
        'supermarket': 'سوبر ماركت',
        'cafe': 'كافيه',
        'hotel': 'فندق'
      }[value] ??
      'مؤسسة أخرى';
}

class _ActionGrid extends StatelessWidget {
  final VoidCallback onOffer;
  final VoidCallback onDonation;
  const _ActionGrid({required this.onOffer, required this.onDonation});
  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, constraints) {
        final children = [
          Expanded(
              child: _ActionCard(
                  icon: Icons.sell_rounded,
                  title: 'بيع بسعر رمزي',
                  subtitle: 'اعرض المنتجات الصالحة بسعر مناسب',
                  color: const Color(0xFF7D562D),
                  onTap: onOffer)),
          Expanded(
              child: _ActionCard(
                  icon: Icons.volunteer_activism_rounded,
                  title: 'تبرع لجمعية',
                  subtitle: 'أرسل الفائض إلى جمعية موثوقة',
                  color: const Color(0xFF0F3D2E),
                  onTap: onDonation)),
        ];
        if (constraints.maxWidth >= 620)
          return Row(
              children: [children[0], const SizedBox(width: 12), children[1]]);
        return Column(children: [
          children[0].child,
          const SizedBox(height: 12),
          children[1].child
        ]);
      });
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  const _ActionCard(
      {required this.icon,
      required this.title,
      required this.subtitle,
      required this.color,
      required this.onTap});
  @override
  Widget build(BuildContext context) => Material(
      color: color,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(children: [
                Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                        color: Colors.white.withOpacity(.14),
                        borderRadius: BorderRadius.circular(15)),
                    child: Icon(icon, color: Colors.white, size: 26)),
                const SizedBox(width: 14),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(title,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text(subtitle,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12))
                    ])),
                const Icon(Icons.arrow_back_rounded, color: Colors.white70)
              ]))));
}

class _StatsGrid extends StatelessWidget {
  final List<Map<String, dynamic>> offers;
  final List<Map<String, dynamic>> donations;
  const _StatsGrid({required this.offers, required this.donations});
  @override
  Widget build(BuildContext context) {
    final completed = donations
        .where((row) => row['status']?.toString() == 'completed')
        .length;
    final active =
        offers.where((row) => row['status']?.toString() == 'active').length;
    return LayoutBuilder(builder: (context, constraints) {
      final items = [
        ('العروض النشطة', '$active', Icons.local_offer_outlined),
        ('عدد التبرعات', '${donations.length}', Icons.loyalty_outlined),
        ('التبرعات المكتملة', '$completed', Icons.check_circle_outline),
        (
          'إجمالي النشاط',
          '${offers.length + donations.length}',
          Icons.insights_outlined
        )
      ];
      return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: constraints.maxWidth >= 720 ? 4 : 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              mainAxisExtent: 112),
          itemBuilder: (_, index) => _StatCard(
              title: items[index].$1,
              value: items[index].$2,
              icon: items[index].$3));
    });
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  const _StatCard(
      {required this.title, required this.value, required this.icon});
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE4E9E5))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Expanded(
              child: Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      const TextStyle(color: Color(0xFF66736D), fontSize: 12))),
          Icon(icon, color: Color(0xFF2D7656), size: 20)
        ]),
        const Spacer(),
        Text(value,
            style: const TextStyle(
                color: Color(0xFF00261A),
                fontSize: 26,
                fontWeight: FontWeight.w800))
      ]));
}

class _RecentSection extends StatelessWidget {
  final List<Map<String, dynamic>> rows;
  final Future<void> Function(Map<String, dynamic>) onOpen;
  const _RecentSection({required this.rows, required this.onOpen});
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _SectionTitle(
            title: 'آخر النشاطات',
            subtitle: 'نظرة سريعة على أحدث ما تم داخل المؤسسة'),
        const SizedBox(height: 12),
        if (rows.isEmpty)
          const _EmptyView(message: 'لا توجد نشاطات بعد')
        else
          ...rows.take(4).map((row) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ActivityCard(
                  row: row,
                  isOffer: row['_kind'] == 'offer',
                  icon: row['_kind'] == 'offer'
                      ? Icons.sell_outlined
                      : Icons.volunteer_activism_outlined,
                  onTap: () => onOpen(row))))
      ]);
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;
  const _SectionTitle({required this.title, required this.subtitle});
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: const TextStyle(
                color: Color(0xFF00261A),
                fontSize: 22,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(subtitle,
            style: const TextStyle(color: Color(0xFF66736D), fontSize: 13))
      ]);
}

class _ActivityCard extends StatelessWidget {
  final Map<String, dynamic> row;
  final IconData icon;
  final bool isOffer;
  final VoidCallback onTap;
  const _ActivityCard(
      {required this.row,
      required this.icon,
      required this.isOffer,
      required this.onTap});
  @override
  Widget build(BuildContext context) {
    final status = _statusLabel(row['status']?.toString() ?? 'pending');
    final value = row['status']?.toString() ?? '';
    final title =
        (row['title'] ?? row['item_title'] ?? 'بدون عنوان').toString();
    final image = _imageUrl(row);
    final subtitle = isOffer
        ? '${row['symbolic_price'] ?? '—'} جنيه · ${row['remaining_quantity'] ?? row['quantity'] ?? '—'} قطعة'
        : '${row['charity_name'] ?? 'جمعية'} · ${row['quantity'] ?? '—'} قطعة';
    final active = value == 'active';
    return Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(18),
            child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                        color: active
                            ? const Color(0xFF6EAE8D)
                            : const Color(0xFFE4E9E5))),
                child: Row(children: [
                  _ListImage(url: image, icon: icon),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Color(0xFF00261A),
                                fontWeight: FontWeight.w800)),
                        const SizedBox(height: 5),
                        Text(subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Color(0xFF66736D), fontSize: 12)),
                        const SizedBox(height: 7),
                        _StatusChip(label: status, status: value)
                      ])),
                  const Icon(Icons.chevron_left_rounded,
                      color: Color(0xFF9AA69F))
                ]))));
  }

  static String? _imageUrl(Map<String, dynamic> row) {
    final images = row['images'];
    if (images is List && images.isNotEmpty) {
      final value = images.first?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  static String _statusLabel(String value) =>
      const {
        'active': 'متاح',
        'paused': 'متوقف',
        'sold_out': 'نفدت الكمية',
        'expired': 'منتهي',
        'cancelled': 'ملغي',
        'pending': 'قيد المراجعة',
        'accepted': 'تم القبول',
        'rejected': 'مرفوض',
        'volunteer_assigned': 'تم تعيين المتطوع',
        'institution_ready': 'جاهز للتسليم',
        'volunteer_departed': 'المتطوع في الطريق',
        'picked_up': 'تم الاستلام',
        'completed': 'تم التسليم'
      }[value] ??
      'غير محدد';
}

class _StatusChip extends StatelessWidget {
  final String label;
  final String status;
  const _StatusChip({required this.label, required this.status});
  @override
  Widget build(BuildContext context) {
    final good =
        {'active', 'accepted', 'completed', 'picked_up'}.contains(status);
    final bad = {'rejected', 'cancelled', 'expired'}.contains(status);
    final color = good
        ? const Color(0xFF2D7656)
        : bad
            ? const Color(0xFFB23A3A)
            : const Color(0xFF8A632F);
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
            color: color.withOpacity(.10),
            borderRadius: BorderRadius.circular(20)),
        child: Text(label,
            style: TextStyle(
                color: color, fontSize: 11, fontWeight: FontWeight.w700)));
  }
}

class _ListImage extends StatelessWidget {
  final String? url;
  final IconData icon;
  const _ListImage({required this.url, required this.icon});
  @override
  Widget build(BuildContext context) => ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
          width: 64,
          height: 64,
          child: url == null
              ? Container(
                  color: const Color(0xFFDDEBE4),
                  child: Icon(icon, color: const Color(0xFF0B7650), size: 28))
              : Image.network(url!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                      color: const Color(0xFFDDEBE4),
                      child: Icon(icon, color: const Color(0xFF0B7650))))));
}

class _Avatar extends StatelessWidget {
  final String? url;
  final double size;
  final bool light;
  const _Avatar({required this.url, required this.size, this.light = false});
  @override
  Widget build(BuildContext context) => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: light ? Colors.white24 : const Color(0xFFDDEBE4),
          image: url != null && url!.trim().isNotEmpty
              ? DecorationImage(
                  image: NetworkImage(url!.trim()), fit: BoxFit.cover)
              : null),
      child: url == null || url!.trim().isEmpty
          ? Icon(Icons.storefront_rounded,
              color: light ? Colors.white : const Color(0xFF0B7650),
              size: size * .48)
          : null);
}

class _BrandMark extends StatelessWidget {
  final double size;
  const _BrandMark({this.size = 44});
  @override
  Widget build(BuildContext context) => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
          color: const Color(0xFFBEEDD7),
          borderRadius: BorderRadius.circular(size * .28)),
      child: Icon(Icons.volunteer_activism_rounded,
          color: const Color(0xFF00261A), size: size * .52));
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();
  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator(color: Color(0xFF0F3D2E)));
}

class _ErrorView extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;
  const _ErrorView({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(
      child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.cloud_off_rounded,
                size: 52, color: Color(0xFF66736D)),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Color(0xFF00261A), fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('إعادة المحاولة'))
          ])));
}

class _EmptyView extends StatelessWidget {
  final String message;
  const _EmptyView({required this.message});
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 20),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE4E9E5))),
      child: Column(children: [
        const Icon(Icons.inbox_rounded, size: 42, color: Color(0xFF8AA096)),
        const SizedBox(height: 10),
        Text(message, style: const TextStyle(color: Color(0xFF66736D)))
      ]));
}
