// lib/features/provider/presentation/pages/provider_reviews_page.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

import 'package:loqma/features/provider/data/repositories/service_provider_repository.dart';

class ProviderReviewsPage extends StatefulWidget {
  const ProviderReviewsPage({super.key});

  @override
  State<ProviderReviewsPage> createState() => _ProviderReviewsPageState();
}

class _ProviderReviewsPageState extends State<ProviderReviewsPage> {
  static const _bg = Color(0xFFF4F8F6);
  static const _bgDark = Color(0xFFE6F0EA);
  static const _blue = Color(0xFF3679C8);
  static const _ink = Color(0xFF123F31);
  static const _inkSoft = Color(0xFF315A45);
  static const _cardBg = Colors.white;
  static const _orange = Color(0xFFE28B00);

  final _repo = ServiceProviderRepository();

  bool _loading = true;
  Map<String, dynamic>? _stats;
  List<Map<String, dynamic>> _reviews = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    final providerResult = await _repo.getCurrentProvider();
    if (!mounted) return;

    await providerResult.fold(
      (err) async {
        setState(() => _loading = false);
      },
      (provider) async {
        final providerId = provider['id'].toString();

        final statsResult = await _repo.getProviderStats(providerId);
        final reviewsResult = await _repo.getProviderReviews(providerId);

        if (!mounted) return;

        setState(() {
          statsResult.fold(
            (err) {},
            (stats) => _stats = stats,
          );
          reviewsResult.fold(
            (err) {},
            (reviews) => _reviews = reviews,
          );
          _loading = false;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _bg,
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [_bg, _bgDark],
            ),
          ),
          child: SafeArea(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: _blue),
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    color: _blue,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildHeader(),
                          const SizedBox(height: 20),
                          _buildRatingSummary(),
                          const SizedBox(height: 20),
                          if (_reviews.isEmpty)
                            _buildEmptyState()
                          else
                            ..._reviews.map(_buildReviewCard),
                        ],
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'التقييمات',
          style: TextStyle(
            color: _ink,
            fontSize: 24,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'كل اللي قالوه عنك العملاء',
          style: TextStyle(
            color: _inkSoft.withValues(alpha: 0.7),
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _buildRatingSummary() {
    final rating = (_stats?['rating_avg'] as num?)?.toDouble() ?? 0;
    final count = (_stats?['total_reviews'] as num?)?.toInt() ?? 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF0A93D), _orange],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _orange.withValues(alpha: 0.3),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Column(
            children: [
              Text(
                rating.toStringAsFixed(1),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 44,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: List.generate(5, (i) {
                  return Icon(
                    i < rating.round()
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                    color: Colors.white,
                    size: 16,
                  );
                }),
              ),
            ],
          ),
          const SizedBox(width: 20),
          Container(
            width: 1,
            height: 60,
            color: Colors.white.withValues(alpha: 0.3),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'بناءً على',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$count تقييم',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  count == 0
                      ? 'لسه مفيش تقييمات'
                      : 'كل الشكر للعملاء اللي قيموك',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _inkSoft.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _orange.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.star_border_rounded,
              color: _orange.withValues(alpha: 0.6),
              size: 42,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'لسه مفيش تقييمات',
            style: TextStyle(
              color: _ink,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'أول ما عميل يقيمك، تقييمه هيظهر هنا',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _inkSoft.withValues(alpha: 0.7),
              fontSize: 12.5,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewCard(Map<String, dynamic> review) {
    final user = review['users'];
    final reviewerName = (user is Map
            ? user['name']?.toString()
            : review['user_name']?.toString()) ??
        'عميل';
    final avatarUrl = user is Map ? user['avatar_url']?.toString() : null;
    final isAnonymous = review['is_anonymous'] as bool? ?? false;
    final rating = (review['rating'] as num?)?.toInt() ?? 0;
    final comment = review['comment']?.toString() ?? '';
    final createdAtRaw = review['created_at']?.toString() ?? '';
    final createdAt = DateTime.tryParse(createdAtRaw);

    // ✅ الصور
    final images = (review['images'] as List?)?.cast<String>() ?? [];

    // ✅ Tags
    final tags = (review['tags'] as List?)?.cast<String>() ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _inkSoft.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: _inkSoft.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: _blue.withValues(alpha: 0.12),
                backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
                    ? NetworkImage(avatarUrl)
                    : null,
                child: (avatarUrl == null || avatarUrl.isEmpty)
                    ? Icon(
                        isAnonymous
                            ? Icons.visibility_off_rounded
                            : Icons.person_rounded,
                        color: _blue,
                        size: 22,
                      )
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            reviewerName,
                            style: const TextStyle(
                              color: _ink,
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        if (isAnonymous) ...[
                          const SizedBox(width: 5),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _inkSoft.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'مجهول',
                              style: TextStyle(
                                color: _inkSoft.withValues(alpha: 0.7),
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: List.generate(5, (i) {
                        return Icon(
                          i < rating
                              ? Icons.star_rounded
                              : Icons.star_border_rounded,
                          color: _orange,
                          size: 14,
                        );
                      }),
                    ),
                  ],
                ),
              ),
              if (createdAt != null)
                Text(
                  DateFormat('dd/MM/yyyy').format(createdAt),
                  style: TextStyle(
                    color: _inkSoft.withValues(alpha: 0.5),
                    fontSize: 10.5,
                  ),
                ),
            ],
          ),

          // Comment
          if (comment.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _bg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                comment,
                style: TextStyle(
                  color: _inkSoft.withValues(alpha: 0.9),
                  fontSize: 12.5,
                  height: 1.6,
                ),
              ),
            ),
          ],

          // Images
          if (images.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 70,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: images.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) => ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    images[i],
                    width: 70,
                    height: 70,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 70,
                      height: 70,
                      color: _bg,
                      child: Icon(Icons.broken_image_outlined,
                          color: _inkSoft.withValues(alpha: 0.4)),
                    ),
                  ),
                ),
              ),
            ),
          ],

          // Tags
          if (tags.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: tags.map((tag) {
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _blue.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    tag,
                    style: const TextStyle(
                      color: _blue,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}
