import 'package:flutter/material.dart';
import 'package:loqma/features/charity/data/repositories/charity_donation_repository_separate.dart';
import 'direct_charity_qr_scanner_page.dart';

class DirectCharityVolunteerTasksPage extends StatefulWidget {
  const DirectCharityVolunteerTasksPage({super.key});
  @override
  State<DirectCharityVolunteerTasksPage> createState() =>
      _DirectCharityVolunteerTasksPageState();
}

class _DirectCharityVolunteerTasksPageState
    extends State<DirectCharityVolunteerTasksPage> {
  final _repo = SeparateCharityDonationRepository();
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _repo.getVolunteerDonations();
  }

  Future<void> _refresh() async {
    final next = _repo.getVolunteerDonations();
    if (!mounted) return;
    setState(() => _future = next);
    await next;
  }

  String _label(String status) =>
      {
        'volunteer_assigned': 'تم تعيينك لاستلام التبرع',
        'ready_for_pickup': 'جاهز للاستلام من المتبرع',
        'picked_up_from_donor': 'تم الاستلام من المتبرع',
        'in_transit': 'في الطريق للجمعية',
        'completed': 'اكتمل التبرع',
      }[status] ??
      'حالة التبرع: $status';

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('مهام التطوع'), actions: [
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
                    child: Text('تعذر تحميل المهام: ${snapshot.error}'));
              }
              final rows = snapshot.data ?? [];
              if (rows.isEmpty) {
                return const Center(
                    child: Text('لا توجد مهام تطوع مسندة إليك'));
              }
              return RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: rows.length,
                      itemBuilder: (_, index) {
                        final row = rows[index];
                        final status =
                            row['status']?.toString() ?? 'volunteer_assigned';
                        final requestId = row['id'].toString();
                        final canScan = status == 'ready_for_pickup';
                        return Card(
                            margin: const EdgeInsets.only(bottom: 14),
                            child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                          row['title']?.toString() ??
                                              'تبرع مباشر',
                                          style: const TextStyle(
                                              fontSize: 17,
                                              fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 7),
                                      Text(
                                          'الجمعية: ${row['charities'] is Map ? (row['charities'] as Map)['name'] ?? 'غير محددة' : 'غير محددة'}'),
                                      Text('الحالة: ${_label(status)}'),
                                      if (canScan) ...[
                                        const SizedBox(height: 12),
                                        SizedBox(
                                            width: double.infinity,
                                            child: FilledButton.icon(
                                                onPressed: () async {
                                                  final changed = await Navigator.push<
                                                          bool>(
                                                      context,
                                                      MaterialPageRoute(
                                                          builder: (_) =>
                                                              DirectCharityQrScannerPage(
                                                                  requestId:
                                                                      requestId)));
                                                  if (changed == true &&
                                                      mounted) {
                                                    _refresh();
                                                  }
                                                },
                                                icon: const Icon(
                                                    Icons.qr_code_scanner),
                                                label: const Text(
                                                    'مسح QR أو إدخال الكود'))),
                                      ],
                                    ])));
                      }));
            }),
      );
}
