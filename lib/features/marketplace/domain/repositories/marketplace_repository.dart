// lib/features/marketplace/domain/repositories/marketplace_repository.dart

import '../entities/marketplace_attribute.dart';
import '../entities/marketplace_attribute_option.dart';
import '../entities/marketplace_offer.dart';

abstract class MarketplaceRepository {
  // ============================================================
  // CATEGORY FLOW
  // ============================================================
  //
  // Returns the attributes configured for the selected category
  // from the database.
  //
  // Current business rules:
  //
  // Cars:
  //
  // Brand
  //   ↓
  // Model
  //   ↓
  // Year
  //   ↓
  // Kilometers
  //   ↓
  // Fuel Type
  //   ↓
  // Transmission
  //   ↓
  // Body Type
  //   ↓
  // Color
  //   ↓
  // Condition
  //   ↓
  // Air Conditioning
  //   ↓
  // Interior
  //   ↓
  // Number Of Owners
  //   ↓
  // Payment Method
  //   ↓
  // Down Payment
  //   ↓
  // Engine Capacity
  //
  // Other categories:
  //
  // Condition
  //
  // "other":
  //
  // Condition
  //   ↓
  // Item Type
  //
  // The actual configuration comes from:
  // marketplace_category_attributes
  //
  // Flutter should NOT hardcode the category fields.
  //

  Future<List<MarketplaceAttribute>> getCategoryFlow(
    String categoryId,
  );

  // ============================================================
  // NEXT ATTRIBUTE
  // ============================================================
  //
  // The database can determine the next attribute after a
  // selected option.
  //
  // The main dependent relationship currently used is:
  //
  // Cars:
  //
  // Toyota
  //   ↓
  // Model
  //
  // BMW
  //   ↓
  // Model
  //
  // This allows the database to control dependent branches.
  //
  // Flutter should not assume that every next attribute depends
  // on the previous selected option.
  //
  // For attributes that don't have option-based branching,
  // MarketplaceBloc can fall back to sort_order.
  //

  Future<MarketplaceAttribute?> getNextAttribute({
    required String categoryId,
    required String optionId,
  });

  // ============================================================
  // LEGACY / BASIC ATTRIBUTE OPTIONS
  // ============================================================
  //
  // Kept for compatibility with existing marketplace code.
  //
  // New marketplace browsing should normally use:
  //
  // getDynamicFilterOptions()
  //
  // instead.
  //

  Future<List<MarketplaceAttributeOption>> getAttributeOptions({
    required String attributeId,
    String? parentOptionId,
  });

  // ============================================================
  // DYNAMIC FILTER OPTIONS
  // ============================================================
  //
  // Returns the valid options for an attribute in a category.
  //
  // parentOptionId is only used when the selected option controls
  // the next attribute's available options.
  //
  // Example:
  //
  // Category = Cars
  // Attribute = Model
  // Parent = Toyota
  //
  // -> return Toyota models only.
  //
  // For independent attributes such as:
  //
  // Condition
  // Fuel Type
  // Transmission
  // Color
  //
  // parentOptionId can be null.
  //

  Future<List<MarketplaceAttributeOption>> getDynamicFilterOptions({
    required String categoryId,
    required String attributeId,
    String? parentOptionId,
  });

  // ============================================================
  // FILTERED OFFERS
  // ============================================================
  //
  // Returns marketplace offers matching the selected filters.
  //
  // Empty filters means:
  //
  // -> return all active/published offers in the category.
  //
  // This is important because old/legacy offers that don't have
  // marketplace_offer_attributes should still be visible when
  // the user hasn't selected filters.
  //
  // Example:
  //
  // {
  //   "brand": "toyota",
  //   "model": "corolla",
  //   "year": "2022",
  //   "condition": "used"
  // }
  //

  Future<List<MarketplaceOffer>> getFilteredOffers({
    required String categoryId,
    Map<String, String> filters = const {},
  });
}
