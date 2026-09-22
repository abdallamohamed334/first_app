// lib/features/community/presentation/pages/community_offer_details_page.dart

import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:loqma/features/community/data/repositories/community_offer_repository.dart';
import 'package:loqma/features/community/presentation/pages/user_profile_page.dart'; // ✅ استيراد صفحة البروفايل

class CommunityOfferDetailsPage extends StatefulWidget {
  final Map<String, dynamic> offer;

  const CommunityOfferDetailsPage({super.key, required this.offer});

  @override
  State<CommunityOfferDetailsPage> createState() =>
      _CommunityOfferDetailsPageState();
}

class _CommunityOfferDetailsPageState extends State<CommunityOfferDetailsPage> {
  final CommunityOfferRepository _repository = CommunityOfferRepository();
  Map<String, dynamic> get offer => widget.offer;

  // ✅ بيانات صاحب العرض من الداتابيز
  String get _ownerName => offer['owner_name']?.toString() ?? '';
  String get _ownerPhone => offer['phone']?.toString() ?? '';
  String get _ownerWhatsapp => offer['whatsapp']?.toString() ?? _ownerPhone;
  String? get _ownerAvatar => offer['avatar_url']?.toString();
  String get _ownerId => offer['owner_id']?.toString() ?? '';

  DateTime? get _ownerJoinedDate {
    final raw = offer['joined_at']?.toString() ??
        offer['users']?['created_at']?.toString() ??
        offer['owner_created_at']?.toString();
    return DateTime.tryParse(raw ?? '');
  }

  // ✅ تجميع كل الصور
  List<String> get _images {
    final result = <String>[];
    if (offer['image']?.toString().isNotEmpty == true) {
      result.add(offer['image'].toString());
    }
    if (offer['images'] is List) {
      result.addAll((offer['images'] as List).cast<String>());
    }
    return result.toSet().toList();
  }

  // ✅ الوقت المتبقي
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

  // ✅ حساب مدة الانضمام
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

  // ✅ تحويل الرقم للصيغة الدولية الصحيحة
  String _normalizePhone(String phone) {
    var cleaned = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleaned.startsWith('00')) {
      cleaned = cleaned.substring(2);
    }
    if (cleaned.startsWith('20')) {
      return cleaned;
    }
    if (cleaned.startsWith('0')) {
      return '2${cleaned.substring(1)}';
    }
    return cleaned;
  }

  // ✅ فتح واتساب
  Future<void> _openWhatsApp() async {
    final phone = _normalizePhone(_ownerWhatsapp);
    if (phone.isEmpty) {
      _snack('لا يوجد رقم واتساب متاح', Colors.orange);
      return;
    }
    final url = 'https://wa.me/$phone';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } else {
      try {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      } catch (e) {
        _snack('تعذر فتح واتساب: $e', Colors.red);
      }
    }
  }

  // ✅ فتح الهاتف
  Future<void> _openPhone() async {
    final phone = _normalizePhone(_ownerPhone);
    if (phone.isEmpty) {
      _snack('لا يوجد رقم هاتف متاح', Colors.orange);
      return;
    }
    final url = 'tel:$phone';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } else {
      try {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      } catch (e) {
        _snack('تعذر إجراء الاتصال: $e', Colors.red);
      }
    }
  }

  void _snack(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(message),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
    );
  }

  // ✅ جلب التقييمات
  Future<List<Map<String, dynamic>>> _loadReviews() async {
    final offerId = offer['id']?.toString() ?? '';
    if (offerId.isEmpty) return [];
    return await _repository.getOfferReviews(offerId);
  }

  // ✅ إضافة تقييم
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

  // ✅ معرفة هل المستخدم هو صاحب العرض
  bool _isOwner = false;

  @override
  void initState() {
    super.initState();
    _checkIfOwner();
  }

  Future<void> _checkIfOwner() async {
    final offerId = offer['id']?.toString() ?? '';
    if (offerId.isEmpty) return;

    final isOwner = await _repository.isCurrentUserOwner(offerId);
    if (mounted) {
      setState(() => _isOwner = isOwner);
    }
  }

  // ✅ فتح صفحة البروفايل
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
        useMaterial3: true,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F8FA),
        extendBody: true,
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverAppBar(
              expandedHeight: 390,
              pinned: true,
              elevation: 0,
              scrolledUnderElevation: 0,
              backgroundColor: const Color(0xFFF7F8FA),
              surfaceTintColor: Colors.transparent,
              leading: _roundAppBarButton(
                  Icons.arrow_back_rounded, () => Navigator.pop(context)),
              actions: [
                _roundAppBarButton(Icons.share_rounded,
                    () => _snack('مشاركة العرض قريبًا', colors.primary)),
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
            SliverToBoxAdapter(
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFF7F8FA),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(34)),
                  boxShadow: [
                    BoxShadow(
                        color: Color(0x14000000),
                        blurRadius: 18,
                        offset: Offset(0, -6)),
                  ],
                ),
                transform: Matrix4.translationValues(0, -22, 0),
                padding: const EdgeInsets.fromLTRB(20, 26, 20, 124),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ✅ مقبض بصري صغير أعلى الشيت
                      Center(
                        child: Container(
                          width: 44,
                          height: 5,
                          margin: const EdgeInsets.only(bottom: 18),
                          decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: .08),
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      Row(children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 11, vertical: 7),
                          decoration: BoxDecoration(
                              color: colors.primary.withValues(alpha: .10),
                              borderRadius: BorderRadius.circular(30)),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.groups_rounded,
                                  size: 13, color: colors.primary),
                              const SizedBox(width: 5),
                              Text('عرض مجتمعي',
                                  style: TextStyle(
                                      color: colors.primary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900)),
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
                                    offset: const Offset(0, 4)),
                              ],
                            ),
                            child: Text('${price.toStringAsFixed(0)} جنيه',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900)),
                          ),
                      ]),
                      const SizedBox(height: 14),
                      Text(title,
                          style: const TextStyle(
                              color: Color(0xFF15171A),
                              fontSize: 26,
                              height: 1.2,
                              fontWeight: FontWeight.w900)),
                      const SizedBox(height: 12),
                      InkWell(
                          onTap: _openOwnerProfile,
                          borderRadius: BorderRadius.circular(12),
                          child: Row(children: [
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
                                    : null),
                            const SizedBox(width: 8),
                            Text(
                                _ownerName.isEmpty ? 'مستخدم لقمة' : _ownerName,
                                style: const TextStyle(
                                    color: Color(0xFF626B75),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(width: 5),
                            Icon(Icons.verified_rounded,
                                size: 16, color: colors.primary),
                            const Spacer(),
                            const Icon(Icons.chevron_left_rounded,
                                color: Color(0xFF9AA1A8)),
                          ])),
                      const SizedBox(height: 22),
                      _infoGrid(colors),
                      const SizedBox(height: 26),
                      _premiumSectionTitle('عن العرض', Icons.notes_rounded),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFEDEEF1)),
                        ),
                        child: Text(
                            description.isEmpty
                                ? 'عرض من مستخدم.'
                                : description,
                            style: const TextStyle(
                                color: Color(0xFF626B75),
                                height: 1.75,
                                fontSize: 14)),
                      ),
                      const SizedBox(height: 24),
                      _premiumSectionTitle(
                          'مكان الاستلام', Icons.location_on_rounded),
                      const SizedBox(height: 10),
                      _locationCard(colors),
                      const SizedBox(height: 24),
                      _premiumSectionTitle(
                          'صاحب العرض', Icons.person_outline_rounded),
                      const SizedBox(height: 10),
                      _ownerCard(colors),
                      const SizedBox(height: 22),
                      _safetyTips(colors),
                      const SizedBox(height: 26),
                      // ✅ قسم التقييمات
                      Row(
                        children: [
                          _premiumSectionTitle('التقييمات', Icons.star_rounded),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // زر إضافة تقييم (مخفي لو صاحب العرض)
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

                      // عرض التقييمات
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
                              child: Column(
                                children: const [
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
                              final comment =
                                  review['comment']?.toString() ?? '';
                              final createdAt = DateTime.tryParse(
                                  review['created_at']?.toString() ?? '');

                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(13),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                      color: const Color(0xFFEDEEF1)),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    CircleAvatar(
                                      radius: 18,
                                      backgroundColor:
                                          colors.primary.withAlpha(20),
                                      child: avatarUrl == null ||
                                              avatarUrl.isEmpty
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
                                                      fontWeight:
                                                          FontWeight.w800),
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
                    ]),
              ),
            ),
          ],
        ),
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
                    offset: const Offset(0, 9))
              ],
            ),
            child: Row(children: [
              Expanded(
                  child: ElevatedButton.icon(
                      onPressed: _openWhatsApp,
                      icon: const Icon(Icons.chat_rounded, size: 19),
                      label: const Text('واتساب'),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF25D366),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15))))),
              const SizedBox(width: 8),
              Expanded(
                  child: ElevatedButton.icon(
                      onPressed: _openPhone,
                      icon: const Icon(Icons.phone_rounded, size: 19),
                      label: const Text('اتصال'),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: colors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15))))),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _roundAppBarButton(IconData icon, VoidCallback onPressed) {
    return Container(
      margin: const EdgeInsets.all(9),
      decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: .48), shape: BoxShape.circle),
      child: IconButton(
          onPressed: onPressed,
          icon: Icon(icon, color: Colors.white, size: 21)),
    );
  }

  Widget _premiumSectionTitle(String title, IconData icon) {
    return Row(children: [
      Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
              color: const Color(0xFFFFE9E5),
              borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: const Color(0xFFE95D4E), size: 17)),
      const SizedBox(width: 9),
      Text(title,
          style: const TextStyle(
              color: Color(0xFF15171A),
              fontSize: 18,
              fontWeight: FontWeight.w900)),
    ]);
  }

  // ✅ كارت صاحب العرض (قابل للضغط لفتح البروفايل)
  Widget _ownerCard(ColorScheme colors) {
    final avatar = _ownerAvatar;

    return InkWell(
      onTap: _openOwnerProfile,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFEDEEF1)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: .03),
                blurRadius: 12,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            // ✅ صورة المستخدم
            CircleAvatar(
              radius: 28,
              backgroundColor: colors.primary.withAlpha(20),
              child: avatar == null || avatar.isEmpty
                  ? Icon(Icons.person, color: colors.primary, size: 32)
                  : ClipOval(
                      child: Image.network(
                        avatar,
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            Icon(Icons.person, color: colors.primary, size: 32),
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            // ✅ الاسم + مدة الانضمام
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _ownerName.isEmpty ? 'مستخدم لقمة' : _ownerName,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: colors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 5),
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
            // ✅ شارة موثوق
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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

  // ✅ قسم الأمان
  Widget _safetyTips(ColorScheme colors) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF6E5),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFFE0B2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.shield_rounded,
                  color: Color(0xFFE28B00), size: 22),
              const SizedBox(width: 8),
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
          const SizedBox(height: 10),
          const Text(
            '• يُفضل مقابلة صاحب العرض في مكان عام ومزدحم (مثل المحلات أو الكافيهات) فيها كاميرات مراقبة.\n'
            '• لا تدفع أي مبلغ قبل معاينة المنتج والتأكد من حالته.\n'
            '• لا تشارك أي بيانات حساسة (مثل كلمات المرور أو بيانات البنك) مع أي شخص عبر الواتساب أو الهاتف.\n'
            '• إذا شعرت بأي شيء غير مريح، لا تتردد في إلغاء الطلب وعدم المتابعة.',
            style: TextStyle(
              fontSize: 12,
              height: 1.6,
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
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withAlpha(45))),
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

  Widget _locationCard(ColorScheme colors) {
    final location = offer['pickup_location']?.toString() ?? 'غير محدد';
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
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: colors.primary.withAlpha(30), shape: BoxShape.circle),
            child: Icon(Icons.location_on_rounded, color: colors.primary),
          ),
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

  Future<void> _openLocation() async {
    final latitude = double.tryParse(offer['latitude']?.toString() ?? '');
    final longitude = double.tryParse(offer['longitude']?.toString() ?? '');
    final query = latitude != null && longitude != null
        ? '$latitude,$longitude'
        : offer['pickup_location']?.toString() ?? '';
    if (query.isEmpty) return;
    final uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(query)}');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

// =====================================================================
// ✅ معرض الصور المصغّر داخل الهيدر
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
                  Image.network(widget.images[index],
                      fit: BoxFit.cover,
                      width: double.infinity,
                      errorBuilder: (_, __, ___) => _placeholder()),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Color(0x66000000)]),
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
              child: Text('${_currentIndex + 1}/${widget.images.length}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800)),
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
        Text('اضغط لعرض كل الصور',
            style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w800)),
      ]),
    );
  }
}

// =====================================================================
// ✅ معرض الصور الكامل (Full screen) — سحب بين الصور + تكبير + شريط
// مصغرات سفلي للتنقل السريع
// =====================================================================
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
            // ✅ شريط علوي: زر إغلاق + عداد الصور
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
                  const SizedBox(width: 44), // موازنة بصرية مع زر الإغلاق
                ],
              ),
            ),
            // ✅ عارض الصور القابل للسحب والتكبير
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
                    onInteractionEnd: (_) {
                      // إبقاء التحكم بسيط دون حالة إضافية
                    },
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
            // ✅ شريط المصغرات السفلي للتنقل السريع بين كل الصور
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
