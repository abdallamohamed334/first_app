// lib/features/community/presentation/pages/community_tracking_page.dart

import 'package:flutter/material.dart';

import 'community_my_requests_page.dart';
import 'community_my_charity_donations_page.dart';
import 'community_my_offers_page.dart';
import 'volunteer_donations_tracking_page.dart';
import 'community_my_grocery_orders_page.dart';

class CommunityTrackingPage extends StatefulWidget {
  const CommunityTrackingPage({super.key});

  @override
  State<CommunityTrackingPage> createState() => _CommunityTrackingPageState();
}

class _CommunityTrackingPageState extends State<CommunityTrackingPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  // ───────── نفس هوية التطبيق ─────────
  static const Color _bg = Color(0xFF0F0F0F);
  static const Color _card = Color(0xFF1C1C1E);
  static const Color _cardSoft = Color(0xFF2C2C2E);
  static const Color _primaryRed = Color(0xFFE31C25);
  static const Color _primaryRedDark = Color(0xFF8E0F14);
  static const Color _textPrimary = Colors.white;
  static const Color _textSecondary = Color(0xFFAAAAAA);
  static const Color _border = Color(0x14FFFFFF);

  static const List<_TrackingTab> _tabs = [
    _TrackingTab(
      label: 'طلباتي',
      icon: Icons.shopping_bag_rounded,
      outlinedIcon: Icons.shopping_bag_outlined,
    ),
    _TrackingTab(
      label: 'تبرعاتي',
      icon: Icons.volunteer_activism_rounded,
      outlinedIcon: Icons.volunteer_activism_outlined,
    ),
    _TrackingTab(
      label: 'توصيلي',
      icon: Icons.delivery_dining_rounded,
      outlinedIcon: Icons.delivery_dining_outlined,
    ),
    _TrackingTab(
      label: 'طلبات البقالة',
      icon: Icons.storefront_rounded,
      outlinedIcon: Icons.storefront_outlined,
    ),
    _TrackingTab(
      label: 'عروضي',
      icon: Icons.campaign_rounded,
      outlinedIcon: Icons.campaign_outlined,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Theme(
        data: ThemeData.dark().copyWith(
          scaffoldBackgroundColor: _bg,
          colorScheme: const ColorScheme.dark(
            primary: _primaryRed,
            surface: _bg,
            onSurface: _textPrimary,
          ),
        ),
        child: Scaffold(
          backgroundColor: _bg,
          appBar: _buildAppBar(),
          body: TabBarView(
            controller: _tabController,
            physics: const BouncingScrollPhysics(),
            children: const [
              CommunityMyRequestsPage(),
              CommunityMyCharityDonationsPage(),
              VolunteerDonationsTrackingPage(),
              CommunityMyGroceryOrdersPage(),
              CommunityMyOffersPage(),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // ✅ AppBar حديث
  // ═══════════════════════════════════════════════════════════
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: _bg,
      surfaceTintColor: _bg,
      elevation: 0,
      centerTitle: false,
      automaticallyImplyLeading: false,
      titleSpacing: 20,
      title: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_primaryRed, _primaryRedDark],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: _primaryRed.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.receipt_long_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'متابعة الطلبات',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  color: _textPrimary,
                  height: 1.1,
                ),
              ),
              SizedBox(height: 3),
              Text(
                'كل حاجة بتعملها في مكان واحد',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(66),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          child: SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: _tabs.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                return _buildTabChip(index);
              },
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // ✅ Tab Chip — Pill style حديث
  // ═══════════════════════════════════════════════════════════
  Widget _buildTabChip(int index) {
    return AnimatedBuilder(
      animation: _tabController,
      builder: (context, _) {
        // نسبة الاختيار (0 = مش مختار، 1 = مختار)
        double t = _tabController.index == index ? 1.0 : 0.0;
        if (_tabController.indexIsChanging) {
          final animationValue = _tabController.animation?.value ?? 0;
          final distance = (animationValue - index).abs();
          t = (1 - distance).clamp(0.0, 1.0);
        }

        final selected = _tabController.index == index;
        final tab = _tabs[index];

        return GestureDetector(
          onTap: () => _tabController.animateTo(index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              gradient: selected
                  ? const LinearGradient(
                      colors: [_primaryRed, _primaryRedDark],
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                    )
                  : null,
              color: selected ? null : _card,
              borderRadius: BorderRadius.circular(100),
              border: Border.all(
                color: selected ? Colors.transparent : _border,
                width: 1,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: _primaryRed.withValues(alpha: 0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  selected ? tab.icon : tab.outlinedIcon,
                  size: 16,
                  color: selected ? Colors.white : _textSecondary,
                ),
                const SizedBox(width: 7),
                Text(
                  tab.label,
                  style: TextStyle(
                    color: selected ? Colors.white : _textPrimary,
                    fontSize: 12.5,
                    fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════
// ✅ Tracking Tab Model
// ═══════════════════════════════════════════════════════════
class _TrackingTab {
  final String label;
  final IconData icon;
  final IconData outlinedIcon;

  const _TrackingTab({
    required this.label,
    required this.icon,
    required this.outlinedIcon,
  });
}
