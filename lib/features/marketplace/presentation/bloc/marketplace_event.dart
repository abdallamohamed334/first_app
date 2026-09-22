import '../../domain/entities/marketplace_attribute.dart';

abstract class MarketplaceEvent {
  const MarketplaceEvent();
}

class LoadMarketplaceCategory extends MarketplaceEvent {
  final String categoryId;
  final String categoryName;

  const LoadMarketplaceCategory({
    required this.categoryId,
    required this.categoryName,
  });
}

class LoadMarketplaceOptions extends MarketplaceEvent {
  final MarketplaceAttribute attribute;
  final String? parentOptionId;

  const LoadMarketplaceOptions({
    required this.attribute,
    this.parentOptionId,
  });
}

class SelectMarketplaceOption extends MarketplaceEvent {
  final MarketplaceAttribute attribute;
  final String optionId;
  final String value;

  const SelectMarketplaceOption({
    required this.attribute,
    required this.optionId,
    required this.value,
  });
}

class LoadMarketplaceResults extends MarketplaceEvent {
  const LoadMarketplaceResults();
}

class ResetMarketplaceFilters extends MarketplaceEvent {
  const ResetMarketplaceFilters();
}
