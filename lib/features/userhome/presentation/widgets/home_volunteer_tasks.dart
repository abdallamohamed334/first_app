import 'package:flutter/material.dart';

class HomeVolunteerTasks extends StatelessWidget {
  final List<Map<String, dynamic>> tasks;
  final ValueChanged<Map<String, dynamic>> onTaskTap;

  const HomeVolunteerTasks({
    super.key,
    required this.tasks,
    required this.onTaskTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            '❤️ فرص مساعدة قريبة',
            style: TextStyle(
              color: Color(0xFF123F31),
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 170,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            itemCount: tasks.length > 4 ? 4 : tasks.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, index) => _TaskCard(
              task: tasks[index],
              onTap: () => onTaskTap(tasks[index]),
            ),
          ),
        ),
      ],
    );
  }
}

class _TaskCard extends StatelessWidget {
  final Map<String, dynamic> task;
  final VoidCallback onTap;

  const _TaskCard({
    required this.task,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final distance = task['distance'];
    final distanceText = distance is num
        ? distance.toStringAsFixed(1)
        : (distance?.toString() ?? '?');

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 220,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border:
              Border.all(color: const Color(0xFF3679C8).withValues(alpha: 0.2)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF3679C8).withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3679C8).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.delivery_dining_rounded,
                    color: Color(0xFF3679C8),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    task['title']?.toString() ?? 'فرصة توصيل',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF123F31),
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _infoRow(
              Icons.location_on_rounded,
              '📍 الاستلام: ${task['pickup_location'] ?? 'غير محدد'}',
            ),
            _infoRow(
              Icons.location_on_rounded,
              '📍 التسليم: ${task['delivery_location'] ?? 'غير محدد'}',
              color: const Color(0xFF0B7650),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _badge(
                  '📦 ${task['quantity'] ?? 0} وجبة',
                  const Color(0xFF0B7650),
                ),
                const SizedBox(width: 6),
                _badge(
                  '🚗 $distanceText كم',
                  const Color(0xFFB77700),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3679C8),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'أريد التوصيل',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        children: [
          Icon(icon, size: 12, color: color ?? const Color(0xFF71837C)),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color ?? const Color(0xFF71837C),
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
