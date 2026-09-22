// lib/features/marketplace/presentation/pages/marketplace_category_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/marketplace_attribute.dart';
import '../bloc/marketplace_bloc.dart';
import '../bloc/marketplace_event.dart';
import '../bloc/marketplace_state.dart';
import '../widgets/marketplace_attribute_selector.dart';
import 'marketplace_results_page.dart';

class MarketplaceCategoryPage extends StatelessWidget {
  final String categoryId;
  final String categoryName;

  const MarketplaceCategoryPage({
    super.key,
    required this.categoryId,
    required this.categoryName,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => MarketplaceBloc()
        ..add(
          LoadMarketplaceCategory(
            categoryId: categoryId,
            categoryName: categoryName,
          ),
        ),
      child: _MarketplaceCategoryView(
        categoryName: categoryName,
      ),
    );
  }
}

class _MarketplaceCategoryView extends StatelessWidget {
  final String categoryName;

  const _MarketplaceCategoryView({
    required this.categoryName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          categoryName,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
        centerTitle: true,
      ),
      body: BlocConsumer<MarketplaceBloc, MarketplaceState>(
        listener: (context, state) {
          if (state.errorMessage != null && state.errorMessage!.isNotEmpty) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  content: Text(
                    state.errorMessage!,
                    textAlign: TextAlign.right,
                  ),
                ),
              );
          }
        },
        builder: (context, state) {
          // ------------------------------------------------------
          // Initial loading
          // ------------------------------------------------------

          if (state.isLoading && state.attributes.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          // ------------------------------------------------------
          // No attributes
          // ------------------------------------------------------

          if (state.attributes.isEmpty) {
            return _EmptyState(
              message: 'لا توجد فلاتر متاحة لهذا القسم حاليًا',
              onRetry: () {
                final currentCategoryId = state.categoryId;

                if (currentCategoryId == null || currentCategoryId.isEmpty) {
                  return;
                }

                context.read<MarketplaceBloc>().add(
                      LoadMarketplaceCategory(
                        categoryId: currentCategoryId,
                        categoryName: state.categoryName ?? categoryName,
                      ),
                    );
              },
            );
          }

          return _buildContent(
            context,
            state,
          );
        },
      ),
    );
  }

  // ============================================================
  // CONTENT
  // ============================================================

  Widget _buildContent(
    BuildContext context,
    MarketplaceState state,
  ) {
    final visibleAttributes = _getVisibleAttributes(state);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          18,
          18,
          18,
          30,
        ),
        children: [
          Text(
            'حدد المواصفات التي تبحث عنها',
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w900,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            'الاختيارات التالية يتم تحديدها تلقائيًا حسب القسم واختيارك السابق.',
            textAlign: TextAlign.right,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),

          const SizedBox(height: 24),

          // ------------------------------------------------------
          // Dynamic attributes
          // ------------------------------------------------------

          ...visibleAttributes.map(
            (attribute) {
              return Padding(
                padding: const EdgeInsets.only(
                  bottom: 20,
                ),
                child: _buildAttribute(
                  context: context,
                  state: state,
                  attribute: attribute,
                ),
              );
            },
          ),

          // ------------------------------------------------------
          // Loading next attribute
          // ------------------------------------------------------

          if (state.isLoadingOptions && visibleAttributes.isNotEmpty)
            const Padding(
              padding: EdgeInsets.only(
                bottom: 12,
              ),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                ),
              ),
            ),

          const SizedBox(height: 5),

          // ------------------------------------------------------
          // Results button
          // ------------------------------------------------------

          SizedBox(
            height: 54,
            child: FilledButton(
              onPressed: state.hasRequiredSelections && !state.isLoadingResults
                  ? () {
                      context.read<MarketplaceBloc>().add(
                            const LoadMarketplaceResults(),
                          );

                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const MarketplaceResultsPage(),
                        ),
                      );
                    }
                  : null,
              child: state.isLoadingResults
                  ? const SizedBox(
                      width: 23,
                      height: 23,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'عرض النتائج',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // BUILD ATTRIBUTE
  // ============================================================
  //
  // select  -> Dropdown / option selector
  // number  -> Numeric text field
  // text    -> Normal text field
  //
  // ============================================================

  Widget _buildAttribute({
    required BuildContext context,
    required MarketplaceState state,
    required MarketplaceAttribute attribute,
  }) {
    final inputType = attribute.inputType.trim().toLowerCase();

    switch (inputType) {
      case 'number':
        return _NumberAttributeField(
          attribute: attribute,
          currentValue: state.selectedValues[attribute.slug],
          isRequired: attribute.isRequired,
          isLoading:
              state.isLoadingOptions && !_hasLoadedOptions(state, attribute),
          onSubmitted: (value) {
            _submitValue(
              context: context,
              attribute: attribute,
              value: value,
            );
          },
        );

      case 'text':
      case 'textarea':
        return _TextAttributeField(
          attribute: attribute,
          currentValue: state.selectedValues[attribute.slug],
          isRequired: attribute.isRequired,
          onSubmitted: (value) {
            _submitValue(
              context: context,
              attribute: attribute,
              value: value,
            );
          },
        );

      case 'select':
      default:
        return _buildSelectAttribute(
          context: context,
          state: state,
          attribute: attribute,
        );
    }
  }

  // ============================================================
  // SELECT ATTRIBUTE
  // ============================================================

  Widget _buildSelectAttribute({
    required BuildContext context,
    required MarketplaceState state,
    required MarketplaceAttribute attribute,
  }) {
    final options = state.optionsByAttribute[attribute.slug] ?? const [];

    final selectedId = state.selectedOptionIds[attribute.slug];

    final isFirstAttribute = _isFirstAttribute(
      state,
      attribute,
    );

    final isLoadingThisAttribute = state.isLoadingOptions &&
        options.isEmpty &&
        (isFirstAttribute ||
            _isWaitingForOptions(
              state,
              attribute,
            ));

    return MarketplaceAttributeSelector(
      attribute: attribute,
      options: options,
      selectedOptionId: selectedId,
      enabled: true,
      isLoading: isLoadingThisAttribute,
      onSelected: (option) {
        context.read<MarketplaceBloc>().add(
              SelectMarketplaceOption(
                attribute: attribute,
                optionId: option.id,
                value: option.value,
              ),
            );
      },
    );
  }

  // ============================================================
  // SUBMIT NUMBER / TEXT VALUE
  // ============================================================

  void _submitValue({
    required BuildContext context,
    required MarketplaceAttribute attribute,
    required String value,
  }) {
    final cleanValue = value.trim();

    if (cleanValue.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              attribute.isRequired
                  ? 'من فضلك أدخل ${attribute.nameAr}'
                  : 'من فضلك أدخل قيمة صحيحة',
              textAlign: TextAlign.right,
            ),
          ),
        );

      return;
    }

    context.read<MarketplaceBloc>().add(
          SelectMarketplaceOption(
            attribute: attribute,
            optionId: '',
            value: cleanValue,
          ),
        );
  }

  // ============================================================
  // GET VISIBLE ATTRIBUTES
  // ============================================================
  //
  // We don't display every attribute immediately.
  //
  // First:
  //
  // Brand
  //
  // After selecting Brand:
  //
  // Brand
  // Model
  //
  // After selecting Model:
  //
  // Brand
  // Model
  // Year
  //
  // For number/text fields, the Bloc loads the next attribute
  // and stores an entry in optionsByAttribute even when there
  // are no options. Therefore containsKey() is enough to make
  // the attribute visible.
  //
  // ============================================================

  List<MarketplaceAttribute> _getVisibleAttributes(
    MarketplaceState state,
  ) {
    if (state.attributes.isEmpty) {
      return const [];
    }

    final sortedAttributes = List<MarketplaceAttribute>.from(
      state.attributes,
    )..sort(
        (a, b) => a.sortOrder.compareTo(b.sortOrder),
      );

    final visible = <MarketplaceAttribute>[];

    for (final attribute in sortedAttributes) {
      final hasLoadedOptions = state.optionsByAttribute.containsKey(
        attribute.slug,
      );

      final hasSelection = state.selectedValues.containsKey(
        attribute.slug,
      );

      final isFirst =
          attribute.attributeId == sortedAttributes.first.attributeId;

      if (isFirst || hasLoadedOptions || hasSelection) {
        visible.add(attribute);
      }
    }

    return visible;
  }

  // ============================================================
  // IS FIRST ATTRIBUTE
  // ============================================================

  bool _isFirstAttribute(
    MarketplaceState state,
    MarketplaceAttribute attribute,
  ) {
    if (state.attributes.isEmpty) {
      return false;
    }

    final sortedAttributes = List<MarketplaceAttribute>.from(
      state.attributes,
    )..sort(
        (a, b) => a.sortOrder.compareTo(b.sortOrder),
      );

    return sortedAttributes.first.attributeId == attribute.attributeId;
  }

  // ============================================================
  // HAS LOADED OPTIONS
  // ============================================================

  bool _hasLoadedOptions(
    MarketplaceState state,
    MarketplaceAttribute attribute,
  ) {
    return state.optionsByAttribute.containsKey(
      attribute.slug,
    );
  }

  // ============================================================
  // WAITING FOR OPTIONS
  // ============================================================

  bool _isWaitingForOptions(
    MarketplaceState state,
    MarketplaceAttribute attribute,
  ) {
    if (state.optionsByAttribute.containsKey(
      attribute.slug,
    )) {
      return false;
    }

    if (state.selectedValues.containsKey(
      attribute.slug,
    )) {
      return false;
    }

    return true;
  }
}

// ================================================================
// NUMBER ATTRIBUTE FIELD
// ================================================================

class _NumberAttributeField extends StatefulWidget {
  final MarketplaceAttribute attribute;
  final String? currentValue;
  final bool isRequired;
  final bool isLoading;
  final ValueChanged<String> onSubmitted;

  const _NumberAttributeField({
    required this.attribute,
    required this.currentValue,
    required this.isRequired,
    required this.isLoading,
    required this.onSubmitted,
  });

  @override
  State<_NumberAttributeField> createState() => _NumberAttributeFieldState();
}

class _NumberAttributeFieldState extends State<_NumberAttributeField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();

    _controller = TextEditingController(
      text: widget.currentValue ?? '',
    );
  }

  @override
  void didUpdateWidget(
    covariant _NumberAttributeField oldWidget,
  ) {
    super.didUpdateWidget(oldWidget);

    final newValue = widget.currentValue ?? '';

    if (newValue != _controller.text) {
      _controller.value = TextEditingValue(
        text: newValue,
        selection: TextSelection.collapsed(
          offset: newValue.length,
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _AttributeInputContainer(
      attribute: widget.attribute,
      child: TextField(
        controller: _controller,
        keyboardType: const TextInputType.numberWithOptions(
          decimal: true,
        ),
        textInputAction: TextInputAction.next,
        inputFormatters: [
          FilteringTextInputFormatter.allow(
            RegExp(r'[0-9.]'),
          ),
        ],
        textAlign: TextAlign.right,
        enabled: !widget.isLoading,
        decoration: InputDecoration(
          hintText: _numberHint(
            widget.attribute.slug,
          ),
          suffixText: _numberSuffix(
            widget.attribute.slug,
          ),
          prefixIcon: const Icon(
            Icons.numbers_rounded,
          ),
        ),
        onSubmitted: widget.onSubmitted,
      ),
    );
  }

  String? _numberHint(String slug) {
    switch (slug) {
      case 'year':
        return 'مثال: 2022';

      case 'kilometers':
        return 'مثال: 80000';

      case 'down_payment':
        return 'مثال: 100000';

      case 'engine_capacity':
        return 'مثال: 1600';

      default:
        return 'أدخل القيمة';
    }
  }

  String? _numberSuffix(String slug) {
    switch (slug) {
      case 'year':
        return 'سنة';

      case 'kilometers':
        return 'كم';

      case 'down_payment':
        return 'جنيه';

      case 'engine_capacity':
        return 'cc';

      default:
        return null;
    }
  }
}

// ================================================================
// TEXT ATTRIBUTE FIELD
// ================================================================

class _TextAttributeField extends StatefulWidget {
  final MarketplaceAttribute attribute;
  final String? currentValue;
  final bool isRequired;
  final ValueChanged<String> onSubmitted;

  const _TextAttributeField({
    required this.attribute,
    required this.currentValue,
    required this.isRequired,
    required this.onSubmitted,
  });

  @override
  State<_TextAttributeField> createState() => _TextAttributeFieldState();
}

class _TextAttributeFieldState extends State<_TextAttributeField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();

    _controller = TextEditingController(
      text: widget.currentValue ?? '',
    );
  }

  @override
  void didUpdateWidget(
    covariant _TextAttributeField oldWidget,
  ) {
    super.didUpdateWidget(oldWidget);

    final newValue = widget.currentValue ?? '';

    if (newValue != _controller.text) {
      _controller.value = TextEditingValue(
        text: newValue,
        selection: TextSelection.collapsed(
          offset: newValue.length,
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _AttributeInputContainer(
      attribute: widget.attribute,
      child: TextField(
        controller: _controller,
        keyboardType: TextInputType.text,
        textInputAction: TextInputAction.next,
        textAlign: TextAlign.right,
        maxLines: 1,
        decoration: InputDecoration(
          hintText: 'مثال: ${widget.attribute.nameAr}',
          prefixIcon: const Icon(
            Icons.edit_outlined,
          ),
        ),
        onSubmitted: widget.onSubmitted,
      ),
    );
  }
}

// ================================================================
// ATTRIBUTE INPUT CONTAINER
// ================================================================

class _AttributeInputContainer extends StatelessWidget {
  final MarketplaceAttribute attribute;
  final Widget child;

  const _AttributeInputContainer({
    required this.attribute,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (attribute.isRequired)
              Text(
                'مطلوب',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.primary,
                ),
              ),
            Expanded(
              child: Text(
                attribute.nameAr,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

// ================================================================
// EMPTY STATE
// ================================================================

class _EmptyState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _EmptyState({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.filter_alt_off_outlined,
              size: 60,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            OutlinedButton(
              onPressed: onRetry,
              child: const Text(
                'إعادة المحاولة',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
