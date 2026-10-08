import 'package:flutter/material.dart';

import 'package:loqma/features/charity/data/repositories/charity_donation_repository_separate.dart';
import 'package:loqma/features/charity/presentation/pages/charity_action_feedback.dart';

class InstitutionDonationDetailsPage extends StatefulWidget {
  final Map<String, dynamic> donation;

  const InstitutionDonationDetailsPage({super.key, required this.donation});

  @override
  State<InstitutionDonationDetailsPage> createState() =>
      _InstitutionDonationDetailsPageState();
}

class _InstitutionDonationDetailsPageState
    extends State<InstitutionDonationDetailsPage> {
  static const _green = Color(0xFF087A52);
  static const _deepGreen = Color(0xFF123D31);
  static const _background = Color(0xFFF5F8F6);
  static const _mint = Color(0xFFE9F7F0);

  final _repository = SeparateCharityDonationRepository();
  bool _loading = false;
  Map<String, dynamic>? _selectedVolunteer;
  late Map<String, dynamic> _donationData;

  Map<String, dynamic> get donation => _donationData;
  String get id => donation['id']?.toString() ?? '';
  String get status =>
      donation['status']?.toString().trim().toLowerCase() ?? 'pending';
  String get title => donation['title']?.toString().trim().isNotEmpty == true
      ? donation['title'].toString()
      : 'تبرع من مؤسسة';
  String get sourceName =>
      donation['restaurant_name']?.toString() ??
      donation['business_name']?.toString() ??
      donation['source_name']?.toString() ??
      'مؤسسة شريكة';
  String get pickupCode =>
      donation['pickup_code']?.toString() ??
      donation['pickup_token']?.toString() ??
      '';

  bool get restaurantReady => donation['restaurant_ready_at'] != null;
  bool get volunteerDeparted => donation['volunteer_departed_at'] != null;
  bool get pickupVerified => donation['pickup_verified_at'] != null;

  @override
  void initState() {
    super.initState();
    _donationData = Map<String, dynamic>.from(widget.donation);
    _loadCanonicalDonation();
  }

  Future<void> _loadCanonicalDonation() async {
    if (id.isEmpty) return;
    try {
      final rows = await _repository.getRestaurantDonations();
      for (final row in rows) {
        if (row['id']?.toString() == id) {
          if (mounted) setState(() => _donationData = row);
          return;
        }
      }
    } catch (_) {
      // Keep the list snapshot if the read fails; mutations remain RPC-gated.
    }
  }

  Future<void> _updateStatus(String nextStatus) async {
    if (_loading || id.isEmpty) return;
    setState(() => _loading = true);
    try {
      await _repository.updateStatus(
        requestId: id,
        status: nextStatus,
        isRestaurantDonation: true,
      );
      if (!mounted) return;
      CharityActionFeedback.showSuccess(context, _statusMessage(nextStatus));
      Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        CharityActionFeedback.showError(context, _friendlyError(error));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _assignVolunteer() async {
    if (_loading || id.isEmpty) return;
    setState(() => _loading = true);
    try {
      final rows = await _repository.getCharityVolunteers();
      final active = rows.where((row) {
        final value = row['status']?.toString().toLowerCase();
        return value == null || value.isEmpty || value == 'active';
      }).toList();
      if (!mounted) return;
      setState(() => _loading = false);
      if (active.isEmpty) {
        CharityActionFeedback.showError(
            context, 'لا يوجد متطوع نشط في الجمعية حاليًا');
        return;
      }
      final selected = await showModalBottomSheet<Map<String, dynamic>>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (_) => _VolunteerSheet(volunteers: active),
      );
      if (selected == null || !mounted) return;
      setState(() {
        _loading = true;
        _selectedVolunteer = selected;
      });
      await _repository.assignRestaurantVolunteer(
        donationId: id,
        volunteerId: selected['id'].toString(),
      );
      if (mounted) {
        CharityActionFeedback.showSuccess(context, 'تم تعيين المتطوع بنجاح');
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      if (mounted) {
        CharityActionFeedback.showError(context, _friendlyError(error));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markDeparted() async {
    if (_loading || id.isEmpty || !restaurantReady || volunteerDeparted) return;
    setState(() => _loading = true);
    try {
      await _repository.markRestaurantDonationDeparted(id);
      if (!mounted) return;
      CharityActionFeedback.showSuccess(
          context, 'تم إبلاغ المطعم أن المندوب في الطريق');
      Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        CharityActionFeedback.showError(context, _friendlyError(error));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verifyPickupCode() async {
    if (_loading || id.isEmpty || !restaurantReady || !volunteerDeparted) {
      return;
    }
    final code = await showDialog<String>(
      context: context,
      builder: (_) => const _PickupCodeDialog(),
    );

    if (code == null || !RegExp(r'^\d{6}$').hasMatch(code)) {
      if (mounted && code != null) {
        CharityActionFeedback.showError(
            context, 'اكتب كودًا صحيحًا مكوّنًا من 6 أرقام');
      }
      return;
    }
    setState(() => _loading = true);
    try {
      await _repository.confirmRestaurantDonationPickup(
        donationId: id,
        token: code,
      );
      if (!mounted) return;
      CharityActionFeedback.showSuccess(
          context, 'تم التحقق واستلم المندوب التبرع');
      Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        CharityActionFeedback.showError(context, _friendlyError(error));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _confirmArrival() async {
    if (_loading || id.isEmpty || !pickupVerified) return;
    setState(() => _loading = true);
    try {
      await _repository.confirmRestaurantDonationArrival(id);
      if (!mounted) return;
      CharityActionFeedback.showSuccess(
          context, 'تم تأكيد وصول التبرع للجمعية');
      Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        CharityActionFeedback.showError(context, _friendlyError(error));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _statusLabel(String value) {
    switch (value) {
      case 'pending':
        return 'في انتظار المراجعة';
      case 'accepted':
        return 'تم القبول';
      case 'volunteer_assigned':
        return 'تم تعيين المندوب';
      case 'restaurant_ready':
        return 'المطعم جاهز للتسليم';
      case 'volunteer_departed':
        return 'المندوب في الطريق';
      case 'picked_up':
        return 'تم استلام المندوب للتبرع';
      case 'completed':
        return 'تم تسليم التبرع للجمعية';
      case 'rejected':
        return 'مرفوض';
      case 'cancelled':
        return 'ملغي';
      case 'expired':
        return 'منتهي';
      default:
        return 'غير محدد';
    }
  }

  String _statusMessage(String value) {
    switch (value) {
      case 'accepted':
        return 'تم قبول تبرع المؤسسة';
      case 'rejected':
        return 'تم رفض تبرع المؤسسة';
      case 'completed':
        return 'تم تأكيد وصول التبرع للجمعية';
      default:
        return 'تم تحديث حالة التبرع';
    }
  }

  String _friendlyError(Object error) {
    final text = error.toString().toLowerCase();
    if (text.contains('permission') ||
        text.contains('row-level') ||
        text.contains('42501')) {
      return 'ليس لديك صلاحية لتنفيذ هذه العملية بحساب الجمعية الحالي.';
    }
    if (text.contains('status') || text.contains('الحالة')) {
      return 'لا يمكن تنفيذ العملية من الحالة الحالية. حدّث الصفحة وحاول مرة أخرى.';
    }
    if (text.contains('random') || text.contains('gen_random_bytes')) {
      return 'تعذر إنشاء كود الاستلام من الخادم. حاول مرة أخرى لاحقًا.';
    }
    return 'تعذر تنفيذ العملية حاليًا. تحقق من الاتصال وحاول مرة أخرى.';
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _background,
        appBar: AppBar(
          title: const Text('تفاصيل تبرع المؤسسة',
              style: TextStyle(fontWeight: FontWeight.w900)),
          backgroundColor: _background,
          foregroundColor: _deepGreen,
          elevation: 0,
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            _hero(),
            const SizedBox(height: 14),
            _detailsCard(),
            const SizedBox(height: 14),
            _timeline(),
            const SizedBox(height: 16),
            _actions(),
          ],
        ),
      ),
    );
  }

  Widget _hero() => Container(
        padding: const EdgeInsets.all(22),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
              colors: [_deepGreen, _green],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft),
          borderRadius: BorderRadius.all(Radius.circular(26)),
        ),
        child: Row(
          children: [
            const CircleAvatar(
                radius: 30,
                backgroundColor: Color(0x35FFFFFF),
                child: Icon(Icons.storefront_rounded,
                    color: Colors.white, size: 31)),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w900)),
                    const SizedBox(height: 6),
                    Text(sourceName,
                        style: const TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.w700)),
                  ]),
            ),
          ],
        ),
      );

  Widget _detailsCard() => _card(
        title: 'بيانات التبرع',
        icon: Icons.info_outline_rounded,
        child: Column(children: [
          _row('الكمية', '${donation['quantity'] ?? 0}'),
          _row('الوصف', donation['description']?.toString() ?? 'غير محدد'),
          _row('الحالة', _statusLabel(status)),
          if (_selectedVolunteer != null)
            _row('المتطوع',
                _selectedVolunteer!['name']?.toString() ?? 'تم التعيين'),
          if (pickupCode.isNotEmpty) _row('الكود', pickupCode),
        ]),
      );

  Widget _timeline() {
    final steps = <String>[
      'pending',
      'accepted',
      'volunteer_assigned',
      if (restaurantReady) 'restaurant_ready',
      if (volunteerDeparted) 'volunteer_departed',
      if (pickupVerified) 'picked_up',
      'completed',
    ];
    final current = status == 'completed'
        ? steps.length - 1
        : status == 'picked_up'
            ? steps.indexOf('picked_up')
            : volunteerDeparted
                ? steps.indexOf('volunteer_departed')
                : restaurantReady
                    ? steps.indexOf('restaurant_ready')
                    : steps.indexOf(status).clamp(0, steps.length - 1);

    return _card(
      title: 'خط سير التبرع',
      icon: Icons.route_rounded,
      child: Column(
        children: List.generate(steps.length, (index) {
          final done = index < current;
          final selected = index == current;
          final color = done || selected ? _green : Colors.grey.shade400;
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(
                width: 30,
                child: Column(children: [
                  Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                          color: done
                              ? _green
                              : selected
                                  ? _mint
                                  : Colors.grey.shade200,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: selected ? _green : Colors.transparent,
                              width: 2)),
                      child: Icon(done ? Icons.check_rounded : Icons.circle,
                          size: 13, color: done ? Colors.white : color)),
                  if (index < steps.length - 1)
                    Container(
                        width: 2,
                        height: 30,
                        color: done ? _green : Colors.grey.shade200),
                ])),
            const SizedBox(width: 12),
            Expanded(
                child: Padding(
                    padding: const EdgeInsets.only(top: 3, bottom: 13),
                    child: Text(_statusLabel(steps[index]),
                        style: TextStyle(
                            color: color, fontWeight: FontWeight.w900)))),
          ]);
        }),
      ),
    );
  }

  Widget _actions() {
    final buttons = <Widget>[];
    if (status == 'pending') {
      buttons.add(_action('قبول التبرع', Icons.check_circle_rounded,
          () => _updateStatus('accepted')));
      buttons.add(_action('رفض التبرع', Icons.cancel_outlined,
          () => _updateStatus('rejected')));
    } else if (status == 'accepted') {
      buttons.add(_action(
          'تعيين متطوع', Icons.person_add_alt_1_rounded, _assignVolunteer));
    } else if (status == 'volunteer_assigned' && !restaurantReady) {
      buttons.add(_notice('في انتظار ضغط المطعم على «أنا جاهز للتسليم»'));
    } else if (status == 'volunteer_assigned' &&
        restaurantReady &&
        !volunteerDeparted) {
      buttons.add(_action('المندوب في الطريق إليك',
          Icons.directions_walk_rounded, _markDeparted));
    } else if (status == 'volunteer_assigned' &&
        volunteerDeparted &&
        !pickupVerified) {
      buttons.add(_action(
          'تحقق من كود الـ6 أرقام', Icons.password_rounded, _verifyPickupCode));
    } else if (status == 'picked_up' || pickupVerified) {
      buttons.add(_action('تم تسليم التبرع للجمعية', Icons.inventory_2_rounded,
          _confirmArrival));
    } else if (status == 'completed') {
      buttons.add(_notice('تم تسليم التبرع للجمعية بنجاح'));
    }
    if (buttons.isEmpty) {
      buttons.add(_notice('لا يوجد إجراء متاح لهذه الحالة حاليًا'));
    }
    return Column(children: buttons);
  }

  Widget _action(String label, IconData icon, VoidCallback onPressed) =>
      SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
              onPressed: _loading ? null : onPressed,
              icon: _loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Icon(icon),
              label: Text(label,
                  style: const TextStyle(fontWeight: FontWeight.w900)),
              style: FilledButton.styleFrom(
                  backgroundColor: _green,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(17)))));

  Widget _notice(String text) => Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration:
          BoxDecoration(color: _mint, borderRadius: BorderRadius.circular(17)),
      child: Row(children: [
        const Icon(Icons.check_circle_rounded, color: _green),
        const SizedBox(width: 9),
        Expanded(
            child: Text(text,
                style: const TextStyle(
                    color: _deepGreen, fontWeight: FontWeight.w800)))
      ]));

  Widget _card(
          {required String title,
          required IconData icon,
          required Widget child}) =>
      Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFE0EBE5))),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(icon, color: _green),
              const SizedBox(width: 8),
              Text(title,
                  style: const TextStyle(
                      color: _deepGreen,
                      fontSize: 17,
                      fontWeight: FontWeight.w900))
            ]),
            const SizedBox(height: 14),
            child
          ]));

  Widget _row(String label, String value) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
            width: 90,
            child: Text(label,
                style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                    fontWeight: FontWeight.w700))),
        Expanded(
            child: Text(value,
                style: const TextStyle(
                    color: _deepGreen, fontWeight: FontWeight.w800)))
      ]));
}

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
          labelText: 'كود الـ6 أرقام الذي أعطاه المطعم',
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

class _VolunteerSheet extends StatelessWidget {
  final List<Map<String, dynamic>> volunteers;
  const _VolunteerSheet({required this.volunteers});

  @override
  Widget build(BuildContext context) => SafeArea(
      child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
          decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey,
                    borderRadius: BorderRadius.circular(8))),
            const SizedBox(height: 14),
            const Text('اختيار متطوع الاستلام',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            ...volunteers.map((row) => ListTile(
                leading: CircleAvatar(
                    child: Text(
                        (row['name']?.toString().trim().isNotEmpty ?? false)
                            ? row['name'].toString().trim().substring(0, 1)
                            : 'م')),
                title: Text(row['name']?.toString() ?? 'متطوع'),
                subtitle:
                    Text(row['phone']?.toString() ?? 'بيانات الهاتف غير متاحة'),
                onTap: () => Navigator.pop(context, row)))
          ])));
}
