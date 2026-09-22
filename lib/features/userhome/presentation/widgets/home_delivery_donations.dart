// lib/features/userhome/presentation/widgets/home_delivery_donations.dart

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class DeliveryDonation {
  final String id;
  final String title;
  final String description;
  final String pickupLocation;
  final String deliveryLocation;
  final double distance;
  final int quantity;
  final String foodType;
  final String status;
  final String donorName;
  final String? donorImage;
  final DateTime createdAt;
  final String? image;
  final String charityName;
  final String city;

  const DeliveryDonation({
    required this.id,
    required this.title,
    required this.description,
    required this.pickupLocation,
    required this.deliveryLocation,
    required this.distance,
    required this.quantity,
    required this.foodType,
    required this.status,
    required this.donorName,
    this.donorImage,
    required this.createdAt,
    this.image,
    required this.charityName,
    required this.city,
  });

  factory DeliveryDonation.fromJson(Map<String, dynamic> json) {
    // ✅ استخراج بيانات الجمعية
    final charity = json['charities'] is Map
        ? Map<String, dynamic>.from(json['charities'] as Map)
        : const {};
    final charityName = charity['name']?.toString() ?? 'جمعية خيرية';

    // ✅ استخراج بيانات المتبرع
    final donor = json['users'] is Map
        ? Map<String, dynamic>.from(json['users'] as Map)
        : const {};
    final donorName = donor['name']?.toString() ?? 'متبرع';

    // ✅ استخراج المدينة
    final city = json['pickup_city']?.toString() ?? '';

    // ✅ استخراج الصور
    final images = json['images'] is List
        ? List<String>.from(json['images'] as List)
        : <String>[];
    final image = images.isNotEmpty ? images.first : null;

    return DeliveryDonation(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'تبرع طعام',
      description: json['description']?.toString() ?? '',
      pickupLocation: json['pickup_location']?.toString() ?? 'غير محدد',
      deliveryLocation: json['delivery_location']?.toString() ?? 'غير محدد',
      distance: (json['distance'] as num?)?.toDouble() ?? 0,
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      foodType: json['food_type']?.toString() ?? 'وجبات',
      status: json['status']?.toString() ?? 'pending',
      donorName: donorName,
      donorImage: donor['avatar_url']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      image: image,
      charityName: charityName,
      city: city,
    );
  }
}

class HomeDeliveryDonations extends StatelessWidget {
  final List<DeliveryDonation> donations;
  final ValueChanged<DeliveryDonation> onDonationTap;

  const HomeDeliveryDonations({
    super.key,
    required this.donations,
    required this.onDonationTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (donations.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '🤝 تبرعات محتاجة توصيل',
                style: TextStyle(
                  color: colors.onSurface,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              TextButton(
                onPressed: () {
                  // TODO: فتح صفحة كل التبرعات
                },
                child: const Text('عرض الكل'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            '${donations.length} تبرع محتاج متطوعين للتوصيل',
            style: TextStyle(
              color: colors.onSurfaceVariant,
              fontSize: 13,
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 320,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: donations.length > 5 ? 5 : donations.length,
            itemBuilder: (context, index) {
              final donation = donations[index];
              return Padding(
                padding: EdgeInsets.only(
                  right: index == donations.length - 1 ? 0 : 14,
                ),
                child: SizedBox(
                  width: 280,
                  child: _LargeDeliveryDonationCard(
                    donation: donation,
                    onTap: () => onDonationTap(donation),
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

// ✅ كارد كبير للتبرعات المحتاجة توصيل (مطابق لصفحة AllOpenVolunteerDonationsPage)
class _LargeDeliveryDonationCard extends StatelessWidget {
  final DeliveryDonation donation;
  final VoidCallback onTap;

  const _LargeDeliveryDonationCard({
    required this.donation,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1F1F1F) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.3)
                  : Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ✅ الصورة (مطابقة لصفحة التبرعات)
            Stack(
              children: [
                Container(
                  height: 160,
                  width: double.infinity,
                  color: const Color(0xFFE8F5EE),
                  child: donation.image != null && donation.image!.isNotEmpty
                      ? Image.network(
                          donation.image!,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return const Center(
                              child: SizedBox(
                                width: 32,
                                height: 32,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Color(0xFF0B7650),
                                ),
                              ),
                            );
                          },
                          errorBuilder: (_, __, ___) =>
                              _buildImagePlaceholder(),
                        )
                      : _buildImagePlaceholder(),
                ),
                // ✅ تدرج شفاف للأسفل
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0.4, 1],
                        colors: [
                          Colors.transparent,
                          Colors.black.withAlpha(190)
                        ],
                      ),
                    ),
                  ),
                ),
                // ✅ اسم الجمعية والعنوان في أسفل الصورة
                Positioned(
                  left: 14,
                  right: 14,
                  bottom: 10,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        donation.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        donation.charityName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withAlpha(200),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                // ✅ عدد الوحدات
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE28B00),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(30),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.inventory_2_outlined,
                          size: 12,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${donation.quantity} وحدة',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            // ✅ المحتوى
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAF6EF),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.location_on_outlined,
                              size: 14,
                              color: Color(0xFF0B7650),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              donation.city.isNotEmpty
                                  ? donation.city
                                  : 'عنوان متاح',
                              style: const TextStyle(
                                color: Color(0xFF0B7650),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Row(
                          children: [
                            const Icon(
                              Icons.person_outline_rounded,
                              size: 13,
                              color: Color(0xFF71837C),
                            ),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                donation.donorName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFF71837C),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 14,
                        color: Color(0xFF0B7650),
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

  Widget _buildImagePlaceholder() {
    return Container(
      height: 160,
      width: double.infinity,
      color: const Color(0xFFE8F5EE),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.volunteer_activism_rounded,
            color: const Color(0xFF0B7650).withAlpha(100),
            size: 44,
          ),
          const SizedBox(height: 4),
          Text(
            'تبرع',
            style: TextStyle(
              color: const Color(0xFF0B7650).withAlpha(80),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
