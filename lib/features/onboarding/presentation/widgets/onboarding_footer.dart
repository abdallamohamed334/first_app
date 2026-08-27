import 'package:flutter/material.dart';

class OnboardingFooter extends StatelessWidget {
  const OnboardingFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildFooterItem(
              context,
              icon: Icons.eco,
              label: 'بيئة أفضل',
              color: colorScheme.secondary,
            ),
            const SizedBox(width: 24),
            _buildFooterItem(
              context,
              icon: Icons.group,
              label: 'مجتمع مترابط',
              color: colorScheme.primary,
            ),
            const SizedBox(width: 24),
            _buildFooterItem(
              context,
              icon: Icons.bolt,
              label: 'تبرع سريع',
              color: colorScheme.tertiary,
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'انضم لـ +10,000 مستخدم نشط في منطقتك',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: colorScheme.outline,
          ),
        ),
      ],
    );
  }

  Widget _buildFooterItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: color,
            size: 20,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}


