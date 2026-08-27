// lib/features/business/presentation/widgets/dashboard_stats.dart

import 'package:flutter/material.dart';

class DashboardStats extends StatelessWidget {
  final int activeOffers;
  final int pendingRequests;
  final int completedRequests;
  final double rating;

  const DashboardStats({
    super.key,
    required this.activeOffers,
    required this.pendingRequests,
    required this.completedRequests,
    required this.rating,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _buildStatCard(
            context,
            icon: Icons.food_bank,
            label: 'عروض نشطة',
            value: '$activeOffers',
            color: colorScheme.primary,
          ),
          const SizedBox(width: 10),
          _buildStatCard(
            context,
            icon: Icons.request_page,
            label: 'طلبات معلقة',
            value: '$pendingRequests',
            color: Colors.orange,
          ),
          const SizedBox(width: 10),
          _buildStatCard(
            context,
            icon: Icons.check_circle,
            label: 'مكتمل',
            value: '$completedRequests',
            color: Colors.green,
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: colorScheme.outlineVariant.withAlpha(51),
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
