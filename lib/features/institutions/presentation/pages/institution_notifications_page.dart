import 'package:flutter/material.dart';

import '../../data/repositories/institutions_repository.dart';

class InstitutionNotificationsPage extends StatefulWidget {
  const InstitutionNotificationsPage({super.key});

  @override
  State<InstitutionNotificationsPage> createState() =>
      _InstitutionNotificationsPageState();
}

class _InstitutionNotificationsPageState
    extends State<InstitutionNotificationsPage> {
  final _repository = InstitutionsRepository();
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _repository.listMyNotifications();
  }

  void _reload() {
    setState(() => _future = _repository.listMyNotifications());
  }

  Future<void> _markRead(String id) async {
    try {
      await _repository.markNotificationAsRead(id);
      _reload();
    } catch (_) {
      if (mounted) _showError('تعذر تحديث الإشعار. حاول مرة أخرى');
    }
  }

  Future<void> _markAllRead() async {
    try {
      await _repository.markAllNotificationsAsRead();
      _reload();
    } catch (_) {
      if (mounted) _showError('تعذر تحديث الإشعارات. حاول مرة أخرى');
    }
  }

  void _showError(String message) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('إشعارات المؤسسة'),
            centerTitle: true,
            actions: [
              IconButton(
                  onPressed: _markAllRead,
                  tooltip: 'تحديد الكل كمقروء',
                  icon: const Icon(Icons.done_all_rounded)),
            ],
          ),
          body: FutureBuilder<List<Map<String, dynamic>>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return _EmptyState(
                    text: 'تعذر تحميل الإشعارات حاليًا', onRetry: _reload);
              }
              final rows = snapshot.data ?? const <Map<String, dynamic>>[];
              if (rows.isEmpty) {
                return const _EmptyState(text: 'لا توجد إشعارات حتى الآن');
              }
              return RefreshIndicator(
                onRefresh: () async => _reload(),
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: rows.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, index) {
                    final row = rows[index];
                    final read = row['is_read'] == true;
                    final id = row['id']?.toString();
                    return Card(
                      elevation: 0,
                      color: read ? Colors.white : const Color(0xFFEAF7F0),
                      child: ListTile(
                        onTap: id == null ? null : () => _markRead(id),
                        leading: CircleAvatar(
                          backgroundColor: read
                              ? const Color(0xFFE5ECE8)
                              : const Color(0xFF0B7650),
                          child: Icon(
                              read
                                  ? Icons.notifications_none
                                  : Icons.notifications_active,
                              color: read
                                  ? const Color(0xFF557066)
                                  : Colors.white),
                        ),
                        title: Text((row['title'] ?? 'إشعار جديد').toString(),
                            style:
                                const TextStyle(fontWeight: FontWeight.w800)),
                        subtitle: Padding(
                            padding: const EdgeInsets.only(top: 5),
                            child: Text((row['body'] ?? '').toString())),
                        trailing: read
                            ? null
                            : const Icon(Icons.circle,
                                size: 10, color: Color(0xFF0B7650)),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      );
}

class _EmptyState extends StatelessWidget {
  final String text;
  final VoidCallback? onRetry;
  const _EmptyState({required this.text, this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.notifications_none_rounded,
                  size: 52, color: Color(0xFF0B7650)),
              const SizedBox(height: 12),
              Text(text, textAlign: TextAlign.center),
              if (onRetry != null) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('إعادة المحاولة')),
              ],
            ],
          ),
        ),
      );
}
