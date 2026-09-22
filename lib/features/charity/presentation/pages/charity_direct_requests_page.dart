import 'package:flutter/material.dart';

import 'package:loqma/features/charity/data/repositories/charity_donation_repository_separate.dart';
import 'package:loqma/features/charity/presentation/pages/charity_action_feedback.dart';
import 'package:loqma/features/charity/presentation/pages/institution_donation_details_page.dart';

class _PickupCodeDialog extends StatefulWidget {
  const _PickupCodeDialog();

  @override
  State<_PickupCodeDialog> createState() => _PickupCodeDialogState();
}

class _PickupCodeDialogState extends State<_PickupCodeDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('تحقق من كود الاستلام'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 6,
        decoration: const InputDecoration(
          hintText: '000000',
          labelText: 'كود الـ6 أرقام من المطعم',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          child: const Text('تحقق'),
        ),
      ],
    );
  }
}

class CharityDirectRequestsPage extends StatefulWidget {
  const CharityDirectRequestsPage({super.key});

  @override
  State<CharityDirectRequestsPage> createState() =>
      _CharityDirectRequestsPageState();
}

class _CharityDirectRequestsPageState extends State<CharityDirectRequestsPage> {
  static const _green = Color(0xFF087A52);
  static const _deepGreen = Color(0xFF123D31);
  static const _background = Color(0xFFF5F8F6);
  static const _mint = Color(0xFFE9F7F0);

  final _repository = SeparateCharityDonationRepository();
  late Future<List<Map<String, dynamic>>> _future;
  String _filter = 'all';
  String? _busyId;

  @override
  void initState() {
    super.initState();
    _future = _repository.getRestaurantDonations();
  }

  Future<void> _refresh() async {
    final next = _repository.getRestaurantDonations();
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

  Future<void> _updateStatus(String id, String status) async {
    if (_busyId != null) return;
    setState(() => _busyId = id);
    try {
      await _repository.updateStatus(
        requestId: id,
        status: status,
        isRestaurantDonation: true,
      );
      await _refresh();
      if (mounted) _message(_statusMessage(status));
    } catch (error) {
      if (mounted) _message(_friendlyError(error), error: true);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _assignVolunteer(String donationId) async {
    if (_busyId != null) return;

    try {
      final volunteers = await _repository.getCharityVolunteers();
      final active = volunteers.where((row) {
        final status = row['status']?.toString().trim().toLowerCase();
        return status == null || status.isEmpty || status == 'active';
      }).toList();

      if (!mounted) return;
      if (active.isEmpty) {
        _message('لا يوجد متطوع نشط في الجمعية حاليًا', error: true);
        return;
      }

      final selected = await showModalBottomSheet<Map<String, dynamic>>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) => _VolunteerPicker(
          volunteers: active,
        ),
      );
      if (selected == null || !mounted) return;

      final volunteerId = selected['id']?.toString().trim();
      if (volunteerId == null || volunteerId.isEmpty) {
        _message('بيانات المتطوع غير مكتملة', error: true);
        return;
      }

      setState(() => _busyId = donationId);
      await _repository.assignRestaurantVolunteer(
        donationId: donationId,
        volunteerId: volunteerId,
      );
      await _refresh();
      if (mounted) _message('تم تعيين متطوع الجمعية بنجاح');
    } catch (error) {
      if (mounted) _message(_friendlyError(error), error: true);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _markDeparted(String donationId) async {
    if (_busyId != null) return;
    setState(() => _busyId = donationId);
    try {
      await _repository.markRestaurantDonationDeparted(donationId);
      await _refresh();
      if (mounted) _message('تم إبلاغ المطعم أن المندوب في الطريق');
    } catch (error) {
      if (mounted) _message(_friendlyError(error), error: true);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _verifyPickup(String donationId) async {
    if (_busyId != null) return;
    final code = await showDialog<String>(
      context: context,
      builder: (_) => const _PickupCodeDialog(),
    );
    if (code == null) return;
    final normalizedCode = _normalizePickupCode(code);
    if (normalizedCode == null) {
      if (mounted) {
        _message('اكتب كودًا صحيحًا مكوّنًا من 6 أرقام', error: true);
      }
      return;
    }
    setState(() => _busyId = donationId);
    try {
      await _repository.confirmRestaurantDonationPickup(
        donationId: donationId,
        token: normalizedCode,
      );
      await _refresh();
      if (mounted) _message('تم التحقق واستلم المندوب التبرع');
    } catch (error) {
      if (mounted) _message(_friendlyError(error), error: true);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _confirmArrival(String donationId) async {
    if (_busyId != null) return;
    setState(() => _busyId = donationId);
    try {
      await _repository.confirmRestaurantDonationArrival(donationId);
      await _refresh();
      if (mounted) _message('تم تأكيد وصول التبرع للجمعية');
    } catch (error) {
      if (mounted) _message(_friendlyError(error), error: true);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  String _statusMessage(String status) {
    switch (status) {
      case 'accepted':
        return 'تم قبول تبرع المؤسسة';
      case 'rejected':
        return 'تم رفض تبرع المؤسسة';
      case 'in_transit':
        return 'تم تسجيل أن التبرع في الطريق';
      case 'completed':
        return 'تم تأكيد وصول التبرع للجمعية';
      default:
        return 'تم تحديث حالة التبرع';
    }
  }

  String? _normalizePickupCode(String value) {
    final normalized = value
        .replaceAll(RegExp(r'[\s\u200B-\u200D\uFEFF]'), '')
        .replaceAll('٠', '0')
        .replaceAll('١', '1')
        .replaceAll('٢', '2')
        .replaceAll('٣', '3')
        .replaceAll('٤', '4')
        .replaceAll('٥', '5')
        .replaceAll('٦', '6')
        .replaceAll('٧', '7')
        .replaceAll('٨', '8')
        .replaceAll('٩', '9')
        .replaceAll('۰', '0')
        .replaceAll('۱', '1')
        .replaceAll('۲', '2')
        .replaceAll('۳', '3')
        .replaceAll('۴', '4')
        .replaceAll('۵', '5')
        .replaceAll('۶', '6')
        .replaceAll('۷', '7')
        .replaceAll('۸', '8')
        .replaceAll('۹', '9');
    return RegExp(r'^[0-9]{6}$').hasMatch(normalized) ? normalized : null;
  }

  String _friendlyError(Object error) {
    final text = error.toString().replaceFirst('Exception: ', '');
    final normalized = text.toLowerCase();
    if (normalized.contains('permission') ||
        normalized.contains('row-level') ||
        normalized.contains('42501')) {
      return 'ليس لديك صلاحية لتنفيذ هذه العملية بحساب الجمعية الحالي.';
    }
    if (normalized.contains('status') || normalized.contains('الحالة')) {
      return 'لا يمكن تنفيذ العملية من الحالة الحالية. حدّث الصفحة وحاول مرة أخرى.';
    }
    if (normalized.contains('network') || normalized.contains('timeout')) {
      return 'تعذر الاتصال بالإنترنت. تحقق من الشبكة وحاول مرة أخرى.';
    }
    return text.isEmpty ? 'تعذر تنفيذ العملية حاليًا' : text;
  }

  void _message(String message, {bool error = false}) {
    if (!mounted) return;
    if (error) {
      CharityActionFeedback.showError(context, message);
    } else {
      CharityActionFeedback.showSuccess(context, message);
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
          title: const Text(
            'تبرعات المؤسسات',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          actions: [
            IconButton(
              onPressed: () {
                _refresh();
              },
              tooltip: 'تحديث',
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        body: FutureBuilder<List<Map<String, dynamic>>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: _green),
              );
            }
            if (snapshot.hasError) {
              return _emptyState(
                'تعذر تحميل تبرعات المؤسسات',
                Icons.cloud_off_rounded,
                canRetry: true,
              );
            }

            final all = snapshot.data ?? const <Map<String, dynamic>>[];
            final rows = all.where(_matches).toList(growable: false);
            return RefreshIndicator(
              color: _green,
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  _hero(all),
                  const SizedBox(height: 16),
                  _sourceNotice(),
                  const SizedBox(height: 16),
                  _filters(),
                  const SizedBox(height: 14),
                  if (rows.isEmpty)
                    _emptyState(
                      _filter == 'all'
                          ? 'لا توجد تبرعات من مطاعم أو مؤسسات حاليًا'
                          : 'لا توجد تبرعات بهذه الحالة',
                      Icons.inventory_2_outlined,
                    )
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

  Widget _hero(List<Map<String, dynamic>> rows) {
    final pending = rows.where((row) => row['status'] == 'pending').length;
    return Container(
      padding: const EdgeInsets.all(21),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF123D31), Color(0xFF087A52)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(25),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26087A52),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'تبرعات المطاعم والمؤسسات',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$pending تبرعات جديدة في انتظار المراجعة',
                  style: const TextStyle(color: Colors.white70, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          const CircleAvatar(
            radius: 30,
            backgroundColor: Color(0x40FFFFFF),
            child: Icon(
              Icons.storefront_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sourceNotice() {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: _mint,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFC9E8D7)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: _green, size: 20),
          SizedBox(width: 9),
          Expanded(
            child: Text(
              'هذه الصفحة تعرض تبرعات المطاعم والمؤسسات فقط. طلبات المستخدمين موجودة في صفحة «طلبات التبرع» بمسار مستقل.',
              style: TextStyle(
                color: _deepGreen,
                fontSize: 12,
                height: 1.45,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filters() {
    const filters = <String, String>{
      'all': 'الكل',
      'pending': 'جديد',
      'accepted': 'مقبول',
      'volunteer_assigned': 'تم تعيين متطوع',
      'in_transit': 'في الطريق',
      'completed': 'مكتمل',
      'rejected': 'مرفوض',
    };

    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 7),
        itemBuilder: (_, index) {
          final key = filters.keys.elementAt(index);
          final selected = key == _filter;
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
              fontWeight: FontWeight.w800,
            ),
            side: BorderSide(
              color: selected ? _green : const Color(0xFFE1ECE6),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
          );
        },
      ),
    );
  }

  bool _matches(Map<String, dynamic> row) {
    return _filter == 'all' || row['status']?.toString() == _filter;
  }

  Widget _card(Map<String, dynamic> row) {
    final id = row['id']?.toString() ?? '';
    final title = row['title']?.toString() ?? 'تبرع من مؤسسة';
    final status = row['status']?.toString() ?? 'pending';
    final sourceName = row['restaurant_name']?.toString() ??
        row['business_name']?.toString() ??
        _nestedSourceName(row);
    final quantity = row['quantity']?.toString() ?? '1';
    final busy = id.isNotEmpty && _busyId == id;
    final image = _firstImage(row['images']);

    return InkWell(
      onTap: () async {
        final changed = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) => InstitutionDonationDetailsPage(donation: row),
          ),
        );
        if (changed == true && mounted) await _refresh();
      },
      borderRadius: BorderRadius.circular(21),
      child: Container(
        margin: const EdgeInsets.only(bottom: 13),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(21),
          border: Border.all(color: const Color(0xFFE0EBE5)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0B000000),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: SizedBox(
                    width: 74,
                    height: 74,
                    child: image == null
                        ? const ColoredBox(
                            color: _mint,
                            child:
                                Icon(Icons.storefront_rounded, color: _green),
                          )
                        : Image.network(
                            image,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const ColoredBox(
                              color: _mint,
                              child: Icon(Icons.image_not_supported_outlined,
                                  color: _green),
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _deepGreen,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        sourceName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF62786D),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _statusPill(status),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FBF9),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(Icons.inventory_2_outlined,
                      color: _green, size: 19),
                  const SizedBox(width: 7),
                  Text(
                    'الكمية: $quantity',
                    style: const TextStyle(
                      color: _deepGreen,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _dateLabel(row['created_at']),
                    style: const TextStyle(
                      color: Color(0xFF74847C),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            if (busy) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(color: _green),
            ] else ...[
              const SizedBox(height: 12),
              _actions(row),
            ],
          ],
        ),
      ),
    );
  }

  Widget _actions(Map<String, dynamic> row) {
    final id = row['id']?.toString() ?? '';
    final status = row['status']?.toString() ?? 'pending';
    if (id.isEmpty) return const SizedBox.shrink();
    final actions = <Widget>[];
    final codeExpiresAt = DateTime.tryParse(
      row['pickup_token_expires_at']?.toString() ?? '',
    );
    final codeUsed = row['pickup_token_used_at'] != null;
    final codeIsActive = codeExpiresAt != null &&
        codeExpiresAt.isAfter(DateTime.now()) &&
        !codeUsed;

    if (status == 'pending') {
      actions.add(
        Expanded(
          child: FilledButton.icon(
            onPressed: () => _updateStatus(id, 'accepted'),
            icon: const Icon(Icons.check_rounded, size: 17),
            label: const Text('قبول'),
          ),
        ),
      );
      actions.add(const SizedBox(width: 8));
      actions.add(
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _updateStatus(id, 'rejected'),
            icon: const Icon(Icons.close_rounded, size: 17),
            label: const Text('رفض'),
          ),
        ),
      );
    } else if (status == 'accepted') {
      actions.add(
        Expanded(
          child: FilledButton.icon(
            onPressed: () => _assignVolunteer(id),
            icon: const Icon(Icons.badge_outlined, size: 17),
            label: const Text('تعيين متطوع'),
          ),
        ),
      );
    } else if (status == 'volunteer_assigned') {
      final restaurantReady = row['restaurant_ready_at'] != null;
      final volunteerDeparted = row['volunteer_departed_at'] != null;
      final pickupVerified = row['pickup_verified_at'] != null;
      if (!restaurantReady) {
        actions.add(
          Expanded(
            child: OutlinedButton.icon(
              onPressed: null,
              icon: const Icon(Icons.hourglass_empty_rounded, size: 17),
              label: const Text('في انتظار جاهزية المطعم'),
            ),
          ),
        );
      } else if (!volunteerDeparted) {
        actions.add(
          Expanded(
            child: FilledButton.icon(
              onPressed: () => _markDeparted(id),
              icon: const Icon(Icons.directions_walk_rounded, size: 17),
              label: const Text('المندوب في الطريق إليك'),
            ),
          ),
        );
      } else if (!pickupVerified) {
        actions.add(
          Expanded(
            child: FilledButton.icon(
              onPressed: () => _verifyPickup(id),
              icon: const Icon(Icons.password_rounded, size: 17),
              label: const Text('تحقق من كود الـ6 أرقام'),
            ),
          ),
        );
      }
    } else if (status == 'picked_up') {
      actions.add(
        Expanded(
          child: FilledButton.icon(
            onPressed: () => _confirmArrival(id),
            icon: const Icon(Icons.task_alt_rounded, size: 17),
            label: const Text('تم تسليم التبرع للجمعية'),
          ),
        ),
      );
    }

    if (actions.isEmpty) {
      return Text(
        status == 'completed'
            ? 'اكتمل هذا التبرع'
            : 'لا توجد خطوة متاحة حاليًا',
        style: const TextStyle(
          color: Color(0xFF74847C),
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      );
    }
    return Row(children: actions);
  }

  Widget _statusPill(String status) {
    final data = _statusData(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: data.color.withAlpha(22),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        data.label,
        style: TextStyle(
          color: data.color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  ({String label, Color color}) _statusData(String status) {
    switch (status) {
      case 'accepted':
        return (label: 'مقبول', color: const Color(0xFF2778B8));
      case 'volunteer_assigned':
        return (label: 'تم تعيين المتطوع', color: _green);
      case 'ready_for_pickup':
        return (label: 'جاهز للاستلام', color: _green);
      case 'in_transit':
        return (label: 'في الطريق', color: const Color(0xFFD47A00));
      case 'completed':
        return (label: 'مكتمل', color: const Color(0xFF2F8F66));
      case 'rejected':
        return (label: 'مرفوض', color: const Color(0xFFB54747));
      default:
        return (label: 'جديد', color: const Color(0xFFB86A00));
    }
  }

  Widget _emptyState(
    String message,
    IconData icon, {
    bool canRetry = false,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: _green, size: 58),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _deepGreen,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (canRetry) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () {
                  _refresh();
                },
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('إعادة المحاولة'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _nestedSourceName(Map<String, dynamic> row) {
    final user = row['users'];
    if (user is Map) {
      final name = user['name']?.toString().trim();
      if (name != null && name.isNotEmpty) return name;
    }
    return 'مؤسسة متبرعة';
  }

  String? _firstImage(dynamic raw) {
    if (raw is! List) return null;
    for (final item in raw) {
      final value = item?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  String _dateLabel(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    if (date == null) return 'التاريخ غير متاح';
    return '${date.day}/${date.month}/${date.year}';
  }
}

class _VolunteerPicker extends StatelessWidget {
  final List<Map<String, dynamic>> volunteers;

  const _VolunteerPicker({required this.volunteers});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(
              child: SizedBox(
                width: 42,
                child: Divider(thickness: 4),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'اختيار متطوع الجمعية',
              style: TextStyle(
                color: _CharityDirectRequestsPageState._deepGreen,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            ...volunteers.map(
              (volunteer) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(
                  backgroundColor: _CharityDirectRequestsPageState._mint,
                  foregroundColor: _CharityDirectRequestsPageState._green,
                  child: Icon(Icons.person_rounded),
                ),
                title: Text(
                  volunteer['name']?.toString() ?? 'متطوع',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(volunteer['phone']?.toString() ?? ''),
                trailing: const Icon(Icons.chevron_left_rounded),
                onTap: () => Navigator.of(context).pop(volunteer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
