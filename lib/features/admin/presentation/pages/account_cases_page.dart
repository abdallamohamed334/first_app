import 'dart:async';

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
  StreamSubscription<List<Map<String, dynamic>>>? _casesSubscription;

  @override
  void initState() {
    super.initState();
    _loadCases();
    _casesSubscription = _client
        .from('account_cases')
        .stream(primaryKey: ['id'])
        .handleError((error) {
          debugPrint('[AccountCases] realtime error: $error');
        })
        .listen((_) {
          if (mounted) unawaited(_loadCases());
        });
  }

  @override
  void dispose() {
    _casesSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadCases() async {
    if (!mounted) return;
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
        _cases = rows
            .whereType<Map>()
            .map((row) => Map<String, dynamic>.from(row))
            .toList();
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'تعذر تحميل القضايا. تأكد من صلاحيات حساب الإدارة.';
      });
      debugPrint('[AccountCases] load failed: $error');
    }
  }

  Future<void> _createCase() async {
    final payload = await _createCaseDialog();
    if (payload == null) return;
    try {
      await _client.rpc('create_account_case', params: {
        'p_target_user_id': payload['target_user_id'],
        'p_reason': payload['reason'],
        'p_priority': payload['priority'],
        'p_internal_notes': payload['internal_notes'],
      });
      await _loadCases();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم فتح القضية وتسجيلها في سجل التدقيق')),
        );
      }
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _suspend(Map<String, dynamic> item) async {
    final result = await _suspensionDialog();
    if (result == null) return;
    try {
      await _client.rpc('suspend_user_account', params: {
        'p_target_user_id': item['target_user_id'],
        'p_reason': result['reason'],
        'p_case_id': item['id'],
        'p_status': result['status'],
        'p_suspension_until': result['until'],
      });
      await _loadCases();
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _reactivate(Map<String, dynamic> item) async {
    final resolution = await _resolutionDialog();
    if (resolution == null || resolution.trim().isEmpty) return;
    try {
      await _client.rpc('reactivate_user_account', params: {
        'p_target_user_id': item['target_user_id'],
        'p_case_id': item['id'],
        'p_resolution': resolution.trim(),
      });
      await _loadCases();
    } catch (error) {
      _showError(error);
    }
  }

  Future<Map<String, dynamic>?> _createCaseDialog() async {
    final searchController = TextEditingController();
    final reasonController = TextEditingController();
    final notesController = TextEditingController();
    var priority = 'normal';
    var searching = false;
    List<Map<String, dynamic>> results = [];
    Map<String, dynamic>? selected;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('فتح قضية حساب'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('ابحث بالاسم أو الهاتف أو البريد الإلكتروني'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: searchController,
                          textDirection: TextDirection.ltr,
                          decoration: const InputDecoration(
                            labelText: 'بيانات المستخدم',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: 'بحث',
                        onPressed: searching
                            ? null
                            : () async {
                                setDialogState(() => searching = true);
                                try {
                                  final raw = await _client.rpc(
                                    'search_account_targets',
                                    params: {
                                      'p_query': searchController.text.trim(),
                                      'p_limit': 20,
                                    },
                                  );
                                  final rows = raw is List ? raw : const [];
                                  setDialogState(() {
                                    results = rows
                                        .whereType<Map>()
                                        .map((row) =>
                                            Map<String, dynamic>.from(row))
                                        .toList();
                                  });
                                } catch (error) {
                                  _showError(error);
                                } finally {
                                  setDialogState(() => searching = false);
                                }
                              },
                        icon: searching
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2),
                              )
                            : const Icon(Icons.search),
                      ),
                    ],
                  ),
                  if (results.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    ...results.map(
                      (user) => ListTile(
                        dense: true,
                        selected: selected?['id'] == user['id'],
                        title: Text(user['name']?.toString().trim().isNotEmpty ==
                                true
                            ? user['name'].toString()
                            : 'بدون اسم'),
                        subtitle: Text(
                          '${user['phone'] ?? user['email'] ?? 'بدون وسيلة تواصل'} • ${user['account_status']}',
                        ),
                        onTap: () => setDialogState(() => selected = user),
                      ),
                    ),
                  ],
                  if (selected != null) ...[
                    const SizedBox(height: 8),
                    Text('المحدد: ${selected!['name'] ?? selected!['id']}'),
                  ],
                  const SizedBox(height: 12),
                  TextField(
                    controller: reasonController,
                    maxLines: 3,
                    onChanged: (_) => setDialogState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'سبب القضية *',
                      hintText: 'اكتب سببًا واضحًا وقابلًا للمراجعة',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: priority,
                    decoration: const InputDecoration(
                      labelText: 'الأولوية',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'low', child: Text('منخفضة')),
                      DropdownMenuItem(
                          value: 'normal', child: Text('عادية')),
                      DropdownMenuItem(value: 'high', child: Text('عالية')),
                      DropdownMenuItem(
                          value: 'critical', child: Text('حرجة')),
                    ],
                    onChanged: (value) =>
                        setDialogState(() => priority = value ?? 'normal'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'ملاحظات داخلية اختيارية',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: selected == null || reasonController.text.trim().isEmpty
                  ? null
                  : () => Navigator.pop(dialogContext, {
                        'target_user_id': selected!['id'],
                        'reason': reasonController.text.trim(),
                        'priority': priority,
                        'internal_notes': notesController.text.trim(),
                      }),
              child: const Text('فتح القضية'),
            ),
          ],
        ),
      ),
    );
    searchController.dispose();
    reasonController.dispose();
    notesController.dispose();
    return result;
  }

  Future<Map<String, dynamic>?> _suspensionDialog() async {
    final reasonController = TextEditingController();
    var status = 'suspended';
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('تقييد الحساب'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: status,
                decoration: const InputDecoration(labelText: 'الإجراء'),
                items: const [
                  DropdownMenuItem(
                      value: 'under_review', child: Text('قيد المراجعة')),
                  DropdownMenuItem(value: 'suspended', child: Text('إيقاف')),
                  DropdownMenuItem(value: 'closed', child: Text('إغلاق')),
                ],
                onChanged: (value) =>
                    setDialogState(() => status = value ?? 'suspended'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                autofocus: true,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'السبب *',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('إلغاء')),
            FilledButton(
              onPressed: () {
                if (reasonController.text.trim().isEmpty) return;
                Navigator.pop(dialogContext, {
                  'status': status,
                  'reason': reasonController.text.trim(),
                  'until': null,
                });
              },
              child: const Text('تأكيد'),
            ),
          ],
        ),
      ),
    );
    reasonController.dispose();
    return result;
  }

  Future<String?> _resolutionDialog() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('قرار إعادة التفعيل'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'اكتب نتيجة المراجعة وقرار الإدارة',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء')),
          FilledButton(
              onPressed: () => Navigator.pop(dialogContext, controller.text),
              child: const Text('إعادة التفعيل')),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  void _showError(Object error) {
    if (!mounted) return;
    debugPrint('[AccountCases] action failed: $error');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('فشلت العملية. راجع صلاحيات الإدارة والبيانات.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('قضايا سلامة الحسابات'),
          actions: [
            IconButton(onPressed: _loadCases, icon: const Icon(Icons.refresh)),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _createCase,
          icon: const Icon(Icons.add_moderator),
          label: const Text('فتح قضية'),
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
  const _CaseCard({
    required this.item,
    required this.onSuspend,
    required this.onReactivate,
  });

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
                  label: const Text('تقييد')),
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
