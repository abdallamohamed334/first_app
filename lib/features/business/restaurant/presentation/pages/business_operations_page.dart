import 'package:flutter/material.dart';
import 'package:loqma/features/business/data/repositories/restaurant_operations_repository.dart';
import 'package:loqma/features/business/restaurant/presentation/pages/business_profile_page.dart';
import 'package:loqma/features/business/restaurant/presentation/pages/business_published_offers_page.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:loqma/core/errors/app_error_mapper.dart';

class BusinessOperationsPage extends StatefulWidget {
  const BusinessOperationsPage({super.key});

  @override
  State<BusinessOperationsPage> createState() => _BusinessOperationsPageState();
}

class _BusinessOperationsPageState extends State<BusinessOperationsPage> {
  static const green = Color(0xFF0B7650);
  static const darkGreen = Color(0xFF123F31);
  static const background = Color(0xFFF6FAF8);

  final _repository = BusinessOperationsRepository();
  late Future<_RestaurantData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_RestaurantData> _load() async {
    final results = await Future.wait<List<Map<String, dynamic>>>([
      _repository.listMyOffers(),
      _repository.listMyRequests(),
    ]);
    return _RestaurantData(offers: results[0], requests: results[1]);
  }

  Future<void> _refresh() async {
    final next = _load();
    setState(() => _future = next);
    await next;
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
      if (!mounted) return;
      await _refresh();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تنفيذ العملية بنجاح')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(AppErrorMapper.message(error,
                fallback: 'تعذر تنفيذ العملية. حاول مرة أخرى.'))),
      );
    }
  }

  void _openPublishedOffers() {
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => const BusinessPublishedOffersPage()));
  }

  void _openBusinessProfile() {
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => const BusinessProfilePage()));
  }

  void _openScanner() {
    Navigator.push<bool>(
      context,
      MaterialPageRoute(
          builder: (_) => BusinessPickupScannerPage(repository: _repository)),
    ).then((completed) {
      if (completed == true && mounted) _refresh();
    });
  }

  Future<void> _openOfferForm() async {
    final result = await showModalBottomSheet<_OfferDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _OfferFormSheet(),
    );
    if (result == null) return;
    await _run(() async {
      await _repository.createFoodOffer(
        title: result.title,
        description: result.description,
        quantity: result.quantity,
        foodType: 'surplus',
        expiryTime: result.expiry,
        pickupBefore: result.pickupBefore,
        salePrice: result.salePrice,
        originalPrice: result.originalPrice,
        pickupLocation: result.location,
      );
    });
  }

  Future<void> _openDonationForm() async {
    try {
      final charities = await _repository.listActiveCharities();
      if (!mounted) return;
      final result = await showModalBottomSheet<_DonationDraft>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _DonationFormSheet(charities: charities),
      );
      if (result == null) return;
      await _run(() async {
        await _repository.createCharityDonation(
          charityId: result.charityId,
          itemTitle: result.title,
          description: result.description,
          quantity: result.quantity,
          condition: result.condition,
        );
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(AppErrorMapper.message(error,
                fallback: 'تعذر تحميل الجمعيات المتاحة.'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: background,
        appBar: AppBar(
          backgroundColor: background,
          foregroundColor: darkGreen,
          elevation: 0,
          title: const Text('مساحة تشغيل المطعم',
              style: TextStyle(fontWeight: FontWeight.w900)),
          actions: [
            IconButton(
                onPressed: _openPublishedOffers,
                tooltip: 'عروضي المنشورة',
                icon: const Icon(Icons.local_offer_outlined)),
            IconButton(
                onPressed: _openBusinessProfile,
                tooltip: 'ملف المطعم',
                icon: const Icon(Icons.account_circle_outlined)),
            IconButton(
                onPressed: () {
                  _refresh();
                },
                tooltip: 'تحديث لوحة التحكم',
                icon: const Icon(Icons.refresh_rounded)),
          ],
        ),
        body: FutureBuilder<_RestaurantData>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                  child: CircularProgressIndicator(color: green));
            }
            if (snapshot.hasError) {
              return _error(snapshot.error!);
            }
            final data = snapshot.data ??
                const _RestaurantData(offers: [], requests: []);
            return RefreshIndicator(
              color: green,
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
                children: [
                  _hero(data),
                  const SizedBox(height: 14),
                  _summaryStrip(data),
                  const SizedBox(height: 18),
                  _actions(),
                  const SizedBox(height: 22),
                  _sectionTitle('عروضي الحالية', '${data.offers.length} عرض'),
                  const SizedBox(height: 10),
                  if (data.offers.isEmpty)
                    _empty('لم تضف عروضًا بعد')
                  else
                    ...data.offers.map(_offerCard),
                  const SizedBox(height: 22),
                  _sectionTitle(
                      'طلبات الاستلام', '${data.requests.length} طلب'),
                  const SizedBox(height: 10),
                  if (data.requests.isEmpty)
                    _empty('لا توجد طلبات استلام حاليًا')
                  else
                    ...data.requests.map(_requestCard),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _hero(_RestaurantData data) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0B7650), Color(0xFF25A872)],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ),
          borderRadius: BorderRadius.circular(26),
          boxShadow: const [
            BoxShadow(
                color: Color(0x290B7650), blurRadius: 18, offset: Offset(0, 8)),
          ],
        ),
        child: Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('مساحة تشغيل المؤسسة',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 23,
                          fontWeight: FontWeight.w900)),
                  SizedBox(height: 6),
                  Text(
                      'انشر الفائض، تابع الحجوزات، وسلّم الطلبات بأمان من مكان واحد.',
                      style: TextStyle(color: Colors.white70, height: 1.45)),
                ],
              ),
            ),
            Container(
              width: 58,
              height: 58,
              decoration: const BoxDecoration(
                  color: Colors.white24, shape: BoxShape.circle),
              child: const Icon(Icons.storefront_rounded,
                  color: Colors.white, size: 30),
            ),
          ],
        ),
      );

  Widget _summaryStrip(_RestaurantData data) {
    final activeOffers = data.offers.where((offer) {
      final status = offer['status']?.toString().toLowerCase();
      return status != 'expired' &&
          status != 'cancelled' &&
          offer['is_paused'] != true;
    }).length;
    final waitingRequests = data.requests.where((request) {
      final status = request['request_status']?.toString().toLowerCase();
      return status == 'pending' ||
          status == 'accepted' ||
          status == 'ready_for_pickup';
    }).length;

    return Row(
      children: [
        Expanded(
            child: _summaryCard(Icons.local_offer_outlined, '$activeOffers',
                'عروض نشطة', const Color(0xFF16835B))),
        const SizedBox(width: 10),
        Expanded(
            child: _summaryCard(Icons.pending_actions_rounded,
                '$waitingRequests', 'طلبات متابعة', const Color(0xFFE98B2A))),
        const SizedBox(width: 10),
        Expanded(
            child: _summaryCard(Icons.verified_user_outlined, 'آمن',
                'تسليم بالكود', const Color(0xFF3986D5))),
      ],
    );
  }

  Widget _summaryCard(IconData icon, String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDCEBE3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(value,
              style: const TextStyle(
                  color: darkGreen, fontSize: 17, fontWeight: FontWeight.w900)),
          const SizedBox(height: 2),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: Color(0xFF71837C),
                  fontSize: 10,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _actions() => LayoutBuilder(builder: (context, constraints) {
        final compact = constraints.maxWidth < 430;
        final buttons = [
          _action(Icons.add_shopping_cart_rounded, 'عرض بسعر مخفض',
              'أضف فائضًا للبيع', _openOfferForm, true),
          _action(Icons.volunteer_activism_rounded, 'تبرع لجمعية',
              'أرسل فائضًا مباشرًا', _openDonationForm, false),
          _action(Icons.qr_code_scanner_rounded, 'سكان الاستلام',
              'QR أو كتابة الكود', _openScanner, false),
        ];
        if (compact) {
          return Column(
              children: buttons
                  .map((button) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: button))
                  .toList());
        }
        return Row(children: [
          for (var i = 0; i < buttons.length; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            Expanded(child: buttons[i])
          ]
        ]);
      });

  Widget _action(IconData icon, String title, String subtitle,
          VoidCallback onTap, bool filled) =>
      Material(
        color: filled ? green : Colors.white,
        borderRadius: BorderRadius.circular(19),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(19),
          child: Container(
            constraints: const BoxConstraints(minHeight: 112),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(19),
                border: Border.all(
                    color: filled ? green : const Color(0xFFDCEBE3))),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(icon, color: filled ? Colors.white : green, size: 27),
              const SizedBox(height: 10),
              Text(title,
                  style: TextStyle(
                      color: filled ? Colors.white : darkGreen,
                      fontWeight: FontWeight.w900,
                      fontSize: 13)),
              const SizedBox(height: 3),
              Text(subtitle,
                  style: TextStyle(
                      color: filled ? Colors.white70 : const Color(0xFF71837C),
                      fontSize: 10)),
            ]),
          ),
        ),
      );

  Widget _sectionTitle(String title, String count) => Padding(
        padding: const EdgeInsetsDirectional.only(start: 2),
        child: Row(
          children: [
            Expanded(
                child: Text(title,
                    style: const TextStyle(
                        color: darkGreen,
                        fontSize: 20,
                        fontWeight: FontWeight.w900))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                  color: const Color(0xFFE4F5ED),
                  borderRadius: BorderRadius.circular(20)),
              child: Text(count,
                  style: const TextStyle(
                      color: green, fontWeight: FontWeight.w800, fontSize: 11)),
            ),
          ],
        ),
      );

  Widget _offerCard(Map<String, dynamic> offer) {
    final paused = offer['is_paused'] == true;
    final status = offer['status']?.toString() ?? 'available';
    final title = offer['title']?.toString() ?? 'عرض بدون عنوان';
    final sale = offer['sale_price'];
    final quantity = offer['quantity']?.toString() ?? '—';
    final pickupBefore = _dateLabel(offer['pickup_before']);
    final terminal = ['completed', 'cancelled', 'expired'].contains(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(21),
        border: Border.all(
            color: paused ? const Color(0xFFFFDCA8) : const Color(0xFFDCEBE3)),
        boxShadow: const [
          BoxShadow(
              color: Color(0x080B7650), blurRadius: 14, offset: Offset(0, 5))
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
                  child: const Icon(Icons.fastfood_rounded, color: green)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: darkGreen,
                              fontWeight: FontWeight.w900,
                              fontSize: 15)),
                      const SizedBox(height: 5),
                      Text(
                          sale == null
                              ? 'سعر رمزي حسب العرض'
                              : 'السعر المخفض: $sale جنيه',
                          style: const TextStyle(
                              color: green,
                              fontSize: 12,
                              fontWeight: FontWeight.w800)),
                    ]),
              ),
              if (!terminal)
                Switch(
                    value: !paused,
                    activeThumbColor: green,
                    onChanged: (enabled) => _run(() async {
                          await _repository.setOfferPaused(
                              offerId: offer['id'].toString(),
                              paused: !enabled);
                        })),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
            decoration: BoxDecoration(
                color: const Color(0xFFF6FAF8),
                borderRadius: BorderRadius.circular(14)),
            child: Row(
              children: [
                Expanded(
                    child: _offerMeta(
                        Icons.inventory_2_outlined, 'الكمية', quantity)),
                Expanded(
                    child: _offerMeta(
                        Icons.schedule_rounded, 'الاستلام قبل', pickupBefore)),
                Expanded(
                    child: _offerMeta(Icons.info_outline_rounded, 'الحالة',
                        paused ? 'موقوف' : _status(status))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _offerMeta(IconData icon, String label, String value) => Row(
        children: [
          Icon(icon, size: 16, color: green),
          const SizedBox(width: 5),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(label,
                    style:
                        const TextStyle(color: Color(0xFF71837C), fontSize: 9)),
                Text(value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: darkGreen,
                        fontSize: 10,
                        fontWeight: FontWeight.w800))
              ])),
        ],
      );

  String _dateLabel(dynamic value) {
    if (value == null) return 'غير محدد';
    final date = DateTime.tryParse(value.toString())?.toLocal();
    if (date == null) return 'غير محدد';
    return '${date.day}/${date.month} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Widget _requestCard(Map<String, dynamic> request) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(19),
            border: Border.all(color: const Color(0xFFDCEBE3))),
        child: Row(children: [
          const Icon(Icons.person_pin_circle_outlined, color: green, size: 28),
          const SizedBox(width: 11),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(request['offer_title']?.toString() ?? 'طلب عرض',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: darkGreen, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(request['requester_name']?.toString() ?? 'مستخدم loqma',
                    style: const TextStyle(
                        color: Color(0xFF71837C), fontSize: 12)),
                const SizedBox(height: 4),
                Text(
                    _status(request['request_status']?.toString() ?? 'pending'),
                    style: const TextStyle(
                        color: green,
                        fontSize: 11,
                        fontWeight: FontWeight.w800)),
              ])),
        ]),
      );

  String _status(String value) =>
      {
        'pending': 'في انتظار المراجعة',
        'accepted': 'مقبول',
        'ready_for_pickup': 'جاهز للاستلام',
        'completed': 'تم الاستلام',
        'cancelled': 'ملغي',
        'expired': 'منتهي'
      }[value] ??
      value;

  Widget _empty(String text) => Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(19),
          border: Border.all(color: const Color(0xFFDCEBE3))),
      child: Text(text,
          textAlign: TextAlign.center,
          style: const TextStyle(
              color: Color(0xFF71837C), fontWeight: FontWeight.w700)));

  Widget _error(Object error) => Center(
      child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
              AppErrorMapper.message(error,
                  fallback: 'تعذر تحميل مساحة المطعم.'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: darkGreen, fontWeight: FontWeight.w800))));
}

class _RestaurantData {
  final List<Map<String, dynamic>> offers;
  final List<Map<String, dynamic>> requests;
  const _RestaurantData({required this.offers, required this.requests});
}

class _OfferDraft {
  final String title, description, location;
  final int quantity;
  final double salePrice;
  final double? originalPrice;
  final DateTime expiry, pickupBefore;
  const _OfferDraft(
      {required this.title,
      required this.description,
      required this.location,
      required this.quantity,
      required this.salePrice,
      required this.originalPrice,
      required this.expiry,
      required this.pickupBefore});
}

class _DonationDraft {
  final String charityId, title, description, condition;
  final int quantity;
  const _DonationDraft(
      {required this.charityId,
      required this.title,
      required this.description,
      required this.condition,
      required this.quantity});
}

class _OfferFormSheet extends StatefulWidget {
  const _OfferFormSheet();
  @override
  State<_OfferFormSheet> createState() => _OfferFormSheetState();
}

class _OfferFormSheetState extends State<_OfferFormSheet> {
  late DateTime _expiry;
  late DateTime _pickupBefore;
  String? _validationMessage;
  final title = TextEditingController();
  final description = TextEditingController();
  final quantity = TextEditingController(text: '1');
  final price = TextEditingController();
  final original = TextEditingController();
  final location = TextEditingController();

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _expiry = now.add(const Duration(hours: 8));
    _pickupBefore = now.add(const Duration(hours: 6));
  }

  @override
  void dispose() {
    title.dispose();
    description.dispose();
    quantity.dispose();
    price.dispose();
    original.dispose();
    location.dispose();
    super.dispose();
  }

  Future<void> _chooseTime({required bool expiry}) async {
    final current = expiry ? _expiry : _pickupBefore;
    final pickedDate = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      initialDate: current,
    );
    if (!mounted || pickedDate == null) return;
    final pickedTime = await showTimePicker(
        context: context, initialTime: TimeOfDay.fromDateTime(current));
    if (!mounted || pickedTime == null) return;
    final value = DateTime(pickedDate.year, pickedDate.month, pickedDate.day,
        pickedTime.hour, pickedTime.minute);
    setState(() {
      if (expiry) {
        _expiry = value;
      } else {
        _pickupBefore = value;
      }
    });
  }

  String _format(DateTime value) =>
      '${value.day}/${value.month}  ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return _sheet(context, 'إضافة عرض بسعر مخفض', [
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: const Color(0xFFEAF8F0),
            borderRadius: BorderRadius.circular(14)),
        child: const Row(children: [
          Icon(Icons.lightbulb_outline_rounded,
              color: _BusinessOperationsPageState.green),
          SizedBox(width: 8),
          Expanded(
              child: Text(
                  'أدخل بيانات واضحة حتى يظهر العرض للمستخدمين بشكل جذاب وسهل.',
                  style: TextStyle(
                      color: _BusinessOperationsPageState.darkGreen,
                      fontSize: 12,
                      height: 1.35)))
        ]),
      ),
      const SizedBox(height: 12),
      _field(title, 'اسم العرض'),
      _field(description, 'وصف مختصر', maxLines: 2),
      Row(children: [
        Expanded(child: _field(quantity, 'الكمية', number: true)),
        const SizedBox(width: 10),
        Expanded(child: _field(price, 'السعر المخفض', number: true))
      ]),
      _field(original, 'السعر الأصلي (اختياري)', number: true),
      _field(location, 'مكان الاستلام'),
      ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.event_outlined,
              color: _BusinessOperationsPageState.green),
          title: const Text('ينتهي العرض'),
          trailing: Text(_format(_expiry),
              style: const TextStyle(fontWeight: FontWeight.w800)),
          onTap: () => _chooseTime(expiry: true)),
      ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.schedule_rounded,
              color: _BusinessOperationsPageState.green),
          title: const Text('آخر موعد للاستلام'),
          trailing: Text(_format(_pickupBefore),
              style: const TextStyle(fontWeight: FontWeight.w800)),
          onTap: () => _chooseTime(expiry: false)),
      if (_validationMessage != null) ...[
        const SizedBox(height: 4),
        Text(_validationMessage!,
            style: const TextStyle(
                color: Color(0xFFD64545),
                fontSize: 12,
                fontWeight: FontWeight.w700)),
      ],
      const SizedBox(height: 8),
      FilledButton.icon(
          onPressed: () {
            final q = int.tryParse(quantity.text.trim());
            final p = double.tryParse(price.text.trim());
            final originalPrice = double.tryParse(original.text.trim());
            String? error;
            if (title.text.trim().isEmpty) {
              error = 'اكتب اسم العرض أولًا';
            } else if (q == null || q <= 0)
              error = 'الكمية يجب أن تكون أكبر من صفر';
            else if (p == null || p < 0)
              error = 'اكتب سعرًا مخفضًا صحيحًا';
            else if (originalPrice != null && originalPrice < p)
              error = 'السعر الأصلي يجب أن يكون أكبر من السعر المخفض';
            else if (!_pickupBefore.isBefore(_expiry))
              error = 'موعد الاستلام يجب أن يسبق انتهاء العرض';
            if (error != null) {
              setState(() => _validationMessage = error);
              return;
            }
            Navigator.pop(
                context,
                _OfferDraft(
                    title: title.text.trim(),
                    description: description.text.trim(),
                    quantity: q!,
                    salePrice: p!,
                    originalPrice: originalPrice,
                    location: location.text.trim(),
                    expiry: _expiry,
                    pickupBefore: _pickupBefore));
          },
          icon: const Icon(Icons.publish_rounded),
          label: const Text('نشر العرض')),
    ]);
  }
}

class _DonationFormSheet extends StatefulWidget {
  final List<Map<String, dynamic>> charities;
  const _DonationFormSheet({required this.charities});
  @override
  State<_DonationFormSheet> createState() => _DonationFormSheetState();
}

class _DonationFormSheetState extends State<_DonationFormSheet> {
  final title = TextEditingController();
  final description = TextEditingController();
  final quantity = TextEditingController(text: '1');
  final condition = TextEditingController(text: 'جيد');
  String? charityId;
  String? _validationMessage;
  @override
  void dispose() {
    title.dispose();
    description.dispose();
    quantity.dispose();
    condition.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _sheet(context, 'تبرع مباشر لجمعية', [
        if (widget.charities.isEmpty)
          Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: const Color(0xFFFFF5E6),
                  borderRadius: BorderRadius.circular(14)),
              child: const Text('لا توجد جمعية متاحة حاليًا لاستقبال التبرع.',
                  style: TextStyle(
                      color: Color(0xFF8B5E14), fontWeight: FontWeight.w700)))
        else
          DropdownButtonFormField<String>(
              initialValue: charityId,
              decoration: const InputDecoration(
                  labelText: 'الجمعية المستفيدة', border: OutlineInputBorder()),
              items: widget.charities
                  .map((row) => DropdownMenuItem(
                      value: row['id']?.toString(),
                      child: Text(row['name']?.toString() ?? 'جمعية')))
                  .toList(),
              onChanged: (value) => setState(() => charityId = value)),
        const SizedBox(height: 10),
        _field(title, 'اسم التبرع'),
        _field(description, 'وصف التبرع', maxLines: 2),
        Row(children: [
          Expanded(child: _field(quantity, 'الكمية', number: true)),
          const SizedBox(width: 10),
          Expanded(child: _field(condition, 'الحالة'))
        ]),
        if (_validationMessage != null)
          Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 6),
              child: Text(_validationMessage!,
                  style: const TextStyle(
                      color: Color(0xFFD64545),
                      fontSize: 12,
                      fontWeight: FontWeight.w700))),
        const SizedBox(height: 6),
        FilledButton.icon(
            onPressed: widget.charities.isEmpty
                ? null
                : () {
                    final q = int.tryParse(quantity.text.trim());
                    String? error;
                    if (charityId == null) {
                      error = 'اختر الجمعية المستفيدة';
                    } else if (title.text.trim().isEmpty)
                      error = 'اكتب اسم التبرع';
                    else if (q == null || q <= 0)
                      error = 'الكمية يجب أن تكون أكبر من صفر';
                    if (error != null) {
                      setState(() => _validationMessage = error);
                      return;
                    }
                    Navigator.pop(
                        context,
                        _DonationDraft(
                            charityId: charityId!,
                            title: title.text.trim(),
                            description: description.text.trim(),
                            condition: condition.text.trim(),
                            quantity: q!));
                  },
            icon: const Icon(Icons.volunteer_activism_rounded),
            label: const Text('إرسال للجمعية')),
      ]);
}

Widget _field(TextEditingController controller, String label,
        {bool number = false, int maxLines = 1}) =>
    Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(
            controller: controller,
            maxLines: maxLines,
            keyboardType: number ? TextInputType.number : TextInputType.text,
            textDirection: TextDirection.rtl,
            decoration: InputDecoration(
                labelText: label, border: const OutlineInputBorder())));

Widget _sheet(BuildContext context, String title, List<Widget> children) =>
    Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
            child: Container(
                padding: EdgeInsets.fromLTRB(
                    18, 18, 18, MediaQuery.of(context).viewInsets.bottom + 18),
                decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(28))),
                child: SingleChildScrollView(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                      Text(title,
                          style: const TextStyle(
                              color: _BusinessOperationsPageState.darkGreen,
                              fontSize: 20,
                              fontWeight: FontWeight.w900)),
                      const SizedBox(height: 16),
                      ...children
                    ])))));

class BusinessPickupScannerPage extends StatefulWidget {
  final BusinessOperationsRepository repository;
  const BusinessPickupScannerPage({super.key, required this.repository});
  @override
  State<BusinessPickupScannerPage> createState() =>
      _BusinessPickupScannerPageState();
}

class _BusinessPickupScannerPageState extends State<BusinessPickupScannerPage> {
  final controller = MobileScannerController();
  final manual = TextEditingController();
  bool busy = false;

  Future<void> _verify(String value) async {
    if (busy || value.trim().isEmpty) return;
    setState(() => busy = true);
    await controller.stop();
    try {
      await widget.repository.verifyPickupCode(value);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() => busy = false);
      await controller.start();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(AppErrorMapper.message(error,
              fallback: 'الكود غير صحيح أو منتهي.'))));
    }
  }

  Future<void> _manualCode() async {
    manual.clear();
    final value = await showDialog<String>(
        context: context,
        builder: (dialogContext) => Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
                title: const Text('إدخال كود الاستلام'),
                content: TextField(
                    controller: manual,
                    autofocus: true,
                    textDirection: TextDirection.ltr,
                    decoration: const InputDecoration(
                        hintText: 'اكتب الكود', border: OutlineInputBorder())),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('إلغاء')),
                  FilledButton(
                      onPressed: () =>
                          Navigator.pop(dialogContext, manual.text),
                      child: const Text('تحقق'))
                ])));
    if (value != null) await _verify(value);
  }

  @override
  void dispose() {
    controller.dispose();
    manual.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          title: const Text('سكان الاستلام'),
          actions: [
            IconButton(
                onPressed: busy ? null : _manualCode,
                icon: const Icon(Icons.keyboard_alt_outlined))
          ]),
      body: Stack(fit: StackFit.expand, children: [
        MobileScanner(
            controller: controller,
            onDetect: (capture) {
              for (final barcode in capture.barcodes) {
                final value = barcode.rawValue;
                if (value != null && value.isNotEmpty) {
                  _verify(value);
                  break;
                }
              }
            }),
        Center(
            child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                    border:
                        Border.all(color: const Color(0xFF66D49C), width: 4),
                    borderRadius: BorderRadius.circular(24)))),
        Positioned(
            left: 22,
            right: 22,
            bottom: 32,
            child: FilledButton.icon(
                onPressed: busy ? null : _manualCode,
                icon: const Icon(Icons.keyboard_alt_outlined),
                label: Text(busy ? 'جارٍ التحقق...' : 'أو اكتب الكود يدويًا')))
      ]));
}
