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
  String _filter = 'all';
  String? _busyId;

  static const _green = Color(0xFF087A52);
  static const _deepGreen = Color(0xFF123D31);
  static const _mint = Color(0xFFE9F7F0);
  static const _background = Color(0xFFF5F8F6);

  static const _stages = [
    'pending',
    'accepted',
    'volunteer_assigned',
    'institution_ready',
    'volunteer_departed',
    'picked_up',
    'completed',
  ];

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? CharityInstitutionDonationsRepository();
    _future = _repository.listMyDonations();
  }

  Future<void> _reload() async {
    final future = _repository.listMyDonations();
    if (!mounted) return;
    setState(() => _future = future);
    try {
      await future;
    } catch (_) {
      // Surfaced by the FutureBuilder itself.
    }
  }

  Future<void> _accept(String id, bool accept) async {
    setState(() => _busyId = id);
    try {
      await _repository.acceptDonation(id, accept);
      if (!mounted) return;
      _toast(accept ? 'تم قبول التبرع' : 'تم رفض التبرع');
      await _reload();
    } catch (_) {
      if (mounted) _toast('تعذر تحديث حالة التبرع', error: true);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _assignVolunteer(String id) async {
    List<Map<String, dynamic>> volunteers;
    try {
      volunteers = await _repository.listCharityVolunteers();
    } catch (_) {
      if (mounted) _toast('تعذر تحميل متطوعي الجمعية', error: true);
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
    setState(() => _busyId = id);
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
      if (mounted)
        _toast('تعذر تعيين المتطوع. راجع بيانات الاختيار', error: true);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _departed(String id) async {
    setState(() => _busyId = id);
    try {
      await _repository.markVolunteerDeparted(id);
      if (!mounted) return;
      _toast('تم تسجيل أن المتطوع في الطريق');
      await _reload();
    } catch (_) {
      if (mounted) _toast('تعذر تحديث حالة المتطوع', error: true);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _generateCode(String id) async {
    try {
      final result = await _repository.generatePickupCode(id);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
            title: const Text('كود استلام التبرع',
                style: TextStyle(fontWeight: FontWeight.w900)),
            content: Container(
              padding: const EdgeInsets.symmetric(vertical: 18),
              decoration: BoxDecoration(
                color: _mint,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                result['pickup_code']?.toString() ?? 'تم إنشاء الكود',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 7,
                    color: _green),
              ),
            ),
            actions: [
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: _green,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('تم'),
                ),
              ),
            ],
          ),
        ),
      );
    } catch (_) {
      if (mounted) _toast('تعذر إنشاء كود الاستلام', error: true);
    }
  }

  Future<void> _verifyCode(String id) async {
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: const Text('التحقق من كود الاستلام',
              style: TextStyle(fontWeight: FontWeight.w900)),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            maxLength: 6,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 6),
            decoration: const InputDecoration(
              hintText: '000000',
              counterText: '',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إلغاء')),
            FilledButton(
                style: FilledButton.styleFrom(backgroundColor: _green),
                onPressed: () => Navigator.pop(context, controller.text.trim()),
                child: const Text('تحقق')),
          ],
        ),
      ),
    );
    controller.dispose();
    if (code == null) return;
    if (code.length != 6) {
      if (mounted) _toast('اكتب كودًا مكونًا من 6 أرقام', error: true);
      return;
    }
    setState(() => _busyId = id);
    try {
      await _repository.verifyPickupCode(donationId: id, code: code);
      if (!mounted) return;
      _toast('تم التحقق واستلام التبرع');
      await _reload();
    } catch (_) {
      if (mounted) _toast('كود الاستلام غير صحيح أو منتهي', error: true);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _complete(String id) async {
    setState(() => _busyId = id);
    try {
      await _repository.confirmArrival(id);
      if (!mounted) return;
      _toast('تم تأكيد وصول التبرع');
      await _reload();
    } catch (_) {
      if (mounted) _toast('تعذر تأكيد وصول التبرع', error: true);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  void _toast(String text, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: error ? const Color(0xFFD64545) : _deepGreen,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  bool _matches(Map<String, dynamic> row) {
    final status = row['status']?.toString() ?? 'pending';
    switch (_filter) {
      case 'all':
        return true;
      case 'pending':
        return status == 'pending';
      case 'in_progress':
        return [
          'accepted',
          'volunteer_assigned',
          'institution_ready',
          'volunteer_departed',
          'picked_up',
        ].contains(status);
      case 'completed':
        return status == 'completed';
      default:
        return true;
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
          title: const Text('تبرعات المؤسسات',
              style: TextStyle(fontWeight: FontWeight.w900)),
          actions: [
            IconButton(
              onPressed: _reload,
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'تحديث',
            ),
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
                'تعذر تحميل التبرعات، تحقق من الاتصال',
                Icons.cloud_off_rounded,
                actionLabel: 'إعادة المحاولة',
                onAction: _reload,
              );
            }
            final all = snapshot.data ?? const <Map<String, dynamic>>[];
            final rows = all.where(_matches).toList();
            return RefreshIndicator(
              color: _green,
              onRefresh: _reload,
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
                    _emptyState('لا توجد تبرعات مؤسسات في هذا القسم',
                        Icons.inbox_rounded)
                  else
                    ...rows.map((row) => _DonationCard(
                          row: row,
                          busy: _busyId == row['id']?.toString(),
                          onAccept: () => _accept(row['id'].toString(), true),
                          onReject: () => _accept(row['id'].toString(), false),
                          onAssign: () =>
                              _assignVolunteer(row['id'].toString()),
                          onDeparted: () => _departed(row['id'].toString()),
                          onGenerateCode: () =>
                              _generateCode(row['id'].toString()),
                          onVerifyCode: () => _verifyCode(row['id'].toString()),
                          onComplete: () => _complete(row['id'].toString()),
                        )),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _hero(List<Map<String, dynamic>> rows) {
    final pending =
        rows.where((r) => r['status']?.toString() == 'pending').length;
    return Container(
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
              const Text('تبرعات المؤسسات والمطاعم',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 21,
                      fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Text(
                pending > 0
                    ? '$pending تبرع بانتظار ردك'
                    : '${rows.length} تبرع قيد المتابعة',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 18),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                    color: Colors.white.withAlpha(35),
                    borderRadius: BorderRadius.circular(30)),
                child: const Text('تابع كل خطوة من القبول للاستلام',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 12)),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
              color: Colors.white.withAlpha(35), shape: BoxShape.circle),
          child: const Icon(Icons.storefront_rounded,
              color: Colors.white, size: 32),
        ),
      ]),
    );
  }

  Widget _stats(List<Map<String, dynamic>> rows) {
    int count(bool Function(String) test) =>
        rows.where((r) => test(r['status']?.toString() ?? 'pending')).length;
    return Row(children: [
      Expanded(
          child: _statCard('الجديدة', count((s) => s == 'pending').toString(),
              Icons.mark_email_unread_rounded, const Color(0xFFFFA62B))),
      const SizedBox(width: 10),
      Expanded(
          child: _statCard(
              'قيد التنفيذ',
              count((s) => [
                    'accepted',
                    'volunteer_assigned',
                    'institution_ready',
                    'volunteer_departed',
                    'picked_up',
                  ].contains(s)).toString(),
              Icons.route_rounded,
              const Color(0xFF3E83C5))),
      const SizedBox(width: 10),
      Expanded(
          child: _statCard('مكتملة', count((s) => s == 'completed').toString(),
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
      'in_progress': 'قيد التنفيذ',
      'completed': 'مكتمل',
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
            side:
                BorderSide(color: selected ? _green : const Color(0xFFE1ECE6)),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          );
        },
      ),
    );
  }

  Widget _emptyState(String text, IconData icon,
      {String? actionLabel, VoidCallback? onAction}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 70),
      child: Column(children: [
        Icon(icon, color: _green, size: 54),
        const SizedBox(height: 15),
        Text(text,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: _deepGreen, fontSize: 15, fontWeight: FontWeight.w800)),
        if (actionLabel != null && onAction != null) ...[
          const SizedBox(height: 14),
          FilledButton.tonal(onPressed: onAction, child: Text(actionLabel)),
        ],
      ]),
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

  static const _green = Color(0xFF087A52);

  @override
  Widget build(BuildContext context) {
    final activeVolunteers = widget.volunteers;
    final selected = activeVolunteers
        .where((item) => item['id']?.toString() == _selectedId)
        .toList();
    final selectedVolunteer = selected.isEmpty ? null : selected.first;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text('تعيين مندوب التبرع',
            style: TextStyle(fontWeight: FontWeight.w900)),
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
            style: FilledButton.styleFrom(backgroundColor: _green),
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
      ),
    );
  }
}

// REDESIGNED: hero image (falls back to a gradient + icon when the donation
// has no photos) with the title, institution name and status pill overlaid,
// a slim quantity/info row, a step timeline, and the same action buttons as
// before — same callbacks, same behaviour, entirely new look.
class _DonationCard extends StatelessWidget {
  final Map<String, dynamic> row;
  final bool busy;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final VoidCallback onAssign;
  final VoidCallback onDeparted;
  final VoidCallback onGenerateCode;
  final VoidCallback onVerifyCode;
  final VoidCallback onComplete;

  static const _green = Color(0xFF087A52);
  static const _deepGreen = Color(0xFF123D31);
  static const _mint = Color(0xFFE9F7F0);

  static const _stages = [
    'pending',
    'accepted',
    'volunteer_assigned',
    'institution_ready',
    'volunteer_departed',
    'picked_up',
    'completed',
  ];

  const _DonationCard({
    required this.row,
    required this.busy,
    required this.onAccept,
    required this.onReject,
    required this.onAssign,
    required this.onDeparted,
    required this.onGenerateCode,
    required this.onVerifyCode,
    required this.onComplete,
  });

  List<String> get _images {
    final raw = row['images'];
    if (raw is! List) return const [];
    return raw
        .map((value) => value.toString())
        .where((url) => url.startsWith('http'))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final status = row['status']?.toString() ?? 'pending';
    final institution = row['institutions'] is Map
        ? Map<String, dynamic>.from(row['institutions'] as Map)
        : const <String, dynamic>{};
    final institutionName = institution['name']?.toString() ?? 'مؤسسة';
    final title = row['item_title']?.toString() ?? 'تبرع غذائي';
    final images = _images;
    final heroImage = images.isNotEmpty ? images.first : null;
    final volunteerName = row['volunteer_name']?.toString().trim() ?? '';
    final volunteerPhone = row['volunteer_phone']?.toString().trim() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE0EBE5)),
        boxShadow: [
          BoxShadow(
              color: _deepGreen.withAlpha(18),
              blurRadius: 20,
              offset: const Offset(0, 10)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 160,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                heroImage == null
                    ? const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [_deepGreen, _green],
                            begin: Alignment.topRight,
                            end: Alignment.bottomLeft,
                          ),
                        ),
                        child: Center(
                          child: Icon(Icons.storefront_rounded,
                              color: Colors.white, size: 44),
                        ),
                      )
                    : Image.network(
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
                                color: Colors.white, size: 38),
                          ),
                        ),
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
                          Colors.black.withAlpha(195),
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
                  left: 14,
                  right: 14,
                  bottom: 12,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(Icons.storefront_rounded,
                              color: Colors.white70, size: 13),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              institutionName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withAlpha(215),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
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
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FBF9),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.inventory_2_outlined,
                          color: _green, size: 18),
                      const SizedBox(width: 6),
                      Text('الكمية: ${row['quantity'] ?? '—'}',
                          style: const TextStyle(
                              color: _deepGreen,
                              fontSize: 12,
                              fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
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
                        const Icon(Icons.badge_outlined,
                            color: _green, size: 22),
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
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 15),
                _timeline(status),
                if (busy)
                  const Padding(
                    padding: EdgeInsets.only(top: 14),
                    child: LinearProgressIndicator(color: _green),
                  ),
                if (!busy) ...[
                  const SizedBox(height: 14),
                  _actions(status),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actions(String status) {
    switch (status) {
      case 'pending':
        return Row(children: [
          Expanded(
              child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFB54747),
                    side: const BorderSide(color: Color(0xFFF0C9C9)),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15)),
                  ),
                  onPressed: onReject,
                  icon: const Icon(Icons.close_rounded, size: 18),
                  label: const Text('رفض'))),
          const SizedBox(width: 10),
          Expanded(
              child: _action('قبول التبرع', Icons.check_rounded, onAccept)),
        ]);
      case 'accepted':
        return _action('تعيين متطوع', Icons.person_add_alt_1_rounded, onAssign);
      case 'volunteer_assigned':
        return _action(
            'المتطوع في الطريق', Icons.directions_walk_rounded, onDeparted);
      case 'institution_ready':
        return _action(
            'تأكيد تحرك المتطوع', Icons.directions_walk_rounded, onDeparted);
      case 'volunteer_departed':
        return Row(children: [
          Expanded(
              child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _green,
                    side: const BorderSide(color: Color(0xFFCBE6D5)),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15)),
                  ),
                  onPressed: onGenerateCode,
                  icon: const Icon(Icons.qr_code_rounded, size: 18),
                  label: const Text('إنشاء الكود'))),
          const SizedBox(width: 10),
          Expanded(
              child: _action(
                  'تحقق من الكود', Icons.verified_user_outlined, onVerifyCode)),
        ]);
      case 'picked_up':
        return _action('تأكيد وصول التبرع', Icons.task_alt_rounded, onComplete);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _action(String text, IconData icon, VoidCallback onPressed) =>
      SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: _green,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 13),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          ),
          onPressed: onPressed,
          icon: Icon(icon, size: 19),
          label:
              Text(text, style: const TextStyle(fontWeight: FontWeight.w800)),
        ),
      );

  Widget _statusPill(String status) {
    final data = _statusData(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
          color: data.$2, borderRadius: BorderRadius.circular(20)),
      child: Text(data.$1,
          style: TextStyle(
              color: data.$3, fontSize: 10, fontWeight: FontWeight.w900)),
    );
  }

  (String, Color, Color) _statusData(String status) =>
      {
        'pending': (
          'في انتظار المراجعة',
          const Color(0xFFFFF1D8),
          const Color(0xFF9A6711)
        ),
        'accepted': (
          'تم القبول',
          const Color(0xFFE5F2FF),
          const Color(0xFF2F6DA5)
        ),
        'volunteer_assigned': (
          'تم تعيين المتطوع',
          const Color(0xFFECE8FF),
          const Color(0xFF6651B5)
        ),
        'institution_ready': (
          'المؤسسة جاهزة',
          const Color(0xFFFFF1D8),
          const Color(0xFF9A6711)
        ),
        'volunteer_departed': (
          'المتطوع في الطريق',
          const Color(0xFFE5F2FF),
          const Color(0xFF2F6DA5)
        ),
        'picked_up': (
          'تم استلام التبرع',
          const Color(0xFFE5F2FF),
          const Color(0xFF2F6DA5)
        ),
        'completed': ('تم الوصول بنجاح', const Color(0xFFE3F7EC), _green),
        'rejected': (
          'تم رفض التبرع',
          const Color(0xFFFBE4E4),
          const Color(0xFFB54747)
        ),
      }[status] ??
      ('في انتظار المراجعة', const Color(0xFFF0F1F0), Colors.black54);

  Widget _timeline(String status) {
    final current = _stages.indexOf(status);
    return SizedBox(
      height: 55,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: List.generate(_stages.length, (index) {
            final done = current >= index && current >= 0;
            return Row(
              children: [
                if (index > 0)
                  SizedBox(
                    width: 28,
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
                          ? const Icon(Icons.check_rounded,
                              size: 12, color: Colors.white)
                          : null,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _stageLabel(_stages[index]),
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
        'volunteer_assigned': 'متطوع',
        'institution_ready': 'جاهز',
        'volunteer_departed': 'طريق',
        'picked_up': 'استلام',
        'completed': 'وصل',
      }[stage] ??
      '';
}
