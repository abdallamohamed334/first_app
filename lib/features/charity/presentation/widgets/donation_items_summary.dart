import 'package:flutter/material.dart';

/// Shared, backwards-compatible presentation for the new multi-item payload.
class DonationItemsSummary extends StatelessWidget {
  const DonationItemsSummary({
    super.key,
    required this.items,
    this.categories,
    this.category,
    this.quantity,
    this.condition,
    this.compact = false,
    this.showTitle = true,
  });

  final dynamic items;
  final dynamic categories;
  final String? category;
  final dynamic quantity;
  final String? condition;
  final bool compact;
  final bool showTitle;

  static const Map<String, String> _categoryLabels = {
    'food': 'طعام ومؤن',
    'clothing': 'ملابس وأحذية',
    'furniture': 'أثاث ومفروشات',
    'electronics': 'أجهزة وإلكترونيات',
    'books': 'كتب وأدوات مدرسية',
    'toys': 'ألعاب وأطفال',
    'household': 'أدوات منزلية',
    'hygiene': 'نظافة وعناية شخصية',
    'medical': 'مستلزمات طبية',
    'other': 'أخرى',
  };

  List<Map<String, dynamic>> _normalizedItems() {
    if (items is List) {
      final normalized = (items as List)
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .where((item) => item['category'] != null)
          .toList(growable: false);
      if (normalized.isNotEmpty) return normalized;
    }

    final slugs = categories is List
        ? (categories as List).map((value) => value.toString()).toList()
        : <String>[];
    if (slugs.isEmpty && category != null && category!.trim().isNotEmpty) {
      slugs.add(category!.trim());
    }
    if (slugs.isEmpty) return const [];
    return slugs
        .map(
          (slug) => <String, dynamic>{
            'category': slug,
            'quantity': quantity ?? 1,
            'unit': 'وحدة',
            'condition': condition,
          },
        )
        .toList(growable: false);
  }

  String _label(String slug) => _categoryLabels[slug] ?? slug;

  String _conditionLabel(String? value) => switch (value) {
    'new' => 'جديد',
    'very_good' => 'جيد جدًا',
    'good' => 'جيد',
    'needs_repair' => 'يحتاج إصلاح',
    'fresh' => 'طازج',
    'sealed' => 'مغلق',
    'near_expiry' => 'قريب الصلاحية',
    'frozen' => 'مجمد',
    _ => value?.trim().isNotEmpty == true ? value!.trim() : 'الحالة غير محددة',
  };

  @override
  Widget build(BuildContext context) {
    final rows = _normalizedItems();
    if (rows.isEmpty) return const SizedBox.shrink();

    if (compact) {
      return Wrap(
        spacing: 6,
        runSpacing: 6,
        children: rows
            .map((item) {
              final slug = item['category']?.toString() ?? 'other';
              final amount = item['quantity']?.toString() ?? '1';
              final unit = item['unit']?.toString().trim() ?? '';
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF5EF),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  '${_label(slug)} · $amount${unit.isEmpty ? '' : ' $unit'}',
                  style: const TextStyle(
                    color: Color(0xFF0B7650),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              );
            })
            .toList(growable: false),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FBF8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0ECE5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showTitle) ...[
            const Row(
              children: [
                Icon(
                  Icons.category_outlined,
                  size: 18,
                  color: Color(0xFF0B7650),
                ),
                SizedBox(width: 7),
                Text(
                  'الأصناف المتبرع بها',
                  style: TextStyle(
                    color: Color(0xFF123F31),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
          ...rows.map((item) {
            final slug = item['category']?.toString() ?? 'other';
            final amount = item['quantity']?.toString() ?? '1';
            final unit = item['unit']?.toString().trim() ?? '';
            final details = item['details']?.toString().trim() ?? '';
            final bestBefore =
                item['best_before_date']?.toString().trim() ?? '';
            final itemCondition = item['condition']?.toString();
            return Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 3),
                    child: Icon(
                      Icons.volunteer_activism_outlined,
                      size: 16,
                      color: Color(0xFF0B7650),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_label(slug)} · $amount${unit.isEmpty ? '' : ' $unit'}',
                          style: const TextStyle(
                            color: Color(0xFF123F31),
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                        if (itemCondition != null && itemCondition.isNotEmpty)
                          Text(
                            'الحالة: ${_conditionLabel(itemCondition)}',
                            style: const TextStyle(
                              color: Color(0xFF71837C),
                              fontSize: 11,
                            ),
                          ),
                        if (details.isNotEmpty)
                          Text(
                            details,
                            style: const TextStyle(
                              color: Color(0xFF40574D),
                              fontSize: 12,
                              height: 1.35,
                            ),
                          ),
                        if (bestBefore.isNotEmpty)
                          Text(
                            'الصلاحية: $bestBefore',
                            style: const TextStyle(
                              color: Color(0xFF9A5A00),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
