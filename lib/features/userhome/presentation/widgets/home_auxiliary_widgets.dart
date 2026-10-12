import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:loqma/features/services/domain/entities/service_provider.dart';
import 'package:loqma/features/userhome/presentation/widgets/home_palette.dart';

class HomeAddActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color color;

  const HomeAddActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: HomePalette.cardSoft,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: HomePalette.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: HomePalette.textSecondary,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_left_rounded,
                color: HomePalette.textSecondary, size: 24),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// ✅ BOTTOM NAV ITEM
// ============================================================
class HomeBottomNavItem extends StatelessWidget {
  final int index;
  final int currentIndex;
  final IconData icon;
  final IconData outlinedIcon;
  final String label;
  final ValueChanged<int> onTap;

  const HomeBottomNavItem({
    required this.index,
    required this.currentIndex,
    required this.icon,
    required this.outlinedIcon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final selected = index == currentIndex;
    final selectedForeground = HomePalette.isDark
        ? Colors.black
        : Colors.white;

    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(index),
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: selected
                      ? HomePalette.primaryRed
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  selected ? icon : outlinedIcon,
                  size: 20,
                  color: selected
                      ? selectedForeground
                      : HomePalette.textSecondary,
                ),
              ),
              const SizedBox(height: 3),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                style: TextStyle(
                  color: selected
                      ? HomePalette.primaryRed
                      : HomePalette.textSecondary,
                  fontSize: 9.5,
                  fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
                ),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HomeNearbySymbolicProviderCard extends StatelessWidget {
  final ServiceProvider provider;
  final double distanceKm;
  final VoidCallback onTap;

  const HomeNearbySymbolicProviderCard({
    required this.provider,
    required this.distanceKm,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = provider.profileImageUrl;
    final distanceLabel = distanceKm < 1
        ? '${(distanceKm * 1000).round()} متر'
        : '${distanceKm.toStringAsFixed(1)} كم';

    return SizedBox(
      width: 218,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          decoration: BoxDecoration(
            color: HomePalette.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: HomePalette.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
                child: SizedBox(
                  height: 102,
                  child: imageUrl == null || imageUrl.isEmpty
                      ? Container(
                          color: HomePalette.cardSoft,
                          child: Icon(
                            Icons.handyman_rounded,
                            color: HomePalette.primaryRed,
                            size: 42,
                          ),
                        )
                      : CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Container(
                            color: HomePalette.cardSoft,
                            child: Icon(
                              Icons.handyman_rounded,
                              color: HomePalette.primaryRed,
                              size: 42,
                            ),
                          ),
                        ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      provider.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: HomePalette.textPrimary,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      provider.categoryName ?? 'خدمات متنوعة',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: HomePalette.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    SizedBox(height: 9),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_rounded,
                          color: HomePalette.primaryRed,
                          size: 15,
                        ),
                        SizedBox(width: 3),
                        Text(
                          distanceLabel,
                          style: TextStyle(
                            color: HomePalette.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        Icon(Icons.star_rounded,
                            color: Color(0xFFFFC107), size: 15),
                        SizedBox(width: 2),
                        Text(
                          provider.ratingAvg > 0
                              ? provider.ratingAvg.toStringAsFixed(1)
                              : 'جديد',
                          style: TextStyle(
                            color: HomePalette.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 9),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: HomePalette.primaryRed
                            .withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        provider.pricingLabel,
                        style: TextStyle(
                          color: HomePalette.primaryRed,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// LOADING
// ============================================================
class HomeLoading extends StatelessWidget {
  const HomeLoading();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HomePalette.bg,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    HomePalette.primaryRed,
                    HomePalette.primaryRedDark,
                  ],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color:
                        HomePalette.primaryRed.withValues(alpha: 0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                Icons.volunteer_activism_rounded,
                color: Colors.white,
                size: 34,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: HomePalette.primaryRed,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Khedma بتحضرلك الخير...',
              style: TextStyle(
                color: HomePalette.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
