import 'package:flutter/material.dart';

const _green = Color(0xFF0B7650);
const _dark = Color(0xFF123F31);
const _muted = Color(0xFF71837C);

class BusinessRestaurantSummaryStrip extends StatelessWidget {
  final List<Map<String, dynamic>> offers;
  final List<Map<String, dynamic>> requests;

  const BusinessRestaurantSummaryStrip({
    super.key,
    required this.offers,
    required this.requests,
  });

  @override
  Widget build(BuildContext context) {
    final activeOffers = offers.where((offer) {
      final status = offer['status']?.toString().trim().toLowerCase();
      return status != 'expired' &&
          status != 'cancelled' &&
          offer['is_paused'] != true;
    }).length;
    final waitingRequests = requests.where((request) {
      final status = request['request_status']?.toString().trim().toLowerCase();
      return status == 'pending' ||
          status == 'accepted' ||
          status == 'ready_for_pickup';
    }).length;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 390;
          final gap = compact ? 6.0 : 10.0;
          return Row(
            children: [
              Expanded(
                child: _item(Icons.local_offer_outlined, '$activeOffers',
                    'عروض نشطة', const Color(0xFF16835B), compact),
              ),
              SizedBox(width: gap),
              Expanded(
                child: _item(Icons.pending_actions_rounded, '$waitingRequests',
                    'طلبات متابعة', const Color(0xFFE98B2A), compact),
              ),
              SizedBox(width: gap),
              Expanded(
                child: _item(Icons.verified_user_outlined, 'آمن',
                    'تسليم بالكود', const Color(0xFF3986D5), compact),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _item(
      IconData icon, String value, String label, Color color, bool compact) {
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: compact ? 6 : 10, vertical: compact ? 10 : 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDCEBE3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: compact ? 20 : 22),
          const SizedBox(height: 6),
          Text(value,
              style: const TextStyle(
                  color: _dark, fontSize: 17, fontWeight: FontWeight.w900)),
          const SizedBox(height: 2),
          Text(label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: _muted, fontSize: 10, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class BusinessRestaurantOfferCard extends StatelessWidget {
  final Map<String, dynamic> offer;
  final ValueChanged<bool>? onPausedChanged;
  final VoidCallback? onTap;

  const BusinessRestaurantOfferCard({
    super.key,
    required this.offer,
    this.onPausedChanged,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final paused = offer['is_paused'] == true;
    final status =
        offer['status']?.toString().trim().toLowerCase() ?? 'available';
    final terminal = {'completed', 'cancelled', 'expired'}.contains(status);
    final title = offer['title']?.toString().trim();
    final quantity = offer['quantity']?.toString() ?? '—';
    final sale = offer['sale_price'];

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(21),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(21),
              border: Border.all(
                color: terminal
                    ? const Color(0xFFFFC7C2)
                    : paused
                        ? const Color(0xFFFFDCA8)
                        : const Color(0xFFDCEBE3),
              ),
              boxShadow: const [
                BoxShadow(
                    color: Color(0x080B7650),
                    blurRadius: 14,
                    offset: Offset(0, 5))
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(
                          color: Color(0xFFDDF3E8), shape: BoxShape.circle),
                      child: const Icon(Icons.fastfood_rounded, color: _green),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title == null || title.isEmpty
                                ? 'عرض بدون عنوان'
                                : title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: _dark,
                                fontWeight: FontWeight.w900,
                                fontSize: 15),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            sale == null
                                ? 'سعر رمزي حسب العرض'
                                : 'السعر المخفض: $sale جنيه',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: _green,
                                fontSize: 12,
                                fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ),
                    if (!terminal && onPausedChanged != null)
                      Switch(
                        value: !paused,
                        activeThumbColor: _green,
                        onChanged: onPausedChanged,
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final narrow = constraints.maxWidth < 330;
                    final children = [
                      _meta(Icons.inventory_2_outlined, 'الكمية', quantity),
                      _meta(Icons.schedule_rounded, 'الاستلام قبل',
                          _date(offer['pickup_before'])),
                      _meta(Icons.info_outline_rounded, 'الحالة',
                          paused ? 'موقوف' : _status(status)),
                    ];
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 11, vertical: 9),
                      decoration: BoxDecoration(
                          color: const Color(0xFFF6FAF8),
                          borderRadius: BorderRadius.circular(14)),
                      child: narrow
                          ? Wrap(
                              spacing: 12,
                              runSpacing: 8,
                              children: children,
                            )
                          : Row(
                              children: children
                                  .map((child) => Expanded(child: child))
                                  .toList(),
                            ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _meta(IconData icon, String label, String value) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: _green),
          const SizedBox(width: 5),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: const TextStyle(color: _muted, fontSize: 9)),
              Text(value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: _dark, fontSize: 10, fontWeight: FontWeight.w800)),
            ],
          ),
        ],
      );

  String _date(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    if (date == null) return 'غير محدد';
    return '${date.day}/${date.month} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _status(String value) =>
      {
        'available': 'متاح',
        'reserved': 'محجوز',
        'completed': 'تم التسليم',
        'expired': 'منتهي',
        'cancelled': 'ملغي',
      }[value] ??
      value;
}

class BusinessRestaurantRequestCard extends StatelessWidget {
  final Map<String, dynamic> request;
  final VoidCallback? onTap;
  final VoidCallback? onVerify;

  const BusinessRestaurantRequestCard({
    super.key,
    required this.request,
    this.onTap,
    this.onVerify,
  });

  @override
  Widget build(BuildContext context) {
    final status =
        request['request_status']?.toString().trim().toLowerCase() ?? 'pending';
    final canVerify = status == 'ready_for_pickup' || status == 'accepted';
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(19),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(19),
                border: Border.all(color: const Color(0xFFDCEBE3))),
            child: Row(
              children: [
                const Icon(Icons.person_pin_circle_outlined,
                    color: _green, size: 28),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(request['offer_title']?.toString() ?? 'طلب عرض',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: _dark, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 4),
                      Text(
                          request['requester_name']?.toString() ??
                              'مستخدم لقمة',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: _muted, fontSize: 12)),
                      const SizedBox(height: 4),
                      Text(_status(status),
                          style: TextStyle(
                              color: _statusColor(status),
                              fontSize: 11,
                              fontWeight: FontWeight.w800)),
                      if (request['created_at'] != null)
                        Text('تم الطلب: ${_date(request['created_at'])}',
                            style: const TextStyle(
                                color: Color(0xFF9AA9A2), fontSize: 10)),
                    ],
                  ),
                ),
                if (canVerify && onVerify != null)
                  OutlinedButton.icon(
                      onPressed: onVerify,
                      icon: const Icon(Icons.qr_code_scanner_rounded, size: 16),
                      label: const Text('تحقق'),
                      style: OutlinedButton.styleFrom(
                          foregroundColor: _green,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 9, vertical: 7))),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _statusColor(String value) => value == 'ready_for_pickup'
      ? const Color(0xFFE98B2A)
      : value == 'completed'
          ? const Color(0xFF16835B)
          : value == 'cancelled' || value == 'expired'
              ? const Color(0xFFD64545)
              : const Color(0xFF3986D5);

  String _date(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    if (date == null) return 'غير محدد';
    return '${date.day}/${date.month} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _status(String value) =>
      {
        'pending': 'في انتظار المراجعة',
        'accepted': 'مقبول',
        'ready_for_pickup': 'جاهز للاستلام',
        'completed': 'تم الاستلام',
        'cancelled': 'ملغي',
        'expired': 'منتهي',
      }[value] ??
      value;
}
