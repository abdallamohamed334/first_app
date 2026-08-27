import 'package:flutter/material.dart';

class MapFilterChips extends StatelessWidget {
  final String selectedFilter;
  final ValueChanged<String> onFilterSelected;

  const MapFilterChips({
    super.key,
    required this.selectedFilter,
    required this.onFilterSelected,
  });

  static const _filters = <_MapFilter>[
    _MapFilter('كل الوجبات', Icons.restaurant_rounded),
    _MapFilter('وجبات جاهزة', Icons.lunch_dining_rounded),
    _MapFilter('حلويات', Icons.cake_rounded),
    _MapFilter('مخبوزات', Icons.bakery_dining_rounded),
    _MapFilter('مشروبات', Icons.local_cafe_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 2),
        itemCount: _filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = _filters[index];
          final isSelected = filter.label == selectedFilter;

          return Semantics(
            button: true,
            selected: isSelected,
            label: 'فلترة حسب ${filter.label}',
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: colorScheme.primary.withAlpha(38),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: FilterChip(
                selected: isSelected,
                onSelected: (_) => onFilterSelected(filter.label),
                showCheckmark: false,
                avatar: Icon(
                  filter.icon,
                  size: 17,
                  color:
                      isSelected ? colorScheme.onPrimary : colorScheme.primary,
                ),
                label: Text(filter.label),
                labelStyle: TextStyle(
                  color: isSelected
                      ? colorScheme.onPrimary
                      : colorScheme.onSurface,
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                backgroundColor: colorScheme.surface,
                selectedColor: colorScheme.primary,
                side: BorderSide(
                  color: isSelected
                      ? colorScheme.primary
                      : colorScheme.outlineVariant.withAlpha(130),
                  width: isSelected ? 1.2 : 1,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MapFilter {
  final String label;
  final IconData icon;

  const _MapFilter(this.label, this.icon);
}

// استخدم نفس القيم في MapBloc:
// كل الوجبات، وجبات جاهزة، حلويات، مخبوزات، مشروبات
// حتى لا يحدث عدم تطابق بين اسم الفلتر والاستعلام.
