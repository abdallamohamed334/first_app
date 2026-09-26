// lib/features/institutions/presentation/pages/institutions_home_page.dart

import 'package:flutter/material.dart';
import 'package:loqma/core/services/supabase_service.dart';
import 'package:loqma/features/auth/presentation/pages/login_page.dart';

import '../../data/repositories/institutions_repository.dart';
import '../../data/repositories/institution_offers_repository.dart';
import '../../domain/entities/institution.dart';
import 'institution_add_donation_page.dart';
import 'institution_add_offer_page.dart';
import 'institution_donation_details_page.dart';
import 'institution_notifications_page.dart';
import 'institution_offer_details_page.dart';
import 'institution_offer_requests_management_page.dart';
import '../../domain/entities/institution_offer.dart';
import 'institution_profile_page.dart';
import 'institution_edit_offer_dialog.dart';
import 'institution_booking_search_page.dart';

// ─── ألوان هوية جُود ───
const Color _primary = Color(0xFF0B7650);
const Color _primaryLight = Color(0xFF25B77C);
const Color _primaryDark = Color(0xFF054D34);
const Color _cream = Color(0xFFF7FAF8);
const Color _ink = Color(0xFF0F2E23);
const Color _inkSoft = Color(0xFF61756D);
const Color _gold = Color(0xFFD4A843);
const Color _orange = Color(0xFFE28B00);
const Color _blue = Color(0xFF3679C8);
const Color _purple = Color(0xFF7B5EC7);
const Color _red = Color(0xFFDC4C4C);

class InstitutionsHomePage extends StatefulWidget {
  const InstitutionsHomePage({super.key});

  @override
  State<InstitutionsHomePage> createState() => _InstitutionsHomePageState();
}

class _InstitutionsHomePageState extends State<InstitutionsHomePage> {
  final _repository = InstitutionsRepository();
  final _offersRepository = InstitutionOffersRepository();
  Institution? _institution;
  List<Map<String, dynamic>> _offers = const [];
  List<Map<String, dynamic>> _donations = const [];
  bool _loading = true;
  String? _error;
  int _tab = 0;
  String _offerFilter = 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final institution = await _repository.getMine();
      final offers = await _repository.listMyOffers(institution.id);
      final donations =
          await _repository.listMyCharityDonations(institution.id);

      if (!mounted) return;
      setState(() {
        _institution = institution;
        _offers = offers;
        _donations = donations;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'تعذر تحميل بيانات المؤسسة. حاول مرة أخرى';
      });
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          'تسجيل الخروج',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        content: const Text('هل تريد تسجيل الخروج من حساب المؤسسة؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text(
              'إلغاء',
              style: TextStyle(color: _inkSoft),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: _red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'تسجيل الخروج',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
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

  Future<void> _openEditOfferDialog(Map<String, dynamic> offer) async {
    final status = offer['status']?.toString() ?? '';
    final expiresAt = offer['expires_at'] != null
        ? DateTime.tryParse(offer['expires_at'].toString())
        : null;

    if (status == 'expired' ||
        (expiresAt != null && expiresAt.isBefore(DateTime.now()))) {
      _showMessage('⛔ هذا العرض منتهي الصلاحية ولا يمكن تعديله', error: true);
      return;
    }

    if (status == 'cancelled') {
      _showMessage('🚫 هذا العرض ملغي ولا يمكن تعديله', error: true);
      return;
    }

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => InstitutionEditOfferDialog(
        offer: offer,
        repository: _offersRepository,
      ),
    );

    if (result != null && mounted) {
      if (result['updated'] == true) {
        _showMessage('✅ تم تحديث العرض بنجاح');
        await _load();
      } else if (result['toggled'] == true) {
        final isActive = result['is_active'] == true;
        _showMessage(
            isActive ? '✅ تم تشغيل العرض' : '⏸️ تم إيقاف العرض مؤقتاً');
        await _load();
      } else if (result['cancelled'] == true) {
        _showMessage('🚫 تم إلغاء العرض');
        await _load();
      }
    }
  }

  void _showMessage(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? _red : _primary,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  List<Map<String, dynamic>> get _filteredOffers {
    if (_offerFilter == 'all') return _offers;
    if (_offerFilter == 'active') {
      return _offers.where((offer) {
        final status = offer['status']?.toString() ?? '';
        return status == 'active' || status == 'available';
      }).toList();
    }
    if (_offerFilter == 'inactive') {
      return _offers.where((offer) {
        final status = offer['status']?.toString() ?? '';
        return status != 'active' && status != 'available';
      }).toList();
    }
    return _offers;
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _cream,
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: _primary))
            : _error != null
                ? _buildErrorView()
                : _buildBody(),
        bottomNavigationBar: _buildBottomNavigation(),
      ),
    );
  }

  Widget _buildBody() {
    return IndexedStack(
      index: _tab,
      children: [
        _buildHomeTab(),
        _buildOffersTab(),
        _buildDonationsTab(),
        _buildRequestsTab(),
      ],
    );
  }

  Widget _buildRequestsTab() {
    final institutionId = _institution?.id;
    if (institutionId == null || institutionId.isEmpty) {
      return const Center(child: Text('لا توجد مؤسسة مرتبطة بالحساب'));
    }
    return InstitutionOfferRequestsManagementPage(
      institutionId: institutionId,
      repository: _repository,
    );
  }

  // ═══════════════════════════════════════════════════════════
  // HOME TAB
  // ═══════════════════════════════════════════════════════════
  Widget _buildHomeTab() {
    final institution = _institution!;
    return RefreshIndicator(
      color: _primary,
      onRefresh: _load,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          // ═══════════════════════════════════════════════
          // HERO APP BAR
          // ═══════════════════════════════════════════════
          SliverAppBar(
            expandedHeight: 240,
            pinned: true,
            stretch: true,
            backgroundColor: _primary,
            foregroundColor: Colors.white,
            elevation: 0,
            scrolledUnderElevation: 0,
            leading: IconButton(
              onPressed: _openProfile,
              icon: _Avatar(url: institution.logoUrl, size: 38),
              padding: const EdgeInsets.all(4),
            ),
            title: Text(
              institution.name,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            actions: [
              IconButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const InstitutionBookingSearchPage(),
                    ),
                  );
                },
                icon: const Icon(Icons.qr_code_scanner_rounded),
                tooltip: 'البحث عن حجز',
              ),
              IconButton(
                onPressed: _openNotifications,
                icon: const Icon(Icons.notifications_none_rounded),
                tooltip: 'الإشعارات',
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'profile') _openProfile();
                  if (value == 'logout') _logout();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'profile',
                    child: Row(
                      children: [
                        Icon(Icons.person_outline_rounded, size: 18),
                        SizedBox(width: 8),
                        Text('الملف الشخصي'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'logout',
                    child: Row(
                      children: [
                        Icon(Icons.logout_rounded, size: 18, color: _red),
                        SizedBox(width: 8),
                        Text('تسجيل الخروج', style: TextStyle(color: _red)),
                      ],
                    ),
                  ),
                ],
                icon: const Icon(Icons.more_vert_rounded),
              ),
              const SizedBox(width: 8),
            ],
            flexibleSpace: FlexibleSpaceBar(
              stretchModes: const [StretchMode.zoomBackground],
              background: _buildHeroHeader(institution),
            ),
          ),

          // ═══════════════════════════════════════════════
          // CONTENT
          // ═══════════════════════════════════════════════
          SliverToBoxAdapter(
            child: Transform.translate(
              offset: const Offset(0, -24),
              child: Container(
                decoration: const BoxDecoration(
                  color: _cream,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStatsGrid(),
                    const SizedBox(height: 24),
                    _buildSectionTitle(
                      'ساهم بطريقتك',
                      'حوّل فائض مؤسستك إلى أثر حقيقي',
                    ),
                    const SizedBox(height: 14),
                    _ActionGrid(
                      onOffer: () => _openAdd(
                        (_) => InstitutionAddOfferPage(
                          institutionId: institution.id,
                        ),
                      ),
                      onDonation: () => _openAdd(
                        (_) => InstitutionAddDonationPage(
                          institutionId: institution.id,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildSectionTitle(
                      'آخر النشاطات',
                      'نظرة سريعة على أحدث ما تم داخل المؤسسة',
                    ),
                    const SizedBox(height: 14),
                    _buildRecentActivities(),
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
  // HERO HEADER
  // ═══════════════════════════════════════════════════════════
  Widget _buildHeroHeader(Institution institution) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_primaryDark, _primary, _primaryLight],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -50,
            left: -40,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          Positioned(
            bottom: -70,
            right: -40,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.04),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 60, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.auto_awesome_rounded,
                              color: Colors.white,
                              size: 12,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              _typeName(institution.type),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (institution.isVerified) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _gold.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.verified_rounded,
                                color: Colors.white,
                                size: 12,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'موثقة',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'لوحة التحكم',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'أهلاً بك في إدارة ${institution.name}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // SECTION TITLE
  // ═══════════════════════════════════════════════════════════
  Widget _buildSectionTitle(String title, String subtitle) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 4,
          height: 34,
          margin: const EdgeInsets.only(top: 4),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_primary, _primaryLight],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(4),
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
                  color: _ink,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  color: _inkSoft,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  // STATS GRID
  // ═══════════════════════════════════════════════════════════
  Widget _buildStatsGrid() {
    final activeOffers = _offers.where((row) {
      final s = row['status']?.toString() ?? '';
      return s == 'active' || s == 'available';
    }).length;

    final completedDonations = _donations
        .where((row) => row['status']?.toString() == 'completed')
        .length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final items = [
          _StatData(
            title: 'العروض النشطة',
            value: '$activeOffers',
            icon: Icons.local_offer_rounded,
            color: _primary,
          ),
          _StatData(
            title: 'إجمالي التبرعات',
            value: '${_donations.length}',
            icon: Icons.volunteer_activism_rounded,
            color: _purple,
          ),
          _StatData(
            title: 'تبرعات مكتملة',
            value: '$completedDonations',
            icon: Icons.check_circle_rounded,
            color: _blue,
          ),
          _StatData(
            title: 'إجمالي النشاط',
            value: '${_offers.length + _donations.length}',
            icon: Icons.insights_rounded,
            color: _gold,
          ),
        ];

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: constraints.maxWidth >= 720 ? 4 : 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            mainAxisExtent: 120,
          ),
          itemBuilder: (_, index) => _StatCard(data: items[index]),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════
  // RECENT ACTIVITIES
  // ═══════════════════════════════════════════════════════════
  Widget _buildRecentActivities() {
    final rows = [
      ..._offers.map((e) => {...e, '_kind': 'offer'}),
      ..._donations.map((e) => {...e, '_kind': 'donation'}),
    ]..sort((a, b) => _dateOf(b).compareTo(_dateOf(a)));

    if (rows.isEmpty) {
      return const _EmptyView(message: 'لا توجد نشاطات بعد');
    }

    return Column(
      children: rows.take(5).map((row) {
        final map = Map<String, dynamic>.from(row);
        final isOffer = map['_kind'] == 'offer';
        map.remove('_kind');

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _ActivityCard(
            row: map,
            isOffer: isOffer,
            icon: isOffer
                ? Icons.sell_outlined
                : Icons.volunteer_activism_outlined,
            onTap: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => isOffer
                      ? InstitutionOfferDetailsPage(
                          offer: InstitutionOffer.fromJson(map),
                        )
                      : InstitutionDonationDetailsPage(donation: map),
                ),
              );
              if (mounted) await _load();
            },
            onEdit: isOffer ? () => _openEditOfferDialog(map) : null,
          ),
        );
      }).toList(),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // OFFERS TAB
  // ═══════════════════════════════════════════════════════════
  Widget _buildOffersTab() {
    final filteredOffers = _filteredOffers;
    final activeCount = _offers.where((o) {
      final status = o['status']?.toString() ?? '';
      return status == 'active' || status == 'available';
    }).length;
    final inactiveCount = _offers.length - activeCount;

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      slivers: [
        SliverAppBar(
          expandedHeight: 130,
          pinned: true,
          backgroundColor: _primary,
          foregroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [_primaryDark, _primary],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 40, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      const Text(
                        'إدارة العروض',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_offers.length} عرض منشور',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                _buildFilterChip('الكل', 'all', _offers.length, _primary),
                const SizedBox(width: 8),
                _buildFilterChip('نشط', 'active', activeCount, _primaryLight),
                const SizedBox(width: 8),
                _buildFilterChip('غير نشط', 'inactive', inactiveCount, _red),
              ],
            ),
          ),
        ),
        if (filteredOffers.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: _EmptyView(message: 'لا توجد عروض في هذا التصنيف'),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            sliver: SliverList.builder(
              itemCount: filteredOffers.length,
              itemBuilder: (context, index) {
                final offer = filteredOffers[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _OfferCard(
                    offer: offer,
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => InstitutionOfferDetailsPage(
                            offer: InstitutionOffer.fromJson(offer),
                          ),
                        ),
                      );
                      if (mounted) await _load();
                    },
                    onEdit: () => _openEditOfferDialog(offer),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildFilterChip(String label, String value, int count, Color color) {
    final isSelected = _offerFilter == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _offerFilter = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            gradient: isSelected
                ? LinearGradient(
                    colors: [color, color.withValues(alpha: 0.8)],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  )
                : null,
            color: isSelected ? null : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? color : const Color(0xFFEEF3F0),
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Column(
            children: [
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : _ink,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$count',
                style: TextStyle(
                  color: isSelected ? Colors.white : color,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // DONATIONS TAB
  // ═══════════════════════════════════════════════════════════
  Widget _buildDonationsTab() {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      slivers: [
        SliverAppBar(
          expandedHeight: 130,
          pinned: true,
          backgroundColor: _purple,
          foregroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF3E2E6E), _purple],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 40, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      const Text(
                        'سجل التبرعات',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'تابع تبرعاتك من لحظة الإرسال حتى الوصول',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        if (_donations.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: _EmptyView(message: 'لا توجد تبرعات حتى الآن'),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            sliver: SliverList.builder(
              itemCount: _donations.length,
              itemBuilder: (context, index) {
                final row = _donations[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _DonationCard(
                    donation: row,
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => InstitutionDonationDetailsPage(
                            donation: row,
                          ),
                        ),
                      );
                      if (mounted) await _load();
                    },
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  // BOTTOM NAVIGATION
  // ═══════════════════════════════════════════════════════════
  Widget _buildBottomNavigation() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: _ink.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            children: [
              _buildNavItem(
                index: 0,
                icon: Icons.dashboard_rounded,
                outlinedIcon: Icons.dashboard_outlined,
                label: 'الرئيسية',
              ),
              _buildNavItem(
                index: 1,
                icon: Icons.sell_rounded,
                outlinedIcon: Icons.sell_outlined,
                label: 'عروضي',
              ),
              _buildNavItem(
                index: 2,
                icon: Icons.volunteer_activism_rounded,
                outlinedIcon: Icons.volunteer_activism_outlined,
                label: 'تبرعاتي',
              ),
              _buildNavItem(
                index: 3,
                icon: Icons.people_alt_rounded,
                outlinedIcon: Icons.people_outline_rounded,
                label: 'طلبات',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required IconData outlinedIcon,
    required String label,
  }) {
    final selected = _tab == index;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tab = index),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            gradient: selected
                ? LinearGradient(
                    colors: [
                      _primary.withValues(alpha: 0.12),
                      _primaryLight.withValues(alpha: 0.08),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  )
                : null,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  gradient: selected
                      ? const LinearGradient(
                          colors: [_primary, _primaryLight],
                          begin: Alignment.topRight,
                          end: Alignment.bottomLeft,
                        )
                      : null,
                  color: selected ? null : Colors.transparent,
                  borderRadius: BorderRadius.circular(11),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: _primary.withValues(alpha: 0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: Icon(
                  selected ? icon : outlinedIcon,
                  size: 20,
                  color: selected ? Colors.white : _inkSoft,
                ),
              ),
              const SizedBox(height: 4),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 260),
                style: TextStyle(
                  color: selected ? _primary : _inkSoft,
                  fontSize: 10.5,
                  fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
                ),
                child: Text(label),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // ERROR VIEW
  // ═══════════════════════════════════════════════════════════
  Widget _buildErrorView() {
    return Center(
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
                color: _red.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.cloud_off_rounded,
                size: 42,
                color: _red,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _error ?? 'حدث خطأ غير متوقع',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _ink,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _load,
              style: FilledButton.styleFrom(
                backgroundColor: _primary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text(
                'إعادة المحاولة',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static DateTime _dateOf(Map<String, dynamic> row) =>
      DateTime.tryParse(
          (row['created_at'] ?? row['updated_at'])?.toString() ?? '') ??
      DateTime(1970);

  static String _typeName(String value) {
    const types = {
      'bakery': 'مخبز وحلويات',
      'grocery': 'بقالة',
      'game_store': 'محل ألعاب',
      'supermarket': 'سوبر ماركت',
      'cafe': 'كافيه',
      'hotel': 'فندق',
    };
    return types[value] ?? 'مؤسسة';
  }
}

// ═══════════════════════════════════════════════════════════
// STAT CARD
// ═══════════════════════════════════════════════════════════
class _StatData {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatData({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });
}

class _StatCard extends StatelessWidget {
  final _StatData data;

  const _StatCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: data.color.withValues(alpha: 0.15),
        ),
        boxShadow: [
          BoxShadow(
            color: data.color.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: data.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(data.icon, color: data.color, size: 16),
              ),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: data.color,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: data.color.withValues(alpha: 0.5),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            data.value,
            style: TextStyle(
              color: data.color,
              fontSize: 26,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            data.title,
            style: const TextStyle(
              color: _inkSoft,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// ACTIVITY CARD
// ═══════════════════════════════════════════════════════════
class _ActivityCard extends StatelessWidget {
  final Map<String, dynamic> row;
  final IconData icon;
  final bool isOffer;
  final VoidCallback onTap;
  final VoidCallback? onEdit;

  const _ActivityCard({
    required this.row,
    required this.icon,
    required this.isOffer,
    required this.onTap,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final status = row['status']?.toString() ?? 'pending';
    final title =
        (row['title'] ?? row['item_title'] ?? 'بدون عنوان').toString();
    final image = _imageUrl(row);
    final subtitle = isOffer
        ? '${row['symbolic_price'] ?? '—'} ج.م · ${row['remaining_quantity'] ?? row['quantity'] ?? '—'} قطعة'
        : '${row['charity_name'] ?? 'جمعية'} · ${row['quantity'] ?? '—'} قطعة';

    final isExpired = status == 'expired';
    final isCancelled = status == 'cancelled';
    final isEditable = isOffer && !isExpired && !isCancelled;

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
              color: status == 'active' || status == 'available'
                  ? _primary.withValues(alpha: 0.3)
                  : const Color(0xFFEEF3F0),
            ),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: image == null
                      ? Container(
                          color: _primary.withValues(alpha: 0.1),
                          child: Icon(icon, color: _primary, size: 24),
                        )
                      : Image.network(
                          image,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: _primary.withValues(alpha: 0.1),
                            child: Icon(icon, color: _primary, size: 24),
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _ink,
                        fontWeight: FontWeight.w900,
                        fontSize: 13.5,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _inkSoft,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _StatusChip(status: status),
                  ],
                ),
              ),
              if (isEditable && onEdit != null)
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') onEdit!();
                  },
                  icon: const Icon(
                    Icons.more_vert_rounded,
                    color: _inkSoft,
                    size: 18,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 16),
                          SizedBox(width: 6),
                          Text('تعديل العرض', style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  static String? _imageUrl(Map<String, dynamic> row) {
    final images = row['images'];
    if (images is List && images.isNotEmpty) {
      final value = images.first?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }
}

// ═══════════════════════════════════════════════════════════
// OFFER CARD
// ═══════════════════════════════════════════════════════════
class _OfferCard extends StatelessWidget {
  final Map<String, dynamic> offer;
  final VoidCallback onTap;
  final VoidCallback onEdit;

  const _OfferCard({
    required this.offer,
    required this.onTap,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final status = offer['status']?.toString() ?? 'pending';
    final title = offer['title']?.toString() ?? 'عرض بدون اسم';
    final price = (offer['symbolic_price'] as num?)?.toDouble() ?? 0;
    final quantity = offer['quantity'] ?? 0;
    final remaining = offer['remaining_quantity'] ?? quantity;
    final images = offer['images'] as List? ?? [];
    final imageUrl = images.isNotEmpty ? images.first.toString() : null;
    final isActive = status == 'active' || status == 'available';
    final isExpired = status == 'expired';
    final isCancelled = status == 'cancelled';
    final isEditable = !isExpired && !isCancelled;

    final expiryDate = offer['expires_at'] != null
        ? DateTime.tryParse(offer['expires_at'].toString())
        : null;
    final expiryStatus = _expiryStatus(expiryDate);
    final expiryColor = expiryStatus.$2;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isActive
                  ? _primary.withValues(alpha: 0.25)
                  : const Color(0xFFEEF3F0),
              width: isActive ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: _ink.withValues(alpha: 0.04),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
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
                          width: 88,
                          height: 88,
                          color: _primary.withValues(alpha: 0.08),
                          child: imageUrl != null
                              ? Image.network(
                                  imageUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Icon(
                                    Icons.image_outlined,
                                    color: _primary,
                                    size: 30,
                                  ),
                                )
                              : const Icon(
                                  Icons.inventory_2_outlined,
                                  color: _primary,
                                  size: 30,
                                ),
                        ),
                      ),
                      if (isActive)
                        Positioned(
                          top: 4,
                          right: 4,
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: _primaryLight,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: _primaryLight.withValues(alpha: 0.5),
                                  blurRadius: 6,
                                ),
                              ],
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
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: _ink,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  height: 1.3,
                                ),
                              ),
                            ),
                            if (isEditable)
                              GestureDetector(
                                onTap: onEdit,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: _primary.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.edit_rounded,
                                    color: _primary,
                                    size: 14,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        _StatusChip(status: status),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: _cream,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    // ── السعر
                    Expanded(
                      child: Row(
                        children: [
                          Icon(
                            Icons.payments_rounded,
                            size: 14,
                            color: _primary,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            '${price.toStringAsFixed(0)} ج.م',
                            style: const TextStyle(
                              color: _primary,
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 20,
                      color: _inkSoft.withValues(alpha: 0.15),
                    ),
                    const SizedBox(width: 10),
                    // ── الكمية
                    Row(
                      children: [
                        Icon(
                          Icons.inventory_2_rounded,
                          size: 14,
                          color: _inkSoft,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '$remaining / $quantity',
                          style: const TextStyle(
                            color: _ink,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 10),
                    Container(
                      width: 1,
                      height: 20,
                      color: _inkSoft.withValues(alpha: 0.15),
                    ),
                    const SizedBox(width: 10),
                    // ── الصلاحية
                    if (expiryDate != null)
                      Row(
                        children: [
                          Icon(
                            expiryStatus.$1,
                            size: 14,
                            color: expiryColor,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            '${expiryDate.day}/${expiryDate.month}',
                            style: TextStyle(
                              color: expiryColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              if (isExpired || isCancelled) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _red.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _red.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isExpired
                            ? Icons.timer_off_rounded
                            : Icons.block_rounded,
                        size: 14,
                        color: _red,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isExpired
                            ? 'هذا العرض منتهي الصلاحية'
                            : 'هذا العرض ملغي',
                        style: const TextStyle(
                          color: _red,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  (IconData, Color) _expiryStatus(DateTime? expiryDate) {
    if (expiryDate == null) {
      return (Icons.help_outline_rounded, _inkSoft);
    }
    final daysLeft = expiryDate.difference(DateTime.now()).inDays;
    if (daysLeft < 0) {
      return (Icons.warning_amber_rounded, _red);
    } else if (daysLeft <= 3) {
      return (Icons.timer_outlined, _orange);
    } else if (daysLeft <= 7) {
      return (Icons.fiber_new_rounded, _primary);
    } else {
      return (Icons.inventory_2_rounded, _blue);
    }
  }
}

// ═══════════════════════════════════════════════════════════
// DONATION CARD
// ═══════════════════════════════════════════════════════════
class _DonationCard extends StatelessWidget {
  final Map<String, dynamic> donation;
  final VoidCallback onTap;

  const _DonationCard({required this.donation, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final status = donation['status']?.toString() ?? 'pending';
    final title = donation['item_title']?.toString() ??
        donation['title']?.toString() ??
        'تبرع';
    final charityName = donation['charities']?['name']?.toString() ?? 'جمعية';
    final quantity = donation['quantity'] ?? 0;
    final images = donation['images'] as List? ?? [];
    final imageUrl = images.isNotEmpty ? images.first.toString() : null;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFEEF3F0)),
            boxShadow: [
              BoxShadow(
                color: _ink.withValues(alpha: 0.04),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: 80,
                  height: 80,
                  color: _purple.withValues(alpha: 0.08),
                  child: imageUrl != null
                      ? Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.volunteer_activism_rounded,
                            color: _purple,
                            size: 30,
                          ),
                        )
                      : const Icon(
                          Icons.volunteer_activism_rounded,
                          color: _purple,
                          size: 30,
                        ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.storefront_rounded,
                          size: 13,
                          color: _inkSoft,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            charityName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _inkSoft,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.inventory_2_outlined,
                          size: 12,
                          color: _inkSoft,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$quantity قطعة',
                          style: const TextStyle(
                            color: _inkSoft,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    _StatusChip(status: status),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 14,
                color: _inkSoft,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// STATUS CHIP
// ═══════════════════════════════════════════════════════════
class _StatusChip extends StatelessWidget {
  final String status;

  const _StatusChip({required this.status});

  String get _label {
    switch (status) {
      case 'active':
      case 'available':
        return 'نشط';
      case 'paused':
        return 'متوقف';
      case 'sold_out':
        return 'خلصت';
      case 'expired':
        return 'منتهي';
      case 'cancelled':
        return 'ملغي';
      case 'pending':
        return 'قيد المراجعة';
      case 'accepted':
        return 'تم القبول';
      case 'rejected':
        return 'مرفوض';
      case 'volunteer_assigned':
        return 'متطوع';
      case 'institution_ready':
        return 'جاهز';
      case 'volunteer_departed':
        return 'في الطريق';
      case 'picked_up':
        return 'تم الاستلام';
      case 'completed':
        return 'مكتمل';
      default:
        return 'غير محدد';
    }
  }

  IconData get _icon {
    switch (status) {
      case 'active':
      case 'available':
        return Icons.check_circle_rounded;
      case 'paused':
        return Icons.pause_circle_rounded;
      case 'sold_out':
        return Icons.inventory_2_rounded;
      case 'expired':
        return Icons.timer_off_rounded;
      case 'cancelled':
      case 'rejected':
        return Icons.cancel_rounded;
      case 'pending':
        return Icons.hourglass_top_rounded;
      case 'accepted':
        return Icons.thumb_up_rounded;
      case 'volunteer_assigned':
        return Icons.person_add_alt_1_rounded;
      case 'institution_ready':
        return Icons.inventory_2_rounded;
      case 'volunteer_departed':
        return Icons.directions_car_rounded;
      case 'picked_up':
        return Icons.shopping_bag_rounded;
      case 'completed':
        return Icons.emoji_events_rounded;
      default:
        return Icons.help_outline_rounded;
    }
  }

  Color get _color {
    final active = {
      'active',
      'available',
      'accepted',
      'completed',
      'picked_up'
    };
    final warning = {
      'pending',
      'volunteer_assigned',
      'institution_ready',
      'volunteer_departed'
    };
    final inactive = {'paused', 'sold_out', 'expired', 'cancelled', 'rejected'};

    if (active.contains(status)) return _primary;
    if (warning.contains(status)) return _orange;
    if (inactive.contains(status)) return _red;
    return _inkSoft;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon, size: 11, color: _color),
          const SizedBox(width: 4),
          Text(
            _label,
            style: TextStyle(
              color: _color,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// ACTION GRID
// ═══════════════════════════════════════════════════════════
class _ActionGrid extends StatelessWidget {
  final VoidCallback onOffer;
  final VoidCallback onDonation;

  const _ActionGrid({
    required this.onOffer,
    required this.onDonation,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 620) {
          return Row(
            children: [
              Expanded(
                child: _ActionCard(
                  icon: Icons.sell_rounded,
                  title: 'بيع بسعر رمزي',
                  subtitle: 'اعرض المنتجات الصالحة',
                  colors: const [Color(0xFFD4A843), Color(0xFFB38A2C)],
                  onTap: onOffer,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ActionCard(
                  icon: Icons.volunteer_activism_rounded,
                  title: 'تبرع لجمعية',
                  subtitle: 'أرسل الفائض للجمعيات',
                  colors: const [Color(0xFF7B5EC7), Color(0xFF5A3FA5)],
                  onTap: onDonation,
                ),
              ),
            ],
          );
        }

        return Column(
          children: [
            _ActionCard(
              icon: Icons.sell_rounded,
              title: 'بيع بسعر رمزي',
              subtitle: 'اعرض المنتجات الصالحة بسعر مناسب',
              colors: const [Color(0xFFD4A843), Color(0xFFB38A2C)],
              onTap: onOffer,
            ),
            const SizedBox(height: 12),
            _ActionCard(
              icon: Icons.volunteer_activism_rounded,
              title: 'تبرع لجمعية',
              subtitle: 'أرسل الفائض إلى جمعية موثوقة',
              colors: const [Color(0xFF7B5EC7), Color(0xFF5A3FA5)],
              onTap: onDonation,
            ),
          ],
        );
      },
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Color> colors;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: colors,
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: colors.first.withValues(alpha: 0.3),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_back_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// EMPTY / AVATAR
// ═══════════════════════════════════════════════════════════
class _EmptyView extends StatelessWidget {
  final String message;

  const _EmptyView({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.inbox_rounded,
                size: 38,
                color: _primary,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _inkSoft,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String? url;
  final double size;

  const _Avatar({required this.url, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.4),
          width: 1.5,
        ),
        color: Colors.white.withValues(alpha: 0.15),
        image: url != null && url!.trim().isNotEmpty
            ? DecorationImage(
                image: NetworkImage(url!.trim()),
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: url == null || url!.trim().isEmpty
          ? Icon(
              Icons.storefront_rounded,
              color: Colors.white,
              size: size * 0.5,
            )
          : null,
    );
  }
}
