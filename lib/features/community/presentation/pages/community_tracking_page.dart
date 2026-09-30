import 'package:flutter/material.dart';

import 'package:loqma/features/swap/presentation/pages/swap_pages.dart';
import 'my_community_needs_page.dart';
import 'community_my_charity_donations_page.dart';
import 'community_my_offers_page.dart';
import 'community_my_grocery_orders_page.dart';

class CommunityTrackingPage extends StatefulWidget {
  const CommunityTrackingPage({super.key});
  @override State<CommunityTrackingPage> createState() => _CommunityTrackingPageState();
}

class _CommunityTrackingPageState extends State<CommunityTrackingPage> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  static const _tabs = [
    (label: 'احتياجاتي', icon: Icons.volunteer_activism_rounded),
    (label: 'تبرعاتي', icon: Icons.favorite_rounded),
    (label: 'طلبات البقالة والفنادق', icon: Icons.storefront_rounded),
    (label: 'عروضي', icon: Icons.campaign_rounded),
    (label: 'استبدالاتي', icon: Icons.swap_horizontal_circle_rounded),
  ];

  @override
  void initState() { super.initState(); _tabController = TabController(length: _tabs.length, vsync: this); }
  @override
  void dispose() { _tabController.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('طلباتي', style: TextStyle(fontWeight: FontWeight.w900)),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(58),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _tabs.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) => AnimatedBuilder(
                    animation: _tabController,
                    builder: (_, __) {
                      final selected = _tabController.index == index;
                      return GestureDetector(
                        onTap: () => _tabController.animateTo(index),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: selected ? colors.primary : colors.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(_tabs[index].icon, size: 16, color: selected ? colors.onPrimary : colors.onSurfaceVariant),
                            const SizedBox(width: 6),
                            Text(_tabs[index].label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: selected ? colors.onPrimary : colors.onSurfaceVariant)),
                          ]),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          physics: const BouncingScrollPhysics(),
          children: const [
            MyCommunityNeedsPage(embedded: true),
            CommunityMyCharityDonationsPage(),
            CommunityMyGroceryOrdersPage(),
            CommunityMyOffersPage(),
            MySwapsPage(),
          ],
        ),
      ),
    );
  }
}
