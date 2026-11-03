// lib/features/home/presentation/widgets/home_banner_carousel.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';

class HomeBanner {
  final String id;
  final String imageUrl;
  final String? targetUrl;
  final int sortOrder;
  final String advertiserName;
  final String? title;
  final String? subtitle;

  const HomeBanner({
    required this.id,
    required this.imageUrl,
    this.targetUrl,
    required this.sortOrder,
    required this.advertiserName,
    this.title,
    this.subtitle,
  });

  factory HomeBanner.fromJson(Map<String, dynamic> json) {
    return HomeBanner(
      id: json['id']?.toString() ?? '',
      imageUrl: json['image_url']?.toString() ?? '',
      targetUrl: json['target_url']?.toString(),
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      advertiserName: json['advertiser_name']?.toString() ?? 'إعلان',
      title: json['title']?.toString(),
      subtitle: json['subtitle']?.toString(),
    );
  }
}

class HomeBannerCarousel extends StatefulWidget {
  final List<HomeBanner> banners;

  const HomeBannerCarousel({
    super.key,
    required this.banners,
  });

  @override
  State<HomeBannerCarousel> createState() => _HomeBannerCarouselState();
}

class _HomeBannerCarouselState extends State<HomeBannerCarousel> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startAutoPlay();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant HomeBannerCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.banners.length == widget.banners.length) return;
    _timer?.cancel();
    _currentPage = 0;
    if (_pageController.hasClients) {
      _pageController.jumpToPage(0);
    }
    _startAutoPlay();
  }

  void _startAutoPlay() {
    if (widget.banners.length <= 1) return;
    _timer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (_pageController.hasClients && widget.banners.isNotEmpty) {
        final nextPage = (_currentPage + 1) % widget.banners.length;
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  Future<void> _onBannerTap(HomeBanner banner) async {
    final rawUrl = banner.targetUrl?.trim();
    if (rawUrl == null || rawUrl.isEmpty) return;
    final uri = Uri.tryParse(rawUrl);
    if (uri == null || !uri.hasScheme || !{'http', 'https'}.contains(uri.scheme)) {
      return;
    }
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('❌ Error opening home ad link: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (widget.banners.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        // ✅ السلايدر بتصميم جديد
        SizedBox(
          height: 250,
          child: Stack(
            children: [
              PageView.builder(
                controller: _pageController,
                itemCount: widget.banners.length,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                  _timer?.cancel();
                  _startAutoPlay();
                },
                itemBuilder: (context, index) {
                  final banner = widget.banners[index];
                  return GestureDetector(
                    onTap: () => _onBannerTap(banner),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: isDark
                                ? Colors.black.withValues(alpha: 0.4)
                                : Colors.black.withValues(alpha: 0.10),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            // ✅ الصورة
                            CachedNetworkImage(
                              imageUrl: banner.imageUrl,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              placeholder: (context, url) => Container(
                                color: colors.primary.withValues(alpha: 0.1),
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.green,
                                  ),
                                ),
                              ),
                              errorWidget: (context, url, error) => Container(
                                color: colors.primary.withValues(alpha: 0.1),
                                child: Icon(
                                  Icons.image_outlined,
                                  size: 48,
                                  color: colors.primary,
                                ),
                              ),
                            ),

                            // ✅ Overlay داكن عشان النص يبان
                            Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: [
                                    Colors.black.withValues(alpha: 0.82),
                                    Colors.black.withValues(alpha: 0.12),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),

                            Positioned(
                              top: 14,
                              right: 14,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.42),
                                  borderRadius: BorderRadius.circular(100),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.22),
                                  ),
                                ),
                                child: Text(
                                  'إعلان • ${banner.advertiserName}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),

                            // ✅ النص على الصورة
                            if (banner.title != null || banner.subtitle != null)
                              Positioned(
                                bottom: 20,
                                left: 20,
                                right: 20,
                                child: Container(
                                  padding: const EdgeInsets.fromLTRB(
                                    14,
                                    12,
                                    14,
                                    12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.48),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.18),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (banner.title != null &&
                                          banner.title!.isNotEmpty)
                                        Text(
                                          banner.title!,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 22,
                                            fontWeight: FontWeight.w900,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      if (banner.subtitle != null &&
                                          banner.subtitle!.isNotEmpty)
                                        const SizedBox(height: 4),
                                      if (banner.subtitle != null &&
                                          banner.subtitle!.isNotEmpty)
                                        Text(
                                          banner.subtitle!,
                                          style: TextStyle(
                                            color: Colors.white
                                                .withValues(alpha: 0.85),
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      // ✅ زر العرض
                                      const SizedBox(height: 10),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: colors.primary,
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          banner.targetUrl == null ||
                                                  banner.targetUrl!.trim().isEmpty
                                              ? 'إعلان'
                                              : 'اعرف أكثر',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                            // ✅ مؤشر الصفحات في الأعلى (يسار) بعيدًا عن اسم المعلن
                            if (widget.banners.length > 1)
                              Positioned(
                                top: 12,
                                left: 16,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.4),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${_currentPage + 1}/${widget.banners.length}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),

        // ✅ نقاط التقدم (أسفل السلايدر)
        if (widget.banners.length > 1)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              widget.banners.length,
              (index) => AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: _currentPage == index ? 24 : 6,
                height: 4,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  color: _currentPage == index
                      ? colors.primary
                      : colors.outlineVariant,
                ),
              ),
            ),
          ),
        const SizedBox(height: 8),
      ],
    );
  }
}

/// Compact sponsored card used above the provider-code search on the Services tab.
/// It stays small and disappears entirely when there are no active banners.
class HomeCompactAdCard extends StatelessWidget {
  const HomeCompactAdCard({super.key, required this.banner});

  final HomeBanner banner;

  Future<void> _openTarget() async {
    final rawUrl = banner.targetUrl?.trim();
    if (rawUrl == null || rawUrl.isEmpty) return;
    final uri = Uri.tryParse(rawUrl);
    if (uri == null || !{'http', 'https'}.contains(uri.scheme)) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (error) {
      debugPrint('❌ Error opening compact home ad: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final title = banner.title?.trim();
    final subtitle = banner.subtitle?.trim();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _openTarget,
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            height: 100,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF252A2D) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.primary.withValues(alpha: .18)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? .16 : .06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(11),
                  child: CachedNetworkImage(
                    imageUrl: banner.imageUrl,
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: colors.primary.withValues(alpha: .08),
                      child: Icon(Icons.campaign_rounded, color: colors.primary),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: colors.primary.withValues(alpha: .08),
                      child: Icon(Icons.campaign_rounded, color: colors.primary),
                    ),
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'إعلان • ${banner.advertiserName}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.primary,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        (title == null || title.isEmpty) ? 'اعرف خدماتنا' : title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isDark ? Colors.white : const Color(0xFF18221F),
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (subtitle != null && subtitle.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.black54,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Icon(Icons.chevron_left_rounded, color: colors.primary, size: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
