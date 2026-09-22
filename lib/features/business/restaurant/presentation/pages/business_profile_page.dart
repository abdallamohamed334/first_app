import 'package:flutter/material.dart';
import 'package:loqma/core/errors/app_error_mapper.dart';
import 'package:loqma/core/services/supabase_service.dart';

class BusinessProfilePage extends StatefulWidget {
  const BusinessProfilePage({super.key});

  @override
  State<BusinessProfilePage> createState() => _BusinessProfilePageState();
}

class _BusinessProfilePageState extends State<BusinessProfilePage> {
  final _client = SupabaseService().client;
  late Future<Map<String, dynamic>> future;

  @override
  void initState() {
    super.initState();
    future = _loadProfile();
  }

  Future<void> refresh() async {
    final next = _loadProfile();
    setState(() {
      future = next;
    });
    await next;
  }

  Future<Map<String, dynamic>> _loadProfile() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      throw const FormatException('جلسة المؤسسة غير صالحة');
    }
    final row = await _client
        .from('businesses')
        .select(
            'id, user_id, name, owner_name, phone, email, address, city, description, status, is_verified, capabilities')
        .eq('user_id', userId)
        .maybeSingle();
    if (row == null) {
      throw const FormatException('لم يتم العثور على بيانات المؤسسة');
    }
    return Map<String, dynamic>.from(row);
  }

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: const Color(0xFFF6FAF8),
          appBar: AppBar(
              backgroundColor: const Color(0xFFF6FAF8),
              foregroundColor: const Color(0xFF123F31),
              elevation: 0,
              title: const Text('ملف المؤسسة',
                  style: TextStyle(fontWeight: FontWeight.w900)),
              actions: [
                IconButton(
                    onPressed: () {
                      refresh();
                    },
                    icon: const Icon(Icons.refresh_rounded))
              ]),
          body: FutureBuilder<Map<String, dynamic>>(
            future: future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(color: Color(0xFF0B7650)));
              }
              if (snapshot.hasError) {
                return _error(
                    AppErrorMapper.message(snapshot.error!,
                        fallback: 'تعذر تحميل ملف المؤسسة.'),
                    refresh);
              }
              final profile = snapshot.data ?? const <String, dynamic>{};
              return RefreshIndicator(
                  color: const Color(0xFF0B7650),
                  onRefresh: refresh,
                  child: ListView(padding: const EdgeInsets.all(18), children: [
                    _hero(profile),
                    const SizedBox(height: 16),
                    _details(profile),
                    const SizedBox(height: 16),
                    _capabilities(profile)
                  ]));
            },
          ),
        ),
      );

  Widget _hero(Map<String, dynamic> profile) => Container(
      padding: const EdgeInsets.all(22),
      decoration: const BoxDecoration(
          gradient:
              LinearGradient(colors: [Color(0xFF0B7650), Color(0xFF25A872)]),
          borderRadius: BorderRadius.all(Radius.circular(25))),
      child: Row(children: [
        const CircleAvatar(
            radius: 30,
            backgroundColor: Colors.white24,
            child:
                Icon(Icons.storefront_rounded, color: Colors.white, size: 30)),
        const SizedBox(width: 14),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(profile['name']?.toString() ?? 'مؤسسة loqma',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 21,
                  fontWeight: FontWeight.w900)),
          const SizedBox(height: 5),
          Text(profile['status']?.toString() ?? 'غير محدد',
              style: const TextStyle(color: Colors.white70))
        ]))
      ]));
  Widget _details(Map<String, dynamic> profile) => _section('بيانات المؤسسة', [
        _row('المسؤول', profile['owner_name']),
        _row('الهاتف', profile['phone']),
        _row('البريد', profile['email']),
        _row('العنوان', profile['address']),
        _row('المدينة', profile['city']),
        _row('الوصف', profile['description'])
      ]);
  Widget _capabilities(Map<String, dynamic> profile) {
    final caps = profile['capabilities'];
    final values =
        caps is List ? caps.whereType<String>().toList() : const <String>[];
    return _section(
        'الصلاحيات الحالية',
        values.isEmpty
            ? [
                const Text('لا توجد صلاحيات مقروءة لهذا الحساب.',
                    style: TextStyle(color: Color(0xFF71837C)))
              ]
            : values
                .map((value) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(children: [
                      const Icon(Icons.verified_outlined,
                          color: Color(0xFF0B7650), size: 18),
                      const SizedBox(width: 8),
                      Text(value,
                          style: const TextStyle(
                              color: Color(0xFF123F31),
                              fontWeight: FontWeight.w700))
                    ])))
                .toList());
  }

  Widget _section(String title, List<Widget> children) => Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFDCEBE3))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: const TextStyle(
                color: Color(0xFF123F31),
                fontSize: 17,
                fontWeight: FontWeight.w900)),
        const SizedBox(height: 12),
        ...children
      ]));
  Widget _row(String label, dynamic value) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
            child: Text(label,
                style:
                    const TextStyle(color: Color(0xFF71837C), fontSize: 12))),
        Expanded(
            flex: 2,
            child: Text(
                value?.toString().trim().isNotEmpty == true
                    ? value.toString()
                    : 'غير محدد',
                textAlign: TextAlign.end,
                style: const TextStyle(
                    color: Color(0xFF123F31), fontWeight: FontWeight.w700)))
      ]));
  Widget _error(String message, VoidCallback retry) => Center(
      child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: retry, child: const Text('إعادة المحاولة'))
          ])));
}
