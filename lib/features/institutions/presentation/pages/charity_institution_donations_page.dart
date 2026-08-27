import 'package:flutter/material.dart';

import '../../data/repositories/charity_institution_donations_repository.dart';

class CharityInstitutionDonationsPage extends StatefulWidget {
  final CharityInstitutionDonationsRepository? repository;

  const CharityInstitutionDonationsPage({super.key, this.repository});

  @override
  State<CharityInstitutionDonationsPage> createState() =>
      _CharityInstitutionDonationsPageState();
}

class _CharityInstitutionDonationsPageState
    extends State<CharityInstitutionDonationsPage> {
  late final CharityInstitutionDonationsRepository _repository;
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? CharityInstitutionDonationsRepository();
    _future = _repository.listMyDonations();
  }

  Future<void> _reload() async {
    final future = _repository.listMyDonations();
    setState(() => _future = future);
    await future;
  }

  Future<void> _accept(String id, bool accept) async {
    try {
      await _repository.acceptDonation(id, accept);
      if (!mounted) return;
      _toast(accept ? 'تم قبول التبرع' : 'تم رفض التبرع');
      await _reload();
    } catch (_) {
      if (mounted) _toast('تعذر تحديث حالة التبرع');
    }
  }

  Future<void> _assignVolunteer(String id) async {
    List<Map<String, dynamic>> volunteers;
    try {
      volunteers = await _repository.listCharityVolunteers();
    } catch (_) {
      if (mounted) _toast('تعذر تحميل متطوعي الجمعية');
      return;
    }
    if (!mounted) return;

    final name = TextEditingController();
    final phone = TextEditingController();
    final assignment = await showDialog<_VolunteerAssignment>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _VolunteerAssignmentDialog(
        volunteers: volunteers,
        nameController: name,
        phoneController: phone,
      ),
    );
    final volunteerName = name.text.trim();
    final volunteerPhone = phone.text.trim();
    name.dispose();
    phone.dispose();

    if (assignment == null) return;
    try {
      await _repository.assignVolunteer(
        donationId: id,
        volunteerId: assignment.id,
        volunteerName: volunteerName.isEmpty ? assignment.name : volunteerName,
        volunteerPhone:
            volunteerPhone.isEmpty ? assignment.phone : volunteerPhone,
      );
      if (!mounted) return;
      _toast('تم تعيين المتطوع بنجاح');
      await _reload();
    } catch (_) {
      if (mounted) _toast('تعذر تعيين المتطوع. راجع بيانات الاختيار');
    }
  }

  Future<void> _departed(String id) async {
    try {
      await _repository.markVolunteerDeparted(id);
      if (!mounted) return;
      _toast('تم تسجيل أن المتطوع في الطريق');
      await _reload();
    } catch (_) {
      if (mounted) _toast('تعذر تحديث حالة المتطوع');
    }
  }

  Future<void> _generateCode(String id) async {
    try {
      final result = await _repository.generatePickupCode(id);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('كود استلام التبرع'),
          content: Text(result['pickup_code']?.toString() ?? 'تم إنشاء الكود',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: 7)),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('تم'))
          ],
        ),
      );
    } catch (_) {
      if (mounted) _toast('تعذر إنشاء كود الاستلام');
    }
  }

  Future<void> _verifyCode(String id) async {
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('التحقق من كود الاستلام'),
        content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            maxLength: 6,
            textAlign: TextAlign.center,
            decoration:
                const InputDecoration(hintText: '000000', counterText: '')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء')),
          FilledButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('تحقق')),
        ],
      ),
    );
    controller.dispose();
    if (code == null || code.length != 6) {
      if (mounted && code != null) _toast('اكتب كودًا مكونًا من 6 أرقام');
      return;
    }
    try {
      await _repository.verifyPickupCode(donationId: id, code: code);
      if (!mounted) return;
      _toast('تم التحقق واستلام التبرع');
      await _reload();
    } catch (_) {
      if (mounted) _toast('كود الاستلام غير صحيح أو منتهي');
    }
  }

  Future<void> _complete(String id) async {
    try {
      await _repository.confirmArrival(id);
      if (!mounted) return;
      _toast('تم تأكيد وصول التبرع');
      await _reload();
    } catch (_) {
      if (mounted) _toast('تعذر تأكيد وصول التبرع');
    }
  }

  void _toast(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFA),
        appBar: AppBar(title: const Text('تبرعات المؤسسات')),
        body: FutureBuilder<List<Map<String, dynamic>>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting)
              return const Center(child: CircularProgressIndicator());
            if (snapshot.hasError)
              return Center(
                  child: FilledButton.tonal(
                      onPressed: _reload,
                      child: const Text('تعذر التحميل — إعادة المحاولة')));
            final rows = snapshot.data ?? const <Map<String, dynamic>>[];
            if (rows.isEmpty)
              return const Center(child: Text('لا توجد تبرعات مؤسسات حاليًا'));
            return RefreshIndicator(
              onRefresh: _reload,
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: rows.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, index) => _DonationCard(
                  row: rows[index],
                  onAccept: () => _accept(rows[index]['id'].toString(), true),
                  onReject: () => _accept(rows[index]['id'].toString(), false),
                  onAssign: () =>
                      _assignVolunteer(rows[index]['id'].toString()),
                  onDeparted: () => _departed(rows[index]['id'].toString()),
                  onGenerateCode: () =>
                      _generateCode(rows[index]['id'].toString()),
                  onVerifyCode: () => _verifyCode(rows[index]['id'].toString()),
                  onComplete: () => _complete(rows[index]['id'].toString()),
                ),
              ),
            );
          },
        ),
      ),
    );
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

class _VolunteerAssignmentDialog extends StatefulWidget {
  final List<Map<String, dynamic>> volunteers;
  final TextEditingController nameController;
  final TextEditingController phoneController;

  const _VolunteerAssignmentDialog({
    required this.volunteers,
    required this.nameController,
    required this.phoneController,
  });

  @override
  State<_VolunteerAssignmentDialog> createState() =>
      _VolunteerAssignmentDialogState();
}

class _VolunteerAssignmentDialogState
    extends State<_VolunteerAssignmentDialog> {
  bool _internal = true;
  String? _selectedId;

  @override
  Widget build(BuildContext context) {
    final activeVolunteers = widget.volunteers;
    final selected = activeVolunteers
        .where((item) => item['id']?.toString() == _selectedId)
        .toList();
    final selectedVolunteer = selected.isEmpty ? null : selected.first;

    return AlertDialog(
      title: const Text('تعيين مندوب التبرع'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'اختاري مندوبًا من الجمعية أو أدخلي بيانات مندوب خارجي.',
              style: TextStyle(color: Colors.black54),
            ),
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
              selected: {_internal},
              onSelectionChanged: (values) {
                setState(() {
                  _internal = values.first;
                  _selectedId = null;
                  widget.nameController.clear();
                  widget.phoneController.clear();
                });
              },
            ),
            const SizedBox(height: 14),
            if (_internal)
              if (activeVolunteers.isEmpty)
                const Text('لا يوجد مندوبون نشطون داخل الجمعية.')
              else
                DropdownButtonFormField<String>(
                  value: _selectedId,
                  decoration: const InputDecoration(
                    labelText: 'اختيار مندوب الجمعية',
                    prefixIcon: Icon(Icons.badge_outlined),
                    border: OutlineInputBorder(),
                  ),
                  items: activeVolunteers.map((item) {
                    final itemId = item['id']?.toString() ?? '';
                    final itemName = item['name']?.toString() ?? 'مندوب';
                    final itemPhone = item['phone']?.toString() ?? '';
                    return DropdownMenuItem<String>(
                      value: itemId,
                      child: Text(
                          '$itemName${itemPhone.isEmpty ? '' : ' — $itemPhone'}'),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() => _selectedId = value);
                  },
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
            if (_internal && selectedVolunteer != null) ...[
              const SizedBox(height: 10),
              Text(
                'سيتم تعيين: ${selectedVolunteer['name'] ?? 'مندوب الجمعية'}',
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
            if (_internal) {
              if (selectedVolunteer == null) return;
              Navigator.pop(
                context,
                _VolunteerAssignment(
                  id: selectedVolunteer['id']?.toString(),
                  name: selectedVolunteer['name']?.toString().trim() ?? '',
                  phone: selectedVolunteer['phone']?.toString().trim() ?? '',
                ),
              );
              return;
            }
            if (widget.nameController.text.trim().isEmpty ||
                widget.phoneController.text.trim().isEmpty) {
              return;
            }
            Navigator.pop(
              context,
              const _VolunteerAssignment(id: null, name: '', phone: ''),
            );
          },
          child: const Text('تعيين المندوب'),
        ),
      ],
    );
  }
}

class _DonationCard extends StatelessWidget {
  final Map<String, dynamic> row;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final VoidCallback onAssign;
  final VoidCallback onDeparted;
  final VoidCallback onGenerateCode;
  final VoidCallback onVerifyCode;
  final VoidCallback onComplete;

  const _DonationCard(
      {required this.row,
      required this.onAccept,
      required this.onReject,
      required this.onAssign,
      required this.onDeparted,
      required this.onGenerateCode,
      required this.onVerifyCode,
      required this.onComplete});

  @override
  Widget build(BuildContext context) {
    final status = row['status']?.toString() ?? 'pending';
    final institution = row['institutions'] is Map
        ? Map<String, dynamic>.from(row['institutions'] as Map)
        : const <String, dynamic>{};
    final institutionName = institution['name']?.toString() ?? 'مؤسسة';
    final title = row['item_title']?.toString() ?? 'تبرع غذائي';
    return Card(
      elevation: 0,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF123F31))),
          const SizedBox(height: 6),
          Text(institutionName,
              style: const TextStyle(color: Color(0xFF71837C))),
          const SizedBox(height: 6),
          Text('الكمية: ${row['quantity'] ?? '—'}',
              style: const TextStyle(color: Color(0xFF66736D))),
          const SizedBox(height: 6),
          Text(_label(status),
              style: const TextStyle(
                  color: Color(0xFF0B7650), fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          if (status == 'pending')
            Row(children: [
              Expanded(
                  child: OutlinedButton(
                      onPressed: onReject, child: const Text('رفض'))),
              const SizedBox(width: 10),
              Expanded(
                  child: FilledButton(
                      onPressed: onAccept, child: const Text('قبول')))
            ])
          else if (status == 'accepted')
            SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                    onPressed: onAssign,
                    icon: const Icon(Icons.person_add_alt_1),
                    label: const Text('تعيين متطوع')))
          else if (status == 'volunteer_assigned')
            SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                    onPressed: onDeparted,
                    icon: const Icon(Icons.directions_walk),
                    label: const Text('المتطوع في الطريق')))
          else if (status == 'institution_ready')
            SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                    onPressed: onDeparted,
                    icon: const Icon(Icons.directions_walk),
                    label: const Text('تأكيد تحرك المتطوع')))
          else if (status == 'volunteer_departed')
            Row(children: [
              Expanded(
                  child: OutlinedButton(
                      onPressed: onGenerateCode,
                      child: const Text('إنشاء الكود'))),
              const SizedBox(width: 10),
              Expanded(
                  child: FilledButton(
                      onPressed: onVerifyCode,
                      child: const Text('تحقق من الكود')))
            ])
          else if (status == 'picked_up')
            SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                    onPressed: onComplete,
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('تأكيد وصول التبرع'))),
        ]),
      ),
    );
  }

  static String _label(String value) {
    switch (value) {
      case 'accepted':
        return 'تم قبول التبرع';
      case 'rejected':
        return 'تم رفض التبرع';
      case 'volunteer_assigned':
        return 'تم تعيين المتطوع';
      case 'institution_ready':
        return 'المؤسسة جاهزة';
      case 'volunteer_departed':
        return 'المتطوع في الطريق';
      case 'picked_up':
        return 'تم استلام التبرع';
      case 'completed':
        return 'تم الوصول بنجاح';
      default:
        return 'في انتظار المراجعة';
    }
  }
}
