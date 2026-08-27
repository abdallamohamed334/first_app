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

  @override
  void initState() {
    super.initState();
    _future = _repository.getCharityDonations();
  }

  Future<void> _refresh() async {
    final next = _repository.getCharityDonations();
    if (!mounted) return;

    // مهم: setState يجب أن يحتوي على تحديث متزامن فقط، وليس await أو Future.
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
    // لا نتخلص من الـController هنا؛ نافذة الـDialog قد تكون ما زالت في مرحلة الإزالة.
    // التخلص المبكر يسبب TextEditingController was used after being disposed.
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

      if (!mounted) return;
      final name = TextEditingController();
      final phone = TextEditingController();
      final assignment = await showDialog<_InstitutionVolunteerAssignment>(
        barrierDismissible: false,
        context: context,
        builder: (dialogContext) => _InstitutionVolunteerDialog(
          volunteers: rawVolunteers
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList(growable: false),
          nameController: name,
          phoneController: phone,
        ),
      );
      final externalName = name.text.trim();
      final externalPhone = phone.text.trim();
      name.dispose();
      phone.dispose();

      if (assignment == null || !mounted) return;
      await SupabaseService().client.rpc(
        'institution_assign_charity_volunteer',
        params: {
          'p_donation_id': id.trim(),
          'p_volunteer_id': assignment.id,
          'p_volunteer_name':
              assignment.id == null ? externalName : assignment.name,
          'p_volunteer_phone':
              assignment.id == null ? externalPhone : assignment.phone,
        },
      );
      await _refresh();
      if (mounted) _message('تم تعيين المندوب بنجاح');
    } catch (e) {
      if (mounted) _message(_friendlyError(e), error: true);
    } finally {
      _assignmentDialogOpen = false;
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
                onPressed: () {
                  _refresh();
                },
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
              return FilterChip(
                  selected: selected,
                  onSelected: (_) => setState(() => _filter = key),
                  label: Text(filters[key]!),
                  selectedColor: _mint,
                  backgroundColor: Colors.white,
                  checkmarkColor: _green,
                  labelStyle: TextStyle(
                      color: selected ? _green : _deepGreen,
                      fontSize: 11,
                      fontWeight: FontWeight.w800),
                  side: BorderSide(
                      color: selected ? _green : const Color(0xFFE1ECE6)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24)));
            }));
  }

  bool _matches(Map<String, dynamic> row) =>
      _filter == 'all' || row['status']?.toString() == _filter;

  Widget _card(Map<String, dynamic> row) {
    final id = row['id']?.toString() ?? '';
    final status = row['status']?.toString() ?? 'pending';
    final user = row['users'] is Map
        ? Map<String, dynamic>.from(row['users'] as Map)
        : <String, dynamic>{};
    final imageList = row['images'] is List
        ? List<String>.from((row['images'] as List).map((e) => e.toString()))
        : <String>[];
    final image = imageList.isNotEmpty ? imageList.first : null;
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
      borderRadius: BorderRadius.circular(23),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(23),
            border: Border.all(color: const Color(0xFFE0EBE5)),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withAlpha(8),
                  blurRadius: 13,
                  offset: const Offset(0, 5))
            ]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                    width: 72,
                    height: 72,
                    child: image == null
                        ? const ColoredBox(
                            color: _mint,
                            child: Icon(Icons.inventory_2_rounded,
                                color: _green, size: 30))
                        : Image.network(image,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const ColoredBox(
                                color: _mint,
                                child: Icon(Icons.image_not_supported_outlined,
                                    color: _green))))),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(row['title']?.toString() ?? 'تبرع مباشر',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: _deepGreen,
                          fontSize: 16,
                          fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  _statusPill(status)
                ])),
          ]),
          if (_imageUrls(row).isNotEmpty) ...[
            const SizedBox(height: 12),
            _donationImages(_imageUrls(row)),
          ],
          const SizedBox(height: 14),
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
                color: const Color(0xFFEFF8F3),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFCBE6D5)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.badge_outlined, color: _green, size: 22),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      'مندوب الجمعية\n${volunteerName.isEmpty ? 'الاسم غير مسجل' : volunteerName}${volunteerPhone.isEmpty ? '' : '\n$volunteerPhone'}',
                      style: const TextStyle(
                          color: _deepGreen,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          height: 1.45),
                    ),
                  ),
                  const Text('خارجي',
                      style: TextStyle(
                          color: _green,
                          fontSize: 11,
                          fontWeight: FontWeight.w900)),
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
            if (status == 'pending')
              _action(
                  'قبول التبرع',
                  Icons.check_rounded,
                  () => _status(id, 'accepted',
                      isRestaurantDonation:
                          row['source'] == 'restaurant_donation')),
            if (status == 'accepted')
              _notice('بانتظار أن يضغط المتبرع «أنا جاهز لتسليم الحاجة».'),
            if (status == 'donor_ready')
              _action('إرسال مندوب الجمعية', Icons.badge_outlined,
                  () => _assignVolunteer(id)),
            if (status == 'volunteer_assigned') ...[
              _notice(
                  'تم إرسال المندوب. عند عودته بالكود، أدخل الكود هنا للتحقق من استلام التبرع.'),
              const SizedBox(height: 10),
              _action('إدخال كود المتبرع والتحقق', Icons.verified_user_outlined,
                  () => _verifyExternalPickup(id)),
            ],
            if (status == 'picked_up_from_donor')
              _action(
                  'التبرع في الطريق',
                  Icons.local_shipping_outlined,
                  () => _status(id, 'in_transit',
                      isRestaurantDonation:
                          row['source'] == 'restaurant_donation')),
            if (status == 'in_transit')
              _action(
                  'تأكيد وصول التبرع للجمعية',
                  Icons.task_alt_rounded,
                  () => _status(id, 'completed',
                      isRestaurantDonation:
                          row['source'] == 'restaurant_donation')),
          ],
        ]),
      ),
    );
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
        height: 118,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: urls.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, index) => ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.network(
              urls[index],
              width: 145,
              height: 118,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                  width: 145,
                  height: 118,
                  color: const Color(0xFFE8F1EC),
                  child:
                      const Icon(Icons.broken_image_outlined, color: _green)),
            ),
          ),
        ),
      );

  Widget _action(String text, IconData icon, VoidCallback onPressed) =>
      SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
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
        const Icon(Icons.qr_code_scanner_rounded,
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
    final current = stages.indexOf(status);
    return SizedBox(
      height: 48,
      child: Row(
        children: List.generate(stages.length, (index) {
          final done = current >= index && current >= 0;
          return Expanded(
            child: Row(
              children: [
                Expanded(
                    child: Container(
                        height: 4,
                        decoration: BoxDecoration(
                            color: index == 0
                                ? Colors.transparent
                                : (done ? _green : const Color(0xFFE1E8E4)),
                            borderRadius: BorderRadius.circular(10)))),
                Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Container(
                      width: 15,
                      height: 15,
                      decoration: BoxDecoration(
                          color: done ? _green : const Color(0xFFE1E8E4),
                          shape: BoxShape.circle)),
                  const SizedBox(height: 4),
                  Text(_stageLabel(stages[index]),
                      style: TextStyle(
                          fontSize: 7,
                          color: done ? _green : Colors.black45,
                          fontWeight: FontWeight.w700))
                ]),
              ],
            ),
          );
        }),
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

class _InstitutionVolunteerAssignment {
  final String? id;
  final String name;
  final String phone;

  const _InstitutionVolunteerAssignment({
    required this.id,
    required this.name,
    required this.phone,
  });
}

class _InstitutionVolunteerDialog extends StatefulWidget {
  final List<Map<String, dynamic>> volunteers;
  final TextEditingController nameController;
  final TextEditingController phoneController;

  const _InstitutionVolunteerDialog({
    required this.volunteers,
    required this.nameController,
    required this.phoneController,
  });

  @override
  State<_InstitutionVolunteerDialog> createState() =>
      _InstitutionVolunteerDialogState();
}

class _InstitutionVolunteerDialogState
    extends State<_InstitutionVolunteerDialog> {
  bool _fromCharity = true;
  String? _selectedId;

  @override
  Widget build(BuildContext context) {
    final selected = widget.volunteers.where(
      (item) => item['id']?.toString() == _selectedId,
    );
    final volunteer = selected.isEmpty ? null : selected.first;

    return AlertDialog(
      title: const Text('تعيين مندوب التبرع'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('اختاري مندوبًا من الجمعية أو أضيفي مندوبًا خارجيًا.'),
            const SizedBox(height: 12),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment<bool>(
                  value: true,
                  label: Text('من الجمعية'),
                  icon: Icon(Icons.groups_outlined),
                ),
                ButtonSegment<bool>(
                  value: false,
                  label: Text('خارجي'),
                  icon: Icon(Icons.person_add_alt_1),
                ),
              ],
              selected: {_fromCharity},
              onSelectionChanged: (values) {
                setState(() {
                  _fromCharity = values.first;
                  _selectedId = null;
                  widget.nameController.clear();
                  widget.phoneController.clear();
                });
              },
            ),
            const SizedBox(height: 14),
            if (_fromCharity)
              widget.volunteers.isEmpty
                  ? const Text('لا يوجد مندوبون نشطون داخل الجمعية.')
                  : DropdownButtonFormField<String>(
                      value: _selectedId,
                      decoration: const InputDecoration(
                        labelText: 'اختيار مندوب الجمعية',
                        prefixIcon: Icon(Icons.badge_outlined),
                        border: OutlineInputBorder(),
                      ),
                      items: widget.volunteers.map((item) {
                        final itemId = item['id']?.toString() ?? '';
                        final itemName = item['name']?.toString() ?? 'مندوب';
                        final itemPhone = item['phone']?.toString() ?? '';
                        return DropdownMenuItem<String>(
                          value: itemId,
                          child: Text(
                            '$itemName${itemPhone.isEmpty ? '' : ' — $itemPhone'}',
                          ),
                        );
                      }).toList(),
                      onChanged: (value) => setState(() => _selectedId = value),
                    )
            else ...[
              TextField(
                controller: widget.nameController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'اسم المندوب الخارجي',
                  prefixIcon: Icon(Icons.person_outline),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: widget.phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'رقم هاتف المندوب الخارجي',
                  prefixIcon: Icon(Icons.phone_outlined),
                  border: OutlineInputBorder(),
                ),
              ),
            ],
            if (_fromCharity && volunteer != null) ...[
              const SizedBox(height: 10),
              Text(
                'سيتم تعيين: ${volunteer['name'] ?? 'مندوب الجمعية'}',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: () {
            if (_fromCharity) {
              if (volunteer == null) return;
              Navigator.pop(
                context,
                _InstitutionVolunteerAssignment(
                  id: volunteer['id']?.toString(),
                  name: volunteer['name']?.toString().trim() ?? '',
                  phone: volunteer['phone']?.toString().trim() ?? '',
                ),
              );
            } else {
              if (widget.nameController.text.trim().isEmpty ||
                  widget.phoneController.text.trim().isEmpty) return;
              Navigator.pop(
                context,
                const _InstitutionVolunteerAssignment(
                  id: null,
                  name: '',
                  phone: '',
                ),
              );
            }
          },
          child: const Text('تعيين المندوب'),
        ),
      ],
    );
  }
}
