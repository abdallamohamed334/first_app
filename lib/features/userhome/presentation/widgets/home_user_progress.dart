// lib/features/home/presentation/widgets/home_user_progress.dart

import 'package:flutter/material.dart';
import 'package:loqma/core/models/user_model.dart';

class HomeUserProgressCard extends StatelessWidget {
  final UserModel user;
  final UserStats stats;

  const HomeUserProgressCard({
    super.key,
    required this.user,
    required this.stats,
  });

  @override
  Widget build(BuildContext context) {
    // ألوان الهوم
    const green = Color(0xFF0B7650);
    const darkGreen = Color(0xFF123F31);
    const lightGreenBg = Color(0xFFE7F6EE);

    // ✅ حساب التقدم (نقاط / 500)
    final progress = (stats.points / 500).clamp(0.0, 1.0);

    // ✅ تحديد المستوى التالي
    final nextLevel = user.level + 1;
    final pointsToNextLevel = 500 - (stats.points % 500);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFDCEBE3)),
          boxShadow: [
            BoxShadow(
              color: green.withAlpha(15),
              blurRadius: 15,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ✅ العنوان + النقاط
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    // أيقونة المستوى بتدرج أخضر جميل
                    Container(
                      width: 42,
                      height: 42,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF0B7650), Color(0xFF12A36C)],
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.workspace_premium,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'مستوى ${user.level}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: darkGreen,
                          ),
                        ),
                        Text(
                          _getLevelTitle(user.level),
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF71837C),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                // حاوية النقاط
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: lightGreenBg,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.star, size: 15, color: Colors.amber),
                      const SizedBox(width: 4),
                      Text(
                        '${stats.points}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: green,
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Text(
                        'نقطة',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF71837C),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // ✅ شريط التقدم
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'التقدم إلى المستوى $nextLevel',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF71837C),
                      ),
                    ),
                    Text(
                      '${(progress * 100).toInt()}%',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: green,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: const Color(0xFFE7F0EB),
                    color: green,
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'باقي $pointsToNextLevel نقطة للوصول للمستوى $nextLevel',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF71837C),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // ✅ الشارات المصغرة
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildBadge(
                  icon: Icons.emoji_events,
                  label: '${user.level} مستويات',
                  color: Colors.amber,
                ),
                _buildBadge(
                  icon: Icons.restaurant_menu,
                  label: '${stats.mealsSaved} وجبة',
                  color: green,
                ),
                _buildBadge(
                  icon: Icons.task_alt,
                  label: '${stats.tasksCompleted} مهمة',
                  color: const Color(0xFF1976D2), // أزرق جميل
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
  }) {
    return Row(
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Color(0xFF123F31),
          ),
        ),
      ],
    );
  }
}
