import 'package:flutter/material.dart';

class ProfileSettingsList extends StatelessWidget {
  final VoidCallback onEditProfile;
  final VoidCallback onLogout;
  final VoidCallback onOpenNotifications;
  final VoidCallback onOpenSupport;
  final VoidCallback onOpenPrivacy;
  final VoidCallback onOpenTerms;
  final VoidCallback onDeleteAccount;
  final bool isDarkMode;
  final ValueChanged<bool> onDarkModeChanged;

  const ProfileSettingsList({
    super.key,
    required this.onEditProfile,
    required this.onLogout,
    required this.onOpenNotifications,
    required this.onOpenSupport,
    required this.onOpenPrivacy,
    required this.onOpenTerms,
    required this.onDeleteAccount,
    required this.isDarkMode,
    required this.onDarkModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.outlineVariant.withAlpha(100)),
      ),
      child: Column(
        children: [
          _SettingTile(icon: Icons.manage_accounts_rounded, title: 'تعديل الملف الشخصي', onTap: onEditProfile),
          _divider(colors),
          _SettingTile(icon: Icons.notifications_none_rounded, title: 'الإشعارات', onTap: onOpenNotifications),
          _divider(colors),
          _SettingTile(
            icon: isDarkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
            title: 'الوضع الداكن',
            trailingWidget: IgnorePointer(child: Switch.adaptive(value: isDarkMode, onChanged: (_) {})),
            onTap: () => onDarkModeChanged(!isDarkMode),
          ),
          _divider(colors),
          _SettingTile(icon: Icons.support_agent_rounded, title: 'الدعم والتواصل', onTap: onOpenSupport),
          _divider(colors),
          _SettingTile(icon: Icons.privacy_tip_outlined, title: 'سياسة الخصوصية', onTap: onOpenPrivacy),
          _divider(colors),
          _SettingTile(icon: Icons.description_outlined, title: 'شروط الاستخدام', onTap: onOpenTerms),
          _divider(colors),
          _SettingTile(icon: Icons.delete_forever_outlined, title: 'حذف الحساب', destructive: true, onTap: onDeleteAccount),
          _divider(colors),
          _SettingTile(icon: Icons.logout_rounded, title: 'تسجيل الخروج', destructive: true, onTap: onLogout),
        ],
      ),
    );
  }

  Widget _divider(ColorScheme colors) => Divider(height: 1, indent: 62, endIndent: 16, color: colors.outlineVariant.withAlpha(70));
}

class _SettingTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget? trailingWidget;
  final bool destructive;
  final VoidCallback onTap;

  const _SettingTile({required this.icon, required this.title, required this.onTap, this.trailingWidget, this.destructive = false});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color = destructive ? colors.error : colors.primary;
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(color: color.withAlpha(18), borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(title, style: TextStyle(color: destructive ? colors.error : colors.onSurface, fontSize: 14, fontWeight: FontWeight.w700)),
      trailing: trailingWidget ?? Icon(Icons.arrow_forward_ios_rounded, size: 14, color: colors.onSurfaceVariant),
    );
  }
}
