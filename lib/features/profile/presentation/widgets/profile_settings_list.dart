import 'package:flutter/material.dart';

class ProfileSettingsList extends StatelessWidget {
  final VoidCallback onEditProfile;
  final VoidCallback onLogout;

  // Dark mode
  final bool isDarkMode;
  final ValueChanged<bool> onDarkModeChanged;

  const ProfileSettingsList({
    super.key,
    required this.onEditProfile,
    required this.onLogout,
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
        border: Border.all(
          color: colors.outlineVariant.withAlpha(100),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(
              Theme.of(context).brightness == Brightness.dark ? 35 : 12,
            ),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          _SettingTile(
            icon: Icons.manage_accounts_rounded,
            title: 'تعديل الملف الشخصي',
            onTap: onEditProfile,
          ),

          _divider(colors),

          _SettingTile(
            icon: Icons.notifications_none_rounded,
            title: 'الإشعارات',
            onTap: () => _comingSoon(context, 'الإشعارات'),
          ),

          _divider(colors),

          // 🌙 Dark Mode
          _SettingTile(
            icon:
                isDarkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
            title: 'الوضع الداكن',
            trailingWidget: Switch.adaptive(
              value: isDarkMode,
              onChanged: onDarkModeChanged,
            ),
            onTap: () {
              onDarkModeChanged(!isDarkMode);
            },
          ),

          _divider(colors),

          _SettingTile(
            icon: Icons.language_rounded,
            title: 'اللغة',
            trailing: 'العربية',
            onTap: () => _comingSoon(context, 'تغيير اللغة'),
          ),

          _divider(colors),

          _SettingTile(
            icon: Icons.logout_rounded,
            title: 'تسجيل الخروج',
            destructive: true,
            onTap: onLogout,
          ),
        ],
      ),
    );
  }

  Widget _divider(ColorScheme colors) {
    return Divider(
      height: 1,
      indent: 62,
      endIndent: 16,
      color: colors.outlineVariant.withAlpha(70),
    );
  }

  void _comingSoon(BuildContext context, String title) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('$title ستكون متاحة قريبًا'),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }
}

class _SettingTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? trailing;
  final Widget? trailingWidget;
  final bool destructive;
  final VoidCallback onTap;

  const _SettingTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.trailing,
    this.trailingWidget,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color = destructive ? colors.error : colors.primary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: ListTile(
          tileColor: Colors.transparent,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 2,
          ),
          leading: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withAlpha(18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: color,
              size: 20,
            ),
          ),
          title: Text(
            title,
            style: TextStyle(
              color: destructive ? colors.error : colors.onSurface,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          trailing: trailingWidget ??
              (destructive
                  ? null
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (trailing != null)
                          Text(
                            trailing!,
                            style: TextStyle(
                              color: colors.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 14,
                          color: colors.onSurfaceVariant,
                        ),
                      ],
                    )),
        ),
      ),
    );
  }
}
