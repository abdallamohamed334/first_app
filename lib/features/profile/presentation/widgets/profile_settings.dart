import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:loqma/routes/app_router.dart';

class ProfileSettings extends StatelessWidget {
  const ProfileSettings({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final settings = [
      (Icons.notifications, 'الإشعارات', AppRouter.notifications),
      (Icons.privacy_tip_outlined, 'سياسة الخصوصية', AppRouter.privacy),
      (Icons.description_outlined, 'شروط الاستخدام', AppRouter.terms),
      (Icons.help_outline, 'المساعدة والدعم', AppRouter.support),
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.3))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('الإعدادات', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: colors.onSurface)),
        const SizedBox(height: 8),
        ...settings.map((setting) => ListTile(
          leading: Icon(setting.$1, color: colors.primary, size: 22),
          title: Text(setting.$2, style: TextStyle(fontSize: 14, color: colors.onSurface)),
          trailing: Icon(Icons.arrow_forward_ios, size: 16, color: colors.onSurfaceVariant),
          onTap: () => context.push(setting.$3),
        )),
      ]),
    );
  }
}
