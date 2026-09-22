// lib/features/institutions/presentation/pages/institution_add_offer_page.dart

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/repositories/institutions_repository.dart';

class InstitutionAddOfferPage extends StatefulWidget {
  final String institutionId;

  const InstitutionAddOfferPage({super.key, required this.institutionId});

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
  final _priceController = TextEditingController();
  final _originalPriceController = TextEditingController();
  final _pickupLocationController = TextEditingController();
  final _pickupNotesController = TextEditingController();
  final _contactPhoneController = TextEditingController();

  final _repository = InstitutionsRepository();
  final _picker = ImagePicker();
  final List<Uint8List> _images = [];

  // ✅ حقول إضافية
  String _category = 'food';
  String _condition = 'good';
  bool _isHalal = true;
  bool _isVegetarian = false;
  bool _requiresRefrigeration = false;

  // ✅ تاريخ الانتهاء هو اللي يحدد كل حاجة
  DateTime _expiresAt = DateTime.now().add(const Duration(days: 7));
  bool _saving = false;

  // ✅ قائمة التصنيفات
  final List<Map<String, dynamic>> _categories = [
    {'id': 'food', 'label': '🍽️ وجبات', 'icon': Icons.restaurant_rounded},
    {
      'id': 'bakery',
      'label': '🥖 مخبوزات',
      'icon': Icons.bakery_dining_rounded
    },
    {'id': 'dessert', 'label': '🍰 حلويات', 'icon': Icons.cake_rounded},
    {'id': 'fruit', 'label': '🍎 فواكه', 'icon': Icons.apple_rounded},
    {'id': 'drink', 'label': '🥤 مشروبات', 'icon': Icons.local_drink_rounded},
    {'id': 'meat', 'label': '🥩 لحوم', 'icon': Icons.restaurant_menu_rounded},
    {'id': 'other', 'label': '📦 أخرى', 'icon': Icons.category_rounded},
  ];

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
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    _originalPriceController.dispose();
    _pickupLocationController.dispose();
    _pickupNotesController.dispose();
    _contactPhoneController.dispose();
    super.dispose();
  }

  // ✅ حساب طبيعة المنتج بناءً على تاريخ الانتهاء
  Map<String, dynamic> _getProductNature() {
    final now = DateTime.now();
    final daysLeft = _expiresAt.difference(now).inDays;

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
    final selected = await showDatePicker(
      context: context,
      initialDate: _expiresAt,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'اختر تاريخ انتهاء العرض',
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
    if (!mounted || selected == null) return;
    setState(() {
      _expiresAt = DateTime(
        selected.year,
        selected.month,
        selected.day,
        23,
        59,
        59,
      );
    });
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
    final category = _categories.firstWhere(
      (c) => c['id'] == _category,
      orElse: () => _categories.last,
    );
    return category['label'] as String;
  }

  Future<void> _save() async {
    if (_saving) return;
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final quantity = int.tryParse(_normalizeDigits(_quantityController.text));
    final symbolicPrice = double.tryParse(
      _normalizeDigits(_priceController.text).replaceAll(',', '.'),
    );
    final originalText = _originalPriceController.text.trim();
    final originalPrice = originalText.isEmpty
        ? null
        : double.tryParse(_normalizeDigits(originalText).replaceAll(',', '.'));

    if (quantity == null || quantity <= 0) {
      _showMessage('اكتب كمية صحيحة أكبر من صفر', error: true);
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

    // ✅ التحقق من أن السعر الرمزي لا يتجاوز السعر الأصلي
    if (originalPrice != null && symbolicPrice > originalPrice) {
      _showMessage(
        '⚠️ السعر الرمزي ($symbolicPrice ج.م) لا يمكن أن يكون أكبر من السعر الأصلي ($originalPrice ج.م)',
        error: true,
      );
      return;
    }

    // ✅ التأكد من أن التاريخ مش منتهي
    if (_expiresAt.isBefore(DateTime.now())) {
      _showMessage('تاريخ الانتهاء لا يمكن أن يكون في الماضي', error: true);
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
        expiresAt: _expiresAt.toUtc(),
        foodType: _getCategoryLabel(),
        isHalal: _isHalal,
        isVegetarian: _isVegetarian,
        foodCondition: _condition,
        requiresRefrigeration: _requiresRefrigeration,
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
      return '⏰ صلاحية العرض لا تتجاوز 12 ساعة من الآن';
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
                      _buildImageSection(),
                      const SizedBox(height: 24),
                      const Divider(color: Color(0xFFE2EEE8)),
                      const SizedBox(height: 24),

                      // ✅ قسم تاريخ الانتهاء وطبيعة المنتج
                      _buildExpirySection(nature),
                      const SizedBox(height: 24),
                      const Divider(color: Color(0xFFE2EEE8)),
                      const SizedBox(height: 24),

                      _buildBasicInfoSection(),
                      const SizedBox(height: 24),
                      const Divider(color: Color(0xFFE2EEE8)),
                      const SizedBox(height: 24),

                      _buildCategorySection(),
                      const SizedBox(height: 20),
                      const Divider(color: Color(0xFFE2EEE8)),
                      const SizedBox(height: 24),

                      _buildConditionSection(),
                      const SizedBox(height: 20),
                      const Divider(color: Color(0xFFE2EEE8)),
                      const SizedBox(height: 24),

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

  // ============================================================
  // ✅ قسم تاريخ الانتهاء وطبيعة المنتج
  // ============================================================
  Widget _buildExpirySection(Map<String, dynamic> nature) {
    final daysLeft = nature['days'] as int;
    final color = nature['color'] as Color;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.event_note_rounded, color: _primary, size: 20),
            const SizedBox(width: 8),
            const Text(
              'تاريخ الانتهاء',
              style: TextStyle(
                color: _primaryDark,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            const Spacer(),
            // ✅ عرض طبيعة المنتج حسب التاريخ
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withValues(alpha: 0.2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(nature['icon'], color: color, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    nature['label'],
                    style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _buildExpiryField(),
        const SizedBox(height: 8),
        // ✅ وصف طبيعة المنتج
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.1)),
          ),
          child: Row(
            children: [
              Icon(nature['icon'], color: color, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  nature['description'],
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (daysLeft <= 3 && daysLeft >= 0)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                      '⚠️ هذا العرض سينتهي خلال $daysLeft أيام - مناسب للاستخدام الفوري',
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
        if (daysLeft < 0)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
      ],
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

  // ============================================================
  // ✅ التصنيفات
  // ============================================================
  Widget _buildCategorySection() {
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
            _buildToggleChip(
              label: 'يحتاج تبريد',
              value: _requiresRefrigeration,
              onChanged: (v) => setState(() => _requiresRefrigeration = v),
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
        _buildTextField(
          controller: _pickupLocationController,
          label: 'موقع الاستلام',
          hint: 'عنوان الفرع أو الموقع',
          icon: Icons.location_on_outlined,
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
  // ✅ تاريخ الانتهاء
  // ============================================================
  Widget _buildExpiryField() {
    return InkWell(
      onTap: _saving ? null : _chooseExpiryDate,
      borderRadius: BorderRadius.circular(14),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'تاريخ الانتهاء',
          prefixIcon: const Icon(Icons.event_outlined, color: _muted),
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
          '${_expiresAt.day.toString().padLeft(2, '0')}/${_expiresAt.month.toString().padLeft(2, '0')}/${_expiresAt.year}',
          style: const TextStyle(
            color: _primaryDark,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
