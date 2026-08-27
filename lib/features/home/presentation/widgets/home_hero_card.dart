import 'package:flutter/material.dart';
import '../../../offers/domain/entities/food_offer.dart';

class HomeHeroCard extends StatelessWidget {
  final List<FoodOffer> offers;
  final VoidCallback? onViewAll;
  final void Function(FoodOffer)? onOfferTap; // ✅ إضافة

  const HomeHeroCard({
    super.key,
    required this.offers,
    this.onViewAll,
    this.onOfferTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final urgentOffers =
        offers.where((o) => o.isUrgent && o.isAvailable).toList();
    final displayOffers = urgentOffers.isNotEmpty ? urgentOffers : offers;
    final offer = displayOffers.isNotEmpty ? displayOffers.first : null;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primary,
            colorScheme.primaryContainer,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.3),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          // ✅ Decorative Pattern
          const Positioned(
            right: -20,
            bottom: -20,
            child: Opacity(
              opacity: 0.1,
              child: Icon(
                Icons.restaurant_menu,
                size: 120,
                color: Colors.white,
              ),
            ),
          ),
          // ✅ Content
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ✅ Badge
                GestureDetector(
                  onTap: offer != null && onOfferTap != null
                      ? () => onOfferTap!(offer)
                      : null,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          offer != null && offer.isUrgent
                              ? Icons.local_fire_department
                              : Icons.volunteer_activism,
                          size: 16,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          offer != null && offer.isUrgent
                              ? '🔥 عروض عاجلة'
                              : '🍽️ عروض متاحة',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // ✅ Main Text
                GestureDetector(
                  onTap: offer != null && onOfferTap != null
                      ? () => onOfferTap!(offer)
                      : null,
                  child: Text(
                    offer != null ? offer.title : 'لا توجد عروض متاحة حالياً',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      height: 1.2,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  offer != null
                      ? '${offer.businessName} • ${offer.quantity} وجبات • ${offer.timeRemaining}'
                      : 'تحقق لاحقاً سيكون هناك عروض جديدة',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
                const SizedBox(height: 16),
                // ✅ Buttons Row
                Row(
                  children: [
                    if (offer != null)
                      GestureDetector(
                        onTap: () => onOfferTap?.call(offer),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.visibility,
                                size: 18,
                                color: colorScheme.primary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'عرض التفاصيل',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (onViewAll != null && offers.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: onViewAll,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.list_alt,
                                size: 18,
                                color: Colors.white,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'عرض الكل',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
