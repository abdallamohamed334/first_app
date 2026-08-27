import 'package:flutter/material.dart';
import 'package:loqma/features/charity/data/repositories/charity_donation_repository_separate.dart';

class CommunityCharityDonationDetailsPage extends StatefulWidget {
  final Map<String, dynamic> donation;

  const CommunityCharityDonationDetailsPage({
    super.key,
    required this.donation,
  });

  @override
  State<CommunityCharityDonationDetailsPage> createState() =>
      _CommunityCharityDonationDetailsPageState();
}

class _CommunityCharityDonationDetailsPageState
    extends State<CommunityCharityDonationDetailsPage> {
  final _repository = SeparateCharityDonationRepository();
  bool _loadingCode = false;
  bool _markingReady = false;
  String? _localStatus;

  static const _green = Color(0xFF0B7650);
  static const _darkGreen = Color(0xFF123F31);
  static const _background = Color(0xFFF6FAF8);

  Map<String, dynamic> get donation => widget.donation;
  String get status =>
      _localStatus ?? donation['status']?.toString() ?? 'pending';

  Future<void> _markReady() async {
    print(
        'DIRECT CHARITY DEBUG: UI markReady TAP id=${donation['id']} status=${donation['status']} status_type=${donation['status'].runtimeType}');
    if (_markingReady) return;
    setState(() => _markingReady = true);
    try {
      final returnedCode =
          await _repository.markDonorReady(donation['id'].toString());
      print(
          'DIRECT CHARITY DEBUG: UI markReady SUCCESS id=${donation['id']} returned_code_present=${returnedCode.isNotEmpty}');
      if (mounted) {
        setState(() => _localStatus = 'donor_ready');
        _message('تم تسجيل جاهزيتك. ستظهر بيانات مندوب الجمعية بعد تعيينه.',
            success: true);
      }
    } catch (error) {
      print('DIRECT CHARITY DEBUG: UI markReady ERROR=$error');
      if (mounted) _message('تعذر تسجيل الجاهزية: $error');
    } finally {
      if (mounted) setState(() => _markingReady = false);
    }
  }

  Future<void> _showCode() async {
    print(
        'DIRECT CHARITY DEBUG: UI showCode TAP id=${donation['id']} status=${donation['status']} volunteer=${donation['volunteer_name']} pickup_token_present=${(donation['pickup_token']?.toString().isNotEmpty ?? false)}');
    if (_loadingCode) return;
    setState(() => _loadingCode = true);
    try {
      final code = await _repository.getPickupCode(donation['id'].toString());
      print(
          'DIRECT CHARITY DEBUG: UI showCode SUCCESS id=${donation['id']} code_present=${code.isNotEmpty}');
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('كود تسليم التبرع'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('اعرض الكود لمندوب الجمعية فقط عند استلام التبرع.'),
              const SizedBox(height: 18),
              SelectableText(code,
                  style: const TextStyle(
                      color: _green,
                      fontSize: 25,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2)),
            ],
          ),
          actions: [
            FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('تم'))
          ],
        ),
      );
    } catch (error) {
      print('DIRECT CHARITY DEBUG: UI showCode ERROR=$error');
      if (mounted) _message('تعذر عرض الكود: $error');
    } finally {
      if (mounted) setState(() => _loadingCode = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final charity = donation['charities'] is Map
        ? Map<String, dynamic>.from(donation['charities'] as Map)
        : <String, dynamic>{};
    final title = donation['title']?.toString() ?? 'تبرع مباشر';
    final volunteer = donation['volunteer_name']?.toString();
    final phone = donation['volunteer_phone']?.toString();
    final address =
        donation['pickup_address']?.toString() ?? 'العنوان غير مضاف';

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _background,
        appBar: AppBar(
            title: const Text('تفاصيل التبرع'),
            backgroundColor: _background,
            foregroundColor: _darkGreen,
            elevation: 0),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
          children: [
            _titleCard(title),
            if (_imageUrls().isNotEmpty) ...[
              const SizedBox(height: 14),
              _imagesCard(),
            ],
            const SizedBox(height: 14),
            _infoCard(
                Icons.volunteer_activism_outlined,
                'الجمعية المستفيدة',
                charity['name']?.toString() ?? 'جمعية موثقة',
                '${charity['address'] ?? 'العنوان غير متاح'}'),
            const SizedBox(height: 10),
            _infoCard(Icons.location_on_outlined, 'مكان استلام التبرع', address,
                'الكمية: ${donation['quantity'] ?? 1}'),
            if (volunteer != null && volunteer.isNotEmpty) ...[
              const SizedBox(height: 10),
              _infoCard(Icons.badge_outlined, 'مندوب الجمعية', volunteer,
                  phone?.isEmpty == false ? phone! : 'رقم الهاتف غير متاح'),
            ],
            const SizedBox(height: 18),
            const Text('خط سير التبرع',
                style: TextStyle(
                    color: _darkGreen,
                    fontSize: 19,
                    fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            _timeline(),
            if (status == 'accepted') ...[
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: _markingReady ? null : _markReady,
                icon: const Icon(Icons.front_hand_rounded),
                label: Text(_markingReady
                    ? 'جارٍ تسجيل الجاهزية...'
                    : 'أنا جاهز لتسليم الحاجة'),
                style: FilledButton.styleFrom(
                    backgroundColor: _green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14)),
              ),
            ],
            if (status == 'volunteer_assigned') ...[
              const SizedBox(height: 18),
              _instructionBox(
                  'تم إرسال مندوب الجمعية. عند وصوله، اطلب منه إبراز بياناته ثم اضغط لعرض الكود الثابت.'),
              const SizedBox(height: 10),
              FilledButton.icon(
                  onPressed: _loadingCode ? null : _showCode,
                  icon: const Icon(Icons.qr_code_2_rounded),
                  label: Text(_loadingCode
                      ? 'جارٍ تجهيز الكود...'
                      : 'عرض كود التسليم للمندوب'),
                  style: FilledButton.styleFrom(
                      backgroundColor: _green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14))),
            ],
            if (status == 'completed') ...[
              const SizedBox(height: 16),
              _successBox(),
            ],
          ],
        ),
      ),
    );
  }

  List<String> _imageUrls() {
    final raw = donation['images'];
    if (raw is! List) return const [];
    return raw
        .map((value) => value.toString())
        .where((url) => url.startsWith('http'))
        .toList();
  }

  Widget _imagesCard() => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE0EBE5))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Icon(Icons.photo_library_outlined, color: _green),
            SizedBox(width: 8),
            Text('صور التبرع',
                style:
                    TextStyle(color: _darkGreen, fontWeight: FontWeight.w900))
          ]),
          const SizedBox(height: 12),
          SizedBox(
            height: 130,
            child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _imageUrls().length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, index) => ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.network(_imageUrls()[index],
                        width: 155,
                        height: 130,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                            width: 155,
                            height: 130,
                            color: const Color(0xFFE8F1EC),
                            child: const Icon(Icons.broken_image_outlined,
                                color: _green))))),
          )
        ]),
      );

  Widget _titleCard(String title) => Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Color(0xFF0B7650), Color(0xFF2BAA76)],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft),
          borderRadius: BorderRadius.circular(24)),
      child: Row(children: [
        const Icon(Icons.lock_rounded, color: Colors.white, size: 35),
        const SizedBox(width: 13),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('تبرع خاص وآمن',
              style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 5),
          Text(title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text(_statusLabel(status),
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800))
        ]))
      ]));

  Widget _infoCard(IconData icon, String label, String value, String sub) =>
      Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE0EBE5))),
          child: Row(children: [
            Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                    color: Color(0xFFE5F4EB), shape: BoxShape.circle),
                child: Icon(icon, color: _green)),
            const SizedBox(width: 11),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(label,
                      style: const TextStyle(
                          color: Color(0xFF71837C),
                          fontSize: 11,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(value,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: _darkGreen,
                          fontSize: 14,
                          fontWeight: FontWeight.w900)),
                  const SizedBox(height: 3),
                  Text(sub,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Color(0xFF71837C), fontSize: 11))
                ]))
          ]));

  Widget _timeline() {
    // هذا خط سير المتبرع فقط، وليس إجراءات الجمعية التشغيلية.
    const steps = <(String, String, IconData)>[
      ('pending', 'أرسلت التبرع', Icons.send_rounded),
      ('accepted', 'راجعت الجمعية الطلب', Icons.fact_check_outlined),
      ('volunteer_assigned', 'مندوب الجمعية جاهز', Icons.badge_outlined),
      (
        'picked_up_from_donor',
        'استلم المندوب التبرع',
        Icons.verified_user_outlined
      ),
      ('completed', 'وصل التبرع للجمعية', Icons.done_all_rounded),
    ];
    final current = switch (status) {
      'pending' => 0,
      'accepted' => 1,
      'donor_ready' || 'volunteer_assigned' => 2,
      'picked_up_from_donor' || 'in_transit' => 3,
      'completed' => 4,
      _ => 0,
    };
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE0EBE5))),
      child: Column(
        children: List.generate(steps.length, (i) {
          final active = i <= current;
          final last = i == steps.length - 1;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(children: [
                Container(
                    width: 31,
                    height: 31,
                    decoration: BoxDecoration(
                        color: active ? _green : const Color(0xFFE5EEE9),
                        shape: BoxShape.circle),
                    child: Icon(steps[i].$3,
                        color: active ? Colors.white : const Color(0xFF9AACA3),
                        size: 16)),
                if (!last)
                  Container(
                      width: 3,
                      height: 28,
                      color: i < current ? _green : const Color(0xFFE5EEE9)),
              ]),
              const SizedBox(width: 11),
              Padding(
                  padding: const EdgeInsets.only(top: 7),
                  child: Text(steps[i].$2,
                      style: TextStyle(
                          color: active ? _darkGreen : const Color(0xFF98A9A1),
                          fontSize: 12,
                          fontWeight:
                              active ? FontWeight.w900 : FontWeight.w500))),
            ],
          );
        }),
      ),
    );
  }

  Widget _successBox() => Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE5F7EC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFBFE3CE)),
      ),
      child: const Row(children: [
        Icon(Icons.verified_rounded, color: _green, size: 26),
        SizedBox(width: 10),
        Expanded(
            child: Text('تم وصول التبرع بنجاح. تمت إضافة نقاط الأثر إلى حسابك.',
                style: TextStyle(
                    color: _darkGreen,
                    fontWeight: FontWeight.w800,
                    height: 1.4)))
      ]));

  Widget _instructionBox(String text) => Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
          color: const Color(0xFFFFF7E3),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: const Color(0xFFFFE1A6))),
      child: Text(text,
          style: const TextStyle(
              color: Color(0xFF805B1B),
              fontSize: 12,
              fontWeight: FontWeight.w700,
              height: 1.45)));

  String _statusLabel(String value) =>
      <String, String>{
        'pending': 'في انتظار مراجعة الجمعية',
        'accepted': 'وافقت الجمعية — أعلن جاهزيتك',
        'donor_ready': 'أعلنت جاهزيتك — في انتظار المندوب',
        'volunteer_assigned': 'تم إرسال مندوب الجمعية',
        'picked_up_from_donor': 'استلم المندوب التبرع منك',
        'in_transit': 'في الطريق للجمعية',
        'completed': 'وصل للجمعية بنجاح'
      }[value] ??
      'جارٍ تحديث الحالة';

  void _message(String text, {bool success = false}) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(text, textDirection: TextDirection.rtl),
          backgroundColor: success ? _green : const Color(0xFFB54747)));
}
