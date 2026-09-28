// lib/features/community/presentation/pages/add_community_need_page.dart

import 'package:flutter/material.dart';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:loqma/core/services/supabase_service.dart';
import 'package:loqma/features/community/data/repositories/community_needs_repository.dart';

class AddCommunityNeedPage extends StatefulWidget {
  final String? needId;
  final Map<String, dynamic>? initialData;

  const AddCommunityNeedPage({
    super.key,
    this.needId,
    this.initialData,
  });

  bool get isEditMode => needId != null && needId!.trim().isNotEmpty;

  @override
  State<AddCommunityNeedPage> createState() => _AddCommunityNeedPageState();
}

class _AddCommunityNeedPageState extends State<AddCommunityNeedPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _whatsappController = TextEditingController();

  final _repository = CommunityNeedsRepository();
  final _imagePicker = ImagePicker();

  // ─────────────── الألوان ───────────────
  static const _green = Color(0xFF0B7650);
  static const _greenSoft = Color(0xFFE7F5EE);
  static const _greenLight = Color(0xFF25B77C);
  static const _darkGreen = Color(0xFF0F2E23);
  static const _background = Color(0xFFF7FAF8);
  static const _orange = Color(0xFFE28B00);
  static const _red = Color(0xFFDC4C4C);
  static const _purple = Color(0xFF7B5EC7);
  static const _blue = Color(0xFF3E83C5);
  static const _muted = Color(0xFF8A9D95);
  static const _cardBg = Colors.white;

  // ✅ محافظات مصر
  static const List<String> _egyptianGovernorates = [
    'القاهرة',
    'الجيزة',
    'الإسكندرية',
    'الدقهلية',
    'الشرقية',
    'القليوبية',
    'المنوفية',
    'الغربية',
    'كفر الشيخ',
    'البحيرة',
    'دمياط',
    'بورسعيد',
    'الإسماعيلية',
    'السويس',
    'شمال سيناء',
    'جنوب سيناء',
    'الفيوم',
    'بني سويف',
    'المنيا',
    'أسيوط',
    'سوهاج',
    'قنا',
    'الأقصر',
    'أسوان',
    'البحر الأحمر',
    'الوادي الجديد',
    'مطروح',
  ];

  // ─────────────── الحالة ───────────────
  String _urgency = 'normal';
  bool _isSubmitting = false;
  bool _isLoadingCategories = true;

  List<Map<String, dynamic>> _categories = [];
  String? _selectedCategoryId;
  String? _selectedCategorySlug;
  String? _selectedCategoryName;

  // ✅ المدينة (من الـ picker)
  String? _selectedCity;
  XFile? _selectedImage;
  String? _existingImageUrl;

  bool get _isEditMode => widget.isEditMode;

  @override
  void initState() {
    super.initState();

    if (_isEditMode) _prefillFromInitialData();
    _loadCategories();
  }

  void _prefillFromInitialData() {
    final data = widget.initialData;
    if (data == null) return;

    _titleController.text = data['title']?.toString() ?? '';
    _descriptionController.text = data['description']?.toString() ?? '';
    _addressController.text = data['address']?.toString() ?? '';
    _phoneController.text = data['contact_phone']?.toString() ?? '';
    _whatsappController.text = data['contact_whatsapp']?.toString() ?? '';

    final qty = data['quantity'];
    if (qty != null) _quantityController.text = qty.toString();

    _urgency = data['urgency']?.toString() ?? 'normal';

    final cityValue = data['city']?.toString().trim();
    if (cityValue != null && cityValue.isNotEmpty) {
      _selectedCity = cityValue;
    }

    _selectedCategoryId = data['category_id']?.toString();
    _selectedCategorySlug = data['category_slug']?.toString();
    _selectedCategoryName = data['category_name_ar']?.toString();
    _existingImageUrl = data['image_url']?.toString();
  }

  Future<void> _pickImage() async {
    final image = await _imagePicker.pickImage(source: ImageSource.gallery, imageQuality: 82, maxWidth: 1600);
    if (image != null && mounted) setState(() => _selectedImage = image);
  }

  Future<void> _openCategoryPicker() async {
    final queryController = TextEditingController();
    await showModalBottomSheet<void>(
      context: context, isScrollControlled: true, useSafeArea: true, backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(builder: (context, setSheetState) {
        final query = queryController.text.trim().toLowerCase();
        final filtered = _categories.where((cat) => (cat['name_ar']?.toString() ?? '').toLowerCase().contains(query)).toList();
        return Container(
          height: MediaQuery.of(context).size.height * .72,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
          child: Column(children: [
            Container(width: 42, height: 4, decoration: BoxDecoration(color: _muted.withValues(alpha: .3), borderRadius: BorderRadius.circular(4))),
            const SizedBox(height: 16),
            const Text('اختار نوع الاحتياج', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _darkGreen)),
            const SizedBox(height: 12),
            TextField(controller: queryController, onChanged: (_) => setSheetState(() {}), autofocus: true, decoration: InputDecoration(prefixIcon: const Icon(Icons.search_rounded, color: _green), hintText: 'ابحث في التصنيفات...', filled: true, fillColor: _greenSoft, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none))),
            const SizedBox(height: 12),
            Expanded(child: ListView.separated(itemCount: filtered.length, separatorBuilder: (_, __) => const Divider(height: 1), itemBuilder: (_, index) {
              final cat = filtered[index]; final id = cat['id']?.toString() ?? ''; final name = cat['name_ar']?.toString() ?? ''; final selected = id == _selectedCategoryId;
              return ListTile(leading: CircleAvatar(backgroundColor: selected ? _green : _greenSoft, child: Icon(_categoryIcon(name), color: selected ? Colors.white : _green, size: 19)), title: Text(name, style: const TextStyle(fontWeight: FontWeight.w800)), trailing: selected ? const Icon(Icons.check_circle_rounded, color: _green) : null, onTap: () { setState(() { _selectedCategoryId = id; _selectedCategorySlug = cat['slug']?.toString(); _selectedCategoryName = name; }); Navigator.pop(sheetContext); });
            }))
          ]),
        );
      }),
    );
    queryController.dispose();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _quantityController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _whatsappController.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════
  // LOAD CATEGORIES
  // ═══════════════════════════════════════════════════════════
  Future<void> _loadCategories() async {
    try {
      final rows = await SupabaseService()
          .client
          .from('community_categories')
          .select('id, slug, name_ar')
          .eq('is_active', true)
          .order('sort_order');

      if (!mounted) return;
      setState(() {
        _categories = List<Map<String, dynamic>>.from(rows);
        _isLoadingCategories = false;
      });
    } catch (e) {
      debugPrint('❌ loadCategories error: $e');
      if (mounted) {
        setState(() => _isLoadingCategories = false);
        _message('تعذر تحميل التصنيفات');
      }
    }
  }

  // ═══════════════════════════════════════════════════════════
  // CITY PICKER
  // ═══════════════════════════════════════════════════════════
  Future<void> _openCityPicker() async {
    final picked = await showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (_) => _GovernoratePickerSheet(
        selected: _selectedCity,
      ),
    );

    if (!mounted || picked == null) return;

    setState(() => _selectedCity = picked.isEmpty ? null : picked);
  }

  // ═══════════════════════════════════════════════════════════
  // SUBMIT
  // ═══════════════════════════════════════════════════════════
  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    if (_selectedCategoryId == null ||
        _selectedCategorySlug == null ||
        _selectedCategoryName == null) {
      _message('اختر التصنيف');
      return;
    }

    if (_selectedCity == null || _selectedCity!.isEmpty) {
      _message('اختر المحافظة');
      return;
    }

    final quantity = int.tryParse(_quantityController.text.trim()) ?? 0;
    if (quantity <= 0) {
      _message('أدخل كمية أكبر من صفر');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      var imageUrl = _existingImageUrl;
      if (_selectedImage != null) {
        imageUrl = await _repository.uploadNeedImage(_selectedImage!);
      }
      if (_isEditMode) {
        final success = await _repository.updateNeed(
          needId: widget.needId!,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          quantity: quantity,
          urgency: _urgency,
          city: _selectedCity,
          address: _addressController.text.trim(),
          contactPhone: _phoneController.text.trim(),
          contactWhatsapp: _whatsappController.text.trim(),
          categoryId: _selectedCategoryId,
          categorySlug: _selectedCategorySlug,
          categoryNameAr: _selectedCategoryName,
          imageUrl: imageUrl,
        );

        if (!mounted) return;

        if (success) {
          _message('✅ تم تحديث الاحتياج بنجاح', success: true);
          Navigator.pop(context, true);
        } else {
          _message('تعذر تحديث الاحتياج');
        }
        return;
      }

      await _repository.createNeed(
        categoryId: _selectedCategoryId!,
        categorySlug: _selectedCategorySlug!,
        categoryNameAr: _selectedCategoryName!,
        title: _titleController.text,
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        quantity: quantity,
        urgency: _urgency,
        city: _selectedCity,
        address: _addressController.text.trim().isEmpty
            ? null
            : _addressController.text.trim(),
        contactPhone: _phoneController.text.trim(),
        contactWhatsapp: _whatsappController.text.trim(),
        imageUrl: imageUrl,
      );

      if (!mounted) return;
      _message('✅ تم نشر احتياجك بنجاح', success: true);
      Navigator.pop(context, true);
    } catch (e) {
      debugPrint('❌ submit error: $e');
      if (mounted) {
        _message(e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // ═══════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _background,
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ── APP BAR
            SliverAppBar(
              expandedHeight: 160,
              pinned: true,
              stretch: true,
              backgroundColor: _green,
              foregroundColor: Colors.white,
              elevation: 0,
              flexibleSpace: FlexibleSpaceBar(
                stretchModes: const [StretchMode.zoomBackground],
                background: _buildHeroHeader(),
              ),
              leading: IconButton(
                onPressed: () => Navigator.maybePop(context),
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
              ),
            ),

            // ── FORM
            SliverToBoxAdapter(
              child: Form(
                key: _formKey,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
                  child: Column(
                    children: [
                      _buildCategorySection(),
                      const SizedBox(height: 14),
                      _buildImageSection(),
                      const SizedBox(height: 14),
                      _buildDetailsSection(),
                      const SizedBox(height: 14),
                      _buildUrgencySection(),
                      const SizedBox(height: 14),
                      _buildLocationSection(),
                      const SizedBox(height: 14),
                      _buildContactSection(),
                      const SizedBox(height: 16),
                      _buildInfoNote(),
                      const SizedBox(height: 20),
                      _buildSubmitButton(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // HERO HEADER
  // ═══════════════════════════════════════════════════════════
  Widget _buildHeroHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_darkGreen, _green],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -40,
            left: -40,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            right: -30,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.04),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          _isEditMode
                              ? Icons.edit_rounded
                              : Icons.volunteer_activism_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isEditMode
                                  ? 'عدّل احتياجك'
                                  : 'قولنا إنت محتاج إيه',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 21,
                                fontWeight: FontWeight.w900,
                                height: 1.1,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              _isEditMode
                                  ? 'أي تعديل هيتطبق فورًا'
                                  : 'هنوصّل احتياجك للناس اللي تقدر تساعد',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // CATEGORY SECTION
  // ═══════════════════════════════════════════════════════════
  Widget _buildCategorySection() {
    return _buildCard(
      icon: Icons.category_rounded,
      title: 'التصنيف',
      subtitle: 'اختار نوع الحاجة اللي محتاجها',
      child: _isLoadingCategories
          ? const Padding(
              padding: EdgeInsets.all(20),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: _green,
                    strokeWidth: 2.5,
                  ),
                ),
              ),
            )
          : _categories.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('لا توجد تصنيفات'),
                )
              : _buildCategoryPickerField(),
    );
  }

  Widget _buildCategoryPickerField() {
    final selected = _selectedCategoryName?.trim().isNotEmpty == true;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _openCategoryPicker,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(color: const Color(0xFFF8FBF9), borderRadius: BorderRadius.circular(14), border: Border.all(color: selected ? _green : const Color(0xFFE0EBE5), width: selected ? 1.5 : 1)),
          child: Row(children: [Icon(selected ? _categoryIcon(_selectedCategoryName!) : Icons.search_rounded, color: _green), const SizedBox(width: 12), Expanded(child: Text(selected ? _selectedCategoryName! : 'ابحث واختر التصنيف', style: TextStyle(color: selected ? _darkGreen : _muted, fontWeight: FontWeight.w800))), const Icon(Icons.keyboard_arrow_down_rounded, color: _green)]),
        ),
      ),
    );
  }

  Widget _buildImageSection() {
    final hasExisting = _existingImageUrl != null && _existingImageUrl!.isNotEmpty;
    final hasImage = _selectedImage != null || hasExisting;
    return _buildCard(
      icon: Icons.image_outlined,
      title: 'صورة توضيحية (اختياري)',
      subtitle: 'صوّر الحاجة أو أضف صورة شبه اللي بتدور عليها',
      child: InkWell(
        onTap: _pickImage,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 150, width: double.infinity,
          decoration: BoxDecoration(color: _greenSoft, borderRadius: BorderRadius.circular(16), border: Border.all(color: _green.withValues(alpha: .2))),
          clipBehavior: Clip.antiAlias,
          child: hasImage
              ? Stack(fit: StackFit.expand, children: [
                  _selectedImage != null ? Image.file(File(_selectedImage!.path), fit: BoxFit.cover) : Image.network(_existingImageUrl!, fit: BoxFit.cover),
                  Positioned(top: 8, left: 8, child: IconButton(onPressed: () => setState(() { _selectedImage = null; _existingImageUrl = null; }), style: IconButton.styleFrom(backgroundColor: Colors.black54, foregroundColor: Colors.white), icon: const Icon(Icons.close_rounded))),
                ])
              : const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.add_photo_alternate_outlined, color: _green, size: 40), SizedBox(height: 8), Text('اضغط لإضافة صورة', style: TextStyle(color: _green, fontWeight: FontWeight.w800))]),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // DETAILS SECTION
  // ═══════════════════════════════════════════════════════════
  Widget _buildDetailsSection() {
    return _buildCard(
      icon: Icons.edit_note_rounded,
      title: 'تفاصيل الاحتياج',
      subtitle: 'اكتب بوضوح إنت محتاج إيه',
      child: Column(
        children: [
          _buildField(
            controller: _titleController,
            label: 'عنوان الاحتياج',
            hint: 'مثال: محتاج ترابيزة سوفا',
            icon: Icons.title_rounded,
            required: true,
            minLength: 3,
          ),
          const SizedBox(height: 12),
          _buildField(
            controller: _descriptionController,
            label: 'وصف إضافي (اختياري)',
            hint: 'مثال: مقاس 120×60، لون بني',
            icon: Icons.description_outlined,
            maxLines: 3,
          ),
          const SizedBox(height: 12),
          _buildField(
            controller: _quantityController,
            label: 'الكمية',
            hint: '1',
            icon: Icons.inventory_2_rounded,
            required: true,
            numeric: true,
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // URGENCY SECTION
  // ═══════════════════════════════════════════════════════════
  Widget _buildUrgencySection() {
    const options = <String, (String, IconData, Color)>{
      'low': ('عادي', Icons.check_circle_rounded, _green),
      'normal': ('متوسط', Icons.flag_rounded, _blue),
      'high': ('مهم', Icons.priority_high_rounded, _orange),
      'urgent': ('عاجل جدًا', Icons.bolt_rounded, _red),
    };

    return _buildCard(
      icon: Icons.flag_outlined,
      title: 'الأولوية',
      subtitle: 'محتاجها إمتى؟',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: options.entries.map((e) {
          final key = e.key;
          final (label, icon, color) = e.value;
          final selected = _urgency == key;

          return _buildChoiceChip(
            label: label,
            icon: icon,
            color: color,
            selected: selected,
            onTap: () => setState(() => _urgency = key),
          );
        }).toList(),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // LOCATION SECTION
  // ═══════════════════════════════════════════════════════════
  Widget _buildLocationSection() {
    return _buildCard(
      icon: Icons.location_on_rounded,
      title: 'المكان',
      subtitle: 'عشان نساعدك تلاقي حد قريب منك',
      child: Column(
        children: [
          // ── City picker
          _buildCityPickerField(),
          const SizedBox(height: 12),
          // ── Address
          _buildField(
            controller: _addressController,
            label: 'العنوان بالتفصيل',
            hint: 'مثال: شارع البحر - بجوار صيدلية...',
            icon: Icons.place_outlined,
            maxLines: 2,
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _blue.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _blue.withValues(alpha: 0.15)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  color: _blue,
                  size: 15,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'اكتب العنوان بالتفصيل عشان الناس تلاقيك بسهولة.',
                    style: TextStyle(
                      color: _blue.withValues(alpha: 0.9),
                      fontSize: 11,
                      height: 1.4,
                      fontWeight: FontWeight.w600,
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

  // ── City picker field
  Widget _buildCityPickerField() {
    final hasCity = _selectedCity != null && _selectedCity!.isNotEmpty;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _openCityPicker,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FBF9),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: hasCity
                  ? _green.withValues(alpha: 0.4)
                  : const Color(0xFFE0EBE5),
              width: hasCity ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: hasCity ? _green : _green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.location_city_rounded,
                  color: hasCity ? Colors.white : _green,
                  size: 17,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'المحافظة',
                      style: TextStyle(
                        color: _muted,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      hasCity ? _selectedCity! : 'اختار محافظتك',
                      style: TextStyle(
                        color: hasCity ? _darkGreen : _muted,
                        fontSize: 14,
                        fontWeight: hasCity ? FontWeight.w900 : FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _greenSoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: _green,
                  size: 18,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // CONTACT SECTION
  // ═══════════════════════════════════════════════════════════
  Widget _buildContactSection() {
    return _buildCard(
      icon: Icons.contact_phone_rounded,
      title: 'بيانات التواصل',
      subtitle: 'هنعرضها للناس اللي عايزة تساعدك',
      child: Column(
        children: [
          _buildField(
            controller: _phoneController,
            label: 'رقم الهاتف',
            hint: 'مثال: 01012345678',
            icon: Icons.phone_rounded,
            required: true,
            phone: true,
          ),
          const SizedBox(height: 12),
          _buildField(
            controller: _whatsappController,
            label: 'رقم الواتساب',
            hint: 'مثال: 01012345678',
            icon: Icons.chat_rounded,
            required: true,
            phone: true,
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _green.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _green.withValues(alpha: 0.15)),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.visibility_rounded,
                  color: _green,
                  size: 16,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'الأرقام دي هتظهر للناس اللي عايزة تساعدك. تأكد إنها صحيحة.',
                    style: TextStyle(
                      color: _green,
                      fontSize: 11,
                      height: 1.4,
                      fontWeight: FontWeight.w600,
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

  // ═══════════════════════════════════════════════════════════
  // INFO NOTE
  // ═══════════════════════════════════════════════════════════
  Widget _buildInfoNote() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _orange.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _orange.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _orange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.info_rounded,
                  color: _orange,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'ملاحظات مهمة',
                style: TextStyle(
                  color: _orange,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildNoteItem(
            icon: Icons.timer_outlined,
            text: 'الاحتياج هيظهر لمدة 7 أيام وبعدها ينتهي تلقائيًا',
          ),
          const SizedBox(height: 8),
          _buildNoteItem(
            icon: Icons.visibility_outlined,
            text: 'هتقدر تشوف كام واحد تواصل معاك',
          ),
          const SizedBox(height: 8),
          _buildNoteItem(
            icon: Icons.event_available_outlined,
            text: 'الحد الأقصى 5 احتياجات في اليوم',
          ),
        ],
      ),
    );
  }

  Widget _buildNoteItem({required IconData icon, required String text}) {
    return Row(
      children: [
        Icon(icon, color: _orange, size: 15),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: _orange.withValues(alpha: 0.9),
              fontSize: 12,
              height: 1.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  // SUBMIT BUTTON
  // ═══════════════════════════════════════════════════════════
  Widget _buildSubmitButton() {
    final label = _isSubmitting
        ? (_isEditMode ? 'جاري التحديث...' : 'جاري النشر...')
        : (_isEditMode ? 'حفظ التعديلات' : 'نشر الاحتياج');

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: _green.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: SizedBox(
        height: 56,
        child: FilledButton.icon(
          onPressed: _isSubmitting ? null : _submit,
          icon: _isSubmitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              : Icon(
                  _isEditMode ? Icons.check_rounded : Icons.publish_rounded,
                  size: 22,
                ),
          label: Text(
            label,
            style: const TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w900,
            ),
          ),
          style: FilledButton.styleFrom(
            backgroundColor: _green,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // CARD WRAPPER
  // ═══════════════════════════════════════════════════════════
  Widget _buildCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFEEF3F0)),
        boxShadow: [
          BoxShadow(
            color: _darkGreen.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _greenSoft,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: _green, size: 19),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: _darkGreen,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: _muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // CHOICE CHIP
  // ═══════════════════════════════════════════════════════════
  Widget _buildChoiceChip({
    required String label,
    required IconData icon,
    required Color color,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? color : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? color : const Color(0xFFE0EBE5),
            width: selected ? 1.5 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: selected ? Colors.white : color,
              size: 16,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : _darkGreen,
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // FIELD
  // ═══════════════════════════════════════════════════════════
  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool required = false,
    bool numeric = false,
    bool phone = false,
    int? minLength,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: numeric
          ? TextInputType.number
          : (phone ? TextInputType.phone : TextInputType.text),
      maxLines: maxLines,
      inputFormatters: phone
          ? [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(15),
            ]
          : null,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: _darkGreen,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(
          color: _muted,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        hintStyle: TextStyle(
          color: _muted.withValues(alpha: 0.6),
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        prefixIcon: Container(
          margin: const EdgeInsets.all(8),
          alignment: Alignment.center,
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: _greenSoft,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, color: _green, size: 16),
        ),
        filled: true,
        fillColor: const Color(0xFFF8FBF9),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE0EBE5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _green, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _red, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _red, width: 1.6),
        ),
      ),
      validator: (value) {
        final text = value?.trim() ?? '';

        if (required && text.isEmpty) return 'هذا الحقل مطلوب';

        if (minLength != null && text.isNotEmpty && text.length < minLength) {
          return 'الحد الأدنى $minLength أحرف';
        }

        if (numeric && text.isNotEmpty) {
          final parsed = int.tryParse(text);
          if (parsed == null || parsed <= 0) {
            return 'أدخل رقم صحيح أكبر من صفر';
          }
        }

        if (phone && text.isNotEmpty) {
          final clean = text.replaceAll(RegExp(r'[^\d]'), '');
          if (clean.length < 10 || clean.length > 15) {
            return 'أدخل رقم صحيح (10-15 رقم)';
          }
        }

        return null;
      },
    );
  }

  // ═══════════════════════════════════════════════════════════
  // ICON MAPPING
  // ═══════════════════════════════════════════════════════════
  IconData _categoryIcon(String name) {
    final n = name.toLowerCase();
    if (n.contains('طعام') || n.contains('أكل')) {
      return Icons.restaurant_rounded;
    }
    if (n.contains('ملابس')) return Icons.checkroom_rounded;
    if (n.contains('دواء') || n.contains('صحة')) {
      return Icons.medical_services_rounded;
    }
    if (n.contains('أثاث')) return Icons.chair_rounded;
    if (n.contains('تعليم') || n.contains('كتب')) {
      return Icons.menu_book_rounded;
    }
    if (n.contains('مال')) return Icons.payments_rounded;
    if (n.contains('سكن') || n.contains('بيت')) {
      return Icons.home_rounded;
    }
    if (n.contains('كهرب') || n.contains('سباك')) {
      return Icons.build_rounded;
    }
    return Icons.category_rounded;
  }

  // ═══════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════
  void _message(String text, {bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text, textDirection: TextDirection.rtl),
          backgroundColor: success ? _green : _red,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
  }
}

// ═══════════════════════════════════════════════════════════
// Governorate Picker Bottom Sheet
// ═══════════════════════════════════════════════════════════
class _GovernoratePickerSheet extends StatefulWidget {
  final String? selected;

  const _GovernoratePickerSheet({required this.selected});

  @override
  State<_GovernoratePickerSheet> createState() =>
      _GovernoratePickerSheetState();
}

class _GovernoratePickerSheetState extends State<_GovernoratePickerSheet> {
  static const _green = Color(0xFF0B7650);
  static const _greenSoft = Color(0xFFE7F5EE);
  static const _darkGreen = Color(0xFF0F2E23);
  static const _muted = Color(0xFF8A9D95);

  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final filtered = _AddCommunityNeedPageState._egyptianGovernorates
        .where((c) => c.contains(_query))
        .toList();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.85,
          ),
          child: Padding(
            padding: EdgeInsets.only(bottom: bottomInset),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Handle
                Container(
                  margin: const EdgeInsets.only(top: 10),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDDE8E2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 18),

                // ── Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _greenSoft,
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: const Icon(
                          Icons.location_city_rounded,
                          color: _green,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'اختار المحافظة',
                              style: TextStyle(
                                color: _darkGreen,
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${_AddCommunityNeedPageState._egyptianGovernorates.length} محافظة متاحة',
                              style: const TextStyle(
                                color: _muted,
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context, null),
                        icon: const Icon(Icons.close_rounded),
                        color: _darkGreen,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),
                const Divider(height: 1, color: Color(0xFFEFF5F1)),
                const SizedBox(height: 12),

                // ── Search
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F9F7),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(width: 12),
                        const Icon(
                          Icons.search_rounded,
                          color: _green,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            textDirection: TextDirection.rtl,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _darkGreen,
                            ),
                            onChanged: (v) => setState(() => _query = v),
                            decoration: const InputDecoration(
                              hintText: 'ابحث عن محافظة...',
                              hintStyle: TextStyle(
                                color: _muted,
                                fontSize: 13,
                              ),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                // ── List
                Flexible(
                  child: filtered.isEmpty
                      ? _buildNoMatchesMessage()
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                          shrinkWrap: true,
                          itemCount: filtered.length,
                          itemBuilder: (_, i) {
                            final city = filtered[i];
                            final selected = widget.selected == city;

                            return _buildCityTile(
                              label: city,
                              selected: selected,
                              onTap: () => Navigator.pop(context, city),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNoMatchesMessage() {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.search_off_rounded, color: _muted, size: 52),
          const SizedBox(height: 14),
          const Text(
            'مفيش نتائج',
            style: TextStyle(
              color: _darkGreen,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'مفيش محافظة مطابقة لـ "$_query"',
            style: const TextStyle(color: _muted, fontSize: 12),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          TextButton.icon(
            onPressed: () {
              _searchController.clear();
              setState(() => _query = '');
            },
            icon: const Icon(Icons.clear_rounded, size: 16),
            label: const Text('مسح البحث'),
            style: TextButton.styleFrom(foregroundColor: _green),
          ),
        ],
      ),
    );
  }

  Widget _buildCityTile({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: selected ? _greenSoft : Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? _green.withValues(alpha: 0.3)
                  : const Color(0xFFEFF5F1),
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? _green : _greenSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.location_city_rounded,
                  color: selected ? Colors.white : _green,
                  size: 17,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: selected ? _green : _darkGreen,
                    fontSize: 13.5,
                    fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                  ),
                ),
              ),
              if (selected)
                Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: _green,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
