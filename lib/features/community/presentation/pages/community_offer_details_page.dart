// lib/features/community/presentation/pages/community_offer_details_page.dart

import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:loqma/features/community/data/repositories/community_offer_repository.dart';
import 'package:loqma/features/community/presentation/pages/user_profile_page.dart';

class CommunityOfferDetailsPage extends StatefulWidget {
  final Map<String, dynamic> offer;

  const CommunityOfferDetailsPage({super.key, required this.offer});

  @override
  State<CommunityOfferDetailsPage> createState() =>
      _CommunityOfferDetailsPageState();
}

class _CommunityOfferDetailsPageState extends State<CommunityOfferDetailsPage> {
  final CommunityOfferRepository _repository = CommunityOfferRepository();

  // ═══════════════════════════════════════════════════════════
  // ✅ الحالة
  // ═══════════════════════════════════════════════════════════
  Map<String, dynamic> _offer = <String, dynamic>{};

  bool _fetchingContacts = false;
  bool _contactsFetched = false;
  bool _isOwner = false;

  List<String> _resolvedImages = [];
  bool _refreshingImages = false;

  // ✅ المواصفات الديناميكية
  List<Map<String, dynamic>> _marketplaceAttributes = [];
  bool _loadingAttributes = false;
  bool _attributesLoaded = false;

  Map<String, dynamic> get offer => _offer;

  @override
  void initState() {
    super.initState();
    _offer = Map<String, dynamic>.from(widget.offer);
    _resolvedImages = _extractRawImages();

    _checkIfOwner();
    _ensureContactsLoaded();
    _refreshImageUrls();
    _loadMarketplaceAttributes();
  }

  @override
  void didUpdateWidget(covariant CommunityOfferDetailsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.offer, widget.offer)) {
      _offer = Map<String, dynamic>.from(widget.offer);
      _contactsFetched = false;
      _resolvedImages = _extractRawImages();
      _attributesLoaded = false;
      _marketplaceAttributes = [];
      _ensureContactsLoaded();
      _refreshImageUrls();
      _loadMarketplaceAttributes();
    }
  }

  // ═══════════════════════════════════════════════════════════
  // ✅ جلب الأرقام
  // ═══════════════════════════════════════════════════════════
  Future<void> _ensureContactsLoaded() async {
    final existingPhone = _offer['phone']?.toString().trim() ?? '';
    final existingWhatsapp = _offer['whatsapp']?.toString().trim() ?? '';

    if (existingPhone.isNotEmpty || existingWhatsapp.isNotEmpty) {
      _contactsFetched = true;
      return;
    }

    final offerId = _offer['id']?.toString() ?? '';
    final ownerId = _offer['owner_id']?.toString() ?? '';

    if (offerId.isEmpty && ownerId.isEmpty) {
      _contactsFetched = true;
      return;
    }

    if (mounted) setState(() => _fetchingContacts = true);

    String phone = '';
    String whatsapp = '';

    if (offerId.isNotEmpty) {
      try {
        final data = await Supabase.instance.client
            .from('community_offers')
            .select('phone, whatsapp, owner_id')
            .eq('id', offerId)
            .maybeSingle();

        if (data != null) {
          phone = data['phone']?.toString().trim() ?? '';
          whatsapp = data['whatsapp']?.toString().trim() ?? '';

          if (ownerId.isEmpty) {
            final dbOwnerId = data['owner_id']?.toString() ?? '';
            if (dbOwnerId.isNotEmpty) {
              _offer['owner_id'] = dbOwnerId;
            }
          }
        }
      } catch (e) {
        debugPrint('❌ [Details] fetch community_offers error: $e');
      }
    }

    final finalOwnerId = _offer['owner_id']?.toString() ?? '';

    if ((phone.isEmpty || whatsapp.isEmpty) && finalOwnerId.isNotEmpty) {
      try {
        final userData = await Supabase.instance.client
            .from('users')
            .select('phone, whatsapp')
            .eq('id', finalOwnerId)
            .maybeSingle();

        if (userData != null) {
          final userPhone = userData['phone']?.toString().trim() ?? '';
          final userWhatsapp = userData['whatsapp']?.toString().trim() ?? '';

          if (phone.isEmpty) phone = userPhone;
          if (whatsapp.isEmpty) whatsapp = userWhatsapp;
        }
      } catch (e) {
        debugPrint('❌ [Details] fetch users error: $e');
      }
    }

    if (!mounted) return;

    if (whatsapp.isEmpty && phone.isNotEmpty) {
      whatsapp = phone;
    }

    setState(() {
      _offer['phone'] = phone;
      _offer['whatsapp'] = whatsapp;
      _contactsFetched = true;
      _fetchingContacts = false;
    });
  }

  // ═══════════════════════════════════════════════════════════
  // ✅ تحميل المواصفات الديناميكية حسب التصنيف
  // ═══════════════════════════════════════════════════════════
  Future<void> _loadMarketplaceAttributes() async {
    if (_attributesLoaded) return;

    final directMarketplaceOfferId =
        _offer['marketplace_offer_id']?.toString().trim() ?? '';
    final sourceOfferId = _offer['id']?.toString().trim() ?? '';

    if (directMarketplaceOfferId.isEmpty && sourceOfferId.isEmpty) {
      if (mounted) setState(() => _attributesLoaded = true);
      return;
    }

    if (mounted) setState(() => _loadingAttributes = true);

    try {
      final client = Supabase.instance.client;

      // 1) نحدد marketplace_offer_id
      String marketplaceOfferId = directMarketplaceOfferId;

      if (marketplaceOfferId.isEmpty && sourceOfferId.isNotEmpty) {
        final moRow = await client
            .from('marketplace_offers')
            .select('id')
            .eq('source_type', 'community')
            .eq('source_id', sourceOfferId)
            .maybeSingle();

        marketplaceOfferId = moRow?['id']?.toString() ?? '';
      }

      if (marketplaceOfferId.isEmpty) {
        if (mounted) {
          setState(() {
            _attributesLoaded = true;
            _loadingAttributes = false;
          });
        }
        return;
      }

      // 2) نجيب صفوف الـ attributes المخزنة للعرض
      final moaRowsRaw = await client
          .from('marketplace_offer_attributes')
          .select('attribute_id, option_id, value_text, value_number')
          .eq('marketplace_offer_id', marketplaceOfferId);

      final moaRows = (moaRowsRaw as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      if (moaRows.isEmpty) {
        if (mounted) {
          setState(() {
            _attributesLoaded = true;
            _loadingAttributes = false;
          });
        }
        return;
      }

      final attributeIds = moaRows
          .map((r) => r['attribute_id']?.toString() ?? '')
          .where((s) => s.isNotEmpty)
          .toSet()
          .toList();

      final optionIds = moaRows
          .map((r) => r['option_id']?.toString() ?? '')
          .where((s) => s.isNotEmpty)
          .toSet()
          .toList();

      // 3) نجيب الـ attributes نفسها
      final attributesRaw = await client
          .from('marketplace_attributes')
          .select('id, slug, name_ar, input_type, icon, sort_order')
          .inFilter('id', attributeIds);

      final attributes = (attributesRaw as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      // 4) نجيب الـ options لو فيه
      List<Map<String, dynamic>> options = [];
      if (optionIds.isNotEmpty) {
        final optionsRaw = await client
            .from('marketplace_attribute_options')
            .select('id, value, label_ar')
            .inFilter('id', optionIds);

        options = (optionsRaw as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }

      // 5) نبني القائمة النهائية
      final Map<String, Map<String, dynamic>> attributesById = {
        for (final a in attributes) a['id']?.toString() ?? '': a,
      };
      final Map<String, Map<String, dynamic>> optionsById = {
        for (final o in options) o['id']?.toString() ?? '': o,
      };

      final result = <Map<String, dynamic>>[];

      for (final row in moaRows) {
        final attrId = row['attribute_id']?.toString() ?? '';
        final attr = attributesById[attrId];
        if (attr == null) continue;

        final optionId = row['option_id']?.toString() ?? '';
        final option = optionId.isNotEmpty ? optionsById[optionId] : null;

        final valueText = row['value_text']?.toString().trim() ?? '';
        final valueNumber = row['value_number'];

        String displayValue = '';

        if (option != null) {
          final label = option['label_ar']?.toString().trim() ?? '';
          final val = option['value']?.toString().trim() ?? '';
          displayValue = label.isNotEmpty ? label : val;
        } else if (valueText.isNotEmpty) {
          displayValue = valueText;
        } else if (valueNumber != null) {
          if (valueNumber is num) {
            displayValue = valueNumber == valueNumber.toInt()
                ? valueNumber.toInt().toString()
                : valueNumber.toString();
          } else {
            displayValue = valueNumber.toString();
          }
        }

        if (displayValue.trim().isEmpty) continue;

        result.add({
          'slug': attr['slug']?.toString() ?? '',
          'name_ar': attr['name_ar']?.toString() ?? '',
          'input_type': attr['input_type']?.toString() ?? '',
          'icon': attr['icon']?.toString(),
          'sort_order': (attr['sort_order'] as num?)?.toInt() ?? 0,
          'value': displayValue,
        });
      }

      result.sort((a, b) {
        final sa = (a['sort_order'] as num?)?.toInt() ?? 0;
        final sb = (b['sort_order'] as num?)?.toInt() ?? 0;
        return sa.compareTo(sb);
      });

      if (!mounted) return;

      setState(() {
        _marketplaceAttributes = result;
        _attributesLoaded = true;
        _loadingAttributes = false;
      });
    } catch (e, st) {
      debugPrint('❌ [Details] load attributes error: $e');
      debugPrint('$st');
      if (mounted) {
        setState(() {
          _attributesLoaded = true;
          _loadingAttributes = false;
        });
      }
    }
  }

  // ═══════════════════════════════════════════════════════════
  // ✅ بيانات صاحب العرض
  // ═══════════════════════════════════════════════════════════
  String get _ownerName => offer['owner_name']?.toString() ?? '';
  String get _ownerPhone => offer['phone']?.toString().trim() ?? '';
  String get _ownerWhatsapp {
    final w = offer['whatsapp']?.toString().trim() ?? '';
    return w.isNotEmpty ? w : _ownerPhone;
  }

  String? get _ownerAvatar => offer['avatar_url']?.toString();
  String get _ownerId => offer['owner_id']?.toString() ?? '';

  DateTime? get _ownerJoinedDate {
    final raw = offer['joined_at']?.toString() ??
        offer['users']?['created_at']?.toString() ??
        offer['owner_created_at']?.toString();
    return DateTime.tryParse(raw ?? '');
  }

  // ═══════════════════════════════════════════════════════════
  // ✅ الصور
  // ═══════════════════════════════════════════════════════════
  List<String> get _images => _resolvedImages;

  List<String> _extractRawImages() {
    final result = <String>[];

    void add(dynamic v) {
      if (v == null) return;
      final s = v.toString().trim();
      if (s.isEmpty || s == 'null' || s == 'undefined') return;
      if (s.startsWith('file://')) return;
      result.add(s);
    }

    add(_offer['image']);

    final imgs = _offer['images'];
    if (imgs is List) {
      for (final i in imgs) {
        add(i);
      }
    }

    return result.toSet().toList();
  }

  Future<void> _refreshImageUrls() async {
    final rawImages = _extractRawImages();
    if (rawImages.isEmpty) {
      if (mounted) setState(() => _refreshingImages = false);
      return;
    }

    if (mounted) setState(() => _refreshingImages = true);

    final fresh = <String>[];

    for (final url in rawImages) {
      final freshUrl = await _regenerateSignedUrl(url);
      if (freshUrl.isNotEmpty) fresh.add(freshUrl);
    }

    if (!mounted) return;

    setState(() {
      _resolvedImages = fresh.toSet().toList();
      _refreshingImages = false;
    });
  }

  Future<String> _regenerateSignedUrl(String url) async {
    if (!url.contains('supabase.co')) return url;
    if (url.contains('/object/public/')) return url;

    final match = RegExp(
      r'/storage/v1/object/sign/([^/]+)/([^?]+)',
    ).firstMatch(url);

    if (match == null) return url;

    final bucket = match.group(1) ?? '';
    final path = match.group(2) ?? '';

    if (bucket.isEmpty || path.isEmpty) return url;

    try {
      final signed = await Supabase.instance.client.storage
          .from(bucket)
          .createSignedUrl(path, 60 * 60 * 24 * 7);
      return signed;
    } catch (e) {
      debugPrint('❌ [Details] regen signed URL failed: $e');
      return url;
    }
  }

  // ═══════════════════════════════════════════════════════════
  // ✅ الوقت
  // ═══════════════════════════════════════════════════════════
  String _timeRemaining() {
    final expiry = DateTime.tryParse(offer['expiry_time']?.toString() ?? '');
    if (expiry == null) return 'غير محدد';
    final diff = expiry.difference(DateTime.now());
    if (diff.isNegative) return 'انتهى';
    if (diff.inDays > 0) return '${diff.inDays} يوم';
    if (diff.inHours > 0) return '${diff.inHours} ساعة';
    if (diff.inMinutes > 0) return '${diff.inMinutes} دقيقة';
    return 'أقل من دقيقة';
  }

  String _memberSince() {
    final joined = _ownerJoinedDate;
    if (joined == null) return 'منضم حديثاً';
    final now = DateTime.now();
    final diff = now.difference(joined);
    if (diff.inDays < 1) return 'منضم اليوم';
    if (diff.inDays < 30) return 'منضم منذ ${diff.inDays} يوم';
    if (diff.inDays < 365) return 'منضم منذ ${(diff.inDays / 30).floor()} شهر';
    return 'منضم منذ ${(diff.inDays / 365).floor()} سنة';
  }

  // ═══════════════════════════════════════════════════════════
  // ✅ Normalize phone
  // ═══════════════════════════════════════════════════════════
  String _normalizePhone(String phone) {
    var cleaned = phone.replaceAll(RegExp(r'[^0-9]'), '');

    if (cleaned.startsWith('00')) {
      cleaned = cleaned.substring(2);
    }

    if (cleaned.startsWith('20') && cleaned.length >= 12) {
      return cleaned;
    }

    if (cleaned.startsWith('0') && cleaned.length == 11) {
      return '20${cleaned.substring(1)}';
    }

    if (cleaned.startsWith('1') && cleaned.length == 10) {
      return '20$cleaned';
    }

    return cleaned;
  }

  // ═══════════════════════════════════════════════════════════
  // ✅ WhatsApp / Phone
  // ═══════════════════════════════════════════════════════════
  Future<void> _openWhatsApp() async {
    if (_fetchingContacts) {
      _snack('جاري تحميل البيانات...', Colors.orange);
      return;
    }

    final rawPhone = _ownerWhatsapp;
    if (rawPhone.isEmpty) {
      _snack('لا يوجد رقم واتساب متاح لهذا العرض', Colors.orange);
      return;
    }

    final phone = _normalizePhone(rawPhone);
    if (phone.isEmpty) {
      _snack('رقم الواتساب غير صالح', Colors.orange);
      return;
    }

    final url = 'https://wa.me/$phone';
    final uri = Uri.parse(url);

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('❌ WhatsApp open error: $e');
      _snack('تعذر فتح واتساب: $e', Colors.red);
    }
  }

  Future<void> _openPhone() async {
    if (_fetchingContacts) {
      _snack('جاري تحميل البيانات...', Colors.orange);
      return;
    }

    final rawPhone = _ownerPhone;
    if (rawPhone.isEmpty) {
      _snack('لا يوجد رقم هاتف متاح لهذا العرض', Colors.orange);
      return;
    }

    final phone = _normalizePhone(rawPhone);
    if (phone.isEmpty) {
      _snack('رقم الهاتف غير صالح', Colors.orange);
      return;
    }

    final url = 'tel:$phone';
    final uri = Uri.parse(url);

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('❌ Phone open error: $e');
      _snack('تعذر إجراء الاتصال: $e', Colors.red);
    }
  }

  void _snack(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // ✅ التقييمات
  // ═══════════════════════════════════════════════════════════
  Future<List<Map<String, dynamic>>> _loadReviews() async {
    final offerId = offer['id']?.toString() ?? '';
    if (offerId.isEmpty) return [];
    return await _repository.getOfferReviews(offerId);
  }

  Future<void> _addReview() async {
    final offerId = offer['id']?.toString() ?? '';
    if (offerId.isEmpty) {
      _snack('بيانات العرض غير مكتملة', Colors.red);
      return;
    }

    int selectedRating = 5;
    String comment = '';

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
            title: const Text('قيّم تجربتك',
                style: TextStyle(fontWeight: FontWeight.w900)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('شارك تجربتك مع صاحب العرض',
                    style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    return IconButton(
                      onPressed: () =>
                          setDialogState(() => selectedRating = index + 1),
                      icon: Icon(
                        Icons.star_rounded,
                        color: index < selectedRating
                            ? Colors.amber
                            : Colors.grey.shade300,
                        size: 34,
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 6),
                TextField(
                  onChanged: (value) => comment = value,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'اكتب تعليقك (اختياري)',
                    filled: true,
                    fillColor: const Color(0xFFF7F8FA),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('إلغاء'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
                onPressed: () async {
                  try {
                    await _repository.addReview(
                      offerId: offerId,
                      rating: selectedRating,
                      comment: comment.isEmpty ? null : comment,
                    );
                    Navigator.pop(dialogContext);
                    _snack('تم إضافة التقييم بنجاح', Colors.green);
                    setState(() {});
                  } catch (e) {
                    _snack('تعذر إضافة التقييم: $e', Colors.red);
                  }
                },
                child: const Text('إرسال'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _checkIfOwner() async {
    final offerId = offer['id']?.toString() ?? '';
    if (offerId.isEmpty) return;

    final isOwner = await _repository.isCurrentUserOwner(offerId);
    if (mounted) {
      setState(() => _isOwner = isOwner);
    }
  }

  void _openOwnerProfile() {
    if (_ownerId.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserProfilePage(
          userId: _ownerId,
          userName: _ownerName,
          userAvatar: _ownerAvatar,
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // ✅ فتح الموقع
  // ═══════════════════════════════════════════════════════════
  Future<void> _openLocation() async {
    final locationText = offer['pickup_location']?.toString().trim() ?? '';

    if (locationText.isEmpty) {
      _snack('لا يوجد مكان استلام محدد', Colors.orange);
      return;
    }

    final geoUri = Uri.parse(
      'geo:0,0?q=${Uri.encodeComponent(locationText)}',
    );

    final googleMapsUri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(locationText)}',
    );

    try {
      if (await canLaunchUrl(geoUri)) {
        await launchUrl(geoUri);
        return;
      }
    } catch (e) {
      debugPrint('⚠️ geo: failed, trying Google Maps: $e');
    }

    try {
      await launchUrl(googleMapsUri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('❌ Location open error: $e');
      _snack('تعذر فتح الخريطة', Colors.red);
    }
  }

  // ═══════════════════════════════════════════════════════════
  // ✅ BUILD
  // ═══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final colors = ColorScheme.fromSeed(
      seedColor: const Color(0xFFE95D4E),
      brightness: Brightness.light,
      surface: const Color(0xFFF7F8FA),
    );
    final title = offer['title']?.toString() ?? 'عرض مستخدم';
    final description = offer['description']?.toString() ?? '';
    final price = (offer['price'] as num?)?.toDouble() ?? 0;
    final images = _images;

    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: colors,
        scaffoldBackgroundColor: const Color(0xFFF7F8FA),
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F8FA),
        extendBody: true,
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ─── SliverAppBar
            SliverAppBar(
              expandedHeight: 390,
              pinned: true,
              elevation: 0,
              scrolledUnderElevation: 0,
              backgroundColor: const Color(0xFFF7F8FA),
              surfaceTintColor: Colors.transparent,
              leading: _roundAppBarButton(
                Icons.arrow_back_rounded,
                () => Navigator.pop(context),
              ),
              actions: [
                _roundAppBarButton(
                  Icons.share_rounded,
                  () => _snack('مشاركة العرض قريبًا', colors.primary),
                ),
                const SizedBox(width: 10),
              ],
              flexibleSpace: FlexibleSpaceBar(
                collapseMode: CollapseMode.parallax,
                background: Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: _HeroGallery(images: images),
                ),
              ),
            ),

            // ─── المحتوى
            SliverToBoxAdapter(
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFF7F8FA),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(34)),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x14000000),
                      blurRadius: 18,
                      offset: Offset(0, -6),
                    ),
                  ],
                ),
                transform: Matrix4.translationValues(0, -22, 0),
                padding: const EdgeInsets.fromLTRB(20, 26, 20, 124),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ─── Handle
                    Center(
                      child: Container(
                        width: 44,
                        height: 5,
                        margin: const EdgeInsets.only(bottom: 18),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: .08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),

                    // ─── Badge + Price
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 11, vertical: 7),
                          decoration: BoxDecoration(
                            color: colors.primary.withValues(alpha: .10),
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.groups_rounded,
                                  size: 13, color: colors.primary),
                              const SizedBox(width: 5),
                              Text(
                                'عرض مجتمعي',
                                style: TextStyle(
                                  color: colors.primary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        if (price > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 7),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [
                                colors.primary,
                                colors.primary.withValues(alpha: .82),
                              ]),
                              borderRadius: BorderRadius.circular(30),
                              boxShadow: [
                                BoxShadow(
                                  color: colors.primary.withValues(alpha: .3),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Text(
                              '${price.toStringAsFixed(0)} جنيه',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // ─── العنوان
                    Text(
                      title,
                      style: const TextStyle(
                        color: Color(0xFF15171A),
                        fontSize: 26,
                        height: 1.2,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ─── صاحب العرض (inline)
                    InkWell(
                      onTap: _openOwnerProfile,
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 15,
                              backgroundColor:
                                  colors.primary.withValues(alpha: .12),
                              backgroundImage: (_ownerAvatar != null &&
                                      _ownerAvatar!.isNotEmpty)
                                  ? NetworkImage(_ownerAvatar!)
                                  : null,
                              child: (_ownerAvatar == null ||
                                      _ownerAvatar!.isEmpty)
                                  ? const Icon(Icons.person_rounded,
                                      size: 17, color: Color(0xFF87909A))
                                  : null,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _ownerName.isEmpty ? 'مستخدم وِصلة' : _ownerName,
                              style: const TextStyle(
                                color: Color(0xFF626B75),
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Icon(Icons.verified_rounded,
                                size: 16, color: colors.primary),
                            const Spacer(),
                            const Icon(Icons.chevron_left_rounded,
                                color: Color(0xFF9AA1A8)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),

                    // ─── معلومات العرض
                    _infoGrid(colors),
                    const SizedBox(height: 26),

                    // ─── وصف العرض
                    _premiumSectionTitle('عن العرض', Icons.notes_rounded),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFEDEEF1)),
                      ),
                      child: Text(
                        description.isEmpty ? 'عرض من مستخدم.' : description,
                        style: const TextStyle(
                          color: Color(0xFF626B75),
                          height: 1.8,
                          fontSize: 14.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ═══════════════════════════════════════════
                    // ✅ المواصفات الديناميكية
                    // ═══════════════════════════════════════════
                    if (_loadingAttributes) ...[
                      _premiumSectionTitle('المواصفات', Icons.tune_rounded),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFFEDEEF1)),
                        ),
                        child: Center(
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: colors.primary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ] else if (_marketplaceAttributes.isNotEmpty) ...[
                      _premiumSectionTitle('المواصفات', Icons.tune_rounded),
                      const SizedBox(height: 10),
                      _attributesCard(colors),
                      const SizedBox(height: 24),
                    ],

                    // ─── مكان الاستلام
                    _premiumSectionTitle(
                        'مكان الاستلام', Icons.location_on_rounded),
                    const SizedBox(height: 10),
                    _locationCard(colors),
                    const SizedBox(height: 24),

                    // ─── صاحب العرض
                    _premiumSectionTitle(
                        'صاحب العرض', Icons.person_outline_rounded),
                    const SizedBox(height: 10),
                    _ownerCard(colors),
                    const SizedBox(height: 22),

                    // ─── نصائح الأمان
                    _safetyTips(colors),
                    const SizedBox(height: 26),

                    // ─── التقييمات
                    Row(
                      children: [
                        _premiumSectionTitle('التقييمات', Icons.star_rounded),
                      ],
                    ),
                    const SizedBox(height: 12),

                    if (!_isOwner)
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _addReview,
                          icon: const Icon(Icons.star_outline_rounded),
                          label: const Text('أضف تقييمك'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: colors.primary,
                            side: BorderSide(
                                color: colors.primary.withValues(alpha: .4)),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      )
                    else
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F2F4),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          'لا يمكنك تقييم عرضك الخاص.',
                          style: TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                      ),
                    const SizedBox(height: 14),

                    // ─── قائمة التقييمات
                    FutureBuilder<List<Map<String, dynamic>>>(
                      future: _loadReviews(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(20),
                              child: CircularProgressIndicator(),
                            ),
                          );
                        }
                        if (snapshot.hasError) {
                          return const Center(
                            child: Text('تعذر جلب التقييمات'),
                          );
                        }
                        final reviews = snapshot.data ?? [];
                        if (reviews.isEmpty) {
                          return Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border:
                                  Border.all(color: const Color(0xFFEDEEF1)),
                            ),
                            alignment: Alignment.center,
                            child: const Column(
                              children: [
                                Icon(Icons.star_border_rounded,
                                    color: Colors.grey, size: 30),
                                SizedBox(height: 8),
                                Text(
                                  'لا توجد تقييمات بعد، كن أول من يقيّم!',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                          );
                        }

                        return Column(
                          children: reviews.map((review) {
                            final user = review['users'] is Map
                                ? Map<String, dynamic>.from(
                                    review['users'] as Map)
                                : <String, dynamic>{};
                            final reviewerName =
                                user['name']?.toString() ?? 'مستخدم';
                            final avatarUrl = user['avatar_url']?.toString();
                            final rating =
                                (review['rating'] as num?)?.toInt() ?? 0;
                            final comment = review['comment']?.toString() ?? '';
                            final createdAt = DateTime.tryParse(
                                review['created_at']?.toString() ?? '');

                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(13),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border:
                                    Border.all(color: const Color(0xFFEDEEF1)),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor:
                                        colors.primary.withAlpha(20),
                                    child:
                                        avatarUrl == null || avatarUrl.isEmpty
                                            ? Icon(Icons.person,
                                                color: colors.primary, size: 20)
                                            : ClipOval(
                                                child: Image.network(
                                                  avatarUrl,
                                                  width: 36,
                                                  height: 36,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (_, __, ___) =>
                                                      Icon(Icons.person,
                                                          color: colors.primary,
                                                          size: 20),
                                                ),
                                              ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                reviewerName,
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                            ),
                                            if (createdAt != null)
                                              Text(
                                                DateFormat('dd/MM/yyyy')
                                                    .format(createdAt),
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: List.generate(5, (index) {
                                            return Icon(
                                              Icons.star_rounded,
                                              size: 15,
                                              color: index < rating
                                                  ? Colors.amber
                                                  : Colors.grey.shade300,
                                            );
                                          }),
                                        ),
                                        if (comment.isNotEmpty) ...[
                                          const SizedBox(height: 6),
                                          Text(
                                            comment,
                                            style: TextStyle(
                                              fontSize: 12.5,
                                              height: 1.5,
                                              color: colors.onSurfaceVariant,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        // ─── Bottom Bar
        bottomNavigationBar: SafeArea(
          top: false,
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: const Color(0xFF15171A),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: .16),
                  blurRadius: 22,
                  offset: const Offset(0, 9),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _fetchingContacts ? null : _openWhatsApp,
                    icon: _fetchingContacts
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.chat_rounded, size: 19),
                    label: const Text('واتساب'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                          const Color(0xFF25D366).withValues(alpha: 0.5),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _fetchingContacts ? null : _openPhone,
                    icon: const Icon(Icons.phone_rounded, size: 19),
                    label: const Text('اتصال'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                          colors.primary.withValues(alpha: 0.5),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // ✅ Helpers — تحسينات الشكل
  // ═══════════════════════════════════════════════════════════
  Widget _roundAppBarButton(IconData icon, VoidCallback onPressed) {
    return Container(
      margin: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: .48),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.white, size: 21),
      ),
    );
  }

  Widget _premiumSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFE9E5), Color(0xFFFFF5F2)],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, color: const Color(0xFFE95D4E), size: 18),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF15171A),
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  // ✅ كارت المواصفات
  // ═══════════════════════════════════════════════════════════
  Widget _attributesCard(ColorScheme colors) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFEDEEF1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: List.generate(_marketplaceAttributes.length, (i) {
          final attr = _marketplaceAttributes[i];
          final isLast = i == _marketplaceAttributes.length - 1;
          return _attributeRow(attr, colors, isLast: isLast);
        }),
      ),
    );
  }

  Widget _attributeRow(
    Map<String, dynamic> attr,
    ColorScheme colors, {
    required bool isLast,
  }) {
    final slug = attr['slug']?.toString() ?? '';
    final nameAr = attr['name_ar']?.toString() ?? '';
    final value = attr['value']?.toString() ?? '';
    final iconData = _iconForAttribute(slug, attr['icon']?.toString());

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(
                bottom: BorderSide(color: Color(0xFFF2F3F5)),
              ),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(iconData, size: 17, color: colors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              nameAr,
              style: const TextStyle(
                color: Color(0xFF626B75),
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.left,
              style: const TextStyle(
                color: Color(0xFF15171A),
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ اختيار أيقونة مناسبة حسب الـ slug (مع fallback للـ icon القادم من الداتا)
  IconData _iconForAttribute(String slug, String? backendIcon) {
    switch (slug) {
      case 'brand':
        return Icons.local_offer_rounded;
      case 'condition':
        return Icons.verified_rounded;
      case 'color':
        return Icons.palette_rounded;
      case 'size':
        return Icons.straighten_rounded;
      case 'year':
        return Icons.calendar_today_rounded;
      case 'mileage':
        return Icons.speed_rounded;
      case 'model':
        return Icons.directions_car_rounded;
      case 'transmission':
        return Icons.settings_rounded;
      case 'fuel_type':
        return Icons.local_gas_station_rounded;
      case 'area':
        return Icons.square_foot_rounded;
      case 'rooms':
        return Icons.meeting_room_rounded;
      case 'bathrooms':
        return Icons.bathtub_rounded;
      case 'floor':
        return Icons.stairs_rounded;
      case 'furnished':
        return Icons.chair_rounded;
      case 'weight':
        return Icons.scale_rounded;
      case 'material':
        return Icons.category_rounded;
      case 'pieces':
        return Icons.widgets_rounded;
      case 'connectivity':
        return Icons.bluetooth_rounded;
      case 'storage':
        return Icons.sd_storage_rounded;
      case 'ram':
        return Icons.memory_rounded;
      case 'screen_size':
        return Icons.phone_android_rounded;
      case 'battery':
        return Icons.battery_full_rounded;
      case 'item_type':
        return Icons.inventory_2_rounded;
      case 'quantity':
        return Icons.numbers_rounded;
    }

    // fallback: جرّب نستخدم الأيقونة اللي جاية من الداتا
    if (backendIcon != null && backendIcon.isNotEmpty) {
      final icon = _materialIconFromName(backendIcon);
      if (icon != null) return icon;
    }

    return Icons.label_important_rounded;
  }

  IconData? _materialIconFromName(String name) {
    // خريطة مبسطة لأشهر الأيقونات
    const map = <String, IconData>{
      'local_offer': Icons.local_offer_rounded,
      'verified': Icons.verified_rounded,
      'palette': Icons.palette_rounded,
      'straighten': Icons.straighten_rounded,
      'speed': Icons.speed_rounded,
      'directions_car': Icons.directions_car_rounded,
      'settings': Icons.settings_rounded,
      'local_gas_station': Icons.local_gas_station_rounded,
      'square_foot': Icons.square_foot_rounded,
      'meeting_room': Icons.meeting_room_rounded,
      'bathtub': Icons.bathtub_rounded,
      'chair': Icons.chair_rounded,
      'scale': Icons.scale_rounded,
      'bluetooth': Icons.bluetooth_rounded,
      'sd_storage': Icons.sd_storage_rounded,
      'memory': Icons.memory_rounded,
      'phone_android': Icons.phone_android_rounded,
      'battery_full': Icons.battery_full_rounded,
      'inventory_2': Icons.inventory_2_rounded,
      'category': Icons.category_rounded,
      'calendar_today': Icons.calendar_today_rounded,
      'numbers': Icons.numbers_rounded,
    };
    return map[name];
  }

  Widget _ownerCard(ColorScheme colors) {
    final avatar = _ownerAvatar;

    return InkWell(
      onTap: _openOwnerProfile,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Colors.white, Color(0xFFFBFBFC)],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFEDEEF1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .04),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    colors.primary.withValues(alpha: .4),
                    colors.primary.withValues(alpha: .1),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: CircleAvatar(
                radius: 28,
                backgroundColor: Colors.white,
                child: avatar == null || avatar.isEmpty
                    ? Icon(Icons.person, color: colors.primary, size: 32)
                    : ClipOval(
                        child: Image.network(
                          avatar,
                          width: 52,
                          height: 52,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Icon(Icons.person,
                              color: colors.primary, size: 32),
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _ownerName.isEmpty ? 'مستخدم وِصلة' : _ownerName,
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w900,
                      color: colors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.calendar_month_rounded,
                          size: 12, color: colors.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text(
                        _memberSince(),
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.green.withAlpha(20),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                children: [
                  Icon(Icons.verified_rounded, size: 14, color: Colors.green),
                  SizedBox(width: 4),
                  Text(
                    'موثوق',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_left_rounded, color: Color(0xFF9AA1A8)),
          ],
        ),
      ),
    );
  }

  Widget _safetyTips(ColorScheme colors) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF9EC), Color(0xFFFFF4DC)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFFE0B2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFFE28B00).withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.shield_rounded,
                    color: Color(0xFFE28B00), size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                'نصيحة أمان',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: colors.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            '• يُفضل مقابلة صاحب العرض في مكان عام ومزدحم (مثل المحلات أو الكافيهات) فيها كاميرات مراقبة.\n'
            '• لا تدفع أي مبلغ قبل معاينة المنتج والتأكد من حالته.\n'
            '• لا تشارك أي بيانات حساسة (مثل كلمات المرور أو بيانات البنك) مع أي شخص عبر الواتساب أو الهاتف.\n'
            '• إذا شعرت بأي شيء غير مريح، لا تتردد في إلغاء الطلب وعدم المتابعة.',
            style: TextStyle(
              fontSize: 12,
              height: 1.65,
              color: Color(0xFF71624B),
            ),
          ),
        ],
      ),
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
        _infoTile(Icons.inventory_2_rounded, 'الكمية',
            '${offer['quantity'] ?? 0}', colors.primary),
        _infoTile(
            Icons.timer_outlined, 'متبقي', _timeRemaining(), Colors.deepOrange),
        _infoTile(Icons.schedule_rounded, 'الاستلام قبل',
            offer['pickup_before']?.toString() ?? 'غير محدد', Colors.blue),
        _infoTile(
            Icons.verified_rounded,
            'الحالة',
            offer['status']?.toString() == 'available' ||
                    offer['status']?.toString() == 'active'
                ? 'متاح'
                : 'غير متاح',
            Colors.green),
      ],
    );
  }

  Widget _infoTile(IconData icon, String label, String value, Color color) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withAlpha(45)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: .05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: color.withAlpha(20),
                borderRadius: BorderRadius.circular(11)),
            child: Icon(icon, color: color, size: 19),
          ),
          const SizedBox(width: 9),
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
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800))
              ])),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // ✅ كارت الموقع
  // ═══════════════════════════════════════════════════════════
  Widget _locationCard(ColorScheme colors) {
    final location = offer['pickup_location']?.toString().trim() ?? '';
    final hasLocation = location.isNotEmpty;

    return InkWell(
      onTap: hasLocation ? _openLocation : null,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: hasLocation
                ? [
                    colors.primary.withValues(alpha: .08),
                    colors.primary.withValues(alpha: .02),
                  ]
                : [Colors.grey.shade100, Colors.grey.shade50],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: hasLocation
                ? colors.primary.withValues(alpha: .35)
                : Colors.grey.shade300,
            width: hasLocation ? 1.4 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: hasLocation
                    ? colors.primary.withValues(alpha: .15)
                    : Colors.grey.withValues(alpha: .15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.location_on_rounded,
                color: hasLocation ? colors.primary : Colors.grey,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'مكان الاستلام',
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    hasLocation ? location : 'غير محدد',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.onSurface,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      height: 1.3,
                    ),
                  ),
                  if (hasLocation) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.touch_app_rounded,
                          size: 12,
                          color: colors.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'اضغط لفتح الخريطة',
                          style: TextStyle(
                            color: colors.primary,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (hasLocation)
              Icon(
                Icons.open_in_new_rounded,
                size: 20,
                color: colors.primary,
              ),
          ],
        ),
      ),
    );
  }
}

// =====================================================================
// معرض الصور
// =====================================================================
class _HeroGallery extends StatefulWidget {
  final List<String> images;

  const _HeroGallery({required this.images});

  @override
  State<_HeroGallery> createState() => _HeroGalleryState();
}

class _HeroGalleryState extends State<_HeroGallery> {
  int _currentIndex = 0;

  void _openFullGallery(int startIndex) {
    if (widget.images.isEmpty) return;
    Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black,
        transitionDuration: const Duration(milliseconds: 260),
        pageBuilder: (_, animation, __) => FadeTransition(
          opacity: animation,
          child: _FullScreenGallery(
            images: widget.images,
            initialIndex: startIndex,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.images.isEmpty) return _placeholder();

    return Stack(
      fit: StackFit.expand,
      children: [
        CarouselSlider.builder(
          itemCount: widget.images.length,
          itemBuilder: (_, index, __) => GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _openFullGallery(index),
            child: Hero(
              tag: 'offer_image_$index',
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    widget.images[index],
                    fit: BoxFit.cover,
                    width: double.infinity,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return Container(
                        color: const Color(0xFF202326),
                        alignment: Alignment.center,
                        child: const CircularProgressIndicator(
                          color: Colors.white54,
                        ),
                      );
                    },
                    errorBuilder: (_, __, ___) => _placeholder(),
                  ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Color(0x66000000),
                          ]),
                    ),
                  ),
                  const Positioned(
                      bottom: 18, right: 18, child: _GalleryHint()),
                ],
              ),
            ),
          ),
          options: CarouselOptions(
            viewportFraction: 1,
            height: double.infinity,
            autoPlay: widget.images.length > 1,
            autoPlayInterval: const Duration(seconds: 4),
            autoPlayAnimationDuration: const Duration(milliseconds: 650),
            enlargeCenterPage: false,
            onPageChanged: (index, _) => setState(() => _currentIndex = index),
          ),
        ),
        if (widget.images.length > 1)
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                  widget.images.length,
                  (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        width: index == _currentIndex ? 22 : 7,
                        height: 7,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                            color: index == _currentIndex
                                ? Colors.white
                                : Colors.white54,
                            borderRadius: BorderRadius.circular(10)),
                      )),
            ),
          ),
        if (widget.images.length > 1)
          Positioned(
            top: 18,
            right: 18,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: .48),
                  borderRadius: BorderRadius.circular(30)),
              child: Text(
                '${_currentIndex + 1}/${widget.images.length}',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800),
              ),
            ),
          ),
      ],
    );
  }

  Widget _placeholder() => Container(
        color: const Color(0xFF202326),
        alignment: Alignment.center,
        child: const Icon(Icons.image_not_supported_outlined,
            size: 72, color: Colors.white38),
      );
}

class _GalleryHint extends StatelessWidget {
  const _GalleryHint();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: .48),
          borderRadius: BorderRadius.circular(30)),
      child: const Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.zoom_in_rounded, color: Colors.white, size: 16),
        SizedBox(width: 4),
        Text(
          'اضغط لعرض كل الصور',
          style: TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
      ]),
    );
  }
}

class _FullScreenGallery extends StatefulWidget {
  final List<String> images;
  final int initialIndex;

  const _FullScreenGallery({
    required this.images,
    required this.initialIndex,
  });

  @override
  State<_FullScreenGallery> createState() => _FullScreenGalleryState();
}

class _FullScreenGalleryState extends State<_FullScreenGallery> {
  late final PageController _pageController;
  late int _currentIndex;
  final Map<int, TransformationController> _zoomControllers = {};

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  TransformationController _zoomFor(int index) {
    return _zoomControllers.putIfAbsent(
        index, () => TransformationController());
  }

  void _resetZoom(int index) {
    _zoomControllers[index]?.value = Matrix4.identity();
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (final c in _zoomControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _goTo(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded,
                        color: Colors.white, size: 26),
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(30)),
                    child: Text(
                      '${_currentIndex + 1} من ${widget.images.length}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w800),
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(width: 44),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: widget.images.length,
                onPageChanged: (index) {
                  setState(() => _currentIndex = index);
                },
                itemBuilder: (context, index) {
                  return InteractiveViewer(
                    transformationController: _zoomFor(index),
                    minScale: 1,
                    maxScale: 4.5,
                    onInteractionEnd: (_) {},
                    child: Center(
                      child: Hero(
                        tag: 'offer_image_$index',
                        child: Image.network(
                          widget.images[index],
                          fit: BoxFit.contain,
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) return child;
                            return const Center(
                              child: CircularProgressIndicator(
                                  color: Colors.white54),
                            );
                          },
                          errorBuilder: (_, __, ___) => const Center(
                              child: Icon(Icons.broken_image_outlined,
                                  color: Colors.white38, size: 60)),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            if (widget.images.length > 1)
              SizedBox(
                height: 78,
                child: ListView.separated(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  scrollDirection: Axis.horizontal,
                  itemCount: widget.images.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final selected = index == _currentIndex;
                    return GestureDetector(
                      onTap: () {
                        _resetZoom(_currentIndex);
                        _goTo(index);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 58,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selected ? Colors.white : Colors.white24,
                            width: selected ? 2.4 : 1,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Opacity(
                            opacity: selected ? 1 : 0.55,
                            child: Image.network(
                              widget.images[index],
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                  color: const Color(0xFF2A2D30),
                                  child: const Icon(Icons.image_not_supported,
                                      color: Colors.white38, size: 18)),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
