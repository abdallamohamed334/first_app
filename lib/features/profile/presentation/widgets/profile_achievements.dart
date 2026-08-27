import 'package:flutter/material.dart';

class ProfileAchievements extends StatelessWidget {
  final List<String> achievements;

  const ProfileAchievements({
    super.key,
    required this.achievements,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final visible =
        achievements.isEmpty ? ['ابدأ رحلتك في إنقاذ الطعام'] : achievements;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'إنجازاتك',
          style: TextStyle(
            color: colors.onSurface,
            fontSize: 17,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 132,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: visible.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              return _AchievementCard(
                title: visible[index],
                index: index,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _AchievementCard extends StatelessWidget {
  final String title;
  final int index;

  const _AchievementCard({required this.title, required this.index});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final accent = [
      Colors.orange,
      colors.primary,
      Colors.blue,
      Colors.purple,
    ][index % 4];

    return Container(
      width: 150,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withAlpha(75)),
        boxShadow: [
          BoxShadow(
            color: accent.withAlpha(18),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 47,
            height: 47,
            decoration: BoxDecoration(
              color: accent.withAlpha(25),
              shape: BoxShape.circle,
            ),
            child: Icon(
              index == 0 ? Icons.emoji_events_rounded : Icons.stars_rounded,
              color: accent,
              size: 26,
            ),
          ),
          const SizedBox(height: 9),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.onSurface,
              fontSize: 11,
              height: 1.25,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
