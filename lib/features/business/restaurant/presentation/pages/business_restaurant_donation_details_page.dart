import 'package:flutter/material.dart';

class BusinessRestaurantDonationDetailsPage extends StatelessWidget {
  final Map<String, dynamic> donation;
  const BusinessRestaurantDonationDetailsPage(
      {super.key, required this.donation});

  static const primary = Color(0xFF003527);
  static const green = Color(0xFF0B7650);
  static const muted = Color(0xFF5F6F68);

  String _value(List<String> keys, {String fallback = 'غير محدد'}) {
    for (final key in keys) {
      final value = donation[key]?.toString().trim();
      if (value != null && value.isNotEmpty && value != 'null') return value;
    }
    return fallback;
  }

  String _date(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    if (date == null) return 'تاريخ غير محدد';
    return '${date.day}/${date.month}/${date.year} - ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _label(String status) =>
      const {
        'pending': 'قيد المراجعة',
        'accepted': 'مقبول',
        'rejected': 'مرفوض',
        'volunteer_assigned': 'تم تعيين المندوب',
        'picked_up': 'تم الاستلام',
        'picked_up_from_donor': 'تم الاستلام',
        'in_transit': 'قيد النقل',
        'completed': 'مكتمل',
        'cancelled': 'ملغي',
        'expired': 'منتهي',
      }[status] ??
      'قيد المراجعة';

  Color _color(String status) {
    if (status == 'completed') return green;
    if (['rejected', 'cancelled', 'expired'].contains(status))
      return const Color(0xFFBA1A1A);
    if ([
      'volunteer_assigned',
      'picked_up',
      'picked_up_from_donor',
      'in_transit'
    ].contains(status)) return const Color(0xFF8A5B13);
    return green;
  }

  @override
  Widget build(BuildContext context) {
    final status = _value(['status'], fallback: 'pending').toLowerCase();
    final color = _color(status);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FF),
        appBar: AppBar(
          title: const Text('تفاصيل التبرع',
              style: TextStyle(fontWeight: FontWeight.w900)),
          backgroundColor: Colors.white,
          foregroundColor: primary,
          elevation: 0,
        ),
        body: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            _header(color, status),
            const SizedBox(height: 14),
            _card('بيانات التبرع', [
              _row(
                  'اسم التبرع',
                  _value(['item_title', 'title', 'name'],
                      fallback: 'تبرع غذائي')),
              _row(
                  'الجمعية المستفيدة',
                  _value(['charity_name', 'organization_name'],
                      fallback: 'الجمعية المستفيدة')),
              _row('الكمية', _value(['quantity'])),
              _row('حالة التبرع', _label(status)),
              _row('تاريخ الإرسال', _date(donation['created_at'])),
            ]),
            const SizedBox(height: 14),
            _card('خط سير التبرع',
                [_DetailsTimeline(status: status, color: color)]),
            const SizedBox(height: 14),
            _card('التفاصيل التشغيلية', [
              _row('المندوب',
                  _value(['volunteer_name'], fallback: 'لم يتم التعيين بعد')),
              _row('آخر تحديث',
                  _date(donation['updated_at'] ?? donation['created_at'])),
              _row('رقم العملية', _value(['id'], fallback: 'غير متاح')),
            ]),
            if (_value(['description'], fallback: '').isNotEmpty) ...[
              const SizedBox(height: 14),
              _card('وصف التبرع', [
                Text(_value(['description']),
                    style: const TextStyle(color: muted, height: 1.6))
              ]),
            ],
          ],
        ),
      ),
    );
  }

  Widget _header(Color color, String status) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [primary, green]),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          children: [
            CircleAvatar(
                backgroundColor: Colors.white.withValues(alpha: .16),
                child: const Icon(Icons.volunteer_activism_rounded,
                    color: Colors.white)),
            const SizedBox(width: 12),
            Expanded(
                child: Text(
                    _value(['item_title', 'title', 'name'],
                        fallback: 'تبرع غذائي'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900))),
            Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                decoration: BoxDecoration(
                    color: color.withValues(alpha: .18),
                    borderRadius: BorderRadius.circular(16)),
                child: Text(_label(status),
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800))),
          ],
        ),
      );

  Widget _card(String title, List<Widget> children) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE1E8E4))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: const TextStyle(
                  color: primary, fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          ...children,
        ]),
      );

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
              width: 118,
              child: Text(label,
                  style: const TextStyle(
                      color: muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w700))),
          Expanded(
              child: Text(value,
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                      color: primary,
                      fontSize: 13,
                      fontWeight: FontWeight.w800))),
        ]),
      );
}

class _DetailsTimeline extends StatelessWidget {
  final String status;
  final Color color;
  const _DetailsTimeline({required this.status, required this.color});

  static const statuses = [
    'pending',
    'accepted',
    'rejected',
    'volunteer_assigned',
    'picked_up',
    'completed',
    'cancelled',
    'expired'
  ];
  static const labels = {
    'pending': 'المراجعة',
    'accepted': 'مقبول',
    'rejected': 'مرفوض',
    'volunteer_assigned': 'المندوب',
    'picked_up': 'الاستلام',
    'completed': 'الوصول',
    'cancelled': 'ملغي',
    'expired': 'منتهي'
  };

  @override
  Widget build(BuildContext context) {
    final normalized =
        status == 'picked_up_from_donor' || status == 'in_transit'
            ? 'picked_up'
            : status;
    final current = statuses.indexOf(normalized);
    final rejected = ['rejected', 'cancelled', 'expired'].contains(normalized);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        for (var i = 0; i < statuses.length; i++) ...[
          SizedBox(
              width: 70,
              child: Column(children: [
                CircleAvatar(
                    radius: 13,
                    backgroundColor: rejected && i == current
                        ? const Color(0xFFBA1A1A)
                        : (!rejected && current >= i
                            ? color
                            : const Color(0xFFE6EEFF)),
                    child: Icon(
                        rejected && i == current
                            ? Icons.close_rounded
                            : Icons.check_rounded,
                        size: 15,
                        color: (!rejected && current >= i) ||
                                (rejected && i == current)
                            ? Colors.white
                            : const Color(0xFF8A9B94))),
                const SizedBox(height: 5),
                Text(labels[statuses[i]]!,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: (!rejected && current >= i) ||
                                (rejected && i == current)
                            ? color
                            : const Color(0xFF71837C))),
              ])),
          if (i < statuses.length - 1)
            Container(
                width: 17,
                height: 2,
                color:
                    !rejected && current > i ? color : const Color(0xFFE6EEFF)),
        ],
      ]),
    );
  }
}
