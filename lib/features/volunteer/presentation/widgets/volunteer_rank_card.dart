import 'package:flutter/material.dart';
import '../models/volunteer_model.dart';

class VolunteerRankCard extends StatelessWidget {
  final UserRankInfo userRank; // ✅ UserRankInfo

  const VolunteerRankCard({super.key, required this.userRank});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final badgeDisplay = _getBadgeDisplay(userRank.badge);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.primary.withAlpha(51),
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withAlpha(20),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // ✅ Rank
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.emoji_events,
                color: Colors.amber,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'ترتيبك الحالي',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '#${userRank.currentRank}',
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withAlpha(25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  badgeDisplay,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
          Text(
            'من أصل ${userRank.totalVolunteers} متطوع',
            style: TextStyle(
              fontSize: 14,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          // ✅ Stats
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                icon: Icons.star,
                label: 'نقاط',
                value: '${userRank.points}',
                color: Colors.amber,
                colorScheme: colorScheme,
              ),
              _buildStatItem(
                icon: Icons.food_bank,
                label: 'وجبات',
                value: '${userRank.mealsSaved}',
                color: colorScheme.primary,
                colorScheme: colorScheme,
              ),
              _buildStatItem(
                icon: Icons.delivery_dining,
                label: 'توصيلات',
                value: '${userRank.completedDeliveries}',
                color: Colors.blue,
                colorScheme: colorScheme,
              ),
              _buildStatItem(
                icon: Icons.request_page,
                label: 'طلبات',
                value: '${userRank.completedRequests}',
                color: Colors.purple,
                colorScheme: colorScheme,
              ),
            ],
          ),
          const SizedBox(height: 16),
          // ✅ Progress to next rank
          if (userRank.pointsToNextRank > 0) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'تبعد ${userRank.pointsToNextRank} نقطة عن المركز ${userRank.nextRankPosition}',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  '${(userRank.progress * 100).toInt()}%',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: userRank.progress.clamp(0.0, 1.0),
                backgroundColor: colorScheme.surfaceContainerHigh,
                color: colorScheme.primary,
                minHeight: 6,
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: Colors.green.withAlpha(25),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.celebration,
                    color: Colors.green,
                    size: 18,
                  ),
                  SizedBox(width: 8),
                  Text(
                    '🎉 أنت في اجُود! استمر في التطوع',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ),
          ],
          // ✅ Level info
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.emoji_events,
                size: 14,
                color: Colors.amber,
              ),
              const SizedBox(width: 4),
              Text(
                'المستوى ${userRank.level}',
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getBadgeDisplay(String badge) {
    switch (badge) {
      case 'beginner':
        return '🥉 مبتدئ';
      case 'silver':
        return '🥈 نشيط';
      case 'gold':
        return '🥇 بطل إنقاذ';
      case 'platinum':
        return '💎 أسطورة الإنقاذ';
      case 'diamond':
        return '👑 ملك الإنقاذ';
      default:
        return '🥉 مبتدئ';
    }
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required ColorScheme colorScheme,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
