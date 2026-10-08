// lib/features/institutions/presentation/pages/institution_add_offer_page.dart

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/repositories/institutions_repository.dart';

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

  // ═══════════════════════════════════════════════════════════
  // ✅ جديد: اختيار نوع المنتج
  // true  → قريب ينتهي (له تاريخ)
  // false → منتج جديد/عادي (بدون تاريخ)
  // ═══════════════════════════════════════════════════════════
  bool _isExpiringSoon = false;

  /// الصلاحية القصوى التي يسمح بها مسار إنشاء عروض المؤسسات.
  static const Duration _maxOfferLifetime = Duration(hours: 12);

  /// التاريخ الافتراضي لما يختار "قريب ينتهي".
  DateTime _expiresAt = DateTime.now().add(_maxOfferLifetime);

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
    {
      'id': 'home_sweets',
      'label': '🍰 حلويات بيتي',
      'icon': Icons.cake_rounded
    },
    {'id': 'home_food', 'label': '🍲 أكل بيتي', 'icon': Icons.restaurant_rounded},
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
  void initState() {
    super.initState();
    if (_isHomeRestaurant) _category = '';
  }

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
    final now = DateTime.now();
    final selected = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
        _expiresAt.isAfter(now)
            ? _expiresAt
            : now.add(const Duration(hours: 1)),
      ),
      helpText: 'اختر وقت انتهاء العرض اليوم',
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
    var candidate = DateTime(
      now.year,
      now.month,
      now.day,
      selected.hour,
      selected.minute,
    );
    if (candidate.isBefore(now)) {
      candidate = candidate.add(const Duration(days: 1));
    }
    if (candidate.isAfter(now.add(_maxOfferLifetime))) {
      _showMessage(
        'اختر وقتًا خلال 12 ساعة من الآن',
        error: true,
      );
      return;
    }
    setState(() {
      _expiresAt = candidate;
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

    if (_isHomeRestaurant &&
        !const {'home_sweets', 'home_food'}.contains(_category)) {
      _showMessage('اختر نوع الحاجة: حلويات بيتي أو أكل بيتي', error: true);
      return;
    }
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

    if (originalPrice != null && symbolicPrice > originalPrice) {
      _showMessage(
        '⚠️ السعر الرمزي ($symbolicPrice ج.م) لا يمكن أن يكون أكبر من السعر الأصلي ($originalPrice ج.م)',
        error: true,
      );
      return;
    }

    // قاعدة البيانات تسمح بحد أقصى 12 ساعة من وقت النشر.
    final now = DateTime.now();
    final maxExpiresAt = now.add(_maxOfferLifetime);
    if (_isExpiringSoon && _expiresAt.isBefore(now)) {
      _showMessage('تاريخ الانتهاء لا يمكن أن يكون في الماضي', error: true);
      return;
    }
    if (_isExpiringSoon && _expiresAt.isAfter(maxExpiresAt)) {
      _showMessage(
        'لا يمكن أن تتجاوز صلاحية العرض 12 ساعة من وقت النشر',
        error: true,
      );
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

      // ✅ كلا النوعين يلتزمان بالحد الذي يفرضه RPC في قاعدة البيانات.
      final expiresAtToSend = _isExpiringSoon
          ? _expiresAt.toUtc()
          : now.add(_maxOfferLifetime).toUtc();

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
                  setState(() => _isExpiringSoon = false);
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
                  setState(() => _isExpiringSoon = true);
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
                        '⚠️ هذا العرض سينتهي خلال ${nature['days']} أيام - مناسب للاستخدام الفوري',
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
  // ✅ حقل تاريخ الانتهاء (يظهر بس لما "قريب ينتهي")
  // ============================================================
  Widget _buildExpiryField() {
    return InkWell(
      onTap: _saving ? null : _chooseExpiryDate,
      borderRadius: BorderRadius.circular(14),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'تاريخ الانتهاء',
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
