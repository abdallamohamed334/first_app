// lib/features/marketplace/data/repositories/marketplace_repository_impl.dart

import '../../domain/entities/marketplace_attribute.dart';
import '../../domain/entities/marketplace_attribute_option.dart';
import '../../domain/entities/marketplace_offer.dart';
import '../../domain/repositories/marketplace_repository.dart';
import '../datasources/marketplace_remote_datasource.dart';
import '../models/marketplace_attribute_model.dart';

class MarketplaceRepositoryImpl implements MarketplaceRepository {
  final MarketplaceRemoteDataSource _remoteDataSource;

  MarketplaceRepositoryImpl({
    MarketplaceRemoteDataSource? remoteDataSource,
  }) : _remoteDataSource = remoteDataSource ?? MarketplaceRemoteDataSource();

  // ============================================================
  // CATEGORY FLOW
  // ============================================================

  @override
  Future<List<MarketplaceAttribute>> getCategoryFlow(
    String categoryId,
  ) {
    return _remoteDataSource.getCategoryFlow(
      categoryId,
    );
  }

  // ============================================================
  // NEXT ATTRIBUTE
  // ============================================================

  @override
  Future<MarketplaceAttribute?> getNextAttribute({
    required String categoryId,
    required String optionId,
  }) {
    return _remoteDataSource.getNextAttribute(
      categoryId: categoryId,
      optionId: optionId,
    );
  }

  // ============================================================
  // LEGACY ATTRIBUTE OPTIONS
  // ============================================================

  @override
  Future<List<MarketplaceAttributeOption>> getAttributeOptions({
    required String attributeId,
    String? parentOptionId,
  }) {
    return _remoteDataSource.getAttributeOptions(
      attributeId: attributeId,
      parentOptionId: parentOptionId,
    );
  }

  // ============================================================
  // DYNAMIC FILTER OPTIONS
  // ============================================================

  @override
  Future<List<MarketplaceAttributeOption>> getDynamicFilterOptions({
    required String categoryId,
    required String attributeId,
    String? parentOptionId,
    Map<String, String> filters = const {},
  }) {
    return _remoteDataSource.getDynamicFilterOptions(
      categoryId: categoryId,
      attributeId: attributeId,
      parentOptionId: parentOptionId,
      filters: filters,
    );
  }

  // ============================================================
  // ✅ BATCH: كل الـ filter options مرة واحدة
  // ============================================================

  @override
  Future<Map<String, List<MarketplaceAttributeOption>>> getAllFilterOptions({
    required String categoryId,
    required List<MarketplaceAttribute> attributes,
    Map<String, String> filters = const {},
  }) async {
    // نحوّل الـ entities لـ models (لو هي أصلاً models نمررها زي ما هي)
    final models = attributes.whereType<MarketplaceAttributeModel>().toList();

    // لو مفيش models (يعني الـ entities مش من نفس النوع)، نبني models مؤقتة
    final safeModels = models.isNotEmpty
        ? models
        : attributes
            .map(
              (a) => MarketplaceAttributeModel(
                attributeId: a.attributeId,
                slug: a.slug,
                nameAr: a.nameAr,
                nameEn: a.nameEn,
                inputType: a.inputType,
                sortOrder: a.sortOrder,
                isRequired: a.isRequired,
                isFilterable: a.isFilterable,
              ),
            )
            .toList();

    final result = await _remoteDataSource.getAllFilterOptions(
      categoryId: categoryId,
      attributes: safeModels,
      filters: filters,
    );

    // نحوّل الـ Map من models لـ entities
    return result.map(
      (key, value) => MapEntry(
        key,
        value.cast<MarketplaceAttributeOption>(),
      ),
    );
  }

  // ============================================================
  // FILTERED OFFERS
  // ============================================================

  @override
  Future<List<MarketplaceOffer>> getFilteredOffers({
    required String categoryId,
    Map<String, String> filters = const {},
  }) {
    return _remoteDataSource.getFilteredOffers(
      categoryId: categoryId,
      filters: filters,
    );
  }
}
