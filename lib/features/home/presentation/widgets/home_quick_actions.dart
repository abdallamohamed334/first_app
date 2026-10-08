import 'package:flutter/material.dart';
import 'package:loqma/core/widgets/page_transition.dart';
import 'package:loqma/features/charity/presentation/pages/charities_page.dart';

class HomeQuickActions extends StatelessWidget {
  const HomeQuickActions({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final actions = [
      {
        'icon': Icons.restaurant_menu,
        'label': 'العروض',
        'color': colorScheme.primary
      },
      {'icon': Icons.inbox, 'label': 'طلباتي', 'color': colorScheme.secondary},
      {
        'icon': Icons.volunteer_activism,
        'label': 'الجمعيات',
        'color': colorScheme.tertiary,
      },
      {
        'icon': Icons.card_giftcard,
        'label': 'المكافآت',
        'color': colorScheme.error
      },
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          childAspectRatio: 1.0,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: actions.length,
        itemBuilder: (context, index) {
          final action = actions[index];
          return _buildQuickAction(
            icon: action['icon'] as IconData,
            label: action['label'] as String,
            color: action['color'] as Color,
            colorScheme: colorScheme,
            context: context,
          );
        },
      ),
    );
  }

  Widget _buildQuickAction({
    required IconData icon,
    required String label,
    required Color color,
    required ColorScheme colorScheme,
    required BuildContext context,
  }) {
    return GestureDetector(
      onTap: () {
        if (label.contains('الجمعيات')) {
          Navigator.push(
            context,
            PageTransition.slideRightToLeft(
              const CharitiesPage(),
            ),
          );
        } else if (label.contains('المكافآت')) {
          // TODO: افتح صفحة المكافآت
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('صفحة المكافآت قيد التطوير'),
              duration: Duration(seconds: 1),
            ),
          );
        } else if (label.contains('الطلبات')) {
          // TODO: افتح صفحة الطلبات
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('صفحة الطلبات قيد التطوير'),
              duration: Duration(seconds: 1),
            ),
          );
        } else if (label.contains('العروض')) {
          // TODO: افتح صفحة العروض
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('صفحة العروض قيد التطوير'),
              duration: Duration(seconds: 1),
            ),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withValues(alpha: 0.1),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: color,
                size: 22,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurface,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
