import 'package:flutter/material.dart';

class HomeMissionTimeline extends StatelessWidget {
  const HomeMissionTimeline({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final steps = [
      {'icon': Icons.restaurant, 'label': 'المطعم'},
      {'icon': Icons.directions_run, 'label': 'المتطوع'},
      {'icon': Icons.volunteer_activism, 'label': 'الجمعية'},
      {'icon': Icons.family_restroom, 'label': 'الأسر'},
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 24,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Text(
              'كيف تسير المهمة',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: steps.map((step) {
                final index = steps.indexOf(step);
                final isFirst = index == 0;
                final isLast = index == steps.length - 1;

                return Expanded(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          if (!isFirst)
                            Expanded(
                              child: Container(
                                height: 2,
                                color: index <= 1
                                    ? colorScheme.primary
                                    : colorScheme.surfaceContainerHigh,
                              ),
                            ),
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: index <= 1
                                  ? colorScheme.primary
                                  : colorScheme.surfaceContainerHigh,
                              border: Border.all(
                                color: index <= 1
                                    ? colorScheme.primary
                                    : colorScheme.outlineVariant,
                                width: 2,
                              ),
                            ),
                            child: Icon(
                              step['icon'] as IconData,
                              size: 20,
                              color: index <= 1
                                  ? Colors.white
                                  : colorScheme.onSurfaceVariant,
                            ),
                          ),
                          if (!isLast)
                            Expanded(
                              child: Container(
                                height: 2,
                                color: index < 1
                                    ? colorScheme.primary
                                    : colorScheme.surfaceContainerHigh,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        step['label'] as String,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: index <= 1
                              ? colorScheme.primary
                              : colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
