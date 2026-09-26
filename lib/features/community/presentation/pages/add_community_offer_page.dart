// lib/features/community/presentation/pages/add_community_offer_page.dart

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:loqma/features/auth/presentation/pages/location_picker_page.dart';
import 'package:loqma/features/community/data/repositories/community_offer_repository.dart';
import 'package:loqma/features/marketplace/data/repositories/marketplace_repository_impl.dart';
import 'package:loqma/features/marketplace/domain/entities/marketplace_attribute.dart';
import 'package:loqma/features/marketplace/domain/entities/marketplace_attribute_option.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

T? _firstWhereOrNull<T>(Iterable<T> items, bool Function(T) test) {
  for (final item in items) {
    if (test(item)) return item;
  }
  return null;
}

class AddCommunityOfferPage extends StatefulWidget {
  final Future<void> Function(Map<String, dynamic> draft)? onSubmit;
  final String? offerId;
  final Map<String, dynamic>? initialData;

  const AddCommunityOfferPage({
    super.key,
    this.onSubmit,
    this.offerId,
    this.initialData,
  });

  bool get isEditMode => offerId != null && offerId!.trim().isNotEmpty;

  @override
  State<AddCommunityOfferPage> createState() => _AddCommunityOfferPageState();
}

class _AddCommunityOfferPageState extends State<AddCommunityOfferPage> {
  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  final _priceController = TextEditingController();
  final _locationController = TextEditingController();
  final _phoneController = TextEditingController();
  final _whatsappController = TextEditingController();

  final _picker = ImagePicker();

  final _repository = CommunityOfferRepository();
  final _marketplaceRepository = MarketplaceRepositoryImpl();

  static const String _listingType = 'symbolic_sale';

  String? _categoryId;
  String? _categorySlug;
  String? _categoryNameAr;
  String? _marketplaceCategoryId;

  String _attributesStatus = 'idle';

  double? _lat;
  double? _lng;

  List<MarketplaceAttribute> _marketplaceAttributes = [];
  final Map<String, List<MarketplaceAttributeOption>> _marketplaceOptions = {};
  final Map<String, String> _selectedMarketplaceOptionIds = {};
  final Map<String, String> _selectedMarketplaceValues = {};
  final Map<String, String> _selectedMarketplaceValueTypes = {};

  bool _isLoadingMarketplaceAttributes = false;
  final Set<String> _optionsLoading = {};

  int _categoryRequestId = 0;

  List<Map<String, dynamic>> _prefilledAttributeData = [];
  bool _prefillApplied = false;

  final List<XFile> _newImages = [];
  final List<String> _keptImagePaths = [];
  final List<String> _removedImagePaths = [];
  final List<String> _existingImageUrls = [];

  String _expiryOption = '7_days';
  bool _termsAccepted = false;

  bool _isSubmitting = false;
  bool _isLoadingCategories = false;
  bool _isInitializing = false;

  List<Map<String, dynamic>> _categories = const [];

  @override
  void initState() {
    super.initState();
    if (widget.isEditMode) {
      _isInitializing = true;
      _prefillFromInitialData();
    }
    _loadCategories();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    _locationController.dispose();
    _phoneController.dispose();
    _whatsappController.dispose();
    super.dispose();
  }

  bool get _isCars =>
      _categorySlug == 'cars' ||
      _categorySlug == 'cars-parts' ||
      _categorySlug == 'passenger-cars' ||
      _categorySlug == 'trucks';
  bool get _isEditMode => widget.isEditMode;
  int get _totalImages => _keptImagePaths.length + _newImages.length;

  String get _currentCategoryName {
    if (_categoryNameAr != null && _categoryNameAr!.isNotEmpty) {
      return _categoryNameAr!;
    }
    if (_categoryId == null) return '';
    for (final c in _categories) {
      if (c['id']?.toString() == _categoryId) {
        return c['name_ar']?.toString() ?? '';
      }
    }
    return '';
  }

  int get _requiredAttributesCount =>
      _marketplaceAttributes.where((a) => a.isRequired).length;
  int get _optionalAttributesCount =>
      _marketplaceAttributes.where((a) => !a.isRequired).length;

  // ═══════════════════════════════════════════════════════════
  // Prefill
  // ═══════════════════════════════════════════════════════════
  void _prefillFromInitialData() {
    final data = widget.initialData;
    if (data == null) {
      _isInitializing = false;
      return;
    }

    _titleController.text = data['title']?.toString() ?? '';
    _descriptionController.text = data['description']?.toString() ?? '';
    _locationController.text = data['pickup_location']?.toString() ?? '';

    _lat = (data['latitude'] as num?)?.toDouble();
    _lng = (data['longitude'] as num?)?.toDouble();

    _phoneController.text = data['phone']?.toString() ?? '';
    _whatsappController.text = data['whatsapp']?.toString() ?? '';

    final price = data['price'];
    if (price != null) {
      final p = price is num
          ? price.toDouble()
          : double.tryParse(price.toString()) ?? 0;
      if (p > 0) _priceController.text = p.toStringAsFixed(0);
    }

    final quantity = data['quantity'];
    if (quantity != null) {
      final q = quantity is num
          ? quantity.toInt()
          : int.tryParse(quantity.toString()) ?? 1;
      _quantityController.text = q.toString();
    }

    _categoryId = data['category_id']?.toString();
    _categorySlug = data['category']?.toString();
    _categoryNameAr = data['category_name']?.toString();
    _marketplaceCategoryId = data['marketplace_category_id']?.toString();

    _expiryOption = _deriveExpiryOption(data['expires_at']);

    final rawAttrs = data['marketplace_attributes'];
    if (rawAttrs is List) {
      _prefilledAttributeData = rawAttrs
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }

    final rawImages = data['images'];
    final rawImage = data['image']?.toString();

    final imageUrls = <String>[];

    if (rawImages is List) {
      for (final raw in rawImages) {
        final value = raw?.toString();
        if (value == null || value.isEmpty || value == 'null') continue;
        imageUrls.add(value);
      }
    }

    if (imageUrls.isEmpty && rawImage != null && rawImage.isNotEmpty) {
      imageUrls.add(rawImage);
    }

    _existingImageUrls.addAll(imageUrls);
    for (final url in imageUrls) {
      _keptImagePaths.add(_extractStoragePath(url));
    }

    _termsAccepted = true;
  }

  String _deriveExpiryOption(dynamic expiresAt) {
    if (expiresAt == null) return 'never';
    final text = expiresAt.toString().trim();
    if (text.isEmpty || text == 'null') return 'never';
    final date = DateTime.tryParse(text);
    if (date == null) return '7_days';
    final diff = date.difference(DateTime.now());
    if (diff.inDays <= 7) return '7_days';
    if (diff.inDays <= 14) return '14_days';
    if (diff.inDays <= 30) return '30_days';
    return '30_days';
  }

  String _extractStoragePath(String url) {
    if (url.isEmpty) return '';
    try {
      final uri = Uri.parse(url);
      final segments = uri.pathSegments;
      final index = segments.indexOf('community-offers');
      if (index != -1 && index < segments.length - 1) {
        return segments.sublist(index + 1).join('/');
      }
    } catch (_) {}
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      return url;
    }
    return '';
  }

  bool _isValidEgyptianPhone(String phone) {
    final cleaned = phone.replaceAll(RegExp(r'[^\d]'), '');
    if (cleaned.length != 11) return false;
    if (!cleaned.startsWith('01')) return false;
    return true;
  }

  bool _hasUnsavedData() {
    if (_isEditMode) {
      if (_isInitializing) return false;
      final data = widget.initialData;
      if (data == null) return false;

      final origTitle = data['title']?.toString().trim() ?? '';
      final origDesc = data['description']?.toString().trim() ?? '';
      final origLoc = data['pickup_location']?.toString().trim() ?? '';
      final origPhone = data['phone']?.toString().trim() ?? '';
      final origWhatsapp = data['whatsapp']?.toString().trim() ?? '';

      if (_titleController.text.trim() != origTitle) return true;
      if (_descriptionController.text.trim() != origDesc) return true;
      if (_locationController.text.trim() != origLoc) return true;
      if (_phoneController.text.trim() != origPhone) return true;
      if (_whatsappController.text.trim() != origWhatsapp) return true;

      final origLat = (data['latitude'] as num?)?.toDouble();
      final origLng = (data['longitude'] as num?)?.toDouble();
      if (_lat != origLat) return true;
      if (_lng != origLng) return true;

      if (_newImages.isNotEmpty) return true;
      if (_removedImagePaths.isNotEmpty) return true;
      return false;
    }

    if (_titleController.text.trim().isNotEmpty) return true;
    if (_descriptionController.text.trim().isNotEmpty) return true;
    if (_priceController.text.trim().isNotEmpty) return true;
    if (_locationController.text.trim().isNotEmpty) return true;
    if (_phoneController.text.trim().isNotEmpty) return true;
    if (_whatsappController.text.trim().isNotEmpty) return true;

    final qty = _quantityController.text.trim();
    if (qty.isNotEmpty && qty != '1') return true;

    if (_newImages.isNotEmpty) return true;
    if (_categoryId != null && _categoryId!.isNotEmpty) return true;
    if (_selectedMarketplaceOptionIds.isNotEmpty) return true;
    if (_selectedMarketplaceValues.isNotEmpty) return true;
    if (_expiryOption != '7_days') return true;
    if (_termsAccepted) return true;
    return false;
  }

  Future<bool> _confirmExit() async {
    final colors = Theme.of(context).colorScheme;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        icon: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: colors.error.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.warning_amber_rounded,
            color: colors.error,
            size: 32,
          ),
        ),
        title: const Text(
          'هل أنت متأكد؟',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
        content: Text(
          _isEditMode
              ? 'لو خرجت دلوقتي، كل التعديلات اللي عملتها هتضيع ومش هتقدر ترجعها تاني.'
              : 'لو خرجت دلوقتي، كل البيانات اللي كتبتها هتضيع ومش هتقدر ترجعها تاني.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            style: TextButton.styleFrom(
              foregroundColor: colors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            child: const Text(
              'كمّل التعديل',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: colors.error,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'اخرج',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  // ═══════════════════════════════════════════════════════════
  // Categories
  // ═══════════════════════════════════════════════════════════
  Future<void> _loadCategories() async {
    if (mounted) setState(() => _isLoadingCategories = true);

    try {
      final rows = await _repository.getCategories();
      if (!mounted) return;

      setState(() => _categories = rows);

      if (_isEditMode && _marketplaceCategoryId != null) {
        final rid = ++_categoryRequestId;
        await _loadMarketplaceAttributes(
          _marketplaceCategoryId!,
          requestId: rid,
        );
      }
    } catch (error) {
      debugPrint('❌ Failed to load categories: $error');
      if (mounted) _showMessage('تعذر تحميل التصنيفات. حاول مرة أخرى.');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingCategories = false;
          _isInitializing = false;
        });
      }
    }
  }

  Future<String?> _getMarketplaceCategoryIdBySlug(String slug) async {
    if (slug.isEmpty) return null;
    try {
      final response = await Supabase.instance.client
          .from('marketplace_categories')
          .select('id')
          .eq('slug', slug)
          .eq('is_active', true)
          .maybeSingle();
      if (response == null) return null;
      return response['id']?.toString();
    } catch (error) {
      debugPrint('⚠️ Failed to load marketplace category: $error');
      return null;
    }
  }

  Future<void> _showCategoryPicker() async {
    FocusScope.of(context).unfocus();

    final selected = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CategoryPickerSheet(
        categories: _categories,
        selectedId: _categoryId,
      ),
    );

    if (selected == null || !mounted) return;
    await _onCategorySelected(selected);
  }

  Future<void> _onCategorySelected(Map<String, dynamic> category) async {
    final value = category['id']?.toString().trim() ?? '';
    final slug = category['slug']?.toString().trim() ?? '';
    final nameAr = category['name_ar']?.toString().trim() ?? '';

    if (value.isEmpty || slug.isEmpty) {
      _showMessage('التصنيف غير صحيح.');
      return;
    }

    final requestId = ++_categoryRequestId;

    setState(() {
      _categoryId = value;
      _categorySlug = slug;
      _categoryNameAr = nameAr;
      _marketplaceCategoryId = null;
      _marketplaceAttributes = [];
      _marketplaceOptions.clear();
      _optionsLoading.clear();
      _selectedMarketplaceOptionIds.clear();
      _selectedMarketplaceValues.clear();
      _selectedMarketplaceValueTypes.clear();
      _isLoadingMarketplaceAttributes = true;
      _attributesStatus = 'loading';
      _prefillApplied = false;
    });

    final marketplaceCategoryId = await _getMarketplaceCategoryIdBySlug(slug);

    if (!mounted || requestId != _categoryRequestId) return;

    if (marketplaceCategoryId == null || marketplaceCategoryId.isEmpty) {
      setState(() {
        _marketplaceCategoryId = null;
        _marketplaceAttributes = [];
        _marketplaceOptions.clear();
        _optionsLoading.clear();
        _isLoadingMarketplaceAttributes = false;
        _attributesStatus = 'missingCategory';
      });
      return;
    }

    setState(() {
      _marketplaceCategoryId = marketplaceCategoryId;
    });

    await _loadMarketplaceAttributes(
      marketplaceCategoryId,
      requestId: requestId,
    );
  }

  // ═══════════════════════════════════════════════════════════
  // ✅ الخصائص — من marketplace_category_attributes
  // ═══════════════════════════════════════════════════════════
  Future<void> _loadMarketplaceAttributes(
    String categoryId, {
    required int requestId,
  }) async {
    if (!mounted) return;

    setState(() {
      _isLoadingMarketplaceAttributes = true;
      _marketplaceAttributes = [];
      _marketplaceOptions.clear();
      _optionsLoading.clear();
      _attributesStatus = 'loading';
    });

    try {
      final client = Supabase.instance.client;

      // 1) links من الجدول الصح
      final linksRaw = await client
          .from('marketplace_category_attributes')
          .select('attribute_id, sort_order, is_required, is_filterable')
          .eq('category_id', categoryId);

      if (!mounted || requestId != _categoryRequestId) return;
      if (_marketplaceCategoryId != categoryId) return;

      final Map<String, Map<String, dynamic>> linksById = {};
      for (final row in (linksRaw as List)) {
        if (row is Map) {
          final id = row['attribute_id']?.toString() ?? '';
          if (id.isEmpty) continue;
          linksById[id] = {
            'sort_order': (row['sort_order'] as num?)?.toInt() ?? 0,
            'is_required': row['is_required'] == true,
            'is_filterable': row['is_filterable'] == true,
          };
        }
      }

      debugPrint('🟢 [Attrs] linked=${linksById.length}');

      if (linksById.isEmpty) {
        setState(() {
          _isLoadingMarketplaceAttributes = false;
          _attributesStatus = 'empty';
        });
        return;
      }

      // 2) attributes — بنجيب name_en كمان
      final attributesRaw = await client
          .from('marketplace_attributes')
          .select('id, slug, name_ar, name_en, input_type')
          .inFilter('id', linksById.keys.toList())
          .eq('is_active', true);

      if (!mounted || requestId != _categoryRequestId) return;
      if (_marketplaceCategoryId != categoryId) return;

      // 3) نبني القائمة
      final List<Map<String, dynamic>> rows = [];
      for (final a in (attributesRaw as List)) {
        if (a is! Map) continue;
        final id = a['id']?.toString() ?? '';
        final link = linksById[id];
        if (link == null) continue;

        rows.add({
          'id': id,
          'slug': a['slug']?.toString() ?? '',
          'name_ar': a['name_ar']?.toString() ?? '',
          'name_en': a['name_en']?.toString() ?? '',
          'input_type': a['input_type']?.toString() ?? 'text',
          'sort_order': link['sort_order'] as int,
          'is_required': link['is_required'] as bool,
          'is_filterable': link['is_filterable'] as bool,
        });
      }

      rows.sort(
        (a, b) => (a['sort_order'] as int).compareTo(b['sort_order'] as int),
      );

      final filtered = rows
          .map((r) => MarketplaceAttribute(
                attributeId: r['id'] as String,
                slug: r['slug'] as String,
                nameAr: r['name_ar'] as String,
                nameEn: r['name_en'] as String,
                inputType: r['input_type'] as String,
                sortOrder: r['sort_order'] as int,
                isRequired: r['is_required'] as bool,
                isFilterable: r['is_filterable'] as bool,
              ))
          .toList();

      debugPrint(
        '🟢 [Attrs] filtered=${filtered.length} '
        'slugs=${filtered.map((a) => a.slug).toList()}',
      );

      if (filtered.isEmpty) {
        setState(() {
          _isLoadingMarketplaceAttributes = false;
          _attributesStatus = 'empty';
        });
        return;
      }

      setState(() {
        _marketplaceAttributes = filtered;
        _isLoadingMarketplaceAttributes = false;
        _attributesStatus = 'loaded';
      });

      // 4) options
      final selectAttrs =
          filtered.where((a) => a.inputType == 'select').toList();

      if (selectAttrs.isNotEmpty) {
        setState(() {
          _optionsLoading
            ..clear()
            ..addAll(selectAttrs.map((a) => a.slug));
        });

        await Future.wait(
          selectAttrs.map((attr) => _loadOptionsFor(attr, requestId)),
        );

        if (!mounted || requestId != _categoryRequestId) return;
        setState(() => _optionsLoading.clear());
      }

      if (!mounted || requestId != _categoryRequestId) return;

      if (!_prefillApplied && _prefilledAttributeData.isNotEmpty) {
        _applyPrefilledAttributes(filtered);
        _prefillApplied = true;
      }
    } catch (e, st) {
      debugPrint('❌ [Attrs] load error: $e');
      debugPrint('$st');
      if (!mounted || requestId != _categoryRequestId) return;
      setState(() {
        _isLoadingMarketplaceAttributes = false;
        _attributesStatus = 'error';
      });
    }
  }

  // ✅ options عالمية على الـ attribute
  Future<void> _loadOptionsFor(
    MarketplaceAttribute attribute,
    int requestId,
  ) async {
    try {
      final client = Supabase.instance.client;

      final optionsRaw = await client
          .from('marketplace_attribute_options')
          .select(
            'id, attribute_id, parent_option_id, value, label_ar, label_en, sort_order',
          )
          .eq('attribute_id', attribute.attributeId)
          .eq('is_active', true)
          .order('sort_order');

      if (!mounted || requestId != _categoryRequestId) return;

      var options = (optionsRaw as List)
          .whereType<Map>()
          .map((row) => MarketplaceAttributeOption(
                id: row['id']?.toString() ?? '',
                attributeId: row['attribute_id']?.toString() ?? '',
                value: row['value']?.toString() ?? '',
                labelAr: row['label_ar']?.toString() ?? '',
                labelEn: row['label_en']?.toString() ?? '',
                sortOrder: (row['sort_order'] as num?)?.toInt() ?? 0,
                parentOptionId: row['parent_option_id']?.toString(),
              ))
          .where((o) => o.id.isNotEmpty)
          .toList();

      final seen = <String>{};
      options = options.where((o) {
        if (seen.contains(o.id)) return false;
        seen.add(o.id);
        return true;
      }).toList();

      final hasChildren = options.any((o) => o.parentOptionId != null);
      if (hasChildren) {
        options = options.where((o) => o.parentOptionId == null).toList();
      }

      options.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

      debugPrint('🟢 [Options] ${attribute.slug}: ${options.length}');

      setState(() {
        _marketplaceOptions[attribute.slug] = options;
        _optionsLoading.remove(attribute.slug);
      });
    } catch (e, st) {
      debugPrint('❌ [Options] ${attribute.slug}: $e');
      debugPrint('$st');
      if (!mounted) return;
      setState(() {
        _marketplaceOptions[attribute.slug] = const [];
        _optionsLoading.remove(attribute.slug);
      });
    }
  }

  void _applyPrefilledAttributes(List<MarketplaceAttribute> attributes) {
    if (!mounted) return;

    for (final row in _prefilledAttributeData) {
      final attrId = row['attribute_id']?.toString();
      if (attrId == null || attrId.isEmpty) continue;

      final attr = _firstWhereOrNull(
        attributes,
        (a) => a.attributeId == attrId,
      );
      if (attr == null) continue;

      final optionId = row['option_id']?.toString();
      if (optionId != null && optionId.isNotEmpty) {
        final options = _marketplaceOptions[attr.slug] ?? const [];
        final opt = _firstWhereOrNull(options, (o) => o.id == optionId);
        _selectedMarketplaceOptionIds[attr.slug] = optionId;
        _selectedMarketplaceValues[attr.slug] = opt?.value ?? '';
        _selectedMarketplaceValueTypes[attr.slug] = 'option';
        continue;
      }

      final valueText = row['value_text']?.toString();
      if (valueText != null && valueText.isNotEmpty) {
        _selectedMarketplaceValues[attr.slug] = valueText;
        _selectedMarketplaceValueTypes[attr.slug] = attr.inputType;
        continue;
      }

      final valueNumber = row['value_number'];
      if (valueNumber != null) {
        _selectedMarketplaceValues[attr.slug] = valueNumber.toString();
        _selectedMarketplaceValueTypes[attr.slug] = attr.inputType;
      }
    }

    setState(() {});
  }

  void _selectMarketplaceOption({
    required MarketplaceAttribute attribute,
    required MarketplaceAttributeOption option,
  }) {
    setState(() {
      _selectedMarketplaceOptionIds[attribute.slug] = option.id;
      _selectedMarketplaceValues[attribute.slug] = option.value;
      _selectedMarketplaceValueTypes[attribute.slug] = 'option';
    });
  }

  void _saveMarketplaceValue({
    required MarketplaceAttribute attribute,
    required String value,
  }) {
    final clean = value.trim();
    setState(() {
      if (clean.isEmpty) {
        _selectedMarketplaceValues.remove(attribute.slug);
        _selectedMarketplaceValueTypes.remove(attribute.slug);
      } else {
        _selectedMarketplaceValues[attribute.slug] = clean;
        _selectedMarketplaceValueTypes[attribute.slug] = attribute.inputType;
      }
      _selectedMarketplaceOptionIds.remove(attribute.slug);
    });
  }

  List<Map<String, dynamic>> _buildMarketplaceAttributesPayload() {
    final payload = <Map<String, dynamic>>[];

    for (final attribute in _marketplaceAttributes) {
      final slug = attribute.slug;

      final selectedOptionId = _selectedMarketplaceOptionIds[slug];
      final selectedValue = _selectedMarketplaceValues[slug];

      if (selectedOptionId != null && selectedOptionId.isNotEmpty) {
        payload.add({
          'attribute_id': attribute.attributeId,
          'option_id': selectedOptionId,
          'value_text': null,
          'value_number': null,
        });
        continue;
      }

      if (selectedValue != null && selectedValue.trim().isNotEmpty) {
        if (attribute.inputType == 'number' ||
            attribute.inputType == 'decimal') {
          final number = num.tryParse(selectedValue.trim());
          if (number != null && number.isFinite) {
            payload.add({
              'attribute_id': attribute.attributeId,
              'option_id': null,
              'value_text': null,
              'value_number': number,
            });
          }
        } else {
          payload.add({
            'attribute_id': attribute.attributeId,
            'option_id': null,
            'value_text': selectedValue.trim(),
            'value_number': null,
          });
        }
      }
    }

    return payload;
  }

  String? _validateMarketplaceAttributes() {
    for (final attribute in _marketplaceAttributes) {
      if (!attribute.isRequired) continue;

      final optionId = _selectedMarketplaceOptionIds[attribute.slug];
      final value = _selectedMarketplaceValues[attribute.slug];

      if (attribute.inputType == 'select') {
        if (optionId == null || optionId.isEmpty) {
          return 'اختر ${attribute.nameAr}';
        }
      } else {
        if (value == null || value.trim().isEmpty) {
          return 'أدخل ${attribute.nameAr}';
        }
        if (attribute.inputType == 'number' ||
            attribute.inputType == 'decimal') {
          final number = num.tryParse(value.trim());
          if (number == null || !number.isFinite || number <= 0) {
            return 'أدخل ${attribute.nameAr} بشكل صحيح';
          }
        }
      }
    }
    return null;
  }

  // ═══════════════════════════════════════════════════════════
  // Images
  // ═══════════════════════════════════════════════════════════
  Future<void> _pickImages() async {
    if (_totalImages >= 6) {
      _showMessage('يمكنك إضافة 6 صور كحد أقصى');
      return;
    }

    try {
      final picked = await _picker.pickMultiImage(
        imageQuality: 82,
        maxWidth: 1600,
      );
      if (!mounted || picked.isEmpty) return;
      setState(() {
        _newImages.addAll(picked.take(6 - _totalImages));
      });
    } catch (error) {
      debugPrint('❌ Failed to pick images: $error');
      if (mounted) _showMessage('تعذر اختيار الصور، حاول مرة أخرى');
    }
  }

  void _removeNewImage(int index) {
    if (!mounted || index < 0 || index >= _newImages.length) return;
    setState(() => _newImages.removeAt(index));
  }

  void _removeExistingImage(int index) {
    if (!mounted || index < 0 || index >= _existingImageUrls.length) return;

    final url = _existingImageUrls[index];
    final path = index < _keptImagePaths.length
        ? _keptImagePaths[index]
        : _extractStoragePath(url);

    setState(() {
      _existingImageUrls.removeAt(index);
      if (index < _keptImagePaths.length) {
        _keptImagePaths.removeAt(index);
      }
      if (path.isNotEmpty && !_removedImagePaths.contains(path)) {
        _removedImagePaths.add(path);
      }
    });
  }

  DateTime? _getExpiresAt() {
    final now = DateTime.now();
    switch (_expiryOption) {
      case '7_days':
        return now.add(const Duration(days: 7));
      case '14_days':
        return now.add(const Duration(days: 14));
      case '30_days':
        return now.add(const Duration(days: 30));
      case 'never':
        return null;
      default:
        return now.add(const Duration(days: 7));
    }
  }

  // ═══════════════════════════════════════════════════════════
  // Submit
  // ═══════════════════════════════════════════════════════════
  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    if (_categoryId == null ||
        _categorySlug == null ||
        _categorySlug!.isEmpty) {
      _showMessage('اختر تصنيف العرض');
      return;
    }

    if (_marketplaceAttributes.isNotEmpty) {
      final marketplaceError = _validateMarketplaceAttributes();
      if (marketplaceError != null) {
        _showMessage(marketplaceError);
        return;
      }
    }

    if (_totalImages == 0) {
      _showMessage('أضف صورة واحدة على الأقل للعرض');
      return;
    }

    if (!_termsAccepted) {
      _showMessage('يجب تأكيد صحة بيانات العرض قبل النشر');
      return;
    }

    if (_lat == null || _lng == null) {
      _showMessage('حدّد مكان الاستلام على الخريطة');
      return;
    }

    final lat = _lat!;
    final lng = _lng!;

    final contactPhone = _phoneController.text.trim();
    if (contactPhone.isEmpty) {
      _showMessage('اكتب رقم هاتفك للتواصل');
      return;
    }

    if (!_isValidEgyptianPhone(contactPhone)) {
      _showMessage('رقم الهاتف غير صحيح (مثال: 01012345678)');
      return;
    }

    final whatsappInput = _whatsappController.text.trim();
    String? whatsapp;
    if (whatsappInput.isNotEmpty) {
      if (!_isValidEgyptianPhone(whatsappInput)) {
        _showMessage('رقم الواتساب غير صحيح (مثال: 01012345678)');
        return;
      }
      whatsapp = whatsappInput;
    }

    final quantity = int.tryParse(_quantityController.text.trim()) ?? 0;
    if (quantity <= 0) {
      _showMessage('أدخل كمية أكبر من صفر');
      return;
    }

    final price = double.tryParse(_priceController.text.trim()) ?? 0;
    if (price <= 0) {
      _showMessage('أدخل سعرًا أكبر من صفر');
      return;
    }

    if (!price.isFinite) {
      _showMessage('أدخل سعرًا صحيحًا');
      return;
    }

    final pickupLocation = _locationController.text.trim();
    if (pickupLocation.isEmpty) {
      _showMessage('اكتب مكان الاستلام');
      return;
    }

    final expiresAt = _getExpiresAt();
    final marketplaceAttributes = _buildMarketplaceAttributesPayload();

    setState(() => _isSubmitting = true);

    try {
      if (_isEditMode) {
        if (widget.onSubmit != null) {
          final draft = <String, dynamic>{
            'id': widget.offerId,
            'title': _titleController.text.trim(),
            'description': _descriptionController.text.trim(),
            'category_id': _categoryId,
            'category': _categorySlug,
            'marketplace_category_id': _marketplaceCategoryId,
            'listing_type': _listingType,
            'item_condition': _getLegacyCondition(),
            'quantity': quantity,
            'price': price,
            'pickup_location': pickupLocation,
            'latitude': lat,
            'longitude': lng,
            'phone': contactPhone,
            'whatsapp': whatsapp,
            'expires_at': expiresAt?.toUtc().toIso8601String(),
            'marketplace_attributes': marketplaceAttributes,
            'kept_image_paths': _keptImagePaths,
            'removed_image_paths': _removedImagePaths,
            'new_images': _newImages.map((i) => i.path).toList(),
          };

          await widget.onSubmit!(draft);
        } else {
          await _repository.updateOffer(
            offerId: widget.offerId!,
            title: _titleController.text.trim(),
            description: _descriptionController.text.trim(),
            categoryId: _categoryId!,
            categorySlug: _categorySlug!,
            itemCondition: _getLegacyCondition(),
            quantity: quantity,
            price: price,
            pickupLocation: pickupLocation,
            latitude: lat,
            longitude: lng,
            contactPhone: contactPhone,
            whatsapp: whatsapp,
            newImages: _newImages,
            keptImagePaths: _keptImagePaths,
            expiresAt: expiresAt,
            marketplaceCategoryId: _marketplaceCategoryId,
            marketplaceAttributes: marketplaceAttributes,
          );
        }

        if (!mounted) return;

        _showMessage('تم تحديث العرض بنجاح', success: true);

        Navigator.pop(context, {
          'id': widget.offerId,
          'updated': true,
        });

        return;
      }

      final draft = <String, dynamic>{
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'category_id': _categoryId,
        'category': _categorySlug,
        'marketplace_category_id': _marketplaceCategoryId,
        'listing_type': _listingType,
        'item_condition': _getLegacyCondition(),
        'quantity': quantity,
        'price': price,
        'pickup_location': pickupLocation,
        'latitude': lat,
        'longitude': lng,
        'phone': contactPhone,
        'whatsapp': whatsapp,
        'expires_at': expiresAt?.toUtc().toIso8601String(),
        'marketplace_attributes': marketplaceAttributes,
        'local_images': _newImages.map((i) => i.path).toList(),
      };

      if (widget.onSubmit != null) {
        await widget.onSubmit!(draft);
      } else {
        await _repository.createOffer(
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          categoryId: _categoryId!,
          categorySlug: _categorySlug!,
          marketplaceCategoryId: _marketplaceCategoryId,
          listingType: _listingType,
          itemCondition: _getLegacyCondition(),
          quantity: quantity,
          price: price,
          pickupLocation: pickupLocation,
          latitude: lat,
          longitude: lng,
          contactPhone: contactPhone,
          whatsapp: whatsapp,
          images: _newImages,
          expiresAt: expiresAt,
          marketplaceAttributes: marketplaceAttributes,
        );
      }

      if (!mounted) return;

      _showMessage('تم إنشاء العرض بنجاح', success: true);
      Navigator.pop(context, draft);
    } catch (error) {
      debugPrint('❌ Failed to submit community offer: $error');
      if (mounted) _showMessage(_friendlyError(error));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String _getLegacyCondition() {
    final optionId = _selectedMarketplaceOptionIds['condition'];
    if (optionId != null && optionId.isNotEmpty) {
      final options = _marketplaceOptions['condition'] ?? const [];
      final opt = _firstWhereOrNull(options, (o) => o.id == optionId);
      if (opt != null && opt.value.isNotEmpty) return opt.value;
    }
    final value = _selectedMarketplaceValues['condition'];
    if (value != null && value.trim().isNotEmpty) return value.trim();
    return 'good';
  }

  String _friendlyError(Object error) {
    final text = error.toString().toLowerCase();

    if (text.contains('owner location is required') ||
        text.contains('location is required')) {
      return 'يجب تفعيل موقعك أولًا حتى تتمكن من نشر العرض.';
    }
    if (text.contains('permission') || text.contains('row-level security')) {
      return 'لا تملك صلاحية حفظ هذا العرض. تأكد من تسجيل الدخول وحاول مرة أخرى.';
    }
    if (text.contains('network') ||
        text.contains('socket') ||
        text.contains('connection')) {
      return 'تعذر الاتصال بالخادم. تحقق من الإنترنت وحاول مرة أخرى.';
    }
    if (text.contains('category')) {
      return 'تصنيف العرض غير صحيح. اختر تصنيفًا آخر وحاول مرة أخرى.';
    }
    if (text.contains('attribute') || text.contains('option')) {
      return 'خصائص العرض غير صحيحة. أعد اختيار الخصائص وحاول مرة أخرى.';
    }
    if (text.contains('expires') || text.contains('expiry')) {
      return 'تاريخ انتهاء العرض غير صحيح.';
    }
    if (text.contains('listing_type') || text.contains('symbolic_sale')) {
      return 'نوع العرض غير صحيح. يجب أن يكون العرض بيعًا بسعر رمزي.';
    }
    if (text.contains('charity')) {
      return 'هذا النوع من العروض لا يدعم الجمعيات الخيرية.';
    }
    if (text.contains('price')) return 'السعر يجب أن يكون أكبر من صفر.';
    if (text.contains('quantity')) {
      return 'الكمية يجب أن تكون أكبر من صفر.';
    }
    if (text.contains('phone') || text.contains('contact')) {
      return 'رقم الهاتف غير صحيح.';
    }

    return 'تعذر حفظ العرض. راجع البيانات وحاول مرة أخرى.';
  }

  void _showMessage(String message, {bool success = false}) {
    final colors = Theme.of(context).colorScheme;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message, textDirection: TextDirection.rtl),
          backgroundColor: success ? colors.primary : colors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
  }

  Future<void> _openLocationPicker() async {
    FocusScope.of(context).unfocus();

    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => LocationPickerPage(
          initialLat: _lat,
          initialLng: _lng,
        ),
      ),
    );

    if (result == null || !mounted) return;

    setState(() {
      _lat = (result['lat'] as num?)?.toDouble();
      _lng = (result['lng'] as num?)?.toDouble();
    });
  }

  // ═══════════════════════════════════════════════════════════
  // Build
  // ═══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: PopScope(
        canPop: !_hasUnsavedData(),
        onPopInvokedWithResult: (didPop, result) async {
          if (didPop) return;
          final shouldPop = await _confirmExit();
          if (shouldPop && mounted) Navigator.of(context).pop();
        },
        child: Scaffold(
          backgroundColor:
              isDark ? const Color(0xFF101318) : const Color(0xFFF7F8FC),
          appBar: AppBar(
            title: Text(_isEditMode ? 'تعديل العرض' : 'إضافة عرض'),
            centerTitle: true,
            elevation: 0,
            backgroundColor:
                isDark ? const Color(0xFF101318) : const Color(0xFFF7F8FC),
            foregroundColor: colors.onSurface,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () async {
                if (!_hasUnsavedData()) {
                  Navigator.of(context).pop();
                  return;
                }
                final shouldPop = await _confirmExit();
                if (shouldPop && mounted) Navigator.of(context).pop();
              },
            ),
          ),
          body: _isInitializing
              ? Center(child: CircularProgressIndicator(color: colors.primary))
              : Form(
                  key: _formKey,
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 36),
                    children: [
                      _buildProgressHeader(colors),
                      const SizedBox(height: 14),
                      _buildIntro(colors),
                      const SizedBox(height: 14),
                      _buildImages(colors),
                      const SizedBox(height: 14),
                      _buildDetailsCard(colors),
                      const SizedBox(height: 14),
                      _buildLocationCard(colors),
                      const SizedBox(height: 14),
                      _buildExpiryCard(colors),
                      const SizedBox(height: 14),
                      _buildConfirmation(colors),
                      const SizedBox(height: 18),
                      _buildSubmitButton(colors),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildProgressHeader(ColorScheme colors) {
    final hasCategory =
        _marketplaceCategoryId != null && _marketplaceCategoryId!.isNotEmpty;
    final hasDetails = _titleController.text.trim().isNotEmpty &&
        _descriptionController.text.trim().isNotEmpty;
    final hasLocation = _lat != null && _lng != null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: .55)),
        boxShadow: [
          BoxShadow(
              color: colors.shadow.withValues(alpha: .05),
              blurRadius: 16,
              offset: const Offset(0, 5)),
        ],
      ),
      child: Row(
        children: [
          _progressDot(colors, true, Icons.check_rounded),
          _progressLine(colors),
          _progressDot(colors, hasCategory, Icons.category_outlined),
          _progressLine(colors),
          _progressDot(colors, hasDetails, Icons.edit_note_rounded),
          _progressLine(colors),
          _progressDot(colors, hasLocation, Icons.location_on_outlined),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              hasCategory ? 'بيانات مناسبة لاختيارك' : 'ابدأ باختيار نوع العرض',
              textAlign: TextAlign.right,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: colors.onSurface),
            ),
          ),
        ],
      ),
    );
  }

  Widget _progressDot(ColorScheme colors, bool active, IconData icon) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: active ? colors.primary : colors.surfaceContainerHighest,
        shape: BoxShape.circle,
      ),
      child: Icon(icon,
          size: 16, color: active ? colors.onPrimary : colors.onSurfaceVariant),
    );
  }

  Widget _progressLine(ColorScheme colors) {
    return Expanded(
        child: Container(
            height: 2,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            color: colors.outlineVariant));
  }

  Widget _buildIntro(ColorScheme colors) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colors.primary, colors.primary.withValues(alpha: 0.7)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            _isEditMode ? Icons.edit_rounded : Icons.sell_rounded,
            color: colors.onPrimary,
            size: 32,
          ),
          const SizedBox(height: 12),
          Text(
            _isEditMode ? 'عدّل بيانات عرضك' : 'خلّي الشيء الزائد يعمل أثرًا',
            style: TextStyle(
              color: colors.onPrimary,
              fontSize: 21,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _isEditMode
                ? 'خد بالك: أي تعديل هيتطبق فورًا على العرض الظاهر للمستخدمين.'
                : 'اعرض الأشياء الزائدة عندك للبيع بسعر رمزي ليستفيد منها شخص قريب منك.',
            style: TextStyle(
              color: colors.onPrimary.withValues(alpha: 0.8),
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImages(ColorScheme colors) {
    return _sectionCard(
      title: 'صور العرض',
      icon: Icons.photo_library_outlined,
      trailing: Text(
        '$_totalImages/6',
        style: TextStyle(
          color: colors.primary,
          fontWeight: FontWeight.w800,
        ),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 104,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _totalImages + 1,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, index) {
                if (index == _totalImages) return _addImageButton(colors);

                if (index < _existingImageUrls.length) {
                  return _existingImageTile(
                    _existingImageUrls[index],
                    index,
                    colors,
                  );
                }

                final newIndex = index - _existingImageUrls.length;
                return _newImageTile(_newImages[newIndex], newIndex, colors);
              },
            ),
          ),
          const SizedBox(height: 9),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'الصورة الأولى ستظهر كصورة رئيسية للعرض',
              style: TextStyle(
                color: colors.onSurfaceVariant,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _addImageButton(ColorScheme colors) {
    return InkWell(
      onTap: _totalImages == 6 ? null : _pickImages,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 104,
        decoration: BoxDecoration(
          color: colors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.primary.withValues(alpha: 0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_photo_alternate_outlined,
              color: colors.primary,
              size: 28,
            ),
            const SizedBox(height: 5),
            Text(
              'أضف صورًا',
              style: TextStyle(
                color: colors.primary,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _existingImageTile(String url, int index, ColorScheme colors) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.network(
            url,
            width: 104,
            height: 104,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Container(
                width: 104,
                height: 104,
                color: colors.primary.withValues(alpha: 0.1),
                child: const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              );
            },
            errorBuilder: (_, __, ___) => Container(
              width: 104,
              height: 104,
              color: colors.primary.withValues(alpha: 0.1),
              child: Icon(
                Icons.broken_image_outlined,
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
        ),
        Positioned(
          top: 5,
          left: 5,
          child: InkWell(
            onTap: () => _removeExistingImage(index),
            child: Container(
              width: 25,
              height: 25,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 15),
            ),
          ),
        ),
      ],
    );
  }

  Widget _newImageTile(XFile image, int index, ColorScheme colors) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: FutureBuilder<Uint8List>(
            future: image.readAsBytes(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const SizedBox(
                  width: 104,
                  height: 104,
                  child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              }

              return Image.memory(
                snapshot.data!,
                width: 104,
                height: 104,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) {
                  return ColoredBox(
                    color: colors.primary.withValues(alpha: 0.1),
                    child: const SizedBox(
                      width: 104,
                      height: 104,
                      child: Icon(Icons.broken_image_outlined),
                    ),
                  );
                },
              );
            },
          ),
        ),
        Positioned(
          top: 5,
          left: 5,
          child: InkWell(
            onTap: () => _removeNewImage(index),
            child: Container(
              width: 25,
              height: 25,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 15),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailsCard(ColorScheme colors) {
    return _sectionCard(
      title: 'بيانات العرض',
      icon: Icons.assignment_outlined,
      trailing: _categoryId == null
          ? null
          : Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: .10),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('مخصص حسب الاختيار',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: colors.primary)),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _field(_titleController, 'عنوان العرض',
              'مثال: جاكت شتوي بحالة ممتازة', Icons.title_rounded,
              requiredField: true),
          const SizedBox(height: 12),
          _buildCategorySelector(colors),
          if (_categoryId == null) ...[
            const SizedBox(height: 10),
            _helperBanner(
                colors,
                Icons.touch_app_rounded,
                'اختار نوع المنتج أولًا',
                'بعد الاختيار ستظهر لك الحقول المناسبة تلقائيًا مثل الماركة، الحالة، المقاس أو المساحة.'),
          ],
          ..._buildDynamicAttributesSection(colors),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                  child: _field(_quantityController, 'الكمية', '1',
                      Icons.inventory_2_outlined,
                      requiredField: true, numeric: true, integerOnly: true)),
              const SizedBox(width: 10),
              Expanded(
                  child: _field(
                      _priceController,
                      _isCars ? 'السعر' : 'السعر الرمزي بالجنيه',
                      _isCars ? 'مثال: 100000' : 'مثال: 100',
                      Icons.payments_outlined,
                      requiredField: true,
                      numeric: true)),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _descriptionController,
            minLines: 4,
            maxLines: 7,
            textInputAction: TextInputAction.newline,
            decoration: _decoration(
                'الوصف والتفاصيل', Icons.description_outlined,
                hint:
                    'اكتب الحالة بالتفصيل، العيوب، المقاس أو أي ملاحظات مهمة...'),
            validator: (value) => value == null || value.trim().length < 10
                ? 'اكتب وصفًا مختصرًا وواضحًا'
                : null,
          ),
          const SizedBox(height: 9),
          _helperBanner(
              colors,
              Icons.lightbulb_outline_rounded,
              'نصيحة لعرض أفضل',
              'البيانات الواضحة والصور الجيدة تساعد الناس على فهم العرض والتواصل معك أسرع.'),
        ],
      ),
    );
  }

  Widget _helperBanner(
      ColorScheme colors, IconData icon, String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: colors.primary.withValues(alpha: .055),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.primary.withValues(alpha: .14))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: colors.primary, size: 19),
          const SizedBox(width: 9),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: colors.onSurface)),
                const SizedBox(height: 3),
                Text(subtitle,
                    style: TextStyle(
                        fontSize: 11,
                        height: 1.45,
                        color: colors.onSurfaceVariant))
              ])),
        ],
      ),
    );
  }

  List<Widget> _buildDynamicAttributesSection(ColorScheme colors) {
    if (_categoryId == null || _categoryId!.isEmpty) {
      return const [];
    }

    if (_isLoadingMarketplaceAttributes || _attributesStatus == 'loading') {
      return [
        const SizedBox(height: 18),
        _attributesStateCard(
          colors: colors,
          icon: Icons.hourglass_top_rounded,
          iconColor: colors.primary,
          title: 'جاري تحميل خصائص التصنيف...',
          subtitle: 'بيتم جلب الحقول المناسبة لـ "$_currentCategoryName"',
          showLoader: true,
        ),
      ];
    }

    if (_attributesStatus == 'error') {
      return [
        const SizedBox(height: 18),
        _attributesStateCard(
          colors: colors,
          icon: Icons.error_outline_rounded,
          iconColor: colors.error,
          title: 'تعذر تحميل الخصائص',
          subtitle: 'حاول تختار التصنيف تاني',
        ),
      ];
    }

    if (_attributesStatus == 'missingCategory') {
      return [
        const SizedBox(height: 18),
        _attributesStateCard(
          colors: colors,
          icon: Icons.info_outline_rounded,
          iconColor: colors.onSurfaceVariant,
          title: 'التصنيف ده لسه مش مفعّل',
          subtitle:
              '"$_currentCategoryName" مش موجود ضمن التصنيفات المدعومة حاليًا. اختار تصنيف تاني.',
        ),
      ];
    }

    if (_attributesStatus == 'empty') {
      return [
        const SizedBox(height: 18),
        _attributesStateCard(
          colors: colors,
          icon: Icons.check_circle_outline_rounded,
          iconColor: Colors.green,
          title: 'مفيش خصائص إضافية',
          subtitle:
              '"$_currentCategoryName" مش محتاج تفاصيل إضافية. كمّل بيانات العرض.',
        ),
      ];
    }

    if (_attributesStatus == 'loaded' && _marketplaceAttributes.isNotEmpty) {
      return [
        const SizedBox(height: 18),
        _buildMarketplaceAttributesHeader(colors),
        const SizedBox(height: 12),
        ..._buildMarketplaceAttributeWidgets(),
      ];
    }

    return const [];
  }

  Widget _attributesStateCard({
    required ColorScheme colors,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    bool showLoader = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? iconColor.withValues(alpha: 0.08)
            : iconColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: iconColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showLoader)
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                color: iconColor,
              ),
            )
          else
            Icon(icon, color: iconColor, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: colors.onSurface,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: 11.5,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMarketplaceAttributesHeader(ColorScheme colors) {
    final requiredCount = _requiredAttributesCount;
    final optionalCount = _optionalAttributesCount;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.primary.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(
              Icons.tune_rounded,
              size: 17,
              color: colors.primary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'خصائص $_currentCategoryName',
                  style: TextStyle(
                    color: colors.onSurface,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _buildAttributesCountLabel(requiredCount, optionalCount),
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _buildAttributesCountLabel(int required, int optional) {
    final parts = <String>[];
    if (required > 0) parts.add('$required مطلوبة');
    if (optional > 0) parts.add('$optional اختيارية');
    if (parts.isEmpty) return 'لا توجد حقول';
    return parts.join(' • ');
  }

  List<Widget> _buildMarketplaceAttributeWidgets() {
    return _marketplaceAttributes.map((attribute) {
      final options = _marketplaceOptions[attribute.slug] ??
          const <MarketplaceAttributeOption>[];

      final selectedId = _selectedMarketplaceOptionIds[attribute.slug];
      final selectedValue = _selectedMarketplaceValues[attribute.slug];

      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _buildMarketplaceAttribute(
          attribute: attribute,
          options: options,
          selectedId: selectedId,
          selectedValue: selectedValue,
        ),
      );
    }).toList();
  }

  Widget _buildMarketplaceAttribute({
    required MarketplaceAttribute attribute,
    required List<MarketplaceAttributeOption> options,
    required String? selectedId,
    required String? selectedValue,
  }) {
    final colors = Theme.of(context).colorScheme;

    if (attribute.inputType == 'select') {
      final uniqueOptions = <String, MarketplaceAttributeOption>{};
      for (final option in options) {
        final id = option.id.trim();
        if (id.isEmpty) continue;
        uniqueOptions[id] = option;
      }

      final safeOptions = uniqueOptions.values.toList();
      final safeSelectedId =
          safeOptions.any((option) => option.id == selectedId)
              ? selectedId
              : null;

      final isLoadingOptions = _optionsLoading.contains(attribute.slug);
      final hasOptions = safeOptions.isNotEmpty;
      final isDisabled = isLoadingOptions || !hasOptions;

      final hintText = isLoadingOptions
          ? 'جاري تحميل الخيارات...'
          : hasOptions
              ? 'اختر ${attribute.nameAr}'
              : 'لا توجد خيارات متاحة';

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            key: ValueKey(
              '${attribute.slug}:$safeSelectedId:${safeOptions.length}:$isLoadingOptions',
            ),
            initialValue: safeSelectedId,
            isExpanded: true,
            decoration: _decoration(attribute.nameAr, Icons.tune_rounded),
            hint: Text(
              hintText,
              style: TextStyle(
                color: colors.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
            items: safeOptions.map((option) {
              return DropdownMenuItem<String>(
                value: option.id,
                child: Text(option.labelAr),
              );
            }).toList(),
            validator: attribute.isRequired && !isDisabled
                ? (value) {
                    if (value == null || value.isEmpty) {
                      return 'اختر ${attribute.nameAr}';
                    }
                    return null;
                  }
                : null,
            onChanged: isDisabled
                ? null
                : (value) {
                    if (value == null) return;
                    final selected =
                        safeOptions.firstWhere((option) => option.id == value);
                    _selectMarketplaceOption(
                      attribute: attribute,
                      option: selected,
                    );
                  },
          ),
          if (!attribute.isRequired) _optionalLabel(colors),
        ],
      );
    }

    if (attribute.inputType == 'number' || attribute.inputType == 'decimal') {
      return _MarketplaceNumberField(
        key: ValueKey('${attribute.slug}:$selectedValue'),
        attribute: attribute,
        initialValue: selectedValue,
        isDecimal: attribute.inputType == 'decimal',
        decoration: _decoration(
          attribute.nameAr,
          Icons.numbers_rounded,
          hint: _numberHint(attribute.slug),
        ).copyWith(suffixText: _numberSuffix(attribute.slug)),
        onChanged: (value) {
          _saveMarketplaceValue(attribute: attribute, value: value);
        },
      );
    }

    final isItemType = attribute.slug == 'item_type';
    return _MarketplaceTextField(
      key: ValueKey('${attribute.slug}:$selectedValue'),
      attribute: attribute,
      initialValue: selectedValue,
      decoration: _decoration(
        attribute.nameAr,
        Icons.edit_outlined,
        hint: isItemType
            ? 'مثال: مزهرية، لوحة، جهاز...'
            : 'أدخل ${attribute.nameAr}',
      ),
      onChanged: (value) {
        _saveMarketplaceValue(attribute: attribute, value: value);
      },
    );
  }

  String _numberHint(String slug) {
    switch (slug) {
      case 'year':
        return 'مثال: 2022';
      case 'mileage':
        return 'مثال: 80000';
      case 'area':
        return 'مثال: 150';
      case 'rooms':
        return 'مثال: 3';
      case 'bathrooms':
        return 'مثال: 2';
      case 'pieces':
        return 'مثال: 12';
      case 'quantity':
        return 'مثال: 5';
      case 'weight':
        return 'مثال: 2.5';
      default:
        return 'أدخل الرقم';
    }
  }

  String? _numberSuffix(String slug) {
    switch (slug) {
      case 'year':
        return 'سنة';
      case 'mileage':
        return 'كم';
      case 'area':
        return 'م²';
      case 'rooms':
        return 'غرفة';
      case 'bathrooms':
        return 'حمام';
      case 'pieces':
        return 'قطعة';
      case 'weight':
        return 'كجم';
      default:
        return null;
    }
  }

  Widget _optionalLabel(ColorScheme colors) {
    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Align(
        alignment: Alignment.centerRight,
        child: Text(
          'اختياري',
          style: TextStyle(color: colors.onSurfaceVariant, fontSize: 10),
        ),
      ),
    );
  }

  Widget _buildCategorySelector(ColorScheme colors) {
    if (_isLoadingCategories) {
      return InputDecorator(
        decoration: _decoration('نوع الشيء', Icons.category_outlined),
        child: const SizedBox(
          height: 24,
          child: Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      );
    }

    if (_categories.isEmpty) {
      return InputDecorator(
        decoration: _decoration('نوع الشيء', Icons.category_outlined),
        child: Text(
          'لا توجد تصنيفات متاحة',
          style: TextStyle(color: colors.onSurfaceVariant),
        ),
      );
    }

    Map<String, dynamic>? selected;
    for (final c in _categories) {
      if (c['id']?.toString() == _categoryId) {
        selected = c;
        break;
      }
    }

    String? parentName;
    if (selected != null) {
      final pid = selected['parent_id']?.toString();
      if (pid != null && pid.isNotEmpty) {
        for (final c in _categories) {
          if (c['id']?.toString() == pid) {
            parentName = c['name_ar']?.toString();
            break;
          }
        }
      }
    }

    final hasSelection = selected != null;
    final nameAr = selected?['name_ar']?.toString() ?? '';

    return InkWell(
      onTap: _showCategoryPicker,
      borderRadius: BorderRadius.circular(15),
      child: InputDecorator(
        decoration: _decoration('نوع الشيء', Icons.category_outlined),
        child: Row(
          children: [
            Expanded(
              child: hasSelection
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (parentName != null) ...[
                          Text(
                            parentName,
                            style: TextStyle(
                              fontSize: 11,
                              color: colors.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                        ],
                        Text(
                          nameAr,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: colors.onSurface,
                          ),
                        ),
                      ],
                    )
                  : Text(
                      'اختر نوع الشيء',
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
            ),
            Icon(
              Icons.search_rounded,
              color: colors.primary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationCard(ColorScheme colors) {
    final hasLocation = _lat != null && _lng != null;

    return _sectionCard(
      title: 'مكان الاستلام والتواصل',
      icon: Icons.location_on_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: _openLocationPicker,
            borderRadius: BorderRadius.circular(15),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: hasLocation
                      ? colors.primary.withValues(alpha: 0.5)
                      : colors.outlineVariant,
                  width: hasLocation ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.map_rounded,
                      color: colors.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hasLocation
                              ? 'تم تحديد الموقع ✅'
                              : 'اختار موقعك على الخريطة',
                          style: TextStyle(
                            color:
                                hasLocation ? colors.primary : colors.onSurface,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          hasLocation
                              ? '${_lat!.toStringAsFixed(4)}, ${_lng!.toStringAsFixed(4)}'
                              : 'علشان نعرض العرض للناس القريبة منك',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    hasLocation
                        ? Icons.edit_location_alt_rounded
                        : Icons.arrow_back_ios_new_rounded,
                    color: colors.primary,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          _field(
            _locationController,
            'وصف المكان (اختياري)',
            'مثال: شارع البحر، قرب مسجد...',
            Icons.place_outlined,
          ),
          const SizedBox(height: 14),
          _field(
            _phoneController,
            'رقم الهاتف للتواصل *',
            'مثال: 01012345678',
            Icons.phone_rounded,
            requiredField: true,
            numeric: true,
            integerOnly: true,
          ),
          const SizedBox(height: 10),
          _field(
            _whatsappController,
            'رقم الواتساب (اختياري)',
            'مثال: 01012345678',
            Icons.chat_rounded,
            numeric: true,
            integerOnly: true,
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: colors.primary,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'حدّد مكان الاستلام على الخريطة واكتب رقم هاتفك للتواصل. لو ضفت رقم واتساب، المشتري هيقدر يتواصل معاك عليه.',
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: 11,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpiryCard(ColorScheme colors) {
    return _sectionCard(
      title: 'مدة توفر العرض',
      icon: Icons.schedule_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _expiryOption,
            decoration: _decoration(
              'العرض متاح حتى',
              Icons.event_available_outlined,
            ),
            items: const [
              DropdownMenuItem(value: '7_days', child: Text('لمدة أسبوع')),
              DropdownMenuItem(value: '14_days', child: Text('لمدة أسبوعين')),
              DropdownMenuItem(value: '30_days', child: Text('لمدة شهر')),
              DropdownMenuItem(
                value: 'never',
                child: Text('بدون تاريخ انتهاء'),
              ),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() => _expiryOption = value);
            },
          ),
          const SizedBox(height: 8),
          Text(
            'بعد انتهاء المدة لن يظهر العرض ضمن العروض المتاحة للمستخدمين.',
            style: TextStyle(
              color: colors.onSurfaceVariant,
              fontSize: 11,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmation(ColorScheme colors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.primary.withValues(alpha: 0.18)),
      ),
      child: CheckboxListTile(
        value: _termsAccepted,
        onChanged: (value) {
          setState(() => _termsAccepted = value ?? false);
        },
        controlAffinity: ListTileControlAffinity.leading,
        contentPadding: EdgeInsets.zero,
        tileColor: Colors.transparent,
        title: Text(
          'أؤكد أن البيانات والصور التي أضفتها صحيحة، وأنني أوضحت حالة المنتج وأي عيوب موجودة به.',
          style: TextStyle(
            color: colors.onSurface,
            fontSize: 12,
            height: 1.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildSubmitButton(ColorScheme colors) {
    final label = _isSubmitting
        ? (_isEditMode ? 'جاري تحديث العرض...' : 'جاري إنشاء العرض...')
        : (_isEditMode ? 'حفظ التعديلات' : 'نشر العرض');

    final icon = _isSubmitting
        ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          )
        : Icon(_isEditMode ? Icons.check_rounded : Icons.sell_rounded);

    return SizedBox(
      height: 56,
      child: ElevatedButton.icon(
        onPressed: _isSubmitting ? null : _submit,
        icon: icon,
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.primary,
          foregroundColor: colors.onPrimary,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required Widget child,
    Widget? trailing,
  }) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F1F1F) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.3)
                : Colors.black.withValues(alpha: 0.03),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 35,
                height: 35,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: colors.primary, size: 19),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: colors.onSurface,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label,
    String hint,
    IconData icon, {
    bool requiredField = false,
    bool numeric = false,
    bool integerOnly = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: numeric
          ? TextInputType.numberWithOptions(decimal: !integerOnly)
          : TextInputType.text,
      inputFormatters: numeric
          ? [
              FilteringTextInputFormatter.allow(
                integerOnly ? RegExp(r'[0-9]') : RegExp(r'[0-9.]'),
              ),
            ]
          : null,
      decoration: _decoration(label, icon, hint: hint),
      validator: requiredField
          ? (value) {
              if (value == null || value.trim().isEmpty) {
                return 'هذا الحقل مطلوب';
              }
              if (numeric) {
                if (integerOnly) {
                  final parsed = int.tryParse(value.trim());
                  if (parsed == null || parsed <= 0) {
                    return 'أدخل رقمًا صحيحًا أكبر من صفر';
                  }
                } else {
                  final parsed = double.tryParse(value.trim());
                  if (parsed == null || !parsed.isFinite || parsed <= 0) {
                    return 'أدخل رقمًا أكبر من صفر';
                  }
                }
              }
              return null;
            }
          : null,
    );
  }

  InputDecoration _decoration(
    String label,
    IconData icon, {
    String? hint,
  }) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: colors.primary, size: 20),
      filled: true,
      fillColor: isDark ? const Color(0xFF1F1F1F) : const Color(0xFFF8FBF9),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: colors.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: colors.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: colors.primary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Marketplace Number Field
// ═══════════════════════════════════════════════════════════════
class _MarketplaceNumberField extends StatefulWidget {
  final MarketplaceAttribute attribute;
  final String? initialValue;
  final InputDecoration decoration;
  final ValueChanged<String> onChanged;
  final bool isDecimal;

  const _MarketplaceNumberField({
    super.key,
    required this.attribute,
    required this.initialValue,
    required this.decoration,
    required this.onChanged,
    this.isDecimal = false,
  });

  @override
  State<_MarketplaceNumberField> createState() =>
      _MarketplaceNumberFieldState();
}

class _MarketplaceNumberFieldState extends State<_MarketplaceNumberField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue ?? '');
  }

  @override
  void didUpdateWidget(covariant _MarketplaceNumberField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialValue != widget.initialValue) {
      final value = widget.initialValue ?? '';
      if (_controller.text != value) _controller.text = value;
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: _controller,
      keyboardType: TextInputType.numberWithOptions(
        decimal: widget.isDecimal,
      ),
      textInputAction: TextInputAction.next,
      inputFormatters: [
        FilteringTextInputFormatter.allow(
          widget.isDecimal ? RegExp(r'[0-9.]') : RegExp(r'[0-9]'),
        ),
      ],
      decoration: widget.decoration,
      onChanged: widget.onChanged,
      validator: widget.attribute.isRequired
          ? (value) {
              if (value == null || value.trim().isEmpty) {
                return 'أدخل ${widget.attribute.nameAr}';
              }
              final number = num.tryParse(value.trim());
              if (number == null || !number.isFinite || number <= 0) {
                return 'أدخل ${widget.attribute.nameAr} بشكل صحيح';
              }
              return null;
            }
          : null,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

// ═══════════════════════════════════════════════════════════════
// Marketplace Text Field
// ═══════════════════════════════════════════════════════════════
class _MarketplaceTextField extends StatefulWidget {
  final MarketplaceAttribute attribute;
  final String? initialValue;
  final InputDecoration decoration;
  final ValueChanged<String> onChanged;

  const _MarketplaceTextField({
    super.key,
    required this.attribute,
    required this.initialValue,
    required this.decoration,
    required this.onChanged,
  });

  @override
  State<_MarketplaceTextField> createState() => _MarketplaceTextFieldState();
}

class _MarketplaceTextFieldState extends State<_MarketplaceTextField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue ?? '');
  }

  @override
  void didUpdateWidget(covariant _MarketplaceTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialValue != widget.initialValue) {
      final value = widget.initialValue ?? '';
      if (_controller.text != value) _controller.text = value;
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: _controller,
      textInputAction: TextInputAction.next,
      decoration: widget.decoration,
      onChanged: widget.onChanged,
      validator: widget.attribute.isRequired
          ? (value) {
              if (value == null || value.trim().isEmpty) {
                return 'أدخل ${widget.attribute.nameAr}';
              }
              return null;
            }
          : null,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

// ═══════════════════════════════════════════════════════════════
// Category Picker Sheet
// ═══════════════════════════════════════════════════════════════
class _CategoryPickerSheet extends StatefulWidget {
  final List<Map<String, dynamic>> categories;
  final String? selectedId;

  const _CategoryPickerSheet({
    required this.categories,
    this.selectedId,
  });

  @override
  State<_CategoryPickerSheet> createState() => _CategoryPickerSheetState();
}

class _CategoryPickerSheetState extends State<_CategoryPickerSheet> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<_PickerItem> _buildFlatList() {
    final items = <_PickerItem>[];

    final childrenByParent = <String, List<Map<String, dynamic>>>{};
    final roots = <Map<String, dynamic>>[];

    for (final c in widget.categories) {
      final pid = c['parent_id']?.toString();
      if (pid == null || pid.isEmpty) {
        roots.add(c);
      } else {
        childrenByParent.putIfAbsent(pid, () => []).add(c);
      }
    }

    void sortByOrder(List<Map<String, dynamic>> list) {
      list.sort((a, b) {
        final sa = (a['sort_order'] as num?)?.toInt() ?? 0;
        final sb = (b['sort_order'] as num?)?.toInt() ?? 0;
        return sa.compareTo(sb);
      });
    }

    sortByOrder(roots);

    void addItem(
      Map<String, dynamic> c, {
      String? parentName,
      String? parentPath,
      int depth = 0,
    }) {
      final id = c['id']?.toString() ?? '';
      if (id.isEmpty) return;

      final name = c['name_ar']?.toString() ?? '';
      final slug = c['slug']?.toString() ?? '';
      final fullPath = parentPath == null ? name : '$parentPath › $name';

      items.add(_PickerItem(
        id: id,
        slug: slug,
        name: name,
        parentName: parentName,
        fullPath: fullPath,
        isRoot: depth == 0,
        depth: depth,
      ));

      final children = childrenByParent[id] ?? [];
      sortByOrder(children);
      for (final child in children) {
        addItem(
          child,
          parentName: name,
          parentPath: fullPath,
          depth: depth + 1,
        );
      }
    }

    for (final root in roots) {
      addItem(root);
    }

    return items;
  }

  List<_PickerItem> _filtered(List<_PickerItem> all) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return all;

    final matchingIds = <String>{};

    for (final item in all) {
      final matches = item.name.toLowerCase().contains(q) ||
          item.slug.toLowerCase().contains(q) ||
          (item.parentName?.toLowerCase().contains(q) ?? false) ||
          item.fullPath.toLowerCase().contains(q);

      if (matches) {
        matchingIds.add(item.id);
        if (item.isRoot) {
          for (final child in all) {
            if (child.parentName == item.name) {
              matchingIds.add(child.id);
            }
          }
        }
      }
    }

    return all.where((item) => matchingIds.contains(item.id)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final all = _buildFlatList();
    final filtered = _filtered(all);

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(28),
            ),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 8),
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: colors.onSurface.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.category_rounded,
                        color: colors.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'اختر تصنيف العرض',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            '${all.length} تصنيف متاح',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _query = v),
                  textInputAction: TextInputAction.search,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    hintText: 'ابحث... (مثال: موبايل، حذاء، أرز)',
                    hintStyle: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: colors.primary,
                      size: 22,
                    ),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                            icon: const Icon(Icons.close_rounded, size: 18),
                          ),
                    filled: true,
                    fillColor: isDark
                        ? const Color(0xFF252525)
                        : const Color(0xFFF5F8F6),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: colors.outlineVariant,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: colors.primary,
                        width: 1.5,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: filtered.isEmpty
                    ? _buildEmpty(colors)
                    : ListView.separated(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 6),
                        itemBuilder: (_, index) {
                          final item = filtered[index];
                          final isSelected = item.id == widget.selectedId;

                          return _CategoryTile(
                            item: item,
                            isSelected: isSelected,
                            onTap: () {
                              Navigator.pop(context, {
                                'id': item.id,
                                'slug': item.slug,
                                'name_ar': item.name,
                              });
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmpty(ColorScheme colors) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.search_off_rounded,
                color: colors.primary,
                size: 36,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'لا توجد نتائج',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'جرب كلمة بحث مختلفة',
              style: TextStyle(
                fontSize: 13,
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Helper Classes
// ═══════════════════════════════════════════════════════════════
class _PickerItem {
  final String id;
  final String slug;
  final String name;
  final String? parentName;
  final String fullPath;
  final bool isRoot;
  final int depth;

  _PickerItem({
    required this.id,
    required this.slug,
    required this.name,
    required this.parentName,
    required this.fullPath,
    required this.isRoot,
    required this.depth,
  });
}

class _CategoryTile extends StatelessWidget {
  final _PickerItem item;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryTile({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final indent = (item.depth * 14.0).clamp(0.0, 42.0);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: EdgeInsetsDirectional.only(start: indent),
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? colors.primary.withValues(alpha: 0.1)
                : (isDark ? const Color(0xFF252525) : const Color(0xFFF9FBFA)),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? colors.primary.withValues(alpha: 0.5)
                  : colors.outlineVariant,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: item.isRoot
                      ? colors.primary.withValues(alpha: 0.12)
                      : colors.primary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  item.isRoot
                      ? Icons.folder_rounded
                      : Icons.label_outline_rounded,
                  color: colors.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (item.parentName != null) ...[
                      Text(
                        item.parentName!,
                        style: TextStyle(
                          fontSize: 10.5,
                          color: colors.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                    ],
                    Text(
                      item.name,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight:
                            item.isRoot ? FontWeight.w900 : FontWeight.w700,
                        color: isSelected ? colors.primary : colors.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: colors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: 14,
                  ),
                )
              else
                Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 14,
                  color: colors.onSurfaceVariant.withValues(alpha: 0.4),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
