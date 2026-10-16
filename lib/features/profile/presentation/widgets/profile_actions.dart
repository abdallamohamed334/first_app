import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:loqma/routes/app_router.dart';

class ProfileActions extends StatelessWidget {
  const ProfileActions({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final actions = [
      (Icons.notifications, 'الإشعارات', AppRouter.notifications),
      (Icons.support_agent, 'الدعم والتواصل', AppRouter.support),
      (Icons.privacy_tip_outlined, 'الخصوصية', AppRouter.privacy),
      (Icons.description_outlined, 'الشروط', AppRouter.terms),
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.3))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('روابط مهمة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: colors.onSurface)),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, childAspectRatio: 1.2, crossAxisSpacing: 8),
          itemCount: actions.length,
          itemBuilder: (context, index) => InkWell(
            onTap: () => context.push(actions[index].$3),
            borderRadius: BorderRadius.circular(12),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(actions[index].$1, color: colors.primary, size: 28),
              const SizedBox(height: 4),
              Text(actions[index].$2, style: TextStyle(fontSize: 11, color: colors.onSurface), textAlign: TextAlign.center),
            ]),
          ),
        ),
      ]),
    );
  }
}
