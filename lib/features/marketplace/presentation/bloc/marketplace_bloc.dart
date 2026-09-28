// lib/features/marketplace/presentation/bloc/marketplace_bloc.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/repositories/marketplace_repository_impl.dart';
import '../../domain/entities/marketplace_attribute.dart';
import '../../domain/entities/marketplace_attribute_option.dart';
import '../../domain/repositories/marketplace_repository.dart';
import 'marketplace_event.dart';
import 'marketplace_state.dart';

class MarketplaceBloc extends Bloc<MarketplaceEvent, MarketplaceState> {
  final MarketplaceRepository _repository;

  // ============================================================
  // REQUEST GUARDS
  // ============================================================

  int _resultsRequestId = 0;
  int _loadCategoryRequestId = 0;

  MarketplaceBloc({
    MarketplaceRepository? repository,
  })  : _repository = repository ?? MarketplaceRepositoryImpl(),
        super(const MarketplaceState()) {
    on<LoadMarketplaceCategory>(_onLoadCategory);
    on<SelectMarketplaceOption>(_onSelectOption);
    on<LoadMarketplaceResults>(_onLoadResults);
    on<ResetMarketplaceFilters>(_onReset);
  }

  // ============================================================
  // LOAD CATEGORY + ALL OPTIONS (BATCH)
  // ============================================================

  Future<void> _onLoadCategory(
    LoadMarketplaceCategory event,
    Emitter<MarketplaceState> emit,
  ) async {
    // ✅ DEBUG
    debugPrint('🟢 [Bloc] LoadMarketplaceCategory called: '
        'categoryId=${event.categoryId}, '
        'categoryName=${event.categoryName}');

    final requestId = ++_loadCategoryRequestId;
    _resultsRequestId++;

    // ─── Reset state ───
    emit(
      state.copyWith(
        isLoading: true,
        isLoadingOptions: true,
        isLoadingResults: false,
        clearError: true,
        categoryId: event.categoryId,
        categoryName: event.categoryName,
        attributes: const [],
        optionsByAttribute: const <String, List<MarketplaceAttributeOption>>{},
        selectedOptionIds: const <String, String>{},
        selectedValues: const <String, String>{},
        offers: const [],
      ),
    );

    try {
      // ─── 1) Get attributes ───
      debugPrint(
          '🟢 [Bloc] Fetching attributes for category=${event.categoryId}');

      final attributes = await _repository.getCategoryFlow(
        event.categoryId,
      );

      debugPrint('🟢 [Bloc] Got ${attributes.length} attributes');

      if (isClosed) return;
      if (requestId != _loadCategoryRequestId) {
        debugPrint('🟢 [Bloc] Request cancelled (attributes)');
        return;
      }
      if (state.categoryId != event.categoryId) {
        debugPrint('🟢 [Bloc] Category changed (attributes)');
        return;
      }

      final sortedAttributes = List<MarketplaceAttribute>.from(attributes)
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

      // ─── 2) Batch load ALL options for select attributes ───
      Map<String, List<MarketplaceAttributeOption>> optionsMap = {};

      try {
        debugPrint('🟢 [Bloc] Fetching all filter options...');

        optionsMap = await _repository.getAllFilterOptions(
          categoryId: event.categoryId,
          attributes: sortedAttributes,
        );

        debugPrint('🟢 [Bloc] Got options for ${optionsMap.length} attributes');
      } catch (e) {
        debugPrint('🟢 [Bloc] ❌ getAllFilterOptions failed: $e');
        optionsMap = <String, List<MarketplaceAttributeOption>>{};
      }

      if (isClosed) return;
      if (requestId != _loadCategoryRequestId) {
        debugPrint('🟢 [Bloc] Request cancelled (options)');
        return;
      }
      if (state.categoryId != event.categoryId) {
        debugPrint('🟢 [Bloc] Category changed (options)');
        return;
      }

      emit(
        state.copyWith(
          isLoading: false,
          isLoadingOptions: false,
          attributes: sortedAttributes,
          optionsByAttribute: optionsMap,
        ),
      );

      // ─── 3) Load all offers with empty filters ───
      add(const LoadMarketplaceResults());
    } catch (error) {
      debugPrint('🟢 [Bloc] ❌ _onLoadCategory error: $error');

      if (isClosed) return;
      if (requestId != _loadCategoryRequestId) return;
      if (state.categoryId != event.categoryId) return;

      emit(
        state.copyWith(
          isLoading: false,
          isLoadingOptions: false,
          errorMessage: _friendlyError(error),
        ),
      );
    }
  }

  // ============================================================
  // SELECT OPTION
  // ============================================================

  Future<void> _onSelectOption(
    SelectMarketplaceOption event,
    Emitter<MarketplaceState> emit,
  ) async {
    debugPrint('🟢 [Bloc] SelectMarketplaceOption: '
        'attribute=${event.attribute.slug}, '
        'optionId=${event.optionId}, '
        'value=${event.value}');

    // ─── Validate attribute exists ───
    final attributeExists = state.attributes.any(
      (attribute) => attribute.attributeId == event.attribute.attributeId,
    );

    if (!attributeExists) {
      debugPrint('🟢 [Bloc] ⚠️ Attribute not in list — skipping');
      return;
    }
    if (event.attribute.slug.trim().isEmpty ||
        event.value.trim().isEmpty ||
        event.optionId.trim().isEmpty) {
      debugPrint('🟢 [Bloc] ⚠️ Invalid filter selection — skipping');
      return;
    }

    if (state.categoryId == null || state.categoryId!.isEmpty) return;

    final selectedIds = <String, String>{...state.selectedOptionIds};
    final selectedValues = <String, String>{...state.selectedValues};

    final value = event.value.trim();

    if (value.isEmpty) {
      selectedValues.remove(event.attribute.slug);
      selectedIds.remove(event.attribute.slug);
    } else {
      selectedValues[event.attribute.slug] = value;

      if (event.optionId.trim().isNotEmpty) {
        selectedIds[event.attribute.slug] = event.optionId;
      } else {
        selectedIds.remove(event.attribute.slug);
      }
    }

    _resultsRequestId++;

    emit(
      state.copyWith(
        selectedOptionIds: selectedIds,
        selectedValues: selectedValues,
        clearError: true,
      ),
    );

    // ─── Reload offers with new filters ───
    add(const LoadMarketplaceResults());
  }

  // ============================================================
  // LOAD RESULTS
  // ============================================================

  Future<void> _onLoadResults(
    LoadMarketplaceResults event,
    Emitter<MarketplaceState> emit,
  ) async {
    final categoryId = state.categoryId;

    debugPrint('🟢 [Bloc] LoadMarketplaceResults: '
        'categoryId=$categoryId, '
        'filters=${state.selectedValues}');

    if (categoryId == null || categoryId.isEmpty) {
      emit(
        state.copyWith(
          errorMessage: 'لم يتم تحديد القسم',
        ),
      );
      return;
    }

    final requestId = ++_resultsRequestId;

    final filters = Map<String, String>.from(state.selectedValues);

    emit(
      state.copyWith(
        isLoadingResults: true,
        clearError: true,
      ),
    );

    try {
      final offers = await _repository.getFilteredOffers(
        categoryId: categoryId,
        filters: filters,
      );

      debugPrint('🟢 [Bloc] ✅ Got ${offers.length} offers');

      if (isClosed) return;
      if (requestId != _resultsRequestId) {
        debugPrint('🟢 [Bloc] Results request cancelled');
        return;
      }
      if (state.categoryId != categoryId) return;

      emit(
        state.copyWith(
          isLoadingResults: false,
          offers: offers,
        ),
      );
    } catch (error) {
      debugPrint('🟢 [Bloc] ❌ _onLoadResults error: $error');

      if (isClosed) return;
      if (requestId != _resultsRequestId) return;
      if (state.categoryId != categoryId) return;

      emit(
        state.copyWith(
          isLoadingResults: false,
          errorMessage: _friendlyError(error),
        ),
      );
    }
  }

  // ============================================================
  // RESET FILTERS
  // ============================================================

  void _onReset(
    ResetMarketplaceFilters event,
    Emitter<MarketplaceState> emit,
  ) {
    debugPrint('🟢 [Bloc] ResetMarketplaceFilters');

    _resultsRequestId++;

    emit(
      state.copyWith(
        selectedOptionIds: const <String, String>{},
        selectedValues: const <String, String>{},
        clearError: true,
      ),
    );

    add(const LoadMarketplaceResults());
  }

  // ============================================================
  // FRIENDLY ERROR
  // ============================================================

  String _friendlyError(Object error) {
    final raw = error.toString().trim();

    final message = raw
        .replaceFirst('PostgrestException(message:', '')
        .replaceFirst('Exception:', '')
        .trim();

    if (message.isEmpty) {
      return 'حدث خطأ غير متوقع. حاول مرة أخرى.';
    }

    final lower = message.toLowerCase();

    if (lower.contains('network') ||
        lower.contains('socket') ||
        lower.contains('connection') ||
        lower.contains('connection reset') ||
        lower.contains('failed host lookup') ||
        lower.contains('clientexception') ||
        lower.contains('timeout') ||
        lower.contains('timed out')) {
      return 'تعذر الاتصال بالإنترنت. تحقق من الاتصال وحاول مرة أخرى.';
    }

    if (lower.contains('permission') ||
        lower.contains('row-level security') ||
        lower.contains('rls') ||
        lower.contains('not authorized') ||
        lower.contains('unauthorized')) {
      return 'ليس لديك صلاحية لتنفيذ هذا الطلب.';
    }

    if (lower.contains('authentication') ||
        (lower.contains('auth') && lower.contains('required')) ||
        lower.contains('jwt') ||
        lower.contains('session')) {
      return 'انتهت جلسة الدخول. سجل الدخول مرة أخرى.';
    }

    if (lower.contains('not found') || lower.contains('does not exist')) {
      return 'البيانات المطلوبة غير متاحة حاليًا.';
    }

    if (lower.contains('rpc') ||
        lower.contains('postgres') ||
        lower.contains('postgrest') ||
        lower.contains('database')) {
      return 'حدث خطأ مؤقت أثناء تحميل البيانات. حاول مرة أخرى.';
    }

    return 'حدث خطأ أثناء تحميل البيانات. حاول مرة أخرى.';
  }
}
