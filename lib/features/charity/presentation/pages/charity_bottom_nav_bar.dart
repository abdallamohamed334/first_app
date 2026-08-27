import 'package:flutter/material.dart';

class CharityBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onChanged;

  const CharityBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onChanged,
  });

  static const _green = Color(0xFF006C48);
  static const _muted = Color(0xFF71847B);

  static const _items = <({IconData icon, String label})>[
    (icon: Icons.dashboard_rounded, label: 'الرئيسية'),
    (icon: Icons.storefront_rounded, label: 'متابعة المؤسسات'),
    (icon: Icons.volunteer_activism_rounded, label: 'متابعة الأشخاص'),
    (icon: Icons.groups_rounded, label: 'المتطوعون'),
    (icon: Icons.person_rounded, label: 'الملف'),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 7, 8, 6),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE1EAE5))),
          boxShadow: [
            BoxShadow(
              color: Color(0x10001E15),
              blurRadius: 14,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: Row(
          children: List.generate(_items.length, (index) {
            final item = _items[index];
            final selected = currentIndex == index;
            return Expanded(
              child: Semantics(
                button: true,
                selected: selected,
                label: item.label,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => onChanged(index),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOut,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: selected
                                ? _green.withAlpha(22)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Icon(
                            item.icon,
                            size: 21,
                            color: selected ? _green : _muted,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: selected ? _green : _muted,
                            fontSize: 10,
                            fontWeight:
                                selected ? FontWeight.w900 : FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
