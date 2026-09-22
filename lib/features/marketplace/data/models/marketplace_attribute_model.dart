import '../../domain/entities/marketplace_attribute.dart';

class MarketplaceAttributeModel extends MarketplaceAttribute {
  const MarketplaceAttributeModel({
    required super.attributeId,
    required super.slug,
    required super.nameAr,
    required super.nameEn,
    required super.inputType,
    required super.sortOrder,
    required super.isRequired,
    required super.isFilterable,
  });

  factory MarketplaceAttributeModel.fromMap(
    Map<String, dynamic> map,
  ) {
    return MarketplaceAttributeModel(
      attributeId: map['attribute_id']?.toString() ?? '',
      slug: map['slug']?.toString() ?? '',
      nameAr: map['name_ar']?.toString() ?? '',
      nameEn: map['name_en']?.toString() ?? '',
      inputType: map['input_type']?.toString() ?? 'select',
      sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
      isRequired: map['is_required'] as bool? ?? false,
      isFilterable: map['is_filterable'] as bool? ?? false,
    );
  }
}
