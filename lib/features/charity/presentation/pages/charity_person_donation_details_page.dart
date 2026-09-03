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
  bool _assignmentDialogOpen = false;
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

  List<String> get _images {
    final raw = donation['images'];
    if (raw is! List) return const [];
    return raw
        .map((value) => value.toString())
        .where((url) => url.startsWith('http'))
        .toList();
  }

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

  Future<void> _assignVolunteer() async {
    if (_assignmentDialogOpen || _loading || donationId.isEmpty || !mounted) {
      return;
    }
    _assignmentDialogOpen = true;

    try {
      final volunteers = await _repository.getMyCharityVolunteers();
      if (!mounted) {
        _assignmentDialogOpen = false;
        return;
      }

      final activeVolunteers = volunteers
          .where((v) => v['status']?.toString() == 'active')
          .toList(growable: false);

      final nameController = TextEditingController();
      final phoneController = TextEditingController();

      final assignment = await showDialog<_VolunteerAssignment>(
        barrierDismissible: false,
        context: context,
        builder: (dialogContext) => _VolunteerDialog(
          volunteers: activeVolunteers,
          nameController: nameController,
          phoneController: phoneController,
        ),
      );

      final externalName = nameController.text.trim();
      final externalPhone = phoneController.text.trim();
      nameController.dispose();
      phoneController.dispose();

      if (assignment == null || !mounted) {
        _assignmentDialogOpen = false;
        return;
      }

      setState(() => _loading = true);

      final isExternal = assignment.id == null;
      final volunteerName = isExternal ? externalName : assignment.name;
      final volunteerPhone = isExternal ? externalPhone : assignment.phone;

      await _repository.assignVolunteer(
        requestId: donationId,
        volunteerType: isExternal ? 'external' : 'charity_volunteer',
        volunteerId: assignment.id,
        volunteerName: volunteerName,
        volunteerPhone: volunteerPhone,
      );

      if (!mounted) return;
      setState(() => _status = 'volunteer_assigned');
      CharityActionFeedback.showSuccess(context, 'تم تعيين المندوب بنجاح');
    } catch (error) {
      if (mounted) {
        CharityActionFeedback.showError(context, _friendlyError(error));
      }
    } finally {
      _assignmentDialogOpen = false;
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

  Widget _hero() {
    final images = _images;
    final heroImage = images.isNotEmpty ? images.first : null;

    return Container(
      height: 190,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: _green.withAlpha(40),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (heroImage == null)
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_deepGreen, _green],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
              ),
              child: Center(
                child: Icon(Icons.volunteer_activism_rounded,
                    color: Colors.white, size: 52),
              ),
            )
          else
            Image.network(
              heroImage,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_deepGreen, _green],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                ),
                child: Center(
                  child: Icon(Icons.image_not_supported_outlined,
                      color: Colors.white, size: 42),
                ),
              ),
            ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.35, 1],
                  colors: [
                    Colors.transparent,
                    Colors.black.withAlpha(190),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 18,
            right: 18,
            bottom: 16,
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 22,
                  backgroundColor: Color(0x35FFFFFF),
                  child: Icon(Icons.volunteer_activism_rounded,
                      color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w900)),
                      const SizedBox(height: 3),
                      Text(donorName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: Colors.white.withAlpha(220),
                              fontWeight: FontWeight.w700,
                              fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (images.length > 1)
            Positioned(
              top: 14,
              left: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(140),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.photo_library_outlined,
                        color: Colors.white, size: 13),
                    const SizedBox(width: 4),
                    Text('${images.length}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

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
      'donor_ready',
      'volunteer_assigned',
      'picked_up_from_donor',
      'completed'
    ];
    final current = switch (_status) {
      'accepted' => 1,
      'donor_ready' => 2,
      'volunteer_assigned' => 3,
      'picked_up_from_donor' || 'in_transit' => 4,
      'completed' => 5,
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
      return _notice('بانتظار أن يضغط المتبرع «أنا جاهز لتسليم الحاجة».');
    }
    if (_status == 'donor_ready') {
      return _actionButton(
          'إرسال مندوب الجمعية', Icons.badge_outlined, _assignVolunteer);
    }
    if (_status == 'volunteer_assigned') {
      return _actionButton(
          'إدخال كود المتبرع والتحقق', Icons.password_rounded, _verifyPickup);
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
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration:
          BoxDecoration(color: _mint, borderRadius: BorderRadius.circular(17)),
      child: Row(children: [
        const Icon(Icons.hourglass_top_rounded, color: _green),
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
      case 'donor_ready':
        return 'المتبرع أعلن الجاهزية';
      case 'volunteer_assigned':
        return 'تم تعيين مندوب';
      case 'picked_up_from_donor':
        return 'استلم المندوب التبرع';
      case 'in_transit':
        return 'في الطريق للجمعية';
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

class _VolunteerDialog extends StatefulWidget {
  final List<Map<String, dynamic>> volunteers;
  final TextEditingController nameController;
  final TextEditingController phoneController;

  const _VolunteerDialog({
    required this.volunteers,
    required this.nameController,
    required this.phoneController,
  });

  @override
  State<_VolunteerDialog> createState() => _VolunteerDialogState();
}

class _VolunteerDialogState extends State<_VolunteerDialog> {
  static const _green = Color(0xFF087A52);
  static const _mint = Color(0xFFE9F7F0);
  static const _deepGreen = Color(0xFF123D31);

  bool _fromCharity = true;
  String? _selectedId;

  @override
  Widget build(BuildContext context) {
    final selected = widget.volunteers.where(
      (item) => item['id']?.toString() == _selectedId,
    );
    final volunteer = selected.isEmpty ? null : selected.first;

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      title: Row(
        children: const [
          Icon(Icons.badge_outlined, color: _green),
          SizedBox(width: 10),
          Text(
            'تعيين مندوب',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'اختر مندوب من الجمعية أو أضف مندوبًا خارجيًا',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 14),
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
            const SizedBox(height: 16),
            if (_fromCharity)
              widget.volunteers.isEmpty
                  ? Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'لا يوجد مندوبون نشطون داخل الجمعية',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : DropdownButtonFormField<String>(
                      value: _selectedId,
                      decoration: const InputDecoration(
                        labelText: 'اختيار مندوب الجمعية',
                        prefixIcon: Icon(Icons.badge_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                        ),
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
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: widget.phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'رقم هاتف المندوب الخارجي',
                  prefixIcon: Icon(Icons.phone_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                ),
              ),
            ],
            if (_fromCharity && volunteer != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _mint,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: _green, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'سيتم تعيين: ${volunteer['name'] ?? 'مندوب الجمعية'}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: _deepGreen,
                        ),
                      ),
                    ),
                  ],
                ),
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
                _VolunteerAssignment(
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
                _VolunteerAssignment(
                  id: null,
                  name: widget.nameController.text.trim(),
                  phone: widget.phoneController.text.trim(),
                ),
              );
            }
          },
          style: FilledButton.styleFrom(
            backgroundColor: _green,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text('تعيين المندوب'),
        ),
      ],
    );
  }
}
