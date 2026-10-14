import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:loqma/features/userhome/presentation/widgets/home_palette.dart';

class HomeNeedsActionPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool filled;
  final VoidCallback onTap;

  const HomeNeedsActionPill({
    required this.icon,
    required this.label,
    required this.filled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: filled ? Colors.white : Colors.white.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: filled
                ? null
                : Border.all(color: Colors.white.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: filled ? const Color(0xFF3679C8) : Colors.white,
              ),
              SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: filled ? const Color(0xFF3679C8) : Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
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

// ============================================================
// ✅ NEED CARD
// ============================================================
class HomeNeedCard extends StatelessWidget {
  final Map<String, dynamic> need;
  final VoidCallback onTap;

  const HomeNeedCard({
    required this.need,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final title = need['title']?.toString() ?? 'احتياج';
    final category = need['category_name_ar']?.toString() ?? 'عام';
    final city = need['city']?.toString() ?? '';
    final urgency = need['urgency']?.toString() ?? 'normal';
    final quantity = (need['quantity'] as num?)?.toInt() ?? 1;
    final imageUrl = need['image_url']?.toString();

    final urgencyData = _urgencyData(urgency);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 200,
        decoration: BoxDecoration(
          color: HomePalette.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: HomePalette.border, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.22),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 80,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF3679C8), Color(0xFF6651B5)],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
              ),
              child: Stack(
                children: [
                  if (imageUrl != null && imageUrl.isNotEmpty)
                    Positioned.fill(
                      child: CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        memCacheHeight: 240,
                        errorWidget: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ),
                  if (imageUrl != null && imageUrl.isNotEmpty)
                    Positioned.fill(child: Container(color: Colors.black26)),
                  Positioned(
                    left: -20,
                    bottom: -20,
                    child: Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                  ),
                  Positioned(
                    right: -10,
                    top: -15,
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.06),
                      ),
                    ),
                  ),
                  Center(
                    child: Icon(
                      Icons.volunteer_activism_rounded,
                      color: Colors.white,
                      size: 34,
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: urgencyData.$3,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(urgencyData.$1, color: Colors.white, size: 10),
                          SizedBox(width: 3),
                          Text(
                            urgencyData.$2,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: HomePalette.textPrimary,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w900,
                      height: 1.3,
                    ),
                  ),
                  SizedBox(height: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: HomePalette.cardSoft,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.local_offer_rounded,
                            size: 10, color: HomePalette.textSecondary),
                        SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            category,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: HomePalette.textSecondary,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 6),
                  Row(
                    children: [
                      if (city.isNotEmpty) ...[
                        Icon(
                          Icons.location_on_rounded,
                          size: 11,
                          color: HomePalette.textSecondary
                              .withValues(alpha: 0.7),
                        ),
                        SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            city,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: HomePalette.textSecondary,
                              fontSize: 10.5,
                            ),
                          ),
                        ),
                      ],
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFF3679C8).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'الكمية: $quantity',
                          style: TextStyle(
                            color: Color(0xFF3679C8),
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                          ),
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

  (IconData, String, Color) _urgencyData(String urgency) {
    switch (urgency) {
      case 'urgent':
        return (
          Icons.warning_amber_rounded,
          'عاجل جدًا',
          const Color(0xFFB54747)
        );
      case 'high':
        return (Icons.priority_high_rounded, 'مهم', const Color(0xFFE28B00));
      case 'low':
        return (
          Icons.sentiment_satisfied_rounded,
          'عادي',
          const Color(0xFF2E9B5C)
        );
      case 'normal':
      default:
        return (
          Icons.sentiment_neutral_rounded,
          'متوسط',
          const Color(0xFF3679C8)
        );
    }
  }
}

// ============================================================
// ✅ LARGE FOOD CARD — (للأرشيف)
// ============================================================
