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
  final _phoneController = TextEditingController(); // ✅
  final _whatsappController = TextEditingController(); // ✅

  final _picker = ImagePicker();

  final _repository = CommunityOfferRepository();
  final _marketplaceRepository = MarketplaceRepositoryImpl();

  static const String _listingType = 'symbolic_sale';

  // Category
  String? _categoryId;
  String? _categorySlug;
  String? _marketplaceCategoryId;

  // ✅ إحداثيات مكان الاستلام
  double? _lat;
  double? _lng;

  // Marketplace Dynamic Attributes
  List<MarketplaceAttribute> _marketplaceAttributes = [];
  final Map<String, List<MarketplaceAttributeOption>> _marketplaceOptions = {};
  final Map<String, String> _selectedMarketplaceOptionIds = {};
  final Map<String, String> _selectedMarketplaceValues = {};
  final Map<String, String> _selectedMarketplaceValueTypes = {};

  bool _isLoadingMarketplaceAttributes = false;
  bool _isLoadingMarketplaceOptions = false;

  int _categoryRequestId = 0;
  int _optionsRequestId = 0;

  // Images
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

  // ============================================================
  // Prefill from initialData
  // ============================================================
  void _prefillFromInitialData() {
    final data = widget.initialData;
    if (data == null) {
      _isInitializing = false;
      return;
    }

    _titleController.text = data['title']?.toString() ?? '';
    _descriptionController.text = data['description']?.toString() ?? '';
    _locationController.text = data['pickup_location']?.toString() ?? '';

    // ✅ نقرأ الإحداثيات
    _lat = (data['latitude'] as num?)?.toDouble();
    _lng = (data['longitude'] as num?)?.toDouble();

    // ✅ نقرأ رقم الهاتف والواتساب (phone مش contact_phone)
    _phoneController.text = data['phone']?.toString() ?? '';
    _whatsappController.text = data['whatsapp']?.toString() ?? '';

    final price = data['price'];
    if (price != null) {
      final p = price is num
          ? price.toDouble()
          : double.tryParse(price.toString()) ?? 0;
      if (p > 0) {
        _priceController.text = p.toStringAsFixed(0);
      }
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
    _marketplaceCategoryId = data['marketplace_category_id']?.toString();

    _expiryOption = _deriveExpiryOption(data['expires_at']);

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

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    _locationController.dispose();
    _phoneController.dispose(); // ✅
    _whatsappController.dispose(); // ✅
    super.dispose();
  }

  // ============================================================
  // Helpers
  // ============================================================
  bool get _isCars => _categorySlug == 'cars';
  bool get _isOther => _categorySlug == 'other';
  bool get _isEditMode => widget.isEditMode;
  int get _totalImages => _keptImagePaths.length + _newImages.length;

  // ✅ التحقق من رقم مصري
  bool _isValidEgyptianPhone(String phone) {
    final cleaned = phone.replaceAll(RegExp(r'[^\d]'), '');
    if (cleaned.length != 11) return false;
    if (!cleaned.startsWith('01')) return false;
    return true;
  }

  // ============================================================
  // فتح خريطة تحديد الموقع
  // ============================================================
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

  // ============================================================
  // Load categories
  // ============================================================
  Future<void> _loadCategories() async {
    if (mounted) setState(() => _isLoadingCategories = true);

    try {
      final rows = await _repository.getCategories();
      if (!mounted) return;

      setState(() => _categories = rows);

      if (_isEditMode && _marketplaceCategoryId != null) {
        await _loadMarketplaceAttributes(_marketplaceCategoryId!);
      }
    } catch (error) {
      debugPrint('❌ Failed to load categories: $error');
      if (mounted) {
        _showMessage('تعذر تحميل التصنيفات. حاول مرة أخرى.');
      }
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

      if (response == null) {
        debugPrint('⚠️ No active marketplace category with slug: $slug');
        return null;
      }

      return response['id']?.toString();
    } catch (error) {
      debugPrint('⚠️ Failed to load marketplace category: $error');
      return null;
    }
  }

  Future<void> _loadMarketplaceAttributes(String categoryId) async {
    if (!mounted) return;

    final requestId = ++_categoryRequestId;

    setState(() {
      _isLoadingMarketplaceAttributes = true;
      _isLoadingMarketplaceOptions = false;

      _marketplaceAttributes = [];
      _marketplaceOptions.clear();
      _selectedMarketplaceOptionIds.clear();
      _selectedMarketplaceValues.clear();
      _selectedMarketplaceValueTypes.clear();
    });

    try {
      final attributes =
          await _marketplaceRepository.getCategoryFlow(categoryId);

      if (!mounted) return;
      if (requestId != _categoryRequestId) return;
      if (_marketplaceCategoryId != categoryId) return;

      setState(() {
        _marketplaceAttributes = attributes.where((attribute) {
          if (_isCars) return true;
          if (_isOther) {
            return attribute.slug == 'condition' ||
                attribute.slug == 'item_type';
          }
          return attribute.slug == 'condition';
        }).toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

        _isLoadingMarketplaceAttributes = false;
      });

      if (_marketplaceAttributes.isNotEmpty) {
        await _loadMarketplaceAttribute(_marketplaceAttributes.first);
      }
    } catch (error, stackTrace) {
      debugPrint('❌ Failed to load marketplace attributes: $error');
      debugPrint('$stackTrace');

      if (!mounted) return;
      if (requestId != _categoryRequestId) return;

      setState(() {
        _isLoadingMarketplaceAttributes = false;
        _marketplaceAttributes = [];
        _marketplaceOptions.clear();
        _selectedMarketplaceOptionIds.clear();
        _selectedMarketplaceValues.clear();
        _selectedMarketplaceValueTypes.clear();
      });

      _showMessage('تعذر تحميل خصائص التصنيف. حاول مرة أخرى.');
    }
  }

  Future<void> _loadMarketplaceAttribute(
    MarketplaceAttribute attribute, {
    String? parentOptionId,
  }) async {
    final categoryId = _marketplaceCategoryId;
    if (categoryId == null || categoryId.isEmpty) return;

    if (attribute.inputType != 'select') {
      if (!mounted) return;
      setState(() {
        _marketplaceOptions[attribute.slug] =
            const <MarketplaceAttributeOption>[];
        _isLoadingMarketplaceOptions = false;
      });
      return;
    }

    final requestCategoryId = categoryId;
    final requestAttributeId = attribute.attributeId;
    final requestId = ++_optionsRequestId;

    if (mounted) setState(() => _isLoadingMarketplaceOptions = true);

    try {
      final response = await Supabase.instance.client
          .from('marketplace_category_attribute_options')
          .select('''
            option_id,
            marketplace_attribute_options!inner(
              id,
              attribute_id,
              parent_option_id,
              value,
              label_ar,
              label_en,
              icon,
              sort_order,
              is_active,
              metadata
            )
            ''')
          .eq('category_id', requestCategoryId)
          .eq('attribute_id', requestAttributeId)
          .eq('marketplace_attribute_options.is_active', true)
          .order('sort_order',
              referencedTable: 'marketplace_attribute_options');

      if (!mounted) return;
      if (requestId != _optionsRequestId) return;
      if (_marketplaceCategoryId != requestCategoryId) return;

      final rows = response as List;

      var options = rows
          .whereType<Map>()
          .map((row) {
            final raw = row['marketplace_attribute_options'];
            if (raw is! Map) return null;
            final item = Map<String, dynamic>.from(raw);
            return MarketplaceAttributeOption(
              id: item['id']?.toString() ?? '',
              attributeId: item['attribute_id']?.toString() ?? '',
              value: item['value']?.toString() ?? '',
              labelAr: item['label_ar']?.toString() ?? '',
              labelEn: item['label_en']?.toString() ?? '',
              icon: item['icon']?.toString(),
              sortOrder: (item['sort_order'] as num?)?.toInt() ?? 0,
              parentOptionId: item['parent_option_id']?.toString(),
            );
          })
          .whereType<MarketplaceAttributeOption>()
          .where((option) => option.id.isNotEmpty)
          .toList();

      final seen = <String>{};
      options = options.where((option) {
        if (seen.contains(option.id)) return false;
        seen.add(option.id);
        return true;
      }).toList();

      if (parentOptionId != null && parentOptionId.isNotEmpty) {
        final children = options
            .where((option) => option.parentOptionId == parentOptionId)
            .toList();

        if (children.isNotEmpty) {
          options = children;
        } else {
          options =
              options.where((option) => option.parentOptionId == null).toList();
        }
      } else {
        final hasChildren =
            options.any((option) => option.parentOptionId != null);
        if (hasChildren) {
          options =
              options.where((option) => option.parentOptionId == null).toList();
        }
      }

      options.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

      if (!mounted) return;
      if (requestId != _optionsRequestId) return;
      if (_marketplaceCategoryId != requestCategoryId) return;

      setState(() {
        _marketplaceOptions[attribute.slug] = options;
        _isLoadingMarketplaceOptions = false;
      });
    } catch (error, stackTrace) {
      debugPrint('❌ Error loading options for ${attribute.slug}: $error');
      debugPrint('$stackTrace');

      if (!mounted) return;
      if (requestId != _optionsRequestId) return;

      setState(() {
        _marketplaceOptions[attribute.slug] =
            const <MarketplaceAttributeOption>[];
        _isLoadingMarketplaceOptions = false;
      });

      _showMessage('تعذر تحميل خيارات ${attribute.nameAr}.');
    }
  }

  Future<void> _selectMarketplaceOption({
    required MarketplaceAttribute attribute,
    required MarketplaceAttributeOption option,
  }) async {
    final categoryId = _marketplaceCategoryId;
    if (categoryId == null || categoryId.isEmpty) return;

    final attributeIndex = _marketplaceAttributes
        .indexWhere((item) => item.attributeId == attribute.attributeId);

    if (attributeIndex == -1) return;

    setState(() {
      _selectedMarketplaceOptionIds[attribute.slug] = option.id;
      _selectedMarketplaceValues[attribute.slug] = option.value;
      _selectedMarketplaceValueTypes[attribute.slug] = 'option';

      for (var i = attributeIndex + 1; i < _marketplaceAttributes.length; i++) {
        final next = _marketplaceAttributes[i];
        _selectedMarketplaceOptionIds.remove(next.slug);
        _selectedMarketplaceValues.remove(next.slug);
        _selectedMarketplaceValueTypes.remove(next.slug);
        _marketplaceOptions.remove(next.slug);
      }

      _isLoadingMarketplaceOptions = true;
    });

    final requestId = ++_optionsRequestId;

    try {
      final nextAttribute = await _marketplaceRepository.getNextAttribute(
        categoryId: categoryId,
        optionId: option.id,
      );

      if (!mounted) return;
      if (requestId != _optionsRequestId) return;
      if (_marketplaceCategoryId != categoryId) return;

      if (nextAttribute == null) {
        setState(() => _isLoadingMarketplaceOptions = false);
        return;
      }

      final isAllowed = _marketplaceAttributes
          .any((item) => item.attributeId == nextAttribute.attributeId);

      if (!isAllowed) {
        setState(() => _isLoadingMarketplaceOptions = false);
        return;
      }

      String? parentOptionId;
      if (nextAttribute.inputType == 'select') {
        parentOptionId = option.id;
      }

      await _loadMarketplaceAttribute(
        nextAttribute,
        parentOptionId: parentOptionId,
      );
    } catch (error, stackTrace) {
      debugPrint('❌ Failed to determine next attribute: $error');
      debugPrint('$stackTrace');

      if (!mounted) return;
      if (requestId != _optionsRequestId) return;

      setState(() => _isLoadingMarketplaceOptions = false);
      _showMessage('تعذر تحميل الخطوة التالية. حاول مرة أخرى.');
    }
  }

  Future<void> _saveMarketplaceValue({
    required MarketplaceAttribute attribute,
    required String value,
  }) async {
    final cleanValue = value.trim();
    if (cleanValue.isEmpty) return;

    final categoryId = _marketplaceCategoryId;
    if (categoryId == null || categoryId.isEmpty) return;

    final attributeIndex = _marketplaceAttributes
        .indexWhere((item) => item.attributeId == attribute.attributeId);

    if (attributeIndex == -1) return;

    setState(() {
      _selectedMarketplaceValues[attribute.slug] = cleanValue;
      _selectedMarketplaceValueTypes[attribute.slug] = attribute.inputType;
      _selectedMarketplaceOptionIds.remove(attribute.slug);

      for (var i = attributeIndex + 1; i < _marketplaceAttributes.length; i++) {
        final next = _marketplaceAttributes[i];
        _selectedMarketplaceOptionIds.remove(next.slug);
        _selectedMarketplaceValues.remove(next.slug);
        _selectedMarketplaceValueTypes.remove(next.slug);
        _marketplaceOptions.remove(next.slug);
      }
    });

    final nextIndex = attributeIndex + 1;

    if (nextIndex >= _marketplaceAttributes.length) {
      if (mounted) setState(() => _isLoadingMarketplaceOptions = false);
      return;
    }

    final nextAttribute = _marketplaceAttributes[nextIndex];
    if (!mounted) return;
    await _loadMarketplaceAttribute(nextAttribute);
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
        if (attribute.inputType == 'number') {
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
        if (attribute.inputType == 'number') {
          final number = num.tryParse(value.trim());
          if (number == null || !number.isFinite || number <= 0) {
            return 'أدخل ${attribute.nameAr} بشكل صحيح';
          }
        }
      }
    }
    return null;
  }

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
    final path = _keptImagePaths.length > index
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

    // ✅ التحقق من تحديد الموقع
    if (_lat == null || _lng == null) {
      _showMessage('حدّد مكان الاستلام على الخريطة');
      return;
    }

    final lat = _lat!;
    final lng = _lng!;

    // ✅ التحقق من رقم الهاتف
    final contactPhone = _phoneController.text.trim();
    if (contactPhone.isEmpty) {
      _showMessage('اكتب رقم هاتفك للتواصل');
      return;
    }

    if (!_isValidEgyptianPhone(contactPhone)) {
      _showMessage('رقم الهاتف غير صحيح (مثال: 01012345678)');
      return;
    }

    // ✅ رقم الواتساب (اختياري)
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
      // ======================================================
      // EDIT MODE
      // ======================================================
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
            'phone': contactPhone, // ✅ تم التعديل
            'whatsapp': whatsapp, // ✅
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
            contactPhone: contactPhone, // ✅
            whatsapp: whatsapp, // ✅
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

      // ======================================================
      // CREATE MODE
      // ======================================================
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
        'phone': contactPhone, // ✅ تم التعديل
        'whatsapp': whatsapp, // ✅
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
          contactPhone: contactPhone, // ✅
          whatsapp: whatsapp, // ✅
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
    final conditionAttribute = _marketplaceAttributes
        .where((attribute) => attribute.slug == 'condition');

    if (conditionAttribute.isEmpty) return 'good';

    final selectedOptionId = _selectedMarketplaceOptionIds['condition'];
    if (selectedOptionId == null || selectedOptionId.isEmpty) return 'good';

    final options = _marketplaceOptions['condition'] ??
        const <MarketplaceAttributeOption>[];

    final selected = options.where((option) => option.id == selectedOptionId);
    if (selected.isEmpty) return 'good';

    final value = selected.first.value.trim();
    if (value.isEmpty) return 'good';

    return value;
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
          backgroundColor: colors.surface,
          appBar: AppBar(
            title: Text(_isEditMode ? 'تعديل العرض' : 'أضف عرضًا جديدًا'),
            centerTitle: true,
            backgroundColor: isDark ? const Color(0xFF1F1F1F) : colors.surface,
            foregroundColor: colors.onSurface,
            elevation: 0,
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
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                    children: [
                      _buildIntro(colors),
                      const SizedBox(height: 18),
                      _buildImages(colors),
                      const SizedBox(height: 18),
                      _buildDetailsCard(colors),
                      const SizedBox(height: 18),
                      _buildLocationCard(colors),
                      const SizedBox(height: 18),
                      _buildExpiryCard(colors),
                      const SizedBox(height: 18),
                      _buildConfirmation(colors),
                      const SizedBox(height: 24),
                      _buildSubmitButton(colors),
                    ],
                  ),
                ),
        ),
      ),
    );
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
      icon: Icons.edit_note_rounded,
      child: Column(
        children: [
          _field(
            _titleController,
            'عنوان العرض',
            'مثال: جاكت شتوي بحالة ممتازة',
            Icons.title_rounded,
            requiredField: true,
          ),
          const SizedBox(height: 12),
          _buildCategoryDropdown(colors),
          if (_isLoadingMarketplaceAttributes) ...[
            const SizedBox(height: 12),
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ],
          if (!_isLoadingMarketplaceAttributes &&
              _marketplaceAttributes.isNotEmpty) ...[
            const SizedBox(height: 18),
            ..._buildMarketplaceAttributeWidgets(),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _field(
                  _quantityController,
                  'الكمية',
                  '1',
                  Icons.inventory_2_outlined,
                  requiredField: true,
                  numeric: true,
                  integerOnly: true,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _field(
                  _priceController,
                  _isCars ? 'سعر السيارة' : 'السعر الرمزي بالجنيه',
                  _isCars ? 'مثال: 100000' : 'مثال: 100',
                  Icons.payments_outlined,
                  requiredField: true,
                  numeric: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _descriptionController,
            minLines: 4,
            maxLines: 6,
            textInputAction: TextInputAction.newline,
            decoration: _decoration(
              'الوصف والتفاصيل',
              Icons.description_outlined,
            ),
            validator: (value) {
              if (value == null || value.trim().length < 10) {
                return 'اكتب وصفًا مختصرًا وواضحًا';
              }
              return null;
            },
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 16,
                  color: colors.primary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'وضح أي خدوش أو تلف أو عيوب موجودة في المنتج حتى يعرف المشتري حالته قبل الاستلام.',
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
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'السعر المعروض هو السعر الذي سيظهر للمشتري.',
              style: TextStyle(
                color: colors.onSurfaceVariant,
                fontSize: 11,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildMarketplaceAttributeWidgets() {
    final visibleAttributes = _getVisibleMarketplaceAttributes();

    return visibleAttributes.map((attribute) {
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

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            initialValue: safeSelectedId,
            isExpanded: true,
            decoration: _decoration(attribute.nameAr, Icons.tune_rounded),
            hint: Text(
              safeOptions.isEmpty
                  ? 'لا توجد خيارات'
                  : 'اختر ${attribute.nameAr}',
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
            validator: attribute.isRequired
                ? (value) {
                    if (value == null || value.isEmpty) {
                      return 'اختر ${attribute.nameAr}';
                    }
                    return null;
                  }
                : null,
            onChanged: safeOptions.isEmpty
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
          if (_isCurrentLoadingAttribute(attribute))
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: LinearProgressIndicator(),
            ),
        ],
      );
    }

    if (attribute.inputType == 'number') {
      return _MarketplaceNumberField(
        key: ValueKey('${attribute.slug}:$selectedValue'),
        attribute: attribute,
        initialValue: selectedValue,
        decoration: _decoration(
          attribute.nameAr,
          Icons.numbers_rounded,
          hint: _numberHint(attribute.slug),
        ).copyWith(suffixText: _numberSuffix(attribute.slug)),
        onSubmitted: (value) {
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
      onSubmitted: (value) {
        _saveMarketplaceValue(attribute: attribute, value: value);
      },
    );
  }

  String _numberHint(String slug) {
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
        return 'أدخل الرقم';
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

  List<MarketplaceAttribute> _getVisibleMarketplaceAttributes() {
    if (_marketplaceAttributes.isEmpty) return const [];

    final visible = <MarketplaceAttribute>[];

    for (final attribute in _marketplaceAttributes) {
      final isFirst =
          attribute.attributeId == _marketplaceAttributes.first.attributeId;
      final hasLoadedOptions = _marketplaceOptions.containsKey(attribute.slug);
      final hasSelection =
          _selectedMarketplaceOptionIds.containsKey(attribute.slug) ||
              _selectedMarketplaceValues.containsKey(attribute.slug);

      if (isFirst || hasLoadedOptions || hasSelection) {
        visible.add(attribute);
      }
    }

    return visible;
  }

  bool _isCurrentLoadingAttribute(MarketplaceAttribute attribute) {
    if (!_isLoadingMarketplaceOptions) return false;
    return !_marketplaceOptions.containsKey(attribute.slug);
  }

  Widget _buildCategoryDropdown(ColorScheme colors) {
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

    final uniqueCategories = <String, Map<String, dynamic>>{};
    for (final category in _categories) {
      final id = category['id']?.toString().trim();
      if (id == null || id.isEmpty) continue;
      uniqueCategories[id] = category;
    }

    final items = uniqueCategories.values
        .map((category) {
          final id = category['id']?.toString();
          final nameAr = category['name_ar']?.toString() ?? '';
          final slug = category['slug']?.toString() ?? '';

          if (id == null || id.isEmpty) return null;

          return DropdownMenuItem<String>(
            value: id,
            child: Text(nameAr.isEmpty ? slug : nameAr),
          );
        })
        .whereType<DropdownMenuItem<String>>()
        .toList();

    final safeCategoryId =
        items.any((item) => item.value == _categoryId) ? _categoryId : null;

    return DropdownButtonFormField<String>(
      initialValue: safeCategoryId,
      isExpanded: true,
      decoration: _decoration('نوع الشيء', Icons.category_outlined),
      items: items,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'اختر تصنيف العرض';
        }
        return null;
      },
      onChanged: (value) async {
        if (value == null) return;

        final selected = uniqueCategories[value];

        if (selected == null) {
          _showMessage('التصنيف غير صحيح.');
          return;
        }

        final slug = selected['slug']?.toString().trim() ?? '';

        if (slug.isEmpty) {
          _showMessage('التصنيف غير صحيح.');
          return;
        }

        final requestId = ++_categoryRequestId;
        ++_optionsRequestId;

        setState(() {
          _categoryId = value;
          _categorySlug = slug;
          _marketplaceCategoryId = null;
          _marketplaceAttributes = [];
          _marketplaceOptions.clear();
          _selectedMarketplaceOptionIds.clear();
          _selectedMarketplaceValues.clear();
          _selectedMarketplaceValueTypes.clear();
          _isLoadingMarketplaceAttributes = true;
          _isLoadingMarketplaceOptions = false;
        });

        final marketplaceCategoryId =
            await _getMarketplaceCategoryIdBySlug(slug);

        if (!mounted) return;
        if (requestId != _categoryRequestId) return;
        if (_categoryId != value) return;

        setState(() {
          _marketplaceCategoryId = marketplaceCategoryId;
          _isLoadingMarketplaceAttributes = false;
        });

        if (marketplaceCategoryId == null) {
          debugPrint('⚠️ No marketplace category for slug=$slug');
          return;
        }

        await _loadMarketplaceAttributes(marketplaceCategoryId);
      },
    );
  }

  // ============================================================
  // ✅ Location Card (مع خريطة + هاتف + واتساب)
  // ============================================================
  Widget _buildLocationCard(ColorScheme colors) {
    final hasLocation = _lat != null && _lng != null;

    return _sectionCard(
      title: 'مكان الاستلام والتواصل',
      icon: Icons.location_on_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // زر تحديد الموقع
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

          // وصف المكان
          _field(
            _locationController,
            'وصف المكان (اختياري)',
            'مثال: شارع البحر، قرب مسجد...',
            Icons.place_outlined,
          ),

          const SizedBox(height: 14),

          // ✅ رقم الهاتف
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

          // ✅ رقم الواتساب (اختياري)
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
        tileColor: Colors.transparent, // ✅ يمنع تحذير ListTile
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

// ================================================================
// Marketplace Number Field
// ================================================================
class _MarketplaceNumberField extends StatefulWidget {
  final MarketplaceAttribute attribute;
  final String? initialValue;
  final InputDecoration decoration;
  final ValueChanged<String> onSubmitted;

  const _MarketplaceNumberField({
    super.key,
    required this.attribute,
    required this.initialValue,
    required this.decoration,
    required this.onSubmitted,
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
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textInputAction: TextInputAction.next,
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
      decoration: widget.decoration,
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
      onFieldSubmitted: widget.onSubmitted,
      onEditingComplete: () {
        final value = _controller.text.trim();
        if (value.isNotEmpty) widget.onSubmitted(value);
        FocusScope.of(context).nextFocus();
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

// ================================================================
// Marketplace Text Field
// ================================================================
class _MarketplaceTextField extends StatefulWidget {
  final MarketplaceAttribute attribute;
  final String? initialValue;
  final InputDecoration decoration;
  final ValueChanged<String> onSubmitted;

  const _MarketplaceTextField({
    super.key,
    required this.attribute,
    required this.initialValue,
    required this.decoration,
    required this.onSubmitted,
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
      minLines: widget.attribute.inputType == 'textarea' ? 3 : 1,
      maxLines: widget.attribute.inputType == 'textarea' ? 5 : 1,
      decoration: widget.decoration,
      validator: widget.attribute.isRequired
          ? (value) {
              if (value == null || value.trim().isEmpty) {
                return 'أدخل ${widget.attribute.nameAr}';
              }
              return null;
            }
          : null,
      onFieldSubmitted: widget.onSubmitted,
      onEditingComplete: () {
        final value = _controller.text.trim();
        if (value.isNotEmpty) widget.onSubmitted(value);
        FocusScope.of(context).nextFocus();
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
