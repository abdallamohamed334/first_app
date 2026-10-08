// lib/features/community/presentation/pages/user_profile_page.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:loqma/features/community/data/repositories/community_offer_repository.dart';
import 'package:loqma/features/community/presentation/pages/community_offer_details_page.dart';
import 'package:url_launcher/url_launcher.dart'; // ✅ أضف الاستيراد

class UserProfilePage extends StatefulWidget {
  final String userId;
  final String userName;
  final String? userAvatar;

  const UserProfilePage({
    super.key,
    required this.userId,
    required this.userName,
    this.userAvatar,
  });

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  final CommunityOfferRepository _repository = CommunityOfferRepository();
  bool _loading = true;
  Map<String, dynamic>? _user;
  List<Map<String, dynamic>> _offers = [];
  List<Map<String, dynamic>> _reviews = [];
  double _averageRating = 0;
  String? _currentUserId;
  bool _canReview = false;
  bool _hasReviewed = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      _currentUserId = _repository.getCurrentUserId();

      final user = await _repository.getUserProfile(widget.userId);
      final offers = await _repository.getUserOffers(widget.userId);
      final reviews = await _repository.getUserReviews(widget.userId);
      final avgRating = await _repository.getUserAverageRating(widget.userId);

      for (var i = 0; i < offers.length; i++) {
        final offerId = offers[i]['id'].toString();
        try {
          final image = await _repository.getOfferImage(offerId);
          offers[i]['image'] = image;
          offers[i]['images'] = image != null ? [image] : [];
        } catch (e) {
          offers[i]['images'] = [];
          offers[i]['image'] = null;
        }
      }

      final alreadyReviewed = reviews.any((review) {
        final reviewerId = review['reviewer_id']?.toString() ?? '';
        return reviewerId == _currentUserId;
      });

      if (!mounted) return;
      setState(() {
        _user = user;
        _offers = offers;
        _reviews = reviews;
        _averageRating = avgRating;
        _canReview = _currentUserId != widget.userId && !alreadyReviewed;
        _hasReviewed = alreadyReviewed;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Error loading user profile: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  // ✅ تشغيل زر الاتصال
  Future<void> _callUser() async {
    final phone = _user?['phone']?.toString() ?? '';
    if (phone.isEmpty) {
      _snack('لا يوجد رقم هاتف متاح', Colors.orange);
      return;
    }

    // تنظيف الرقم من أي رموز
    final cleanedPhone = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (cleanedPhone.isEmpty) {
      _snack('رقم الهاتف غير صالح', Colors.orange);
      return;
    }

    final uri = Uri.parse('tel:$cleanedPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      _snack('تعذر إجراء الاتصال', Colors.red);
    }
  }

  // ✅ إضافة تقييم للمستخدم - مع معالجة كل الأخطاء
  Future<void> _addReview() async {
    final colors = Theme.of(context).colorScheme;
    if (!_canReview || _hasReviewed) {
      _snack('لقد قمت بتقييم هذا المستخدم من قبل', colors.onSurfaceVariant);
      return;
    }

    int selectedRating = 5;
    String comment = '';

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('قيّم المستخدم'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('شارك تجربتك مع هذا المستخدم'),
              const SizedBox(height: 15),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return IconButton(
                    onPressed: () => setState(() => selectedRating = index + 1),
                    icon: Icon(
                      Icons.star,
                      color:
                          index < selectedRating ? Colors.amber : Colors.grey,
                      size: 32,
                    ),
                  );
                }),
              ),
              const SizedBox(height: 10),
              TextField(
                onChanged: (value) => comment = value,
                decoration: InputDecoration(
                  hintText: 'اكتب تعليقك (اختياري)',
                  border: OutlineInputBorder(
                    borderSide: BorderSide(color: colors.outlineVariant),
                  ),
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
              onPressed: () async {
                try {
                  await _repository.addUserReview(
                    ownerId: widget.userId,
                    rating: selectedRating,
                    comment: comment.isEmpty ? null : comment,
                  );
                  Navigator.pop(dialogContext);
                  _snack('تم إضافة التقييم بنجاح', colors.primary);
                  _loadData();
                } catch (e) {
                  debugPrint('Error adding review: $e');
                  Navigator.pop(dialogContext);
                  _snack('لقد قمت بتقييم هذا المستخدم من قبل',
                      colors.onSurfaceVariant);
                }
              },
              child: const Text('إرسال'),
            ),
          ],
        );
      },
    );
  }

  void _snack(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1F1F1F) : Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'الملف الشخصي',
          style: TextStyle(
            color: colors.onSurface,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.arrow_back_rounded, color: colors.onSurface),
        ),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: colors.primary))
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final userName = _user?['name']?.toString() ?? widget.userName;
    final avatar = _user?['avatar_url']?.toString() ?? widget.userAvatar;
    final phone = _user?['phone']?.toString() ?? '';
    final memberSince = _user?['created_at']?.toString() ?? '';
    final offerCount = _offers.length;
    final reviewCount = _reviews.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ✅ كارت المستخدم الرئيسي
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1F1F1F) : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: colors.outlineVariant),
            ),
            child: Column(
              children: [
                // الصورة الشخصية
                CircleAvatar(
                  radius: 50,
                  backgroundColor: colors.primary.withValues(alpha: 0.1),
                  child: avatar == null || avatar.isEmpty
                      ? Icon(Icons.person, color: colors.primary, size: 50)
                      : ClipOval(
                          child: Image.network(
                            avatar,
                            width: 100,
                            height: 100,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Icon(
                              Icons.person,
                              color: colors.primary,
                              size: 50,
                            ),
                          ),
                        ),
                ),
                const SizedBox(height: 12),
                // الاسم
                Text(
                  userName,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: colors.onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                // تاريخ الانضمام
                Text(
                  _formatDate(memberSince),
                  style: TextStyle(
                    fontSize: 13,
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),

                // ✅ إحصائيات سريعة
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildStat('$offerCount', 'عروض'),
                    const SizedBox(width: 24),
                    _buildStat(_averageRating.toStringAsFixed(1), 'تقييم'),
                    const SizedBox(width: 24),
                    _buildStat('$reviewCount', 'تقييمات'),
                  ],
                ),

                const SizedBox(height: 16),

                // ✅ زر التواصل (لو الرقم موجود)
                if (phone.isNotEmpty)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _callUser, // ✅ تم التفعيل
                      icon: Icon(Icons.phone, color: colors.primary),
                      label: const Text('اتصال'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colors.primary,
                        side: BorderSide(color: colors.primary),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),

                // ✅ زر إضافة تقييم (لو مش صاحب البروفايل ولو مقيّمش قبل كده)
                if (_canReview && !_hasReviewed) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _addReview,
                      icon: const Icon(Icons.star_outline_rounded),
                      label: const Text('أضف تقييمك'),
                      style: FilledButton.styleFrom(
                        backgroundColor: colors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ] else
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text(
                      _hasReviewed
                          ? 'لقد قمت بتقييم هذا المستخدم من قبل'
                          : 'لا يمكنك تقييم نفسك.',
                      style: TextStyle(
                          color: colors.onSurfaceVariant, fontSize: 13),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ✅ قسم العروض
          Text(
            'عروض المستخدم',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: 12),

          if (_offers.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: Text(
                  'لا توجد عروض حالياً',
                  style: TextStyle(color: colors.onSurfaceVariant),
                ),
              ),
            )
          else
            ..._offers.map((offer) => _buildOfferCard(offer)),

          const SizedBox(height: 24),

          // ✅ قسم التقييمات
          Text(
            'التقييمات',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: 12),

          if (_reviews.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: Text(
                  'لا توجد تقييمات بعد',
                  style: TextStyle(color: colors.onSurfaceVariant),
                ),
              ),
            )
          else
            ..._reviews.map((review) => _buildReviewCard(review)),
        ],
      ),
    );
  }

  Widget _buildStat(String value, String label) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: colors.primary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildOfferCard(Map<String, dynamic> offer) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final image = offer['image']?.toString() ?? '';
    final title = (offer['title'] ?? 'عرض مجتمعي').toString();
    final description = (offer['description'] ?? '').toString();
    final price = (offer['price'] as num?)?.toDouble() ?? 0;
    final category = (offer['category'] ?? 'أخرى').toString();
    final itemCondition = (offer['item_condition'] ?? 'good').toString();

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CommunityOfferDetailsPage(offer: offer),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1F1F1F) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: colors.outlineVariant),
        ),
        child: Row(
          children: [
            // الصورة
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 80,
                height: 80,
                child: image.isNotEmpty
                    ? Image.network(
                        image,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: colors.primary.withValues(alpha: 0.1),
                          child: Icon(
                            Icons.checkroom_rounded,
                            color: colors.primary,
                            size: 32,
                          ),
                        ),
                      )
                    : Container(
                        color: colors.primary.withValues(alpha: 0.1),
                        child: Icon(
                          Icons.checkroom_rounded,
                          color: colors.primary,
                          size: 32,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            // البيانات
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: colors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (price > 0)
                        Text(
                          '$price جنيه',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: colors.primary,
                          ),
                        ),
                      const SizedBox(width: 12),
                      Text(
                        category,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _getConditionLabel(itemCondition),
                        style: TextStyle(
                          fontSize: 11,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_back_ios_new_rounded,
                size: 16, color: colors.primary),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewCard(Map<String, dynamic> review) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = review['users'] is Map
        ? Map<String, dynamic>.from(review['users'] as Map)
        : <String, dynamic>{};
    final reviewerName = user['name']?.toString() ?? 'مستخدم';
    final avatar = user['avatar_url']?.toString();
    final rating = (review['rating'] as num?)?.toInt() ?? 0;
    final comment = review['comment']?.toString() ?? '';
    final createdAt = DateTime.tryParse(review['created_at']?.toString() ?? '');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F1F1F) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: colors.primary.withValues(alpha: 0.1),
            child: avatar == null || avatar.isEmpty
                ? Icon(Icons.person, color: colors.primary, size: 20)
                : ClipOval(
                    child: Image.network(
                      avatar,
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Icon(
                        Icons.person,
                        color: colors.primary,
                        size: 20,
                      ),
                    ),
                  ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reviewerName,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: colors.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: List.generate(5, (index) {
                    return Icon(
                      Icons.star,
                      size: 14,
                      color: index < rating ? Colors.amber : Colors.grey,
                    );
                  }),
                ),
                const SizedBox(height: 6),
                if (comment.isNotEmpty)
                  Text(
                    comment,
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                if (createdAt != null)
                  Text(
                    DateFormat('dd/MM/yyyy').format(createdAt),
                    style: TextStyle(
                      fontSize: 10,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String date) {
    if (date.isEmpty) return '--';
    try {
      final parsed = DateTime.parse(date);
      final now = DateTime.now();
      final diff = now.difference(parsed);
      if (diff.inDays > 0) return 'منذ ${diff.inDays} يوم';
      if (diff.inHours > 0) return 'منذ ${diff.inHours} ساعة';
      if (diff.inMinutes > 0) return 'منذ ${diff.inMinutes} دقيقة';
      return 'الآن';
    } catch (_) {
      return date.substring(0, 10);
    }
  }

  String _getConditionLabel(String condition) {
    switch (condition) {
      case 'new':
        return 'جديد';
      case 'very_good':
        return 'ممتاز';
      case 'good':
        return 'جيد';
      case 'needs_repair':
        return 'يحتاج إصلاح';
      default:
        return 'غير محدد';
    }
  }
}
