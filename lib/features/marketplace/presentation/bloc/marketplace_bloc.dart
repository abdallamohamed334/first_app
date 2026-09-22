// lib/features/marketplace/presentation/bloc/marketplace_bloc.dart

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

  int _optionsRequestId = 0;
  int _resultsRequestId = 0;
  int _nextAttributeRequestId = 0;

  MarketplaceBloc({
    MarketplaceRepository? repository,
  })  : _repository = repository ?? MarketplaceRepositoryImpl(),
        super(const MarketplaceState()) {
    on<LoadMarketplaceCategory>(_onLoadCategory);
    on<LoadMarketplaceOptions>(_onLoadOptions);
    on<SelectMarketplaceOption>(_onSelectOption);
    on<LoadMarketplaceResults>(_onLoadResults);
    on<ResetMarketplaceFilters>(_onReset);
  }

  // ============================================================
  // LOAD CATEGORY
  // ============================================================

  Future<void> _onLoadCategory(
    LoadMarketplaceCategory event,
    Emitter<MarketplaceState> emit,
  ) async {
    _optionsRequestId++;
    _resultsRequestId++;
    _nextAttributeRequestId++;

    emit(
      state.copyWith(
        isLoading: true,
        isLoadingOptions: false,
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
      final attributes = await _repository.getCategoryFlow(
        event.categoryId,
      );

      if (isClosed) return;

      if (state.categoryId != event.categoryId) {
        return;
      }

      final sortedAttributes = List<MarketplaceAttribute>.from(attributes)
        ..sort(
          (a, b) => a.sortOrder.compareTo(b.sortOrder),
        );

      emit(
        state.copyWith(
          isLoading: false,
          attributes: sortedAttributes,
        ),
      );

      // Empty filters = all offers.
      add(const LoadMarketplaceResults());

      // Start with the first attribute.
      if (sortedAttributes.isNotEmpty) {
        add(
          LoadMarketplaceOptions(
            attribute: sortedAttributes.first,
          ),
        );
      }
    } catch (error) {
      if (isClosed) return;

      if (state.categoryId != event.categoryId) {
        return;
      }

      emit(
        state.copyWith(
          isLoading: false,
          errorMessage: _friendlyError(error),
        ),
      );
    }
  }

  // ============================================================
  // LOAD OPTIONS
  // ============================================================

  Future<void> _onLoadOptions(
    LoadMarketplaceOptions event,
    Emitter<MarketplaceState> emit,
  ) async {
    final categoryId = state.categoryId;

    if (categoryId == null || categoryId.isEmpty) {
      return;
    }

    final requestId = ++_optionsRequestId;

    emit(
      state.copyWith(
        isLoadingOptions: true,
        clearError: true,
      ),
    );

    try {
      final options = await _repository.getDynamicFilterOptions(
        categoryId: categoryId,
        attributeId: event.attribute.attributeId,
        parentOptionId: event.parentOptionId,
      );

      if (isClosed) return;

      if (requestId != _optionsRequestId) {
        return;
      }

      if (state.categoryId != categoryId) {
        return;
      }

      final optionsMap = <String, List<MarketplaceAttributeOption>>{
        ...state.optionsByAttribute,
        event.attribute.slug: options,
      };

      emit(
        state.copyWith(
          isLoadingOptions: false,
          optionsByAttribute: optionsMap,
        ),
      );
    } catch (error) {
      if (isClosed) return;

      if (requestId != _optionsRequestId) {
        return;
      }

      if (state.categoryId != categoryId) {
        return;
      }

      emit(
        state.copyWith(
          isLoadingOptions: false,
          errorMessage: _friendlyError(error),
        ),
      );
    }
  }

  // ============================================================
  // SELECT OPTION / VALUE
  // ============================================================

  Future<void> _onSelectOption(
    SelectMarketplaceOption event,
    Emitter<MarketplaceState> emit,
  ) async {
    final currentAttribute = event.attribute;

    final attributeExists = state.attributes.any(
      (attribute) => attribute.attributeId == currentAttribute.attributeId,
    );

    if (!attributeExists) {
      return;
    }

    final categoryId = state.categoryId;

    if (categoryId == null || categoryId.isEmpty) {
      return;
    }

    final selectedIds = <String, String>{
      ...state.selectedOptionIds,
    };

    final selectedValues = <String, String>{
      ...state.selectedValues,
    };

    final optionsMap = <String, List<MarketplaceAttributeOption>>{
      ...state.optionsByAttribute,
    };

    // SAVE VALUE
    final value = event.value.trim();

    if (value.isEmpty) {
      selectedValues.remove(currentAttribute.slug);
      selectedIds.remove(currentAttribute.slug);
    } else {
      selectedValues[currentAttribute.slug] = value;

      if (event.optionId.trim().isNotEmpty) {
        selectedIds[currentAttribute.slug] = event.optionId;
      } else {
        selectedIds.remove(currentAttribute.slug);
      }
    }

    // CLEAR OLD BRANCH
    _removeStaleSelectionsAfterAttribute(
      selectedIds: selectedIds,
      selectedValues: selectedValues,
      optionsMap: optionsMap,
      currentAttributeId: currentAttribute.attributeId,
    );

    // INVALIDATE OLD REQUESTS
    _optionsRequestId++;
    _resultsRequestId++;

    final nextRequestId = ++_nextAttributeRequestId;

    emit(
      state.copyWith(
        selectedOptionIds: selectedIds,
        selectedValues: selectedValues,
        optionsByAttribute: optionsMap,
        clearError: true,
      ),
    );

    // NUMBER / TEXT ATTRIBUTE
    final isValueAttribute = currentAttribute.inputType != 'select';

    if (isValueAttribute) {
      final nextAttribute = _getNextAttributeByOrder(
        currentAttribute.attributeId,
      );

      if (nextAttribute != null) {
        add(
          LoadMarketplaceOptions(
            attribute: nextAttribute,
          ),
        );
      }

      add(const LoadMarketplaceResults());
      return;
    }

    // SELECT ATTRIBUTE
    final optionId = event.optionId.trim();

    if (optionId.isEmpty) {
      final nextAttribute = _getNextAttributeByOrder(
        currentAttribute.attributeId,
      );

      if (nextAttribute != null) {
        add(
          LoadMarketplaceOptions(
            attribute: nextAttribute,
          ),
        );
      }

      add(const LoadMarketplaceResults());
      return;
    }

    // ASK DATABASE FOR NEXT ATTRIBUTE
    try {
      final nextAttribute = await _repository.getNextAttribute(
        categoryId: categoryId,
        optionId: optionId,
      );

      if (isClosed) return;

      if (nextRequestId != _nextAttributeRequestId) {
        return;
      }

      if (state.categoryId != categoryId) {
        return;
      }

      if (nextAttribute != null) {
        final shouldUseParentOption = _shouldUseParentOption(
          currentAttribute: currentAttribute,
          nextAttribute: nextAttribute,
        );

        add(
          LoadMarketplaceOptions(
            attribute: nextAttribute,
            parentOptionId: shouldUseParentOption ? optionId : null,
          ),
        );

        add(const LoadMarketplaceResults());
        return;
      }

      final fallbackNextAttribute = _getNextAttributeByOrder(
        currentAttribute.attributeId,
      );

      if (fallbackNextAttribute != null) {
        add(
          LoadMarketplaceOptions(
            attribute: fallbackNextAttribute,
          ),
        );
      }

      add(const LoadMarketplaceResults());
    } catch (error) {
      if (isClosed) return;

      if (nextRequestId != _nextAttributeRequestId) {
        return;
      }

      if (state.categoryId != categoryId) {
        return;
      }

      emit(
        state.copyWith(
          errorMessage: _friendlyError(error),
        ),
      );

      add(const LoadMarketplaceResults());

      final fallbackNextAttribute = _getNextAttributeByOrder(
        currentAttribute.attributeId,
      );

      if (fallbackNextAttribute != null) {
        add(
          LoadMarketplaceOptions(
            attribute: fallbackNextAttribute,
          ),
        );
      }
    }
  }

  // ============================================================
  // SHOULD USE PARENT OPTION?
  // ============================================================

  bool _shouldUseParentOption({
    required MarketplaceAttribute currentAttribute,
    required MarketplaceAttribute nextAttribute,
  }) {
    final currentSlug = currentAttribute.slug.trim().toLowerCase();
    final nextSlug = nextAttribute.slug.trim().toLowerCase();

    // Brand -> Model
    if (currentSlug == 'brand' && nextSlug == 'model') {
      return true;
    }

    return false;
  }

  // ============================================================
  // GET NEXT ATTRIBUTE BY SORT ORDER
  // ============================================================

  MarketplaceAttribute? _getNextAttributeByOrder(
    String currentAttributeId,
  ) {
    final attributes = List<MarketplaceAttribute>.from(state.attributes)
      ..sort(
        (a, b) => a.sortOrder.compareTo(b.sortOrder),
      );

    final currentIndex = attributes.indexWhere(
      (attribute) => attribute.attributeId == currentAttributeId,
    );

    if (currentIndex == -1) {
      return null;
    }

    final nextIndex = currentIndex + 1;

    if (nextIndex >= attributes.length) {
      return null;
    }

    return attributes[nextIndex];
  }

  // ============================================================
  // REMOVE STALE SELECTIONS
  // ============================================================

  void _removeStaleSelectionsAfterAttribute({
    required Map<String, String> selectedIds,
    required Map<String, String> selectedValues,
    required Map<String, List<MarketplaceAttributeOption>> optionsMap,
    required String currentAttributeId,
  }) {
    final attributes = List<MarketplaceAttribute>.from(state.attributes)
      ..sort(
        (a, b) => a.sortOrder.compareTo(b.sortOrder),
      );

    final currentIndex = attributes.indexWhere(
      (attribute) => attribute.attributeId == currentAttributeId,
    );

    if (currentIndex == -1) {
      return;
    }

    for (var i = currentIndex + 1; i < attributes.length; i++) {
      final attribute = attributes[i];

      selectedIds.remove(attribute.slug);
      selectedValues.remove(attribute.slug);
      optionsMap.remove(attribute.slug);
    }
  }

  // ============================================================
  // LOAD RESULTS
  // ============================================================

  Future<void> _onLoadResults(
    LoadMarketplaceResults event,
    Emitter<MarketplaceState> emit,
  ) async {
    final categoryId = state.categoryId;

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

      if (isClosed) return;

      if (requestId != _resultsRequestId) {
        return;
      }

      if (state.categoryId != categoryId) {
        return;
      }

      emit(
        state.copyWith(
          isLoadingResults: false,
          offers: offers,
        ),
      );
    } catch (error) {
      if (isClosed) return;

      if (requestId != _resultsRequestId) {
        return;
      }

      if (state.categoryId != categoryId) {
        return;
      }

      emit(
        state.copyWith(
          isLoadingResults: false,
          errorMessage: _friendlyError(error),
        ),
      );
    }
  }

  // ============================================================
  // RESET
  // ============================================================

  void _onReset(
    ResetMarketplaceFilters event,
    Emitter<MarketplaceState> emit,
  ) {
    _optionsRequestId++;
    _resultsRequestId++;
    _nextAttributeRequestId++;

    emit(
      state.copyWith(
        optionsByAttribute: const <String, List<MarketplaceAttributeOption>>{},
        selectedOptionIds: const <String, String>{},
        selectedValues: const <String, String>{},
        offers: const [],
        clearError: true,
      ),
    );

    final attributes = List<MarketplaceAttribute>.from(state.attributes)
      ..sort(
        (a, b) => a.sortOrder.compareTo(b.sortOrder),
      );

    if (attributes.isNotEmpty) {
      add(
        LoadMarketplaceOptions(
          attribute: attributes.first,
        ),
      );
    }

    add(const LoadMarketplaceResults());
  }

  // ============================================================
  // FRIENDLY ERROR
  // ============================================================

  String _friendlyError(Object error) {
    final raw = error.toString().trim();

    final message = raw
        .replaceFirst(
          'PostgrestException(message:',
          '',
        )
        .replaceFirst(
          'Exception:',
          '',
        )
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
