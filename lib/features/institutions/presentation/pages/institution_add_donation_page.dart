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
  static const primary = Color(0xFF00261A);
  static const forest = Color(0xFF0F3D2E);
  static const secondary = Color(0xFF7D562D);
  static const background = Color(0xFFF9FAF7);
  static const surfaceLow = Color(0xFFF3F4F1);
  static const outline = Color(0xFFC0C8C3);
  static const muted = Color(0xFF66736D);

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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('تم إرسال التبرع للجمعية بنجاح'),
        ),
      );
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF7B1E1E),
        content: Text(message),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: background,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: background,
          surfaceTintColor: Colors.transparent,
          leading: IconButton(
            tooltip: 'رجوع',
            icon: const Icon(Icons.arrow_forward_rounded, color: primary),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          title: const Text(
            'إضافة تبرع لجمعية',
            style: TextStyle(
              color: primary,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          centerTitle: true,
        ),
        body: FutureBuilder<List<Map<String, dynamic>>>(
          future: _charitiesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: forest),
              );
            }
            if (snapshot.hasError) {
              return _FailureView(
                message: 'تعذر تحميل الجمعيات حاليًا',
                onRetry: () => setState(() {
                  _charitiesFuture = _repository.listActiveCharities();
                }),
              );
            }

            return _DonationForm(
              charities: snapshot.data ?? const <Map<String, dynamic>>[],
            );
          },
        ),
      ),
    );
  }

  Widget _DonationForm({required List<Map<String, dynamic>> charities}) {
    final query = _searchQuery.trim().toLowerCase();
    final filtered = charities.where((charity) {
      if (query.isEmpty) return true;
      final name = (charity['name'] ?? '').toString().toLowerCase();
      final location = (charity['city'] ?? charity['address'] ?? '')
          .toString()
          .toLowerCase();
      return name.contains(query) || location.contains(query);
    }).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 780;
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            wide ? 36 : 16,
            10,
            wide ? 36 : 16,
            36,
          ),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Container(
                padding: EdgeInsets.all(wide ? 30 : 18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: outline.withValues(alpha: .45)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0D0F3D2E),
                      blurRadius: 18,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _SectionTitle(
                        title: 'تفاصيل التبرع',
                        subtitle:
                            'اكتب تفاصيل المنتجات التي تريد تقديمها للجمعية',
                      ),
                      const SizedBox(height: 16),
                      _Field(
                        controller: _titleController,
                        label: 'اسم التبرع',
                        hint: 'مثال: خبز طازج، معجنات مشكلة...',
                        icon: Icons.inventory_2_outlined,
                      ),
                      const SizedBox(height: 12),
                      _Field(
                        controller: _descriptionController,
                        label: 'وصف التبرع',
                        hint: 'اكتب وصفًا تفصيليًا للمنتجات وحالتها...',
                        icon: Icons.notes_outlined,
                        maxLines: 4,
                      ),
                      const SizedBox(height: 12),
                      if (wide)
                        Row(
                          children: [
                            Expanded(child: _quantityField()),
                            const SizedBox(width: 12),
                            Expanded(child: _conditionField()),
                          ],
                        )
                      else ...[
                        _quantityField(),
                        const SizedBox(height: 12),
                        _conditionField(),
                      ],
                      const SizedBox(height: 20),
                      _ImageUploadCard(
                        images: _images,
                        onPick: _saving ? null : _pickImages,
                        onRemove: _saving
                            ? null
                            : (index) =>
                                setState(() => _images.removeAt(index)),
                      ),
                      const SizedBox(height: 28),
                      const Divider(color: outline),
                      const SizedBox(height: 24),
                      const _SectionTitle(
                        title: 'اختيار الجمعية',
                        subtitle: 'اختر جمعية موثقة ونشطة لاستقبال التبرع',
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _searchController,
                        onChanged: (value) =>
                            setState(() => _searchQuery = value),
                        decoration: _decoration(
                          label: 'البحث عن جمعية',
                          hint: 'ابحث باسم الجمعية أو المدينة...',
                          icon: Icons.search_rounded,
                        ),
                      ),
                      const SizedBox(height: 14),
                      if (filtered.isEmpty)
                        const _EmptyCharities()
                      else
                        ...filtered.map(
                          (charity) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _CharityCard(
                              charity: charity,
                              selected: _charityId == charity['id']?.toString(),
                              onTap: _saving
                                  ? null
                                  : () => setState(() =>
                                      _charityId = charity['id']?.toString()),
                            ),
                          ),
                        ),
                      if (_charityId == null && filtered.isNotEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: Text(
                            'اختيار الجمعية مطلوب قبل الإرسال',
                            style: TextStyle(color: muted, fontSize: 12),
                          ),
                        ),
                      const SizedBox(height: 28),
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: FilledButton.icon(
                          onPressed: _saving ? null : _save,
                          style: FilledButton.styleFrom(
                            backgroundColor: primary,
                            disabledBackgroundColor:
                                primary.withValues(alpha: .35),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          icon: _saving
                              ? const SizedBox.square(
                                  dimension: 19,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.send_rounded),
                          label: Text(
                            _saving
                                ? 'جارٍ إرسال التبرع...'
                                : 'إرسال التبرع للجمعية',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _quantityField() => _Field(
        controller: _quantityController,
        label: 'الكمية التقريبية',
        hint: '0',
        icon: Icons.numbers_outlined,
        numeric: true,
        suffix: 'وحدة',
      );

  Widget _conditionField() => _Field(
        controller: _conditionController,
        label: 'حالة المنتجات',
        hint: 'طازجة أو صالحة للاستهلاك...',
        icon: Icons.fact_check_outlined,
      );

  static InputDecoration _decoration({
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: const Icon(Icons.search_rounded, color: muted),
      filled: true,
      fillColor: surfaceLow,
      labelStyle: const TextStyle(color: muted),
      hintStyle: const TextStyle(color: Color(0x99818C86), fontSize: 13),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: primary, width: 1.5),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;
  const _SectionTitle({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  color: Color(0xFF00261A),
                  fontSize: 24,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(subtitle,
              style: const TextStyle(color: Color(0xFF66736D), fontSize: 13)),
        ],
      );
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final int maxLines;
  final bool numeric;
  final String? suffix;

  const _Field({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.maxLines = 1,
    this.numeric = false,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) => TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: numeric
            ? TextInputType.number
            : (maxLines > 1 ? TextInputType.multiline : TextInputType.text),
        textInputAction:
            maxLines > 1 ? TextInputAction.newline : TextInputAction.next,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, color: const Color(0xFF66736D)),
          suffixText: suffix,
          filled: true,
          fillColor: const Color(0xFFF3F4F1),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFC0C8C3)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFC0C8C3)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF00261A), width: 1.5),
          ),
        ),
        validator: (value) {
          if (value == null || value.trim().isEmpty) return 'هذا الحقل مطلوب';
          if (numeric && int.tryParse(value.trim()) == null) {
            return 'اكتب رقمًا صحيحًا';
          }
          return null;
        },
      );
}

class _ImageUploadCard extends StatelessWidget {
  final List<Uint8List> images;
  final VoidCallback? onPick;
  final ValueChanged<int>? onRemove;
  const _ImageUploadCard({
    required this.images,
    required this.onPick,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('صور التبرع (اختياري)',
              style: TextStyle(
                  color: Color(0xFF00261A), fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          InkWell(
            onTap: onPick,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 25, horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFC0C8C3), width: 1.4),
              ),
              child: Column(
                children: [
                  const Icon(Icons.add_a_photo_outlined,
                      size: 34, color: Color(0xFF66736D)),
                  const SizedBox(height: 8),
                  Text(
                      images.isEmpty
                          ? 'اضغط هنا لإضافة صور للتبرع'
                          : 'إضافة صور أخرى',
                      style: const TextStyle(
                          color: Color(0xFF414944),
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  const Text('JPG أو PNG · بحد أقصى 6 صور',
                      style: TextStyle(color: Color(0xFF89948E), fontSize: 12)),
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
                      child: Image.memory(images[index],
                          width: 88, height: 88, fit: BoxFit.cover),
                    ),
                    if (onRemove != null)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: InkWell(
                          onTap: () => onRemove!(index),
                          child: const CircleAvatar(
                            radius: 12,
                            backgroundColor: Colors.black54,
                            child: Icon(Icons.close_rounded,
                                size: 15, color: Colors.white),
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

class _CharityCard extends StatelessWidget {
  final Map<String, dynamic> charity;
  final bool selected;
  final VoidCallback? onTap;
  const _CharityCard({
    required this.charity,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final name = (charity['name'] ?? 'جمعية موثوقة').toString();
    final city =
        (charity['city'] ?? charity['address'] ?? 'جمعية نشطة').toString();
    final logo =
        charity['logo_url'] ?? charity['image_url'] ?? charity['avatar_url'];

    return Material(
      color: selected ? const Color(0xFFF0F8F3) : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color:
                  selected ? const Color(0xFF00261A) : const Color(0xFFC0C8C3),
              width: selected ? 1.7 : 1,
            ),
          ),
          child: Row(
            children: [
              _CharityLogo(url: logo?.toString(), selected: selected),
              const SizedBox(width: 12),
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
                            style: const TextStyle(
                                color: Color(0xFF00261A),
                                fontWeight: FontWeight.w800),
                          ),
                        ),
                        const SizedBox(width: 5),
                        const Icon(Icons.verified_rounded,
                            color: Color(0xFF2D7656), size: 17),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(city,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Color(0xFF66736D), fontSize: 12)),
                  ],
                ),
              ),
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: selected
                    ? const Color(0xFF00261A)
                    : const Color(0xFFA1ABA5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CharityLogo extends StatelessWidget {
  final String? url;
  final bool selected;
  const _CharityLogo({required this.url, required this.selected});

  @override
  Widget build(BuildContext context) => Container(
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          color: const Color(0xFFDDEBE4),
          borderRadius: BorderRadius.circular(14),
          image: url != null && url!.trim().isNotEmpty
              ? DecorationImage(
                  image: NetworkImage(url!.trim()), fit: BoxFit.cover)
              : null,
        ),
        child: url == null || url!.trim().isEmpty
            ? Icon(Icons.volunteer_activism_rounded,
                color: selected
                    ? const Color(0xFF00261A)
                    : const Color(0xFF2D7656))
            : null,
      );
}

class _EmptyCharities extends StatelessWidget {
  const _EmptyCharities();
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
            color: const Color(0xFFF3F4F1),
            borderRadius: BorderRadius.circular(16)),
        child: const Center(
            child: Text('لا توجد جمعيات مطابقة للبحث',
                style: TextStyle(color: Color(0xFF66736D)))),
      );
}

class _FailureView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _FailureView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded,
                  size: 52, color: Color(0xFF66736D)),
              const SizedBox(height: 12),
              Text(message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Color(0xFF00261A), fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('إعادة المحاولة')),
            ],
          ),
        ),
      );
}
