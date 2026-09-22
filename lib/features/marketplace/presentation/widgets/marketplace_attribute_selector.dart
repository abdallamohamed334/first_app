import 'package:flutter/material.dart';

import '../../domain/entities/marketplace_attribute.dart';
import '../../domain/entities/marketplace_attribute_option.dart';

class MarketplaceAttributeSelector extends StatelessWidget {
  final MarketplaceAttribute attribute;
  final List<MarketplaceAttributeOption> options;
  final String? selectedOptionId;
  final bool enabled;
  final bool isLoading;
  final ValueChanged<MarketplaceAttributeOption> onSelected;

  const MarketplaceAttributeSelector({
    super.key,
    required this.attribute,
    required this.options,
    required this.selectedOptionId,
    required this.enabled,
    required this.isLoading,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                attribute.nameAr,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (attribute.isRequired)
              const Text(
                '*',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (isLoading)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.colorScheme.outlineVariant,
              ),
            ),
            child: const Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                ),
              ),
            ),
          )
        else if (options.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: theme.colorScheme.surfaceContainerHighest,
            ),
            child: const Text(
              'لا توجد خيارات متاحة حاليًا',
              textAlign: TextAlign.right,
            ),
          )
        else
          DropdownButtonFormField<String>(
            value: selectedOptionId,
            isExpanded: true,
            decoration: InputDecoration(
              hintText: 'اختر ${attribute.nameAr}',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: theme.colorScheme.outlineVariant,
                ),
              ),
              filled: true,
              fillColor: theme.colorScheme.surface,
            ),
            items: options.map((option) {
              return DropdownMenuItem<String>(
                value: option.id,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    option.labelAr,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              );
            }).toList(),
            onChanged: enabled
                ? (value) {
                    if (value == null) return;

                    final selected = options.firstWhere(
                      (option) => option.id == value,
                    );

                    onSelected(selected);
                  }
                : null,
          ),
      ],
    );
  }
}
