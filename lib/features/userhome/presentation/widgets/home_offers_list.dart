// lib/features/home/presentation/widgets/home_offers_list.dart

import 'package:flutter/material.dart';
import 'package:loqma/features/offers/domain/entities/food_offer.dart';
import 'package:cached_network_image/cached_network_image.dart';

class HomeOffersList extends StatelessWidget {
  final List<FoodOffer> offers;
  final ValueChanged<FoodOffer> onOfferTap;

  const HomeOffersList({
    super.key,
    required this.offers,
    required this.onOfferTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (offers.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: _EmptyOffers(),
      );
    }

    // عرض الكاردات حسب حجم الشاشة
    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = screenWidth > 600 ? 320.0 : 280.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '🔥 عروض قريبة منك',
                style: TextStyle(
                  color: colors.onSurface,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                'عرض الكل',
                style: TextStyle(
                  color: colors.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 400,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            itemCount: offers.length,
            itemBuilder: (context, index) {
              final offer = offers[index];
              return Padding(
                padding: EdgeInsets.only(
                  right: index == offers.length - 1 ? 0 : 12,
                ),
                child: SizedBox(
                  width: cardWidth,
                  child: _LargeOfferCard(
                    offer: offer,
                    onTap: () => onOfferTap(offer),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _LargeOfferCard extends StatelessWidget {
  final FoodOffer offer;
  final VoidCallback onTap;

  const _LargeOfferCard({
    required this.offer,
    required this.onTap,
  });

  List<String> get _images {
    final images = offer.displayImages;
    if (images.isEmpty && offer.image != null) {
      return [offer.image!];
    }
    return images;
  }

  String _getSourceIcon() {
    if (offer.source == 'institution') return '🏪';
    if (offer.businessType == 'restaurant') return '🍔';
    if (offer.businessType == 'bakery') return '🥐';
    if (offer.businessType == 'sweets') return '🍰';
    if (offer.businessType == 'grocery') return '🛒';
    if (offer.businessType == 'hotel') return '🏨';
    return '👤';
  }

  String _getSourceLabel() {
    if (offer.source == 'institution') return offer.businessName;
    if (offer.businessType == 'restaurant') return 'مطعم ${offer.businessName}';
    if (offer.businessType == 'bakery') return 'مخبز ${offer.businessName}';
    if (offer.businessType == 'sweets') return 'حلويات ${offer.businessName}';
    if (offer.businessType == 'grocery') return 'بقالة ${offer.businessName}';
    if (offer.businessType == 'hotel') return 'فندق ${offer.businessName}';
    return offer.businessName;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sale = offer.salePrice;
    final orig = offer.originalPrice;
    final hasDiscount = sale != null && orig != null && orig > sale;
    final discount = hasDiscount ? ((1 - sale / orig) * 100).round() : 0;
    final images = _images;
    final hasImages = images.isNotEmpty;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1F1F1F) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.3)
                  : Colors.black.withValues(alpha: 0.06),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // الصورة الكبيرة
            SizedBox(
              height: 200,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (hasImages)
                    PageView.builder(
                      itemCount: images.length,
                      itemBuilder: (context, index) {
                        return CachedNetworkImage(
                          imageUrl: images[index],
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: colors.primary.withValues(alpha: 0.1),
                            child: const Icon(
                              Icons.image_outlined,
                              size: 60,
                              color: Colors.green,
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: colors.primary.withValues(alpha: 0.1),
                            child: Icon(
                              Icons.image_not_supported_outlined,
                              size: 60,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        );
                      },
                    )
                  else
                    Container(
                      color: colors.primary.withValues(alpha: 0.1),
                      child: Icon(
                        Icons.restaurant_rounded,
                        size: 60,
                        color: colors.primary,
                      ),
                    ),

                  // تعداد الصور
                  if (images.length > 1)
                    Positioned(
                      bottom: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${images.length} صور',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),

                  // حالة الطلب
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: offer.isUrgent
                            ? const Color(0xFFE28B00)
                            : colors.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        offer.isUrgent ? '🔥 عاجل' : 'متاح',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // المحتوى
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // المصدر والتقييم
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '$_getSourceIcon() $_getSourceLabel()',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.onSurfaceVariant,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (offer.businessRating > 0) ...[
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.star_rounded,
                          size: 14,
                          color: Color(0xFFE28B00),
                        ),
                        Text(
                          offer.businessRating.toStringAsFixed(1),
                          style: TextStyle(
                            color: colors.onSurfaceVariant,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),

                  // العنوان
                  Text(
                    offer.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // الموقع والكمية
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_rounded,
                        size: 14,
                        color: colors.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          offer.pickupLocation,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.onSurfaceVariant,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '📦 ${offer.quantity}',
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // ✅ السعر والتوفير - من غير Expanded جوه Wrap
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    alignment: WrapAlignment.start,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (sale != null && sale > 0)
                        Text(
                          '${sale.toStringAsFixed(0)} ج.م',
                          style: TextStyle(
                            color: colors.primary,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      if (hasDiscount) ...[
                        Text(
                          '${orig.toStringAsFixed(0)} ج.م',
                          style: TextStyle(
                            color: colors.onSurfaceVariant,
                            fontSize: 12,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFE9B8),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'وفر $discount%',
                            style: const TextStyle(
                              color: Color(0xFFB77700),
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                      if (sale == null || sale == 0)
                        Text(
                          '🎁 مجاني',
                          style: TextStyle(
                            color: colors.primary,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 6),

                  // ✅ زر احجز والوقت في صف واحد
                  Row(
                    children: [
                      const Icon(
                        Icons.timer_outlined,
                        size: 14,
                        color: Color(0xFFB77700),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '⏰ يغلق خلال ${offer.timeRemaining}',
                          style: const TextStyle(
                            color: Color(0xFFB77700),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: colors.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'احجز الآن',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
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
      ),
    );
  }
}

class _EmptyOffers extends StatelessWidget {
  const _EmptyOffers();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F1F1F) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        children: [
          Icon(
            Icons.inbox_rounded,
            size: 64,
            color: colors.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            'لا توجد عروض قريبة',
            style: TextStyle(
              color: colors.onSurface,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'ابقَ قريبًا، سنعرض لك أي فرصة فور توفرها',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.onSurfaceVariant,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
