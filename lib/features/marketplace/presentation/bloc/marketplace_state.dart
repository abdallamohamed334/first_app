import '../../domain/entities/marketplace_attribute.dart';
import '../../domain/entities/marketplace_attribute_option.dart';
import '../../domain/entities/marketplace_offer.dart';

class MarketplaceState {
  final bool isLoading;
  final bool isLoadingOptions;
  final bool isLoadingResults;
  final String? errorMessage;

  final String? categoryId;
  final String? categoryName;

  final List<MarketplaceAttribute> attributes;

  final Map<String, List<MarketplaceAttributeOption>> optionsByAttribute;

  final Map<String, String> selectedOptionIds;

  final Map<String, String> selectedValues;

  final List<MarketplaceOffer> offers;

  const MarketplaceState({
    this.isLoading = false,
    this.isLoadingOptions = false,
    this.isLoadingResults = false,
    this.errorMessage,
    this.categoryId,
    this.categoryName,
    this.attributes = const [],
    this.optionsByAttribute = const {},
    this.selectedOptionIds = const {},
    this.selectedValues = const {},
    this.offers = const [],
  });

  MarketplaceState copyWith({
    bool? isLoading,
    bool? isLoadingOptions,
    bool? isLoadingResults,
    String? errorMessage,
    bool clearError = false,
    String? categoryId,
    String? categoryName,
    List<MarketplaceAttribute>? attributes,
    Map<String, List<MarketplaceAttributeOption>>? optionsByAttribute,
    Map<String, String>? selectedOptionIds,
    Map<String, String>? selectedValues,
    List<MarketplaceOffer>? offers,
  }) {
    return MarketplaceState(
      isLoading: isLoading ?? this.isLoading,
      isLoadingOptions: isLoadingOptions ?? this.isLoadingOptions,
      isLoadingResults: isLoadingResults ?? this.isLoadingResults,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      attributes: attributes ?? this.attributes,
      optionsByAttribute: optionsByAttribute ?? this.optionsByAttribute,
      selectedOptionIds: selectedOptionIds ?? this.selectedOptionIds,
      selectedValues: selectedValues ?? this.selectedValues,
      offers: offers ?? this.offers,
    );
  }

  bool get hasRequiredSelections {
    for (final attribute in attributes) {
      if (!attribute.isRequired) {
        continue;
      }

      final value = selectedValues[attribute.slug];

      if (value == null || value.isEmpty) {
        return false;
      }
    }

    return true;
  }
}
