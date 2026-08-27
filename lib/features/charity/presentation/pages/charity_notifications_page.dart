import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CharityNotificationsPage extends StatefulWidget {
  const CharityNotificationsPage({super.key});

  @override
  State<CharityNotificationsPage> createState() =>
      _CharityNotificationsPageState();
}

class _CharityNotificationsPageState extends State<CharityNotificationsPage> {
  static const _green = Color(0xFF087A52);
  static const _deepGreen = Color(0xFF123D31);
  static const _background = Color(0xFFF5F8F6);

  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      throw Exception('انتهت الجلسة الحالية');
    }
    final user = await client
        .from('users')
        .select('user_type')
        .eq('id', userId)
        .maybeSingle();
    if (user?['user_type']?.toString().trim().toLowerCase() != 'charity') {
      throw Exception('هذه الصفحة متاحة لحسابات الجمعيات فقط');
    }

    final rows = await client
        .from('notifications')
        .select('id, title, body, type, is_read, created_at')
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return (rows as List)
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  Future<void> _markRead(String id) async {
    if (id.isEmpty) return;
    try {
      await Supabase.instance.client
          .from('notifications')
          .update({'is_read': true})
          .eq('id', id)
          .eq('user_id', Supabase.instance.client.auth.currentUser!.id);
      if (mounted) setState(() => _future = _load());
    } catch (error) {
      if (mounted) _message('تعذر تحديث حالة الإشعار', error: true);
    }
  }

  Future<void> _markAllRead() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) return;
    try {
      await Supabase.instance.client
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', userId)
          .eq('is_read', false);
      if (mounted) {
        setState(() => _future = _load());
        _message('تم تعليم كل الإشعارات كمقروءة');
      }
    } catch (error) {
      if (mounted) _message('تعذر تحديث الإشعارات', error: true);
    }
  }

  void _message(String text, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text, textDirection: TextDirection.rtl),
          backgroundColor: error ? const Color(0xFFB54747) : _green,
          behavior: SnackBarBehavior.floating,
        ),
      );
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
          title: const Text(
            'إشعارات الجمعية',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          actions: [
            IconButton(
              onPressed: _markAllRead,
              tooltip: 'تعليم الكل كمقروء',
              icon: const Icon(Icons.done_all_rounded),
            ),
            IconButton(
              onPressed: () => setState(() => _future = _load()),
              tooltip: 'تحديث',
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        body: FutureBuilder<List<Map<String, dynamic>>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: _green),
              );
            }
            if (snapshot.hasError) {
              return _empty('تعذر تحميل الإشعارات', Icons.cloud_off_rounded);
            }
            final rows = snapshot.data ?? const <Map<String, dynamic>>[];
            if (rows.isEmpty) {
              return _empty('لا توجد إشعارات جديدة حاليًا',
                  Icons.notifications_none_rounded);
            }
            return RefreshIndicator(
              color: _green,
              onRefresh: () async {
                final next = _load();
                setState(() => _future = next);
                await next;
              },
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
                itemCount: rows.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, index) => _item(rows[index]),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _item(Map<String, dynamic> row) {
    final id = row['id']?.toString() ?? '';
    final unread = row['is_read'] != true;
    return Material(
      color: unread ? const Color(0xFFEFF8F3) : Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: unread ? () => _markRead(id) : null,
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor:
                    unread ? const Color(0xFFCFEFDE) : const Color(0xFFE9EFEC),
                foregroundColor: _green,
                child: Icon(
                  unread
                      ? Icons.notifications_active_rounded
                      : Icons.notifications_none_rounded,
                  size: 20,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row['title']?.toString() ?? 'إشعار جديد',
                      style: const TextStyle(
                          color: _deepGreen, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      row['body']?.toString() ?? '',
                      style: const TextStyle(
                          color: Color(0xFF52675D), height: 1.45, fontSize: 12),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      _date(row['created_at']),
                      style: const TextStyle(
                          color: Color(0xFF809089), fontSize: 10),
                    ),
                  ],
                ),
              ),
              if (unread)
                const Padding(
                  padding: EdgeInsets.only(top: 3),
                  child: Icon(Icons.circle, color: _green, size: 9),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _empty(String text, IconData icon) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: _green, size: 54),
            const SizedBox(height: 12),
            Text(text,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: _deepGreen, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }

  String _date(dynamic value) {
    final parsed = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    if (parsed == null) return 'التاريخ غير متاح';
    return '${parsed.day}/${parsed.month}/${parsed.year} • ${parsed.hour.toString().padLeft(2, '0')}:${parsed.minute.toString().padLeft(2, '0')}';
  }
}
