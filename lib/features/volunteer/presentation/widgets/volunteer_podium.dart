import 'package:flutter/material.dart';
import '../models/volunteer_model.dart';

class VolunteerPodium extends StatelessWidget {
  final VolunteerModel? top1;
  final VolunteerModel? top2;
  final VolunteerModel? top3;

  const VolunteerPodium({
    super.key,
    this.top1,
    this.top2,
    this.top3,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            colorScheme.primary.withAlpha(20),
            Colors.transparent,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          // ✅ Title
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.emoji_events, color: Colors.amber),
              const SizedBox(width: 8),
              Text(
                'أفضل المتطوعين',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'ساهم معنا في إنقاذ الطعام وتصدر قائمة الأبطال',
            style: TextStyle(
              fontSize: 14,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          // ✅ Podium
          if (top1 != null || top2 != null || top3 != null)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // ✅ المركز الثاني
                if (top2 != null)
                  _buildPodiumItem(
                    context,
                    volunteer: top2!,
                    rank: 2,
                    height: 120,
                    color: Colors.grey.shade400,
                    colorScheme: colorScheme,
                  ),
                // ✅ المركز الأول
                if (top1 != null)
                  _buildPodiumItem(
                    context,
                    volunteer: top1!,
                    rank: 1,
                    height: 160,
                    color: Colors.amber,
                    colorScheme: colorScheme,
                  ),
                // ✅ المركز الثالث
                if (top3 != null)
                  _buildPodiumItem(
                    context,
                    volunteer: top3!,
                    rank: 3,
                    height: 100,
                    color: Colors.brown.shade300,
                    colorScheme: colorScheme,
                  ),
              ],
            ),
          if (top1 == null && top2 == null && top3 == null)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(
                    Icons.emoji_events_outlined,
                    size: 64,
                    color: colorScheme.outline.withAlpha(128),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'لا يوجد متطوعين حتى الآن',
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    'كن أول متطوع!',
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
    );
  }

  Widget _buildPodiumItem(
    BuildContext context, {
    required VolunteerModel volunteer,
    required int rank,
    required double height,
    required Color color,
    required ColorScheme colorScheme,
  }) {
    final medals = {
      1: '🥇',
      2: '🥈',
      3: '🥉',
    };

    return SizedBox(
      width: 100,
      child: Column(
        children: [
          // ✅ Rank Emoji
          Text(
            medals[rank] ?? '🏅',
            style: const TextStyle(fontSize: 32),
          ),
          const SizedBox(height: 4),
          // ✅ Avatar
          CircleAvatar(
            radius: 28,
            backgroundImage: volunteer.avatarUrl != null
                ? NetworkImage(volunteer.avatarUrl!)
                : null,
            backgroundColor: colorScheme.primary.withAlpha(25),
            child: volunteer.avatarUrl == null
                ? Text(
                    volunteer.name[0].toUpperCase(),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                  )
                : null,
          ),
          const SizedBox(height: 4),
          // ✅ Name
          Text(
            volunteer.name,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          // ✅ Points
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.star,
                size: 14,
                color: Colors.amber,
              ),
              const SizedBox(width: 2),
              Text(
                '${volunteer.points}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
          // ✅ Podium
          Container(
            width: 60,
            height: height,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  color.withAlpha(76),
                  color.withAlpha(153),
                ],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                '#$rank',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
