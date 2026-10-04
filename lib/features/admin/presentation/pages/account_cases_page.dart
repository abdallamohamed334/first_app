import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AccountCasesPage extends StatefulWidget {
  const AccountCasesPage({super.key});

  @override
  State<AccountCasesPage> createState() => _AccountCasesPageState();
}

class _AccountCasesPageState extends State<AccountCasesPage> {
  final _client = Supabase.instance.client;
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _cases = const [];

  @override
  void initState() {
    super.initState();
    _loadCases();
  }

  Future<void> _loadCases() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final raw = await _client.rpc('list_account_cases', params: {
        'p_limit': 100,
        'p_offset': 0,
      });
      final rows = raw is List ? raw : const [];
      if (!mounted) return;
      setState(() {
        _cases =
            rows.map((row) => Map<String, dynamic>.from(row as Map)).toList();
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'تعذر تحميل القضايا: ${error.toString()}';
      });
    }
  }

  Future<void> _suspend(Map<String, dynamic> item) async {
    final reason = await _reasonDialog();
    if (reason == null || reason.trim().isEmpty) return;
    try {
      await _client.rpc('suspend_user_account', params: {
        'p_target_user_id': item['target_user_id'],
        'p_reason': reason.trim(),
        'p_case_id': item['id'],
        'p_status': 'suspended',
      });
      await _loadCases();
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _reactivate(Map<String, dynamic> item) async {
    try {
      await _client.rpc('reactivate_user_account', params: {
        'p_target_user_id': item['target_user_id'],
        'p_case_id': item['id'],
        'p_resolution': 'تمت مراجعة الحالة وإعادة تفعيل الحساب من لوحة الإدارة',
      });
      await _loadCases();
    } catch (error) {
      _showError(error);
    }
  }

  Future<String?> _reasonDialog() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('سبب الإيقاف'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 4,
          decoration: const InputDecoration(
              hintText: 'اكتب سببًا واضحًا وقابلًا للمراجعة'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء')),
          FilledButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: const Text('إيقاف الحساب')),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  void _showError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('فشلت العملية: $error')));
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('قضايا سلامة الحسابات'),
          actions: [
            IconButton(onPressed: _loadCases, icon: const Icon(Icons.refresh))
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text(_error!, textAlign: TextAlign.center))
                : _cases.isEmpty
                    ? const Center(child: Text('لا توجد قضايا مسجلة'))
                    : RefreshIndicator(
                        onRefresh: _loadCases,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _cases.length,
                          itemBuilder: (context, index) => _CaseCard(
                            item: _cases[index],
                            onSuspend: () => _suspend(_cases[index]),
                            onReactivate: () => _reactivate(_cases[index]),
                          ),
                        ),
                      ),
      ),
    );
  }
}

class _CaseCard extends StatelessWidget {
  const _CaseCard(
      {required this.item,
      required this.onSuspend,
      required this.onReactivate});
  final Map<String, dynamic> item;
  final VoidCallback onSuspend;
  final VoidCallback onReactivate;

  @override
  Widget build(BuildContext context) {
    final status = item['account_status']?.toString() ?? 'active';
    final caseStatus = item['status']?.toString() ?? 'open';
    final name = item['target_name']?.toString().trim();
    final label = name == null || name.isEmpty ? 'بدون اسم' : name;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
                child: Text(label,
                    style: Theme.of(context).textTheme.titleMedium)),
            Chip(label: Text(status)),
          ]),
          const SizedBox(height: 6),
          Text(
              '${item['target_role'] ?? 'غير معروف'} • ${item['target_phone'] ?? 'بدون هاتف'}'),
          const SizedBox(height: 6),
          Text(
              'القضية: $caseStatus • الأولوية: ${item['priority'] ?? 'normal'}'),
          const SizedBox(height: 8),
          Text(item['reason']?.toString() ?? ''),
          const SizedBox(height: 10),
          Wrap(spacing: 8, children: [
            if (status != 'suspended' && status != 'closed')
              OutlinedButton.icon(
                  onPressed: onSuspend,
                  icon: const Icon(Icons.block),
                  label: const Text('إيقاف')),
            if (status != 'active')
              FilledButton.icon(
                  onPressed: onReactivate,
                  icon: const Icon(Icons.check_circle),
                  label: const Text('إعادة تفعيل')),
          ]),
        ]),
      ),
    );
  }
}
