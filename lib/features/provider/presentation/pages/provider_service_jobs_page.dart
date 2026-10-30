import 'package:flutter/material.dart';

import 'package:loqma/features/provider/data/repositories/service_job_repository.dart';
import 'package:loqma/features/provider/data/repositories/service_provider_repository.dart';
import 'complete_service_job_page.dart';

class ProviderServiceJobsPage extends StatefulWidget {
  const ProviderServiceJobsPage({super.key});

  @override
  State<ProviderServiceJobsPage> createState() => _ProviderServiceJobsPageState();
}

class _ProviderServiceJobsPageState extends State<ProviderServiceJobsPage> {
  final _providerRepository = ServiceProviderRepository();
  final _jobsRepository = ServiceJobRepository();
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _requests = [];
  List<Map<String, dynamic>> _completions = [];

  static const _blue = Color(0xFF3679C8);
  static const _green = Color(0xFF0B7650);
  static const _ink = Color(0xFF123F31);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await _providerRepository.getCurrentProvider();
    if (!mounted) return;
    await result.fold(
      (error) async => setState(() {
        _loading = false;
        _error = error;
      }),
      (provider) async {
        final providerId = provider['id'].toString();
        try {
          final requests = await _jobsRepository.acceptedRequests(providerId);
          final completions = await _jobsRepository.providerCompletions(providerId);
          if (!mounted) return;
          setState(() {
            _requests = requests;
            _completions = completions;
            _loading = false;
          });
        } catch (error) {
          if (!mounted) return;
          setState(() {
            _loading = false;
            _error = error.toString().replaceFirst('Exception: ', '');
          });
        }
      },
    );
  }

  Future<void> _finish(Map<String, dynamic> request) async {
    final done = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => CompleteServiceJobPage(request: request)),
    );
    if (done == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إرسال الشغلانة للعميل للتأكيد')),
      );
      _load();
    }
  }

  String _date(dynamic value) {
    final parsed = DateTime.tryParse(value?.toString() ?? '');
    if (parsed == null) return '—';
    return '${parsed.day}/${parsed.month}/${parsed.year}';
  }

  String _status(String status) {
    switch (status) {
      case 'confirmed':
        return 'مؤكدة من العميل ✓';
      case 'unconfirmed':
        return 'غير مؤكدة';
      case 'disputed':
        return 'محجوبة للمراجعة';
      default:
        return 'في انتظار تأكيد العميل';
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'confirmed':
        return _green;
      case 'disputed':
        return Colors.red.shade700;
      case 'unconfirmed':
        return Colors.orange.shade800;
      default:
        return _blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final confirmedCount = _completions.where((row) => row['status'] == 'confirmed').length;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('طلبات الخدمة والأعمال'),
          actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded))],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text(_error!))
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _counterCard(confirmedCount),
                        const SizedBox(height: 20),
                        _sectionTitle('الطلبات المقبولة'),
                        const SizedBox(height: 8),
                        if (_requests.isEmpty)
                          _empty('لا توجد طلبات مقبولة تحتاج إلى إنهاء')
                        else
                          ..._requests.map(_requestCard),
                        const SizedBox(height: 22),
                        _sectionTitle('الأعمال المنفذة'),
                        const SizedBox(height: 8),
                        if (_completions.isEmpty)
                          _empty('لم تسجل أعمالًا منفذة حتى الآن')
                        else
                          ..._completions.map(_completionCard),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _counterCard(int count) => Card(
        color: _green.withValues(alpha: 0.08),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              const Icon(Icons.verified_rounded, color: _green, size: 30),
              const SizedBox(width: 12),
              const Expanded(child: Text('عدد الشغلانات المؤكدة', style: TextStyle(color: _ink, fontWeight: FontWeight.w800))),
              Text('$count', style: const TextStyle(color: _green, fontSize: 28, fontWeight: FontWeight.w900)),
            ],
          ),
        ),
      );

  Widget _sectionTitle(String title) => Text(title, style: const TextStyle(color: _ink, fontSize: 18, fontWeight: FontWeight.w900));

  Widget _empty(String text) => Padding(padding: const EdgeInsets.symmetric(vertical: 20), child: Text(text, style: TextStyle(color: Colors.grey.shade600)));

  Widget _requestCard(Map<String, dynamic> request) => Card(
        margin: const EdgeInsets.only(bottom: 10),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(request['title']?.toString() ?? 'طلب خدمة', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
              if ((request['description']?.toString() ?? '').isNotEmpty) ...[
                const SizedBox(height: 5),
                Text(request['description'].toString(), maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
              const SizedBox(height: 6),
              Text('تاريخ الطلب: ${_date(request['created_at'])}', style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: () => _finish(request),
                icon: const Icon(Icons.task_alt_rounded),
                label: const Text('إنهاء الشغلانة'),
                style: FilledButton.styleFrom(backgroundColor: _green),
              ),
            ],
          ),
        ),
      );

  Widget _completionCard(Map<String, dynamic> completion) {
    final status = completion['status']?.toString() ?? '';
    final paths = (completion['photo_urls'] as List?)?.map((e) => e.toString()).toList() ?? const <String>[];
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [Icon(Icons.circle, size: 10, color: _statusColor(status)), const SizedBox(width: 6), Text(_status(status), style: TextStyle(color: _statusColor(status), fontWeight: FontWeight.w800))]),
            const SizedBox(height: 7),
            Text(_date(completion['executed_on']), style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
            const SizedBox(height: 6),
            Text(completion['description']?.toString() ?? '', style: const TextStyle(color: _ink, height: 1.4)),
            if (paths.isNotEmpty && completion['photos_hidden'] != true) ...[
              const SizedBox(height: 10),
              SizedBox(
                height: 76,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: paths.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, index) => ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(_jobsRepository.imageUrl(paths[index]), width: 76, height: 76, fit: BoxFit.cover),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
