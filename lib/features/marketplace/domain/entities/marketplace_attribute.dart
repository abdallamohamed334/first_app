class MarketplaceAttribute {
  final String attributeId;
  final String slug;
  final String nameAr;
  final String nameEn;
  final String inputType;
  final int sortOrder;
  final bool isRequired;
  final bool isFilterable;

  const MarketplaceAttribute({
    required this.attributeId,
    required this.slug,
    required this.nameAr,
    required this.nameEn,
    required this.inputType,
    required this.sortOrder,
    required this.isRequired,
    required this.isFilterable,
  });
}
