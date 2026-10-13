import 'package:flutter/material.dart';

import 'home_auxiliary_widgets.dart';

class UserHomeLocationNotice extends StatelessWidget {
  final Color cardColor;
  final Color orangeColor;
  final Color textPrimaryColor;
  final Color primaryColor;
  final VoidCallback onChooseLocation;

  const UserHomeLocationNotice({
    super.key,
    required this.cardColor,
    required this.orangeColor,
    required this.textPrimaryColor,
    required this.primaryColor,
    required this.onChooseLocation,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
      child: Material(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(Icons.location_off_rounded, color: orangeColor, size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'حدّد موقعك علشان نعرض العروض والخدمات القريبة منك.',
                  style: TextStyle(
                    color: textPrimaryColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
              ),
              TextButton(
                onPressed: onChooseLocation,
                child: Text(
                  'تحديد',
                  style: TextStyle(
                    color: primaryColor,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class UserHomeBottomNavigationBar extends StatelessWidget {
  final int currentIndex;
  final Color cardColor;
  final Color borderColor;
  final bool isDark;
  final ValueChanged<int> onTap;

  const UserHomeBottomNavigationBar({
    super.key,
    required this.currentIndex,
    required this.cardColor,
    required this.borderColor,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Container(
        height: 72,
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.08),
              blurRadius: 20,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            HomeBottomNavItem(
              index: 0,
              currentIndex: currentIndex,
              icon: Icons.home_rounded,
              outlinedIcon: Icons.home_outlined,
              label: 'الرئيسية',
              onTap: onTap,
            ),
            HomeBottomNavItem(
              index: 1,
              currentIndex: currentIndex,
              icon: Icons.grid_view_rounded,
              outlinedIcon: Icons.grid_view_rounded,
              label: 'الأقسام',
              onTap: onTap,
            ),
            HomeBottomNavItem(
              index: 2,
              currentIndex: currentIndex,
              icon: Icons.volunteer_activism_rounded,
              outlinedIcon: Icons.volunteer_activism_outlined,
              label: 'الاحتياجات',
              onTap: onTap,
            ),
            HomeBottomNavItem(
              index: 3,
              currentIndex: currentIndex,
              icon: Icons.receipt_long_rounded,
              outlinedIcon: Icons.receipt_long_outlined,
              label: 'الطلبات',
              onTap: onTap,
            ),
            HomeBottomNavItem(
              index: 4,
              currentIndex: currentIndex,
              icon: Icons.person_rounded,
              outlinedIcon: Icons.person_outline_rounded,
              label: 'حسابي',
              onTap: onTap,
            ),
          ],
        ),
      ),
    );
  }
}
