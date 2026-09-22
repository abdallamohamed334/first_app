// lib/features/marketplace/data/datasources/marketplace_remote_datasource.dart

import 'package:loqma/features/marketplace/data/models/marketplace_attribute_model.dart';
import 'package:loqma/features/marketplace/data/models/marketplace_attribute_option_model.dart';
import 'package:loqma/features/marketplace/data/models/marketplace_offer_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MarketplaceRemoteDataSource {
  final SupabaseClient _supabase;

  MarketplaceRemoteDataSource({
    SupabaseClient? supabase,
  }) : _supabase = supabase ?? Supabase.instance.client;

  // ============================================================
  // CATEGORY FLOW
  // ============================================================

  Future<List<MarketplaceAttributeModel>> getCategoryFlow(
    String categoryId,
  ) async {
    final response = await _supabase.rpc(
      'get_marketplace_category_flow',
      params: {
        'p_category_id': categoryId,
      },
    );

    if (response is! List) {
      return <MarketplaceAttributeModel>[];
    }

    return response
        .whereType<Map>()
        .map(
          (item) => MarketplaceAttributeModel.fromMap(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList();
  }

  // ============================================================
  // GET NEXT ATTRIBUTE
  // ============================================================

  Future<MarketplaceAttributeModel?> getNextAttribute({
    required String categoryId,
    required String optionId,
  }) async {
    final response = await _supabase.rpc(
      'get_marketplace_next_attribute',
      params: {
        'p_category_id': categoryId,
        'p_option_id': optionId,
      },
    );

    if (response is! List || response.isEmpty) {
      return null;
    }

    final first = response.first;

    if (first is! Map) {
      return null;
    }

    return MarketplaceAttributeModel.fromMap(
      Map<String, dynamic>.from(first),
    );
  }

  // ============================================================
  // LEGACY ATTRIBUTE OPTIONS
  // ============================================================

  Future<List<MarketplaceAttributeOptionModel>> getAttributeOptions({
    required String attributeId,
    String? parentOptionId,
  }) async {
    final response = await _supabase.rpc(
      'get_marketplace_attribute_options',
      params: {
        'p_attribute_id': attributeId,
        'p_parent_option_id': parentOptionId,
      },
    );

    if (response is! List) {
      return <MarketplaceAttributeOptionModel>[];
    }

    return response
        .whereType<Map>()
        .map(
          (item) => MarketplaceAttributeOptionModel.fromMap(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList();
  }

  // ============================================================
  // DYNAMIC FILTER OPTIONS
  // ============================================================

  Future<List<MarketplaceAttributeOptionModel>> getDynamicFilterOptions({
    required String categoryId,
    required String attributeId,
    String? parentOptionId,
  }) async {
    // ✅ نبعت كل الباراميترز — الـ RPC بتقبلهم
    final response = await _supabase.rpc(
      'get_marketplace_dynamic_filter_options',
      params: {
        'p_category_id': categoryId,
        'p_attribute_id': attributeId,
        'p_parent_option_id': parentOptionId,
        'p_filters': <String, String>{},
      },
    );

    if (response is! List) {
      return <MarketplaceAttributeOptionModel>[];
    }

    return response
        .whereType<Map>()
        .map(
          (item) => MarketplaceAttributeOptionModel.fromMap(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList();
  }

  // ============================================================
  // FILTERED OFFERS
  // ============================================================

  Future<List<MarketplaceOfferModel>> getFilteredOffers({
    required String categoryId,
    Map<String, String> filters = const {},
  }) async {
    final response = await _supabase.rpc(
      'get_marketplace_filtered_offers',
      params: {
        'p_category_id': categoryId,
        'p_filters': filters,
      },
    );

    if (response is! List) {
      return <MarketplaceOfferModel>[];
    }

    return response
        .whereType<Map>()
        .map(
          (item) => MarketplaceOfferModel.fromMap(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList();
  }

  // ============================================================
  // GET ALL OFFERS BY CATEGORY
  // ============================================================

  Future<List<MarketplaceOfferModel>> getOffersByCategory(
    String categoryId,
  ) async {
    return getFilteredOffers(
      categoryId: categoryId,
      filters: const {},
    );
  }
}
