import 'dart:async';

import 'package:flutter/material.dart';
import 'package:loqma/core/services/supabase_service.dart';
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
    extends State<CommunityMyCharityDonationsPage> {
  final _repository = SeparateCharityDonationRepository();
  late Future<List<Map<String, dynamic>>> _future;
  String _filter = 'all';
  bool _loadingCode = false;
  StreamSubscription<List<Map<String, dynamic>>>? _donationSubscription;
  final Map<String, String> _knownStatuses = <String, String>{};

  static const _green = Color(0xFF0B7650);
  static const _darkGreen = Color(0xFF123F31);
  static const _background = Color(0xFFF6FAF8);
  static const _red = Color(0xFFB54747);

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
          title: const Text('🔑 كود تسليم التبرع'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'اعرض هذا الكود لمندوب الجمعية عند استلام التبرع. لا ترسله لأي شخص آخر.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _green.withAlpha(20),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _green.withAlpha(50)),
                ),
                child: SelectableText(
                  code,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _green,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '⏰ الكود صالح لمدة 24 ساعة',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('تم'),
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

  // ✅ دالة تأكيد جاهزية المتبرع
  Future<void> _markDonorReady(String requestId) async {
    try {
      await SupabaseService().client.from('charity_donation_requests').update({
        'status': 'donor_ready',
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', requestId);
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
          titleSpacing: 16,
          title: Row(children: [
            Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    color: _darkGreen, borderRadius: BorderRadius.circular(12)),
                child: const Text('ل',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900))),
            const SizedBox(width: 10),
            const Text('لقمة',
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
          ]),
          actions: [
            IconButton(
                onPressed: _refresh,
                icon: const Icon(Icons.refresh_rounded),
                tooltip: 'تحديث'),
            IconButton(
                onPressed: () =>
                    _message('ستظهر إشعارات التبرعات هنا عند وصول تحديث جديد'),
                icon: const Icon(Icons.notifications_none_rounded),
                tooltip: 'الإشعارات'),
          ],
        ),
        body: FutureBuilder<List<Map<String, dynamic>>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                  child: CircularProgressIndicator(color: _green));
            }
            if (snapshot.hasError) {
              return _emptyState(
                  _friendlyError(snapshot.error!), Icons.cloud_off_rounded);
            }
            final all = snapshot.data ?? const <Map<String, dynamic>>[];
            final rows = all.where(_matches).toList();
            final pending =
                all.where((r) => r['status']?.toString() == 'pending').length;
            final active = all
                .where((r) => {
                      'accepted',
                      'donor_ready',
                      'volunteer_assigned',
                      'picked_up_from_donor',
                      'in_transit'
                    }.contains(r['status']?.toString()))
                .length;
            final assigned = all
                .where((r) => r['status']?.toString() == 'volunteer_assigned')
                .length;
            final completed =
                all.where((r) => r['status']?.toString() == 'completed').length;
            final actionRows = all
                .where((r) => {'accepted', 'volunteer_assigned'}
                    .contains(r['status']?.toString()))
                .take(2)
                .toList();
            final recent = [...all]
              ..sort((a, b) => _dateValue(b).compareTo(_dateValue(a)));
            return RefreshIndicator(
              color: _green,
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 100),
                children: [
                  _welcomeHero(pending),
                  const SizedBox(height: 18),
                  _metricGrid(pending, active, assigned, completed),
                  const SizedBox(height: 22),
                  if (actionRows.isNotEmpty) ...[
                    _sectionTitle(
                        'يحتاج إلى إجراء', '${actionRows.length} طلب'),
                    const SizedBox(height: 10),
                    ...actionRows.map(_actionCard),
                    const SizedBox(height: 18),
                  ],
                  _sectionTitle('آخر التحديثات', '${recent.length} تبرع'),
                  const SizedBox(height: 10),
                  recent.isEmpty
                      ? _emptyState(
                          'لا توجد تحديثات بعد.', Icons.timeline_rounded)
                      : _activityCard(recent.take(4).toList()),
                  const SizedBox(height: 22),
                  _filters(),
                  const SizedBox(height: 14),
                  if (rows.isEmpty)
                    _emptyState('لا توجد تبرعات خاصة بهذا الفلتر.',
                        Icons.volunteer_activism_outlined)
                  else
                    ...rows.map(_card),
                ],
              ),
            );
          },
        ),
        bottomNavigationBar: _bottomNavigation(),
      ),
    );
  }

  DateTime _dateValue(Map<String, dynamic> row) =>
      DateTime.tryParse(row['updated_at']?.toString() ??
          row['created_at']?.toString() ??
          '') ??
      DateTime.fromMillisecondsSinceEpoch(0);

  String _relativeDate(Map<String, dynamic> row) {
    final date = _dateValue(row);
    if (date.millisecondsSinceEpoch == 0) return 'وقت غير محدد';
    final diff = DateTime.now().difference(date.toLocal());
    if (diff.inMinutes < 1) return 'الآن';
    if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} دقيقة';
    if (diff.inHours < 24) return 'منذ ${diff.inHours} ساعة';
    return 'منذ ${diff.inDays} يوم';
  }

  Widget _sectionTitle(String title, String trailing) =>
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(title,
            style: const TextStyle(
                color: _darkGreen, fontSize: 18, fontWeight: FontWeight.w900)),
        Text(trailing,
            style: const TextStyle(
                color: _green, fontSize: 12, fontWeight: FontWeight.w700))
      ]);

  Widget _welcomeHero(int pending) => Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Color(0xFF003527), Color(0xFF006C48)],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft),
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(
                color: Color(0x22003527), blurRadius: 18, offset: Offset(0, 8))
          ]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Expanded(
              child: Text('مرحباً، متبرع الخير',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900))),
          Icon(Icons.volunteer_activism_rounded,
              color: Colors.white.withValues(alpha: .9), size: 32)
        ]),
        const SizedBox(height: 10),
        Text(
            pending > 0
                ? 'لديك $pending تبرع يحتاج إلى متابعة. شكراً لمساهمتك في إيصال الخير لمستحقيه.'
                : 'تابع أثر تبرعاتك مع الجمعيات الموثقة من مكان واحد.',
            style: const TextStyle(
                color: Colors.white70, height: 1.6, fontSize: 13)),
        const SizedBox(height: 16),
        OutlinedButton.icon(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('تحديث الحالة'),
            style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white54)))
      ]));

  Widget _metricGrid(int pending, int active, int assigned, int completed) {
    final metrics = [
      (
        'طلبات جديدة',
        pending,
        Icons.new_releases_rounded,
        const Color(0xFFFFE3E0),
        const Color(0xFFB54747)
      ),
      (
        'قيد التنفيذ',
        active,
        Icons.hourglass_top_rounded,
        const Color(0xFFDDF3E8),
        _green
      ),
      (
        'في انتظار مندوب',
        assigned,
        Icons.local_shipping_rounded,
        const Color(0xFFE8F0ED),
        _darkGreen
      ),
      (
        'مكتملة',
        completed,
        Icons.check_circle_rounded,
        const Color(0xFFE4EDEA),
        const Color(0xFF496B5E)
      )
    ];
    return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: metrics.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.45),
        itemBuilder: (_, i) {
          final m = metrics[i];
          return Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE1ECE6)),
                  boxShadow: const [
                    BoxShadow(
                        color: Color(0x08003527),
                        blurRadius: 12,
                        offset: Offset(0, 4))
                  ]),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                              child: Text(m.$1,
                                  style: const TextStyle(
                                      color: Color(0xFF52645C),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700))),
                          Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                  color: m.$4, shape: BoxShape.circle),
                              child: Icon(m.$3, color: m.$5, size: 17))
                        ]),
                    Text('${m.$2}',
                        style: const TextStyle(
                            color: _darkGreen,
                            fontSize: 26,
                            fontWeight: FontWeight.w900))
                  ]));
        });
  }

  Widget _actionCard(Map<String, dynamic> row) {
    final status = row['status']?.toString() ?? 'pending';
    final isCurrentUserVolunteer = row['volunteer_id']?.toString() ==
        Supabase.instance.client.auth.currentUser?.id;

    return Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border(
                right: BorderSide(
                    color:
                        status == 'volunteer_assigned' && isCurrentUserVolunteer
                            ? _green
                            : status == 'accepted'
                                ? const Color(0xFF3679C8)
                                : _green,
                    width: 4)),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x08003527),
                  blurRadius: 12,
                  offset: Offset(0, 4))
            ]),
        child: Row(children: [
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(row['title']?.toString() ?? 'تبرع مباشر',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: _darkGreen, fontWeight: FontWeight.w900)),
                const SizedBox(height: 5),
                Text(_statusLabel(status),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style:
                        const TextStyle(color: Color(0xFF61736A), fontSize: 11))
              ])),
          const SizedBox(width: 8),
          OutlinedButton(
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          CommunityCharityDonationDetailsPage(donation: row))),
              child: const Text('التفاصيل'))
        ]));
  }

  Widget _activityCard(List<Map<String, dynamic>> rows) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE1ECE6)),
      ),
      child: Column(
        children: rows.map((row) {
          final status = row['status']?.toString() ?? 'pending';
          final title = row['title']?.toString() ?? 'تبرع مباشر';
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.only(top: 5),
                  decoration: BoxDecoration(
                    color: _statusColor(status),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _statusLabel(status),
                        style: TextStyle(
                          color: _statusColor(status),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '$title • ${_relativeDate(row)}',
                        style: const TextStyle(
                          color: Color(0xFF74847C),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _bottomNavigation() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE1ECE6))),
          boxShadow: [
            BoxShadow(
              color: Color(0x12003527),
              blurRadius: 14,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _navItem(Icons.dashboard_rounded, 'الرئيسية', true, () {}),
            _navItem(Icons.volunteer_activism_rounded, 'تبرعاتي', false, () {}),
            _navItem(
              Icons.favorite_border_rounded,
              'الجمعيات',
              false,
              () => _message('يمكنك استعراض الجمعيات من الصفحة الرئيسية'),
            ),
            _navItem(
              Icons.person_outline_rounded,
              'حسابي',
              false,
              () => _message('ملف الحساب متاح من الصفحة الشخصية'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _navItem(
    IconData icon,
    String label,
    bool active,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: active ? _green : const Color(0xFF71837C),
              size: 22,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: active ? _green : const Color(0xFF71837C),
                fontSize: 10,
                fontWeight: active ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filters() {
    const filters = <String, String>{
      'all': 'الكل',
      'pending': '⏳ في الانتظار',
      'accepted': '✅ مقبول',
      'volunteer_assigned': '👤 تم تعيين المندوب',
      'donor_ready': '📦 أعلنت جاهزيتك',
      'picked_up_from_donor': '📋 تم الاستلام',
      'in_transit': '🚗 في الطريق',
      'completed': '🎉 وصل للجمعية',
    };
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 7),
        itemBuilder: (_, index) {
          final key = filters.keys.elementAt(index);
          final active = _filter == key;
          return FilterChip(
            selected: active,
            onSelected: (_) => setState(() => _filter = key),
            label: Text(filters[key]!),
            selectedColor: const Color(0xFFDDF3E8),
            backgroundColor: Colors.white,
            checkmarkColor: _green,
            side: BorderSide(color: active ? _green : const Color(0xFFE0EBE5)),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          );
        },
      ),
    );
  }

  String _statusLabel(String status) =>
      <String, String>{
        'pending': '⏳ في انتظار مراجعة الجمعية',
        'accepted': '✅ وافقت الجمعية — أعلن جاهزيتك',
        'donor_ready': '📦 أعلنت جاهزيتك — في انتظار مندوب الجمعية',
        'volunteer_assigned':
            '👤 تم إرسال مندوب الجمعية — اعرض الكود عند وصوله',
        'picked_up_from_donor': '📋 تم استلامه من المتبرع',
        'in_transit': '🚗 التبرع في الطريق',
        'completed': '🎉 وصل التبرع للجمعية بنجاح',
        'rejected': '❌ لم تقبل الجمعية التبرع',
        'cancelled': '🚫 تم إلغاء التبرع',
        'expired': '⏰ انتهت مهلة التبرع',
      }[status] ??
      '🔄 جار تحديث حالة التبرع';

  Color _statusColor(String status) {
    if (status == 'rejected' || status == 'cancelled' || status == 'expired') {
      return _red;
    }
    if (status == 'completed') {
      return _green;
    }
    if (status == 'volunteer_assigned' || status == 'accepted') {
      return const Color(0xFF3679C8);
    }
    if (status == 'donor_ready' ||
        status == 'picked_up_from_donor' ||
        status == 'in_transit') {
      return const Color(0xFFB77700);
    }
    return _green;
  }

  Widget _card(Map<String, dynamic> row) {
    final charity = row['charities'] is Map
        ? Map<String, dynamic>.from(row['charities'] as Map)
        : <String, dynamic>{};
    final status = row['status']?.toString() ?? 'pending';
    final images = row['images'] is List
        ? List<dynamic>.from(row['images'] as List)
        : <dynamic>[];
    final image = images.isNotEmpty ? images.first.toString() : '';
    final title = row['title']?.toString() ?? 'تبرع مباشر';
    final charityName = charity['name']?.toString() ?? 'جمعية موثقة';
    final volunteer = row['volunteer_name']?.toString();
    final isCurrentUserVolunteer = row['volunteer_id']?.toString() ==
        Supabase.instance.client.auth.currentUser?.id;
    final showCode = status == 'volunteer_assigned' && isCurrentUserVolunteer;
    final showDonorReady = status == 'accepted';

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CommunityCharityDonationDetailsPage(donation: row),
        ),
      ),
      borderRadius: BorderRadius.circular(23),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(23),
          border: Border.all(color: const Color(0xFFE1ECE6)),
          boxShadow: const [
            BoxShadow(
                color: Color(0x080B7650), blurRadius: 14, offset: Offset(0, 5))
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: SizedBox(
                    width: 76,
                    height: 76,
                    child: image.isEmpty
                        ? Container(
                            color: const Color(0xFFE8F5EE),
                            child: const Icon(Icons.volunteer_activism_rounded,
                                color: _green, size: 31))
                        : Image.network(image,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                                color: const Color(0xFFE8F5EE),
                                child: const Icon(
                                    Icons.volunteer_activism_rounded,
                                    color: _green,
                                    size: 31))),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: _darkGreen,
                              fontWeight: FontWeight.w900,
                              fontSize: 15)),
                      const SizedBox(height: 7),
                      Text(charityName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: _green,
                              fontWeight: FontWeight.w800,
                              fontSize: 12)),
                      const SizedBox(height: 5),
                      Text(_statusLabel(status),
                          style: TextStyle(
                              color: _statusColor(status),
                              fontSize: 12,
                              fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
              ],
            ),
            if (volunteer != null && volunteer.isNotEmpty) ...[
              const SizedBox(height: 10),
              Align(
                  alignment: Alignment.centerRight,
                  child: Text('مندوب الجمعية: $volunteer',
                      style: const TextStyle(
                          color: Color(0xFF71837C), fontSize: 11))),
            ],
            const SizedBox(height: 17),
            _timeline(status),
            // ✅ زر "أنا جاهز للتسليم" للمتبرع
            if (showDonorReady) ...[
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _markDonorReady(row['id'].toString()),
                  icon: const Icon(Icons.check_circle_outline_rounded),
                  label: const Text('📦 أنا جاهز للتسليم'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
            // ✅ زر "اعرض كود الاستلام" للمتبرع
            if (showCode) ...[
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _loadingCode
                      ? null
                      : () => _showPickupCode(row['id'].toString()),
                  icon: const Icon(Icons.qr_code_2_rounded),
                  label: Text(_loadingCode
                      ? 'جار تجهيز الكود...'
                      : '🔑 اعرض كود الاستلام للمندوب'),
                  style: FilledButton.styleFrom(
                      backgroundColor: _green, foregroundColor: Colors.white),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _timeline(String status) {
    const steps = <(String, String, IconData)>[
      ('pending', 'أرسلت التبرع', Icons.send_rounded),
      ('accepted', 'راجعت الجمعية', Icons.fact_check_outlined),
      ('volunteer_assigned', 'المندوب جاهز', Icons.badge_outlined),
      ('picked_up_from_donor', 'استلمه المندوب', Icons.verified_user_outlined),
      ('completed', 'وصل للجمعية', Icons.done_all_rounded),
    ];

    final activeIndex = switch (status) {
      'pending' => 0,
      'accepted' => 1,
      'donor_ready' || 'volunteer_assigned' => 2,
      'picked_up_from_donor' || 'in_transit' => 3,
      'completed' => 4,
      _ => 0,
    };

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(steps.length, (index) {
          final active = index <= activeIndex;
          return SizedBox(
            width: 78,
            child: Column(
              children: [
                Container(
                    width: 29,
                    height: 29,
                    decoration: BoxDecoration(
                        color: active
                            ? _statusColor(status)
                            : const Color(0xFFE5EEE9),
                        shape: BoxShape.circle),
                    child: Icon(steps[index].$3,
                        color: active ? Colors.white : const Color(0xFF9AACA3),
                        size: 15)),
                const SizedBox(height: 5),
                Text(steps[index].$2,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: active ? _darkGreen : const Color(0xFF98A9A1),
                        fontSize: 9,
                        fontWeight:
                            active ? FontWeight.w800 : FontWeight.w500)),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _emptyState(String text, IconData icon) => Center(
      child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: _green, size: 46),
            const SizedBox(height: 12),
            Text(text,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: _darkGreen, fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            OutlinedButton(
                onPressed: _refresh, child: const Text('إعادة المحاولة'))
          ])));

  String _friendlyError(Object error) {
    final text = error.toString().toLowerCase();
    if (text.contains('permission') || text.contains('42501')) {
      return 'لا توجد صلاحية لقراءة تبرعاتك. سجّل الدخول مرة أخرى.';
    }
    if (text.contains('network') || text.contains('timeout')) {
      return 'تعذر الاتصال بالإنترنت.';
    }
    return 'تعذر تحميل تبرعاتك للجمعيات. حاول مرة أخرى.';
  }

  void _message(String text, {bool error = false}) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(text, textDirection: TextDirection.rtl),
          backgroundColor: error ? _red : _green));
}
