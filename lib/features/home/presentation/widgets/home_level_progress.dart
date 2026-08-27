// lib/features/home/presentation/widgets/home_level_progress.dart

import 'package:flutter/material.dart';
import 'package:loqma/core/models/user_model.dart';

class HomeLevelProgress extends StatelessWidget {
  final UserModel user;
  final UserStats stats;

  const HomeLevelProgress({
    super.key,
    required this.user,
    required this.stats,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // ✅ حساب التقدم (نقاط / 500)
    final progress = (stats.points / 500).clamp(0.0, 1.0);

    // ✅ تحديد المستوى التالي
    final nextLevel = user.level + 1;
    final pointsToNextLevel = 500 - (stats.points % 500);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: colorScheme.outlineVariant.withAlpha(76),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(10),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ✅ العنوان مع أيقونة
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.amber.shade400,
                            Colors.amber.shade700,
                          ],
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.workspace_premium,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'مستوى ${user.level}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        Text(
                          _getLevelTitle(user.level),
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                // ✅ النقاط
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withAlpha(25),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.star,
                        size: 16,
                        color: Colors.amber,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${stats.points}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                        ),
                      ),
                      Text(
                        ' نقطة',
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // ✅ شريط التقدم
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'التقدم إلى المستوى $nextLevel',
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      '${(progress * 100).toInt()}%',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: colorScheme.surfaceContainerHigh,
                    color: colorScheme.primary,
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$pointsToNextLevel نقطة للوصول إلى المستوى $nextLevel',
                  style: TextStyle(
                    fontSize: 11,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // ✅ الشارات الصغيرة
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildBadge(
                  icon: Icons.emoji_events,
                  label: '${user.level} مستويات',
                  color: Colors.amber,
                  colorScheme: colorScheme,
                ),
                _buildBadge(
                  icon: Icons.restaurant_menu,
                  label: '${stats.mealsSaved} وجبة',
                  color: colorScheme.primary,
                  colorScheme: colorScheme,
                ),
                _buildBadge(
                  icon: Icons.task_alt,
                  label: '${stats.tasksCompleted} مهمة',
                  color: colorScheme.secondary,
                  colorScheme: colorScheme,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getLevelTitle(int level) {
    if (level >= 10) return '🦸 بطل خارق';
    if (level >= 7) return '🌟 نجم التطوع';
    if (level >= 5) return '💪 منقذ طعام';
    if (level >= 3) return '🤝 متطوع نشط';
    if (level >= 1) return '🌱 متطوع مبتدئ';
    return '🌱 متطوع مبتدئ';
  }

  Widget _buildBadge({
    required IconData icon,
    required String label,
    required Color color,
    required ColorScheme colorScheme,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: color,
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
