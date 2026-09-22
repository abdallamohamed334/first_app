// lib/features/charity/presentation/pages/charity_donation_requests_page.dart

import 'package:flutter/material.dart';
import 'package:loqma/features/charity/data/repositories/charity_donation_repository_separate.dart';
import 'package:loqma/features/charity/presentation/pages/charity_action_feedback.dart';
import 'package:loqma/features/charity/presentation/pages/charity_person_donation_details_page.dart';
import 'package:loqma/core/services/supabase_service.dart';
import 'package:loqma/features/auth/presentation/pages/login_page.dart';

class CharityDonationRequestsPage extends StatefulWidget {
  const CharityDonationRequestsPage({super.key});

  @override
  State<CharityDonationRequestsPage> createState() =>
      _CharityDonationRequestsPageState();
}

class _CharityDonationRequestsPageState
    extends State<CharityDonationRequestsPage> {
  final _repository = SeparateCharityDonationRepository();
  late Future<List<Map<String, dynamic>>> _future;
  String _filter = 'all';
  String? _busyId;
  bool _assignmentDialogOpen = false;

  static const _green = Color(0xFF087A52);
  static const _deepGreen = Color(0xFF123D31);
  static const _mint = Color(0xFFE9F7F0);
  static const _background = Color(0xFFF5F8F6);
  static const _purple = Color(0xFF6651B5);
  static const _orange = Color(0xFFB77700);

  @override
  void initState() {
    super.initState();
    _future = _repository.getCharityDonations();
  }

  Future<void> _refresh() async {
    final next = _repository.getCharityDonations();
    if (!mounted) return;

    setState(() {
      _future = next;
    });

    try {
      await next;
    } catch (error) {
      if (mounted) _message(_friendlyError(error), error: true);
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تسجيل الخروج'),
        content: const Text('هل تريد تسجيل الخروج من حساب الجمعية؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
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
      if (mounted) _message('تعذر تسجيل الخروج، حاول مرة أخرى', error: true);
    }
  }

  Future<void> _verifyExternalPickup(String id) async {
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('التحقق من كود الاستلام'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            labelText: 'كود المتبرع',
            hintText: 'LD-XXXXXXXXXXXXXXX',
            prefixIcon: Icon(Icons.verified_user_outlined),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء')),
          FilledButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, controller.text.trim()),
              child: const Text('تحقق')),
        ],
      ),
    );
    if (code == null || code.trim().isEmpty) return;
    setState(() => _busyId = id);
    try {
      await _repository.confirmPickup(requestId: id, token: code);
      await _refresh();
      if (mounted) _message('تم التحقق من الكود وتأكيد استلام التبرع');
    } catch (e) {
      if (mounted) _message(_friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _verifyVolunteerCode(Map<String, dynamic> row) async {
    final id = row['id']?.toString() ?? '';
    final charityId = row['charity_id']?.toString() ?? '';
    final controller = TextEditingController();

    final code = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تأكيد وصول التبرع للجمعية'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'أدخل كود المتطوع (6 أرقام) لتأكيد وصول التبرع',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(
                labelText: 'كود المتطوع (6 أرقام)',
                hintText: 'أدخل الكود الذي أعطاه لك المندوب',
                prefixIcon: Icon(Icons.person_pin_rounded),
                counterText: '',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء')),
          FilledButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, controller.text.trim()),
              child: const Text('تأكيد الوصول')),
        ],
      ),
    );

    if (code == null || code.trim().isEmpty) return;

    setState(() => _busyId = id);
    try {
      await _repository.confirmCharityDeliveryWithCode(
        id,
        code.trim(),
        charityId: charityId,
      );
      await _refresh();
      if (mounted) _message('✅ تم تأكيد وصول التبرع للجمعية بنجاح');
    } catch (e) {
      if (mounted) _message(_friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _acceptWithCharityVolunteer(String id) async {
    setState(() => _busyId = id);
    try {
      final result = await _repository.charityAcceptDonation(
        requestId: id,
        openToVolunteers: false,
      );
      await _refresh();
      if (mounted) {
        final status = result['status']?.toString() ?? 'accepted';
        if (status == 'accepted') {
          _message('✅ تم قبول التبرع — بانتظار جاهزية المتبرع');
        }
      }
    } catch (e) {
      if (mounted) _message(_friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _acceptOpenForVolunteers(String id) async {
    setState(() => _busyId = id);
    try {
      final result = await _repository.charityAcceptDonation(
        requestId: id,
        openToVolunteers: true,
      );
      await _refresh();
      if (mounted) {
        final status = result['status']?.toString() ?? 'volunteer_needed';
        if (status == 'volunteer_needed') {
          _message('✅ تم قبول التبرع وإتاحته للمتطوعين المستقلين');
        }
      }
    } catch (e) {
      if (mounted) _message(_friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _rejectDonation(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('رفض التبرع'),
        content: const Text('هل أنت متأكد؟ هيتم إعلام المتبرع بالرفض.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('إلغاء')),
          FilledButton(
              style:
                  FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('رفض')),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busyId = id);
    try {
      await _repository.charityRejectDonation(requestId: id);
      await _refresh();
      if (mounted) _message('تم رفض التبرع');
    } catch (e) {
      if (mounted) _message(_friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _status(String id, String value,
      {bool isRestaurantDonation = false}) async {
    setState(() => _busyId = id);
    try {
      await _repository.updateStatus(
        requestId: id,
        status: value,
        isRestaurantDonation: isRestaurantDonation,
      );
      await _refresh();
      if (mounted) _message(_successMessage(value));
    } catch (e) {
      if (mounted) {
        _message(e.toString().replaceFirst('Exception: ', ''), error: true);
      }
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  /// ✅ تعيين مندوب — Bottom Sheet بدل Dialog
  Future<void> _assignVolunteer(String id) async {
    if (_assignmentDialogOpen || !mounted) return;
    _assignmentDialogOpen = true;

    try {
      final charityId = await _currentCharityId();
      final rawVolunteers = await SupabaseService()
          .client
          .from('charity_volunteers')
          .select('id, name, phone, status')
          .eq('charity_id', charityId)
          .eq('status', 'active')
          .order('name');

      if (!mounted) {
        _assignmentDialogOpen = false;
        return;
      }

      final volunteers = rawVolunteers
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList(growable: false);

      // ✅ Bottom Sheet
      final assignment = await showModalBottomSheet<_VolunteerAssignment>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _VolunteerBottomSheet(volunteers: volunteers),
      );

      if (assignment == null || !mounted) {
        _assignmentDialogOpen = false;
        return;
      }

      setState(() => _busyId = id);

      final isExternal = assignment.id == null;

      await _repository.charityAssignVolunteer(
        requestId: id,
        volunteerId: assignment.id,
        externalName: isExternal ? assignment.name : null,
        externalPhone: isExternal ? assignment.phone : null,
      );

      await _refresh();
      if (mounted) _message('✅ تم تعيين المندوب بنجاح');
    } catch (e) {
      if (mounted) _message(_friendlyError(e), error: true);
    } finally {
      _assignmentDialogOpen = false;
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<String> _currentCharityId() async {
    final userId = SupabaseService().client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      throw const FormatException('يجب تسجيل الدخول أولًا');
    }
    final row = await SupabaseService()
        .client
        .from('charities')
        .select('id')
        .eq('user_id', userId)
        .eq('status', 'active')
        .maybeSingle();
    final id = row?['id']?.toString().trim() ?? '';
    if (id.isEmpty) {
      throw const FormatException('لا توجد جمعية نشطة مرتبطة بالحساب');
    }
    return id;
  }

  String _successMessage(String status) =>
      {
        'accepted': 'تم قبول التبرع، وبانتظار إعلان المتبرع جاهزيته',
        'in_transit': 'تم تسجيل أن التبرع في الطريق إلى الجمعية',
        'completed': 'تم تأكيد وصول التبرع بنجاح',
      }[status] ??
      'تم تحديث حالة التبرع';

  String _friendlyError(Object error) {
    final raw = error.toString();
    final text = raw.toLowerCase();
    debugPrint('CHARITY_PAGE_ERROR: $raw');

    if (text.contains('23503') || text.contains('foreign key')) {
      return 'تعذر حفظ البيانات لأن هناك حسابًا أو جمعية غير مرتبطة بشكل صحيح.';
    }
    if (text.contains('42501') ||
        text.contains('permission') ||
        text.contains('row-level')) {
      return 'ليس لديك صلاحية لتنفيذ هذه العملية. تأكد من تسجيل الدخول بحساب الجمعية.';
    }
    if (text.contains('pgrst116') || text.contains('no rows')) {
      return 'لم يتم العثور على الطلب. حدّث الصفحة وحاول مرة أخرى.';
    }
    if (text.contains('network') ||
        text.contains('socket') ||
        text.contains('timeout')) {
      return 'تعذر الاتصال بالإنترنت. تحقق من الشبكة وحاول مرة أخرى.';
    }
    if (text.contains('لا توجد جمعية') || text.contains('جمعية نشطة')) {
      return 'لا توجد جمعية نشطة مرتبطة بهذا الحساب.';
    }
    if (text.contains('accepted') || text.contains('حالة الطلب')) {
      return 'لا يمكن تعيين المندوب لأن حالة الطلب تغيرت. حدّث الصفحة وحاول مرة أخرى.';
    }
    if (text.contains('كود') || text.contains('token')) {
      return 'كود الاستلام غير صحيح أو منتهي.';
    }
    if (text.contains('التبرع غير موجود') || text.contains('request')) {
      return 'تعذر العثور على التبرع. حدّث الصفحة وحاول مرة أخرى.';
    }
    if (text.contains('6 أرقام') || text.contains('6')) {
      return 'كود المتطوع يجب أن يكون 6 أرقام.';
    }
    return 'حدث خطأ غير متوقع. حاول مرة أخرى.';
  }

  void _message(String text, {bool error = false}) {
    if (!mounted) return;
    if (error) {
      CharityActionFeedback.showError(context, text);
    } else {
      CharityActionFeedback.showSuccess(context, text);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _background,
        appBar: AppBar(
          backgroundColor: _background,
          foregroundColor: _deepGreen,
          elevation: 0,
          title: const Text('لوحة التبرعات',
              style: TextStyle(fontWeight: FontWeight.w900)),
          actions: [
            IconButton(
                onPressed: _refresh,
                icon: const Icon(Icons.refresh_rounded),
                tooltip: 'تحديث'),
            IconButton(
                onPressed: _logout,
                icon: const Icon(Icons.logout_rounded),
                tooltip: 'تسجيل الخروج'),
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
            final all = snapshot.data ?? <Map<String, dynamic>>[];
            final rows = all.where(_matches).toList();
            return RefreshIndicator(
              color: _green,
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics()),
                padding: const EdgeInsets.fromLTRB(18, 6, 18, 32),
                children: [
                  _hero(all),
                  const SizedBox(height: 18),
                  _stats(all),
                  const SizedBox(height: 20),
                  _sectionTitle('طلبات التبرع', '${rows.length} طلب'),
                  const SizedBox(height: 10),
                  _filters(),
                  const SizedBox(height: 14),
                  if (rows.isEmpty)
                    _emptyState('لا توجد تبرعات في هذا القسم',
                        Icons.volunteer_activism_outlined)
                  else
                    ...rows.map(_card),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _hero(List<Map<String, dynamic>> rows) => Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Color(0xFF087A52), Color(0xFF27B47E)],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
                color: _green.withAlpha(45),
                blurRadius: 20,
                offset: const Offset(0, 10))
          ],
        ),
        child: Row(children: [
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                const Text('أثرُك يبدأ من هنا',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 23,
                        fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                Text('${rows.length} تبرع مباشر يحتاج إلى متابعة',
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 18),
                Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                        color: Colors.white.withAlpha(35),
                        borderRadius: BorderRadius.circular(30)),
                    child: const Text('راجع كل خطوة حتى يصل التبرع بأمان',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 12))),
              ])),
          const SizedBox(width: 12),
          Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                  color: Colors.white.withAlpha(35), shape: BoxShape.circle),
              child: const Icon(Icons.volunteer_activism_rounded,
                  color: Colors.white, size: 34)),
        ]),
      );

  Widget _stats(List<Map<String, dynamic>> rows) {
    int count(String status) =>
        rows.where((r) => r['status']?.toString() == status).length;
    return Row(children: [
      Expanded(
          child: _statCard('الجديدة', count('pending').toString(),
              Icons.mark_email_unread_rounded, const Color(0xFFFFA62B))),
      const SizedBox(width: 10),
      Expanded(
          child: _statCard(
              'قيد التنفيذ',
              (count('accepted') +
                      count('volunteer_needed') +
                      count('donor_ready') +
                      count('volunteer_assigned') +
                      count('picked_up_from_donor') +
                      count('in_transit'))
                  .toString(),
              Icons.route_rounded,
              const Color(0xFF3E83C5))),
      const SizedBox(width: 10),
      Expanded(
          child: _statCard('مكتملة', count('completed').toString(),
              Icons.check_circle_rounded, _green)),
    ]);
  }

  Widget _statCard(String label, String value, IconData icon, Color color) =>
      Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE1ECE6))),
          child: Column(children: [
            Icon(icon, color: color, size: 23),
            const SizedBox(height: 8),
            Text(value,
                style: const TextStyle(
                    color: _deepGreen,
                    fontSize: 21,
                    fontWeight: FontWeight.w900)),
            const SizedBox(height: 2),
            Text(label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 10,
                    fontWeight: FontWeight.w700))
          ]));

  Widget _sectionTitle(String title, String count) =>
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(title,
            style: const TextStyle(
                color: _deepGreen, fontSize: 20, fontWeight: FontWeight.w900)),
        Text(count,
            style: const TextStyle(
                color: _green, fontSize: 12, fontWeight: FontWeight.w800))
      ]);

  Widget _filters() {
    const filters = {
      'all': 'الكل',
      'pending': 'جديد',
      'accepted': 'مقبول',
      'volunteer_needed': 'مفتوح للمتطوعين',
      'donor_ready': 'المتبرع جاهز',
      'volunteer_assigned': 'المندوب أُرسل',
      'picked_up_from_donor': 'تم الاستلام',
      'in_transit': 'في الطريق',
      'completed': 'مكتمل'
    };
    return SizedBox(
        height: 38,
        child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: filters.length,
            separatorBuilder: (_, __) => const SizedBox(width: 7),
            itemBuilder: (_, i) {
              final key = filters.keys.elementAt(i);
              final selected = _filter == key;
              final activeColor = key == 'volunteer_needed' ? _purple : _green;

              return FilterChip(
                  selected: selected,
                  onSelected: (_) => setState(() => _filter = key),
                  label: Text(filters[key]!),
                  selectedColor:
                      key == 'volunteer_needed' ? _purple.withAlpha(25) : _mint,
                  backgroundColor: Colors.white,
                  checkmarkColor: activeColor,
                  labelStyle: TextStyle(
                      color: selected ? activeColor : _deepGreen,
                      fontSize: 11,
                      fontWeight: FontWeight.w800),
                  side: BorderSide(
                      color: selected ? activeColor : const Color(0xFFE1ECE6)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24)));
            }));
  }

  bool _matches(Map<String, dynamic> row) =>
      _filter == 'all' || row['status']?.toString() == _filter;

  Widget _card(Map<String, dynamic> row) {
    final id = row['id']?.toString() ?? '';
    final status = row['status']?.toString() ?? 'pending';
    final deliveryType =
        row['delivery_type']?.toString() ?? 'charity_volunteer';
    final isIndependent = deliveryType == 'independent_volunteer';

    final user = row['users'] is Map
        ? Map<String, dynamic>.from(row['users'] as Map)
        : <String, dynamic>{};
    final images = _imageUrls(row);
    final heroImage = images.isNotEmpty ? images.first : null;
    final extraImages = images.length > 1 ? images.sublist(1) : const [];
    final busy = _busyId == id;
    final volunteerName = row['volunteer_name']?.toString().trim() ?? '';
    final volunteerPhone = row['volunteer_phone']?.toString().trim() ?? '';

    return InkWell(
      onTap: () async {
        final changed = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) => CharityPersonDonationDetailsPage(donation: row),
          ),
        );
        if (changed == true && mounted) await _refresh();
      },
      borderRadius: BorderRadius.circular(24),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFE0EBE5)),
            boxShadow: [
              BoxShadow(
                  color: _deepGreen.withAlpha(18),
                  blurRadius: 20,
                  offset: const Offset(0, 10))
            ]),
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            height: 170,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                heroImage == null
                    ? const ColoredBox(
                        color: _mint,
                        child: Icon(Icons.volunteer_activism_rounded,
                            color: _green, size: 46),
                      )
                    : Image.network(
                        heroImage,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const ColoredBox(
                            color: _mint,
                            child: Icon(Icons.image_not_supported_outlined,
                                color: _green, size: 40)),
                      ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0.4, 1],
                        colors: [
                          Colors.transparent,
                          Colors.black.withAlpha(190),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: _statusPill(status),
                ),
                Positioned(
                  top: 12,
                  left: 12,
                  child: _deliveryBadge(isIndependent),
                ),
                Positioned(
                  left: 14,
                  right: 14,
                  bottom: 12,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        row['title']?.toString() ?? 'تبرع مباشر',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        user['name']?.toString() ?? 'متبرع غير معروف',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withAlpha(215),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (extraImages.isNotEmpty) ...[
                  _donationImages(extraImages.cast<String>()),
                  const SizedBox(height: 12),
                ],
                Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: const Color(0xFFF8FBF9),
                        borderRadius: BorderRadius.circular(16)),
                    child: Row(children: [
                      const Icon(Icons.person_outline_rounded,
                          color: _green, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(
                              '${user['name'] ?? 'متبرع غير معروف'}\n${user['phone'] ?? row['donor_phone'] ?? 'رقم غير متاح'}',
                              style: const TextStyle(
                                  color: _deepGreen,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  height: 1.5))),
                      Text('الكمية ${row['quantity'] ?? 1}',
                          style: const TextStyle(
                              color: _green,
                              fontSize: 11,
                              fontWeight: FontWeight.w900))
                    ])),
                if (volunteerName.isNotEmpty || volunteerPhone.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isIndependent
                          ? _purple.withAlpha(15)
                          : const Color(0xFFEFF8F3),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: isIndependent
                              ? _purple.withAlpha(50)
                              : const Color(0xFFCBE6D5)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isIndependent
                              ? Icons.person_rounded
                              : Icons.badge_outlined,
                          color: isIndependent ? _purple : _green,
                          size: 22,
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            '${isIndependent ? 'متطوع مستقل' : (row['volunteer_type'] == 'app_user' ? 'متطوع' : 'مندوب الجمعية')}\n${volunteerName.isEmpty ? 'الاسم غير مسجل' : volunteerName}${volunteerPhone.isEmpty ? '' : '\n$volunteerPhone'}',
                            style: TextStyle(
                                color: isIndependent ? _purple : _deepGreen,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                height: 1.45),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 15),
                _timeline(status),
                if (busy)
                  const Padding(
                      padding: EdgeInsets.only(top: 14),
                      child: LinearProgressIndicator(color: _green)),
                if (!busy) ...[
                  const SizedBox(height: 14),
                  _buildActions(row, status),
                ],
              ],
            ),
          ),
        ]),
      ),
    );
  }

  Widget _deliveryBadge(bool isIndependent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isIndependent
            ? _purple.withAlpha(220)
            : const Color(0xFF2F6DA5).withAlpha(220),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isIndependent ? Icons.people_alt_rounded : Icons.badge_outlined,
            color: Colors.white,
            size: 12,
          ),
          const SizedBox(width: 4),
          Text(
            isIndependent ? 'متطوعين' : 'مندوب',
            style: const TextStyle(
                color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(Map<String, dynamic> row, String status) {
    final id = row['id']?.toString() ?? '';
    final isRestaurant = row['source'] == 'restaurant_donation';
    final openToVolunteers = row['open_to_independent_volunteers'] == true;
    final deliveryType =
        row['delivery_type']?.toString() ?? 'charity_volunteer';
    final isIndependent = deliveryType == 'independent_volunteer';

    switch (status) {
      case 'pending':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _action(
              '✅ اقبل وعيّن مندوبي',
              Icons.badge_outlined,
              () => _acceptWithCharityVolunteer(id),
            ),
            const SizedBox(height: 8),
            _action(
              '🤝 اقبل واسيبه مفتوح للمتطوعين',
              Icons.groups_outlined,
              () => _acceptOpenForVolunteers(id),
              outlined: true,
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: () => _rejectDonation(id),
                icon: const Icon(Icons.close_rounded, size: 18),
                label: const Text('رفض التبرع'),
                style:
                    TextButton.styleFrom(foregroundColor: Colors.red.shade700),
              ),
            ),
          ],
        );

      case 'accepted':
        if (openToVolunteers) {
          return _notice(
              'التبرع متاح دلوقتي لأي متطوع مستقل. بانتظار حد يوافق يوصّله.');
        }
        return Column(
          children: [
            _notice(
                'بانتظار أن يضغط المتبرع «أنا جاهز لتسليم الحاجة». تقدر كمان ترسل مندوب من عندك.'),
            const SizedBox(height: 10),
            _action(
              'إرسال مندوب الجمعية',
              Icons.badge_outlined,
              () => _assignVolunteer(id),
              outlined: true,
            ),
          ],
        );

      case 'volunteer_needed':
        return Column(
          children: [
            _notice(
                'التبرع مفتوح للمتطوعين المستقلين. في انتظار حد يحجز التبرع. تقدر كمان ترسل مندوب من عندك.'),
            const SizedBox(height: 10),
            _action(
              'إرسال مندوب الجمعية',
              Icons.badge_outlined,
              () => _assignVolunteer(id),
              outlined: true,
            ),
          ],
        );

      case 'donor_ready':
        return _action(
          'إرسال مندوب الجمعية',
          Icons.badge_outlined,
          () => _assignVolunteer(id),
        );

      case 'volunteer_assigned':
        return Column(
          children: [
            _notice(isIndependent
                ? 'المتطوع في الطريق. عند وصوله، اطلب منه كود المتبرع وأدخله هنا.'
                : 'تم إرسال المندوب. عند عودته بالكود، أدخل الكود هنا للتحقق من استلام التبرع.'),
            const SizedBox(height: 10),
            _action(
              'إدخال كود المتبرع والتحقق',
              Icons.verified_user_outlined,
              () => _verifyExternalPickup(id),
            ),
          ],
        );

      case 'picked_up_from_donor':
        return _action(
          'التبرع في الطريق',
          Icons.local_shipping_outlined,
          () => _status(id, 'in_transit', isRestaurantDonation: isRestaurant),
        );

      case 'in_transit':
        return Column(
          children: [
            _notice(
                'المندوب في الطريق للجمعية. عندما يصل، اطلب منه كود المتطوع وأدخله هنا لتأكيد وصول التبرع.'),
            const SizedBox(height: 10),
            _action(
              'إدخال كود المتطوع والتحقق',
              Icons.person_pin_rounded,
              () => _verifyVolunteerCode(row),
            ),
          ],
        );

      case 'completed':
        return _notice('تم تأكيد وصول التبرع للجمعية بنجاح ✅');

      case 'rejected':
        return _notice('تم رفض هذا التبرع.');

      case 'cancelled':
        return _notice('تم إلغاء هذا التبرع من المتبرع.');

      default:
        return const SizedBox.shrink();
    }
  }

  List<String> _imageUrls(Map<String, dynamic> row) {
    final raw = row['images'];
    if (raw is! List) return const [];
    return raw
        .map((value) => value.toString())
        .where((url) => url.startsWith('http'))
        .toList();
  }

  Widget _donationImages(List<String> urls) => SizedBox(
        height: 90,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: urls.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, index) => ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.network(
              urls[index],
              width: 110,
              height: 90,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                  width: 110,
                  height: 90,
                  color: const Color(0xFFE8F1EC),
                  child:
                      const Icon(Icons.broken_image_outlined, color: _green)),
            ),
          ),
        ),
      );

  Widget _action(String text, IconData icon, VoidCallback onPressed,
          {bool outlined = false}) =>
      SizedBox(
          width: double.infinity,
          child: outlined
              ? OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                      foregroundColor: _green,
                      side: const BorderSide(color: _green),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15))),
                  onPressed: onPressed,
                  icon: Icon(icon, size: 19),
                  label: Text(text,
                      style: const TextStyle(fontWeight: FontWeight.w800)))
              : FilledButton.icon(
                  style: FilledButton.styleFrom(
                      backgroundColor: _green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15))),
                  onPressed: onPressed,
                  icon: Icon(icon, size: 19),
                  label: Text(text,
                      style: const TextStyle(fontWeight: FontWeight.w800))));

  Widget _notice(String text) => Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: const Color(0xFFFFF7E3),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: const Color(0xFFFFE1A6))),
      child: Row(children: [
        const Icon(Icons.info_outline_rounded,
            color: Color(0xFFB7791F), size: 21),
        const SizedBox(width: 8),
        Expanded(
            child: Text(text,
                style: const TextStyle(
                    color: Color(0xFF805B1B),
                    fontSize: 12,
                    fontWeight: FontWeight.w700)))
      ]));

  Widget _statusPill(String status) {
    final data = _statusData(status);
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
            color: data.$2, borderRadius: BorderRadius.circular(20)),
        child: Text(data.$1,
            style: TextStyle(
                color: data.$3, fontSize: 10, fontWeight: FontWeight.w900)));
  }

  (String, Color, Color) _statusData(String status) =>
      {
        'pending': (
          'في انتظار القبول',
          const Color(0xFFFFF1D8),
          const Color(0xFF9A6711)
        ),
        'accepted': (
          'تم القبول — بانتظار جاهزية المتبرع',
          const Color(0xFFE5F2FF),
          const Color(0xFF2F6DA5)
        ),
        'volunteer_needed': (
          'مفتوح للمتطوعين',
          const Color(0xFFECE8FF),
          const Color(0xFF6651B5)
        ),
        'donor_ready': (
          'المتبرع جاهز',
          const Color(0xFFE5F2FF),
          const Color(0xFF2F6DA5)
        ),
        'volunteer_assigned': (
          'تم إرسال المندوب',
          const Color(0xFFECE8FF),
          const Color(0xFF6651B5)
        ),
        'ready_for_pickup': (
          'جاهز للاستلام',
          const Color(0xFFFFF1D8),
          const Color(0xFF9A6711)
        ),
        'picked_up_from_donor': (
          'استلمه المتطوع',
          const Color(0xFFE5F2FF),
          const Color(0xFF2F6DA5)
        ),
        'in_transit': (
          'في الطريق',
          const Color(0xFFE5F2FF),
          const Color(0xFF2F6DA5)
        ),
        'completed': ('اكتمل بنجاح', const Color(0xFFE3F7EC), _green),
        'rejected': ('مرفوض', const Color(0xFFFBE4E4), const Color(0xFFB54747)),
        'cancelled': ('ملغي', const Color(0xFFF0F1F0), Colors.black54)
      }[status] ??
      ('حالة غير معروفة', const Color(0xFFF0F1F0), Colors.black54);

  Widget _timeline(String status) {
    const stages = [
      'pending',
      'accepted',
      'donor_ready',
      'volunteer_assigned',
      'picked_up_from_donor',
      'in_transit',
      'completed'
    ];

    final effectiveStatus = status == 'volunteer_needed' ? 'accepted' : status;
    final current = stages.indexOf(effectiveStatus);

    return SizedBox(
      height: 55,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: List.generate(stages.length, (index) {
            final done = current >= index && current >= 0;
            return Row(
              children: [
                if (index > 0)
                  SizedBox(
                    width: 32,
                    child: Container(
                      height: 3,
                      color: done ? _green : const Color(0xFFE1E8E4),
                    ),
                  ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: done ? _green : const Color(0xFFE1E8E4),
                        shape: BoxShape.circle,
                      ),
                      child: done
                          ? const Icon(
                              Icons.check_rounded,
                              size: 12,
                              color: Colors.white,
                            )
                          : null,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _stageLabel(stages[index]),
                      style: TextStyle(
                        fontSize: 9,
                        color: done ? _green : Colors.black45,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            );
          }),
        ),
      ),
    );
  }

  String _stageLabel(String stage) =>
      {
        'pending': 'طلب',
        'accepted': 'قبول',
        'donor_ready': 'جاهز',
        'volunteer_assigned': 'مندوب',
        'picked_up_from_donor': 'استلام',
        'in_transit': 'طريق',
        'completed': 'وصل',
      }[stage] ??
      '';

  Widget _emptyState(String text, IconData icon) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 70),
      child: Column(children: [
        Icon(icon, color: _green, size: 54),
        const SizedBox(height: 15),
        Text(text,
            style: const TextStyle(
                color: _deepGreen, fontSize: 16, fontWeight: FontWeight.w800))
      ]));
}

// ═══════════════════════════════════════════════════════════════
// VOLUNTEER ASSIGNMENT MODEL
// ═══════════════════════════════════════════════════════════════

class _VolunteerAssignment {
  final String? id;
  final String name;
  final String phone;

  const _VolunteerAssignment({
    required this.id,
    required this.name,
    required this.phone,
  });
}

// ═══════════════════════════════════════════════════════════════
// VOLUNTEER BOTTOM SHEET (بدل Dialog)
// ═══════════════════════════════════════════════════════════════

class _VolunteerBottomSheet extends StatefulWidget {
  final List<Map<String, dynamic>> volunteers;

  const _VolunteerBottomSheet({required this.volunteers});

  @override
  State<_VolunteerBottomSheet> createState() => _VolunteerBottomSheetState();
}

class _VolunteerBottomSheetState extends State<_VolunteerBottomSheet> {
  static const _green = Color(0xFF087A52);
  static const _mint = Color(0xFFE9F7F0);
  static const _deepGreen = Color(0xFF123D31);

  bool _fromCharity = true;
  String? _selectedId;
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_fromCharity) {
      if (_selectedId == null) return;
      final selected = widget.volunteers.firstWhere(
        (v) => v['id']?.toString() == _selectedId,
      );
      Navigator.pop(
        context,
        _VolunteerAssignment(
          id: selected['id']?.toString(),
          name: selected['name']?.toString().trim() ?? '',
          phone: selected['phone']?.toString().trim() ?? '',
        ),
      );
    } else {
      if (_nameController.text.trim().isEmpty ||
          _phoneController.text.trim().isEmpty) {
        return;
      }
      Navigator.pop(
        context,
        _VolunteerAssignment(
          id: null,
          name: _nameController.text.trim(),
          phone: _phoneController.text.trim(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        margin: const EdgeInsets.only(top: 60),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottomInset),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Title
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.badge_outlined,
                        color: _green,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'تعيين مندوب للتبرع',
                        style: TextStyle(
                          color: _deepGreen,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                      color: Colors.grey,
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Segmented Button
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment<bool>(
                      value: true,
                      label: Text('من الجمعية'),
                      icon: Icon(Icons.groups_outlined, size: 18),
                    ),
                    ButtonSegment<bool>(
                      value: false,
                      label: Text('خارجي'),
                      icon: Icon(Icons.person_add_alt_1, size: 18),
                    ),
                  ],
                  selected: {_fromCharity},
                  onSelectionChanged: (values) {
                    setState(() {
                      _fromCharity = values.first;
                      _selectedId = null;
                      _nameController.clear();
                      _phoneController.clear();
                    });
                  },
                  style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.selected)) {
                        return _mint;
                      }
                      return Colors.white;
                    }),
                  ),
                ),
                const SizedBox(height: 20),

                // Content
                if (_fromCharity)
                  widget.volunteers.isEmpty
                      ? Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Column(
                            children: [
                              Icon(
                                Icons.person_off_outlined,
                                color: Colors.grey,
                                size: 32,
                              ),
                              SizedBox(height: 8),
                              Text(
                                'لا يوجد مندوبون نشطون',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        )
                      : DropdownButtonFormField<String>(
                          initialValue: _selectedId,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: 'اختر المندوب',
                            prefixIcon: const Icon(Icons.badge_outlined),
                            filled: true,
                            fillColor: const Color(0xFFF8FBF9),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: Color(0xFFE0EBE5),
                              ),
                            ),
                          ),
                          items: widget.volunteers.map((item) {
                            final itemId = item['id']?.toString() ?? '';
                            final itemName =
                                item['name']?.toString() ?? 'مندوب';
                            final itemPhone = item['phone']?.toString() ?? '';
                            return DropdownMenuItem<String>(
                              value: itemId,
                              child: Text(
                                '$itemName${itemPhone.isEmpty ? '' : ' — $itemPhone'}',
                              ),
                            );
                          }).toList(),
                          onChanged: (value) =>
                              setState(() => _selectedId = value),
                        )
                else ...[
                  TextField(
                    controller: _nameController,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: 'اسم المندوب',
                      prefixIcon: const Icon(Icons.person_outline),
                      filled: true,
                      fillColor: const Color(0xFFF8FBF9),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                          color: Color(0xFFE0EBE5),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'رقم الهاتف',
                      prefixIcon: const Icon(Icons.phone_outlined),
                      filled: true,
                      fillColor: const Color(0xFFF8FBF9),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                          color: Color(0xFFE0EBE5),
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),

                // Actions
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _deepGreen,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          'إلغاء',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: FilledButton(
                        onPressed: _submit,
                        style: FilledButton.styleFrom(
                          backgroundColor: _green,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          'تعيين المندوب',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
