// lib/features/services/data/repositories/service_categories_repository.dart

import 'package:flutter/foundation.dart';
import 'package:loqma/core/services/supabase_service.dart';
import 'package:loqma/features/services/domain/entities/service_category.dart';

class ServiceCategoriesRepository {
  final _client = SupabaseService().client;

  Future<List<ServiceCategory>> listCategories() async {
    try {
      final rows = await _client
          .from('service_categories')
          .select()
          .eq('is_active', true)
          .order('sort_order', ascending: true);

      final list = (rows as List)
          .map((r) => ServiceCategory.fromMap(Map<String, dynamic>.from(r)))
          .toList();

      debugPrint('✅ Loaded service categories: ${list.length}');
      return list;
    } catch (e) {
      debugPrint('❌ listCategories error: $e');
      rethrow;
    }
  }
}
