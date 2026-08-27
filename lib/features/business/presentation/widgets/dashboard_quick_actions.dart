// lib/features/business/presentation/widgets/dashboard_quick_actions.dart

import 'package:flutter/material.dart';

class DashboardQuickActions extends StatelessWidget {
  final List<String> capabilities;
  final String businessId;

  const DashboardQuickActions({
    super.key,
    required this.capabilities,
    required this.businessId,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final actions = <QuickAction>[];

    if (capabilities.contains('create_food_offers')) {
      actions.add(
        QuickAction(
          icon: Icons.add_circle,
          label: 'إنشاء عرض',
          color: colorScheme.primary,
          onTap: () {
            // TODO: التنقل لصفحة إنشاء عرض
          },
        ),
      );
    }

    if (capabilities.contains('manage_requests')) {
      actions.add(
        QuickAction(
          icon: Icons.request_page,
          label: 'الطلبات',
          color: Colors.orange,
          onTap: () {
            // TODO: التنقل لصفحة الطلبات
          },
        ),
      );
    }

    if (capabilities.contains('scan_pickup_qr')) {
      actions.add(
        QuickAction(
          icon: Icons.qr_code_scanner,
          label: 'مسح QR',
          color: Colors.green,
          onTap: () {
            // TODO: فتح Scanner
          },
        ),
      );
    }

    if (capabilities.contains('analytics')) {
      actions.add(
        QuickAction(
          icon: Icons.bar_chart,
          label: 'إحصائيات',
          color: Colors.blue,
          onTap: () {
            // TODO: التنقل لصفحة الإحصائيات
          },
        ),
      );
    }

    if (capabilities.contains('manage_products')) {
      actions.add(
        QuickAction(
          icon: Icons.inventory_2,
          label: 'المنتجات',
          color: Colors.purple,
          onTap: () {
            // TODO: التنقل لصفحة المنتجات
          },
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: actions.map((action) {
          return _buildActionButton(context, action, colorScheme);
        }).toList(),
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    QuickAction action,
    ColorScheme colorScheme,
  ) {
    return InkWell(
      onTap: action.onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: (MediaQuery.of(context).size.width - 56) / 3,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: colorScheme.outlineVariant.withAlpha(51),
          ),
        ),
        child: Column(
          children: [
            Icon(action.icon, color: action.color, size: 28),
            const SizedBox(height: 4),
            Text(
              action.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class QuickAction {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
}
