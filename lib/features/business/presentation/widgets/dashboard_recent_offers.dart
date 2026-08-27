// lib/features/business/presentation/widgets/dashboard_recent_offers.dart

import 'package:flutter/material.dart';
import 'package:loqma/core/services/supabase_service.dart';

class DashboardRecentOffers extends StatefulWidget {
  final String businessId;

  const DashboardRecentOffers({super.key, required this.businessId});

  @override
  State<DashboardRecentOffers> createState() => _DashboardRecentOffersState();
}

class _DashboardRecentOffersState extends State<DashboardRecentOffers> {
  List<Map<String, dynamic>> _offers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadOffers();
  }

  Future<void> _loadOffers() async {
    setState(() => _isLoading = true);
    try {
      final supabase = SupabaseService().client;
      final response = await supabase
          .from('food_offers')
          .select()
          .eq('business_id', widget.businessId)
          .order('created_at', ascending: false)
          .limit(5);

      setState(() {
        _offers = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Error loading offers: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '📦 العروض الأخيرة',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              TextButton(
                onPressed: () {
                  // TODO: عرض الكل
                },
                child: const Text('عرض الكل'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_offers.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  'لا توجد عروض حتى الآن',
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            )
          else
            ..._offers
                .map((offer) => _buildOfferCard(context, offer, colorScheme)),
        ],
      ),
    );
  }

  Widget _buildOfferCard(
    BuildContext context,
    Map<String, dynamic> offer,
    ColorScheme colorScheme,
  ) {
    final status = offer['status'] as String? ?? 'available';
    final statusColors = {
      'available': Colors.green,
      'reserved': Colors.orange,
      'completed': Colors.blue,
      'expired': Colors.red,
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outlineVariant.withAlpha(51),
        ),
      ),
      child: Row(
        children: [
          // ✅ Image
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 50,
              height: 50,
              color: colorScheme.primary.withAlpha(25),
              child: offer['image'] != null
                  ? Image.network(
                      offer['image'],
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Icon(
                        Icons.restaurant_menu,
                        color: colorScheme.primary.withAlpha(50),
                      ),
                    )
                  : Icon(
                      Icons.restaurant_menu,
                      color: colorScheme.primary.withAlpha(50),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  offer['title'] ?? 'عرض',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(
                      Icons.food_bank,
                      size: 14,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${offer['quantity'] ?? 0} وجبة',
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color:
                            (statusColors[status] ?? Colors.grey).withAlpha(20),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: statusColors[status] ?? Colors.grey,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              // TODO: عرض تفاصيل العرض
            },
            icon: const Icon(Icons.arrow_forward_ios, size: 16),
          ),
        ],
      ),
    );
  }
}
