import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:loqma/features/community/data/repositories/community_offer_repository.dart';

class CustomerReviewsPage extends StatefulWidget {
  const CustomerReviewsPage({
    super.key,
    required this.userId,
    required this.userName,
  });

  final String userId;
  final String userName;

  @override
  State<CustomerReviewsPage> createState() => _CustomerReviewsPageState();
}

class _CustomerReviewsPageState extends State<CustomerReviewsPage> {
  final CommunityOfferRepository _repository = CommunityOfferRepository();
  late Future<_CustomerReviewsData> _reviewsFuture;

  @override
  void initState() {
    super.initState();
    _reviewsFuture = _loadReviews();
  }

  Future<_CustomerReviewsData> _loadReviews() async {
    final results = await Future.wait<Object?>([
      _repository.getUserReviews(widget.userId),
      _repository.getUserAverageRating(widget.userId),
    ]);
    return _CustomerReviewsData(
      reviews: List<Map<String, dynamic>>.from(results[0] as List),
      averageRating: (results[1] as num).toDouble(),
    );
  }

  Future<void> _refresh() async {
    final future = _loadReviews();
    setState(() => _reviewsFuture = future);
    await future;
  }

  Map<String, dynamic> _relationMap(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    if (value is List && value.isNotEmpty && value.first is Map) {
      return Map<String, dynamic>.from(value.first as Map);
    }
    return const {};
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: colors.surface,
        appBar: AppBar(
          title: const Text(
            'تقييمات العملاء',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          centerTitle: true,
          backgroundColor: colors.surface,
          foregroundColor: colors.onSurface,
          elevation: 0,
          scrolledUnderElevation: 0,
          actions: [
            IconButton(
              tooltip: 'تحديث التقييمات',
              onPressed: _refresh,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        body: FutureBuilder<_CustomerReviewsData>(
          future: _reviewsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: CircularProgressIndicator(color: colors.primary),
              );
            }
            if (snapshot.hasError) {
              return _errorState(colors);
            }

            final data =
                snapshot.data ??
                const _CustomerReviewsData(reviews: [], averageRating: 0);
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
              children: [
                _summaryCard(data, colors),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Icon(Icons.rate_review_rounded, color: colors.primary),
                    const SizedBox(width: 8),
                    Text(
                      'آراء الزوار',
                      style: TextStyle(
                        color: colors.onSurface,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${data.reviews.length}',
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (data.reviews.isEmpty)
                  _emptyState(colors)
                else
                  ...data.reviews.map((review) => _reviewCard(review, colors)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _summaryCard(_CustomerReviewsData data, ColorScheme colors) {
    final isDark = colors.brightness == Brightness.dark;
    final accent = isDark ? const Color(0xFF48C98A) : colors.primary;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: isDark ? 0.18 : 0.1),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(Icons.star_rounded, color: accent, size: 32),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'متوسط تقييمات عروض ${widget.userName}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.onSurface,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Text(
                      data.averageRating.toStringAsFixed(1),
                      style: TextStyle(
                        color: accent,
                        fontWeight: FontWeight.w900,
                        fontSize: 26,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Icon(Icons.star_rounded, color: Colors.amber.shade700),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        '${data.reviews.length} تقييم',
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _reviewCard(Map<String, dynamic> review, ColorScheme colors) {
    final reviewer = _relationMap(review['users']);
    final offer = _relationMap(review['community_offers']);
    final reviewerName = reviewer['name']?.toString() ?? 'مستخدم';
    final avatarUrl = reviewer['avatar_url']?.toString();
    final offerTitle = offer['title']?.toString() ?? 'عرض مجتمعي';
    final ratingValue = review['rating'];
    final rating = ratingValue is num
        ? ratingValue.toInt()
        : int.tryParse(ratingValue?.toString() ?? '') ?? 0;
    final comment = review['comment']?.toString().trim() ?? '';
    final createdAt = DateTime.tryParse(review['created_at']?.toString() ?? '');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 21,
            backgroundColor: colors.primaryContainer,
            backgroundImage: avatarUrl == null || avatarUrl.isEmpty
                ? null
                : NetworkImage(avatarUrl),
            child: avatarUrl == null || avatarUrl.isEmpty
                ? Icon(Icons.person_rounded, color: colors.onPrimaryContainer)
                : null,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        reviewerName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.onSurface,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    if (createdAt != null)
                      Text(
                        intl.DateFormat('dd/MM/yyyy').format(createdAt),
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
                          fontSize: 10,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: List.generate(
                    5,
                    (index) => Icon(
                      Icons.star_rounded,
                      size: 17,
                      color: index < rating
                          ? Colors.amber.shade700
                          : colors.outlineVariant,
                    ),
                  ),
                ),
                const SizedBox(height: 9),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.storefront_outlined,
                        color: colors.primary,
                        size: 15,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          offerTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.onSurface,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (comment.isNotEmpty) ...[
                  const SizedBox(height: 9),
                  Text(
                    comment,
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      height: 1.45,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(ColorScheme colors) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: colors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: colors.outlineVariant),
    ),
    child: Column(
      children: [
        Icon(Icons.star_outline_rounded, color: colors.primary, size: 42),
        const SizedBox(height: 10),
        Text(
          'لا توجد تقييمات حتى الآن',
          style: TextStyle(
            color: colors.onSurface,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          'عندما يقيّم أحد زوار عروضك تجربته مع صاحب العرض، سيظهر تقييمه هنا.',
          textAlign: TextAlign.center,
          style: TextStyle(color: colors.onSurfaceVariant, height: 1.45),
        ),
      ],
    ),
  );

  Widget _errorState(ColorScheme colors) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off_rounded, color: colors.error, size: 42),
          const SizedBox(height: 10),
          Text(
            'تعذر تحميل التقييمات',
            style: TextStyle(
              color: colors.onSurface,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'تحقق من اتصال الإنترنت ثم حاول مرة أخرى.',
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    ),
  );
}

class _CustomerReviewsData {
  const _CustomerReviewsData({
    required this.reviews,
    required this.averageRating,
  });

  final List<Map<String, dynamic>> reviews;
  final double averageRating;
}
