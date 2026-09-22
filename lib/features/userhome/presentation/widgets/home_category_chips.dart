// lib/features/home/presentation/widgets/home_category_chips.dart

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class HomeCategoryChips extends StatelessWidget {
  final String selectedCategory;
  final ValueChanged<String> onCategorySelected;

  const HomeCategoryChips({
    super.key,
    required this.selectedCategory,
    required this.onCategorySelected,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final categories = <Map<String, dynamic>>[
      {'id': 'الكل', 'label': 'الكل', 'iconPath': 'assets/icons/all.svg'},
      {
        'id': 'restaurant',
        'label': 'مطاعم',
        'iconPath': 'assets/icons/restaurant_logo.svg'
      },
      {'id': 'bakery', 'label': 'مخابز', 'iconPath': 'assets/icons/bakery.svg'},
      {
        'id': 'sweets',
        'label': 'حلويات',
        'iconPath': 'assets/icons/sweets.svg'
      },
      {
        'id': 'grocery',
        'label': 'بقالة',
        'iconPath': 'assets/icons/grocery.svg'
      },
      {'id': 'hotel', 'label': 'فنادق', 'iconPath': 'assets/icons/hotel.svg'},
      {'id': 'hall', 'label': 'قاعات', 'iconPath': 'assets/icons/hall.svg'},
      {
        'id': 'individual',
        'label': 'أفراد',
        'iconPath': 'assets/icons/individual.svg'
      },
    ];

    return SizedBox(
      height: 50,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: categories.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final category = categories[index];
          final id = category['id'] as String;
          final label = category['label'] as String;
          final iconPath = category['iconPath'] as String;
          final isSelected = selectedCategory == id;

          return FilterChip(
            selected: isSelected,
            onSelected: (_) => onCategorySelected(id),
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // عرض الأيقونة
                SizedBox(
                  width: 18,
                  height: 18,
                  child: SvgPicture.asset(
                    iconPath,
                    placeholderBuilder: (context) =>
                        const Icon(Icons.error_outline, size: 18),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? colors.onPrimary : colors.onSurface,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            backgroundColor: isDark ? const Color(0xFF1F1F1F) : Colors.white,
            selectedColor: colors.primary,
            side: BorderSide(
              color: isSelected ? colors.primary : colors.outlineVariant,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            showCheckmark: false,
          );
        },
      ),
    );
  }
}
