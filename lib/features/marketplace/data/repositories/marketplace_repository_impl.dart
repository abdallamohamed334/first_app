// lib/features/marketplace/data/repositories/marketplace_repository_impl.dart

import '../../domain/entities/marketplace_attribute.dart';
import '../../domain/entities/marketplace_attribute_option.dart';
import '../../domain/entities/marketplace_offer.dart';
import '../../domain/repositories/marketplace_repository.dart';
import '../datasources/marketplace_remote_datasource.dart';

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
  }) {
    return _remoteDataSource.getDynamicFilterOptions(
      categoryId: categoryId,
      attributeId: attributeId,
      parentOptionId: parentOptionId,
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
