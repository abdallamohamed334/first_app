// lib/features/institutions/presentation/pages/institution_add_donation_page.dart

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/repositories/institutions_repository.dart';

class InstitutionAddDonationPage extends StatefulWidget {
  final String institutionId;

  const InstitutionAddDonationPage({super.key, required this.institutionId});

  @override
  State<InstitutionAddDonationPage> createState() =>
      _InstitutionAddDonationPageState();
}

class _InstitutionAddDonationPageState
    extends State<InstitutionAddDonationPage> {
  // ─── ألوان هوية وِصلة ───
  static const Color _primary = Color(0xFF0B7650);
  static const Color _primaryLight = Color(0xFF25B77C);
  static const Color _primaryDark = Color(0xFF054D34);
  static const Color _cream = Color(0xFFF7FAF8);
  static const Color _ink = Color(0xFF0F2E23);
  static const Color _inkSoft = Color(0xFF61756D);
  static const Color _gold = Color(0xFFD4A843);
  static const Color _orange = Color(0xFFE28B00);
  static const Color _purple = Color(0xFF7B5EC7);
  static const Color _red = Color(0xFFDC4C4C);

  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _quantityController = TextEditingController();
  final _conditionController = TextEditingController();
  final _searchController = TextEditingController();
  final _repository = InstitutionsRepository();
  final _picker = ImagePicker();
  final List<Uint8List> _images = [];

  late Future<List<Map<String, dynamic>>> _charitiesFuture;
  String? _charityId;
  String _searchQuery = '';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _charitiesFuture = _repository.listActiveCharities();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _quantityController.dispose();
    _conditionController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    try {
      final files = await _picker.pickMultiImage(
        imageQuality: 82,
        maxWidth: 1600,
      );
      if (files.isEmpty) return;

      final remaining = 6 - _images.length;
      final picked = <Uint8List>[];
      for (final file in files.take(remaining)) {
        picked.add(await file.readAsBytes());
      }

      if (!mounted) return;
      setState(() => _images.addAll(picked));
    } catch (_) {
      if (mounted) _showError('تعذر اختيار الصور. حاول مرة أخرى');
    }
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    if (_charityId == null) {
      _showError('اختر الجمعية المستفيدة أولًا');
      return;
    }

    final quantity = int.tryParse(_quantityController.text.trim());
    if (quantity == null || quantity <= 0) {
      _showError('اكتب كمية صحيحة أكبر من صفر');
      return;
    }

    setState(() => _saving = true);
    try {
      final imageUrls = <String>[];
      for (final image in _images) {
        imageUrls.add(await _repository.uploadInstitutionImage(
          bytes: image,
          fileExtension: 'jpg',
        ));
      }

      await _repository.createCharityDonation(
        institutionId: widget.institutionId,
        charityId: _charityId!,
        itemTitle: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        quantity: quantity,
        itemCondition: _conditionController.text.trim(),
        images: imageUrls,
      );

      if (!mounted) return;
      _showSuccess('✅ تم إرسال التبرع للجمعية بنجاح');
      Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        _showError('تعذر إرسال التبرع. راجع البيانات وحاول مرة أخرى');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: _red,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          content: Text(
            message,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: _primary,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          content: Text(
            message,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _cream,
        body: FutureBuilder<List<Map<String, dynamic>>>(
          future: _charitiesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: _primary),
              );
            }
            if (snapshot.hasError) {
              return _buildErrorView();
            }
            return _buildForm(snapshot.data ?? const []);
          },
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // FORM
  // ═══════════════════════════════════════════════════════════
  Widget _buildForm(List<Map<String, dynamic>> charities) {
    return Form(
      key: _formKey,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ═══════════════════════════════════════════════
          // APP BAR
          // ═══════════════════════════════════════════════
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            stretch: true,
            backgroundColor: _purple,
            foregroundColor: Colors.white,
            elevation: 0,
            scrolledUnderElevation: 0,
            leading: IconButton(
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_forward_rounded, size: 22),
              tooltip: 'رجوع',
            ),
            flexibleSpace: FlexibleSpaceBar(
              stretchModes: const [StretchMode.zoomBackground],
              background: _buildHeroHeader(),
            ),
          ),

          // ═══════════════════════════════════════════════
          // CONTENT
          // ═══════════════════════════════════════════════
          SliverToBoxAdapter(
            child: Transform.translate(
              offset: const Offset(0, -28),
              child: Container(
                decoration: const BoxDecoration(
                  color: _cream,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(32),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x14000000),
                      blurRadius: 24,
                      offset: Offset(0, -8),
                    ),
                  ],
                ),
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Handle
                    Center(
                      child: Container(
                        width: 44,
                        height: 5,
                        margin: const EdgeInsets.only(bottom: 22),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: .08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),

                    // ── Section 1: تفاصيل التبرع
                    _sectionCard(
                      icon: Icons.inventory_2_rounded,
                      iconColor: _primary,
                      title: 'تفاصيل التبرع',
                      subtitle: 'اكتب تفاصيل المنتجات اللي هتتبرع بيها',
                      child: Column(
                        children: [
                          _buildField(
                            controller: _titleController,
                            label: 'اسم التبرع',
                            hint: 'مثال: خبز طازج، معجنات مشكلة...',
                            icon: Icons.inventory_2_outlined,
                          ),
                          const SizedBox(height: 12),
                          _buildField(
                            controller: _descriptionController,
                            label: 'وصف التبرع',
                            hint: 'اكتب وصف تفصيلي للمنتجات وحالتها...',
                            icon: Icons.notes_outlined,
                            maxLines: 4,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _buildField(
                                  controller: _quantityController,
                                  label: 'الكمية',
                                  hint: '0',
                                  icon: Icons.numbers_outlined,
                                  numeric: true,
                                  suffix: 'وحدة',
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _buildField(
                                  controller: _conditionController,
                                  label: 'الحالة',
                                  hint: 'طازجة...',
                                  icon: Icons.fact_check_outlined,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── Section 2: الصور
                    _sectionCard(
                      icon: Icons.photo_library_rounded,
                      iconColor: _gold,
                      title: 'صور التبرع',
                      subtitle: 'اختياري · بحد أقصى 6 صور',
                      trailing: _images.isEmpty
                          ? null
                          : Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${_images.length}/6',
                                style: const TextStyle(
                                  color: _primary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                      child: _ImageUploadCard(
                        images: _images,
                        onPick: _saving ? null : _pickImages,
                        onRemove: _saving
                            ? null
                            : (index) =>
                                setState(() => _images.removeAt(index)),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── Section 3: الجمعيات
                    _sectionCard(
                      icon: Icons.volunteer_activism_rounded,
                      iconColor: _purple,
                      title: 'اختيار الجمعية',
                      subtitle: 'اختار جمعية موثقة ونشطة لاستقبال التبرع',
                      child: _buildCharitiesSection(charities),
                    ),

                    const SizedBox(height: 24),

                    // ── Submit Button
                    _buildSubmitButton(),
                  ],
                ),
              ),
            ),
          ),
        ],
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
          colors: [Color(0xFF3E2E6E), _purple, Color(0xFFA28FDB)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
      ),
      child: Stack(
        children: [
          // ── دوائر زخرفية
          Positioned(
            top: -60,
            left: -40,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          Positioned(
            bottom: -70,
            right: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.04),
              ),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 60, 20, 50),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                    ),
                    child: const Icon(
                      Icons.volunteer_activism_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'تبرع لجمعية',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'ساهم بفائض مؤسستك للجمعيات الموثوقة',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
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
  // SECTION CARD
  // ═══════════════════════════════════════════════════════════
  Widget _sectionCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required Widget child,
    Widget? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFEEF3F0)),
        boxShadow: [
          BoxShadow(
            color: _ink.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      iconColor,
                      iconColor.withValues(alpha: 0.75),
                    ],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                  borderRadius: BorderRadius.circular(13),
                  boxShadow: [
                    BoxShadow(
                      color: iconColor.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: _inkSoft,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // CHARITIES SECTION
  // ═══════════════════════════════════════════════════════════
  Widget _buildCharitiesSection(List<Map<String, dynamic>> charities) {
    final query = _searchQuery.trim().toLowerCase();
    final filtered = charities.where((charity) {
      if (query.isEmpty) return true;
      final name = (charity['name'] ?? '').toString().toLowerCase();
      final location = (charity['city'] ?? charity['address'] ?? '')
          .toString()
          .toLowerCase();
      return name.contains(query) || location.contains(query);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Search field
        Container(
          height: 48,
          decoration: BoxDecoration(
            color: _cream,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFEEF3F0)),
          ),
          child: TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _searchQuery = value),
            style: const TextStyle(
              color: _ink,
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              hintText: 'ابحث باسم الجمعية أو المدينة...',
              hintStyle: TextStyle(
                color: _inkSoft.withValues(alpha: 0.6),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: _primary,
                size: 20,
              ),
              suffixIcon: _searchQuery.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                      icon: const Icon(Icons.close_rounded, size: 18),
                    ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        const SizedBox(height: 14),

        // ── List
        if (filtered.isEmpty)
          _buildEmptyCharities()
        else
          ...filtered.map(
            (charity) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _CharityCard(
                charity: charity,
                selected: _charityId == charity['id']?.toString(),
                onTap: _saving
                    ? null
                    : () => setState(
                          () => _charityId = charity['id']?.toString(),
                        ),
              ),
            ),
          ),

        // ── Hint if not selected
        if (_charityId == null && filtered.isNotEmpty) ...[
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _orange.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _orange.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  color: _orange,
                  size: 14,
                ),
                const SizedBox(width: 6),
                Text(
                  'اختيار الجمعية مطلوب قبل الإرسال',
                  style: TextStyle(
                    color: _orange.withValues(alpha: 0.9),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildEmptyCharities() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _cream,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _purple.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.search_off_rounded,
              color: _purple,
              size: 28,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'لا توجد جمعيات مطابقة للبحث',
            style: TextStyle(
              color: _ink,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'جرب البحث باسم مختلف',
            style: TextStyle(color: _inkSoft, fontSize: 12),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // SUBMIT BUTTON
  // ═══════════════════════════════════════════════════════════
  Widget _buildSubmitButton() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: _primary.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 58,
        child: ElevatedButton(
          onPressed: _saving ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: _primary,
            foregroundColor: Colors.white,
            disabledBackgroundColor: _primary.withValues(alpha: 0.4),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_saving)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                )
              else
                const Icon(Icons.send_rounded, size: 22),
              const SizedBox(width: 10),
              Text(
                _saving ? 'جارٍ إرسال التبرع...' : 'إرسال التبرع للجمعية',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 15.5,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
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
    int maxLines = 1,
    bool numeric = false,
    String? suffix,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: numeric
          ? TextInputType.number
          : (maxLines > 1 ? TextInputType.multiline : TextInputType.text),
      textInputAction:
          maxLines > 1 ? TextInputAction.newline : TextInputAction.next,
      style: const TextStyle(
        color: _ink,
        fontSize: 14,
        fontWeight: FontWeight.w700,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(
          color: _inkSoft,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        hintStyle: TextStyle(
          color: _inkSoft.withValues(alpha: 0.5),
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        prefixIcon: Container(
          margin: const EdgeInsets.all(8),
          alignment: Alignment.center,
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: _primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: _primary, size: 16),
        ),
        suffixText: suffix,
        suffixStyle: const TextStyle(
          color: _inkSoft,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
        filled: true,
        fillColor: _cream,
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
          borderSide: const BorderSide(color: Color(0xFFEEF3F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _primary, width: 1.6),
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
        if (value == null || value.trim().isEmpty) return 'هذا الحقل مطلوب';
        if (numeric && int.tryParse(value.trim()) == null) {
          return 'اكتب رقم صحيح';
        }
        if (numeric) {
          final parsed = int.tryParse(value.trim());
          if (parsed != null && parsed <= 0) {
            return 'أدخل رقم أكبر من صفر';
          }
        }
        return null;
      },
    );
  }

  // ═══════════════════════════════════════════════════════════
  // ERROR VIEW
  // ═══════════════════════════════════════════════════════════
  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 90,
              height: 90,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _red.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.cloud_off_rounded,
                color: _red,
                size: 40,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'تعذر تحميل الجمعيات',
              style: TextStyle(
                color: _ink,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'تأكد من اتصال الإنترنت وحاول مرة أخرى',
              textAlign: TextAlign.center,
              style: TextStyle(color: _inkSoft, fontSize: 13),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => setState(() {
                _charitiesFuture = _repository.listActiveCharities();
              }),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text(
                'إعادة المحاولة',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: _primary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// IMAGE UPLOAD CARD
// ═══════════════════════════════════════════════════════════
class _ImageUploadCard extends StatelessWidget {
  final List<Uint8List> images;
  final VoidCallback? onPick;
  final ValueChanged<int>? onRemove;

  const _ImageUploadCard({
    required this.images,
    required this.onPick,
    required this.onRemove,
  });

  static const Color _primary = Color(0xFF0B7650);
  static const Color _primaryLight = Color(0xFF25B77C);
  static const Color _cream = Color(0xFFF7FAF8);
  static const Color _ink = Color(0xFF0F2E23);
  static const Color _inkSoft = Color(0xFF61756D);

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty) {
      return InkWell(
        onTap: onPick,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                _primary.withValues(alpha: 0.04),
                _primaryLight.withValues(alpha: 0.06),
              ],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: _primary.withValues(alpha: 0.2),
              width: 1.4,
            ),
          ),
          child: Column(
            children: [
              Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: _primary.withValues(alpha: 0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.add_a_photo_rounded,
                  color: _primary,
                  size: 26,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'اضغط لإضافة صور',
                style: TextStyle(
                  color: _ink,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'JPG أو PNG · بحد أقصى 6 صور',
                style: TextStyle(
                  color: _inkSoft,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: images.length + (images.length < 6 ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, index) {
          // ── زرار إضافة
          if (index == images.length) {
            return InkWell(
              onTap: onPick,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: 96,
                height: 96,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _primary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _primary.withValues(alpha: 0.3),
                    width: 1.4,
                    strokeAlign: BorderSide.strokeAlignInside,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_rounded,
                      color: _primary,
                      size: 26,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'إضافة',
                      style: TextStyle(
                        color: _primary,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          // ── صورة
          return Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.memory(
                  images[index],
                  width: 96,
                  height: 96,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                top: 5,
                right: 5,
                child: InkWell(
                  onTap: onRemove == null ? null : () => onRemove!(index),
                  child: Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// CHARITY CARD
// ═══════════════════════════════════════════════════════════
class _CharityCard extends StatelessWidget {
  final Map<String, dynamic> charity;
  final bool selected;
  final VoidCallback? onTap;

  const _CharityCard({
    required this.charity,
    required this.selected,
    required this.onTap,
  });

  static const Color _primary = Color(0xFF0B7650);
  static const Color _primaryLight = Color(0xFF25B77C);
  static const Color _cream = Color(0xFFF7FAF8);
  static const Color _ink = Color(0xFF0F2E23);
  static const Color _inkSoft = Color(0xFF61756D);
  static const Color _purple = Color(0xFF7B5EC7);

  @override
  Widget build(BuildContext context) {
    final name = (charity['name'] ?? 'جمعية موثوقة').toString();
    final city =
        (charity['city'] ?? charity['address'] ?? 'جمعية نشطة').toString();
    final logo =
        charity['logo_url'] ?? charity['image_url'] ?? charity['avatar_url'];

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: selected
                ? LinearGradient(
                    colors: [
                      _primary.withValues(alpha: 0.08),
                      _primaryLight.withValues(alpha: 0.04),
                    ],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  )
                : null,
            color: selected ? null : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected
                  ? _primary.withValues(alpha: 0.5)
                  : const Color(0xFFEEF3F0),
              width: selected ? 1.6 : 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: _primary.withValues(alpha: 0.12),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              // ── Logo
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: logo == null || logo.toString().trim().isEmpty
                      ? const LinearGradient(
                          colors: [_primary, _primaryLight],
                          begin: Alignment.topRight,
                          end: Alignment.bottomLeft,
                        )
                      : null,
                  color: logo != null && logo.toString().trim().isNotEmpty
                      ? Colors.white
                      : null,
                  borderRadius: BorderRadius.circular(16),
                  image: logo != null && logo.toString().trim().isNotEmpty
                      ? DecorationImage(
                          image: NetworkImage(logo.toString().trim()),
                          fit: BoxFit.cover,
                        )
                      : null,
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: _primary.withValues(alpha: 0.25),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: logo == null || logo.toString().trim().isEmpty
                    ? const Icon(
                        Icons.volunteer_activism_rounded,
                        color: Colors.white,
                        size: 26,
                      )
                    : null,
              ),
              const SizedBox(width: 14),

              // ── Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: selected ? _primary : _ink,
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const SizedBox(width: 5),
                        Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: _primary.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.verified_rounded,
                            color: _primary,
                            size: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_rounded,
                          size: 12,
                          color: _inkSoft.withValues(alpha: 0.7),
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            city,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _inkSoft,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ── Selection indicator
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? _primary : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color:
                        selected ? _primary : _inkSoft.withValues(alpha: 0.3),
                    width: 1.6,
                  ),
                ),
                child: selected
                    ? const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 16,
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
