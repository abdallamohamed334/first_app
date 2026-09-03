import 'package:flutter/material.dart';
import 'package:loqma/features/charity/data/repositories/charity_donation_repository_separate.dart';
import 'package:loqma/features/charity/presentation/pages/charity_action_feedback.dart';

/// صفحة تبرعات المطاعم للجمعية.
///
/// مهم: عمود status في restaurant_charity_donations مقيّد بـ CHECK constraint
/// يسمح فقط بالقيم: pending, accepted, rejected, volunteer_assigned,
/// picked_up, completed, cancelled, expired.
///
/// الخطوات الدقيقة (المطعم جاهز / المندوب تحرك / تم إنشاء الكود) لا تُخزَّن
/// كحالات منفصلة، بل كأعمدة توقيت على نفس الصف:
///   restaurant_ready_at, volunteer_departed_at, code_generated_at,
///   pickup_verified_at, arrived_at
/// والواجهة هنا بتستنتج الخطوة الحالية من وجود/غياب التوقيتات دي مع status.
class CharityRestaurantDonationsPage extends StatefulWidget {
  const CharityRestaurantDonationsPage({super.key});

  @override
  State<CharityRestaurantDonationsPage> createState() =>
      _CharityRestaurantDonationsPageState();
}

class _CharityRestaurantDonationsPageState
    extends State<CharityRestaurantDonationsPage> {
  static const primary = Color(0xFF001E15);
  static const green = Color(0xFF006C48);
  static const background = Color(0xFFF8FAFA);
  static const muted = Color(0xFF62786D);
  static const mint = Color(0xFFE9F7F0);

  final _repository = SeparateCharityDonationRepository();
  late Future<List<Map<String, dynamic>>> _future;
  String? _busyId;

  @override
  void initState() {
    super.initState();
    _future = _repository.getRestaurantDonations();
  }

  Future<void> _refresh() async {
    final next = _repository.getRestaurantDonations();
    if (!mounted) return;
    setState(() => _future = next);
    try {
      await next;
    } catch (error) {
      if (mounted) _message(_friendlyError(error), error: true);
    }
  }

  // ==================== منطق الحالة/الخطوة ====================

  /// خطوة داخلية مشتقة من status + التوقيتات، مستخدمة فقط للعرض
  /// (الـ timeline والأزرار). القيمة الوحيدة المخزنة فعليًا في القاعدة هي
  /// status، والخطوات دي بس تفسير لها.
  String _step(Map<String, dynamic> row) {
    final status = row['status']?.toString() ?? 'pending';
    if (status == 'pending') return 'pending';
    if (status == 'rejected') return 'rejected';
    if (status == 'cancelled') return 'cancelled';
    if (status == 'expired') return 'expired';
    if (status == 'completed') return 'completed';
    if (status == 'picked_up') return 'picked_up';
    if (status == 'accepted') return 'accepted';
    // status == 'volunteer_assigned' يتفرّع حسب التوقيتات
    if (row['volunteer_departed_at'] != null) return 'volunteer_departed';
    if (row['restaurant_ready_at'] != null) return 'restaurant_ready';
    return 'volunteer_assigned';
  }

  Future<void> _accept(String id) => _run(id, () async {
        await _repository.updateStatus(
          requestId: id,
          status: 'accepted',
          isRestaurantDonation: true,
        );
      }, 'تم قبول التبرع من المطعم');

  Future<void> _reject(String id) => _run(id, () async {
        await _repository.updateStatus(
          requestId: id,
          status: 'rejected',
          isRestaurantDonation: true,
        );
      }, 'تم رفض التبرع');

  Future<void> _assignVolunteer(Map<String, dynamic> row) async {
    final id = row['id']?.toString() ?? '';
    final volunteers = await _repository.getMyCharityVolunteers();
    if (!mounted) return;
    final active = volunteers
        .where((v) => v['status']?.toString() == 'active')
        .toList(growable: false);

    if (active.isEmpty) {
      _message('لا يوجد مندوبون نشطون داخل الجمعية. أضف مندوبًا أولًا.',
          error: true);
      return;
    }

    final selectedId = await showDialog<String>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('اختيار مندوب الجمعية'),
        children: active
            .map((v) => SimpleDialogOption(
                  onPressed: () =>
                      Navigator.pop(dialogContext, v['id']?.toString()),
                  child: Text(
                    '${v['name'] ?? 'مندوب'}'
                    '${(v['phone']?.toString().isNotEmpty ?? false) ? ' — ${v['phone']}' : ''}',
                  ),
                ))
            .toList(),
      ),
    );
    if (selectedId == null || !mounted) return;

    await _run(id, () async {
      await _repository.assignRestaurantVolunteer(
        donationId: id,
        volunteerId: selectedId,
      );
    }, 'تم تعيين المندوب بنجاح');
  }

  Future<void> _markVolunteerDeparted(String id) => _run(id, () async {
        await _repository.markRestaurantDonationDeparted(id);
      }, 'تم تسجيل أن المندوب في الطريق للمطعم');

  Future<void> _generateAndShowCode(String id) async {
    setState(() => _busyId = id);
    try {
      final result = await _repository.generateRestaurantPickupCode(id);
      final code =
          result['code']?.toString() ?? result['pickup_code']?.toString() ?? '';
      await _refresh();
      if (!mounted) return;
      if (code.isEmpty) {
        _message('تم إنشاء الكود لكن تعذر عرضه، حدّث الصفحة وحاول تاني',
            error: true);
        return;
      }
      await _showCodeDialog(code);
    } catch (error) {
      if (mounted) _message(_friendlyError(error), error: true);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _showCodeDialog(String code) {
    return showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('🔑 كود استلام التبرع'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('أعط هذا الكود لمندوبك ليقدمه للمطعم عند الاستلام'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: green.withAlpha(20),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: green.withAlpha(50)),
              ),
              child: SelectableText(
                code,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 4,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmPickup(String id) async {
    final controller = TextEditingController();
    final token = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تأكيد استلام التبرع من المطعم'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          maxLength: 6,
          decoration: const InputDecoration(
            labelText: 'كود الاستلام',
            hintText: 'الكود المكوّن من 6 أرقام',
            prefixIcon: Icon(Icons.qr_code_2_rounded),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء')),
          FilledButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, controller.text.trim()),
              child: const Text('تأكيد')),
        ],
      ),
    );
    controller.dispose();
    if (token == null || token.trim().isEmpty || !mounted) return;

    await _run(id, () async {
      await _repository.confirmRestaurantDonationPickup(
        donationId: id,
        token: token.trim(),
      );
    }, 'تم تأكيد استلام التبرع من المطعم');
  }

  Future<void> _confirmArrival(String id) => _run(id, () async {
        await _repository.confirmRestaurantDonationArrival(id);
      }, 'تم تسجيل وصول التبرع للجمعية بنجاح 🎉');

  Future<void> _run(
      String id, Future<void> Function() action, String successMessage) async {
    if (_busyId != null) return;
    setState(() => _busyId = id);
    try {
      await action();
      await _refresh();
      if (mounted) _message(successMessage);
    } catch (error) {
      if (mounted) _message(_friendlyError(error), error: true);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  String _friendlyError(Object error) {
    final raw = error.toString().toLowerCase();
    debugPrint('RESTAURANT_DONATIONS_PAGE_ERROR: $error');
    if (raw.contains('permission') ||
        raw.contains('row-level') ||
        raw.contains('42501')) {
      return 'ليس لديك صلاحية لتنفيذ هذه العملية بحساب الجمعية الحالي.';
    }
    if (raw.contains('check constraint') || raw.contains('status')) {
      return 'لا يمكن تنفيذ هذه الخطوة من الحالة الحالية. حدّث الصفحة وحاول مرة أخرى.';
    }
    if (raw.contains('code') || raw.contains('token') || raw.contains('كود')) {
      return 'كود الاستلام غير صحيح أو منتهي.';
    }
    if (raw.contains('network') ||
        raw.contains('socket') ||
        raw.contains('timeout')) {
      return 'تعذر الاتصال بالإنترنت. تحقق من الشبكة وحاول مرة أخرى.';
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

  // ==================== الواجهة ====================

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: background,
        appBar: AppBar(
          title: const Text('تبرعات المطاعم',
              style: TextStyle(fontWeight: FontWeight.w900)),
          backgroundColor: Colors.white,
          foregroundColor: primary,
          surfaceTintColor: Colors.white,
          actions: [
            IconButton(
                onPressed: _refresh, icon: const Icon(Icons.refresh_rounded)),
          ],
        ),
        body: FutureBuilder<List<Map<String, dynamic>>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                  child: CircularProgressIndicator(color: green));
            }
            if (snapshot.hasError) {
              return _errorState(_friendlyError(snapshot.error!));
            }
            final rows = snapshot.data ?? const <Map<String, dynamic>>[];
            if (rows.isEmpty) return _empty();
            return RefreshIndicator(
              color: green,
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics()),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
                children: [
                  _hero(rows),
                  const SizedBox(height: 16),
                  _stats(rows),
                  const SizedBox(height: 18),
                  ...rows.map(_donationCard),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _hero(List<Map<String, dynamic>> rows) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [primary, green],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft),
          borderRadius: BorderRadius.circular(26),
        ),
        child: Row(children: [
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                const Text('تبرعات المطاعم',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                Text('${rows.length} تبرع من المطاعم الشريكة',
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 13)),
              ])),
          Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                  color: Colors.white.withAlpha(35), shape: BoxShape.circle),
              child: const Icon(Icons.storefront_rounded,
                  color: Colors.white, size: 30)),
        ]),
      );

  Widget _stats(List<Map<String, dynamic>> rows) {
    int count(bool Function(Map<String, dynamic>) test) =>
        rows.where(test).length;
    final pending = count((r) => r['status']?.toString() == 'pending');
    final inProgress = count((r) => const {
          'accepted',
          'volunteer_assigned',
          'picked_up'
        }.contains(r['status']?.toString()));
    final done = count((r) => r['status']?.toString() == 'completed');
    return Row(children: [
      Expanded(child: _statCard('جديدة', '$pending', const Color(0xFFFFA62B))),
      const SizedBox(width: 10),
      Expanded(
          child:
              _statCard('قيد التنفيذ', '$inProgress', const Color(0xFF3E83C5))),
      const SizedBox(width: 10),
      Expanded(child: _statCard('مكتملة', '$done', green)),
    ]);
  }

  Widget _statCard(String label, String value, Color color) => Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE1ECE6))),
      child: Column(children: [
        Text(value,
            style: TextStyle(
                color: color, fontSize: 20, fontWeight: FontWeight.w900)),
        const SizedBox(height: 3),
        Text(label,
            style: const TextStyle(
                color: muted, fontSize: 11, fontWeight: FontWeight.w700)),
      ]));

  Widget _empty() => Center(
      child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.volunteer_activism_rounded,
                size: 64, color: green),
            const SizedBox(height: 14),
            const Text('لا توجد تبرعات مطاعم حتى الآن',
                style: TextStyle(
                    color: primary, fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 7),
            const Text('ستظهر هنا التبرعات الجديدة فور إرسالها من المطاعم.',
                textAlign: TextAlign.center, style: TextStyle(color: muted)),
          ])));

  Widget _errorState(String message) => Center(
      child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton.icon(
                onPressed: _refresh,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('إعادة المحاولة')),
          ])));

  Widget _donationCard(Map<String, dynamic> row) {
    final id = row['id']?.toString() ?? '';
    final step = _step(row);
    final busy = _busyId == id;
    final images = _imageUrls(row);
    final heroImage = images.isNotEmpty ? images.first : null;
    final title = row['title']?.toString().trim().isNotEmpty == true
        ? row['title'].toString()
        : 'تبرع من مطعم';
    final restaurant = (row['users'] is Map)
        ? Map<String, dynamic>.from(row['users'] as Map)
        : <String, dynamic>{};
    final restaurantName = restaurant['name']?.toString() ?? 'مطعم مشارك';
    final volunteerName = row['volunteer_name']?.toString().trim() ?? '';
    final volunteerPhone = row['volunteer_phone']?.toString().trim() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFE0EBE5))),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          height: 150,
          width: double.infinity,
          child: Stack(fit: StackFit.expand, children: [
            heroImage == null
                ? const ColoredBox(
                    color: mint,
                    child:
                        Icon(Icons.storefront_rounded, color: green, size: 42))
                : Image.network(heroImage,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const ColoredBox(
                        color: mint,
                        child: Icon(Icons.image_not_supported_outlined,
                            color: green))),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withAlpha(180)],
                  ),
                ),
              ),
            ),
            Positioned(top: 10, right: 10, child: _statusPill(step)),
            Positioned(
              left: 12,
              right: 12,
              bottom: 10,
              child: Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900)),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(14),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.storefront_rounded, color: green, size: 18),
              const SizedBox(width: 6),
              Expanded(
                  child: Text(restaurantName,
                      style: const TextStyle(
                          color: primary, fontWeight: FontWeight.w800))),
              Text('${row['quantity'] ?? 1} وحدة',
                  style: const TextStyle(
                      color: green, fontWeight: FontWeight.w800)),
            ]),
            if (volunteerName.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: mint,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(children: [
                  const Icon(Icons.badge_outlined, color: green, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'مندوب الجمعية: $volunteerName'
                      '${volunteerPhone.isEmpty ? '' : ' — $volunteerPhone'}',
                      style: const TextStyle(
                          color: primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ]),
              ),
            ],
            const SizedBox(height: 14),
            _timeline(step),
            const SizedBox(height: 14),
            if (busy)
              const LinearProgressIndicator(color: green)
            else
              _actionsFor(row, step),
          ]),
        ),
      ]),
    );
  }

  Widget _statusPill(String step) {
    final data = _stepData(step);
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
            color: data.$2, borderRadius: BorderRadius.circular(20)),
        child: Text(data.$1,
            style: TextStyle(
                color: data.$3, fontSize: 10, fontWeight: FontWeight.w900)));
  }

  (String, Color, Color) _stepData(String step) =>
      {
        'pending': (
          'في انتظار القبول',
          const Color(0xFFFFF1D8),
          const Color(0xFF9A6711)
        ),
        'accepted': (
          'بانتظار تعيين مندوب',
          const Color(0xFFE5F2FF),
          const Color(0xFF2F6DA5)
        ),
        'volunteer_assigned': (
          'تم تعيين مندوب',
          const Color(0xFFECE8FF),
          const Color(0xFF6651B5)
        ),
        'restaurant_ready': (
          'المطعم جاهز',
          const Color(0xFFFFF1D8),
          const Color(0xFF9A6711)
        ),
        'volunteer_departed': (
          'المندوب في الطريق',
          const Color(0xFFE5F2FF),
          const Color(0xFF2F6DA5)
        ),
        'picked_up': (
          'التبرع مع المندوب',
          const Color(0xFFE5F2FF),
          const Color(0xFF2F6DA5)
        ),
        'completed': ('اكتمل بنجاح', const Color(0xFFE3F7EC), green),
        'rejected': ('مرفوض', const Color(0xFFFBE4E4), const Color(0xFFB54747)),
        'cancelled': ('ملغي', const Color(0xFFF0F1F0), Colors.black54),
        'expired': ('منتهي', const Color(0xFFF0F1F0), Colors.black54),
      }[step] ??
      ('حالة غير معروفة', const Color(0xFFF0F1F0), Colors.black54);

  Widget _timeline(String step) {
    const steps = [
      'pending',
      'accepted',
      'volunteer_assigned',
      'restaurant_ready',
      'volunteer_departed',
      'picked_up',
      'completed',
    ];
    final current = steps.indexOf(step);
    return SizedBox(
      height: 46,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(steps.length, (index) {
            final done = current >= index && current >= 0;
            return Row(children: [
              if (index > 0)
                SizedBox(
                    width: 26,
                    child: Container(
                        height: 3,
                        color: done ? green : const Color(0xFFE1E8E4))),
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: done ? green : const Color(0xFFE1E8E4),
                  shape: BoxShape.circle,
                ),
              ),
            ]);
          }),
        ),
      ),
    );
  }

  Widget _actionsFor(Map<String, dynamic> row, String step) {
    final id = row['id']?.toString() ?? '';
    switch (step) {
      case 'pending':
        return Row(children: [
          Expanded(
              child: _actionButton(
                  'قبول', Icons.check_rounded, () => _accept(id), green)),
          const SizedBox(width: 8),
          Expanded(
              child: _actionButton(
                  'رفض', Icons.close_rounded, () => _reject(id), Colors.red)),
        ]);
      case 'accepted':
        return _actionButton('تعيين مندوب الجمعية', Icons.badge_outlined,
            () => _assignVolunteer(row), green);
      case 'volunteer_assigned':
        return _notice('بانتظار أن يؤكد المطعم جاهزية التبرع للتسليم.');
      case 'restaurant_ready':
        return _actionButton(
            'المندوب تحرك للمطعم',
            Icons.directions_run_rounded,
            () => _markVolunteerDeparted(id),
            green);
      case 'volunteer_departed':
        return row['code_generated_at'] == null
            ? _actionButton('إنشاء كود الاستلام', Icons.qr_code_rounded,
                () => _generateAndShowCode(id), green)
            : _actionButton('تأكيد استلام التبرع من المطعم',
                Icons.verified_user_outlined, () => _confirmPickup(id), green);
      case 'picked_up':
        return _actionButton('تأكيد وصول التبرع للجمعية',
            Icons.task_alt_rounded, () => _confirmArrival(id), green);
      case 'completed':
        return _notice('تم استلام التبرع وإغلاق العملية بنجاح 🎉');
      case 'rejected':
      case 'cancelled':
      case 'expired':
        return const SizedBox.shrink();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _actionButton(
          String label, IconData icon, VoidCallback onTap, Color color) =>
      SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: onTap,
          icon: Icon(icon, size: 18),
          label:
              Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
          style: FilledButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 13),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      );

  Widget _notice(String text) => Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: const Color(0xFFFFF7E3),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFFFE1A6))),
      child: Row(children: [
        const Icon(Icons.hourglass_top_rounded,
            color: Color(0xFFB7791F), size: 19),
        const SizedBox(width: 8),
        Expanded(
            child: Text(text,
                style: const TextStyle(
                    color: Color(0xFF805B1B),
                    fontSize: 12,
                    fontWeight: FontWeight.w700))),
      ]));

  List<String> _imageUrls(Map<String, dynamic> row) {
    final raw = row['images'];
    if (raw is! List) return const [];
    return raw
        .map((value) => value.toString())
        .where((url) => url.startsWith('http'))
        .toList();
  }
}
