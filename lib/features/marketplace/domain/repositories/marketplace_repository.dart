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
  //
  // Other categories:
  //
  // Brand
  //
  // "other":
  //
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

  Future<MarketplaceAttribute?> getNextAttribute({
    required String categoryId,
    required String optionId,
  });

  // ============================================================
  // LEGACY / BASIC ATTRIBUTE OPTIONS
  // ============================================================

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

  Future<List<MarketplaceAttributeOption>> getDynamicFilterOptions({
    required String categoryId,
    required String attributeId,
    String? parentOptionId,
    Map<String, String> filters = const {},
  });

  // ============================================================
  // ✅ BATCH: كل الـ filter options مرة واحدة
  // ============================================================
  //
  // Returns a map where:
  //   key   = attribute slug
  //   value = list of options for that attribute
  //
  // This avoids N round-trips to the database when the filters
  // section is opened. Options for all filterable (select)
  // attributes are fetched in a single call.
  //

  Future<Map<String, List<MarketplaceAttributeOption>>> getAllFilterOptions({
    required String categoryId,
    required List<MarketplaceAttribute> attributes,
    Map<String, String> filters = const {},
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
