// lib/features/donation/presentation/pages/offer_details_page.dart

import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:loqma/core/pickup/presentation/pages/pickup_qr_page.dart';
import 'package:loqma/core/services/supabase_service.dart';
import 'package:loqma/features/auth/presentation/pages/login_page.dart';

class OfferDetailsPage extends StatefulWidget {
  final Map<String, dynamic> offer;

  const OfferDetailsPage({super.key, required this.offer});

  @override
  State<OfferDetailsPage> createState() => _OfferDetailsPageState();
}

class _OfferDetailsPageState extends State<OfferDetailsPage> {
  final _client = Supabase.instance.client;
  bool _isBooking = false;
  bool _hasRequested = false;
  String _requestStatus = '';
  String? _requestId;
  int _requestCount = 0;
  bool _isRequestedByUser = false;
  bool _isAccepted = false;
  List<String> _cachedImages = [];
  bool _isLoadingImages = false;

  static const _green = Color(0xFF0B7650);
  static const _darkGreen = Color(0xFF123F31);
  static const _mint = Color(0xFFDDF3E8);
  static const _muted = Color(0xFF71837C);

  Map<String, dynamic> get offer => widget.offer;
  Map<String, dynamic>? get business {
    final value = offer['businesses'];
    return value is Map ? Map<String, dynamic>.from(value) : null;
  }

  // ✅ دالة _getImageUrl المعدلة - تدعم المسارات المختلفة مع try-catch
  String _getImageUrl(String? rawPath) {
    if (rawPath == null) return '';

    var path = rawPath.trim();
    if (path.isEmpty || path == 'null') return '';

    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }

    const bucket = 'restaurant-offers';

    path = path.replaceFirst(RegExp(r'^/+'), '');
    if (path.startsWith('$bucket/')) {
      path = path.substring(bucket.length + 1);
    }

    try {
      final url = _client.storage.from(bucket).getPublicUrl(path);
      debugPrint('📌 IMAGE URL: $url');
      return url;
    } catch (e) {
      debugPrint('❌ IMAGE URL ERROR: $e');
      return '';
    }
  }

  List<String> get _images {
    final result = <String>[];

    final images = offer['images'];
    if (images is List) {
      for (final item in images) {
        final url = item.toString();
        if (url.isNotEmpty && url != 'null') {
          result.add(url);
        }
      }
    }

    final single = offer['image']?.toString() ?? '';
    if (single.isNotEmpty && single != 'null' && !result.contains(single)) {
      result.add(single);
    }

    final imageUrl = offer['image_url']?.toString() ?? '';
    if (imageUrl.isNotEmpty &&
        imageUrl != 'null' &&
        !result.contains(imageUrl)) {
      result.add(imageUrl);
    }

    if (result.isEmpty && _cachedImages.isNotEmpty) {
      result.addAll(_cachedImages);
    }

    final nested = offer['food_offer_images'];
    if (nested is List) {
      for (final item in nested) {
        if (item is Map && item['image_url'] != null) {
          final url = item['image_url'].toString();
          if (url.isNotEmpty && url != 'null' && !result.contains(url)) {
            result.add(url);
          }
        }
      }
    }

    debugPrint('📌 FOUND IMAGES: $result');
    return result;
  }

  Future<void> _loadImagesFromStorage() async {
    final offerId = _string('id');
    final businessId = _string('business_id');

    if (offerId.isEmpty || _isLoadingImages) return;

    setState(() => _isLoadingImages = true);

    try {
      final bucket = 'restaurant-offers';
      final List<String> urls = [];

      // ✅ 1. جرب البحث في مجلد العرض مباشرة
      try {
        final files = await _client.storage.from(bucket).list(path: offerId);
        debugPrint('📌 Found ${files.length} files in $offerId');
        for (final file in files) {
          final url = _getImageUrl('$offerId/${file.name}');
          if (url.isNotEmpty) {
            urls.add(url);
          }
        }
      } catch (e) {
        debugPrint('⚠️ No files in $offerId folder');
      }

      // ✅ 2. جرب البحث في مجلد business_id
      if (urls.isEmpty && businessId.isNotEmpty) {
        try {
          final files =
              await _client.storage.from(bucket).list(path: businessId);
          debugPrint(
              '📌 Found ${files.length} files in business folder: $businessId');
          for (final file in files) {
            final url = _getImageUrl('$businessId/${file.name}');
            if (url.isNotEmpty) {
              urls.add(url);
            }
          }
        } catch (e) {
          debugPrint('⚠️ No files in business folder: $businessId');
        }
      }

      // ✅ 3. جرب البحث في مجلد restaurants
      if (urls.isEmpty) {
        try {
          final restaurantsList =
              await _client.storage.from(bucket).list(path: 'restaurants');
          for (final folder in restaurantsList) {
            if (folder.name == businessId || folder.name.contains(businessId)) {
              final subFiles = await _client.storage
                  .from(bucket)
                  .list(path: 'restaurants/${folder.name}');
              for (final file in subFiles) {
                final url =
                    _getImageUrl('restaurants/${folder.name}/${file.name}');
                if (url.isNotEmpty) {
                  urls.add(url);
                }
              }
            }
          }
        } catch (e) {
          debugPrint('⚠️ Error searching in restaurants folder: $e');
        }
      }

      if (mounted && urls.isNotEmpty) {
        setState(() {
          _cachedImages = urls;
          _isLoadingImages = false;
        });
      } else {
        setState(() => _isLoadingImages = false);
      }
    } catch (e) {
      debugPrint('❌ Error loading images from storage: $e');
      if (mounted) setState(() => _isLoadingImages = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _checkExistingRequest();
    _loadRequestCount();
    _loadImagesFromStorage();
  }

  Future<void> _loadRequestCount() async {
    try {
      final offerId = _string('id');
      if (offerId.isEmpty) return;

      final response = await _client
          .from('offer_requests')
          .select('id')
          .eq('offer_id', offerId)
          .filter('status', 'in', '("pending","accepted","ready_for_pickup")');

      if (!mounted) return;

      setState(() {
        _requestCount = response.length;
      });
    } catch (e) {
      debugPrint('❌ Error loading request count: $e');
    }
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
        _isRequestedByUser = true;
        _isAccepted = row['status'] == 'accepted';
      });
    } catch (e) {
      debugPrint('❌ Offer request check failed: $e');
    }
  }

  Future<void> _bookOffer() async {
    final user = await SupabaseService().getCurrentUser();
    if (user == null) {
      _showLoginRequired();
      return;
    }
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

      final response = await _client
          .from('offer_requests')
          .insert({
            'offer_id': offerId,
            'user_id': user.id,
            'restaurant_id': restaurantId,
            'status': 'pending',
            'requested_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .select('id')
          .single();

      if (!mounted) return;
      setState(() {
        _hasRequested = true;
        _requestStatus = 'pending';
        _requestId = response['id']?.toString();
        _isRequestedByUser = true;
        _isAccepted = false;
      });

      await _loadRequestCount();
      _snack('تم إرسال طلبك للمطعم بنجاح', Colors.green);
    } catch (e) {
      debugPrint('❌ Booking error: $e');
      _snack('تعذر إنشاء الحجز: ${_friendlyError(e)}', Colors.red);
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
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
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
            style: FilledButton.styleFrom(backgroundColor: _green),
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
    final gallery = _images;
    final title = _string('title').isEmpty ? 'عرض طعام' : _string('title');
    final restaurantName = business?['name']?.toString() ??
        _string('business_name').ifEmpty('مطعم قريب');
    final restaurantLogo = business?['logo']?.toString();

    return Scaffold(
      backgroundColor: const Color(0xFFF6FAF8),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 340,
            pinned: true,
            elevation: 0,
            backgroundColor: _green,
            leading: _circleButton(
                Icons.arrow_back_rounded, () => Navigator.pop(context)),
            actions: [
              _circleButton(Icons.share_rounded, _shareOffer),
              const SizedBox(width: 4),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: _isLoadingImages
                  ? Container(
                      color: _mint,
                      child: const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(_green),
                        ),
                      ),
                    )
                  : _HeroGallery(
                      images: gallery,
                      urgent: _isUrgent,
                      available: _isAvailable,
                      quantity: offer['quantity']?.toString() ?? '0',
                      getImageUrl: _getImageUrl,
                    ),
            ),
          ),
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.fromLTRB(18, 24, 18, 130),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: _darkGreen,
                          height: 1.25)),
                  const SizedBox(height: 12),
                  _restaurantRow(restaurantName, restaurantLogo),
                  const SizedBox(height: 22),
                  _quickFactsStrip(),
                  const SizedBox(height: 24),
                  _sectionTitle('عن العرض', Icons.description_outlined),
                  const SizedBox(height: 8),
                  Text(
                    _string('description').isEmpty
                        ? 'وجبة فائضة آمنة وجاهزة للاستلام.'
                        : _string('description'),
                    style: const TextStyle(
                        color: _muted, height: 1.7, fontSize: 14.5),
                  ),
                  const SizedBox(height: 22),
                  _sectionTitle('مكان الاستلام', Icons.location_on_outlined),
                  const SizedBox(height: 8),
                  _locationCard(),
                  const SizedBox(height: 22),
                  if (_requestCount > 0) ...[
                    _interestBanner(),
                    const SizedBox(height: 18),
                  ],
                  _lifecycleTimeline(),
                  if (gallery.length > 1) ...[
                    const SizedBox(height: 22),
                    _sectionTitle('صور العرض', Icons.photo_library_outlined),
                    const SizedBox(height: 10),
                    _gallery(gallery.skip(1).toList()),
                  ],
                  const SizedBox(height: 22),
                  _requestStatusCard(),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomSheet: _bottomBar(),
    );
  }

  Widget _restaurantRow(String restaurantName, String? logoUrl) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: _mint,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                  color: _green.withAlpha(30),
                  blurRadius: 10,
                  offset: const Offset(0, 3)),
            ],
          ),
          child: ClipOval(
            child: logoUrl != null && logoUrl.isNotEmpty
                ? Image.network(
                    _getImageUrl(logoUrl),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.storefront_rounded, color: _green),
                  )
                : const Icon(Icons.storefront_rounded, color: _green, size: 20),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(restaurantName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: _darkGreen,
                  fontWeight: FontWeight.w800,
                  fontSize: 14)),
        ),
      ],
    );
  }

  Widget _quickFactsStrip() {
    final facts = <({IconData icon, String label, String value, Color color})>[
      (
        icon: Icons.fastfood_rounded,
        label: 'الكمية',
        value: '${offer['quantity'] ?? 0} وجبات',
        color: _green,
      ),
      (
        icon: Icons.timer_outlined,
        label: 'متبقي',
        value: _timeRemaining(),
        color: const Color(0xFFE28B00),
      ),
      (
        icon: Icons.schedule_rounded,
        label: 'الاستلام قبل',
        value: _formatDate('pickup_before'),
        color: const Color(0xFF3679C8),
      ),
      (
        icon: Icons.verified_rounded,
        label: 'الحالة',
        value: _isAvailable ? 'متاح' : 'غير متاح',
        color: _isAvailable ? _green : Colors.grey,
      ),
      (
        icon: Icons.people_outline_rounded,
        label: 'الطلبات',
        value: _requestCount > 0 ? '$_requestCount شخص' : 'لا يوجد',
        color: _requestCount > 0 ? const Color(0xFF6651B5) : Colors.grey,
      ),
    ];

    return SizedBox(
      height: 84,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: facts.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, index) {
          final fact = facts[index];
          return Container(
            width: 128,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: fact.color.withAlpha(16),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: fact.color.withAlpha(45)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(fact.icon, color: fact.color, size: 20),
                Text(fact.label,
                    style: const TextStyle(color: _muted, fontSize: 10)),
                Text(fact.value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: _darkGreen,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w900)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _locationCard() {
    final location = _string('pickup_location').isEmpty
        ? 'موقع المطعم غير محدد'
        : _string('pickup_location');
    return InkWell(
      onTap: _openLocation,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: _mint.withAlpha(140),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _green.withAlpha(45))),
        child: Row(children: [
          Container(
            width: 42,
            height: 42,
            decoration:
                const BoxDecoration(color: _mint, shape: BoxShape.circle),
            child: const Icon(Icons.location_on_rounded, color: _green),
          ),
          const SizedBox(width: 12),
          Expanded(
              child: Text(location,
                  style: const TextStyle(
                      color: _darkGreen,
                      fontWeight: FontWeight.w700,
                      fontSize: 13))),
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
                color: Colors.white, shape: BoxShape.circle),
            child:
                const Icon(Icons.open_in_new_rounded, size: 16, color: _green),
          ),
        ]),
      ),
    );
  }

  Widget _interestBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: const Color(0xFFF0EBFF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDCD0F7)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
                color: Color(0xFFE4DAFB), shape: BoxShape.circle),
            child: const Icon(Icons.people_alt_rounded,
                color: Color(0xFF6651B5), size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _requestCount == 1
                  ? 'شخص واحد طلب هذا العرض بالفعل'
                  : '$_requestCount أشخاص طلبوا هذا العرض بالفعل',
              style: const TextStyle(
                color: Color(0xFF6651B5),
                fontWeight: FontWeight.w800,
                fontSize: 12.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _lifecycleTimeline() {
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2EEE8)),
        boxShadow: [
          BoxShadow(
              color: _darkGreen.withAlpha(12),
              blurRadius: 16,
              offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('مسار العرض', Icons.route_rounded),
          const SizedBox(height: 18),
          ...List.generate(steps.length, (index) {
            final complete = index < current;
            final selected = index == current;
            final color =
                complete || selected ? _green : const Color(0xFFB8C9C0);
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
                              ? _green
                              : selected
                                  ? _mint
                                  : const Color(0xFFEFF3F1),
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: selected ? _green : Colors.transparent,
                              width: 2),
                        ),
                        child: Icon(
                            complete ? Icons.check_rounded : steps[index].icon,
                            size: 15,
                            color: complete ? Colors.white : color),
                      ),
                      if (index < steps.length - 1)
                        Container(
                            width: 2,
                            height: 35,
                            color: complete ? _green : const Color(0xFFE3ECE7)),
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
                            style: const TextStyle(
                                color: _muted, fontSize: 11, height: 1.3)),
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
    if (status == 'completed' || status == 'redeemed') return 4;
    if (status == 'ready_for_pickup') return 3;
    if (status == 'accepted' || status == 'approved') return 2;
    if (_hasRequested) return 1;
    return 0;
  }

  Widget _requestStatusCard() {
    if (!_hasRequested) return const SizedBox.shrink();
    final data = _statusData(_requestStatus);
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
          color: data.$2.withAlpha(18),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: data.$2.withAlpha(60))),
      child: Row(children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
              color: data.$2.withAlpha(35), shape: BoxShape.circle),
          child: Icon(data.$1, color: data.$2, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
            child: Text(data.$3,
                style: TextStyle(
                    color: data.$2,
                    fontWeight: FontWeight.w800,
                    fontSize: 13))),
        if (_requestStatus == 'ready_for_pickup')
          Container(
            decoration: const BoxDecoration(
                color: Colors.white, shape: BoxShape.circle),
            child: IconButton(
                onPressed: _showPickupQr,
                icon: const Icon(Icons.qr_code_2_rounded)),
          ),
      ]),
    );
  }

  (IconData, Color, String) _statusData(String status) {
    switch (status) {
      case 'accepted':
        return (
          Icons.check_circle_rounded,
          const Color(0xFF3679C8),
          'تم قبول طلبك من المطعم'
        );
      case 'ready_for_pickup':
        return (Icons.inventory_2_rounded, _green, 'الطلب جاهز للاستلام');
      case 'completed':
        return (Icons.celebration_rounded, _green, 'تم استلام الوجبة بنجاح');
      case 'cancelled':
        return (
          Icons.cancel_rounded,
          const Color(0xFFD64545),
          'تم إلغاء هذا الطلب'
        );
      default:
        return (
          Icons.hourglass_top_rounded,
          const Color(0xFFE28B00),
          'طلبك في انتظار موافقة المطعم'
        );
    }
  }

  Widget _bottomBar() {
    final canBook = _isAvailable && !_hasRequested && !_isBooking;
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
                color: Colors.black.withAlpha(20),
                blurRadius: 20,
                offset: const Offset(0, -6)),
          ],
        ),
        child: Row(
          children: [
            if (!_hasRequested) ...[
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('الكمية المتاحة',
                      style: TextStyle(color: _muted, fontSize: 10)),
                  Text('${offer['quantity'] ?? 0} وجبة',
                      style: const TextStyle(
                          color: _darkGreen,
                          fontSize: 15,
                          fontWeight: FontWeight.w900)),
                ],
              ),
              const SizedBox(width: 14),
            ],
            Expanded(
              child: SizedBox(
                height: 54,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor:
                        canBook || _requestStatus == 'ready_for_pickup'
                            ? _green
                            : const Color(0xFFB8C9C0),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(17)),
                  ),
                  onPressed: canBook
                      ? _bookOffer
                      : (_requestStatus == 'ready_for_pickup'
                          ? _showPickupQr
                          : null),
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
          ],
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

  Widget _sectionTitle(String title, IconData icon) => Row(
        children: [
          Icon(icon, color: _green, size: 19),
          const SizedBox(width: 7),
          Text(title,
              style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: _darkGreen)),
        ],
      );

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
          itemBuilder: (_, i) {
            final imageUrl = _getImageUrl(images[i]);
            return ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                imageUrl,
                width: 125,
                height: 100,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    width: 125,
                    height: 100,
                    color: _mint,
                    child: Center(
                      child: CircularProgressIndicator(
                        color: _green,
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                                loadingProgress.expectedTotalBytes!
                            : null,
                      ),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  debugPrint('❌ IMAGE LOAD ERROR: $error');
                  debugPrint('❌ FAILED IMAGE URL: $imageUrl');
                  return Container(
                    width: 125,
                    height: 100,
                    color: _mint,
                    alignment: Alignment.center,
                    child:
                        const Icon(Icons.broken_image_outlined, color: _green),
                  );
                },
              ),
            );
          }));

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

class _HeroGallery extends StatefulWidget {
  final List<String> images;
  final bool urgent;
  final bool available;
  final String quantity;
  final String Function(String?) getImageUrl;

  const _HeroGallery({
    required this.images,
    required this.urgent,
    required this.available,
    required this.quantity,
    required this.getImageUrl,
  });

  @override
  State<_HeroGallery> createState() => _HeroGalleryState();
}

class _HeroGalleryState extends State<_HeroGallery> {
  int _currentIndex = 0;

  static const _green = Color(0xFF0B7650);

  @override
  Widget build(BuildContext context) {
    final validImages =
        widget.images.where((img) => img.isNotEmpty && img != 'null').toList();

    return Stack(
      fit: StackFit.expand,
      children: [
        validImages.isEmpty
            ? _placeholder()
            : CarouselSlider.builder(
                itemCount: validImages.length,
                itemBuilder: (_, index, __) {
                  final imageUrl = widget.getImageUrl(validImages[index]);
                  return Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        color: const Color(0xFFDDF3E8),
                        child: Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                : null,
                            color: _green,
                          ),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      debugPrint('❌ HERO IMAGE LOAD ERROR: $error');
                      return _placeholder();
                    },
                  );
                },
                options: CarouselOptions(
                  viewportFraction: 1,
                  height: double.infinity,
                  autoPlay: validImages.length > 1,
                  enlargeCenterPage: false,
                  onPageChanged: (index, _) =>
                      setState(() => _currentIndex = index),
                ),
              ),
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.55, 1],
                  colors: [
                    Colors.transparent,
                    Colors.black.withAlpha(140),
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: 100,
          right: 16,
          child: Row(
            children: [
              if (widget.urgent) _badge('عاجل', const Color(0xFFE28B00)),
              if (!widget.urgent && !widget.available)
                _badge('غير متاح', Colors.grey.shade600),
            ],
          ),
        ),
        Positioned(
          top: 100,
          left: 16,
          child: _badge('${widget.quantity} وجبة متبقية', _green),
        ),
        if (validImages.length > 1)
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                validImages.length > 6 ? 6 : validImages.length,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: index == _currentIndex ? 18 : 6,
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: index == _currentIndex
                        ? Colors.white
                        : Colors.white.withAlpha(140),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _badge(String text, Color color) => Container(
        margin: const EdgeInsets.only(left: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
                color: color.withAlpha(70),
                blurRadius: 10,
                offset: const Offset(0, 3)),
          ],
        ),
        child: Text(text,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 11.5,
                fontWeight: FontWeight.w900)),
      );

  Widget _placeholder() => Container(
        color: const Color(0xFFDDF3E8),
        alignment: Alignment.center,
        child: const Icon(
          Icons.restaurant_rounded,
          size: 85,
          color: Color(0xFFA9D6C0),
        ),
      );
}

extension _StringFallback on String {
  String ifEmpty(String fallback) => trim().isEmpty ? fallback : this;
}
