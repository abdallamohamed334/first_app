// lib/features/community/presentation/pages/add_community_offer_page.dart

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:loqma/features/community/data/repositories/community_offer_repository.dart';
import 'package:loqma/features/community/presentation/pages/community_charities_page.dart';
import 'package:loqma/features/community/presentation/pages/community_charity_option.dart';

/// UI-only first step for regular users.
/// The submit callback returns a draft map; Supabase persistence will be added next.
class AddCommunityOfferPage extends StatefulWidget {
  final Future<void> Function(Map<String, dynamic> draft)? onSubmit;
  final List<CommunityCharityOption> charities;

  const AddCommunityOfferPage({
    super.key,
    this.onSubmit,
    this.charities = const [],
  });

  @override
  State<AddCommunityOfferPage> createState() => _AddCommunityOfferPageState();
}

class _AddCommunityOfferPageState extends State<AddCommunityOfferPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  final _priceController = TextEditingController();
  final _locationController = TextEditingController();
  final _picker = ImagePicker();

  String _listingType = 'charity_donation';
  String _category = 'clothing';
  String _condition = 'good';
  String? _charityId;
  final List<XFile> _images = [];
  bool _isSubmitting = false;
  bool _isLoadingCharities = false;
  List<CommunityCharityOption> _availableCharities = const [];

  static const _green = Color(0xFF0B7650);
  static const _darkGreen = Color(0xFF123F31);
  static const _background = Color(0xFFF6FAF8);
  static const _orange = Color(0xFFE08B32);

  @override
  void initState() {
    super.initState();
    _availableCharities = List<CommunityCharityOption>.from(widget.charities);
    _loadActiveCharities();
  }

  Future<void> _loadActiveCharities() async {
    if (widget.charities.isNotEmpty) return;
    setState(() => _isLoadingCharities = true);
    try {
      final rows = await CommunityOfferRepository().getActiveCharities();
      if (!mounted) return;
      setState(() {
        _availableCharities = rows
            .map(CommunityCharityOption.fromMap)
            .where((item) => item.id.isNotEmpty)
            .toList();
      });
    } catch (_) {
      if (mounted) {
        _showMessage('تعذر تحميل الجمعيات المتاحة. حاول مرة أخرى.');
      }
    } finally {
      if (mounted) setState(() => _isLoadingCharities = false);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    if (_images.length >= 6) {
      _showMessage('يمكنك إضافة 6 صور كحد أقصى');
      return;
    }
    try {
      final picked = await _picker.pickMultiImage(
        imageQuality: 82,
        maxWidth: 1600,
      );
      if (!mounted || picked.isEmpty) return;
      setState(() {
        _images.addAll(picked.take(6 - _images.length));
      });
    } catch (_) {
      if (mounted) _showMessage('تعذر اختيار الصور، حاول مرة أخرى');
    }
  }

  void _removeImage(int index) {
    if (!mounted || index < 0 || index >= _images.length) return;
    setState(() => _images.removeAt(index));
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    if (_listingType == 'charity_donation' && _charityId == null) {
      _showMessage('اختار الجمعية التي تريد توجيه التبرع إليها');
      return;
    }
    if (_images.isEmpty) {
      _showMessage('أضف صورة واحدة على الأقل للعرض');
      return;
    }

    final draft = <String, dynamic>{
      'title': _titleController.text.trim(),
      'description': _descriptionController.text.trim(),
      'category': _category,
      'listing_type': _listingType,
      'item_condition': _condition,
      'quantity': int.tryParse(_quantityController.text.trim()) ?? 1,
      'price': _listingType == 'symbolic_sale'
          ? double.tryParse(_priceController.text.trim()) ?? 0
          : 0,
      'charity_id': _charityId,
      'pickup_location': _locationController.text.trim(),
      'local_images': _images.map((image) => image.path).toList(),
    };

    setState(() => _isSubmitting = true);
    try {
      if (widget.onSubmit != null) {
        await widget.onSubmit!(draft);
      } else {
        await CommunityOfferRepository().createOffer(
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          category: _category,
          listingType: _listingType,
          itemCondition: _condition,
          quantity: int.tryParse(_quantityController.text.trim()) ?? 1,
          price: _listingType == 'symbolic_sale'
              ? double.tryParse(_priceController.text.trim()) ?? 0
              : 0,
          pickupLocation: _locationController.text.trim(),
          images: _images,
          charityId: _charityId,
        );
      }
      if (!mounted) return;
      _showMessage('تم تجهيز العرض للمراجعة بنجاح', success: true);
      Navigator.pop(context, draft);
    } catch (error) {
      if (mounted) _showMessage(_friendlyError(error));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String _friendlyError(Object error) {
    final text = error.toString().toLowerCase();
    if (text.contains('permission') || text.contains('row-level security')) {
      return 'لا تملك صلاحية حفظ هذا العرض. تأكد من تسجيل الدخول وحاول مرة أخرى.';
    }
    if (text.contains('network') || text.contains('socket')) {
      return 'تعذر الاتصال بالخادم. تحقق من الإنترنت وحاول مرة أخرى.';
    }
    return 'تعذر حفظ العرض. راجع البيانات وحاول مرة أخرى.';
  }

  void _showMessage(String message, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, textDirection: TextDirection.rtl),
        backgroundColor: success ? _green : const Color(0xFFB54747),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
          title: const Text('أضف عرضًا جديدًا'),
          centerTitle: true,
          backgroundColor: _background,
          foregroundColor: _darkGreen,
          elevation: 0,
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              _buildIntro(),
              const SizedBox(height: 18),
              _buildListingType(),
              const SizedBox(height: 18),
              _buildImages(),
              const SizedBox(height: 18),
              _buildDetailsCard(),
              const SizedBox(height: 18),
              if (_listingType == 'charity_donation') _buildCharityCard(),
              if (_listingType == 'charity_donation')
                const SizedBox(height: 18),
              _buildLocationCard(),
              const SizedBox(height: 24),
              _buildSubmitButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIntro() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0B7650), Color(0xFF21A36F)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.volunteer_activism_rounded, color: Colors.white, size: 32),
          SizedBox(height: 12),
          Text('خلّي الشيء الزائد يعمل أثرًا',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 21,
                  fontWeight: FontWeight.w900)),
          SizedBox(height: 6),
          Text(
              'اعرض ملابس أو أثاث بحالة جيدة للبيع بسعر بسيط أو تبرع به لجمعية تحتاجه.',
              style:
                  TextStyle(color: Colors.white70, fontSize: 13, height: 1.5)),
        ],
      ),
    );
  }

  Widget _buildListingType() {
    return _sectionCard(
      title: 'ماذا تريد أن تفعل؟',
      icon: Icons.swap_vertical_circle_outlined,
      child: Column(
        children: [
          _choiceTile(
              'تبرع لجمعية',
              'الجمعية تتواصل معك وترسل مندوبًا للاستلام',
              'charity_donation',
              Icons.favorite_rounded,
              _green),
          const SizedBox(height: 10),
          _choiceTile(
              'بيع بسعر رمزي',
              'اعرضه للمستخدمين بسعر بسيط والدفع عند الاستلام',
              'symbolic_sale',
              Icons.sell_rounded,
              _orange),
        ],
      ),
    );
  }

  Widget _choiceTile(
      String title, String subtitle, String value, IconData icon, Color color) {
    final selected = _listingType == value;
    return InkWell(
      onTap: () => setState(() => _listingType = value),
      borderRadius: BorderRadius.circular(17),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? color.withAlpha(20) : Colors.white,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(
              color: selected ? color : const Color(0xFFE0EBE5),
              width: selected ? 1.5 : 1),
        ),
        child: Row(children: [
          Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  color: color.withAlpha(25), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 22)),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(title,
                    style: const TextStyle(
                        color: _darkGreen, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(subtitle,
                    style: const TextStyle(
                        color: Color(0xFF71837C), fontSize: 11, height: 1.35))
              ])),
          Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              color: selected ? color : const Color(0xFFB4C6BE)),
        ]),
      ),
    );
  }

  Widget _buildImages() {
    return _sectionCard(
      title: 'صور العرض',
      icon: Icons.photo_library_outlined,
      trailing: Text('${_images.length}/6',
          style: const TextStyle(color: _green, fontWeight: FontWeight.w800)),
      child: Column(children: [
        SizedBox(
          height: 104,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _images.length + 1,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, index) {
              if (index == _images.length) return _addImageButton();
              return _imageTile(_images[index], index);
            },
          ),
        ),
        const SizedBox(height: 9),
        const Align(
            alignment: Alignment.centerRight,
            child: Text('الصورة الأولى ستظهر كصورة رئيسية للعرض',
                style: TextStyle(color: Color(0xFF71837C), fontSize: 11))),
      ]),
    );
  }

  Widget _addImageButton() {
    return InkWell(
      onTap: _images.length == 6 ? null : _pickImages,
      borderRadius: BorderRadius.circular(16),
      child: Container(
          width: 104,
          decoration: BoxDecoration(
              color: const Color(0xFFE8F5EE),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _green.withAlpha(80))),
          child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_photo_alternate_outlined,
                    color: _green, size: 28),
                SizedBox(height: 5),
                Text('أضف صورًا',
                    style: TextStyle(
                        color: _green,
                        fontSize: 11,
                        fontWeight: FontWeight.w800))
              ])),
    );
  }

  Widget _imageTile(XFile image, int index) {
    return Stack(children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: FutureBuilder<Uint8List>(
          future: image.readAsBytes(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const SizedBox(
                width: 104,
                height: 104,
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              );
            }
            return Image.memory(
              snapshot.data!,
              width: 104,
              height: 104,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const ColoredBox(
                color: Color(0xFFE8F5EE),
                child: SizedBox(
                  width: 104,
                  height: 104,
                  child: Icon(Icons.broken_image_outlined, color: _green),
                ),
              ),
            );
          },
        ),
      ),
      Positioned(
          top: 5,
          left: 5,
          child: InkWell(
              onTap: () => _removeImage(index),
              child: Container(
                  width: 25,
                  height: 25,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                      color: Colors.black54, shape: BoxShape.circle),
                  child:
                      const Icon(Icons.close, color: Colors.white, size: 15)))),
    ]);
  }

  Widget _buildDetailsCard() {
    return _sectionCard(
      title: 'بيانات العرض',
      icon: Icons.edit_note_rounded,
      child: Column(children: [
        _field(_titleController, 'عنوان العرض', 'مثال: جاكت شتوي بحالة ممتازة',
            Icons.title_rounded,
            requiredField: true),
        const SizedBox(height: 12),
        _dropdown(
            'نوع الشيء',
            _category,
            {'clothing': 'ملابس', 'furniture': 'أثاث'},
            (value) => setState(() => _category = value!)),
        const SizedBox(height: 12),
        _dropdown(
            'الحالة',
            _condition,
            {
              'new': 'جديد أو شبه جديد',
              'very_good': 'جيد جدًا',
              'good': 'جيد',
              'needs_repair': 'يحتاج إصلاحًا بسيطًا'
            },
            (value) => setState(() => _condition = value!)),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
              child: _field(_quantityController, 'الكمية', '1',
                  Icons.inventory_2_outlined,
                  requiredField: true, numeric: true)),
          if (_listingType == 'symbolic_sale') ...[
            const SizedBox(width: 10),
            Expanded(
                child: _field(_priceController, 'السعر بالجنيه', '0',
                    Icons.payments_outlined,
                    requiredField: true, numeric: true))
          ]
        ]),
        const SizedBox(height: 12),
        TextFormField(
            controller: _descriptionController,
            minLines: 4,
            maxLines: 6,
            textInputAction: TextInputAction.newline,
            decoration:
                _decoration('الوصف والتفاصيل', Icons.description_outlined),
            validator: (value) => value == null || value.trim().length < 10
                ? 'اكتب وصفًا مختصرًا وواضحًا'
                : null),
      ]),
    );
  }

  Future<void> _openCharityPicker() async {
    final selected = await Navigator.push<CommunityCharityOption>(
      context,
      MaterialPageRoute(
        builder: (_) => CommunityCharitiesPage(initialCharityId: _charityId),
      ),
    );
    if (!mounted || selected == null) return;
    setState(() {
      _charityId = selected.id;
      if (!_availableCharities.any((item) => item.id == selected.id)) {
        _availableCharities = [..._availableCharities, selected];
      }
    });
  }

  Widget _buildCharityCard() {
    final selected =
        _availableCharities.cast<CommunityCharityOption?>().firstWhere(
              (item) => item?.id == _charityId,
              orElse: () => null,
            );

    return _sectionCard(
      title: 'الجمعية المستفيدة',
      icon: Icons.account_balance_rounded,
      child: _isLoadingCharities
          ? const Padding(
              padding: EdgeInsets.all(18),
              child: Center(child: CircularProgressIndicator(color: _green)),
            )
          : InkWell(
              onTap: _openCharityPicker,
              borderRadius: BorderRadius.circular(18),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color:
                      selected == null ? const Color(0xFFE8F5EE) : Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: selected == null
                        ? _green.withAlpha(90)
                        : const Color(0xFFDCEAE2),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.chevron_left_rounded, color: _green),
                    const SizedBox(width: 10),
                    Expanded(
                      child: selected == null
                          ? const Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'اختيار جمعية مستفيدة',
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    color: _darkGreen,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 15,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'ابحث عن جمعية واعرض تفاصيلها قبل الاختيار',
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    color: Color(0xFF71837C),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  selected.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(
                                    color: _darkGreen,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'اضغط لتغيير الجمعية أو رؤية التفاصيل',
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    color: _green,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                    ),
                    const SizedBox(width: 12),
                    CircleAvatar(
                      radius: 25,
                      backgroundColor: const Color(0xFFD8F0E2),
                      backgroundImage: selected?.logo?.isNotEmpty == true
                          ? NetworkImage(selected!.logo!)
                          : null,
                      child: selected?.logo?.isNotEmpty == true
                          ? null
                          : const Icon(Icons.volunteer_activism_rounded,
                              color: _green),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildLocationCard() {
    return _sectionCard(
        title: 'مكان الاستلام',
        icon: Icons.location_on_outlined,
        child: _field(_locationController, 'العنوان أو وصف المكان',
            'مثال: طنطا، شارع البحر', Icons.place_outlined,
            requiredField: true));
  }

  Widget _buildSubmitButton() {
    return SizedBox(
        height: 56,
        child: ElevatedButton.icon(
            onPressed: _isSubmitting ? null : _submit,
            icon: _isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.arrow_forward_rounded),
            label: Text(
                _isSubmitting ? 'جاري تجهيز العرض...' : 'متابعة ومراجعة العرض'),
            style: ElevatedButton.styleFrom(
                backgroundColor: _green,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18)),
                textStyle: const TextStyle(fontWeight: FontWeight.w900))));
  }

  Widget _sectionCard(
      {required String title,
      required IconData icon,
      required Widget child,
      Widget? trailing}) {
    return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFE3EEE8)),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withAlpha(8),
                  blurRadius: 16,
                  offset: const Offset(0, 5))
            ]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
                width: 35,
                height: 35,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    color: const Color(0xFFE8F5EE),
                    borderRadius: BorderRadius.circular(11)),
                child: Icon(icon, color: _green, size: 19)),
            const SizedBox(width: 10),
            Expanded(
                child: Text(title,
                    style: const TextStyle(
                        color: _darkGreen,
                        fontSize: 15,
                        fontWeight: FontWeight.w900))),
            if (trailing != null) trailing
          ]),
          const SizedBox(height: 14),
          child
        ]));
  }

  Widget _field(TextEditingController controller, String label, String hint,
      IconData icon,
      {bool requiredField = false, bool numeric = false}) {
    return TextFormField(
        controller: controller,
        keyboardType: numeric ? TextInputType.number : TextInputType.text,
        inputFormatters: numeric
            ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))]
            : null,
        decoration: _decoration(label, icon, hint: hint),
        validator: requiredField
            ? (value) =>
                value == null || value.trim().isEmpty ? 'هذا الحقل مطلوب' : null
            : null);
  }

  InputDecoration _decoration(String label, IconData icon, {String? hint}) {
    return InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: _green, size: 20),
        filled: true,
        fillColor: const Color(0xFFF8FBF9),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(color: Color(0xFFE1ECE6))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(color: Color(0xFFE1ECE6))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(color: _green, width: 1.5)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 15));
  }

  Widget _dropdown(String label, String value, Map<String, String> items,
      ValueChanged<String?> onChanged) {
    return DropdownButtonFormField<String>(
        initialValue: value,
        decoration: _decoration(label, Icons.category_outlined),
        items: items.entries
            .map((entry) =>
                DropdownMenuItem(value: entry.key, child: Text(entry.value)))
            .toList(),
        onChanged: onChanged);
  }
}
