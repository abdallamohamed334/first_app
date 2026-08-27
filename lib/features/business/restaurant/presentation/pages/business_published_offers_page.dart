import 'package:flutter/material.dart';
import 'package:loqma/core/errors/app_error_mapper.dart';
import 'package:loqma/features/business/data/repositories/restaurant_operations_repository.dart';

class BusinessPublishedOffersPage extends StatefulWidget {
  const BusinessPublishedOffersPage({super.key});

  @override
  State<BusinessPublishedOffersPage> createState() =>
      _BusinessPublishedOffersPageState();
}

class _BusinessPublishedOffersPageState
    extends State<BusinessPublishedOffersPage> {
  final repository = BusinessOperationsRepository();
  late Future<List<Map<String, dynamic>>> future;

  @override
  void initState() {
    super.initState();
    future = repository.listMyOffers();
  }

  Future<void> refresh() async {
    final next = repository.listMyOffers();
    setState(() {
      future = next;
    });
    await next;
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
              title: const Text('عروضي المنشورة',
                  style: TextStyle(fontWeight: FontWeight.w900)),
              actions: [
                IconButton(
                    onPressed: () {
                      refresh();
                    },
                    icon: const Icon(Icons.refresh_rounded))
              ]),
          body: FutureBuilder<List<Map<String, dynamic>>>(
            future: future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(color: Color(0xFF0B7650)));
              }
              if (snapshot.hasError) {
                return _error(
                    AppErrorMapper.message(snapshot.error!,
                        fallback: 'تعذر تحميل العروض.'),
                    refresh);
              }
              final offers = snapshot.data ?? const <Map<String, dynamic>>[];
              if (offers.isEmpty) return _empty();
              return RefreshIndicator(
                  color: const Color(0xFF0B7650),
                  onRefresh: refresh,
                  child: ListView(
                      padding: const EdgeInsets.all(18),
                      children: offers.map(_card).toList()));
            },
          ),
        ),
      );

  Widget _card(Map<String, dynamic> offer) {
    final paused = offer['is_paused'] == true;
    final status = offer['status']?.toString() ?? 'available';
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(19),
          side: const BorderSide(color: Color(0xFFDCEBE3))),
      child: ListTile(
        contentPadding: const EdgeInsets.all(14),
        leading: const CircleAvatar(
            backgroundColor: Color(0xFFDDF3E8),
            child: Icon(Icons.fastfood_rounded, color: Color(0xFF0B7650))),
        title: Text(offer['title']?.toString() ?? 'عرض بدون عنوان',
            style: const TextStyle(
                color: Color(0xFF123F31), fontWeight: FontWeight.w900)),
        subtitle: Text(
            'الكمية: ${offer['quantity'] ?? '—'}\n${paused ? 'موقوف مؤقتًا' : _status(status)}',
            style: const TextStyle(height: 1.45)),
        isThreeLine: true,
        trailing: Text(
            offer['sale_price'] == null
                ? 'سعر رمزي'
                : '${offer['sale_price']} ج',
            style: const TextStyle(
                color: Color(0xFF0B7650), fontWeight: FontWeight.w900)),
      ),
    );
  }

  Widget _empty() => const Center(
      child: Padding(
          padding: EdgeInsets.all(28),
          child: Text(
              'لا توجد عروض منشورة حاليًا.\nأضف عرضًا مخفضًا ليظهر هنا.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Color(0xFF71837C),
                  height: 1.5,
                  fontWeight: FontWeight.w700))));
  Widget _error(String message, VoidCallback retry) => Center(
      child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: retry, child: const Text('إعادة المحاولة'))
          ])));
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
