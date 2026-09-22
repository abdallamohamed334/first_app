class MarketplaceAttributeOption {
  final String id;
  final String attributeId;
  final String value;
  final String labelAr;
  final String labelEn;
  final String? icon;
  final int sortOrder;
  final String? parentOptionId;

  const MarketplaceAttributeOption({
    required this.id,
    required this.attributeId,
    required this.value,
    required this.labelAr,
    required this.labelEn,
    this.icon,
    required this.sortOrder,
    this.parentOptionId,
  });
}
