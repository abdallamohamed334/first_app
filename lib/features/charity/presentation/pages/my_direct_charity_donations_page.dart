import 'package:flutter/material.dart';
import 'package:loqma/features/charity/data/repositories/charity_donation_repository_separate.dart';

class MyDirectCharityDonationsPage extends StatefulWidget {
  const MyDirectCharityDonationsPage({super.key});
  @override
  State<MyDirectCharityDonationsPage> createState() =>
      _MyDirectCharityDonationsPageState();
}

class _MyDirectCharityDonationsPageState
    extends State<MyDirectCharityDonationsPage> {
  final _repo = SeparateCharityDonationRepository();
  late Future<List<Map<String, dynamic>>> _future;
  String? _loadingId;

  static const steps = <String>[
    'pending',
    'accepted',
    'volunteer_assigned',
    'ready_for_pickup',
    'picked_up_from_donor',
    'in_transit',
    'completed',
  ];

  @override
  void initState() {
    super.initState();
    _future = _repo.getMyDonations();
  }

  Future<void> _refresh() async {
    final next = _repo.getMyDonations();
    if (!mounted) return;
    setState(() {
      _future = next;
    });
    await next;
  }

  Future<void> _showCode(String id) async {
    setState(() => _loadingId = id);
    try {
      final token = await _repo.generatePickupToken(id);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('كود استلام التبرع'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('اعرض هذا الكود للمتطوع عند استلام التبرع من منزلك.'),
            const SizedBox(height: 18),
            SelectableText(token,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2)),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إغلاق'))
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _loadingId = null);
    }
  }

  String _label(String status) =>
      {
        'pending': 'في انتظار قبول الجمعية',
        'accepted': 'قبلت الجمعية التبرع',
        'volunteer_assigned': 'تم تعيين المتطوع',
        'ready_for_pickup': 'جاهز للاستلام من المتبرع',
        'picked_up_from_donor': 'استلمه المتطوع من المتبرع',
        'in_transit': 'المتبرع في الطريق للجمعية',
        'completed': 'وصل للجمعية واكتمل',
        'rejected': 'تم رفض التبرع',
        'cancelled': 'تم إلغاء التبرع',
      }[status] ??
      'حالة غير معروفة ($status)';

  int _stepIndex(String status) {
    final index = steps.indexOf(status);
    return index < 0 ? 0 : index;
  }

  Widget _timeline(String status) {
    final current = _stepIndex(status);
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(steps.length, (index) {
          final done =
              index <= current && status != 'rejected' && status != 'cancelled';
          final active = index == current;
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Column(children: [
              Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: done
                          ? const Color(0xFF0B7650)
                          : Colors.grey.shade300),
                  child: done
                      ? const Icon(Icons.check, size: 13, color: Colors.white)
                      : null),
              if (index < steps.length - 1)
                Container(
                    width: 2,
                    height: 28,
                    color: index < current
                        ? const Color(0xFF0B7650)
                        : Colors.grey.shade300),
            ]),
            const SizedBox(width: 10),
            Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Text(_label(steps[index]),
                    style: TextStyle(
                        fontWeight: active ? FontWeight.w900 : FontWeight.w500,
                        color: active
                            ? const Color(0xFF0B7650)
                            : Colors.black54))),
          ]);
        }));
  }

  Widget _card(Map<String, dynamic> row) {
    final id = row['id'].toString();
    final status = row['status']?.toString() ?? 'pending';
    final charity = row['charities'] is Map
        ? Map<String, dynamic>.from(row['charities'] as Map)
        : <String, dynamic>{};
    final canShowCode = status == 'ready_for_pickup';
    return Card(
        margin: const EdgeInsets.only(bottom: 16),
        child: Padding(
            padding: const EdgeInsets.all(16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(row['title']?.toString() ?? 'تبرع مباشر',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 5),
              Text('الجمعية: ${charity['name'] ?? 'غير محددة'}'),
              Text('الكمية: ${row['quantity'] ?? 1}'),
              const Divider(height: 25),
              Text('الحالة الحالية: ${_label(status)}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: Color(0xFF0B7650))),
              const SizedBox(height: 12),
              _timeline(status),
              if (canShowCode) ...[
                const SizedBox(height: 14),
                SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                        onPressed:
                            _loadingId == id ? null : () => _showCode(id),
                        icon: const Icon(Icons.qr_code_2),
                        label: Text(_loadingId == id
                            ? 'جارٍ إنشاء الكود...'
                            : 'عرض كود الاستلام'))),
              ],
            ])));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('تبرعاتي للجمعيات'), actions: [
          IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh))
        ]),
        body: FutureBuilder<List<Map<String, dynamic>>>(
            future: _future,
            builder: (_, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                    child: Text('تعذر تحميل التبرعات: ${snapshot.error}'));
              }
              final rows = snapshot.data ?? [];
              if (rows.isEmpty) {
                return const Center(child: Text('لا توجد تبرعات مباشرة'));
              }
              return RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: rows.length,
                      itemBuilder: (_, i) => _card(rows[i])));
            }),
      );
}
