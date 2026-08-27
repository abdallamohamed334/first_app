import 'package:flutter/material.dart';

import 'package:loqma/features/charity/data/repositories/charity_donation_repository_separate.dart';
import 'package:loqma/features/charity/presentation/pages/charity_action_feedback.dart';

class CharityPersonDonationDetailsPage extends StatefulWidget {
  final Map<String, dynamic> donation;

  const CharityPersonDonationDetailsPage({
    super.key,
    required this.donation,
  });

  @override
  State<CharityPersonDonationDetailsPage> createState() =>
      _CharityPersonDonationDetailsPageState();
}

class _CharityPersonDonationDetailsPageState
    extends State<CharityPersonDonationDetailsPage> {
  static const _green = Color(0xFF087A52);
  static const _deepGreen = Color(0xFF123D31);
  static const _mint = Color(0xFFE9F7F0);
  static const _background = Color(0xFFF5F8F6);

  final _repository = SeparateCharityDonationRepository();
  bool _loading = false;
  late String _status;

  Map<String, dynamic> get donation => widget.donation;
  String get donationId => donation['id']?.toString() ?? '';
  String get title => donation['title']?.toString().trim().isNotEmpty == true
      ? donation['title'].toString()
      : 'تبرع من مستخدم';
  String get donorName =>
      donation['donor_name']?.toString() ??
      donation['user_name']?.toString() ??
      _nestedName(donation['users']) ??
      'متبرع';

  @override
  void initState() {
    super.initState();
    _status = donation['status']?.toString().trim().toLowerCase() ?? 'pending';
  }

  Future<void> _updateStatus(String nextStatus) async {
    if (_loading || donationId.isEmpty) return;
    setState(() => _loading = true);
    try {
      await _repository.updateStatus(
        requestId: donationId,
        status: nextStatus,
        isRestaurantDonation: false,
      );
      if (!mounted) return;
      setState(() => _status = nextStatus);
      CharityActionFeedback.showSuccess(context, _statusMessage(nextStatus));
    } catch (error) {
      if (mounted) {
        CharityActionFeedback.showError(context, _friendlyError(error));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _assignRepresentative() async {
    if (_loading || donationId.isEmpty) return;
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _RepresentativeSheet(
        nameController: nameController,
        phoneController: phoneController,
        onConfirm: () {
          if (nameController.text.trim().isEmpty ||
              phoneController.text.trim().isEmpty) {
            return;
          }
          Navigator.of(sheetContext).pop(true);
        },
      ),
    );
    nameController.dispose();
    phoneController.dispose();
    if (confirmed != true || !mounted) return;

    setState(() => _loading = true);
    try {
      await _repository.assignExternalRepresentative(
        requestId: donationId,
        name: nameController.text.trim(),
        phone: phoneController.text.trim(),
      );
      if (!mounted) return;
      setState(() => _status = 'volunteer_assigned');
      CharityActionFeedback.showSuccess(
          context, 'تم تعيين مندوب الاستلام بنجاح');
    } catch (error) {
      if (mounted) {
        CharityActionFeedback.showError(context, _friendlyError(error));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verifyPickup() async {
    if (_loading || donationId.isEmpty) return;
    final controller = TextEditingController();
    final token = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تأكيد استلام التبرع'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'كود الاستلام',
            hintText: 'أدخل الكود الذي مع المندوب',
            prefixIcon: Icon(Icons.password_rounded),
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

    setState(() => _loading = true);
    try {
      await _repository.confirmPickup(
          requestId: donationId, token: token.trim());
      if (!mounted) return;
      setState(() => _status = 'completed');
      CharityActionFeedback.showSuccess(
          context, 'تم تأكيد استلام التبرع بنجاح');
    } catch (error) {
      if (mounted) {
        CharityActionFeedback.showError(context, _friendlyError(error));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _statusMessage(String value) {
    switch (value) {
      case 'accepted':
        return 'تم قبول تبرع المستخدم';
      case 'rejected':
        return 'تم رفض تبرع المستخدم';
      default:
        return 'تم تحديث حالة التبرع';
    }
  }

  String _friendlyError(Object error) {
    final value = error.toString().toLowerCase();
    if (value.contains('permission') ||
        value.contains('row-level') ||
        value.contains('42501')) {
      return 'ليس لديك صلاحية لتنفيذ هذه العملية بحساب الجمعية الحالي.';
    }
    if (value.contains('status') || value.contains('الحالة')) {
      return 'لا يمكن تنفيذ العملية من الحالة الحالية. حدّث الصفحة وحاول مرة أخرى.';
    }
    if (value.contains('code') ||
        value.contains('token') ||
        value.contains('كود')) {
      return 'كود الاستلام غير صحيح أو منتهي.';
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
          title: const Text('تفاصيل تبرع شخص',
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
        child: Row(children: [
          const CircleAvatar(
              radius: 30,
              backgroundColor: Color(0x35FFFFFF),
              child: Icon(Icons.volunteer_activism_rounded,
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
                Text(donorName,
                    style: const TextStyle(
                        color: Colors.white70, fontWeight: FontWeight.w700)),
              ])),
        ]),
      );

  Widget _detailsCard() => _card(
        title: 'بيانات التبرع',
        icon: Icons.info_outline_rounded,
        child: Column(children: [
          _row('المتبرع', donorName),
          _row('الكمية', '${donation['quantity'] ?? 1}'),
          _row('الوصف', donation['description']?.toString() ?? 'غير محدد'),
          _row('العنوان', donation['pickup_address']?.toString() ?? 'غير محدد'),
          _row('الحالة', _statusLabel(_status)),
        ]),
      );

  Widget _timeline() {
    const steps = [
      'pending',
      'accepted',
      'volunteer_assigned',
      'picked_up_from_donor',
      'completed'
    ];
    final current = switch (_status) {
      'accepted' => 1,
      'volunteer_assigned' || 'donor_ready' => 2,
      'picked_up_from_donor' || 'in_transit' => 3,
      'completed' => 4,
      _ => 0,
    };
    return _card(
      title: 'خط سير تبرع المستخدم',
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
      })),
    );
  }

  Widget _actions() {
    if (_status == 'pending') {
      return Row(children: [
        Expanded(
            child: FilledButton.icon(
                onPressed: _loading ? null : () => _updateStatus('accepted'),
                icon: const Icon(Icons.check_rounded),
                label: const Text('قبول'))),
        const SizedBox(width: 10),
        Expanded(
            child: OutlinedButton.icon(
                onPressed: _loading ? null : () => _updateStatus('rejected'),
                icon: const Icon(Icons.close_rounded),
                label: const Text('رفض'))),
      ]);
    }
    if (_status == 'accepted') {
      return _actionButton('تعيين مندوب الاستلام',
          Icons.person_add_alt_1_rounded, _assignRepresentative);
    }
    if (_status == 'volunteer_assigned' || _status == 'donor_ready') {
      return _actionButton(
          'تأكيد كود الاستلام', Icons.password_rounded, _verifyPickup);
    }
    if (_status == 'completed') {
      return _notice('تم استلام التبرع وإغلاق العملية بنجاح');
    }
    return _notice('لا يوجد إجراء متاح لهذه الحالة حاليًا');
  }

  Widget _actionButton(String label, IconData icon, VoidCallback action) =>
      SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
              onPressed: _loading ? null : action,
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
            width: 78,
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

  String _statusLabel(String value) {
    switch (value) {
      case 'pending':
        return 'في انتظار المراجعة';
      case 'accepted':
        return 'تم القبول';
      case 'volunteer_assigned':
        return 'تم تعيين مندوب';
      case 'donor_ready':
        return 'المتبرع أعلن الجاهزية';
      case 'picked_up_from_donor':
        return 'استلم المندوب التبرع';
      case 'completed':
        return 'تم الوصول';
      case 'rejected':
        return 'مرفوض';
      default:
        return value;
    }
  }

  String? _nestedName(dynamic value) {
    if (value is Map) {
      final name = value['name']?.toString().trim();
      if (name != null && name.isNotEmpty) return name;
    }
    return null;
  }
}

class _RepresentativeSheet extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController phoneController;
  final VoidCallback onConfirm;

  const _RepresentativeSheet(
      {required this.nameController,
      required this.phoneController,
      required this.onConfirm});

  @override
  Widget build(BuildContext context) => SafeArea(
      child: Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
          child: Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
              decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(28))),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                        color: Colors.grey,
                        borderRadius: BorderRadius.circular(8))),
                const SizedBox(height: 14),
                const Text('تعيين مندوب الاستلام',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                const SizedBox(height: 14),
                TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                        labelText: 'اسم المندوب',
                        prefixIcon: Icon(Icons.person_outline_rounded))),
                const SizedBox(height: 10),
                TextField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                        labelText: 'رقم الهاتف',
                        prefixIcon: Icon(Icons.phone_outlined))),
                const SizedBox(height: 16),
                SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                        onPressed: onConfirm,
                        child: const Text('تعيين المندوب')))
              ]))));
}
