import 'package:flutter/material.dart';
import '../../../offers/domain/entities/food_offer.dart';

class MapOfferCard extends StatelessWidget {
  final FoodOffer offer;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onShowDetails;
  final double? userLatitude;
  final double? userLongitude;

  const MapOfferCard({
    super.key,
    required this.offer,
    required this.isSelected,
    required this.onTap,
    required this.onShowDetails,
    this.userLatitude,
    this.userLongitude,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasImage = offer.image != null && offer.image!.trim().isNotEmpty;
    final urgent = offer.isUrgent && !offer.isExpired;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isSelected
                  ? colorScheme.primary.withAlpha(20)
                  : colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected
                    ? colorScheme.primary
                    : urgent
                        ? Colors.orange.withAlpha(150)
                        : colorScheme.outlineVariant.withAlpha(110),
                width: isSelected ? 1.8 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: isSelected
                      ? colorScheme.primary.withAlpha(35)
                      : Colors.black.withAlpha(12),
                  blurRadius: isSelected ? 16 : 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _OfferImage(
                  imageUrl: hasImage ? offer.image : null,
                  urgent: urgent,
                  colorScheme: colorScheme,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              offer.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: colorScheme.onSurface,
                                fontSize: 15,
                                height: 1.25,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          if (urgent) ...[
                            const SizedBox(width: 6),
                            _StatusPill(
                              text: 'عاجل',
                              icon: Icons.bolt_rounded,
                              foreground: Colors.deepOrange,
                              background: Colors.orange.withAlpha(30),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      _InfoLine(
                        icon: Icons.storefront_rounded,
                        text: offer.businessName,
                        color: colorScheme.primary,
                        bold: true,
                      ),
                      const SizedBox(height: 4),
                      _InfoLine(
                        icon: Icons.location_on_outlined,
                        text: offer.displayLocation,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 7),
                      Wrap(
                        spacing: 6,
                        runSpacing: 5,
                        children: [
                          _StatusPill(
                            text: offer.isExpired ? 'منتهٍ' : 'متاح',
                            icon: offer.isExpired
                                ? Icons.block_rounded
                                : Icons.check_circle_rounded,
                            foreground: offer.isExpired
                                ? Colors.grey.shade700
                                : Colors.green.shade700,
                            background: offer.isExpired
                                ? Colors.grey.withAlpha(22)
                                : Colors.green.withAlpha(24),
                          ),
                          _StatusPill(
                            text: '${offer.quantity} وجبة',
                            icon: Icons.restaurant_rounded,
                            foreground: colorScheme.primary,
                            background: colorScheme.primary.withAlpha(22),
                          ),
                          _StatusPill(
                            text: offer.isExpired
                                ? 'انتهى العرض'
                                : 'ينتهي خلال ${offer.timeRemaining}',
                            icon: Icons.schedule_rounded,
                            foreground: urgent
                                ? Colors.deepOrange
                                : colorScheme.onSurfaceVariant,
                            background: urgent
                                ? Colors.orange.withAlpha(24)
                                : colorScheme.surfaceContainerHighest,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  tooltip: 'عرض التفاصيل',
                  onPressed: onShowDetails,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 36,
                    height: 36,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                  ),
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OfferImage extends StatelessWidget {
  final String? imageUrl;
  final bool urgent;
  final ColorScheme colorScheme;

  const _OfferImage({
    required this.imageUrl,
    required this.urgent,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 68,
      height: 84,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colorScheme.primary.withAlpha(18),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: urgent
              ? Colors.orange.withAlpha(150)
              : colorScheme.primary.withAlpha(30),
        ),
      ),
      child: imageUrl == null
          ? Icon(Icons.restaurant_rounded, color: colorScheme.primary, size: 30)
          : Image.network(
              imageUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Icon(
                Icons.restaurant_rounded,
                color: colorScheme.primary,
                size: 30,
              ),
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colorScheme.primary,
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  final bool bold;

  const _InfoLine({
    required this.icon,
    required this.text,
    required this.color,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            text.isEmpty ? 'مطعم قريب' : text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String text;
  final IconData icon;
  final Color foreground;
  final Color background;

  const _StatusPill({
    required this.text,
    required this.icon,
    required this.foreground,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: foreground),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: foreground,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
