import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:loqma/core/errors/app_error_mapper.dart';
import 'package:loqma/features/charity/data/repositories/charity_donation_repository_separate.dart';
import 'package:loqma/features/community/presentation/pages/community_charities_page.dart';
import 'package:loqma/features/community/presentation/pages/community_charity_option.dart';

class AddCharityDonationPage extends StatefulWidget {
  const AddCharityDonationPage({super.key});

  @override
  State<AddCharityDonationPage> createState() => _AddCharityDonationPageState();
}

class _AddCharityDonationPageState extends State<AddCharityDonationPage> {
  static const _green = Color(0xFF0B7650);
  static const _darkGreen = Color(0xFF123F31);

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  ColorScheme get _colors => Theme.of(context).colorScheme;
  Color get _background => _colors.surface;
  Color get _cardSurface => _colors.surfaceContainerLow;
  Color get _softSurface => _colors.surfaceContainerHighest;
  Color get _textPrimary => _colors.onSurface;
  Color get _textSecondary => _colors.onSurfaceVariant;
  Color get _outline => _colors.outlineVariant;
  Color get _accent => _isDark ? const Color(0xFF48C98A) : _green;
  Color get _safetyBackground =>
      _isDark ? const Color(0xFF302716) : const Color(0xFFFFF7E8);
  Color get _safetyBorder =>
      _isDark ? const Color(0xFF665126) : const Color(0xFFF3D8A5);
  Color get _safetyText =>
      _isDark ? const Color(0xFFFFD77A) : const Color(0xFF684A17);
  Color get _safetyIcon =>
      _isDark ? const Color(0xFFFFC95A) : const Color(0xFF9A5A00);

  static const _categories = <_DonationCategory>[
    _DonationCategory('food', 'طعام ومؤن', Icons.restaurant_rounded),
    _DonationCategory('clothing', 'ملابس وأحذية', Icons.checkroom_rounded),
    _DonationCategory('furniture', 'أثاث ومفروشات', Icons.chair_alt_rounded),
    _DonationCategory(
      'electronics',
      'أجهزة وإلكترونيات',
      Icons.devices_other_rounded,
    ),
    _DonationCategory('books', 'كتب وأدوات مدرسية', Icons.menu_book_rounded),
    _DonationCategory('toys', 'ألعاب وأطفال', Icons.toys_rounded),
    _DonationCategory('household', 'أدوات منزلية', Icons.home_work_rounded),
    _DonationCategory('hygiene', 'نظافة وعناية شخصية', Icons.spa_rounded),
    _DonationCategory(
      'medical',
      'مستلزمات طبية',
      Icons.medical_services_rounded,
    ),
    _DonationCategory('other', 'أخرى', Icons.volunteer_activism_rounded),
  ];

  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _address = TextEditingController();
  final _city = TextEditingController();
  final _phone = TextEditingController();
  final _notes = TextEditingController();
  final _repository = SeparateCharityDonationRepository();
  final _picker = ImagePicker();
  final List<XFile> _images = [];
  final Set<String> _selectedCategories = <String>{};
  final Map<String, TextEditingController> _quantityControllers = {};
  final Map<String, TextEditingController> _detailsControllers = {};
  final Map<String, String> _units = {};
  final Map<String, String> _conditions = {};
  final Map<String, DateTime?> _bestBeforeDates = {};

  CommunityCharityOption? _charity;
  bool _busy = false;
  String? _categoryError;

  List<String> get _orderedSelectedCategories => _categories
      .map((item) => item.id)
      .where(_selectedCategories.contains)
      .toList(growable: false);

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _address.dispose();
    _city.dispose();
    _phone.dispose();
    _notes.dispose();
    for (final controller in _quantityControllers.values) {
      controller.dispose();
    }
    for (final controller in _detailsControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _addItemFields(String category) {
    _quantityControllers.putIfAbsent(
      category,
      () => TextEditingController(text: '1'),
    );
    _detailsControllers.putIfAbsent(category, TextEditingController.new);
    _units.putIfAbsent(category, () => _defaultUnit(category));
    _conditions.putIfAbsent(category, () => _defaultCondition(category));
    _bestBeforeDates.putIfAbsent(category, () => null);
  }

  void _toggleCategory(String category, bool selected) {
    setState(() {
      _categoryError = null;
      if (selected) {
        _selectedCategories.add(category);
        _addItemFields(category);
      } else {
        _selectedCategories.remove(category);
      }
    });
  }

  String _defaultUnit(String category) => switch (category) {
    'food' => 'عبوة',
    'clothing' => 'قطعة',
    'furniture' => 'قطعة',
    'books' => 'كتاب',
    'toys' => 'قطعة',
    'electronics' => 'قطعة',
    'household' => 'قطعة',
    'hygiene' => 'عبوة',
    'medical' => 'عبوة',
    _ => 'وحدة',
  };

  String _defaultCondition(String category) =>
      category == 'food' ? 'sealed' : 'good';

  List<String> _unitsFor(String category) => switch (category) {
    'food' => const ['وجبة', 'عبوة', 'كرتونة', 'كيلو', 'لتر', 'قطعة'],
    'clothing' => const ['قطعة', 'طقم', 'كيس'],
    'books' => const ['كتاب', 'قطعة', 'مجموعة'],
    'hygiene' || 'medical' => const ['عبوة', 'كرتونة', 'قطعة'],
    _ => const ['قطعة', 'طقم', 'كرتونة', 'وحدة'],
  };

  Map<String, String> _conditionsFor(String category) => category == 'food'
      ? const {
          'sealed': 'مغلف ومحفوظ جيدًا',
          'fresh': 'طازج',
          'frozen': 'مجمد ومحفوظ',
          'near_expiry': 'قريب الصلاحية',
        }
      : const {
          'new': 'جديد',
          'very_good': 'جيد جدًا',
          'good': 'جيد',
          'needs_repair': 'يحتاج إصلاحًا',
        };

  Future<void> _chooseCharity() async {
    final selected = await Navigator.push<CommunityCharityOption>(
      context,
      MaterialPageRoute(builder: (_) => const CommunityCharitiesPage()),
    );
    if (selected != null && mounted) setState(() => _charity = selected);
  }

  Future<void> _pickImages() async {
    final remaining = 6 - _images.length;
    if (remaining <= 0) return;
    try {
      final picked = await _picker.pickMultiImage(
        imageQuality: 82,
        maxWidth: 1600,
        maxHeight: 1600,
      );
      if (!mounted || picked.isEmpty) return;
      setState(() => _images.addAll(picked.take(remaining)));
      if (picked.length > remaining) _message('تمت إضافة 6 صور كحد أقصى');
    } catch (error) {
      if (mounted) _message('تعذر فتح معرض الصور: $error');
    }
  }

  Future<void> _takePhoto() async {
    if (_images.length >= 6) return;
    try {
      final photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 82,
        maxWidth: 1600,
        maxHeight: 1600,
      );
      if (!mounted || photo == null) return;
      setState(() => _images.add(photo));
    } catch (error) {
      if (mounted) _message('تعذر فتح الكاميرا: $error');
    }
  }

  Future<void> _chooseFoodExpiry(String category) async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _bestBeforeDates[category] ?? now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 5),
      helpText: 'اختر تاريخ الصلاحية',
      cancelText: 'إلغاء',
      confirmText: 'اختيار',
    );
    if (selected != null && mounted) {
      setState(() => _bestBeforeDates[category] = selected);
    }
  }

  String _formatDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  List<Map<String, dynamic>> _buildItems() => _orderedSelectedCategories
      .map((category) {
        final quantity =
            int.tryParse(_quantityControllers[category]?.text.trim() ?? '') ??
            0;
        final bestBefore = _bestBeforeDates[category];
        return <String, dynamic>{
          'category': category,
          'quantity': quantity,
          'unit': _units[category] ?? _defaultUnit(category),
          'condition': _conditions[category] ?? _defaultCondition(category),
          'details': _detailsControllers[category]?.text.trim() ?? '',
          if (category == 'food' && bestBefore != null)
            'best_before_date': _formatDate(bestBefore),
        };
      })
      .toList(growable: false);

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategories.isEmpty) {
      setState(() => _categoryError = 'اختر نوعًا واحدًا على الأقل');
      _message('اختر صنفًا واحدًا على الأقل للتبرع');
      return;
    }
    if (_charity == null) {
      _message('اختر الجمعية التي سيصل إليها التبرع');
      return;
    }

    final items = _buildItems();
    if (items.any((item) => (item['quantity'] as int) <= 0)) {
      _message('أدخل كمية صحيحة لكل صنف');
      return;
    }
    final categories = items.map((item) => item['category'] as String).toList();

    setState(() => _busy = true);
    try {
      final imagePaths = _images.isEmpty
          ? const <String>[]
          : await _repository.uploadDonationImages(
              _images,
              charityId: _charity!.id,
            );

      await _repository.createDonation(
        charityId: _charity!.id,
        title: _title.text,
        description: _description.text,
        category: categories.first,
        categories: categories,
        items: items,
        quantity: items.first['quantity'] as int,
        condition: items.first['condition'] as String,
        pickupAddress: _address.text,
        pickupCity: _city.text,
        donorPhone: _phone.text,
        donorNotes: _notes.text,
        images: imagePaths,
      );

      if (!mounted) return;
      _message(
        'تم إرسال التبرع للجمعية بنجاح، ويمكنك متابعة حالته من تبرعاتي',
        success: true,
      );
      Navigator.pop(context, true);
    } catch (error, stackTrace) {
      debugPrint('ADD CHARITY DONATION ERROR: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        final raw = error.toString().toLowerCase();
        final message =
            raw.contains('row-level security') ||
                raw.contains('permission denied') ||
                raw.contains('not authorized') ||
                raw.contains('42501')
            ? 'لا توجد صلاحية لإرسال التبرع. تأكد من تفعيل تحديث قاعدة البيانات.'
            : raw.contains('check constraint') || raw.contains('23514')
            ? 'أحد الأصناف أو الكميات غير مقبول؛ راجع البيانات وحاول مجددًا.'
            : raw.contains('foreign key') || raw.contains('23503')
            ? 'الجمعية المختارة غير موجودة أو لم تعد متاحة.'
            : raw.contains('column') &&
                  (raw.contains('items') || raw.contains('categories'))
            ? 'قاعدة البيانات تحتاج تحديث دعم الأصناف المتعددة.'
            : AppErrorMapper.message(
                error,
                fallback: 'تعذر إرسال التبرع. حاول مرة أخرى.',
              );
        _message(message);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _message(String text, {bool success = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          backgroundColor: success ? _green : const Color(0xFFB54747),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _background,
        appBar: AppBar(
          title: const Text(
            'إرسال تبرع',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          centerTitle: true,
          backgroundColor: _background,
          foregroundColor: _textPrimary,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 30),
            children: [
              _heroCard(),
              const SizedBox(height: 16),
              _charityCard(),
              const SizedBox(height: 14),
              _sectionCard(
                icon: Icons.inventory_2_outlined,
                title: 'ماذا تريد أن تتبرع؟',
                subtitle: 'اختر صنفًا واحدًا أو أكثر، وحدد تفاصيل كل صنف.',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _categories
                          .map((category) {
                            final selected = _selectedCategories.contains(
                              category.id,
                            );
                            return FilterChip(
                              selected: selected,
                              showCheckmark: true,
                              avatar: Icon(
                                category.icon,
                                size: 17,
                                color: selected ? _accent : _textSecondary,
                              ),
                              label: Text(category.label),
                              onSelected: (value) =>
                                  _toggleCategory(category.id, value),
                              selectedColor: _accent.withValues(
                                alpha: _isDark ? 0.25 : 0.12,
                              ),
                              backgroundColor: _cardSurface,
                              side: BorderSide(
                                color: selected
                                    ? _accent.withValues(alpha: 0.65)
                                    : _outline,
                              ),
                              labelStyle: TextStyle(
                                color: selected ? _accent : _textPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            );
                          })
                          .toList(growable: false),
                    ),
                    if (_categoryError != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        _categoryError!,
                        style: TextStyle(color: _colors.error, fontSize: 12),
                      ),
                    ],
                    if (_selectedCategories.isEmpty &&
                        _categoryError == null) ...[
                      const SizedBox(height: 10),
                      Text(
                        'اختر صنفًا أو أكثر من القائمة لإضافة الكمية والتفاصيل.',
                        style: TextStyle(color: _textSecondary, fontSize: 12),
                      ),
                    ],
                    const SizedBox(height: 12),
                    ..._orderedSelectedCategories.map(_itemCard),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _sectionCard(
                icon: Icons.description_outlined,
                title: 'معلومات عامة',
                subtitle: 'عنوان موجز يساعد الجمعية على فهم التبرع.',
                child: Column(
                  children: [
                    _field(
                      _title,
                      label: 'عنوان التبرع',
                      hint: 'مثال: ملابس شتوية وأجهزة منزلية',
                      required: true,
                      maxLength: 90,
                      icon: Icons.title_rounded,
                    ),
                    const SizedBox(height: 12),
                    _field(
                      _description,
                      label: 'وصف إضافي (اختياري)',
                      hint: 'أضف أي معلومات عامة تريد أن تعرفها الجمعية',
                      maxLines: 3,
                      icon: Icons.notes_rounded,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _sectionCard(
                icon: Icons.location_on_outlined,
                title: 'مكان الاستلام والتواصل',
                subtitle: 'لن تُعرض بياناتك للمتطوعين قبل إسناد التبرع لهم.',
                child: Column(
                  children: [
                    _field(
                      _city,
                      label: 'المدينة أو المنطقة',
                      hint: 'مثال: مدينة نصر، القاهرة',
                      required: true,
                      icon: Icons.location_city_rounded,
                    ),
                    const SizedBox(height: 12),
                    _field(
                      _address,
                      label: 'عنوان الاستلام بالتفصيل',
                      hint: 'الشارع، رقم المبنى، وأقرب علامة مميزة',
                      required: true,
                      maxLines: 2,
                      icon: Icons.home_outlined,
                    ),
                    const SizedBox(height: 12),
                    _field(
                      _phone,
                      label: 'رقم هاتف للتنسيق',
                      hint: 'رقم يمكن للجمعية التواصل من خلاله',
                      required: true,
                      keyboard: TextInputType.phone,
                      icon: Icons.phone_outlined,
                      validator: (value) {
                        final digits = (value ?? '').replaceAll(
                          RegExp(r'\D'),
                          '',
                        );
                        if (digits.length < 7) return 'أدخل رقم هاتف صحيحًا';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    _field(
                      _notes,
                      label: 'تعليمات الاستلام (اختياري)',
                      hint: 'أفضل وقت للاتصال، الدور، أو أي ملاحظة مفيدة',
                      maxLines: 2,
                      icon: Icons.schedule_outlined,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _imageSection(),
              const SizedBox(height: 14),
              _safetyNote(),
              const SizedBox(height: 20),
              SizedBox(
                height: 56,
                child: FilledButton.icon(
                  onPressed: _busy ? null : _submit,
                  icon: _busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.volunteer_activism_rounded),
                  label: Text(
                    _busy ? 'جارٍ إرسال التبرع...' : 'إرسال التبرع للجمعية',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: _green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'بعد الإرسال، ستراجع الجمعية طلبك ويمكنك متابعة كل خطوة من صفحة «تبرعاتي».',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _textSecondary,
                  fontSize: 11,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _heroCard() => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [_darkGreen, _green],
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
      ),
      borderRadius: BorderRadius.circular(24),
      boxShadow: const [
        BoxShadow(
          color: Color(0x260B7650),
          blurRadius: 18,
          offset: Offset(0, 8),
        ),
      ],
    ),
    child: const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.volunteer_activism_rounded,
              color: Colors.white,
              size: 27,
            ),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'تبرع بما لم تعد تحتاجه',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 9),
        Text(
          'يمكنك إرسال طعام أو ملابس أو عدة أصناف معًا إلى جمعية تختارها، مع توضيح الكمية والحالة ومكان الاستلام.',
          style: TextStyle(color: Colors.white, height: 1.55, fontSize: 12),
        ),
        SizedBox(height: 13),
        Row(
          children: [
            _StepPill(number: '١', label: 'اختر الأصناف'),
            SizedBox(width: 7),
            _StepPill(number: '٢', label: 'حدد الجمعية'),
            SizedBox(width: 7),
            _StepPill(number: '٣', label: 'تابع الاستلام'),
          ],
        ),
      ],
    ),
  );

  Widget _charityCard() => InkWell(
    onTap: _busy ? null : _chooseCharity,
    borderRadius: BorderRadius.circular(20),
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _charity == null ? _outline : _accent,
          width: 1.3,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: _isDark ? 0.25 : 0.05),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: _softSurface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.account_balance_rounded,
              color: _accent,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _charity?.name ?? 'اختر الجمعية المستفيدة',
                  style: TextStyle(
                    color: _textPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _charity == null
                      ? 'سيصل طلبك مباشرةً إلى حساب الجمعية'
                      : 'الجمعية التي ستراجع طلب التبرع',
                  style: TextStyle(color: _textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
          Icon(
            _charity == null
                ? Icons.add_circle_outline_rounded
                : Icons.edit_outlined,
            color: _accent,
          ),
        ],
      ),
    ),
  );

  Widget _sectionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget child,
  }) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: _cardSurface,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: _outline),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: _isDark ? 0.24 : 0.04),
          blurRadius: 12,
          offset: Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: _accent, size: 21),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: _textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(color: _textSecondary, fontSize: 11, height: 1.45),
        ),
        const SizedBox(height: 14),
        child,
      ],
    ),
  );

  Widget _itemCard(String category) {
    final model = _categories.firstWhere((item) => item.id == category);
    final conditions = _conditionsFor(category);
    final units = _unitsFor(category);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: _softSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(model.icon, color: _accent, size: 19),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  model.label,
                  style: TextStyle(
                    color: _textPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => _toggleCategory(category, false),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red.shade700,
                ),
                child: const Text('إزالة'),
              ),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _field(
                  _quantityControllers[category]!,
                  label: 'الكمية',
                  hint: '1',
                  required: true,
                  keyboard: TextInputType.number,
                  validator: (value) {
                    final number = int.tryParse((value ?? '').trim());
                    if (number == null || number <= 0) {
                      return 'أدخل رقمًا أكبر من صفر';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: units.contains(_units[category])
                      ? _units[category]
                      : units.first,
                  isExpanded: true,
                  decoration: _decoration('وحدة القياس'),
                  items: units
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(value, overflow: TextOverflow.ellipsis),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) {
                    if (value != null) setState(() => _units[category] = value);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: conditions.containsKey(_conditions[category])
                ? _conditions[category]
                : conditions.keys.first,
            isExpanded: true,
            decoration: _decoration('حالة الصنف'),
            items: conditions.entries
                .map(
                  (entry) => DropdownMenuItem(
                    value: entry.key,
                    child: Text(entry.value, overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(growable: false),
            onChanged: (value) {
              if (value != null) setState(() => _conditions[category] = value);
            },
          ),
          const SizedBox(height: 10),
          _field(
            _detailsControllers[category]!,
            label: 'تفاصيل الصنف (اختياري)',
            hint: category == 'food'
                ? 'مثال: أرز، زيت، وجبات جاهزة'
                : 'النوع، المقاس، أو أي وصف يساعد الجمعية',
            maxLines: 2,
          ),
          if (category == 'food') ...[
            const SizedBox(height: 5),
            Row(
              children: [
                Icon(
                  Icons.event_available_outlined,
                  color: _safetyIcon,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _bestBeforeDates[category] == null
                        ? 'تاريخ الصلاحية غير مضاف'
                        : 'الصلاحية حتى ${_formatDate(_bestBeforeDates[category]!)}',
                    style: TextStyle(
                      color: _safetyText,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => _chooseFoodExpiry(category),
                  child: Text(
                    _bestBeforeDates[category] == null
                        ? 'إضافة تاريخ'
                        : 'تغيير التاريخ',
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _imageSection() => _sectionCard(
    icon: Icons.photo_library_outlined,
    title: 'صور التبرع (اختيارية)',
    subtitle: 'الصورة الواضحة تساعد الجمعية على تقييم الأصناف بسرعة. الحد الأقصى 6 صور.',
    child: Column(
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _busy || _images.length >= 6 ? null : _pickImages,
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('اختيار صور'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _busy || _images.length >= 6 ? null : _takePhoto,
                icon: const Icon(Icons.camera_alt_outlined),
                label: const Text('التقاط صورة'),
              ),
            ),
          ],
        ),
        if (_images.isNotEmpty) ...[
          const SizedBox(height: 10),
          SizedBox(
            height: 88,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _images.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, index) => Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      File(_images[index].path),
                      width: 88,
                      height: 88,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: InkWell(
                      onTap: _busy
                          ? null
                          : () => setState(() => _images.removeAt(index)),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: _cardSurface,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.close_rounded,
                          size: 15,
                          color: _colors.error,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    ),
  );

  Widget _safetyNote() => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: _safetyBackground,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: _safetyBorder),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.health_and_safety_outlined, color: _safetyIcon, size: 20),
        SizedBox(width: 9),
        Expanded(
          child: Text(
            'يرجى التأكد من سلامة الطعام وعدم انتهاء صلاحيته، ووصف حالة الأجهزة والأثاث بدقة. ستراجع الجمعية التبرع وتتواصل معك لترتيب الاستلام.',
            style: TextStyle(color: _safetyText, fontSize: 11, height: 1.5),
          ),
        ),
      ],
    ),
  );

  InputDecoration _decoration(String label) => InputDecoration(
    labelText: label,
    filled: true,
    fillColor: _softSurface,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(13),
      borderSide: BorderSide(color: _outline),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(13),
      borderSide: BorderSide(color: _outline),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(13),
      borderSide: BorderSide(color: _accent, width: 1.5),
    ),
  );

  Widget _field(
    TextEditingController controller, {
    required String label,
    String? hint,
    bool required = false,
    int maxLines = 1,
    int? maxLength,
    TextInputType? keyboard,
    IconData? icon,
    String? Function(String?)? validator,
  }) => TextFormField(
    controller: controller,
    maxLines: maxLines,
    maxLength: maxLength,
    keyboardType: keyboard,
    textInputAction: maxLines > 1
        ? TextInputAction.newline
        : TextInputAction.next,
    decoration: _decoration(label).copyWith(
      hintText: hint,
      prefixIcon: icon == null ? null : Icon(icon, size: 19),
    ),
    validator:
        validator ??
        (required
            ? (value) => value == null || value.trim().isEmpty
                  ? 'هذا الحقل مطلوب'
                  : null
            : null),
  );
}

class _DonationCategory {
  const _DonationCategory(this.id, this.label, this.icon);

  final String id;
  final String label;
  final IconData icon;
}

class _StepPill extends StatelessWidget {
  const _StepPill({required this.number, required this.label});

  final String number;
  final String label;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 9,
            backgroundColor: Colors.white,
            child: Text(
              number,
              style: const TextStyle(
                color: Color(0xFF0B7650),
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
