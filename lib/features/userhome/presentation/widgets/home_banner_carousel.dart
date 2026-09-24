// lib/features/home/presentation/widgets/home_banner_carousel.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:loqma/core/services/supabase_service.dart';
import 'package:loqma/features/institutions/presentation/pages/institution_offer_details_page.dart';
import 'package:loqma/features/institutions/domain/entities/institution_offer.dart';

class HomeBanner {
  final String id;
  final String imageUrl;
  final String offerId;
  final int sortOrder;
  final String? title;
  final String? subtitle;

  const HomeBanner({
    required this.id,
    required this.imageUrl,
    required this.offerId,
    required this.sortOrder,
    this.title,
    this.subtitle,
  });

  factory HomeBanner.fromJson(Map<String, dynamic> json) {
    return HomeBanner(
      id: json['id']?.toString() ?? '',
      imageUrl: json['image_url']?.toString() ?? '',
      offerId: json['offer_id']?.toString() ?? '',
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
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

  void _onBannerTap(HomeBanner banner) async {
    try {
      final client = SupabaseService().client;
      final response = await client.from('institution_offers').select('''
            *,
            institutions:institution_id (
              id,
              name,
              institution_type,
              logo_url,
              address,
              phone
            )
          ''').eq('id', banner.offerId).maybeSingle();

      if (response == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('العرض غير متاح حالياً'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final offer = InstitutionOffer.fromJson(
        Map<String, dynamic>.from(response),
      );

      if (!offer.isActive) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('هذا العرض غير متاح حالياً'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => InstitutionOfferDetailsPage(offer: offer),
        ),
      );
    } catch (e) {
      debugPrint('❌ Error opening banner offer: $e');
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
          height: 200,
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
                                    Colors.black.withValues(alpha: 0.6),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),

                            // ✅ النص على الصورة
                            if (banner.title != null || banner.subtitle != null)
                              Positioned(
                                bottom: 20,
                                left: 20,
                                right: 20,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (banner.title != null &&
                                        banner.title!.isNotEmpty)
                                      Text(
                                        banner.title!,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 20,
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
                                          fontSize: 13,
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
                                      child: const Text(
                                        'شاهد العرض',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                            // ✅ مؤشر الصفحات في الأعلى (يمين)
                            if (widget.banners.length > 1)
                              Positioned(
                                top: 12,
                                right: 16,
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
