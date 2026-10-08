import 'package:flutter/material.dart';
import 'package:loqma/features/swap/data/swap_repository.dart';

class SwapReportsPage extends StatefulWidget {
  const SwapReportsPage({super.key});

  @override
  State<SwapReportsPage> createState() => _SwapReportsPageState();
}

class _SwapReportsPageState extends State<SwapReportsPage> {
  final _repo = SwapRepository();
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _repo.listSwapReports();
  }

  void _reload() {
    final future = _repo.listSwapReports();
    setState(() {
      _future = future;
    });
  }

  Future<void> _refresh() async {
    final future = _repo.listSwapReports();
    setState(() {
      _future = future;
    });
    await future;
  }

  Future<void> _update(Map<String, dynamic> report, String status) async {
    try {
      await _repo.updateSwapReportStatus(
        reportId: report['id'].toString(),
        status: status,
        resolution: status == 'resolved'
            ? 'تمت مراجعة البلاغ واتخاذ الإجراء المناسب.'
            : status == 'dismissed'
                ? 'تمت مراجعة البلاغ ولم يثبت وجود مخالفة.'
                : null,
      );
      if (mounted) {
        _reload();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تحديث حالة البلاغ')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر تحديث البلاغ')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('بلاغات الاستبدالات',
              style: TextStyle(fontWeight: FontWeight.w900)),
          actions: [
            IconButton(
                onPressed: _reload,
                tooltip: 'تحديث',
                icon: const Icon(Icons.refresh_rounded)),
          ],
        ),
        body: FutureBuilder<List<Map<String, dynamic>>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Text('تعذر تحميل البلاغات. تأكد من صلاحيات الإدارة.'),
              );
            }
            final reports = snapshot.data ?? const [];
            if (reports.isEmpty) {
              return const Center(child: Text('لا توجد بلاغات حاليًا'));
            }
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                itemCount: reports.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, index) => _ReportCard(
                  report: reports[index],
                  onStatus: (status) => _update(reports[index], status),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  final Map<String, dynamic> report;
  final ValueChanged<String> onStatus;
  const _ReportCard({required this.report, required this.onStatus});

  String _reason(String? value) => const {
        'fraud': 'إعلان مضلل أو احتيالي',
        'inappropriate': 'محتوى غير مناسب',
        'wrong_contact': 'رقم التواصل غير صحيح',
        'duplicate': 'إعلان مكرر',
        'other': 'سبب آخر',
      }[value] ?? 'بلاغ';

  String _status(String? value) => const {
        'open': 'مفتوح',
        'reviewing': 'قيد المراجعة',
        'resolved': 'تم الحل',
        'dismissed': 'مرفوض',
      }[value] ?? 'غير معروف';

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final listing = report['swap_listings'] as Map?;
    final reporter = report['reporter'] as Map?;
    final status = report['status']?.toString() ?? 'open';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Text(listing?['wanted_title']?.toString() ?? 'إعلان استبدال',
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
            ),
            Chip(label: Text(_status(status))),
          ]),
          const SizedBox(height: 8),
          Text('السبب: ${_reason(report['reason']?.toString())}'),
          if (report['details']?.toString().trim().isNotEmpty == true) ...[
            const SizedBox(height: 6),
            Text('التفاصيل: ${report['details']}'),
          ],
          const SizedBox(height: 6),
          Text(
            'المُبلّغ: ${reporter?['name'] ?? reporter?['phone'] ?? report['reporter_id'] ?? 'غير معروف'}',
            style: TextStyle(color: c.onSurfaceVariant, fontSize: 12),
          ),
          if (status == 'open' || status == 'reviewing') ...[
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              OutlinedButton(
                  onPressed: () => onStatus('reviewing'),
                  child: const Text('قيد المراجعة')),
              FilledButton(
                  onPressed: () => onStatus('resolved'),
                  child: const Text('تم الحل')),
              TextButton(
                  onPressed: () => onStatus('dismissed'),
                  child: const Text('رفض البلاغ')),
            ]),
          ],
        ]),
      ),
    );
  }
}
