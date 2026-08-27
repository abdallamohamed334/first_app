import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/profile_bloc.dart';
import '../bloc/profile_event.dart';

class ProfileSettings extends StatelessWidget {
  const ProfileSettings({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final settings = [
      {
        'icon': Icons.notifications,
        'label': 'الإشعارات',
        'color': colorScheme.primary,
      },
      {
        'icon': Icons.lock,
        'label': 'الخصوصية والأمان',
        'color': colorScheme.secondary,
      },
      {
        'icon': Icons.language,
        'label': 'اللغة',
        'color': colorScheme.tertiary,
      },
      {
        'icon': Icons.help,
        'label': 'المساعدة والدعم',
        'color': Colors.blue,
      },
      {
        'icon': Icons.info,
        'label': 'عن التطبيق',
        'color': Colors.purple,
      },
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'الإعدادات',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          ...settings.map((setting) {
            final color = setting['color'] as Color;
            return ListTile(
              leading: Icon(
                setting['icon'] as IconData,
                color: color,
                size: 22,
              ),
              title: Text(
                setting['label'] as String,
                style: TextStyle(
                  fontSize: 14,
                  color: colorScheme.onSurface,
                ),
              ),
              trailing: Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: colorScheme.onSurfaceVariant,
              ),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${setting['label']} - قيد التطوير'),
                    duration: const Duration(seconds: 1),
                  ),
                );
              },
            );
          }),
          const Divider(),
          // ✅ تسجيل الخروج
          ListTile(
            leading: const Icon(
              Icons.logout,
              color: Colors.red,
              size: 22,
            ),
            title: const Text(
              'تسجيل الخروج',
              style: TextStyle(
                fontSize: 14,
                color: Colors.red,
              ),
            ),
            onTap: () => _showLogoutDialog(context),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تسجيل الخروج'),
        content: const Text('هل أنت متأكد من رغبتك في تسجيل الخروج؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<ProfileBloc>().add(const ProfileSignOut());
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('تسجيل الخروج'),
          ),
        ],
      ),
    );
  }
}


