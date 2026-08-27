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
  static const _primary = Color(0xFF00261A);
  static const _primaryContainer = Color(0xFF0F3D2E);
  static const _background = Color(0xFFF9FAF7);
  static const _surfaceLow = Color(0xFFF3F4F1);
  static const _outline = Color(0xFFC0C8C3);
  static const _muted = Color(0xFF66736D);
  static const _accent = Color(0xFFE8A356);

  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _quantityController = TextEditingController();
  final _priceController = TextEditingController();
  final _originalPriceController = TextEditingController();
  final _pickupLocationController = TextEditingController();
  final _pickupNotesController = TextEditingController();
  final _repository = InstitutionsRepository();
  final _picker = ImagePicker();
  final List<Uint8List> _images = [];

  DateTime _expiresAt = DateTime.now().add(const Duration(days: 2));
  bool _saving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    _originalPriceController.dispose();
    _pickupLocationController.dispose();
    _pickupNotesController.dispose();
    super.dispose();
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
      if (mounted)
        _showMessage('تعذر اختيار الصور. حاول مرة أخرى', error: true);
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

    setState(() => _saving = true);
    try {
      final imageUrls = <String>[];
      for (final bytes in _images) {
        imageUrls.add(await _repository.uploadInstitutionImage(
          bytes: bytes,
          fileExtension: 'jpg',
        ));
      }

      final location = _buildPickupLocation();
      await _repository.createNormalizedOffer(
        institutionId: widget.institutionId,
        title: _titleController.text,
        description: _descriptionController.text,
        category: 'other',
        quantity: quantity,
        symbolicPrice: symbolicPrice,
        originalPrice: originalPrice,
        images: imageUrls,
        pickupLocation: location,
        expiresAt: _expiresAt.toUtc(),
      );

      if (!mounted) return;
      _showMessage('تم نشر العرض بنجاح');
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      _showMessage(_friendlyError(error), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _buildPickupLocation() {
    final location = _pickupLocationController.text.trim();
    final notes = _pickupNotesController.text.trim();
    if (location.isEmpty) return notes;
    if (notes.isEmpty) return location;
    return '$location — ملاحظات: $notes';
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

  String _friendlyError(Object error) {
    if (error is FormatException) return error.message.toString();
    final text = error.toString().toLowerCase();
    if (text.contains('permission') || text.contains('row-level security')) {
      return 'ليس لديك صلاحية نشر العرض من هذا الحساب';
    }
    if (text.contains('network') || text.contains('socket')) {
      return 'تعذر الاتصال بالإنترنت. حاول مرة أخرى';
    }
    return 'تعذر نشر العرض الآن. راجع البيانات وحاول مرة أخرى';
  }

  void _showMessage(String message, {bool error = false}) {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message, textAlign: TextAlign.right),
          backgroundColor: error ? const Color(0xFF9B2C2C) : _primaryContainer,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 18),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          elevation: 0,
          centerTitle: false,
          leading: IconButton(
            tooltip: 'رجوع',
            onPressed: _saving ? null : () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_forward_rounded, color: _primary),
          ),
          title: const Text(
            'إضافة عرض بسعر رمزي',
            style: TextStyle(
              color: _primary,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(height: 1, color: _outline.withValues(alpha: .35)),
          ),
        ),
        body: SafeArea(
          bottom: false,
          child: Form(
            key: _formKey,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final horizontal = constraints.maxWidth >= 720 ? 32.0 : 16.0;
                return ListView(
                  padding: EdgeInsets.fromLTRB(horizontal, 24, horizontal, 34),
                  children: [
                    const _PageIntro(),
                    const SizedBox(height: 22),
                    _FormCard(
                      children: [
                        _SectionTitle(
                          title: 'صورة المنتج',
                          subtitle:
                              'أضف صورة واضحة تساعد العملاء على معرفة العرض',
                        ),
                        const SizedBox(height: 12),
                        _ImagePickerCard(
                          images: _images,
                          onPick: _saving ? null : _pickImages,
                          onRemove: (index) {
                            if (_saving) return;
                            setState(() => _images.removeAt(index));
                          },
                        ),
                        const _Divider(),
                        _SectionTitle(
                          title: 'بيانات العرض',
                          subtitle:
                              'اكتب المعلومات الأساسية التي ستظهر للعملاء',
                        ),
                        const SizedBox(height: 16),
                        _field(
                          controller: _titleController,
                          label: 'اسم العرض',
                          hint: 'مثال: سلة معجنات متنوعة',
                          icon: Icons.inventory_2_outlined,
                        ),
                        const SizedBox(height: 14),
                        _field(
                          controller: _descriptionController,
                          label: 'وصف قصير',
                          hint: 'اكتب محتويات العرض وحالته...',
                          icon: Icons.notes_outlined,
                          maxLines: 3,
                        ),
                        const SizedBox(height: 14),
                        LayoutBuilder(
                          builder: (context, inner) {
                            final twoColumns = inner.maxWidth >= 560;
                            final fields = [
                              _field(
                                controller: _priceController,
                                label: 'السعر الرمزي',
                                hint: '0.00',
                                icon: Icons.payments_outlined,
                                numeric: true,
                              ),
                              _field(
                                controller: _originalPriceController,
                                label: 'السعر الأصلي (اختياري)',
                                hint: '0.00',
                                icon: Icons.sell_outlined,
                                numeric: true,
                                requiredField: false,
                              ),
                              _field(
                                controller: _quantityController,
                                label: 'الكمية المتاحة',
                                hint: '1',
                                icon: Icons.layers_outlined,
                                numeric: true,
                              ),
                              _expiryField(),
                            ];
                            return twoColumns
                                ? Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(child: fields[0]),
                                      const SizedBox(width: 14),
                                      Expanded(child: fields[1]),
                                      const SizedBox(width: 14),
                                      Expanded(child: fields[2]),
                                      const SizedBox(width: 14),
                                      Expanded(child: fields[3]),
                                    ],
                                  )
                                : Column(
                                    children: fields
                                        .map((field) => Padding(
                                              padding: const EdgeInsets.only(
                                                  bottom: 14),
                                              child: field,
                                            ))
                                        .toList(),
                                  );
                          },
                        ),
                        const _Divider(),
                        _SectionTitle(
                          title: 'تفاصيل الاستلام',
                          subtitle: 'ساعد العميل على الوصول إلى الفرع بسهولة',
                        ),
                        const SizedBox(height: 16),
                        _field(
                          controller: _pickupLocationController,
                          label: 'موقع الاستلام أو اسم الفرع',
                          hint: 'مثال: فرع العليا',
                          icon: Icons.location_on_outlined,
                          requiredField: false,
                        ),
                        const SizedBox(height: 14),
                        _field(
                          controller: _pickupNotesController,
                          label: 'ملاحظات الاستلام (اختياري)',
                          hint: 'تعليمات إضافية للمستلم...',
                          icon: Icons.info_outline,
                          maxLines: 2,
                          requiredField: false,
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          height: 56,
                          child: FilledButton.icon(
                            onPressed: _saving ? null : _save,
                            style: FilledButton.styleFrom(
                              backgroundColor: _accent,
                              foregroundColor: const Color(0xFF2C1600),
                              disabledBackgroundColor:
                                  _accent.withValues(alpha: .55),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                            ),
                            icon: _saving
                                ? const SizedBox.square(
                                    dimension: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                      color: Color(0xFF2C1600),
                                    ),
                                  )
                                : const Icon(Icons.campaign_outlined),
                            label: Text(
                              _saving ? 'جارٍ نشر العرض...' : 'نشر العرض',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _field({
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
      decoration: _inputDecoration(label: label, hint: hint, icon: icon),
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

  Widget _expiryField() {
    return InkWell(
      onTap: _saving ? null : _chooseExpiryDate,
      borderRadius: BorderRadius.circular(14),
      child: InputDecorator(
        decoration: _inputDecoration(
          label: 'تاريخ انتهاء الصلاحية',
          hint: '',
          icon: Icons.event_outlined,
        ),
        child: Text(
          '${_expiresAt.day.toString().padLeft(2, '0')}/${_expiresAt.month.toString().padLeft(2, '0')}/${_expiresAt.year}',
          style: const TextStyle(color: _primary, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: _muted),
      filled: true,
      fillColor: _surfaceLow,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      labelStyle: const TextStyle(color: _muted),
      hintStyle: TextStyle(color: _muted.withValues(alpha: .75)),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _primary, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFBA1A1A)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFBA1A1A), width: 1.6),
      ),
    );
  }
}

class _PageIntro extends StatelessWidget {
  const _PageIntro();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'شارك فائضك بطريقة أفضل',
          style: TextStyle(
            color: Color(0xFF00261A),
            fontSize: 28,
            fontWeight: FontWeight.w800,
            height: 1.15,
          ),
        ),
        SizedBox(height: 7),
        Text(
          'أنشئ عرضًا بسعر رمزي ليصل إلى من يحتاجه بسهولة.',
          style: TextStyle(color: Color(0xFF66736D), fontSize: 14, height: 1.5),
        ),
      ],
    );
  }
}

class _FormCard extends StatelessWidget {
  final List<Widget> children;
  const _FormCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E3E0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D0F3D2E),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionTitle({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF00261A),
            fontSize: 19,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(color: Color(0xFF66736D), fontSize: 13),
        ),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Divider(color: const Color(0xFFC0C8C3).withValues(alpha: .45)),
      );
}

class _ImagePickerCard extends StatelessWidget {
  final List<Uint8List> images;
  final VoidCallback? onPick;
  final ValueChanged<int> onRemove;

  const _ImagePickerCard({
    required this.images,
    required this.onPick,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onPick,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: double.infinity,
            height: 150,
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF717974),
                width: 1.2,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.add_photo_alternate_outlined,
                  size: 38,
                  color: Color(0xFF66736D),
                ),
                const SizedBox(height: 8),
                Text(
                  images.isEmpty ? 'انقر لإضافة صور' : 'إضافة صور أخرى',
                  style: const TextStyle(
                    color: Color(0xFF414944),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${images.length}/6 صور',
                  style:
                      const TextStyle(color: Color(0xFF66736D), fontSize: 12),
                ),
              ],
            ),
          ),
        ),
        if (images.isNotEmpty) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 88,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: images.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, index) => Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(
                      images[index],
                      width: 88,
                      height: 88,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Material(
                      color: Colors.black54,
                      shape: const CircleBorder(),
                      child: InkWell(
                        onTap: () => onRemove(index),
                        customBorder: const CircleBorder(),
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child:
                              Icon(Icons.close, size: 14, color: Colors.white),
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
    );
  }
}
