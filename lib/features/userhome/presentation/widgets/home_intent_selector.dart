// lib/features/home/presentation/widgets/home_intent_selector.dart

import 'package:flutter/material.dart';

class HomeIntentSelector extends StatelessWidget {
  final String selectedIntent;
  final ValueChanged<String> onIntentSelected;

  const HomeIntentSelector({
    super.key,
    required this.selectedIntent,
    required this.onIntentSelected,
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
            'ماذا تريد أن تفعل اليوم؟',
            style: TextStyle(
              color: colors.onSurface,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _IntentCard(
                  id: 'buy',
                  icon: Icons.shopping_bag_rounded,
                  title: 'أشتري',
                  subtitle: 'فائض بسعر رمزي',
                  color: colors.primary,
                  isSelected: selectedIntent == 'buy',
                  onTap: onIntentSelected,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _IntentCard(
                  id: 'sell',
                  icon: Icons.attach_money_rounded,
                  title: 'أبيع',
                  subtitle: 'فائض عندي',
                  color: const Color(0xFFE28B00),
                  isSelected: selectedIntent == 'sell',
                  onTap: onIntentSelected,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _IntentCard(
                  id: 'donate',
                  icon: Icons.volunteer_activism_rounded,
                  title: 'أتبرع',
                  subtitle: 'بفائض لجمعية',
                  color: const Color(0xFF8A5BB7),
                  isSelected: selectedIntent == 'donate',
                  onTap: onIntentSelected,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _IntentCard(
                  id: 'volunteer',
                  icon: Icons.delivery_dining_rounded,
                  title: 'أتطوع',
                  subtitle: 'أوصل تبرع',
                  color: const Color(0xFF3679C8),
                  isSelected: selectedIntent == 'volunteer',
                  onTap: onIntentSelected,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _IntentCard extends StatelessWidget {
  final String id;
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final bool isSelected;
  final ValueChanged<String> onTap;

  const _IntentCard({
    required this.id,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => onTap(id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? color
              : isDark
                  ? const Color(0xFF1F1F1F)
                  : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? color : colors.outlineVariant,
            width: isSelected ? 2 : 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withAlpha(30),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: (isSelected ? Colors.white : color).withAlpha(25),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isSelected ? Colors.white : color,
                size: 18,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isSelected ? Colors.white : color,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: isSelected
                          ? Colors.white.withAlpha(200)
                          : colors.onSurfaceVariant,
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
