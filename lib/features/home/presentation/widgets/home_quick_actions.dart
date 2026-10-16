import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:loqma/core/widgets/page_transition.dart';
import 'package:loqma/features/charity/presentation/pages/charities_page.dart';
import 'package:loqma/features/community/presentation/pages/community_my_requests_page.dart';
import 'package:loqma/routes/app_router.dart';

class HomeQuickActions extends StatelessWidget {
  const HomeQuickActions({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final actions = [
      {'icon': Icons.inbox, 'label': 'طلباتي', 'color': colors.secondary, 'tap': () => Navigator.push(context, PageTransition.slideRightToLeft(const CommunityMyRequestsPage()))},
      {'icon': Icons.volunteer_activism, 'label': 'الجمعيات', 'color': colors.tertiary, 'tap': () => Navigator.push(context, PageTransition.slideRightToLeft(const CharitiesPage()))},
      {'icon': Icons.notifications, 'label': 'الإشعارات', 'color': colors.primary, 'tap': () => context.push(AppRouter.notifications)},
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, childAspectRatio: 1.0, crossAxisSpacing: 8, mainAxisSpacing: 8),
        itemCount: actions.length,
        itemBuilder: (context, index) {
          final action = actions[index];
          final color = action['color'] as Color;
          return GestureDetector(
            onTap: action['tap'] as VoidCallback,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withValues(alpha: 0.1)), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 16, offset: const Offset(0, 4))]),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Container(width: 44, height: 44, decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle), child: Icon(action['icon'] as IconData, color: color, size: 22)),
                const SizedBox(height: 4),
                Text(action['label'] as String, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: colors.onSurface), maxLines: 1, overflow: TextOverflow.ellipsis),
              ]),
            ),
          );
        },
      ),
    );
  }
}
