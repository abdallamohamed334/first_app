import 'dart:async';

import 'package:flutter/material.dart';

import 'package:loqma/core/errors/app_error_mapper.dart';
import 'package:loqma/features/business/restaurant/data/repositories/business_restaurant_repository.dart';
import 'package:loqma/features/business/restaurant/presentation/pages/restaurant_operation_feedback.dart';

class BusinessRestaurantDirectDonationPage extends StatefulWidget {
  const BusinessRestaurantDirectDonationPage({super.key});

  @override
  State<BusinessRestaurantDirectDonationPage> createState() =>
      _BusinessRestaurantDirectDonationPageState();
}

class _BusinessRestaurantDirectDonationPageState
    extends State<BusinessRestaurantDirectDonationPage> {
  static const primary = Color(0xFF003527);
  static const green = Color(0xFF0B7650);
  static const background = Color(0xFFF8F9FF);
  static const muted = Color(0xFF5F6F68);
  static const border = Color(0xFFBFC9C3);

  final _repository = BusinessRestaurantRepository();
  late Future<List<Map<String, dynamic>>> _charitiesFuture;
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _quantity = TextEditingController();
  final _condition = TextEditingController(text: 'جيد وصالح للتوزيع');
  final _imageUrl = TextEditingController();
  String? _selectedCharityId;
  String? _formError;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _charitiesFuture = _repository.listActiveCharities();
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _quantity.dispose();
    _condition.dispose();
    _imageUrl.dispose();
    super.dispose();
  }

  Future<void> _refreshCharities() async {
    final next = _repository.listActiveCharities();
    if (!mounted) {
      await next;
      return;
    }
    setState(() {
      _charitiesFuture = next;
    });
    await next;
  }

  Future<void> _submit(List<Map<String, dynamic>> charities) async {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _formError = null);
    if (!_formKey.currentState!.validate()) return;
    final quantity = int.tryParse(_quantity.text.trim());
    if (_selectedCharityId == null) {
      setState(() => _formError = 'اختر الجمعية المستفيدة أولًا.');
      return;
    }
    if (quantity == null || quantity <= 0) {
      setState(() => _formError = 'الكمية يجب أن تكون أكبر من صفر.');
      return;
    }
    if (!charities.any((row) => row['id']?.toString() == _selectedCharityId)) {
      setState(() => _formError =
          'الجمعية المختارة لم تعد متاحة. حدّث القائمة وحاول مرة أخرى.');
      return;
    }

    setState(() => _submitting = true);
    try {
      await _repository.createCharityDonation(
        charityId: _selectedCharityId!,
        itemTitle: _title.text.trim(),
        description: _description.text.trim(),
        quantity: quantity,
        condition: _condition.text.trim(),
        images:
            _imageUrl.text.trim().isEmpty ? const [] : [_imageUrl.text.trim()],
      );
      if (!mounted) return;
      RestaurantOperationFeedback.success(
          context, 'تم إرسال طلب التبرع للجمعية بنجاح.');
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _formError = AppErrorMapper.message(error,
            fallback: 'تعذر إرسال طلب التبرع. حاول مرة أخرى.');
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
          title: const Text('تبرع مباشر لجمعية',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          actions: [
            IconButton(
              tooltip: 'تحديث الجمعيات',
              onPressed:
                  _submitting ? null : () => unawaited(_refreshCharities()),
              icon: const Icon(Icons.refresh_rounded),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: FutureBuilder<List<Map<String, dynamic>>>(
          future: _charitiesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const _DonationLoadingView();
            }
            if (snapshot.hasError) {
              return _DonationErrorView(
                message: AppErrorMapper.message(snapshot.error!,
                    fallback: 'تعذر تحميل الجمعيات المتاحة.'),
                onRetry: () => unawaited(_refreshCharities()),
              );
            }
            final charities = snapshot.data ?? const <Map<String, dynamic>>[];
            return RefreshIndicator(
              color: green,
              onRefresh: _refreshCharities,
              child: Form(
                key: _formKey,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(18, 24, 18, 34),
                  children: [
                    const Text('تبرع مباشر لجمعية',
                        style: TextStyle(
                            color: primary,
                            fontSize: 29,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 7),
                    const Text(
                        'وجّه فائض الطعام الصالح للاستهلاك إلى جمعية موثقة ليصل إلى المستحقين بأمان.',
                        style: TextStyle(
                            color: muted, fontSize: 15, height: 1.45)),
                    const SizedBox(height: 24),
                    _charitySelection(charities),
                    const SizedBox(height: 18),
                    _detailsCard(charities),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _charitySelection(List<Map<String, dynamic>> charities) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE0EAE5)),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x080B7650),
                  blurRadius: 13,
                  offset: Offset(0, 5))
            ]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('اختر الجمعية',
              style: TextStyle(
                  color: primary, fontSize: 19, fontWeight: FontWeight.w800)),
          const SizedBox(height: 13),
          if (charities.isEmpty)
            const _NoCharityView()
          else
            LayoutBuilder(builder: (context, constraints) {
              final columns = constraints.maxWidth >= 600 ? 2 : 1;
              return GridView.builder(
                itemCount: charities.length,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: columns == 2 ? 2.65 : 3.3),
                itemBuilder: (_, index) => _CharityCard(
                  charity: charities[index],
                  selected:
                      charities[index]['id']?.toString() == _selectedCharityId,
                  onTap: () => setState(() =>
                      _selectedCharityId = charities[index]['id']?.toString()),
                ),
              );
            }),
        ]),
      );

  Widget _detailsCard(List<Map<String, dynamic>> charities) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE0EAE5)),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x080B7650),
                  blurRadius: 13,
                  offset: Offset(0, 5))
            ]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('تفاصيل التبرع',
              style: TextStyle(
                  color: primary, fontSize: 19, fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          _field(_title, 'اسم التبرع', 'مثال: وجبات دجاج وأرز', required: true),
          _field(
              _description, 'وصف الأصناف', 'اكتب الأصناف وحالتها بالتفصيل...',
              maxLines: 3, required: true),
          LayoutBuilder(builder: (context, constraints) {
            if (constraints.maxWidth < 520) {
              return Column(children: [
                _field(_quantity, 'الكمية المقدرة', '0',
                    number: true, required: true),
                _field(_condition, 'حالة التبرع', 'جيد وصالح للتوزيع',
                    required: true),
              ]);
            }
            return Row(children: [
              Expanded(
                  child: _field(_quantity, 'الكمية المقدرة', '0',
                      number: true, required: true)),
              const SizedBox(width: 12),
              Expanded(
                  child: _field(_condition, 'حالة التبرع', 'جيد وصالح للتوزيع',
                      required: true)),
            ]);
          }),
          _field(_imageUrl, 'رابط صورة التبرع (اختياري)', 'https://...',
              ltr: true, icon: Icons.link_rounded),
          if (_formError != null) ...[
            Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: const Color(0xFFFFE5E1),
                    borderRadius: BorderRadius.circular(11)),
                child: Text(_formError!,
                    style: const TextStyle(
                        color: Color(0xFFBA1A1A),
                        fontWeight: FontWeight.w700))),
            const SizedBox(height: 12),
          ],
          SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                  onPressed: _submitting || charities.isEmpty
                      ? null
                      : () => _submit(charities),
                  icon: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.volunteer_activism_rounded),
                  label: Text(
                      _submitting ? 'جارٍ الإرسال...' : 'إرسال طلب التبرع',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w800)),
                  style: FilledButton.styleFrom(
                      backgroundColor: primary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12))))),
        ]),
      );

  Widget _field(TextEditingController controller, String label, String hint,
          {bool number = false,
          bool required = false,
          int maxLines = 1,
          bool ltr = false,
          IconData? icon}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: TextFormField(
          controller: controller,
          maxLines: maxLines,
          textDirection: ltr ? TextDirection.ltr : TextDirection.rtl,
          keyboardType: number ? TextInputType.number : TextInputType.text,
          decoration: InputDecoration(
              labelText: required ? '$label *' : label,
              hintText: hint,
              prefixIcon: icon == null ? null : Icon(icon, color: muted),
              filled: true,
              fillColor: background,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(11),
                  borderSide: const BorderSide(color: border)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(11),
                  borderSide: const BorderSide(color: border)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(11),
                  borderSide: const BorderSide(color: primary, width: 1.4))),
          validator: required
              ? (value) => value == null || value.trim().isEmpty
                  ? 'هذا الحقل مطلوب'
                  : null
              : null,
        ),
      );
}

class _CharityCard extends StatelessWidget {
  final Map<String, dynamic> charity;
  final bool selected;
  final VoidCallback onTap;
  const _CharityCard(
      {required this.charity, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final name = charity['name']?.toString() ?? 'جمعية موثقة';
    final address = charity['address']?.toString() ?? 'العنوان غير مسجل';
    final logo = charity['logo']?.toString();
    return Material(
        color: selected ? const Color(0xFFEAF8F0) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: selected
                            ? const Color(0xFF003527)
                            : const Color(0xFFE0EAE5),
                        width: selected ? 1.8 : 1)),
                child: Row(children: [
                  Stack(children: [
                    Container(
                        width: 48,
                        height: 48,
                        clipBehavior: Clip.antiAlias,
                        decoration: const BoxDecoration(
                            color: Color(0xFFE6EEFF), shape: BoxShape.circle),
                        child: logo != null && logo.isNotEmpty
                            ? Image.network(logo,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(
                                    Icons.volunteer_activism_rounded,
                                    color: Color(0xFF0B7650)))
                            : const Icon(Icons.volunteer_activism_rounded,
                                color: Color(0xFF0B7650))),
                    if (selected)
                      const Positioned(
                          bottom: -1,
                          left: -1,
                          child: Icon(Icons.check_circle_rounded,
                              color: Color(0xFF0B7650), size: 19)),
                  ]),
                  const SizedBox(width: 11),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Row(children: [
                          Expanded(
                              child: Text(name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      color: Color(0xFF003527),
                                      fontWeight: FontWeight.w800))),
                          const Icon(Icons.verified_rounded,
                              color: Color(0xFF0B7650), size: 17)
                        ]),
                        const SizedBox(height: 4),
                        Text(address,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Color(0xFF5F6F68), fontSize: 12)),
                      ])),
                ]))));
  }
}

class _NoCharityView extends StatelessWidget {
  const _NoCharityView();
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: const Color(0xFFFFF3D9),
          borderRadius: BorderRadius.circular(12)),
      child: const Row(children: [
        Icon(Icons.info_outline_rounded, color: Color(0xFF8A5B13)),
        SizedBox(width: 9),
        Expanded(
            child: Text('لا توجد جمعية موثقة متاحة لاستقبال التبرعات حاليًا.',
                style: TextStyle(
                    color: Color(0xFF8A5B13), fontWeight: FontWeight.w700)))
      ]));
}

class _DonationLoadingView extends StatelessWidget {
  const _DonationLoadingView();
  @override
  Widget build(BuildContext context) =>
      ListView(padding: const EdgeInsets.all(18), children: [
        for (var i = 0; i < 3; i++)
          Container(
              height: 150,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                  color: const Color(0xFFE6EEFF),
                  borderRadius: BorderRadius.circular(16)))
      ]);
}

class _DonationErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _DonationErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
      child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.cloud_off_rounded,
                size: 50, color: Color(0xFF71837C)),
            const SizedBox(height: 14),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 14),
            FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('إعادة المحاولة'))
          ])));
}
