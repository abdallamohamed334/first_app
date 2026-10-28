import 'package:flutter/material.dart';

class ProfileStats extends StatelessWidget {
  final String memberSince;

  const ProfileStats({
    super.key,
    required this.memberSince,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outlineVariant.withAlpha(90)),
      ),
      child: Row(
        children: [
          Icon(Icons.calendar_month_rounded, color: colors.primary, size: 20),
          const SizedBox(width: 9),
          Text(
            'عضو في خدمة منذ $memberSince',
            style: TextStyle(
              color: colors.onSurfaceVariant,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
