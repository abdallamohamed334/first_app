import 'package:flutter/material.dart';

import 'community_my_requests_page.dart';
import 'community_my_charity_donations_page.dart';
import 'community_owner_requests_page.dart';

class CommunityTrackingPage extends StatelessWidget {
  const CommunityTrackingPage({super.key});

  static const _green = Color(0xFF0B7650);
  static const _darkGreen = Color(0xFF123F31);
  static const _background = Color(0xFFF6FAF8);

  void _open(BuildContext context, Widget page) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => page),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _background,
        appBar: AppBar(
          title: const Text('متابعة الطلبات'),
          centerTitle: true,
          backgroundColor: _background,
          foregroundColor: _darkGreen,
          elevation: 0,
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0B7650), Color(0xFF2BAA76)],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
                borderRadius: BorderRadius.circular(26),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x220B7650),
                    blurRadius: 18,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: const Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'كل طلباتك في مكان واحد',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'تابع الطلبات التي قدمتها، وتبرعاتك للجمعيات، والطلبات الواردة على عروضك.',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 14),
                  Icon(Icons.track_changes_rounded,
                      color: Colors.white, size: 44),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _TrackingCard(
              icon: Icons.shopping_bag_outlined,
              color: const Color(0xFF2F6DA5),
              title: 'الطلبات التي قدمتها',
              subtitle:
                  'اعرف حالة طلبات الملابس والأثاث، واعرض كود الاستلام عند الجاهزية.',
              onTap: () => _open(context, const CommunityMyRequestsPage()),
            ),
            const SizedBox(height: 14),
            _TrackingCard(
              icon: Icons.volunteer_activism_rounded,
              color: const Color(0xFF8A5BB7),
              title: 'تبرعاتي للجمعيات',
              subtitle:
                  'تابع الجمعيات التي اخترتها، وموعد التبرع، وحالة استلام التبرع.',
              onTap: () =>
                  _open(context, const CommunityMyCharityDonationsPage()),
            ),
            const SizedBox(height: 14),
            _TrackingCard(
              icon: Icons.campaign_outlined,
              color: _green,
              title: 'العروض التي نشرتها',
              subtitle:
                  'شاهد طلبات عروضك، افتح تفاصيلها، واقبل أو ارفض ثم جهّز الطلب للتسليم.',
              onTap: () => _open(context, const CommunityOwnerRequestsPage()),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrackingCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _TrackingCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFDCEBE3)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A123F31),
                blurRadius: 12,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF123F31),
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFF71837C),
                        fontSize: 12,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Padding(
                padding: EdgeInsets.only(top: 18),
                child: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 17,
                  color: Color(0xFF71837C),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
