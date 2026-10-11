import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:loqma/features/community/data/repositories/community_my_offers_repository.dart';

class CommunityOfferEditDialog extends StatefulWidget {
  const CommunityOfferEditDialog({
    super.key,
    required this.offer,
  });

  final Map<String, dynamic> offer;

  @override
  State<CommunityOfferEditDialog> createState() =>
      _CommunityOfferEditDialogState();
}

class _CommunityOfferEditDialogState extends State<CommunityOfferEditDialog> {
  final _client = Supabase.instance.client;
  final _repository = CommunityMyOffersRepository();
  final _titleController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _loading = true;
  bool _saving = false;
  bool _loadFailed = false;
  bool _canEditName = true;
  String? _error;
  String _categoryName = '';
  List<_EditableOfferAttribute> _attributes = [];

  @override
  void initState() {
    super.initState();
    _titleController.text = widget.offer['title']?.toString() ?? '';
    final editCount =
        int.tryParse(widget.offer['edit_count']?.toString() ?? '') ?? 0;
    _canEditName = editCount < 1;
    _loadAttributes();
  }

  @override
  void dispose() {
    _titleController.dispose();
    for (final attribute in _attributes) {
      attribute.dispose();
    }
    super.dispose();
  }

  Future<void> _loadAttributes() async {
    try {
      final offerId = widget.offer['id']?.toString() ?? '';
      if (offerId.isEmpty) throw StateError('بيانات العرض غير مكتملة.');

      final marketplaceOffer = await _client
          .from('marketplace_offers')
          .select('id, marketplace_category_id')
          .eq('source_type', 'community')
          .eq('source_id', offerId)
          .maybeSingle();

      if (marketplaceOffer == null) {
        throw StateError('تعذر تحميل مواصفات العرض.');
      }

      final marketplaceOfferId = marketplaceOffer['id']?.toString() ?? '';
      final categoryId =
          marketplaceOffer['marketplace_category_id']?.toString() ?? '';
      if (marketplaceOfferId.isEmpty || categoryId.isEmpty) {
        throw StateError('التصنيف المرتبط بالعرض غير متاح.');
      }

      final linksRaw = await _client
          .from('marketplace_category_attributes')
          .select(
            'attribute_id, sort_order, is_required, is_for_offer_creation, is_for_display',
          )
          .eq('category_id', categoryId)
          .eq('is_for_offer_creation', true)
          .eq('is_for_display', true);
      final links = (linksRaw as List)
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .where((row) => (row['attribute_id']?.toString() ?? '').isNotEmpty)
          .toList();

      final existingRaw = await _client
          .from('marketplace_offer_attributes')
          .select(
            'attribute_id, option_id, value_text, value_number, value_boolean',
          )
          .eq('marketplace_offer_id', marketplaceOfferId);
      final existing = <String, Map<String, dynamic>>{
        for (final row in (existingRaw as List).whereType<Map>())
          row['attribute_id'].toString(): Map<String, dynamic>.from(row),
      };

      final ids = links
          .map((row) => row['attribute_id'].toString())
          .toSet()
          .toList();
      final definitions = ids.isEmpty
          ? <Map<String, dynamic>>[]
          : (await _client
                  .from('marketplace_attributes')
                  .select('id, slug, name_ar, input_type')
                  .inFilter('id', ids)
                  .eq('is_active', true) as List)
              .whereType<Map>()
              .map((row) => Map<String, dynamic>.from(row))
              .toList();

      final linkById = <String, Map<String, dynamic>>{
        for (final row in links) row['attribute_id'].toString(): row,
      };
      definitions.sort((a, b) {
        final aOrder = (linkById[a['id']?.toString()]?['sort_order'] as num?)
                ?.toInt() ??
            0;
        final bOrder = (linkById[b['id']?.toString()]?['sort_order'] as num?)
                ?.toInt() ??
            0;
        return aOrder.compareTo(bOrder);
      });

      final loaded = <_EditableOfferAttribute>[];
      for (final definition in definitions) {
        final id = definition['id']?.toString() ?? '';
        final link = linkById[id];
        if (id.isEmpty || link == null) continue;

        final type = definition['input_type']?.toString() ?? 'text';
        final previous = existing[id] ?? const <String, dynamic>{};
        var options = <Map<String, dynamic>>[];
        if (type == 'select') {
          final optionsRaw = await _client
              .from('marketplace_attribute_options')
              .select('id, parent_option_id, value, label_ar, sort_order')
              .eq('attribute_id', id)
              .eq('is_active', true)
              .order('sort_order');
          options = (optionsRaw as List)
              .whereType<Map>()
              .map((row) => Map<String, dynamic>.from(row))
              .toList();
          if (options.any((option) => option['parent_option_id'] != null)) {
            options = options
                .where((option) => option['parent_option_id'] == null)
                .toList();
          }
        }

        final oldNumber = previous['value_number'];
        final oldValue = previous['value_text']?.toString() ??
            (oldNumber == null
                ? ''
                : oldNumber is num && oldNumber == oldNumber.toInt()
                    ? oldNumber.toInt().toString()
                    : oldNumber.toString());
        loaded.add(
          _EditableOfferAttribute(
            id: id,
            slug: definition['slug']?.toString() ?? '',
            label: definition['name_ar']?.toString().trim().isNotEmpty == true
                ? definition['name_ar'].toString()
                : 'المواصفة',
            inputType: type,
            required: link['is_required'] == true,
            options: options,
            selectedOptionId: previous['option_id']?.toString(),
            textController: TextEditingController(text: oldValue),
            booleanValue: previous['value_boolean'] as bool?,
          ),
        );
      }

      if (!mounted) {
        for (final attribute in loaded) {
          attribute.dispose();
        }
        return;
      }

      final rawCategory = widget.offer['marketplace_categories'];
      final categoryRow = rawCategory is Map
          ? Map<String, dynamic>.from(rawCategory)
          : <String, dynamic>{};
      final categoryName = categoryRow['name_ar']?.toString().trim() ??
          widget.offer['category_name']?.toString().trim() ??
          widget.offer['category']?.toString().trim() ??
          '';
      var displayCategoryName = categoryName;
      try {
        final category = await _client
            .from('marketplace_categories')
            .select('name_ar')
            .eq('id', categoryId)
            .maybeSingle();
        final loadedName = category?['name_ar']?.toString().trim() ?? '';
        if (loadedName.isNotEmpty) displayCategoryName = loadedName;
      } catch (_) {
        // Keep the category label already present on the offer as a fallback.
      }
      if (!mounted) {
        for (final attribute in loaded) {
          attribute.dispose();
        }
        return;
      }

      setState(() {
        _attributes = loaded;
        _categoryName = displayCategoryName.isEmpty
            ? 'تصنيف العرض الحالي'
            : displayCategoryName;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error is StateError
            ? error.message.toString()
            : 'تعذر تحميل مواصفات العرض. تحقق من اتصالك ثم حاول مرة أخرى.';
        _loading = false;
        _loadFailed = true;
      });
    }
  }

  Future<void> _save() async {
    if (_saving || _loading || !_formKey.currentState!.validate()) return;

    final payload = <Map<String, dynamic>>[];
    for (final attribute in _attributes) {
      if (attribute.inputType == 'select') {
        final optionId = attribute.selectedOptionId;
        if (optionId == null || optionId.isEmpty) continue;
        payload.add({'attribute_id': attribute.id, 'option_id': optionId});
      } else if (attribute.inputType == 'number' ||
          attribute.inputType == 'decimal') {
        final text = attribute.textController.text.trim();
        if (text.isEmpty) continue;
        final number = num.tryParse(text);
        if (number == null || !number.isFinite || (attribute.required && number <= 0)) {
          _showError('أدخل ${attribute.label} بشكل صحيح.');
          return;
        }
        payload.add({'attribute_id': attribute.id, 'value_number': number});
      } else if (const {'boolean', 'checkbox', 'toggle'}
          .contains(attribute.inputType)) {
        final value = attribute.booleanValue;
        if (value == null) continue;
        payload.add({'attribute_id': attribute.id, 'value_boolean': value});
      } else {
        final value = attribute.textController.text.trim();
        if (value.isEmpty) continue;
        payload.add({'attribute_id': attribute.id, 'value_text': value});
      }
    }

    for (final attribute in _attributes.where((item) => item.required)) {
      final hasValue = switch (attribute.inputType) {
        'select' => (attribute.selectedOptionId ?? '').isNotEmpty,
        'number' || 'decimal' => attribute.textController.text.trim().isNotEmpty,
        'boolean' || 'checkbox' || 'toggle' => attribute.booleanValue != null,
        _ => attribute.textController.text.trim().isNotEmpty,
      };
      if (!hasValue) {
        _showError('أكمل المواصفة المطلوبة: ${attribute.label}.');
        return;
      }
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await _repository.updateOfferNameAndAttributes(
        offerId: widget.offer['id'].toString(),
        title: _titleController.text.trim(),
        attributes: payload,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error =
              'تعذر حفظ التعديل. ${error.toString().replaceFirst('Exception: ', '')}';
        });
      }
    }
  }

  void _showError(String message) {
    setState(() => _error = message);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.88,
            maxWidth: 520,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'تعديل العرض',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'يمكنك تعديل الاسم والمواصفات فقط',
                            style: TextStyle(color: colors.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _saving ? null : () => Navigator.pop(context),
                      tooltip: 'إغلاق',
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: _loading
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    : Form(
                        key: _formKey,
                        child: ListView(
                          shrinkWrap: true,
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: colors.primary.withValues(alpha: 0.07),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.lock_outline_rounded,
                                    color: colors.primary,
                                    size: 19,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'التصنيف ثابت: $_categoryName',
                                      style: TextStyle(
                                        color: colors.primary,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _titleController,
                              enabled: _canEditName,
                              maxLength: 120,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'اسم المنتج',
                                prefixIcon: Icon(Icons.sell_outlined),
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) {
                                if (!_canEditName) return null;
                                final title = value?.trim() ?? '';
                                if (title.length < 3) {
                                  return 'اكتب اسمًا من 3 أحرف على الأقل';
                                }
                                return null;
                              },
                            ),
                            if (!_canEditName)
                              Padding(
                                padding: const EdgeInsets.only(top: 2, bottom: 8),
                                child: Text(
                                  'تم استخدام التعديل المتاح للاسم؛ يمكنك تعديل المواصفات فقط.',
                                  style: TextStyle(
                                    color: colors.onSurfaceVariant,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            if (_attributes.isEmpty && _error == null)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: Text(
                                  'لا توجد مواصفات إضافية لهذا التصنيف.',
                                  style: TextStyle(color: colors.onSurfaceVariant),
                                ),
                              ),
                            for (final attribute in _attributes) ...[
                              const SizedBox(height: 8),
                              _buildAttributeField(attribute, colors),
                            ],
                            if (_error != null) ...[
                              const SizedBox(height: 12),
                              Text(
                                _error!,
                                style: TextStyle(
                                  color: colors.error,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _saving ? null : () => Navigator.pop(context),
                        child: const Text('إلغاء'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _loading || _saving || _loadFailed
                            ? null
                            : _save,
                        icon: _saving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.save_outlined, size: 18),
                        label: Text(_saving ? 'جارٍ الحفظ' : 'حفظ التعديل'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAttributeField(
    _EditableOfferAttribute attribute,
    ColorScheme colors,
  ) {
    final label = attribute.required ? '${attribute.label} *' : attribute.label;
    if (attribute.inputType == 'select') {
      final optionIds = attribute.options
          .map((option) => option['id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toSet();
      final selected = optionIds.contains(attribute.selectedOptionId)
          ? attribute.selectedOptionId
          : null;
      return DropdownButtonFormField<String>(
        value: selected,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        items: [
          for (final option in attribute.options)
            DropdownMenuItem<String>(
              value: option['id']?.toString(),
              child: Text(
                (option['label_ar']?.toString().trim().isNotEmpty == true
                        ? option['label_ar']
                        : option['value'])
                    .toString(),
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
        onChanged: (value) => setState(() => attribute.selectedOptionId = value),
      );
    }

    if (const {'boolean', 'checkbox', 'toggle'}.contains(attribute.inputType)) {
      return DropdownButtonFormField<bool>(
        value: attribute.booleanValue,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        items: const [
          DropdownMenuItem(value: true, child: Text('نعم')),
          DropdownMenuItem(value: false, child: Text('لا')),
        ],
        onChanged: (value) => setState(() => attribute.booleanValue = value),
      );
    }

    final isNumeric =
        attribute.inputType == 'number' || attribute.inputType == 'decimal';
    return TextFormField(
      controller: attribute.textController,
      keyboardType: isNumeric
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      validator: (value) {
        final text = value?.trim() ?? '';
        if (attribute.required && text.isEmpty) return 'هذا الحقل مطلوب';
        if (isNumeric && text.isNotEmpty) {
          final number = num.tryParse(text);
          if (number == null || !number.isFinite || (attribute.required && number <= 0)) {
            return 'أدخل رقمًا أكبر من صفر';
          }
        }
        return null;
      },
    );
  }
}

class _EditableOfferAttribute {
  _EditableOfferAttribute({
    required this.id,
    required this.slug,
    required this.label,
    required this.inputType,
    required this.required,
    required this.options,
    required this.selectedOptionId,
    required this.textController,
    required this.booleanValue,
  });

  final String id;
  final String slug;
  final String label;
  final String inputType;
  final bool required;
  final List<Map<String, dynamic>> options;
  String? selectedOptionId;
  final TextEditingController textController;
  bool? booleanValue;

  void dispose() => textController.dispose();
}
