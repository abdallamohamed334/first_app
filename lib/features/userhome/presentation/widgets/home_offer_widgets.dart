import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:loqma/core/config/app_config.dart';
import 'package:loqma/features/community/presentation/utils/offer_expiry_helper.dart';
import 'package:loqma/features/offers/domain/entities/food_offer.dart';
import 'package:loqma/features/userhome/domain/entities/category_offer.dart';
import 'package:loqma/features/userhome/presentation/widgets/home_palette.dart';

class HomeFoodOfferLargeCard extends StatelessWidget {
  final FoodOffer offer;
  final VoidCallback onTap;

  const HomeFoodOfferLargeCard({
    required this.offer,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 260,
        decoration: BoxDecoration(
          color: HomePalette.cardSoft,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: HomePalette.border, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: HomePalette.isDark ? 0.28 : 0.07,
              ),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  HomeFoodImage(
                    url: offer.displayImage,
                    fallback: Icons.restaurant_rounded,
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFFE28B00), Color(0xFFB77700)],
                        ),
                        borderRadius: BorderRadius.circular(100),
                        boxShadow: [
                          BoxShadow(
                            color:
                                const Color(0xFFE28B00).withValues(alpha: 0.4),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Text(
                        'عاجل 🔥',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    offer.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: HomePalette.textPrimary,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    offer.businessName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: HomePalette.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.schedule_rounded,
                          size: 13, color: HomePalette.primaryRed),
                      SizedBox(width: 4),
                      Text(
                        offer.timeRemaining,
                        style: TextStyle(
                          color: HomePalette.primaryRed,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
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

// ============================================================
// ✅ FOOD CARD — (للأرشيف)
// ============================================================
class HomeFoodOfferCard extends StatelessWidget {
  final FoodOffer offer;
  final VoidCallback onTap;

  const HomeFoodOfferCard({
    required this.offer,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 180,
        decoration: BoxDecoration(
          color: HomePalette.cardSoft,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: HomePalette.border, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: HomePalette.isDark ? 0.28 : 0.07,
              ),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 130,
              width: double.infinity,
              child: HomeFoodImage(
                url: offer.displayImage,
                fallback: Icons.restaurant_rounded,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    offer.priceDisplay,
                    style: TextStyle(
                      color: HomePalette.primaryRed,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    offer.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: HomePalette.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                    ),
                  ),
                  SizedBox(height: 7),
                  Text(
                    offer.businessName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: HomePalette.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (offer.distanceMeters != null) ...[
                    SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(Icons.location_on_rounded,
                            size: 11,
                            color: HomePalette.textSecondary
                                .withValues(alpha: 0.7)),
                        SizedBox(width: 3),
                        Text(
                          offer.distanceDisplay,
                          style: TextStyle(
                            color: HomePalette.textSecondary,
                            fontSize: 10.5,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// FOOD IMAGE
// ============================================================
class HomeFoodImage extends StatelessWidget {
  final String? url;
  final IconData fallback;

  const HomeFoodImage({
    required this.url,
    required this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty || url == 'null') {
      return Container(
        color: HomePalette.cardSoft,
        child: Icon(fallback,
            color: HomePalette.textSecondary.withValues(alpha: 0.7),
            size: 36),
      );
    }

    return CachedNetworkImage(
      imageUrl: url!,
      fit: BoxFit.cover,
      placeholder: (_, __) => Container(
        color: HomePalette.cardSoft,
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: HomePalette.primaryRed,
            ),
          ),
        ),
      ),
      errorWidget: (_, __, ___) => Container(
        color: HomePalette.cardSoft,
        child: Icon(fallback,
            color: HomePalette.textSecondary.withValues(alpha: 0.7),
            size: 36),
      ),
    );
  }
}

// ============================================================
// ✅ COMMUNITY CARD
// ============================================================
class HomeCommunityOfferCard extends StatelessWidget {
  final Map<String, dynamic> offer;
  final VoidCallback onTap;

  const HomeCommunityOfferCard({
    required this.offer,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final title = offer['title']?.toString() ?? 'عرض بسعر رمزي';
    final description = offer['description']?.toString().trim() ?? '';
    final category = offer['category_name_ar']?.toString() ??
        offer['category']?.toString() ??
        'أخرى';
    final price = _formatPrice(offer['price']);
    final viewsCount =
        int.tryParse(offer['views_count']?.toString() ?? '') ?? 0;
    final distance = _formatDistance(offer['distance_meters']);
    final image = _communityImage(offer);
    final expiresAt = _parseDate(offer['expires_at']);

    return Container(
      width: 250,
      decoration: BoxDecoration(
        color: HomePalette.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: HomePalette.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: HomePalette.isDark ? 0.3 : 0.08,
            ),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 142,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    HomeCommunityImage(image: image),
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: HomePalette.primaryRed,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: HomePalette.primaryRed.withValues(
                                alpha: 0.28,
                              ),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Text(
                          price,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 112),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.58),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Text(
                          category,
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
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      height: 46,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.42),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 9,
                      right: 11,
                      child: Row(
                        children: const [
                          Icon(
                            Icons.volunteer_activism_rounded,
                            color: Colors.white,
                            size: 15,
                          ),
                          SizedBox(width: 5),
                          Text(
                            'من المجتمع',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(13, 11, 13, 11),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: HomePalette.textPrimary,
                          fontSize: 14,
                          height: 1.25,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Icon(
                            Icons.visibility_outlined,
                            size: 14,
                            color: HomePalette.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$viewsCount شخص',
                            style: TextStyle(
                              color: HomePalette.textSecondary,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      if (description.isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Text(
                          description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: HomePalette.textSecondary,
                            fontSize: 11,
                            height: 1.25,
                          ),
                        ),
                      ],
                      const Spacer(),
                      Row(
                        children: [
                          if (distance != null) ...[
                            Icon(
                              Icons.near_me_rounded,
                              size: 14,
                              color: HomePalette.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                distance,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: HomePalette.textSecondary,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ] else
                            const Spacer(),
                          if (expiresAt != null)
                            OfferExpiryHelper.buildBadge(
                              expiresAt: expiresAt,
                              compact: true,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    if (text.isEmpty || text == 'null') return null;
    return DateTime.tryParse(text);
  }

  static String _formatPrice(dynamic value) {
    final number = value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '') ?? 0;
    if (number <= 0) return 'سعر رمزي';
    return '${number.toStringAsFixed(0)} ج.م';
  }

  static String? _formatDistance(dynamic value) {
    final meters = value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '');
    if (meters == null) return null;
    if (meters < 1000) return '${meters.round()} م';
    return '${(meters / 1000).toStringAsFixed(1)} كم';
  }

  static String? _communityImage(Map<String, dynamic> offer) {
    final values = <dynamic>[
      offer['image'],
      offer['image_url'],
      offer['images'],
      offer['image_urls'],
      offer['offer_images'],
    ];
    for (final value in values) {
      final raw = value is List && value.isNotEmpty ? value.first : value;
      final text = raw?.toString().trim() ?? '';
      if (text.isEmpty || text == 'null' || text == 'undefined') continue;
      if (text.startsWith('http://') || text.startsWith('https://')) {
        return text;
      }
      return AppConfig.storagePublicUrl('community-offers', text);
    }
    return null;
  }
}

// ============================================================
// COMMUNITY IMAGE
// ============================================================
class HomeCommunityImage extends StatelessWidget {
  final String? image;

  const HomeCommunityImage({required this.image});

  @override
  Widget build(BuildContext context) {
    if (image == null || image!.isEmpty || image == 'null') {
      return Container(
        color: HomePalette.cardSoft,
        child: Icon(Icons.sell_rounded,
            color: HomePalette.textSecondary.withValues(alpha: 0.7),
            size: 36),
      );
    }

    return CachedNetworkImage(
      imageUrl: image!,
      fit: BoxFit.cover,
      errorWidget: (_, __, ___) => Container(
        color: HomePalette.cardSoft,
        child: Icon(Icons.sell_rounded,
            color: HomePalette.textSecondary.withValues(alpha: 0.7),
            size: 36),
      ),
    );
  }
}

// ============================================================
// COMMUNITY EMPTY
// ============================================================
class HomeCommunityEmptyCard extends StatelessWidget {
  final VoidCallback onAdd;

  const HomeCommunityEmptyCard({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: HomePalette.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: HomePalette.border, width: 1),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: HomePalette.primaryRed.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.sell_rounded,
                  color: HomePalette.primaryRed, size: 24),
            ),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'أضف شيئًا للبيع',
                    style: TextStyle(
                      color: HomePalette.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'عندك حاجة مش محتاجها؟ اعرضها للبيع بسعر مناسب.',
                    style: TextStyle(
                      color: HomePalette.textSecondary,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 10),
            ElevatedButton(
              onPressed: onAdd,
              style: ElevatedButton.styleFrom(
                backgroundColor: HomePalette.primaryRed,
                foregroundColor: Colors.white,
                elevation: 0,
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text('أضف', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// ✅ ADD ACTION TILE
// ============================================================

class HomeCategoryOfferCard extends StatelessWidget {
  final CategoryOffer offer;
  final VoidCallback onTap;
  const HomeCategoryOfferCard({required this.offer, required this.onTap});

  String? _storageImageUrl(String? rawValue) {
    final value = rawValue?.trim();
    if (value == null ||
        value.isEmpty ||
        value == 'null' ||
        value == 'undefined') {
      return null;
    }

    final defaultBucket =
        offer.isInstitution ? 'institution-images' : 'community-offers';
    final uri = Uri.tryParse(value);
    if (uri != null && uri.hasScheme && uri.host.isNotEmpty) {
      final segments = uri.pathSegments;
      final objectIndex = segments.indexOf('object');
      if (objectIndex >= 0 && segments.length > objectIndex + 2) {
        final bucket = segments[objectIndex + 2];
        final path = segments.sublist(objectIndex + 3).join('/');
        if (path.isNotEmpty) {
          // Convert expired signed/authenticated URLs to a fresh public URL.
          return AppConfig.storagePublicUrl(bucket, path);
        }
      }
      return value;
    }

    var path = value;
    if (path.startsWith('$defaultBucket/')) {
      path = path.substring(defaultBucket.length + 1);
    }
    return AppConfig.storagePublicUrl(defaultBucket, path);
  }

  String? _imageUrl() {
    return _storageImageUrl(offer.image);
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = _imageUrl();
    final ownerLabel = offer.isInstitution
        ? (offer.ownerName ?? 'مؤسسة')
        : (offer.ownerName ?? 'عرض من المجتمع');
    final typeLabel = offer.isInstitution ? 'مؤسسة' : 'من المجتمع';
    final viewsCount =
        int.tryParse(offer.raw['views_count']?.toString() ?? '') ?? 0;

    return SizedBox(
      width: 210,
      child: Material(
        color: HomePalette.cardSoft,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: HomePalette.border),
        ),
        elevation: 1,
        shadowColor: Colors.black.withValues(
          alpha: HomePalette.isDark ? 0.28 : 0.07,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 134,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    imageUrl == null
                        ? Container(
                            color: HomePalette.cardSoft,
                            child: Icon(
                              Icons.image_outlined,
                              size: 44,
                              color: HomePalette.primaryRed,
                            ),
                          )
                        : CachedNetworkImage(
                            imageUrl: imageUrl,
                            fit: BoxFit.cover,
                            memCacheWidth: 640,
                            placeholder: (_, __) => Container(
                              color: HomePalette.cardSoft,
                              child: Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: HomePalette.primaryRed,
                                ),
                              ),
                            ),
                            errorWidget: (_, __, ___) => Container(
                              color: HomePalette.cardSoft,
                              child: Icon(
                                Icons.image_not_supported_outlined,
                                color: HomePalette.textSecondary,
                                size: 36,
                              ),
                            ),
                          ),
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.18),
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.42),
                            ],
                            stops: const [0, 0.45, 1],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.94),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          typeLabel,
                          style: TextStyle(
                            color: HomePalette.primaryRed,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.42),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
                        ),
                        child: const Icon(Icons.bookmark_border_rounded, color: Colors.white, size: 19),
                      ),
                    ),
                    if (offer.hasPrice)
                      Positioned(
                        left: 10,
                        bottom: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: HomePalette.primaryRed,
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: Text(
                            offer.priceDisplay,
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900),
                          ),
                        ),
                      ),
                    if (offer.distanceDisplay != null)
                      Positioned(
                        bottom: 9,
                        right: 10,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.location_on_rounded,
                              size: 13,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              offer.distanceDisplay!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        offer.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: HomePalette.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          height: 1.25,
                        ),
                      ),
                      if (offer.isCommunity) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.visibility_outlined,
                              size: 13,
                              color: HomePalette.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$viewsCount شخص',
                              style: TextStyle(
                                color: HomePalette.textSecondary,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const Spacer(),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              ownerLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: HomePalette.textSecondary,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: HomePalette.primaryRed.withValues(
                                alpha: 0.10,
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              offer.priceDisplay,
                              style: TextStyle(
                                color: HomePalette.primaryRed,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
