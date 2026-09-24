// lib/features/community/presentation/pages/add_community_need_page.dart

import 'package:flutter/material.dart';
import 'package:loqma/core/services/supabase_service.dart';
import 'package:loqma/features/community/data/repositories/community_needs_repository.dart';

class AddCommunityNeedPage extends StatefulWidget {
  /// ✅ في وضع التعديل: رقم الاحتياج
  final String? needId;

  /// ✅ في وضع التعديل: البيانات الأولية
  final Map<String, dynamic>? initialData;

  const AddCommunityNeedPage({
    super.key,
    this.needId,
    this.initialData,
  });

  /// ✅ هل إحنا في وضع التعديل؟
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
  final _cityController = TextEditingController();
  final _phoneController = TextEditingController();
  final _whatsappController = TextEditingController();

  final _repository = CommunityNeedsRepository();

  // ─────────────── الألوان ───────────────
  static const _green = Color(0xFF0B7650);
  static const _darkGreen = Color(0xFF0F2E23);
  static const _background = Color(0xFFF5F9F7);
  static const _orange = Color(0xFFE28B00);
  static const _red = Color(0xFFB54747);
  static const _purple = Color(0xFF6651B5);
  static const _blue = Color(0xFF3679C8);
  static const _whatsapp = Color(0xFF25D366);

  // ─────────────── الحالة ───────────────
  String _urgency = 'normal';
  bool _isSubmitting = false;
  bool _isLoadingCategories = true;

  // ─────────────── التصنيف ───────────────
  List<Map<String, dynamic>> _categories = [];
  String? _selectedCategoryId;
  String? _selectedCategorySlug;
  String? _selectedCategoryName;

  bool get _isEditMode => widget.isEditMode;

  @override
  void initState() {
    super.initState();

    if (_isEditMode) {
      _prefillFromInitialData();
    }

    _loadCategories();
  }

  // ═══════════════════════════════════════════════════════════
  // PREFILL (وضع التعديل)
  // ═══════════════════════════════════════════════════════════

  void _prefillFromInitialData() {
    final data = widget.initialData;
    if (data == null) return;

    _titleController.text = data['title']?.toString() ?? '';
    _descriptionController.text = data['description']?.toString() ?? '';
    _cityController.text = data['city']?.toString() ?? '';
    _addressController.text = data['address']?.toString() ?? '';
    _phoneController.text = data['contact_phone']?.toString() ?? '';
    _whatsappController.text = data['contact_whatsapp']?.toString() ?? '';

    final qty = data['quantity'];
    if (qty != null) {
      _quantityController.text = qty.toString();
    }

    _urgency = data['urgency']?.toString() ?? 'normal';

    _selectedCategoryId = data['category_id']?.toString();
    _selectedCategorySlug = data['category_slug']?.toString();
    _selectedCategoryName = data['category_name_ar']?.toString();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _quantityController.dispose();
    _addressController.dispose();
    _cityController.dispose();
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

    final quantity = int.tryParse(_quantityController.text.trim()) ?? 0;
    if (quantity <= 0) {
      _message('أدخل كمية أكبر من صفر');
      return;
    }

    if (_phoneController.text.trim().isEmpty) {
      _message('أدخل رقم الهاتف');
      return;
    }

    if (_whatsappController.text.trim().isEmpty) {
      _message('أدخل رقم الواتساب');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // ✅ وضع التعديل
      if (_isEditMode) {
        final success = await _repository.updateNeed(
          needId: widget.needId!,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          quantity: quantity,
          urgency: _urgency,
          city: _cityController.text.trim(),
          address: _addressController.text.trim(),
          contactPhone: _phoneController.text.trim(),
          contactWhatsapp: _whatsappController.text.trim(),
          categoryId: _selectedCategoryId,
          categorySlug: _selectedCategorySlug,
          categoryNameAr: _selectedCategoryName,
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

      // ✅ وضع الإنشاء
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
        city: _cityController.text.trim().isEmpty
            ? null
            : _cityController.text.trim(),
        address: _addressController.text.trim().isEmpty
            ? null
            : _addressController.text.trim(),
        contactPhone: _phoneController.text.trim(),
        contactWhatsapp: _whatsappController.text.trim(),
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
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: _darkGreen,
          elevation: 0,
          centerTitle: true,
          title: Text(
            _isEditMode ? 'تعديل الاحتياج' : 'أنا محتاج حاجة',
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
          ),
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              _buildIntro(),
              const SizedBox(height: 20),
              _buildCategorySection(),
              const SizedBox(height: 20),
              _buildDetailsSection(),
              const SizedBox(height: 20),
              _buildUrgencySection(),
              const SizedBox(height: 20),
              _buildLocationSection(),
              const SizedBox(height: 20),
              _buildContactSection(),
              const SizedBox(height: 20),
              _buildInfoNote(),
              const SizedBox(height: 24),
              _buildSubmitButton(),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // INTRO
  // ═══════════════════════════════════════════════════════════

  Widget _buildIntro() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_darkGreen, _green],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _darkGreen.withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _isEditMode
                  ? Icons.edit_rounded
                  : Icons.volunteer_activism_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _isEditMode ? 'عدّل بيانات احتياجك' : 'قولنا إنت محتاج إيه',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _isEditMode
                ? 'خد بالك: أي تعديل هيتطبق فورًا.'
                : 'اكتب احتياجك بوضوح، وهنعرضه على الناس اللي عندها الحاجة دي.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 13,
              height: 1.5,
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
      icon: Icons.category_outlined,
      title: 'التصنيف',
      subtitle: 'اختار نوع الحاجة اللي محتاجها',
      child: _isLoadingCategories
          ? const Padding(
              padding: EdgeInsets.all(20),
              child: Center(
                child: CircularProgressIndicator(color: _green),
              ),
            )
          : _categories.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('لا توجد تصنيفات'),
                )
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _categories.map((cat) {
                    final id = cat['id']?.toString() ?? '';
                    final name = cat['name_ar']?.toString() ?? '';
                    final selected = _selectedCategoryId == id;

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedCategoryId = id;
                          _selectedCategorySlug = cat['slug']?.toString();
                          _selectedCategoryName = name;
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: selected ? _green : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selected ? _green : const Color(0xFFE0EBE5),
                            width: selected ? 1.5 : 1,
                          ),
                          boxShadow: selected
                              ? [
                                  BoxShadow(
                                    color: _green.withValues(alpha: 0.25),
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
                              Icons.category_rounded,
                              color: selected ? Colors.white : _green,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              name,
                              style: TextStyle(
                                color: selected ? Colors.white : _darkGreen,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
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
            icon: Icons.inventory_2_outlined,
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
      'low': ('عادي', Icons.sentiment_satisfied_rounded, _green),
      'normal': ('متوسط', Icons.sentiment_neutral_rounded, _blue),
      'high': ('مهم', Icons.priority_high_rounded, _orange),
      'urgent': ('عاجل جدًا', Icons.warning_amber_rounded, _red),
    };

    return _buildCard(
      icon: Icons.flag_outlined,
      title: 'الأولوية',
      subtitle: 'محتاجه إمتى؟',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: options.entries.map((e) {
          final key = e.key;
          final (label, icon, color) = e.value;
          final selected = _urgency == key;

          return GestureDetector(
            onTap: () => setState(() => _urgency = key),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
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
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
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
      icon: Icons.location_on_outlined,
      title: 'الموقع',
      subtitle: 'عشان نساعدك تلاقي حد قريب منك',
      child: Column(
        children: [
          _buildField(
            controller: _cityController,
            label: 'المدينة',
            hint: 'مثال: طنطا',
            icon: Icons.location_city_rounded,
          ),
          const SizedBox(height: 12),
          _buildField(
            controller: _addressController,
            label: 'العنوان التفصيلي',
            hint: 'مثال: شارع البحر - بجوار...',
            icon: Icons.place_outlined,
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // CONTACT SECTION
  // ═══════════════════════════════════════════════════════════

  Widget _buildContactSection() {
    return _buildCard(
      icon: Icons.contact_phone_outlined,
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
          ),
          const SizedBox(height: 12),
          _buildField(
            controller: _whatsappController,
            label: 'رقم الواتساب',
            hint: 'مثال: 01012345678',
            icon: Icons.chat_rounded,
            required: true,
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
                  Icons.info_outline_rounded,
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _orange.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _orange.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: _orange,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ملاحظة مهمة',
                  style: TextStyle(
                    color: _orange,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '• الاحتياج هيظهر لمدة 7 أيام وبعدها ينتهي تلقائيًا.\n'
                  '• هتقدر تشوف كام واحد تواصل معاك.\n'
                  '• الحد الأقصى 5 احتياجات في اليوم.',
                  style: TextStyle(
                    color: _orange.withValues(alpha: 0.9),
                    fontSize: 11.5,
                    height: 1.6,
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

  // ═══════════════════════════════════════════════════════════
  // SUBMIT BUTTON
  // ═══════════════════════════════════════════════════════════

  Widget _buildSubmitButton() {
    final label = _isSubmitting
        ? (_isEditMode ? 'جاري التحديث...' : 'جاري النشر...')
        : (_isEditMode ? 'حفظ التعديلات' : 'نشر الاحتياج');

    return SizedBox(
      height: 56,
      child: FilledButton.icon(
        onPressed: _isSubmitting ? null : _submit,
        icon: _isSubmitting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Icon(
                _isEditMode ? Icons.check_rounded : Icons.publish_rounded,
              ),
        label: Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w900,
          ),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: _green,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE8F1EC)),
        boxShadow: [
          BoxShadow(
            color: _darkGreen.withValues(alpha: 0.04),
            blurRadius: 12,
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
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: _green, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: _darkGreen,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFF71837C),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
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
    int? minLength,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: numeric
          ? TextInputType.number
          : (label.contains('هاتف') || label.contains('واتساب')
              ? TextInputType.phone
              : TextInputType.text),
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: _green, size: 20),
        filled: true,
        fillColor: const Color(0xFFF8FBF9),
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
          borderSide: const BorderSide(color: _green, width: 1.5),
        ),
      ),
      validator: (value) {
        if (required && (value == null || value.trim().isEmpty)) {
          return 'هذا الحقل مطلوب';
        }
        if (minLength != null && value != null && value.trim().isNotEmpty) {
          if (value.trim().length < minLength) {
            return 'الحد الأدنى $minLength أحرف';
          }
        }
        if (numeric && value != null && value.trim().isNotEmpty) {
          final parsed = int.tryParse(value.trim());
          if (parsed == null || parsed <= 0) {
            return 'أدخل رقم صحيح أكبر من صفر';
          }
        }
        if ((label.contains('هاتف') || label.contains('واتساب')) &&
            value != null &&
            value.trim().isNotEmpty) {
          final clean = value.trim().replaceAll(RegExp(r'[^\d]'), '');
          if (clean.length < 10 || clean.length > 15) {
            return 'أدخل رقم صحيح (10-15 رقم)';
          }
        }
        return null;
      },
    );
  }

  // ═══════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════

  void _message(String text, {bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text, textDirection: TextDirection.rtl),
        backgroundColor: success ? _green : _red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}
