// lib/features/home/presentation/widgets/home_impact_stats.dart

import 'package:flutter/material.dart';
import 'package:loqma/core/models/community_stats.dart';

class HomeImpactStats extends StatelessWidget {
  final CommunityStats stats;

  const HomeImpactStats({
    super.key,
    required this.stats,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '🌍 أثر مجتمعنا',
            style: TextStyle(
              color: colors.onSurface,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1F1F1F) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.outlineVariant),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.3)
                      : colors.primary.withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: _StatItem(
                    icon: Icons.restaurant_rounded,
                    value: _formatNumber(stats.mealsSaved),
                    label: 'وجبة تم إنقاذها',
                    color: colors.primary,
                  ),
                ),
                Container(
                  width: 1,
                  height: 48,
                  color: colors.outlineVariant,
                ),
                Expanded(
                  child: _StatItem(
                    icon: Icons.volunteer_activism_rounded,
                    value: _formatNumber(stats.activeVolunteers),
                    label: 'متطوع نشط',
                    color: const Color(0xFF3679C8),
                  ),
                ),
                Container(
                  width: 1,
                  height: 48,
                  color: colors.outlineVariant,
                ),
                Expanded(
                  child: _StatItem(
                    icon: Icons.favorite_rounded,
                    value: _formatNumber(stats.beneficiaryCharities),
                    label: 'جمعية مستفيدة',
                    color: const Color(0xFF8A5BB7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    }
    if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatItem({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: colors.onSurfaceVariant,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
