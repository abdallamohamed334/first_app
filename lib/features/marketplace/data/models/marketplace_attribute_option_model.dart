import '../../domain/entities/marketplace_attribute_option.dart';

class MarketplaceAttributeOptionModel extends MarketplaceAttributeOption {
  const MarketplaceAttributeOptionModel({
    required super.id,
    required super.attributeId,
    required super.value,
    required super.labelAr,
    required super.labelEn,
    super.icon,
    required super.sortOrder,
    super.parentOptionId,
  });

  factory MarketplaceAttributeOptionModel.fromMap(
    Map<String, dynamic> map,
  ) {
    return MarketplaceAttributeOptionModel(
      id: map['id']?.toString() ?? '',
      attributeId: map['attribute_id']?.toString() ?? '',
      value: map['value']?.toString() ?? '',
      labelAr: map['label_ar']?.toString() ?? '',
      labelEn: map['label_en']?.toString() ?? '',
      icon: map['icon']?.toString(),
      sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
      parentOptionId: map['parent_option_id']?.toString(),
    );
  }
}
