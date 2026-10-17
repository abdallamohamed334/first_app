// lib/features/institutions/presentation/pages/institution_add_offer_page.dart

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/repositories/institutions_repository.dart';
import '../../domain/institution_offer_policy.dart';

class InstitutionAddOfferPage extends StatefulWidget {
  final String institutionId;
  final String institutionType;

  const InstitutionAddOfferPage({
    super.key,
    required this.institutionId,
    required this.institutionType,
  });

  @override
  State<InstitutionAddOfferPage> createState() =>
      _InstitutionAddOfferPageState();
}

class _InstitutionAddOfferPageState extends State<InstitutionAddOfferPage> {
  // ✅ الألوان
  static const _primary = Color(0xFF0B7650);
  static const _primaryDark = Color(0xFF123F31);
  static const _background = Color(0xFFF6FAF8);
  static const _surface = Color(0xFFFFFFFF);
  static const _surfaceVariant = Color(0xFFE8F0EC);
  static const _muted = Color(0xFF71837C);
  static const _accent = Color(0xFFE28B00);
  static const _error = Color(0xFFD64545);

  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _quantityController = TextEditingController();
  final _minBookingQuantityController = TextEditingController(text: '1');
  final _maxBookingQuantityController = TextEditingController();
  final _priceController = TextEditingController();
  final _originalPriceController = TextEditingController();
  final _pickupLocationController = TextEditingController();
  final _pickupNotesController = TextEditingController();
  final _contactPhoneController = TextEditingController();
  final _meatCutController = TextEditingController();
  final _productWeightController = TextEditingController();

  final _repository = InstitutionsRepository();
  final _picker = ImagePicker();
  final List<Uint8List> _images = [];

  // ✅ حقول إضافية
  String _category = 'food';
  String? _productSubcategory;
  String _condition = 'good';
  bool _isHalal = true;
  bool _isVegetarian = false;
  String _storageCondition = 'no_cooling';

  // ═══════════════════════════════════════════════════════════
  // ✅ جديد: اختيار نوع المنتج
  // true  → قريب ينتهي (له تاريخ)
  // false → منتج جديد/عادي (بدون تاريخ)
  // ═══════════════════════════════════════════════════════════
  bool _isExpiringSoon = false;
  DateTime? _productExpiryAt;
  DateTime? _productPreparedAt;
  DateTime? _pickupStart;
  DateTime? _pickupEnd;
  DateTime? _pickupDeadline;
  bool _usePickupWindow = true;
  bool _isBookable = true;

  /// الصلاحية القصوى التي يسمح بها مسار إنشاء عروض المؤسسات.
  static const Duration _maxOfferLifetime = Duration(hours: 12);

  /// التاريخ الافتراضي لما يختار "قريب ينتهي".

  bool _saving = false;

  bool get _isHomeRestaurant {
    final type = widget.institutionType
        .trim()
        .toLowerCase()
        .replaceAll('-', '_')
        .replaceAll(RegExp(r'\s+'), '_');
    return const {
      'home_restaurant',
      'home_restaurants',
      'مطاعم_منزلية',
      'مطاعم_منزليه',
    }.contains(type);
  }

  // تصنيفات العرض مرتبطة بنوع المؤسسة: بيع رمزي أو فائض مؤسسة.
  static const _categoryDefinitions = <String, Map<String, dynamic>>{
    'food': {'label': '🍽️ وجبات', 'icon': Icons.restaurant_rounded},
    'bakery': {'label': '🥖 مخبوزات', 'icon': Icons.bakery_dining_rounded},
    'dessert': {'label': '🍰 حلويات', 'icon': Icons.cake_rounded},
    'fruit': {'label': '🍎 فواكه', 'icon': Icons.apple_rounded},
    'drink': {'label': '🥤 مشروبات', 'icon': Icons.local_drink_rounded},
    'meat': {'label': '🥩 لحوم', 'icon': Icons.restaurant_menu_rounded},
    'other': {'label': '📦 أخرى', 'icon': Icons.category_rounded},
  };

  List<Map<String, dynamic>> get _categories =>
      InstitutionOfferPolicy.categoryIdsFor(widget.institutionType)
          .map((id) => {'id': id, ...?_categoryDefinitions[id]})
          .where((category) => category.length > 1)
          .toList(growable: false);

  String get _normalizedInstitutionType =>
      InstitutionOfferPolicy.normalizeType(widget.institutionType);

  List<Map<String, String>> get _productSubcategories {
    switch (_normalizedInstitutionType) {
      case 'grocery':
      case 'supermarket':
        return const [
          {'id': 'canned_goods', 'label': 'معلبات', 'category': 'food'},
          {'id': 'drink', 'label': 'مشروبات', 'category': 'drink'},
          {'id': 'dairy', 'label': 'ألبان', 'category': 'food'},
        ];
      case 'butcher':
      case 'meat_shop':
        return const [
          {'id': 'beef', 'label': 'لحوم بقري', 'category': 'meat'},
          {'id': 'lamb', 'label': 'لحوم ضأن', 'category': 'meat'},
          {'id': 'poultry', 'label': 'دواجن', 'category': 'meat'},
          {'id': 'other_meat', 'label': 'أنواع أخرى', 'category': 'meat'},
        ];
      case 'bakery':
        return const [
          {'id': 'bakery', 'label': 'مخبوزات', 'category': 'bakery'},
          {'id': 'dessert', 'label': 'حلويات', 'category': 'dessert'},
        ];
      default:
        return const [];
    }
  }

  // ✅ قائمة حالات المنتج
  final List<Map<String, dynamic>> _conditions = [
    {'id': 'new', 'label': 'جديد', 'color': _primary},
    {'id': 'very_good', 'label': 'ممتاز', 'color': const Color(0xFF3679C8)},
    {'id': 'good', 'label': 'جيد', 'color': const Color(0xFFB77700)},
    {
      'id': 'needs_repair',
      'label': 'يحتاج إصلاح',
      'color': const Color(0xFFD64545)
    },
  ];

  @override
  void initState() {
    super.initState();
    if (_isHomeRestaurant) _category = '';
    if (!_isHomeRestaurant) {
      final categories = _categories;
      if (categories.isNotEmpty) _category = categories.first['id'] as String;
    }
    final subcategories = _productSubcategories;
    if (subcategories.isNotEmpty) {
      _productSubcategory = subcategories.first['id'];
      _category = subcategories.first['category']!;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _quantityController.dispose();
    _minBookingQuantityController.dispose();
    _maxBookingQuantityController.dispose();
    _priceController.dispose();
    _originalPriceController.dispose();
    _pickupLocationController.dispose();
    _pickupNotesController.dispose();
    _contactPhoneController.dispose();
    _meatCutController.dispose();
    _productWeightController.dispose();
    super.dispose();
  }

  // ✅ حساب طبيعة المنتج بناءً على تاريخ الانتهاء
  Map<String, dynamic> _getProductNature() {
    final now = DateTime.now();
    final productExpiry = _productExpiryAt;
    if (productExpiry == null) {
      return {
        'id': 'ordinary',
        'label': 'منتج عادي',
        'color': _primary,
        'icon': Icons.inventory_2_rounded,
        'description': 'يتم توضيح تاريخ الصلاحية عند تحديده.',
        'days': 365,
      };
    }
    final daysLeft = productExpiry.difference(now).inDays;

    if (daysLeft < 0) {
      return {
        'id': 'expired',
        'label': '🔴 منتهي الصلاحية',
        'color': _error,
        'icon': Icons.warning_amber_rounded,
        'description': 'انتهت صلاحية هذا المنتج',
        'days': daysLeft,
      };
    } else if (daysLeft <= 3) {
      return {
        'id': 'expiring_soon',
        'label': '🟠 ينتهي قريباً',
        'color': _accent,
        'icon': Icons.timer_outlined,
        'description': 'ينتهي خلال $daysLeft أيام - مناسب للاستخدام الفوري',
        'days': daysLeft,
      };
    } else if (daysLeft <= 7) {
      return {
        'id': 'fresh',
        'label': '🟢 طازج',
        'color': _primary,
        'icon': Icons.fiber_new_rounded,
        'description': 'منتج طازج، صلاحية متبقية $daysLeft يوم',
        'days': daysLeft,
      };
    } else {
      return {
        'id': 'long_shelf',
        'label': '📦 طويل الصلاحية',
        'color': const Color(0xFF3679C8),
        'icon': Icons.inventory_2_rounded,
        'description': 'صلاحية متبقية $daysLeft يوم - مناسب للتخزين',
        'days': daysLeft,
      };
    }
  }

  Future<void> _pickImages() async {
    if (_saving) return;
    try {
      final files = await _picker.pickMultiImage(
        imageQuality: 84,
        maxWidth: 1600,
        maxHeight: 1600,
      );
      if (files.isEmpty) return;

      final remaining = 6 - _images.length;
      if (remaining <= 0) {
        _showMessage('يمكنك إضافة 6 صور كحد أقصى', error: true);
        return;
      }

      final selectedBytes = <Uint8List>[];
      for (final file in files.take(remaining)) {
        selectedBytes.add(await file.readAsBytes());
      }

      if (!mounted) return;
      setState(() => _images.addAll(selectedBytes));
    } catch (_) {
      if (mounted) {
        _showMessage('تعذر اختيار الصور. حاول مرة أخرى', error: true);
      }
    }
  }

  Future<void> _chooseExpiryDate() async {
    final now = DateTime.now();
    final latestAllowed = DateTime(now.year + 10, now.month, now.day);
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: _productExpiryAt ?? now.add(const Duration(days: 3)),
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: latestAllowed,
      helpText: 'اختر تاريخ انتهاء صلاحية المنتج',
      cancelText: 'إلغاء',
      confirmText: 'تأكيد',
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
                primary: _primary,
                onPrimary: Colors.white,
                surface: Colors.white,
              ),
        ),
        child: child!,
      ),
    );
    if (!mounted || selectedDate == null) return;
    setState(() {
      _productExpiryAt = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        23,
        59,
        59,
      );
    });
  }

  Future<DateTime?> _choosePickupDateTime({DateTime? initial}) async {
    final now = DateTime.now();
    final latestAllowed = now.add(_maxOfferLifetime);
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: initial != null && initial.isAfter(now) ? initial : now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(latestAllowed.year, latestAllowed.month, latestAllowed.day),
      helpText: 'اختر يوم الاستلام',
      cancelText: 'إلغاء',
      confirmText: 'التالي',
    );
    if (!mounted || selectedDate == null) return null;
    final selectedTime = await showTimePicker(
      context: context,
      initialTime: initial != null && initial.isAfter(now)
          ? TimeOfDay.fromDateTime(initial)
          : TimeOfDay.fromDateTime(now.add(const Duration(hours: 1))),
      helpText: 'اختر وقت الاستلام',
      cancelText: 'إلغاء',
      confirmText: 'تأكيد',
    );
    if (!mounted || selectedTime == null) return null;
    final value = DateTime(selectedDate.year, selectedDate.month,
        selectedDate.day, selectedTime.hour, selectedTime.minute);
    if (value.isBefore(now) || value.isAfter(latestAllowed)) {
      _showMessage('وقت الاستلام يجب أن يكون خلال الـ 12 ساعة القادمة', error: true);
      return null;
    }
    return value;
  }

  Future<void> _choosePreparedDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _productPreparedAt ?? now,
      firstDate: DateTime(now.year - 1, now.month, now.day),
      lastDate: DateTime(now.year, now.month, now.day),
      helpText: 'اختر تاريخ الإنتاج أو التجهيز',
      cancelText: 'إلغاء',
      confirmText: 'تأكيد',
    );
    if (!mounted || date == null) return;
    setState(() => _productPreparedAt = date);
  }

  String _normalizeDigits(String value) {
    const arabic = '٠١٢٣٤٥٦٧٨٩';
    const persian = '۰۱۲۳۴۵۶۷۸۹';
    var result = value;
    for (var i = 0; i < 10; i++) {
      result = result.replaceAll(arabic[i], '$i');
      result = result.replaceAll(persian[i], '$i');
    }
    return result.trim();
  }

  String _getCategoryLabel() {
    final subcategory =
        _productSubcategories.where((c) => c['id'] == _productSubcategory);
    if (subcategory.isNotEmpty) return subcategory.first['label']!;
    final category = _categories.where((c) => c['id'] == _category);
    return category.isNotEmpty ? category.first['label'] as String : _category;
  }

  Future<void> _save() async {
    if (_saving) return;
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (!InstitutionOfferPolicy.canPublishOffers(widget.institutionType)) {
      _showMessage(
        'نوع المؤسسة ده لا ينشر عروضًا في قسم المؤسسات حاليًا',
        error: true,
      );
      return;
    }

    final quantity = int.tryParse(_normalizeDigits(_quantityController.text));
    final minBookingQuantity = _isBookable
        ? int.tryParse(_normalizeDigits(_minBookingQuantityController.text))
        : 1;
    final minBookingQuantityToSend = minBookingQuantity ?? 1;
    final maxBookingText =
        _isBookable ? _maxBookingQuantityController.text.trim() : '';
    final maxBookingQuantity = maxBookingText.isEmpty
        ? null
        : int.tryParse(_normalizeDigits(maxBookingText));
    final weightText = _productWeightController.text.trim();
    final productWeight = weightText.isEmpty
        ? null
        : double.tryParse(_normalizeDigits(weightText).replaceAll(',', '.'));
    final symbolicPrice = double.tryParse(
      _normalizeDigits(_priceController.text).replaceAll(',', '.'),
    );
    final originalText = _originalPriceController.text.trim();
    final originalPrice = originalText.isEmpty
        ? null
        : double.tryParse(_normalizeDigits(originalText).replaceAll(',', '.'));

    if (_isHomeRestaurant &&
        !const {'home_sweets', 'home_food'}.contains(_category)) {
      _showMessage('اختر نوع الحاجة: حلويات بيتي أو أكل بيتي', error: true);
      return;
    }
    if (quantity == null || quantity <= 0) {
      _showMessage('اكتب كمية صحيحة أكبر من صفر', error: true);
      return;
    }
    if (_isBookable &&
        (minBookingQuantity == null ||
            minBookingQuantity < 1 ||
            minBookingQuantity > quantity)) {
      _showMessage('الحد الأدنى للحجز يجب أن يكون بين 1 والكمية المتاحة', error: true);
      return;
    }
    if (_isBookable && maxBookingText.isNotEmpty &&
        (maxBookingQuantity == null ||
            maxBookingQuantity < minBookingQuantityToSend ||
            maxBookingQuantity > quantity)) {
      _showMessage('الحد الأقصى يجب ألا يقل عن الحد الأدنى أو يتجاوز الكمية', error: true);
      return;
    }
    if (symbolicPrice == null || symbolicPrice < 0) {
      _showMessage('اكتب سعرًا رمزيًا صحيحًا', error: true);
      return;
    }
    if (originalText.isNotEmpty &&
        (originalPrice == null || originalPrice < 0)) {
      _showMessage('السعر الأصلي غير صحيح', error: true);
      return;
    }

    if (originalPrice != null && symbolicPrice > originalPrice) {
      _showMessage(
        '⚠️ السعر الرمزي ($symbolicPrice ج.م) لا يمكن أن يكون أكبر من السعر الأصلي ($originalPrice ج.م)',
        error: true,
      );
      return;
    }

    final now = DateTime.now();
    if (_isExpiringSoon &&
        (_productExpiryAt == null || !_productExpiryAt!.isAfter(now))) {
      _showMessage('تاريخ صلاحية المنتج مطلوب ويجب أن يكون في المستقبل', error: true);
      return;
    }
    if (productWeight != null && productWeight <= 0) {
      _showMessage('الوزن يجب أن يكون أكبر من صفر', error: true);
      return;
    }
    if (_normalizedInstitutionType == 'butcher' &&
        (_meatCutController.text.trim().isEmpty || productWeight == null)) {
      _showMessage('اكتب نوع قطعة اللحم والوزن', error: true);
      return;
    }
    final pickupStart = _isBookable && _usePickupWindow ? _pickupStart : null;
    final pickupEnd = !_isBookable
        ? null
        : (_usePickupWindow ? _pickupEnd : _pickupDeadline);
    if (_isBookable && _usePickupWindow &&
        (pickupStart == null || pickupEnd == null)) {
      _showMessage('حدد بداية ونهاية فترة الاستلام', error: true);
      return;
    }
    if (_isBookable && !_usePickupWindow && pickupEnd == null) {
      _showMessage('حدد الموعد النهائي للاستلام', error: true);
      return;
    }
    if (_isBookable && pickupStart != null && pickupEnd != null &&
        !pickupEnd.isAfter(pickupStart)) {
      _showMessage('نهاية فترة الاستلام يجب أن تكون بعد بدايتها', error: true);
      return;
    }

    setState(() => _saving = true);
    try {
      final imageUrls = <String>[];
      for (final bytes in _images) {
        imageUrls.add(await _repository.uploadInstitutionImage(
          bytes: bytes,
          fileExtension: 'jpg',
        ));
      }

      final location = _pickupLocationController.text.trim();

      // مدة نشر العرض تبقى منفصلة عن تاريخ صلاحية المنتج.
      final expiresAtToSend = now.add(_maxOfferLifetime).toUtc();

      await _repository.createOffer(
        institutionId: widget.institutionId,
        title: _titleController.text,
        description: _descriptionController.text,
        category: _category,
        quantity: quantity,
        symbolicPrice: symbolicPrice,
        originalPrice: originalPrice,
        images: imageUrls,
        pickupLocation: location.isNotEmpty ? location : null,
        expiresAt: expiresAtToSend,
        foodType: _getCategoryLabel(),
        isHalal: _isHalal,
        isVegetarian: _isVegetarian,
        foodCondition: _condition,
        requiresRefrigeration: _storageCondition != 'no_cooling',
        storageCondition: _storageCondition,
        productSubcategory: _productSubcategory,
        meatCut: _meatCutController.text.trim(),
        productWeight: productWeight,
        productPreparedAt: _productPreparedAt,
        productExpiryAt: _isExpiringSoon ? _productExpiryAt : null,
        minBookingQuantity: minBookingQuantityToSend,
        maxBookingQuantity: maxBookingQuantity,
        isBookable: _isBookable,
        pickupStart: pickupStart,
        pickupEnd: pickupEnd,
        pickupNotes: _pickupNotesController.text.trim(),
        contactPhone: _contactPhoneController.text.trim(),
      );

      if (!mounted) return;
      _showMessage('✅ تم نشر العرض بنجاح');
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      _showMessage(_friendlyError(error), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _friendlyError(Object error) {
    final text = error.toString().toLowerCase();
    if (text.contains('permission') || text.contains('row-level security')) {
      return 'ليس لديك صلاحية نشر العرض من هذا الحساب';
    }
    if (text.contains('network') || text.contains('socket')) {
      return 'تعذر الاتصال بالإنترنت. حاول مرة أخرى';
    }
    if (text.contains('column') || text.contains('does not exist')) {
      return 'بعض الحقول غير موجودة في قاعدة البيانات. تواصل مع الدعم الفني.';
    }
    if (text.contains('null value in column')) {
      return 'بعض الحقول المطلوبة فارغة. تأكد من ملء جميع البيانات.';
    }
    if (text.contains('symbolic price cannot exceed original price')) {
      return '⚠️ السعر الرمزي لا يمكن أن يكون أكبر من السعر الأصلي';
    }
    if (text.contains('expires_at') || text.contains('صلاحية')) {
      return '⏰ صلاحية العرض لا تتجاوز المدة المسموح بها من الآن';
    }
    if (text.contains('institution not found') ||
        text.contains('المؤسسة غير موجودة')) {
      return '🏢 المؤسسة غير موجودة أو غير نشطة';
    }
    return 'تعذر نشر العرض الآن: ${error.toString().replaceFirst('Exception: ', '')}';
  }

  void _showMessage(String message, {bool error = false}) {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message, textAlign: TextAlign.right),
          backgroundColor: error ? const Color(0xFFD64545) : _primary,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final nature = _getProductNature();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _background,
        appBar: AppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          elevation: 0,
          centerTitle: false,
          leading: IconButton(
            tooltip: 'رجوع',
            onPressed: _saving ? null : () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back_ios_rounded, color: _primary),
          ),
          title: const Text(
            'إضافة عرض جديد',
            style: TextStyle(
              color: _primaryDark,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(
              height: 1,
              color: const Color(0xFFE2EEE8),
            ),
          ),
        ),
        body: SafeArea(
          bottom: false,
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 34),
              children: [
                _buildHeader(),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: _surface,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(6),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_isHomeRestaurant) ...[
                        _buildHomeRestaurantKindSection(),
                        const SizedBox(height: 20),
                        const Divider(color: Color(0xFFE2EEE8)),
                        const SizedBox(height: 24),
                      ],
                      _buildPublicationModeSection(),
                      const SizedBox(height: 20),
                      const Divider(color: Color(0xFFE2EEE8)),
                      const SizedBox(height: 24),
                      _buildImageSection(),
                      const SizedBox(height: 24),
                      const Divider(color: Color(0xFFE2EEE8)),
                      const SizedBox(height: 24),

                      // ✅ قسم نوع المنتج + تاريخ الانتهاء
                      _buildExpirySection(nature),
                      const SizedBox(height: 24),
                      const Divider(color: Color(0xFFE2EEE8)),
                      const SizedBox(height: 24),

                      _buildBasicInfoSection(),
                      const SizedBox(height: 24),
                      const Divider(color: Color(0xFFE2EEE8)),
                      const SizedBox(height: 24),

                      if (_productSubcategories.isEmpty) ...[
                        _buildCategorySection(),
                        const SizedBox(height: 20),
                      ],
                      _buildProductSubcategorySection(),
                      if (_productSubcategories.isNotEmpty)
                        const SizedBox(height: 20),
                      const Divider(color: Color(0xFFE2EEE8)),
                      const SizedBox(height: 24),

                      _buildConditionSection(),
                      const SizedBox(height: 20),
                      _buildStorageSection(),
                      if (_isBookable) ...[
                        const SizedBox(height: 20),
                        _buildQuantityLimitsSection(),
                        const SizedBox(height: 20),
                        const Divider(color: Color(0xFFE2EEE8)),
                        const SizedBox(height: 24),
                      ],

                      _buildPickupSection(),
                      const SizedBox(height: 24),

                      _buildSubmitButton(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // ✅ قسم نوع المنتج + تاريخ الانتهاء
  // ═══════════════════════════════════════════════════════════
  Widget _buildExpirySection(Map<String, dynamic> nature) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── العنوان
        Row(
          children: [
            const Icon(Icons.event_note_rounded, color: _primary, size: 20),
            const SizedBox(width: 8),
            const Text(
              'نوع المنتج',
              style: TextStyle(
                color: _primaryDark,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            const Spacer(),
            // ── عرض طبيعة المنتج لو "قريب ينتهي"
            if (_isExpiringSoon)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (nature['color'] as Color).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: (nature['color'] as Color).withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      nature['icon'] as IconData,
                      color: nature['color'] as Color,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      nature['label'] as String,
                      style: TextStyle(
                        color: nature['color'] as Color,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),

        // ═══════════════════════════════════════════════════════
        // ✅ أزرار الاختيار (منتج جديد عادي / قريب ينتهي)
        // ═══════════════════════════════════════════════════════
        Row(
          children: [
            Expanded(
              child: _buildTypeCard(
                title: 'منتج جديد / عادي',
                subtitle: 'مفيش تاريخ انتهاء',
                icon: Icons.inventory_2_rounded,
                selected: !_isExpiringSoon,
                color: _primary,
                onTap: () {
                  if (_saving) return;
                  setState(() {
                    _isExpiringSoon = false;
                    _productExpiryAt = null;
                  });
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildTypeCard(
                title: 'قريب ينتهي',
                subtitle: 'حدد تاريخ الانتهاء',
                icon: Icons.timer_outlined,
                selected: _isExpiringSoon,
                color: _accent,
                onTap: () {
                  if (_saving) return;
                  setState(() {
                    _isExpiringSoon = true;
                    _productExpiryAt ??= DateTime.now().add(const Duration(days: 3));
                  });
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // ═══════════════════════════════════════════════════════
        // ✅ لو "قريب ينتهي" → نظهر حقل التاريخ + وصف الطبيعة
        // ═══════════════════════════════════════════════════════
        if (_isExpiringSoon) ...[
          _buildExpiryField(),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: (nature['color'] as Color).withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: (nature['color'] as Color).withValues(alpha: 0.1),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  nature['icon'] as IconData,
                  color: nature['color'] as Color,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    nature['description'] as String,
                    style: TextStyle(
                      color: nature['color'] as Color,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if ((nature['days'] as int) <= 3 && (nature['days'] as int) >= 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _accent.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.timer_outlined,
                      color: _accent,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '⚠️ صلاحية المنتج تنتهي خلال ${nature['days']} أيام',
                        style: const TextStyle(
                          color: _accent,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if ((nature['days'] as int) < 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _error.withValues(alpha: 0.2)),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: _error,
                      size: 16,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '⚠️ هذا التاريخ منتهي، يرجى اختيار تاريخ مستقبلي',
                        style: TextStyle(
                          color: _error,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ] else ...[
          // ═══════════════════════════════════════════════════════
          // ✅ لو "منتج جديد عادي" → نظهر رسالة توضيحية
          // ═══════════════════════════════════════════════════════
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _primary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _primary.withValues(alpha: 0.15)),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_outline_rounded,
                    color: _primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'منتج جديد / عادي',
                        style: TextStyle(
                          color: _primaryDark,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'هذا المنتج مش محتاج تاريخ انتهاء، العرض هيفضل متاح لحد ما توقفه بنفسك.',
                        style: TextStyle(
                          color: _muted,
                          fontSize: 11.5,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  // ✅ كارت اختيار نوع المنتج
  // ═══════════════════════════════════════════════════════════
  Widget _buildTypeCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool selected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.08) : _surfaceVariant,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? color : const Color(0xFFDCEBE3),
            width: selected ? 1.8 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color:
                        selected ? color.withValues(alpha: 0.15) : Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: selected ? color : _muted,
                    size: 20,
                  ),
                ),
                const Spacer(),
                if (selected)
                  Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 15,
                    ),
                  )
                else
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFC4D5CC),
                        width: 1.5,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(
                color: selected ? color : _primaryDark,
                fontSize: 13.5,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                color: selected ? color.withValues(alpha: 0.8) : _muted,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // ✅ الهيدر
  // ============================================================
  Widget _buildHeader() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'شارك فائضك',
          style: TextStyle(
            color: _primaryDark,
            fontSize: 26,
            fontWeight: FontWeight.w900,
          ),
        ),
        SizedBox(height: 4),
        Text(
          'أنشئ عرضاً جديداً ليصل إلى من يحتاجه',
          style: TextStyle(
            color: _muted,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // ✅ قسم الصور
  // ============================================================
  Widget _buildImageSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.image_outlined, color: _primary, size: 20),
            const SizedBox(width: 8),
            const Text(
              'صور المنتج',
              style: TextStyle(
                color: _primaryDark,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            const Spacer(),
            Text(
              '${_images.length}/6',
              style: const TextStyle(
                color: _muted,
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        InkWell(
          onTap: _saving ? null : _pickImages,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: double.infinity,
            height: 140,
            decoration: BoxDecoration(
              color: _surfaceVariant,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFFCBE4D5),
                width: 1.5,
                style: BorderStyle.solid,
              ),
            ),
            child: _images.isEmpty
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_photo_alternate_outlined,
                        size: 42,
                        color: _primary.withAlpha(100),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'اضغط لإضافة صور',
                        style: TextStyle(
                          color: _primary.withAlpha(80),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'jpg, png, webp',
                        style: TextStyle(
                          color: _primary.withAlpha(50),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    scrollDirection: Axis.horizontal,
                    itemCount: _images.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, index) => Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.memory(
                            _images[index],
                            width: 120,
                            height: 140,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: 6,
                          right: 6,
                          child: Material(
                            color: Colors.black54,
                            shape: const CircleBorder(),
                            child: InkWell(
                              onTap: () {
                                if (_saving) return;
                                setState(() => _images.removeAt(index));
                              },
                              customBorder: const CircleBorder(),
                              child: const Padding(
                                padding: EdgeInsets.all(4),
                                child: Icon(
                                  Icons.close,
                                  size: 14,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // ✅ معلومات العرض
  // ============================================================
  Widget _buildBasicInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.info_outline_rounded, color: _primary, size: 20),
            SizedBox(width: 8),
            Text(
              'معلومات العرض',
              style: TextStyle(
                color: _primaryDark,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _buildTextField(
          controller: _titleController,
          label: 'اسم العرض',
          hint: 'مثال: سلة معجنات متنوعة',
          icon: Icons.inventory_2_outlined,
        ),
        const SizedBox(height: 12),
        _buildTextField(
          controller: _descriptionController,
          label: 'وصف العرض',
          hint: 'اكتب محتويات العرض وحالته...',
          icon: Icons.description_outlined,
          maxLines: 3,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildTextField(
                controller: _priceController,
                label: 'السعر الرمزي',
                hint: '0.00',
                icon: Icons.payments_outlined,
                numeric: true,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildTextField(
                controller: _originalPriceController,
                label: 'السعر الأصلي',
                hint: 'اختياري',
                icon: Icons.sell_outlined,
                numeric: true,
                requiredField: false,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildTextField(
                controller: _quantityController,
                label: 'الكمية',
                hint: '1',
                icon: Icons.layers_outlined,
                numeric: true,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildTextField(
                controller: _contactPhoneController,
                label: 'رقم التواصل (اختياري)',
                hint: 'رقم للتواصل مع المؤسسة',
                icon: Icons.phone_outlined,
                requiredField: false,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHomeRestaurantKindSection() {
    final choices = _categories
        .where(
          (item) => const {'home_sweets', 'home_food'}.contains(item['id']),
        )
        .toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'نوع الحاجة',
          style: TextStyle(
            color: _primaryDark,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'اختار حلويات بيتي أو أكل بيتي، وبعدها كمّل تفاصيل العرض.',
          style: TextStyle(color: _muted, fontSize: 13),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: choices.map((item) {
            final selected = _category == item['id'];
            return ChoiceChip(
              selected: selected,
              label: Text(item['label'] as String),
              onSelected: _saving
                  ? null
                  : (_) => setState(() => _category = item['id'] as String),
              selectedColor: _primary,
              labelStyle: TextStyle(
                color: selected ? Colors.white : _primaryDark,
                fontWeight: FontWeight.w800,
              ),
            );
          }).toList(growable: false),
        ),
      ],
    );
  }

  // ============================================================
  // ✅ التصنيفات
  // ============================================================
  Widget _buildCategorySection() {
    if (_isHomeRestaurant) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.category_outlined, color: _primary, size: 20),
            SizedBox(width: 8),
            Text(
              'تصنيف العرض',
              style: TextStyle(
                color: _primaryDark,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _categories.map((category) {
            final isSelected = _category == category['id'];
            return FilterChip(
              selected: isSelected,
              onSelected: (_) {
                if (_saving) return;
                setState(() => _category = category['id']);
              },
              label: Text(
                category['label'],
                style: TextStyle(
                  color: isSelected ? Colors.white : _primaryDark,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  fontSize: 12,
                ),
              ),
              backgroundColor: _surfaceVariant,
              selectedColor: _primary,
              checkmarkColor: Colors.white,
              side: BorderSide(
                color: isSelected ? _primary : const Color(0xFFDCEBE3),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            _buildToggleChip(
              label: 'حلال',
              value: _isHalal,
              onChanged: (v) => setState(() => _isHalal = v),
            ),
            _buildToggleChip(
              label: 'نباتي',
              value: _isVegetarian,
              onChanged: (v) => setState(() => _isVegetarian = v),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProductSubcategorySection() {
    final options = _productSubcategories;
    if (options.isEmpty) return const SizedBox.shrink();
    final isButcher =
        _normalizedInstitutionType == 'butcher' || _normalizedInstitutionType == 'meat_shop';
    final isBakery = _normalizedInstitutionType == 'bakery';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'نوع المنتج',
          style: TextStyle(color: _primaryDark, fontSize: 16, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((option) {
            final selected = _productSubcategory == option['id'];
            return ChoiceChip(
              label: Text(option['label']!),
              selected: selected,
              onSelected: _saving
                  ? null
                  : (_) => setState(() {
                        _productSubcategory = option['id'];
                        _category = option['category']!;
                      }),
              selectedColor: _primary,
              labelStyle: TextStyle(
                color: selected ? Colors.white : _primaryDark,
                fontWeight: FontWeight.w700,
              ),
            );
          }).toList(),
        ),
        if (isButcher) ...[
          const SizedBox(height: 12),
          _buildTextField(
            controller: _meatCutController,
            label: 'نوع القطعة',
            hint: 'مثال: مفروم، ستيك، صدور',
            icon: Icons.restaurant_menu_rounded,
          ),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _productWeightController,
            label: 'الوزن بالكيلو (مطلوب)',
            hint: 'مثال: 1.5',
            icon: Icons.straighten_rounded,
            numeric: true,
            requiredField: false,
          ),
        ],
        if (isBakery) ...[
          const SizedBox(height: 12),
          _buildDateField(
            label: 'تاريخ الإنتاج (اختياري)',
            value: _productPreparedAt,
            onTap: _choosePreparedDate,
            icon: Icons.event_outlined,
          ),
        ],
      ],
    );
  }

  Widget _buildStorageSection() {
    const options = [
      ('needs_refrigeration', 'يحتاج تبريد', Icons.ac_unit_rounded),
      ('needs_freezing', 'يحتاج تجميد', Icons.kitchen_rounded),
      ('no_cooling', 'لا يحتاج تبريد', Icons.wb_sunny_outlined),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'حالة التخزين',
          style: TextStyle(color: _primaryDark, fontSize: 16, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((option) {
            final selected = _storageCondition == option.$1;
            return ChoiceChip(
              avatar: Icon(option.$3, size: 17),
              label: Text(option.$2),
              selected: selected,
              onSelected: _saving ? null : (_) => setState(() => _storageCondition = option.$1),
              selectedColor: _primary,
              labelStyle: TextStyle(
                color: selected ? Colors.white : _primaryDark,
                fontWeight: FontWeight.w700,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildPublicationModeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.tune_rounded, color: _primary, size: 20),
            SizedBox(width: 8),
            Text(
              'طريقة نشر العرض',
              style: TextStyle(
                color: _primaryDark,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildPublicationModeOption(
          isBookable: false,
          title: 'عرض عادي',
          subtitle: 'يشاهده المستخدمون فقط، بدون حجز أو إرسال طلب.',
          icon: Icons.visibility_outlined,
        ),
        const SizedBox(height: 10),
        _buildPublicationModeOption(
          isBookable: true,
          title: 'عرض مع إمكانية الحجز',
          subtitle: 'يستمر بنفس خطوات الحجز المتاحة حاليًا للمستخدمين.',
          icon: Icons.shopping_bag_outlined,
        ),
      ],
    );
  }

  Widget _buildPublicationModeOption({
    required bool isBookable,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final selected = _isBookable == isBookable;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _saving
            ? null
            : () => setState(() => _isBookable = isBookable),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected ? _primary.withValues(alpha: 0.07) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? _primary : const Color(0xFFDCEBE3),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: selected ? _primary : _muted, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: _primaryDark,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: _muted,
                        fontSize: 11.5,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: selected ? _primary : _muted,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuantityLimitsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'حدود الحجز',
          style: TextStyle(color: _primaryDark, fontSize: 16, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        Column(
          children: [
            _buildTextField(
              controller: _minBookingQuantityController,
              label: 'الحد الأدنى للحجز',
              hint: '1',
              icon: Icons.remove_shopping_cart_outlined,
              numeric: true,
            ),
            const SizedBox(height: 10),
            _buildTextField(
              controller: _maxBookingQuantityController,
              label: 'الحد الأقصى للحجز (اختياري)',
              hint: 'حسب الكمية المتاحة',
              icon: Icons.add_shopping_cart_outlined,
              numeric: true,
              requiredField: false,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildToggleChip({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return FilterChip(
      selected: value,
      onSelected: onChanged,
      label: Text(
        label,
        style: TextStyle(
          color: value ? Colors.white : _primaryDark,
          fontWeight: value ? FontWeight.w800 : FontWeight.w600,
          fontSize: 12,
        ),
      ),
      backgroundColor: _surfaceVariant,
      selectedColor: _primary,
      checkmarkColor: Colors.white,
      side: BorderSide(
        color: value ? _primary : const Color(0xFFDCEBE3),
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    );
  }

  // ============================================================
  // ✅ حالة المنتج
  // ============================================================
  Widget _buildConditionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.verified_outlined, color: _primary, size: 20),
            SizedBox(width: 8),
            Text(
              'حالة المنتج',
              style: TextStyle(
                color: _primaryDark,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _conditions.map((condition) {
            final isSelected = _condition == condition['id'];
            return FilterChip(
              selected: isSelected,
              onSelected: (_) {
                if (_saving) return;
                setState(() => _condition = condition['id']);
              },
              label: Text(
                condition['label'],
                style: TextStyle(
                  color: isSelected ? Colors.white : _primaryDark,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  fontSize: 12,
                ),
              ),
              backgroundColor: _surfaceVariant,
              selectedColor: condition['color'],
              checkmarkColor: Colors.white,
              side: BorderSide(
                color:
                    isSelected ? condition['color'] : const Color(0xFFDCEBE3),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ============================================================
  // ✅ معلومات الاستلام
  // ============================================================
  Widget _buildPickupSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.local_shipping_outlined, color: _primary, size: 20),
            SizedBox(width: 8),
            Text(
              'معلومات الاستلام',
              style: TextStyle(
                color: _primaryDark,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _primary.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _primary.withValues(alpha: 0.18)),
          ),
          child: const Row(
            children: [
              Icon(Icons.storefront_outlined, color: _primary),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'طريقة الاستلام: استلام من المحل',
                  style: TextStyle(color: _primaryDark, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        if (_isBookable) ...[
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            activeColor: _primary,
            value: _usePickupWindow,
            onChanged: _saving
                ? null
                : (value) => setState(() => _usePickupWindow = value),
            title: Text(_usePickupWindow
                ? 'تحديد فترة الاستلام من وإلى'
                : 'تحديد موعد نهائي للاستلام'),
            subtitle: const Text('يظهر الموعد للعميل قبل إرسال طلب الحجز'),
          ),
          if (_usePickupWindow) ...[
            _buildDateField(
              label: 'بداية الاستلام',
              value: _pickupStart,
              onTap: () async {
                final value = await _choosePickupDateTime(initial: _pickupStart);
                if (value != null) setState(() => _pickupStart = value);
              },
              icon: Icons.play_circle_outline_rounded,
            ),
            const SizedBox(height: 10),
            _buildDateField(
              label: 'نهاية الاستلام',
              value: _pickupEnd,
              onTap: () async {
                final value = await _choosePickupDateTime(
                  initial: _pickupEnd ??
                      _pickupStart?.add(const Duration(hours: 1)),
                );
                if (value != null) setState(() => _pickupEnd = value);
              },
              icon: Icons.stop_circle_outlined,
            ),
          ] else
            _buildDateField(
              label: 'آخر موعد للاستلام',
              value: _pickupDeadline,
              onTap: () async {
                final value = await _choosePickupDateTime(
                  initial: _pickupDeadline,
                );
                if (value != null) setState(() => _pickupDeadline = value);
              },
              icon: Icons.event_available_outlined,
            ),
        ],
        const SizedBox(height: 12),
        _buildTextField(
          controller: _pickupLocationController,
          label: 'موقع الاستلام',
          hint: 'عنوان الفرع أو الموقع',
          icon: Icons.location_on_outlined,
          requiredField: false,
        ),
        const SizedBox(height: 12),
        _buildTextField(
          controller: _contactPhoneController,
          label: 'رقم التواصل (اختياري)',
          hint: 'رقم المحل أو رقم مخصص للطلبات',
          icon: Icons.phone_outlined,
          numeric: true,
          requiredField: false,
        ),
        const SizedBox(height: 12),
        _buildTextField(
          controller: _pickupNotesController,
          label: 'ملاحظات الاستلام',
          hint: 'تعليمات إضافية للمستلم...',
          icon: Icons.info_outline,
          maxLines: 2,
          requiredField: false,
        ),
      ],
    );
  }

  Widget _buildDateField({
    required String label,
    required DateTime? value,
    required VoidCallback onTap,
    required IconData icon,
  }) {
    final text = value == null
        ? 'اختر التاريخ والوقت'
        : '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year} · ${TimeOfDay.fromDateTime(value).format(context)}';
    return InkWell(
      onTap: _saving ? null : onTap,
      borderRadius: BorderRadius.circular(14),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: _muted),
          filled: true,
          fillColor: _surfaceVariant,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: value == null ? _muted : _primaryDark,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // ✅ زر النشر
  // ============================================================
  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: FilledButton.icon(
        onPressed: _saving ? null : _save,
        style: FilledButton.styleFrom(
          backgroundColor: _primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: _primary.withAlpha(80),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 2,
        ),
        icon: _saving
            ? const SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.send_rounded),
        label: Text(
          _saving ? 'جاري النشر...' : 'نشر العرض',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // ✅ حقل النص
  // ============================================================
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    bool numeric = false,
    bool requiredField = true,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: numeric
          ? const TextInputType.numberWithOptions(decimal: true)
          : (maxLines > 1 ? TextInputType.multiline : TextInputType.text),
      textInputAction:
          maxLines > 1 ? TextInputAction.newline : TextInputAction.next,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: _muted),
        filled: true,
        fillColor: _surfaceVariant,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        labelStyle: const TextStyle(color: _muted),
        hintStyle: TextStyle(color: _muted.withAlpha(150)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFCBE4D5)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFCBE4D5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFD64545)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFD64545), width: 1.6),
        ),
      ),
      validator: (value) {
        final text = value?.trim() ?? '';
        if (requiredField && text.isEmpty) return 'هذا الحقل مطلوب';
        if (numeric &&
            text.isNotEmpty &&
            num.tryParse(_normalizeDigits(text).replaceAll(',', '.')) == null) {
          return 'اكتب رقمًا صحيحًا';
        }
        return null;
      },
    );
  }

  // ============================================================
  // ✅ حقل تاريخ الانتهاء (يظهر بس لما "قريب ينتهي")
  // ============================================================
  Widget _buildExpiryField() {
    return InkWell(
      onTap: _saving ? null : _chooseExpiryDate,
      borderRadius: BorderRadius.circular(14),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'تاريخ انتهاء صلاحية المنتج (مطلوب)',
          prefixIcon: const Icon(Icons.event_outlined, color: _muted),
          suffixIcon: const Icon(
            Icons.arrow_drop_down_rounded,
            color: _muted,
          ),
          filled: true,
          fillColor: _surfaceVariant,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          labelStyle: const TextStyle(color: _muted),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFCBE4D5)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFCBE4D5)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _primary, width: 1.6),
          ),
        ),
        child: Text(
          _productExpiryAt == null
              ? 'اضغط لاختيار التاريخ'
              : '${_productExpiryAt!.day.toString().padLeft(2, '0')}/${_productExpiryAt!.month.toString().padLeft(2, '0')}/${_productExpiryAt!.year}',
          style: const TextStyle(
            color: _primaryDark,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

}
