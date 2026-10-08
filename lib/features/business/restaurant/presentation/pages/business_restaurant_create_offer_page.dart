import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:loqma/core/errors/app_error_mapper.dart';
import 'package:loqma/features/business/restaurant/data/repositories/business_restaurant_repository.dart';
import 'package:loqma/features/business/restaurant/presentation/pages/restaurant_operation_feedback.dart';

class BusinessRestaurantCreateOfferPage extends StatefulWidget {
  const BusinessRestaurantCreateOfferPage({super.key});

  @override
  State<BusinessRestaurantCreateOfferPage> createState() =>
      _BusinessRestaurantCreateOfferPageState();
}

class _BusinessRestaurantCreateOfferPageState
    extends State<BusinessRestaurantCreateOfferPage> {
  static const primary = Color(0xFF003527);
  static const green = Color(0xFF0B7650);
  static const background = Color(0xFFF8F9FF);
  static const muted = Color(0xFF5F6F68);
  static const border = Color(0xFFBFC9C3);

  final _repository = BusinessRestaurantRepository();
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _quantity = TextEditingController();
  final _originalPrice = TextEditingController();
  final _salePrice = TextEditingController();
  final _location = TextEditingController();
  final _imageUrl = TextEditingController();
  final _imagePicker = ImagePicker();
  XFile? _selectedImage;

  String? _foodType;
  DateTime _expiry = DateTime.now().add(const Duration(hours: 8));
  DateTime _pickupBefore = DateTime.now().add(const Duration(hours: 6));
  String? _formError;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _salePrice.addListener(_rebuildPriceSummary);
    _originalPrice.addListener(_rebuildPriceSummary);
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _quantity.dispose();
    _originalPrice.dispose();
    _salePrice.dispose();
    _location.dispose();
    _imageUrl.dispose();
    super.dispose();
  }

  void _rebuildPriceSummary() => setState(() {});

  double? _number(TextEditingController controller) =>
      double.tryParse(controller.text.trim().replaceAll(',', '.'));

  int? _int(TextEditingController controller) =>
      int.tryParse(controller.text.trim());

  double? get _discountPercent {
    final original = _number(_originalPrice);
    final sale = _number(_salePrice);
    if (original == null || sale == null || original <= 0 || sale < 0) {
      return null;
    }
    return ((original - sale) / original * 100).clamp(0, 100).toDouble();
  }

  String _formatDate(DateTime value) =>
      '${value.day}/${value.month}/${value.year}  ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

  Future<void> _pickDateTime({required bool expiry}) async {
    final current = expiry ? _expiry : _pickupBefore;
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 60)),
      initialDate: current,
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child ?? const SizedBox.shrink(),
      ),
    );
    if (!mounted || date == null) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child ?? const SizedBox.shrink(),
      ),
    );
    if (!mounted || time == null) return;
    final value =
        DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() {
      if (expiry) {
        _expiry = value;
      } else {
        _pickupBefore = value;
      }
    });
  }

  Future<void> _submit() async {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _formError = null);
    if (!_formKey.currentState!.validate()) return;
    final quantity = _int(_quantity);
    final salePrice = _number(_salePrice);
    final originalPrice = _number(_originalPrice);
    if (quantity == null || quantity <= 0) {
      setState(() => _formError = 'الكمية يجب أن تكون أكبر من صفر.');
      return;
    }
    if (salePrice == null || salePrice < 0) {
      setState(() => _formError = 'اكتب السعر بعد الخصم بشكل صحيح.');
      return;
    }
    if (originalPrice != null && originalPrice < salePrice) {
      setState(
          () => _formError = 'السعر الأصلي يجب أن يكون أكبر من السعر المخفض.');
      return;
    }
    if (!_pickupBefore.isBefore(_expiry)) {
      setState(
          () => _formError = 'آخر موعد للاستلام يجب أن يسبق انتهاء العرض.');
      return;
    }
    if (!_expiry.isAfter(DateTime.now())) {
      setState(() => _formError = 'وقت انتهاء العرض يجب أن يكون في المستقبل.');
      return;
    }

    setState(() => _submitting = true);
    try {
      String? imageUrl =
          _imageUrl.text.trim().isEmpty ? null : _imageUrl.text.trim();
      if (_selectedImage != null) {
        imageUrl = await _repository.uploadOfferImage(_selectedImage!);
      }
      debugPrint('📌 OFFER IMAGE URL BEFORE RPC: $imageUrl');
      await _repository.createFoodOffer(
        title: _title.text.trim(),
        description: _description.text.trim(),
        quantity: quantity,
        foodType: _foodType!,
        expiryTime: _expiry,
        pickupBefore: _pickupBefore,
        salePrice: salePrice,
        originalPrice: originalPrice,
        pickupLocation:
            _location.text.trim().isEmpty ? null : _location.text.trim(),
        image: imageUrl,
      );
      if (!mounted) return;
      RestaurantOperationFeedback.success(context, 'تم نشر العرض بنجاح.');
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _formError = AppErrorMapper.message(error,
            fallback: 'تعذر نشر العرض. حاول مرة أخرى.');
      });
      RestaurantOperationFeedback.error(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: background,
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: primary,
          surfaceTintColor: Colors.white,
          elevation: 0,
          titleSpacing: 16,
          leading: IconButton(
            tooltip: 'العودة',
            onPressed: _submitting ? null : () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_forward_rounded),
          ),
          title: const Text('إضافة عرض بسعر مخفض',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          actions: [
            IconButton(
              tooltip: 'مسح الحقول',
              onPressed: _submitting ? null : _clearForm,
              icon: const Icon(Icons.more_vert_rounded),
            ),
          ],
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 22, 18, 34),
            children: [
              _imageSection(),
              const SizedBox(height: 18),
              _field(_title, 'عنوان العرض', 'مثال: بوكس معجنات مشكل',
                  required: true),
              _field(_description, 'وصف العرض', 'وصف المكونات والكمية...',
                  maxLines: 3),
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 520;
                  final fields = [
                    _foodTypeField(),
                    _field(_quantity, 'الكمية المتاحة', '0',
                        number: true, required: true),
                    _field(_originalPrice, 'السعر الأصلي', '0.00',
                        number: true),
                    _field(_salePrice, 'السعر بعد الخصم', '0.00',
                        number: true, required: true),
                  ];
                  if (compact) {
                    return Column(children: fields);
                  }
                  return GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 0,
                    childAspectRatio: 4.2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: fields,
                  );
                },
              ),
              const SizedBox(height: 4),
              _dateTile('وقت انتهاء العرض', _expiry,
                  () => _pickDateTime(expiry: true), Icons.event_outlined),
              _dateTile('آخر موعد للاستلام', _pickupBefore,
                  () => _pickDateTime(expiry: false), Icons.schedule_rounded),
              _field(_location, 'موقع الاستلام', 'حدد الفرع أو الموقع...',
                  icon: Icons.location_on_outlined),
              _field(_imageUrl, 'رابط صورة العرض (اختياري)', 'https://...',
                  ltr: true, icon: Icons.link_rounded),
              _priceSummary(),
              if (_formError != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                      color: const Color(0xFFFFE5E1),
                      borderRadius: BorderRadius.circular(12)),
                  child: Text(_formError!,
                      style: const TextStyle(
                          color: Color(0xFFBA1A1A),
                          fontWeight: FontWeight.w700)),
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                height: 52,
                child: FilledButton.icon(
                  onPressed: _submitting
                      ? null
                      : () {
                          _submit();
                        },
                  icon: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.publish_rounded),
                  label: Text(_submitting ? 'جارٍ نشر العرض...' : 'نشر العرض',
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w800)),
                  style: FilledButton.styleFrom(
                      backgroundColor: primary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12))),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 84,
        maxWidth: 1400,
      );
      if (!mounted || image == null) return;
      setState(() {
        _selectedImage = image;
        _formError = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _formError = 'تعذر اختيار الصورة. حاول مرة أخرى.');
    }
  }

  Widget _imageSection() => InkWell(
        onTap: _submitting ? null : _pickImage,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          constraints: const BoxConstraints(minHeight: 188),
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .82),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: border, style: BorderStyle.solid),
          ),
          child: Column(
            children: [
              if (_selectedImage != null)
                FutureBuilder<Uint8List>(
                  future: _selectedImage!.readAsBytes(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const SizedBox(
                        width: 120,
                        height: 90,
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.memory(
                        snapshot.data!,
                        width: 120,
                        height: 90,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.image_rounded,
                          size: 54,
                          color: Color(0xFF80BEA6),
                        ),
                      ),
                    );
                  },
                )
              else
                Container(
                  width: 62,
                  height: 62,
                  decoration: const BoxDecoration(
                      color: Color(0xFF064E3B), shape: BoxShape.circle),
                  child: const Icon(Icons.add_photo_alternate_rounded,
                      color: Color(0xFF80BEA6), size: 30),
                ),
              const SizedBox(height: 12),
              const Text('إضافة صورة للعرض',
                  style: TextStyle(
                      color: primary,
                      fontSize: 18,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 5),
              Text(
                  _selectedImage == null
                      ? 'اضغط هنا لاختيار صورة الوجبة من الجهاز.\nيمكنك أيضًا استخدام رابط صورة في الحقل بالأسفل.'
                      : 'تم اختيار صورة الوجبة. اضغط لتغييرها.',
                  textAlign: TextAlign.center,
                  style:
                      const TextStyle(color: muted, fontSize: 13, height: 1.4)),
            ],
          ),
        ),
      );

  Widget _field(TextEditingController controller, String label, String hint,
      {bool number = false,
      bool required = false,
      int maxLines = 1,
      bool ltr = false,
      IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        textDirection: ltr ? TextDirection.ltr : TextDirection.rtl,
        keyboardType: number
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        decoration: InputDecoration(
          labelText: required ? '$label *' : label,
          hintText: hint,
          prefixIcon: icon == null ? null : Icon(icon, color: muted),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(11),
              borderSide: const BorderSide(color: border)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(11),
              borderSide: const BorderSide(color: border)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(11),
              borderSide: const BorderSide(color: primary, width: 1.4)),
        ),
        validator: required
            ? (value) =>
                value == null || value.trim().isEmpty ? 'هذا الحقل مطلوب' : null
            : null,
      ),
    );
  }

  Widget _foodTypeField() => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: DropdownButtonFormField<String>(
          initialValue: _foodType,
          decoration: InputDecoration(
            labelText: 'نوع الطعام *',
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(11),
                borderSide: const BorderSide(color: border)),
          ),
          items: const [
            DropdownMenuItem(value: 'bakery', child: Text('مخبوزات وحلويات')),
            DropdownMenuItem(value: 'meals', child: Text('وجبات رئيسية')),
            DropdownMenuItem(value: 'produce', child: Text('خضار وفواكه')),
            DropdownMenuItem(value: 'groceries', child: Text('بقالة متنوعة')),
            DropdownMenuItem(value: 'surplus', child: Text('فائض طعام')),
          ],
          onChanged: (value) => setState(() => _foodType = value),
          validator: (value) => value == null ? 'اختر تصنيف العرض' : null,
        ),
      );

  Widget _dateTile(
          String label, DateTime value, VoidCallback onTap, IconData icon) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          leading: Icon(icon, color: green),
          title:
              Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(_formatDate(value), textDirection: TextDirection.ltr),
          trailing: const Icon(Icons.chevron_left_rounded),
          onTap: _submitting ? null : onTap,
        ),
      );

  Widget _priceSummary() {
    final sale = _number(_salePrice) ?? 0;
    final discount = _discountPercent;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: const Border(top: BorderSide(color: primary, width: 4)),
        boxShadow: const [
          BoxShadow(
              color: Color(0x080B7650), blurRadius: 13, offset: Offset(0, 5))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('ملخص التسعير',
              style: TextStyle(
                  color: primary, fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: const Color(0xFFEFF4FF),
                borderRadius: BorderRadius.circular(11)),
            child: Row(
              children: [
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      const Text('السعر للعميل',
                          style: TextStyle(color: muted, fontSize: 13)),
                      const SizedBox(height: 4),
                      Text('${sale.toStringAsFixed(2)} جنيه',
                          style: const TextStyle(
                              color: primary,
                              fontSize: 24,
                              fontWeight: FontWeight.w900)),
                    ])),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  const Text('نسبة الخصم',
                      style: TextStyle(color: muted, fontSize: 13)),
                  const SizedBox(height: 5),
                  Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 11, vertical: 5),
                      decoration: BoxDecoration(
                          color: const Color(0xFFD3E3DC),
                          borderRadius: BorderRadius.circular(20)),
                      child: Text(
                          discount == null ? '0%' : '${discount.round()}%',
                          style: const TextStyle(
                              color: primary, fontWeight: FontWeight.w800))),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _clearForm() {
    _title.clear();
    _description.clear();
    _quantity.clear();
    _originalPrice.clear();
    _salePrice.clear();
    _location.clear();
    _imageUrl.clear();
    setState(() {
      _foodType = null;
      _formError = null;
    });
  }
}
