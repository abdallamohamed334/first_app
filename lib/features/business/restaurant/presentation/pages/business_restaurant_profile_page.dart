import 'package:flutter/material.dart';

import 'package:loqma/core/errors/app_error_mapper.dart';
import 'package:loqma/core/services/supabase_service.dart';
import 'package:loqma/features/business/restaurant/data/repositories/business_restaurant_repository.dart';
import 'package:loqma/features/auth/presentation/pages/login_page.dart';
import 'package:loqma/features/business/restaurant/presentation/pages/restaurant_operation_feedback.dart';

class BusinessRestaurantProfilePage extends StatefulWidget {
  const BusinessRestaurantProfilePage({super.key});

  @override
  State<BusinessRestaurantProfilePage> createState() =>
      _BusinessRestaurantProfilePageState();
}

class _BusinessRestaurantProfilePageState
    extends State<BusinessRestaurantProfilePage> {
  static const primary = Color(0xFF003527);
  static const green = Color(0xFF0B7650);
  static const background = Color(0xFFF8F9FF);
  static const muted = Color(0xFF5F6F68);

  final _repository = BusinessRestaurantRepository();
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _repository.getCurrentRestaurantProfile();
  }

  Future<void> _refresh() async {
    final next = _repository.getCurrentRestaurantProfile();
    if (!mounted) return;
    setState(() {
      _future = next;
    });
    try {
      await next;
    } catch (_) {
      // FutureBuilder renders the localized error state.
    }
  }

  String _value(Map<String, dynamic> row, List<String> keys,
      {String fallback = 'غير متوفر'}) {
    for (final key in keys) {
      final value = row[key]?.toString().trim();
      if (value != null && value.isNotEmpty && value != 'null') return value;
    }
    return fallback;
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: background,
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: primary,
          elevation: 0,
          surfaceTintColor: Colors.white,
          titleSpacing: 16,
          leading: IconButton(
            tooltip: 'العودة',
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_forward_rounded),
          ),
          title: const Text('ملف المطعم',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          actions: [
            IconButton(
                onPressed: () {
                  _refresh();
                },
                icon: const Icon(Icons.refresh_rounded)),
            const SizedBox(width: 8),
          ],
        ),
        body: FutureBuilder<Map<String, dynamic>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const _ProfileLoading();
            }
            if (snapshot.hasError) {
              return _ProfileError(
                message: AppErrorMapper.message(snapshot.error!,
                    fallback: 'تعذر تحميل ملف المطعم.'),
                onRetry: () async {
                  await _refresh();
                },
              );
            }
            final row = snapshot.data;
            if (row == null || row.isEmpty) return const _ProfileEmpty();
            return RefreshIndicator(
              color: green,
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(18, 22, 18, 34),
                children: [
                  _headerCard(row),
                  const SizedBox(height: 14),
                  _logoutCard(),
                  const SizedBox(height: 14),
                  LayoutBuilder(builder: (context, constraints) {
                    if (constraints.maxWidth < 620) {
                      return Column(children: [
                        _contactCard(row),
                        const SizedBox(height: 14),
                        _locationCard(row)
                      ]);
                    }
                    return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _contactCard(row)),
                          const SizedBox(width: 14),
                          Expanded(child: _locationCard(row))
                        ]);
                  }),
                  const SizedBox(height: 14),
                  _operationsCard(row),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _headerCard(Map<String, dynamic> row) {
    final name = _value(row, ['name', 'business_name', 'restaurant_name']);
    final description = _value(row, ['description', 'bio'],
        fallback: 'ملف المطعم وبيانات التشغيل المعتمدة.');
    final category = _value(row, ['food_type', 'category', 'cuisine_type'],
        fallback: 'مطعم');
    final image =
        _value(row, ['logo_url', 'image_url', 'avatar_url'], fallback: '');
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(
                color: Color(0x080B7650), blurRadius: 13, offset: Offset(0, 5))
          ]),
      child: LayoutBuilder(builder: (context, constraints) {
        final compact = constraints.maxWidth < 520;
        final avatar = Container(
            width: compact ? 96 : 116,
            height: compact ? 96 : 116,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
                color: const Color(0xFFE6EEFF),
                shape: BoxShape.circle,
                border: Border.all(color: primary, width: 2)),
            child: image.isEmpty
                ? const Icon(Icons.storefront_rounded, color: green, size: 46)
                : Image.network(image,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(
                        Icons.storefront_rounded,
                        color: green,
                        size: 46)));
        final details = Column(
            crossAxisAlignment:
                compact ? CrossAxisAlignment.center : CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: compact
                      ? MainAxisAlignment.center
                      : MainAxisAlignment.start,
                  children: [
                    Flexible(
                        child: Text(name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign:
                                compact ? TextAlign.center : TextAlign.start,
                            style: const TextStyle(
                                color: primary,
                                fontSize: 25,
                                fontWeight: FontWeight.w900))),
                    const SizedBox(width: 7),
                    if (row['is_verified'] == true)
                      const Icon(Icons.verified_rounded, color: green, size: 22)
                  ]),
              const SizedBox(height: 8),
              Text(description,
                  textAlign: compact ? TextAlign.center : TextAlign.start,
                  style: const TextStyle(
                      color: muted, fontSize: 14, height: 1.45)),
              const SizedBox(height: 10),
              Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                      color: const Color(0xFFE6EEFF),
                      borderRadius: BorderRadius.circular(20)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.restaurant_rounded,
                        color: primary, size: 16),
                    const SizedBox(width: 5),
                    Text(category,
                        style: const TextStyle(
                            color: muted,
                            fontSize: 12,
                            fontWeight: FontWeight.w700))
                  ]))
            ]);
        if (compact) {
          return Column(
              mainAxisSize: MainAxisSize.min,
              children: [avatar, const SizedBox(height: 14), details]);
        }
        return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          avatar,
          const SizedBox(width: 18),
          Expanded(child: details)
        ]);
      }),
    );
  }

  Widget _logoutCard() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFFD6D1))),
        child: Row(children: [
          const Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('تسجيل الخروج',
                    style: TextStyle(
                        color: Color(0xFFBA1A1A),
                        fontSize: 16,
                        fontWeight: FontWeight.w800)),
                SizedBox(height: 4),
                Text('سيتم إنهاء جلسة المطعم والعودة إلى صفحة الدخول.',
                    style: TextStyle(color: Color(0xFF71837C), fontSize: 12))
              ])),
          OutlinedButton.icon(
              onPressed: () {
                _confirmLogout();
              },
              icon: const Icon(Icons.logout_rounded),
              label: const Text('خروج'),
              style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFBA1A1A),
                  side: const BorderSide(color: Color(0xFFBA1A1A)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)))),
        ]),
      );

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تسجيل الخروج'),
          content: const Text('هل تريد تسجيل الخروج من حساب المطعم؟'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('إلغاء')),
            FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFBA1A1A)),
                child: const Text('تسجيل الخروج')),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await SupabaseService().client.auth.signOut();
      if (!mounted) return;
      await Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (_) => false,
      );
    } catch (error) {
      if (!mounted) return;
      RestaurantOperationFeedback.error(context, error,
          title: 'تعذر تسجيل الخروج');
    }
  }

  Widget _contactCard(Map<String, dynamic> row) =>
      _InfoCard(title: 'معلومات التواصل', children: [
        _InfoRow(
            icon: Icons.mail_outline_rounded,
            label: 'البريد الإلكتروني',
            value: _value(row, ['email', 'organization_email'])),
        _InfoRow(
            icon: Icons.call_outlined,
            label: 'رقم الهاتف',
            value: _value(row, ['phone', 'mobile'])),
      ]);

  Widget _locationCard(Map<String, dynamic> row) =>
      _InfoCard(title: 'الموقع', children: [
        _InfoRow(
            icon: Icons.location_city_rounded,
            label: 'المدينة',
            value: _value(row, ['city', 'governorate'])),
        _InfoRow(
            icon: Icons.map_outlined,
            label: 'العنوان التفصيلي',
            value: _value(row, ['address', 'location'])),
      ]);

  Widget _operationsCard(Map<String, dynamic> row) =>
      _InfoCard(title: 'التفاصيل التشغيلية', children: [
        LayoutBuilder(builder: (context, constraints) {
          final items = [
            _InfoRow(
                icon: Icons.verified_user_outlined,
                label: 'حالة الحساب',
                value: _value(row, ['status'], fallback: 'نشط')),
            _InfoRow(
                icon: Icons.person_outline_rounded,
                label: 'المالك / المدير المعتمد',
                value: _value(row, ['owner_name', 'manager_name'])),
            _InfoRow(
                icon: Icons.calendar_today_outlined,
                label: 'تاريخ الانضمام',
                value: _value(row, ['created_at'])),
            _InfoRow(
                icon: Icons.lock_outline_rounded,
                label: 'صلاحية التشغيل',
                value: row['is_verified'] == true
                    ? 'موثق ومفعل'
                    : 'بانتظار التحقق'),
          ];
          if (constraints.maxWidth < 600) return Column(children: items);
          return GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 14,
              mainAxisSpacing: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 4.2,
              children: items);
        }),
      ]);
}

class _InfoCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _InfoCard({required this.title, required this.children});
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
                color: Color(0x080B7650), blurRadius: 13, offset: Offset(0, 5))
          ]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: const TextStyle(
                color: Color(0xFF003527),
                fontSize: 18,
                fontWeight: FontWeight.w800)),
        const Divider(color: Color(0xFFE6EEFF), height: 24),
        ...children
      ]));
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow(
      {required this.icon, required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
                color: Color(0xFFE6EEFF), shape: BoxShape.circle),
            child: Icon(icon, color: const Color(0xFF0B7650), size: 20)),
        const SizedBox(width: 11),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: const TextStyle(color: Color(0xFF71837C), fontSize: 12)),
          const SizedBox(height: 3),
          Text(value,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: Color(0xFF121C2A),
                  fontSize: 14,
                  fontWeight: FontWeight.w700))
        ]))
      ]));
}

class _ProfileLoading extends StatelessWidget {
  const _ProfileLoading();
  @override
  Widget build(BuildContext context) =>
      ListView(padding: const EdgeInsets.all(18), children: [
        for (var i = 0; i < 4; i++)
          Container(
              height: i == 0 ? 190 : 135,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                  color: const Color(0xFFE6EEFF),
                  borderRadius: BorderRadius.circular(16)))
      ]);
}

class _ProfileError extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;
  const _ProfileError({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(
      child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.cloud_off_rounded,
                size: 50, color: Color(0xFF71837C)),
            const SizedBox(height: 14),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 14),
            FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('إعادة المحاولة'))
          ])));
}

class _ProfileEmpty extends StatelessWidget {
  const _ProfileEmpty();
  @override
  Widget build(BuildContext context) => const Center(
      child: Padding(
          padding: EdgeInsets.all(28),
          child: Text('لم يتم العثور على ملف المطعم المرتبط بالحساب.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Color(
                    0xFF5F6F68,
                  ),
                  fontSize: 16,
                  fontWeight: FontWeight.w700))));
}
