import 'package:flutter/material.dart';
import 'package:loqma/features/charity/data/repositories/charity_donation_repository_separate.dart';

class CharityVolunteersPage extends StatefulWidget {
  const CharityVolunteersPage({super.key});

  @override
  State<CharityVolunteersPage> createState() => _CharityVolunteersPageState();
}

class _CharityVolunteersPageState extends State<CharityVolunteersPage> {
  final _repository = SeparateCharityDonationRepository();
  late Future<List<Map<String, dynamic>>> _future;
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _statusFilter = 'all';
  String? _busyId;
  static const green = Color(0xFF087A52);
  static const deepGreen = Color(0xFF123D31);
  static const background = Color(0xFFF5F8F6);

  @override
  void initState() {
    super.initState();
    _future = _load();
    _searchController.addListener(() {
      if (mounted) {
        setState(
            () => _searchQuery = _searchController.text.trim().toLowerCase());
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _load() =>
      _repository.getCharityVolunteers();

  Future<void> _refresh() async {
    final next = _load();
    setState(() => _future = next);
    try {
      await next;
    } catch (error) {
      if (mounted) _message(_friendly(error), error: true);
    }
  }

  Future<void> _openEditor({Map<String, dynamic>? volunteer}) async {
    final name =
        TextEditingController(text: volunteer?['name']?.toString() ?? '');
    final phone =
        TextEditingController(text: volunteer?['phone']?.toString() ?? '');
    String status =
        volunteer?['status']?.toString() == 'inactive' ? 'inactive' : 'active';
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title:
              Text(volunteer == null ? 'إضافة متطوع' : 'تعديل بيانات المتطوع'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                  controller: name,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                      labelText: 'اسم المتطوع',
                      prefixIcon: Icon(Icons.person_outline))),
              const SizedBox(height: 12),
              TextField(
                  controller: phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                      labelText: 'رقم الهاتف',
                      prefixIcon: Icon(Icons.phone_outlined))),
              if (volunteer != null) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                    initialValue: status,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'الحالة'),
                    items: const [
                      DropdownMenuItem(value: 'active', child: Text('نشط')),
                      DropdownMenuItem(
                          value: 'inactive', child: Text('متوقف مؤقتًا'))
                    ],
                    onChanged: (value) =>
                        setDialogState(() => status = value ?? 'active')),
              ],
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('إلغاء')),
            FilledButton(
                onPressed: () {
                  if (name.text.trim().length < 2 ||
                      phone.text.trim().length < 6) {
                    return;
                  }
                  Navigator.pop(dialogContext, true);
                },
                child: const Text('حفظ')),
          ],
        ),
      ),
    );
    if (result != true || !mounted) return;
    setState(() => _busyId = volunteer?['id']?.toString() ?? 'new');
    try {
      if (volunteer == null) {
        await _repository.createCharityVolunteer(
            name: name.text, phone: phone.text);
        _message('تمت إضافة المتطوع');
      } else {
        await _repository.updateCharityVolunteer(
            id: volunteer['id'].toString(),
            name: name.text,
            phone: phone.text,
            status: status);
        _message('تم تحديث بيانات المتطوع');
      }
      await _refresh();
    } catch (error) {
      if (mounted) _message(_friendly(error), error: true);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _delete(Map<String, dynamic> volunteer) async {
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
                title: const Text('حذف المتطوع'),
                content:
                    Text('هل تريد حذف ${volunteer['name'] ?? 'هذا المتطوع'}؟'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: const Text('إلغاء')),
                  FilledButton(
                      style: FilledButton.styleFrom(
                          backgroundColor: Colors.red.shade700),
                      onPressed: () => Navigator.pop(dialogContext, true),
                      child: const Text('حذف'))
                ]));
    if (confirmed != true || !mounted) return;
    setState(() => _busyId = volunteer['id']?.toString());
    try {
      await _repository.deleteCharityVolunteer(volunteer['id'].toString());
      await _refresh();
      if (mounted) _message('تم حذف المتطوع');
    } catch (error) {
      if (mounted) _message(_friendly(error), error: true);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  String _friendly(Object error) {
    final text = error.toString().replaceFirst('Exception: ', '');
    if (text.contains('صلاحية')) {
      return 'ليس لديك صلاحية لإدارة متطوعي هذه الجمعية';
    }
    if (text.contains('متطوع')) return text;
    if (text.toLowerCase().contains('network') ||
        text.toLowerCase().contains('timeout')) {
      return 'تعذر الاتصال بالإنترنت';
    }
    return 'تعذر تنفيذ العملية، حاول مرة أخرى';
  }

  void _message(String message, {bool error = false}) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(message, textDirection: TextDirection.rtl),
          backgroundColor: error ? Colors.red.shade700 : green,
          behavior: SnackBarBehavior.floating));

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: background,
        appBar: AppBar(
          backgroundColor: background,
          foregroundColor: deepGreen,
          elevation: 0,
          title: const Text('متطوعو الجمعية',
              style: TextStyle(fontWeight: FontWeight.w900)),
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
              return Center(
                  child: Text(_friendly(snapshot.error!),
                      textAlign: TextAlign.center));
            }
            final allRows = snapshot.data ?? <Map<String, dynamic>>[];
            final rows = allRows.where(_matches).toList();
            return RefreshIndicator(
              color: green,
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.all(18),
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [Color(0xFF087A52), Color(0xFF27B47E)]),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('فريق الجمعية',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900)),
                              SizedBox(height: 7),
                              Text('أضف المندوبين الذين يمكنهم استلام التبرعات',
                                  style: TextStyle(color: Colors.white70)),
                            ],
                          ),
                        ),
                        CircleAvatar(
                          radius: 27,
                          backgroundColor: Colors.white24,
                          child: Text(
                            allRows.length.toString(),
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w900),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  _stats(allRows),
                  const SizedBox(height: 18),
                  _searchField(),
                  const SizedBox(height: 12),
                  _filters(),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => _openEditor(),
                      icon: const Icon(Icons.person_add_alt_1_rounded),
                      label: const Text('إضافة متطوع'),
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (rows.isEmpty) _empty() else ...rows.map(_card),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _stats(List<Map<String, dynamic>> rows) {
    final active =
        rows.where((row) => row['status']?.toString() == 'active').length;
    final inactive = rows.length - active;
    return Row(children: [
      Expanded(
          child: _statCard('إجمالي المتطوعين', rows.length.toString(),
              Icons.groups_rounded, green)),
      const SizedBox(width: 10),
      Expanded(
          child: _statCard('متطوع نشط', active.toString(),
              Icons.verified_rounded, const Color(0xFF2F8F66))),
      const SizedBox(width: 10),
      Expanded(
          child: _statCard('متوقف مؤقتًا', inactive.toString(),
              Icons.pause_circle_outline_rounded, const Color(0xFF9A6711))),
    ]);
  }

  Widget _statCard(String label, String value, IconData icon, Color color) =>
      Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 13),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE1E8E4)),
              boxShadow: const [
                BoxShadow(
                    color: Color(0x08000000),
                    blurRadius: 10,
                    offset: Offset(0, 3))
              ]),
          child: Column(children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(value,
                style: const TextStyle(
                    color: deepGreen,
                    fontSize: 20,
                    fontWeight: FontWeight.w900)),
            const SizedBox(height: 2),
            Text(label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 10,
                    fontWeight: FontWeight.w700))
          ]));

  Widget _searchField() => Container(
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFC0C8C3))),
      child: TextField(
          controller: _searchController,
          textDirection: TextDirection.rtl,
          decoration: const InputDecoration(
              hintText: 'ابحث عن متطوع بالاسم أو الهاتف...',
              prefixIcon: Icon(Icons.search_rounded, color: Color(0xFF717974)),
              border: InputBorder.none,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 16, vertical: 14))));

  Widget _filters() {
    const filters = {'all': 'الكل', 'active': 'نشط', 'inactive': 'غير نشط'};
    return SizedBox(
        height: 38,
        child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: filters.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, index) {
              final key = filters.keys.elementAt(index);
              final selected = _statusFilter == key;
              return FilterChip(
                  selected: selected,
                  onSelected: (_) => setState(() => _statusFilter = key),
                  label: Text(filters[key]!),
                  selectedColor: const Color(0xFF97F2C3),
                  backgroundColor: Colors.white,
                  checkmarkColor: deepGreen,
                  side: BorderSide(
                      color: selected ? green : const Color(0xFFC0C8C3)),
                  labelStyle: TextStyle(
                      color: selected ? deepGreen : Colors.black54,
                      fontWeight: FontWeight.w800));
            }));
  }

  bool _matches(Map<String, dynamic> row) {
    final status = row['status']?.toString() ?? 'active';
    if (_statusFilter != 'all' && status != _statusFilter) return false;
    if (_searchQuery.isEmpty) return true;
    final text = '${row['name'] ?? ''} ${row['phone'] ?? ''}'.toLowerCase();
    return text.contains(_searchQuery);
  }

  Widget _card(Map<String, dynamic> row) {
    final id = row['id']?.toString() ?? '';
    final active = row['status']?.toString() == 'active';
    final busy = _busyId == id;
    return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
                color:
                    active ? const Color(0xFFBFE6D0) : const Color(0xFFE7D9B8),
                width: 1.2),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x08000000),
                  blurRadius: 12,
                  offset: Offset(0, 4))
            ]),
        child: Row(children: [
          CircleAvatar(
              backgroundColor:
                  active ? const Color(0xFFE3F7EC) : const Color(0xFFF0F1F0),
              child: Icon(Icons.person, color: active ? green : Colors.grey)),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(row['name']?.toString() ?? 'بدون اسم',
                    style: const TextStyle(
                        color: deepGreen, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(row['phone']?.toString() ?? 'بدون هاتف',
                    style: const TextStyle(color: Colors.black54)),
                const SizedBox(height: 5),
                Text(active ? 'نشط ويمكن اختياره للاستلام' : 'متوقف مؤقتًا',
                    style: TextStyle(
                        color: active ? green : Colors.grey,
                        fontSize: 11,
                        fontWeight: FontWeight.w700))
              ])),
          if (busy)
            const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: green))
          else
            PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') _openEditor(volunteer: row);
                  if (value == 'delete') _delete(row);
                },
                itemBuilder: (_) => const [
                      PopupMenuItem(
                          value: 'edit', child: Text('تعديل الحالة والبيانات')),
                      PopupMenuItem(value: 'delete', child: Text('حذف المتطوع'))
                    ])
        ]));
  }

  Widget _empty() => Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: const Column(children: [
        Icon(Icons.groups_outlined, size: 48, color: green),
        SizedBox(height: 10),
        Text('لا يوجد متطوعون بعد',
            style: TextStyle(color: deepGreen, fontWeight: FontWeight.w900)),
        SizedBox(height: 5),
        Text('أضف أول متطوع ليظهر في قائمة تعيين مندوب الاستلام',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black54))
      ]));
}
