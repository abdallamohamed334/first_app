import 'package:flutter/material.dart';

class VolunteerFilterChips extends StatelessWidget {
  final String selectedFilter;
  final ValueChanged<String> onFilterSelected;

  const VolunteerFilterChips({
    super.key,
    required this.selectedFilter,
    required this.onFilterSelected,
  });

  static const filters = <String>[
    'اليوم',
    'هذا الأسبوع',
    'هذا الشهر',
    'كل الوقت',
  ];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          children: filters.map((filter) {
            final isSelected = filter == selectedFilter;
            return Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: FilterChip(
                label: Text(
                  filter,
                  textDirection: TextDirection.rtl,
                ),
                selected: isSelected,
                onSelected: (_) => onFilterSelected(filter),
                backgroundColor: colorScheme.surface,
                selectedColor: colorScheme.primary,
                checkmarkColor: Colors.white,
                labelStyle: TextStyle(
                  color:
                      isSelected ? Colors.white : colorScheme.onSurfaceVariant,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(100),
                  side: BorderSide(
                    color: isSelected
                        ? colorScheme.primary
                        : colorScheme.outlineVariant.withValues(alpha: 0.3),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
