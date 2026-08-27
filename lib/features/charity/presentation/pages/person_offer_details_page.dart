import 'package:carousel_slider/carousel_slider.dart';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:loqma/core/pickup/presentation/pages/pickup_qr_page.dart';
import 'package:loqma/core/services/supabase_service.dart';
import 'package:loqma/features/auth/presentation/pages/login_page.dart';

class PersonOfferDetailsPage extends StatefulWidget {
  final Map<String, dynamic> offer;

  const PersonOfferDetailsPage({super.key, required this.offer});

  @override
  State<PersonOfferDetailsPage> createState() => _PersonOfferDetailsPageState();
}

class _PersonOfferDetailsPageState extends State<PersonOfferDetailsPage> {
  final _client = Supabase.instance.client;
  bool _isBooking = false;
  bool _hasRequested = false;
  String _requestStatus = '';
  String? _requestId;

  Map<String, dynamic> get offer => widget.offer;
  Map<String, dynamic>? get business {
    final value = offer['businesses'];
    return value is Map ? Map<String, dynamic>.from(value) : null;
  }

  @override
  void initState() {
    super.initState();
    _checkExistingRequest();
  }

  Future<void> _checkExistingRequest() async {
    try {
      final user = await SupabaseService().getCurrentUser();
      final offerId = _string('id');
      if (user == null || offerId.isEmpty) return;

      final row = await _client
          .from('offer_requests')
          .select('id, status')
          .eq('offer_id', offerId)
          .eq('user_id', user.id)
          .order('requested_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (!mounted || row == null) return;
      setState(() {
        _hasRequested = true;
        _requestStatus = row['status']?.toString() ?? 'pending';
        _requestId = row['id']?.toString();
      });
    } catch (e) {
      debugPrint('Offer request check failed: $e');
    }
  }

  Future<void> _bookOffer() async {
    final user = await SupabaseService().getCurrentUser();
    if (user == null) {
      _showLoginRequired();
      return;
    }
    if (_isBooking) return;
    if (_hasRequested) {
      _snack('لقد قمت بطلب هذا العرض بالفعل', Colors.orange);
      return;
    }

    final offerId = _string('id');
    if (offerId.isEmpty) {
      _snack('بيانات العرض غير مكتملة', Colors.red);
      return;
    }
    if (!_isAvailable) {
      _snack('هذا العرض لم يعد متاحًا للحجز', Colors.orange);
      return;
    }

    setState(() => _isBooking = true);
    try {
      final restaurantId = await _resolveRestaurantId(offerId);
      if (restaurantId == null || restaurantId.isEmpty) {
        _snack('لا يوجد مطعم مرتبط بهذا العرض', Colors.red);
        return;
      }

      final rawResult = await _client.rpc(
        'create_food_offer_request',
        params: {
          'p_offer_id': offerId,
          'p_restaurant_id': restaurantId,
        },
      );
      final result = rawResult is List ? rawResult.first : rawResult;
      final requestId = result is Map ? result['id']?.toString() : null;
      if (requestId == null || requestId.isEmpty) {
        throw PostgrestException(message: 'تعذر إنشاء طلب العرض');
      }
      final response = {'id': requestId};

      if (!mounted) return;
      setState(() {
        _hasRequested = true;
        _requestStatus = 'pending';
        _requestId = response['id']?.toString();
      });
      _snack('تم إرسال طلبك للمطعم بنجاح', Colors.green);
    } catch (e) {
      debugPrint('Booking error: $e');
      final message = _friendlyError(e).toLowerCase();
      if (message.contains('duplicate') ||
          message.contains('already') ||
          message.contains('unique')) {
        if (mounted) {
          setState(() {
            _hasRequested = true;
            _requestStatus = 'pending';
          });
        }
        _snack('تم تسجيل طلبك بالفعل لهذا العرض', Colors.orange);
      } else if (message.contains('available') ||
          message.contains('quantity') ||
          message.contains('sold out')) {
        _snack('العرض لم يعد متاحًا بالكمية المطلوبة', Colors.orange);
      } else {
        _snack('تعذر إنشاء الحجز: ${_friendlyError(e)}', Colors.red);
      }
    } finally {
      if (mounted) setState(() => _isBooking = false);
    }
  }

  Future<String?> _resolveRestaurantId(String offerId) async {
    final businessId = _string('business_id');
    String? ownerId;

    if (businessId.isNotEmpty) {
      final businessRow = await _client
          .from('businesses')
          .select('user_id')
          .eq('id', businessId)
          .maybeSingle();
      ownerId = businessRow?['user_id']?.toString();
    }

    if (ownerId == null || ownerId.isEmpty) {
      final row = await _client
          .from('food_offers')
          .select('business_id')
          .eq('id', offerId)
          .maybeSingle();
      final id = row?['business_id']?.toString();
      if (id != null && id.isNotEmpty) {
        final businessRow = await _client
            .from('businesses')
            .select('user_id')
            .eq('id', id)
            .maybeSingle();
        ownerId = businessRow?['user_id']?.toString();
      }
    }

    if (ownerId == null || ownerId.isEmpty) return null;
    final restaurant = await _client
        .from('restaurants')
        .select('id')
        .eq('user_id', ownerId)
        .maybeSingle();
    return restaurant?['id']?.toString();
  }

  Future<void> _showPickupQr() async {
    final user = await SupabaseService().getCurrentUser();
    if (user == null) {
      _showLoginRequired();
      return;
    }

    try {
      final row = await _client
          .from('offer_requests')
          .select('id, pickup_token_hash, status')
          .eq('offer_id', _string('id'))
          .eq('user_id', user.id)
          .eq('status', 'ready_for_pickup')
          .maybeSingle();

      if (row == null) {
        _snack('الطلب غير جاهز للاستلام بعد', Colors.orange);
        return;
      }

      final restaurantId = await _resolveRestaurantId(_string('id'));
      if (!mounted || restaurantId == null || restaurantId.isEmpty) {
        _snack('لا يوجد مطعم مرتبط بالحجز', Colors.red);
        return;
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PickupQRPage(
            requestId: row['id'].toString(),
            businessId: restaurantId,
            existingToken: row['pickup_token_hash']?.toString(),
          ),
        ),
      );
    } catch (e) {
      _snack('تعذر فتح رمز الاستلام', Colors.red);
    }
  }

  bool get _isAvailable {
    final status = _string('status').toLowerCase();
    final expiry = _date('expiry_time');
    return (status == 'available' || status == 'active') &&
        (expiry == null || expiry.isAfter(DateTime.now()));
  }

  bool get _isUrgent {
    if (_string('priority').toLowerCase() == 'high') return true;
    final expiry = _date('expiry_time');
    return expiry != null &&
        expiry.difference(DateTime.now()).inHours <= 2 &&
        !expiry.isBefore(DateTime.now());
  }

  List<String> get _images {
    final result = <String>[];
    _collectImages(offer['food_offer_images'], result);
    _collectImages(offer['images'], result);
    _collectImages(offer['image_urls'], result);
    _collectImages(offer['offer_images'], result);
    _collectImages(offer['image'], result);
    return List<String>.unmodifiable(result);
  }

  void _collectImages(dynamic value, List<String> result) {
    if (value == null) return;
    if (value is List) {
      for (final item in value) {
        _collectImages(item, result);
      }
      return;
    }
    if (value is Map) {
      for (final key in const ['image_url', 'public_url', 'url', 'path']) {
        _collectImages(value[key], result);
      }
      return;
    }

    final text = value.toString().trim();
    if (text.isEmpty || text == 'null') return;
    try {
      final decoded = jsonDecode(text);
      if (decoded is List || decoded is Map) {
        _collectImages(decoded, result);
        return;
      }
    } catch (_) {
      // Plain URL; continue below.
    }
    for (final part in text.split(',')) {
      final url = part.trim();
      if (url.isNotEmpty && !result.contains(url)) result.add(url);
    }
  }

  String _string(String key) => offer[key]?.toString() ?? '';

  DateTime? _date(String key) {
    final raw = offer[key]?.toString();
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw)?.toLocal();
  }

  String _timeRemaining() {
    final expiry = _date('expiry_time');
    if (expiry == null) return 'غير محدد';
    final difference = expiry.difference(DateTime.now());
    if (difference.isNegative) return 'انتهى';
    if (difference.inDays > 0) return '${difference.inDays} يوم';
    if (difference.inHours > 0) return '${difference.inHours} ساعة';
    if (difference.inMinutes > 0) return '${difference.inMinutes} دقيقة';
    return 'أقل من دقيقة';
  }

  String _formatDate(String key) {
    final date = _date(key);
    return date == null
        ? 'غير محدد'
        : DateFormat('dd/MM/yyyy – HH:mm').format(date);
  }

  String _friendlyError(Object error) {
    final text = error.toString();
    if (text.contains('foreign key')) return 'المطعم غير مرتبط بشكل صحيح';
    if (text.contains('duplicate')) return 'تم إنشاء هذا الحجز من قبل';
    return text.length > 120 ? 'تحقق من الاتصال وحاول مرة أخرى' : text;
  }

  void _snack(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(message),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating),
    );
  }

  void _showLoginRequired() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text('تسجيل الدخول مطلوب'),
        content: const Text('سجّل الدخول أولًا حتى تتمكن من حجز الوجبة.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء')),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const LoginPage()));
            },
            icon: const Icon(Icons.login_rounded),
            label: const Text('تسجيل الدخول'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final gallery = _images;
    final title = _string('title').isEmpty ? 'عرض طعام' : _string('title');
    final restaurantName = business?['name']?.toString() ??
        _string('business_name').ifEmpty('مطعم قريب');

    return Scaffold(
      backgroundColor: colors.surface,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 330,
            pinned: true,
            elevation: 0,
            backgroundColor: colors.primary,
            leading: _circleButton(
                Icons.arrow_back_rounded, () => Navigator.pop(context)),
            actions: [
              _circleButton(Icons.share_rounded, _shareOffer),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: _HeroGallery(images: gallery, urgent: _isUrgent),
            ),
          ),
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.fromLTRB(18, 22, 18, 120),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(title,
                            style: TextStyle(
                                fontSize: 25,
                                fontWeight: FontWeight.w900,
                                color: colors.onSurface)),
                      ),
                      if (_isUrgent) _tag('عاجل', Colors.deepOrange),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.storefront_rounded,
                          size: 18, color: colors.primary),
                      const SizedBox(width: 6),
                      Expanded(
                          child: Text(restaurantName,
                              style: TextStyle(
                                  color: colors.onSurfaceVariant,
                                  fontWeight: FontWeight.w700))),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _infoGrid(colors),
                  const SizedBox(height: 18),
                  _sectionTitle('عن العرض', colors),
                  const SizedBox(height: 8),
                  Text(
                    _string('description').isEmpty
                        ? 'وجبة فائضة آمنة وجاهزة للاستلام.'
                        : _string('description'),
                    style: TextStyle(
                        color: colors.onSurfaceVariant,
                        height: 1.7,
                        fontSize: 15),
                  ),
                  const SizedBox(height: 20),
                  _sectionTitle('مكان الاستلام', colors),
                  const SizedBox(height: 8),
                  _locationCard(colors),
                  const SizedBox(height: 22),
                  _lifecycleTimeline(colors),
                  if (gallery.length > 1) ...[
                    const SizedBox(height: 20),
                    _sectionTitle('صور العرض', colors),
                    const SizedBox(height: 10),
                    _gallery(gallery.skip(1).toList()),
                  ],
                  const SizedBox(height: 20),
                  _requestStatusCard(colors),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomSheet: _bottomBar(colors),
    );
  }

  Widget _infoGrid(ColorScheme colors) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 2.25,
      children: [
        _infoTile(Icons.fastfood_rounded, 'الكمية',
            '${offer['quantity'] ?? 0} وجبات', colors.primary),
        _infoTile(
            Icons.timer_outlined, 'متبقي', _timeRemaining(), Colors.deepOrange),
        _infoTile(Icons.schedule_rounded, 'الاستلام قبل',
            _formatDate('pickup_before'), Colors.blue),
        _infoTile(
            Icons.verified_rounded,
            'الحالة',
            _isAvailable ? 'متاح' : 'غير متاح',
            _isAvailable ? Colors.green : Colors.grey),
      ],
    );
  }

  Widget _infoTile(IconData icon, String label, String value, Color color) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
          color: color.withAlpha(18), borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 8),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                Text(label,
                    style: TextStyle(
                        color: colors.onSurfaceVariant, fontSize: 10)),
                Text(value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: colors.onSurface,
                        fontSize: 12,
                        fontWeight: FontWeight.w800))
              ])),
        ],
      ),
    );
  }

  Widget _locationCard(ColorScheme colors) {
    final location = _string('pickup_location').isEmpty
        ? 'موقع المطعم غير محدد'
        : _string('pickup_location');
    return InkWell(
      onTap: _openLocation,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: colors.primary.withAlpha(15),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: colors.primary.withAlpha(45))),
        child: Row(children: [
          Icon(Icons.location_on_rounded, color: colors.primary),
          const SizedBox(width: 10),
          Expanded(
              child: Text(location,
                  style: TextStyle(
                      color: colors.onSurface, fontWeight: FontWeight.w700))),
          Icon(Icons.open_in_new_rounded, size: 18, color: colors.primary)
        ]),
      ),
    );
  }

  Widget _lifecycleTimeline(ColorScheme colors) {
    final current = _timelineIndex;
    const steps = <({String title, String subtitle, IconData icon})>[
      (
        title: 'تم نشر العرض',
        subtitle: 'العرض متاح للمستخدمين',
        icon: Icons.publish_rounded
      ),
      (
        title: 'تم إرسال الطلب',
        subtitle: 'طلب الحجز أُرسل للمطعم',
        icon: Icons.send_rounded
      ),
      (
        title: 'تمت الموافقة',
        subtitle: 'المطعم وافق على الطلب',
        icon: Icons.thumb_up_alt_rounded
      ),
      (
        title: 'جاهز للاستلام',
        subtitle: 'يمكنك إظهار رمز الاستلام',
        icon: Icons.inventory_2_rounded
      ),
      (
        title: 'تم الاستلام',
        subtitle: 'اكتملت عملية الاستلام بنجاح',
        icon: Icons.check_circle_rounded
      ),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.surfaceContainerHighest),
        boxShadow: const [
          BoxShadow(
              color: Color(0x08001E15), blurRadius: 14, offset: Offset(0, 5))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('مسار العرض', colors),
          const SizedBox(height: 18),
          ...List.generate(steps.length, (index) {
            final complete = index < current;
            final selected = index == current;
            final color =
                complete || selected ? colors.primary : colors.outline;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 34,
                  child: Column(
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: complete
                              ? colors.primary
                              : selected
                                  ? colors.primaryContainer
                                  : colors.surfaceContainerHighest,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: selected
                                  ? colors.primary
                                  : Colors.transparent,
                              width: 2),
                        ),
                        child: Icon(
                            complete ? Icons.check_rounded : steps[index].icon,
                            size: 15,
                            color: complete ? colors.onPrimary : color),
                      ),
                      if (index < steps.length - 1)
                        Container(
                            width: 2,
                            height: 35,
                            color: complete
                                ? colors.primary
                                : colors.surfaceContainerHighest),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2, bottom: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(steps[index].title,
                            style: TextStyle(
                                color: color,
                                fontSize: 14,
                                fontWeight: FontWeight.w900)),
                        const SizedBox(height: 3),
                        Text(steps[index].subtitle,
                            style: TextStyle(
                                color: colors.onSurfaceVariant,
                                fontSize: 11,
                                height: 1.3)),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  int get _timelineIndex {
    final status = _hasRequested
        ? _requestStatus.toLowerCase()
        : _string('status').toLowerCase();
    if (status == 'completed' || status == 'redeemed') return 5;
    if (status == 'ready_for_pickup') return 4;
    if (status == 'accepted' || status == 'approved') return 3;
    if (_hasRequested) return 2;
    return 1;
  }

  Widget _requestStatusCard(ColorScheme colors) {
    if (!_hasRequested) return const SizedBox.shrink();
    final data = _statusData(_requestStatus);
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
          color: data.$2.withAlpha(18),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: data.$2.withAlpha(60))),
      child: Row(children: [
        Icon(data.$1, color: data.$2, size: 27),
        const SizedBox(width: 10),
        Expanded(
            child: Text(data.$3,
                style: TextStyle(color: data.$2, fontWeight: FontWeight.w800))),
        if (_requestStatus == 'ready_for_pickup')
          IconButton(
              onPressed: _showPickupQr,
              icon: const Icon(Icons.qr_code_2_rounded))
      ]),
    );
  }

  (IconData, Color, String) _statusData(String status) {
    switch (status) {
      case 'accepted':
        return (
          Icons.check_circle_rounded,
          Colors.blue,
          'تم قبول طلبك من المطعم'
        );
      case 'ready_for_pickup':
        return (Icons.inventory_2_rounded, Colors.green, 'الطلب جاهز للاستلام');
      case 'completed':
        return (
          Icons.celebration_rounded,
          Colors.green,
          'تم استلام الوجبة بنجاح'
        );
      case 'cancelled':
        return (Icons.cancel_rounded, Colors.red, 'تم إلغاء هذا الطلب');
      default:
        return (
          Icons.hourglass_top_rounded,
          Colors.orange,
          'طلبك في انتظار موافقة المطعم'
        );
    }
  }

  Widget _bottomBar(ColorScheme colors) {
    final canBook = _isAvailable && !_hasRequested && !_isBooking;
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
        decoration: BoxDecoration(color: colors.surface, boxShadow: [
          BoxShadow(
              color: Colors.black.withAlpha(25),
              blurRadius: 18,
              offset: const Offset(0, -5))
        ]),
        child: SizedBox(
          width: double.infinity,
          height: 54,
          child: FilledButton.icon(
            onPressed: canBook
                ? _bookOffer
                : (_requestStatus == 'ready_for_pickup' ? _showPickupQr : null),
            icon: Icon(_isBooking
                ? Icons.hourglass_top_rounded
                : _requestStatus == 'ready_for_pickup'
                    ? Icons.qr_code_2_rounded
                    : Icons.calendar_month_rounded),
            label: Text(_isBooking ? 'جاري إرسال الطلب...' : _buttonLabel,
                style: const TextStyle(fontWeight: FontWeight.w900)),
          ),
        ),
      ),
    );
  }

  String get _buttonLabel {
    if (!_isAvailable && !_hasRequested) return 'العرض غير متاح';
    if (!_hasRequested) return 'احجز الوجبة الآن';
    switch (_requestStatus) {
      case 'accepted':
        return 'تم قبول الحجز';
      case 'ready_for_pickup':
        return 'إظهار رمز الاستلام';
      case 'completed':
        return 'تم التسليم';
      case 'cancelled':
        return 'تم إلغاء الحجز';
      default:
        return 'في انتظار موافقة المطعم';
    }
  }

  Widget _sectionTitle(String title, ColorScheme colors) => Text(title,
      style: TextStyle(
          fontSize: 18, fontWeight: FontWeight.w900, color: colors.onSurface));

  Widget _tag(String text, Color color) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
          color: color.withAlpha(25), borderRadius: BorderRadius.circular(100)),
      child: Text(text,
          style: TextStyle(
              color: color, fontWeight: FontWeight.w900, fontSize: 12)));

  Widget _circleButton(IconData icon, VoidCallback onPressed) => Container(
      margin: const EdgeInsets.all(9),
      decoration: BoxDecoration(
          color: Colors.black.withAlpha(95), shape: BoxShape.circle),
      child: IconButton(
          onPressed: onPressed, icon: Icon(icon, color: Colors.white)));

  Widget _gallery(List<String> images) => SizedBox(
      height: 100,
      child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: images.length,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (_, i) => ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.network(images[i],
                  width: 125,
                  height: 100,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                      width: 125,
                      color: Colors.grey.shade200,
                      child: const Icon(Icons.broken_image_outlined))))));

  Future<void> _shareOffer() async {
    final title = Uri.encodeComponent(_string('title'));
    final url = Uri.parse('https://www.google.com/search?q=$title');
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  Future<void> _openLocation() async {
    final latitude = double.tryParse(_string('latitude'));
    final longitude = double.tryParse(_string('longitude'));
    final query = latitude != null && longitude != null
        ? '$latitude,$longitude'
        : _string('pickup_location');
    if (query.isEmpty) return;
    final uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(query)}');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class _HeroGallery extends StatelessWidget {
  final List<String> images;
  final bool urgent;

  const _HeroGallery({required this.images, required this.urgent});

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty) return _placeholder();
    return CarouselSlider.builder(
      itemCount: images.length,
      itemBuilder: (_, index, __) => Image.network(images[index],
          fit: BoxFit.cover,
          width: double.infinity,
          errorBuilder: (_, __, ___) => _placeholder()),
      options: CarouselOptions(
          viewportFraction: 1,
          height: double.infinity,
          autoPlay: images.length > 1,
          enlargeCenterPage: false),
    );
  }

  Widget _placeholder() => Container(
      color: Colors.green.shade50,
      alignment: Alignment.center,
      child: Icon(Icons.restaurant_rounded,
          size: 85, color: Colors.green.shade200));
}

extension _StringFallback on String {
  String ifEmpty(String fallback) => trim().isEmpty ? fallback : this;
}
