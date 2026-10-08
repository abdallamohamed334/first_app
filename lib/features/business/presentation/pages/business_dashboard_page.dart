import 'package:flutter/material.dart';
import 'package:loqma/features/business/domain/entities/business_capability.dart';

import 'package:loqma/core/models/business.dart';
import 'package:loqma/core/services/supabase_service.dart';
import 'package:loqma/features/business/data/repositories/business_repository.dart';
import 'package:loqma/features/business/presentation/pages/BusinessOperationsPage.dart';
import 'package:loqma/features/business/presentation/pages/pickup_requests_page.dart';
import 'package:loqma/features/business/presentation/pages/scan_qr_page.dart';
import 'package:loqma/features/business/presentation/pages/add_offer_page.dart';
import 'package:loqma/features/auth/presentation/pages/login_page.dart';

class BusinessDashboardPage extends StatefulWidget {
  final String businessId;

  const BusinessDashboardPage({
    super.key,
    required this.businessId,
  });

  @override
  State<BusinessDashboardPage> createState() => _BusinessDashboardPageState();
}

class _BusinessDashboardPageState extends State<BusinessDashboardPage> {
  final BusinessRepository _repository = BusinessRepository(SupabaseService());

  bool _isLoading = true;
  String? _error;
  Business? _business;
  Map<String, dynamic> _stats = <String, dynamic>{};
  List<Map<String, dynamic>> _recentRequests = <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await Future.wait<dynamic>([
        _repository.getBusinessById(widget.businessId),
        _repository.getBusinessStats(widget.businessId),
        _repository.getPickupRequests(widget.businessId),
      ]);

      final business = results[0] as Business?;
      final stats = Map<String, dynamic>.from(results[1] as Map);
      final requests = List<Map<String, dynamic>>.from(results[2] as List);

      if (business == null) {
        throw Exception('لم يتم العثور على بيانات المطعم');
      }

      if (!mounted) return;

      setState(() {
        _business = business;
        _stats = stats;
        _recentRequests = requests.take(5).toList();
        _isLoading = false;
      });

      debugPrint('✅ Business loaded: ${business.name}');
      debugPrint('✅ Stats loaded: $stats');
      debugPrint('✅ Recent requests: ${_recentRequests.length}');
    } catch (e) {
      debugPrint('❌ Dashboard error: $e');

      if (!mounted) return;

      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return _buildLoading();
    if (_error != null) return _buildError();
    if (_business == null) return _buildNoData();

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8F7),
      body: RefreshIndicator(
        color: const Color(0xFF16835B),
        onRefresh: _loadData,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            _buildHeader(),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildWelcomeText(),
                  const SizedBox(height: 16),
                  if (_business!.can(BusinessCapability.analytics))
                    _buildStatsSection(),
                  if (_business!.can(BusinessCapability.analytics))
                    const SizedBox(height: 22),
                  _buildQuickActions(),
                  if (_business!.can(BusinessCapability.manageRequests))
                    const SizedBox(height: 22),
                  if (_business!.can(BusinessCapability.manageRequests))
                    _buildRecentRequests(),
                  const SizedBox(height: 22),
                  _buildBusinessDetails(),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return const Scaffold(
      backgroundColor: Color(0xFFF6F8F7),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFF16835B)),
            SizedBox(height: 16),
            Text('جاري تحميل بيانات المطعم...'),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8F7),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded,
                  size: 64, color: Colors.redAccent),
              const SizedBox(height: 16),
              const Text(
                'تعذر تحميل البيانات',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                _error ?? 'حدث خطأ غير معروف',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _loadData,
                icon: const Icon(Icons.refresh),
                label: const Text('إعادة المحاولة'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF16835B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoData() {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8F7),
      appBar: AppBar(title: const Text('لوحة المطعم')),
      body: const Center(child: Text('لا توجد بيانات لهذا المطعم')),
    );
  }

  Widget _buildHeader() {
    final business = _business!;
    final isActive = business.status == 'active';

    return SliverAppBar(
      pinned: true,
      expandedHeight: 220,
      backgroundColor: const Color(0xFF0B6B49),
      foregroundColor: Colors.white,
      elevation: 0,
      actions: [
        IconButton(
          tooltip: 'تحديث البيانات',
          onPressed: _loadData,
          icon: const Icon(Icons.refresh_rounded),
        ),
        IconButton(
          tooltip: 'تسجيل الخروج',
          onPressed: _logout,
          icon: const Icon(Icons.logout_rounded),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsetsDirectional.only(start: 20, bottom: 16),
        title: Text(
          business.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0B6B49), Color(0xFF16A06E)],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 50, 20, 42),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 78,
                    height: 78,
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(235),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _initials(business.name),
                      style: const TextStyle(
                        color: Color(0xFF0B6B49),
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'مرحبًا بك في لوحة التحكم',
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          business.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _statusBadge(isActive),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _statusBadge(bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isActive ? Colors.white.withAlpha(40) : Colors.red.withAlpha(70),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withAlpha(70)),
      ),
      child: Text(
        isActive ? 'نشط الآن' : 'غير نشط',
        style: const TextStyle(fontSize: 12, color: Colors.white),
      ),
    );
  }

  Widget _buildWelcomeText() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'نظرة عامة',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            SizedBox(height: 4),
            Text(
              'تابع أداء مطعمك وطلبات الاستلام',
              style: TextStyle(color: Colors.black54, fontSize: 13),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFE4F5ED),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.analytics_rounded,
            color: Color(0xFF16835B),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsSection() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.15,
      children: [
        _statCard(
          title: 'طلبات جاهزة',
          value: _statValue('pendingPickups'),
          icon: Icons.pending_actions_rounded,
          color: const Color(0xFFE98B2A),
        ),
        _statCard(
          title: 'طلبات اليوم',
          value: _statValue('todayPickups'),
          icon: Icons.today_rounded,
          color: const Color(0xFF3986D5),
        ),
        _statCard(
          title: 'إجمالي الطلبات',
          value: _statValue('totalPickups'),
          icon: Icons.inventory_2_rounded,
          color: const Color(0xFF7B61C9),
        ),
        _statCard(
          title: 'النقاط',
          value: _statValue('points'),
          icon: Icons.stars_rounded,
          color: const Color(0xFFD59B18),
        ),
      ],
    );
  }

  Widget _statCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withAlpha(8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withAlpha(25),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 2),
              Text(title, style: const TextStyle(color: Colors.black54)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    final business = _business!;
    final actions = <Widget>[];

    if (business.can(BusinessCapability.createFoodOffers)) {
      actions.add(_actionCard(
        icon: Icons.add_circle_outline_rounded,
        title: 'إضافة عرض بسعر مخفض',
        subtitle: 'عرض فائض الطعام',
        color: const Color(0xFF16835B),
        onTap: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => AddOfferPage(businessId: widget.businessId)),
          );
          if (result == true) _loadData();
        },
      ));
    }

    if (business.can(BusinessCapability.manageRequests)) {
      actions.add(_actionCard(
        icon: Icons.receipt_long_rounded,
        title: 'الطلبات',
        subtitle: 'إدارة طلبات الاستلام',
        color: const Color(0xFFE98B2A),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) =>
                    PickupRequestsPage(businessId: widget.businessId)),
          );
          _loadData();
        },
      ));
    }

    if (business.can(BusinessCapability.scanPickupQr)) {
      actions.add(_actionCard(
        icon: Icons.qr_code_scanner_rounded,
        title: 'مسح رمز الاستلام',
        subtitle: 'QR أو إدخال الكود يدويًا',
        color: const Color(0xFF3986D5),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => ScanQRPage(businessId: widget.businessId)),
        ),
      ));
    }

    if (business.can(BusinessCapability.donations)) {
      actions.add(_actionCard(
        icon: Icons.volunteer_activism_rounded,
        title: 'تبرع لجمعية',
        subtitle: 'إرسال فائض مباشر لجمعية موثقة',
        color: const Color(0xFF7B61C9),
        onTap: _openCharityDonation,
      ));
    }

    if (actions.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 18),
        child: Text('لا توجد صلاحيات تشغيل مفعلة لهذا الحساب حاليًا.',
            textAlign: TextAlign.center),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('إجراءات سريعة',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 650) {
              return Column(
                  children: actions
                      .map((action) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: action))
                      .toList());
            }
            return GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 2.8,
              children: actions,
            );
          },
        ),
      ],
    );
  }

  Future<void> _openCharityDonation() async {
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const BusinessOperationsPage()),
    );
    if (mounted) _loadData();
  }

  Widget _actionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: color.withAlpha(25),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 25),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          const TextStyle(fontSize: 11, color: Colors.black54),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded,
                  size: 14, color: Colors.black38),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentRequests() {
    return _sectionCard(
      title: 'أحدث الطلبات',
      icon: Icons.history_rounded,
      trailing: TextButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PickupRequestsPage(businessId: widget.businessId),
            ),
          );
          _loadData();
        },
        child: const Text('عرض الكل'),
      ),
      child: _recentRequests.isEmpty
          ? _emptyInline(
              icon: Icons.inbox_rounded,
              text: 'لا توجد طلبات حاليًا من قاعدة البيانات',
            )
          : Column(
              children: _recentRequests.map(_buildRequestItem).toList(),
            ),
    );
  }

  Widget _buildRequestItem(Map<String, dynamic> request) {
    final user = request['users'] as Map<String, dynamic>?;
    final offer = request['food_offers'] as Map<String, dynamic>?;
    final userName = (user?['name'] as String?)?.trim();
    final offerTitle = (offer?['title'] as String?)?.trim();
    final status = request['status'] as String? ?? 'pending';

    return InkWell(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PickupRequestsPage(businessId: widget.businessId),
          ),
        );
        _loadData();
      },
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: [
            CircleAvatar(
              radius: 21,
              backgroundColor: const Color(0xFFE4F5ED),
              child: Text(
                _initials(userName?.isNotEmpty == true ? userName! : 'مستخدم'),
                style: const TextStyle(
                  color: Color(0xFF16835B),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    userName?.isNotEmpty == true ? userName! : 'مستخدم',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    offerTitle?.isNotEmpty == true ? offerTitle! : 'عرض طعام',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
              ),
            ),
            _statusChip(status),
          ],
        ),
      ),
    );
  }

  Widget _buildBusinessDetails() {
    final business = _business!;

    return _sectionCard(
      title: 'بيانات المطعم',
      icon: Icons.storefront_rounded,
      child: Column(
        children: [
          _detailRow(Icons.badge_outlined, 'المعرف', business.id),
          _detailRow(Icons.email_outlined, 'البريد الإلكتروني',
              business.email.toString()),
          _detailRow(Icons.phone_outlined, 'الهاتف', business.phone.toString()),
          _detailRow(Icons.location_on_outlined, 'العنوان',
              business.address?.toString() ?? 'غير محدد'),
          _detailRow(Icons.star_outline_rounded, 'التقييم',
              '${business.rating} (${business.totalReviews} مراجعة)'),
          _detailRow(
              Icons.category_outlined, 'نوع النشاط', business.type.displayName),
          _detailRow(Icons.check_circle_outline, 'الحالة',
              business.status == 'active' ? 'نشط' : 'غير نشط'),
          _detailRow(Icons.inventory_2_outlined, 'عمليات مكتملة',
              business.completedCount.toString()),
        ],
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required Widget child,
    Widget? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.black.withAlpha(8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(7),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF16835B), size: 21),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w800),
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
          const Divider(height: 22),
          child,
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 19, color: Colors.black45),
          const SizedBox(width: 10),
          SizedBox(
            width: 95,
            child: Text(label,
                style: const TextStyle(color: Colors.black54, fontSize: 13)),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyInline({required IconData icon, required String text}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Column(
        children: [
          Icon(icon, size: 42, color: Colors.black26),
          const SizedBox(height: 8),
          Text(text, style: const TextStyle(color: Colors.black54)),
        ],
      ),
    );
  }

  Widget _statusChip(String status) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withAlpha(22),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        _statusLabel(status),
        style:
            TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  String _statValue(String key) {
    final value = _stats[key];
    return value?.toString() ?? '0';
  }

  String _initials(String value) {
    final clean = value.trim();
    if (clean.isEmpty) return '؟';
    final words = clean.split(RegExp(r'\s+'));
    if (words.length > 1) {
      return '${words.first.characters.first}${words[1].characters.first}';
    }
    return clean.characters.first;
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'معلق';
      case 'accepted':
        return 'مقبول';
      case 'ready_for_pickup':
        return 'جاهز';
      case 'completed':
        return 'مكتمل';
      case 'cancelled':
        return 'ملغي';
      default:
        return status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'pending':
        return const Color(0xFFE98B2A);
      case 'accepted':
        return const Color(0xFF3986D5);
      case 'ready_for_pickup':
        return const Color(0xFF16835B);
      case 'completed':
        return const Color(0xFF00897B);
      case 'cancelled':
        return const Color(0xFFD64545);
      default:
        return Colors.grey;
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تسجيل الخروج'),
        content: const Text('هل أنت متأكد من تسجيل الخروج؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('تسجيل الخروج'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await SupabaseService().client.auth.signOut();

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ أثناء تسجيل الخروج: $e')),
      );
    }
  }
}
