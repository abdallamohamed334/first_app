import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:loqma/features/community/presentation/pages/community_charities_page.dart';
import 'package:loqma/features/community/presentation/pages/community_charity_option.dart';
import 'package:loqma/core/errors/app_error_mapper.dart';
import 'package:loqma/features/charity/data/repositories/charity_donation_repository_separate.dart';

class AddCharityDonationPage extends StatefulWidget {
  const AddCharityDonationPage({super.key});

  @override
  State<AddCharityDonationPage> createState() => _AddCharityDonationPageState();
}

class _AddCharityDonationPageState extends State<AddCharityDonationPage> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _quantity = TextEditingController(text: '1');
  final _address = TextEditingController();
  final _phone = TextEditingController();
  final _notes = TextEditingController();
  final _repository = SeparateCharityDonationRepository();
  final _picker = ImagePicker();
  final List<XFile> _images = [];

  CommunityCharityOption? _charity;
  String _category = 'clothing';
  String _condition = 'good';
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _quantity.dispose();
    _address.dispose();
    _phone.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _chooseCharity() async {
    final selected = await Navigator.push<CommunityCharityOption>(
      context,
      MaterialPageRoute(builder: (_) => const CommunityCharitiesPage()),
    );
    if (selected != null && mounted) setState(() => _charity = selected);
  }

  Future<void> _pickImages() async {
    final picked = await _picker.pickMultiImage(
      imageQuality: 82,
      maxWidth: 1600,
      maxHeight: 1600,
    );
    if (!mounted || picked.isEmpty) return;
    setState(() => _images.addAll(picked.take(6 - _images.length)));
  }

  Future<void> _takePhoto() async {
    if (_images.length >= 6) return;
    final photo = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 82,
      maxWidth: 1600,
      maxHeight: 1600,
    );
    if (!mounted || photo == null) return;
    setState(() => _images.add(photo));
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_charity == null) {
      _message('اختر الجمعية التي سيصل إليها التبرع');
      return;
    }
    if (_images.isEmpty) {
      _message('أضف صورة واحدة على الأقل للتبرع');
      return;
    }
    setState(() => _busy = true);
    try {
      final imageUrls = await _repository.uploadDonationImages(_images);
      await _repository.createDonation(
        charityId: _charity!.id,
        title: _title.text,
        description: _description.text,
        category: _category,
        quantity: int.tryParse(_quantity.text) ?? 1,
        condition: _condition,
        pickupAddress: _address.text,
        donorPhone: _phone.text,
        donorNotes: _notes.text,
        images: imageUrls,
      );
      if (!mounted) return;
      _message('تم إرسال التبرع للجمعية بنجاح', success: true);
      Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        final raw = error.toString().toLowerCase();
        final message = raw.contains('row-level security') ||
                raw.contains('permission denied') ||
                raw.contains('not authorized') ||
                raw.contains('42501')
            ? 'لا توجد صلاحية لرفع الصور أو إرسال التبرع. شغّل ملف صلاحيات التبرع في Supabase ثم حاول مرة أخرى.'
            : AppErrorMapper.message(error,
                fallback: 'تعذر إرسال التبرع. حاول مرة أخرى.');
        _message(message);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _message(String text, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(text),
          backgroundColor:
              success ? const Color(0xFF0B7650) : const Color(0xFFB54747)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar:
            AppBar(title: const Text('إضافة تبرع لجمعية'), centerTitle: true),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(18),
            children: [
              _imageCard(),
              const SizedBox(height: 16),
              _charityCard(),
              const SizedBox(height: 16),
              _field(_title, 'عنوان التبرع', 'مثال: ملابس شتوية',
                  required: true),
              const SizedBox(height: 12),
              _field(_description, 'وصف التبرع', 'اكتب التفاصيل والحالة',
                  maxLines: 3, required: true),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                    child: _dropdown(
                        'النوع',
                        _category,
                        {'clothing': 'ملابس', 'furniture': 'أثاث'},
                        (v) => setState(() => _category = v!))),
                const SizedBox(width: 10),
                Expanded(
                    child: _field(_quantity, 'الكمية', '1',
                        keyboard: TextInputType.number, required: true)),
              ]),
              const SizedBox(height: 12),
              _dropdown(
                  'الحالة',
                  _condition,
                  {
                    'new': 'جديد',
                    'very_good': 'جيد جدًا',
                    'good': 'جيد',
                    'needs_repair': 'يحتاج إصلاح'
                  },
                  (v) => setState(() => _condition = v!)),
              const SizedBox(height: 12),
              _field(_address, 'عنوان استلام التبرع', 'العنوان بالتفصيل',
                  maxLines: 2, required: true),
              const SizedBox(height: 12),
              _field(_phone, 'رقم هاتف المتبرع', '01xxxxxxxxx',
                  keyboard: TextInputType.phone, required: true),
              const SizedBox(height: 12),
              _field(_notes, 'ملاحظات للجمعية', 'اختياري', maxLines: 2),
              const SizedBox(height: 22),
              FilledButton.icon(
                onPressed: _busy ? null : _submit,
                icon: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.volunteer_activism_rounded),
                label: Text(_busy ? 'جاري الإرسال...' : 'إرسال التبرع للجمعية'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _imageCard() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFDDEAE3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [
              Icon(Icons.photo_library_outlined, color: Color(0xFF0B7650)),
              SizedBox(width: 8),
              Text('صور التبرع',
                  style: TextStyle(
                      fontWeight: FontWeight.w900, color: Color(0xFF123F31))),
            ]),
            const SizedBox(height: 6),
            const Text('أضف صورًا واضحة تساعد الجمعية على مراجعة التبرع.',
                style: TextStyle(fontSize: 12, color: Colors.black54)),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                  child: OutlinedButton.icon(
                      onPressed: _images.length >= 6 ? null : _pickImages,
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('من المعرض'))),
              const SizedBox(width: 8),
              Expanded(
                  child: OutlinedButton.icon(
                      onPressed: _images.length >= 6 ? null : _takePhoto,
                      icon: const Icon(Icons.camera_alt_outlined),
                      label: const Text('الكاميرا'))),
            ]),
            if (_images.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 92,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _images.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, index) => Stack(children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(File(_images[index].path),
                          width: 92, height: 92, fit: BoxFit.cover),
                    ),
                    Positioned(
                      top: 3,
                      right: 3,
                      child: GestureDetector(
                        onTap: () => setState(() => _images.removeAt(index)),
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                              color: Colors.white, shape: BoxShape.circle),
                          child: const Icon(Icons.close,
                              size: 16, color: Colors.red),
                        ),
                      ),
                    ),
                  ]),
                ),
              ),
            ],
          ],
        ),
      );

  Widget _charityCard() => InkWell(
        onTap: _chooseCharity,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: const Color(0xFFE8F5EE),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFB8DDC8))),
          child: Row(children: [
            const Icon(Icons.volunteer_activism_rounded,
                color: Color(0xFF0B7650), size: 32),
            const SizedBox(width: 12),
            Expanded(
                child: Text(_charity?.name ?? 'اختر الجمعية المستفيدة',
                    style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF123F31)))),
            const Icon(Icons.arrow_back_ios_new_rounded, size: 16),
          ]),
        ),
      );

  Widget _field(TextEditingController controller, String label, String hint,
          {bool required = false, int maxLines = 1, TextInputType? keyboard}) =>
      TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboard,
        decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            border: const OutlineInputBorder()),
        validator: required
            ? (value) =>
                value == null || value.trim().isEmpty ? 'هذا الحقل مطلوب' : null
            : null,
      );

  Widget _dropdown(String label, String value, Map<String, String> items,
          ValueChanged<String?> onChanged) =>
      DropdownButtonFormField<String>(
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(
            labelText: label, border: const OutlineInputBorder()),
        items: items.entries
            .map((e) => DropdownMenuItem(
                value: e.key,
                child: Text(e.value, overflow: TextOverflow.ellipsis)))
            .toList(),
        onChanged: onChanged,
      );
}
