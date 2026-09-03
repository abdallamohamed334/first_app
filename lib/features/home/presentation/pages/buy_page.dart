import 'package:flutter/material.dart';
import 'package:loqma/features/offers/domain/entities/food_offer.dart';

class BuyPage extends StatefulWidget {
  final List<FoodOffer> offers;

  const BuyPage({super.key, required this.offers});

  @override
  State<BuyPage> createState() => _BuyPageState();
}

class _BuyPageState extends State<BuyPage> {
  String _selectedCategory = 'الكل';

  final List<Map<String, dynamic>> _categories = [
    {'id': 'الكل', 'label': 'الكل', 'icon': Icons.apps_rounded},
    {'id': 'مطاعم', 'label': '🍔 مطاعم', 'icon': Icons.restaurant_rounded},
    {'id': 'أفراد', 'label': '👤 أفراد', 'icon': Icons.person_rounded},
    {'id': 'بقالة', 'label': '🛒 بقالة', 'icon': Icons.shopping_basket_rounded},
    {'id': 'فنادق', 'label': '🏨 فنادق', 'icon': Icons.hotel_rounded},
    {
      'id': 'قاعات',
      'label': '🏛️ قاعات',
      'icon': Icons.event_available_rounded
    },
    {'id': 'مخابز', 'label': '🥐 مخابز', 'icon': Icons.bakery_dining_rounded},
    {'id': 'حلويات', 'label': '🍰 حلويات', 'icon': Icons.cake_rounded},
  ];

  @override
  Widget build(BuildContext context) {
    final filteredOffers = _filterOffers(widget.offers);

    return Scaffold(
      backgroundColor: const Color(0xFFF6FAF8),
      appBar: AppBar(
        title: const Text(
          '🛍️ أشتري بسعر رمزي',
          style: TextStyle(
            color: Color(0xFF123F31),
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          // ✅ الفلاتر
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: _categories.map((category) {
                  final isSelected = _selectedCategory == category['id'];
                  return Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: FilterChip(
                      selected: isSelected,
                      onSelected: (_) {
                        setState(() => _selectedCategory = category['id']);
                      },
                      label: Text(
                        category['label'],
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : const Color(0xFF123F31),
                          fontWeight:
                              isSelected ? FontWeight.w800 : FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                      backgroundColor: Colors.white,
                      selectedColor: const Color(0xFF0B7650),
                      side: BorderSide(
                        color: isSelected
                            ? const Color(0xFF0B7650)
                            : const Color(0xFFDCEBE3),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          // ✅ العروض
          Expanded(
            child: filteredOffers.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredOffers.length,
                    itemBuilder: (context, index) {
                      return _buildOfferCard(filteredOffers[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  List<FoodOffer> _filterOffers(List<FoodOffer> offers) {
    if (_selectedCategory == 'الكل') return offers;
    // TODO: فلترة حسب التصنيف
    return offers;
  }

  Widget _buildOfferCard(FoodOffer offer) {
    final price = offer.salePrice ?? 0;
    final image = offer.displayImage;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5EE),
              borderRadius: BorderRadius.circular(12),
              image: image != null && image.isNotEmpty
                  ? DecorationImage(
                      image: NetworkImage(image),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: image == null || image.isEmpty
                ? const Icon(
                    Icons.restaurant_rounded,
                    color: Color(0xFF0B7650),
                    size: 32,
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  offer.businessName,
                  style: const TextStyle(
                    color: Color(0xFF71837C),
                    fontSize: 11,
                  ),
                ),
                Text(
                  offer.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF123F31),
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0B7650).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${offer.quantity} وجبة',
                        style: const TextStyle(
                          color: Color(0xFF0B7650),
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0B7650).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        price > 0 ? '${price.toStringAsFixed(0)} ج.م' : 'مجاني',
                        style: const TextStyle(
                          color: Color(0xFF0B7650),
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Icon(
            Icons.arrow_forward_ios_rounded,
            size: 16,
            color: Color(0xFF71837C),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.inbox_rounded,
            size: 48,
            color: Color(0xFF71837C),
          ),
          SizedBox(height: 12),
          Text(
            'لا توجد عروض في هذا التصنيف',
            style: TextStyle(
              color: Color(0xFF71837C),
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
