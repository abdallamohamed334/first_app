import 'package:flutter/material.dart';
import '../../../offers/domain/entities/food_offer.dart';
import '../pages/all_offers_page.dart';
import '../../../donation/presentation/pages/offer_details_page.dart';

class HomeUrgentOpportunities extends StatelessWidget {
  final List<FoodOffer> offers;

  const HomeUrgentOpportunities({
    super.key,
    required this.offers,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final urgentOffers =
        offers.where((offer) => offer.isAvailable && offer.isUrgent).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'فرص عاجلة',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AllOffersPage(offers: offers),
                    ),
                  );
                },
                child: const Text('عرض الكل'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (urgentOffers.isEmpty)
            _buildEmptyState(colorScheme)
          else
            SizedBox(
              height: 210, // ✅ زودناها من 180 إلى 210
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: urgentOffers.length > 3 ? 3 : urgentOffers.length,
                itemBuilder: (context, index) {
                  final offer = urgentOffers[index];
                  return _buildOfferCard(context, offer, colorScheme);
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme colorScheme) {
    return Container(
      height: 120,
      width: double.infinity,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outlineVariant.withAlpha(51), // ✅ 0.3 opacity
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.food_bank_outlined,
            size: 32,
            color: colorScheme.outline,
          ),
          const SizedBox(height: 8),
          Text(
            'لا توجد فرص عاجلة حالياً',
            style: TextStyle(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            'تحقق لاحقاً',
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOfferCard(
    BuildContext context,
    FoodOffer offer,
    ColorScheme colorScheme,
  ) {
    return Container(
      width: 240,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outlineVariant.withAlpha(51), // ✅ 0.3 opacity
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10), // ✅ 0.04 opacity
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize:
            MainAxisSize.min, // ✅ أضف هذا عشان الـ Column ياخد أقل مساحة
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.red.withAlpha(25), // ✅ 0.1 opacity
                  borderRadius: BorderRadius.circular(100),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 12,
                      color: Colors.red,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'عاجل',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.red,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withAlpha(25), // ✅ 0.1 opacity
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  '${offer.quantity} وجبة',
                  style: TextStyle(
                    fontSize: 11,
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            offer.title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                Icons.location_on,
                size: 12,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  offer.pickupLocation,
                  style: TextStyle(
                    fontSize: 11,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(
                Icons.access_time,
                size: 12,
                color: Colors.orange,
              ),
              const SizedBox(width: 4),
              Text(
                'ينتهي خلال ${offer.timeRemaining}',
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.orange,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => OfferDetailsPage(
                      offer: {
                        'id': offer.id,
                        'title': offer.title,
                        'description': offer.description,
                        'quantity': offer.quantity,
                        'food_type': offer.foodType,
                        'expiry_time': offer.expiryTime.toIso8601String(),
                        'pickup_before': offer.pickupBefore.toIso8601String(),
                        'pickup_location': offer.pickupLocation,
                        'latitude': offer.latitude,
                        'longitude': offer.longitude,
                        'image': offer.image,
                        'status': offer.status.value,
                        'restaurant_id': offer.businessId,
                        'charity_id': offer.charityId,
                        'created_at': offer.createdAt.toIso8601String(),
                        'updated_at': offer.updatedAt.toIso8601String(),
                        'restaurants': {
                          'name': offer.businessName,
                        },
                        'images': offer.images ??
                            (offer.image != null ? [offer.image!] : []),
                      },
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                padding: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(100),
                ),
                minimumSize: const Size(double.infinity, 32),
              ),
              child: const Text(
                'اطلب الآن',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
