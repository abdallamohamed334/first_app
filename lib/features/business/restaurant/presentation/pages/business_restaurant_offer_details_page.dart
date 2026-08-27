import 'package:flutter/material.dart';

class BusinessRestaurantOfferDetailsPage extends StatelessWidget {
  final Map<String, dynamic> offer;

  const BusinessRestaurantOfferDetailsPage({super.key, required this.offer});

  static const green = Color(0xFF0B7650);
  static const darkGreen = Color(0xFF123F31);

  @override
  Widget build(BuildContext context) {
    final title = offer['title']?.toString() ?? 'عرض بدون عنوان';
    final description = offer['description']?.toString().trim();
    final status = offer['status']?.toString() ?? 'available';
    final paused = offer['is_paused'] == true;
    final sale = offer['sale_price'];
    final original = offer['original_price'];
    final quantity = offer['quantity']?.toString() ?? 'غير محدد';
    final location = offer['pickup_location']?.toString().trim();
    final expiry = _date(offer['expiry_time']);
    final pickupBefore = _date(offer['pickup_before']);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF6FAF8),
        appBar: AppBar(
          backgroundColor: const Color(0xFFF6FAF8),
          foregroundColor: darkGreen,
          elevation: 0,
          title: const Text('تفاصيل العرض',
              style: TextStyle(fontWeight: FontWeight.w900)),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 30),
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                    colors: [Color(0xFF0B7650), Color(0xFF25A872)],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft),
                borderRadius: BorderRadius.all(Radius.circular(26)),
              ),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.fastfood_rounded,
                        color: Colors.white, size: 38),
                    const SizedBox(height: 18),
                    Text(title,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 25,
                            fontWeight: FontWeight.w900)),
                    const SizedBox(height: 8),
                    _badge(paused ? 'موقوف مؤقتًا' : _status(status),
                        paused ? const Color(0xFFFFE5B5) : Colors.white),
                  ]),
            ),
            const SizedBox(height: 16),
            _section('بيانات العرض', [
              _row(
                  Icons.description_outlined,
                  'الوصف',
                  description?.isNotEmpty == true
                      ? description!
                      : 'لا يوجد وصف'),
              _row(Icons.inventory_2_outlined, 'الكمية', quantity),
              _row(Icons.location_on_outlined, 'مكان الاستلام',
                  location?.isNotEmpty == true ? location! : 'غير محدد'),
            ]),
            const SizedBox(height: 14),
            _section('السعر والمواعيد', [
              _row(Icons.sell_outlined, 'السعر المخفض',
                  sale == null ? 'غير محدد' : '$sale جنيه'),
              _row(Icons.price_change_outlined, 'السعر الأصلي',
                  original == null ? 'غير محدد' : '$original جنيه'),
              _row(Icons.schedule_rounded, 'آخر موعد للاستلام', pickupBefore),
              _row(Icons.event_outlined, 'انتهاء العرض', expiry),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _section(String title, List<Widget> children) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(21),
            border: Border.all(color: const Color(0xFFDCEBE3))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: const TextStyle(
                  color: darkGreen, fontSize: 17, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          ...children,
        ]),
      );

  Widget _row(IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 11),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: green, size: 20),
          const SizedBox(width: 9),
          Expanded(
              child: Text(label,
                  style:
                      const TextStyle(color: Color(0xFF71837C), fontSize: 12))),
          const SizedBox(width: 10),
          Flexible(
              child: Text(value,
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                      color: darkGreen,
                      fontSize: 12,
                      fontWeight: FontWeight.w800))),
        ]),
      );

  Widget _badge(String value, Color color) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
          color: color.withAlpha(45), borderRadius: BorderRadius.circular(20)),
      child: Text(value,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w900)));

  String _date(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    if (date == null) return 'غير محدد';
    return '${date.day}/${date.month}/${date.year} - ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _status(String value) =>
      {
        'available': 'متاح',
        'reserved': 'محجوز',
        'completed': 'تم التسليم',
        'expired': 'منتهي',
        'cancelled': 'ملغي'
      }[value] ??
      value;
}
