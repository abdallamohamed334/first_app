// lib/features/charity/presentation/pages/volunteer_donation_detail_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:loqma/core/services/supabase_service.dart';
import 'package:loqma/features/charity/data/repositories/charity_donation_repository_separate.dart';
import 'package:url_launcher/url_launcher.dart';

class VolunteerDonationDetailPage extends StatefulWidget {
  final Map<String, dynamic> donation;

  const VolunteerDonationDetailPage({super.key, required this.donation});

  @override
  State<VolunteerDonationDetailPage> createState() =>
      _VolunteerDonationDetailPageState();
}

class _VolunteerDonationDetailPageState
    extends State<VolunteerDonationDetailPage> {
  static const _green = Color(0xFF0B7650);
  static const _darkGreen = Color(0xFF123F31);
  static const _mint = Color(0xFFDDF3E8);
  static const _background = Color(0xFFF6FAF8);
  static const _orange = Color(0xFFE28B00);

  final _repository = SeparateCharityDonationRepository();
  bool _isLoading = false;
  bool _isClaimed = false;
  bool _changed = false;
  late String _status;
  String _charityCode = '';

  final TextEditingController _codeController = TextEditingController();

  String get _donationId => widget.donation['id']?.toString() ?? '';

  @override
  void initState() {
    super.initState();
    _status = widget.donation['status']?.toString() ?? 'accepted';
    _refreshCurrentState();
  }

  Future<void> _loadCharityCode() async {
    try {
      final code = await _repository.getCharityPickupCode(_donationId);
      setState(() => _charityCode = code);
    } catch (e) {
      debugPrint('❌ Error loading charity code: $e');
    }
  }

  Future<void> _refreshCurrentState() async {
    try {
      final user = SupabaseService().client.auth.currentUser;
      if (user == null || _donationId.isEmpty) return;

      final response = await SupabaseService()
          .client
          .from('charity_donation_requests')
          .select('volunteer_id, status')
          .eq('id', _donationId)
          .maybeSingle();

      if (response != null && mounted) {
        setState(() {
          _isClaimed = response['volunteer_id'] == user.id;
          if (response['status'] != null) {
            _status = response['status'].toString();
          }
        });
        await _loadCharityCode();
      }
    } catch (e) {
      debugPrint('❌ Error checking claim status: $e');
    }
  }

  String _friendlyError(Object error) {
    final text = error.toString().toLowerCase();
    if (text.contains('تم قبول هذا التبرع') || text.contains('طرف آخر')) {
      return 'للأسف تم حجز هذا التبرع من متطوع آخر قبلك';
    }
    if (text.contains('لا يمكن تنفيذ') || text.contains('الحالة الحالية')) {
      return 'لا يمكن تنفيذ هذه الخطوة الآن';
    }
    if (text.contains('كود') || text.contains('رمز')) {
      return 'الكود غير صحيح، تأكد من الرقم الذي أعطاك إياه المتبرع';
    }
    if (text.contains('انتهت صلاحية')) {
      return 'انتهت صلاحية الكود، اطلب كود جديد من المتبرع';
    }
    return 'حدث خطأ، حاول مرة أخرى';
  }

  void _toast(String text, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: error ? const Color(0xFFD64545) : _darkGreen,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  // ✅ زرار 1: قادر أوصله - حجز التبرع
  Future<void> _claimDonation() async {
    if (_isLoading || _donationId.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      await _repository.claimOpenDonation(_donationId);
      if (!mounted) return;
      setState(() {
        _isClaimed = true;
        _status = 'volunteer_assigned';
        _changed = true;
        _isLoading = false;
      });
      _toast('✅ تم حجز التبرع بنجاح');
      _refreshCurrentState();
    } catch (e) {
      if (mounted) {
        _toast(_friendlyError(e), error: true);
        setState(() => _isLoading = false);
      }
    }
  }

  // ✅ زرار 2: إدخال كود المتبرع (بدون عرض الكود)
  void _showDonorCodeDialog() {
    _codeController.clear();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.qr_code_scanner_rounded, color: _green),
            SizedBox(width: 10),
            Text(
              'تأكيد استلام التبرع',
              style: TextStyle(
                color: _darkGreen,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'اطلب من المتبرع إعطاءك كود الاستلام المكون من 6 أرقام، ثم أدخله هنا.',
              style: TextStyle(fontSize: 13, color: Color(0xFF71837C)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _codeController,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              maxLength: 6,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                letterSpacing: 4,
                color: _darkGreen,
              ),
              decoration: InputDecoration(
                labelText: 'أدخل كود الاستلام (6 أرقام)',
                labelStyle: const TextStyle(color: Color(0xFF71837C)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _green, width: 2),
                ),
                prefixIcon:
                    const Icon(Icons.lock_outline_rounded, color: _green),
                counterText: '',
                helperText: 'اسأل المتبرع عن الكود',
                helperStyle:
                    const TextStyle(color: Color(0xFF71837C), fontSize: 11),
              ),
              onSubmitted: (_) => _confirmDonorPickup(),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
                const Text('إلغاء', style: TextStyle(color: Color(0xFF71837C))),
          ),
          FilledButton.icon(
            onPressed: _isLoading ? null : _confirmDonorPickup,
            icon: _isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.check_rounded),
            label: const Text('تأكيد الاستلام'),
            style: FilledButton.styleFrom(
              backgroundColor: _green,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // ✅ تأكيد الاستلام بالكود مع معالجة أفضل للأخطاء
  Future<void> _confirmDonorPickup() async {
    final code = _codeController.text.trim();

    // ✅ التحقق من أن الكود 6 أرقام
    if (code.length != 6) {
      _toast('الكود يجب أن يتكون من 6 أرقام', error: true);
      return;
    }

    if (!RegExp(r'^[0-9]{6}$').hasMatch(code)) {
      _toast('الكود يجب أن يحتوي على أرقام فقط', error: true);
      return;
    }

    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      await _repository.confirmVolunteerPickupWithCode(_donationId, code);
      if (!mounted) return;

      setState(() {
        _status = 'picked_up_from_donor';
        _changed = true;
        _isLoading = false;
      });

      Navigator.pop(context); // إغلاق النافذة
      _toast('✅ تم تأكيد استلام التبرع من المتبرع بنجاح');

      // ✅ تحديث الحالة في الخلفية
      await _refreshCurrentState();
    } catch (e) {
      if (mounted) {
        // ✅ عرض رسالة الخطأ بشكل مفهوم
        final errorMsg = _friendlyError(e);
        _toast(errorMsg, error: true);
        setState(() => _isLoading = false);
      }
    }
  }

  // ✅ زرار 3: إنشاء كود الجمعية
  Future<void> _generateCharityCode() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      final code = await _repository.generateCharityPickupCode(_donationId);
      if (!mounted) return;
      setState(() {
        _charityCode = code;
        _status = 'in_transit';
        _changed = true;
        _isLoading = false;
      });
      _toast('✅ تم إنشاء كود الجمعية: $code');
      await _loadCharityCode();
    } catch (e) {
      if (mounted) {
        _toast(_friendlyError(e), error: true);
        setState(() => _isLoading = false);
      }
    }
  }

  // ✅ زرار 4: عرض كود الجمعية
  void _showCharityCode() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.business_center_rounded, color: _orange),
            SizedBox(width: 10),
            Text(
              'كود تسليم الجمعية',
              style: TextStyle(
                color: _darkGreen,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'أعط هذا الكود للجمعية لتأكيد وصول التبرع.',
              style: TextStyle(fontSize: 13, color: Color(0xFF71837C)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _orange.withAlpha(50)),
              ),
              child: SelectableText(
                _charityCode,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _orange,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 3,
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '⏰ الكود صالح لمدة 24 ساعة',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            style: FilledButton.styleFrom(backgroundColor: _orange),
            child: const Text('تم'),
          ),
        ],
      ),
    );
  }

  void _callDonor(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (cleanPhone.isEmpty) {
      _toast('رقم الهاتف غير متوفر', error: true);
      return;
    }
    final Uri url = Uri(scheme: 'tel', path: cleanPhone);
    try {
      if (await canLaunchUrl(url)) await launchUrl(url);
    } catch (e) {
      _toast('حدث خطأ أثناء محاولة الاتصال', error: true);
    }
  }

  List<String> get _images {
    final raw = widget.donation['images'];
    if (raw is! List) return const [];
    return raw
        .map((v) => v.toString())
        .where((url) => url.startsWith('http'))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final donation = widget.donation;
    final title = donation['title']?.toString().trim().isNotEmpty == true
        ? donation['title'].toString()
        : 'تبرع';
    final quantity = donation['quantity']?.toString() ?? '1';
    final charity = donation['charities'] is Map
        ? Map<String, dynamic>.from(donation['charities'] as Map)
        : const {};
    final charityName = charity['name']?.toString() ??
        donation['charity_name']?.toString() ??
        'جمعية خيرية';
    final city = donation['pickup_city']?.toString() ?? '';
    final description = donation['description']?.toString() ?? '';
    final address = donation['pickup_address']?.toString() ?? '';
    final donor = donation['users'] is Map
        ? Map<String, dynamic>.from(donation['users'] as Map)
        : const {};
    final donorName = donor['name']?.toString() ??
        donation['donor_name']?.toString() ??
        'متبرع';
    final donorPhone =
        donor['phone']?.toString() ?? donation['donor_phone']?.toString() ?? '';

    return PopScope(
      canPop: true,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: _background,
          appBar: AppBar(
            title: const Text('تفاصيل التبرع',
                style: TextStyle(fontWeight: FontWeight.w900)),
            backgroundColor: _background,
            foregroundColor: _darkGreen,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_forward_rounded),
              onPressed: () => Navigator.pop(context, _changed),
            ),
            actions: [
              if (donorPhone.isNotEmpty && _isClaimed)
                IconButton(
                  icon: const Icon(Icons.phone_rounded, color: _green),
                  onPressed: () => _callDonor(donorPhone),
                  tooltip: 'اتصال بالمتبرع',
                ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              _hero(title, charityName),
              const SizedBox(height: 16),
              Wrap(spacing: 8, runSpacing: 8, children: [
                _infoChip(Icons.inventory_2_outlined, '$quantity وحدة', _green),
                _infoChip(Icons.volunteer_activism_rounded, charityName,
                    const Color(0xFF3679C8)),
                if (city.isNotEmpty)
                  _infoChip(Icons.location_on_outlined, city,
                      const Color(0xFFB77700)),
                _infoChip(Icons.person_outline, 'المتبرع: $donorName',
                    const Color(0xFF71837C)),
                if (donorPhone.isNotEmpty && _isClaimed)
                  GestureDetector(
                    onTap: () => _callDonor(donorPhone),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: _green.withAlpha(15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _green.withAlpha(40)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.phone_rounded,
                              size: 14, color: _green),
                          const SizedBox(width: 4),
                          Text(donorPhone,
                              style: const TextStyle(
                                  color: _green,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700)),
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                                color: _green,
                                borderRadius: BorderRadius.circular(4)),
                            child: const Icon(Icons.call_rounded,
                                size: 10, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
              ]),
              const SizedBox(height: 16),
              _card(
                title: 'معلومات التبرع',
                icon: Icons.info_outline_rounded,
                child: Column(children: [
                  if (description.isNotEmpty) _row('الوصف', description),
                  if (address.isNotEmpty) _row('العنوان', address),
                  if (donorPhone.isNotEmpty && _isClaimed)
                    _row(
                      'هاتف المتبرع',
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(donorPhone,
                              style: const TextStyle(
                                  color: _darkGreen,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13)),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: () => _callDonor(donorPhone),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                  color: _green,
                                  borderRadius: BorderRadius.circular(8)),
                              child: const Icon(Icons.phone_rounded,
                                  size: 14, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                  _row('الحالة', _statusLabel(_status)),
                  if (_status == 'in_transit' && _charityCode.isNotEmpty)
                    _row(
                      'كود الجمعية',
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE3F7EC),
                          borderRadius: BorderRadius.circular(8),
                          border:
                              Border.all(color: _green.withAlpha(50), width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.business_center_rounded,
                                size: 14, color: _green),
                            const SizedBox(width: 6),
                            Text(_charityCode,
                                style: const TextStyle(
                                    color: _green,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16,
                                    letterSpacing: 2)),
                            const SizedBox(width: 6),
                            InkWell(
                              onTap: () {
                                Clipboard.setData(
                                    ClipboardData(text: _charityCode));
                                _toast('تم نسخ الكود 📋');
                              },
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                    color: _green.withAlpha(30),
                                    borderRadius: BorderRadius.circular(4)),
                                child: const Icon(Icons.copy_rounded,
                                    size: 12, color: _green),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ]),
              ),
              const SizedBox(height: 16),
              _timeline(),
              const SizedBox(height: 20),
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: LinearProgressIndicator(color: _green),
                )
              else
                _actions(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _hero(String title, String charityName) {
    final images = _images;
    final heroImage = images.isNotEmpty ? images.first : null;
    return Container(
      height: 190,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
              color: _green.withAlpha(40),
              blurRadius: 20,
              offset: const Offset(0, 10))
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          heroImage == null
              ? const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                        colors: [_darkGreen, _green],
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft),
                  ),
                  child: Center(
                      child: Icon(Icons.volunteer_activism_rounded,
                          color: Colors.white, size: 52)),
                )
              : Image.network(
                  heroImage,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                          colors: [_darkGreen, _green],
                          begin: Alignment.topRight,
                          end: Alignment.bottomLeft),
                    ),
                    child: Center(
                        child: Icon(Icons.image_not_supported_outlined,
                            color: Colors.white, size: 42)),
                  ),
                ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.35, 1],
                  colors: [Colors.transparent, Colors.black.withAlpha(190)],
                ),
              ),
            ),
          ),
          Positioned(top: 14, right: 14, child: _statusPill(_status)),
          Positioned(
            left: 18,
            right: 18,
            bottom: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w900)),
                const SizedBox(height: 3),
                Text(charityName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: Colors.white.withAlpha(220),
                        fontWeight: FontWeight.w700,
                        fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actions() {
    // 1. التبرع متاح للحجز
    if (_status == 'accepted' && !_isClaimed) {
      return _actionButton(
          '🚀 قادر أوصله', Icons.volunteer_activism_rounded, _claimDonation,
          color: _green);
    }

    // 2. تم الحجز - إدخال كود المتبرع
    if (_status == 'volunteer_assigned' && _isClaimed) {
      return Column(
        children: [
          _notice(
            Icons.info_outline_rounded,
            '📌 تم تعيينك كمندوب',
            'اطلب كود الاستلام من المتبرع',
            const Color(0xFF3679C8),
          ),
          const SizedBox(height: 12),
          _actionButton('🔑 إدخال كود المتبرع', Icons.qr_code_scanner_rounded,
              _showDonorCodeDialog,
              color: const Color(0xFFE28B00)),
        ],
      );
    }

    // 3. تم الاستلام من المتبرع - إنشاء كود الجمعية
    if (_status == 'picked_up_from_donor' && _isClaimed) {
      return Column(
        children: [
          _notice(
            Icons.check_circle_rounded,
            '✅ تم استلام التبرع من المتبرع',
            'أنشئ كود الجمعية لتقديمه عند الوصول',
            _green,
          ),
          const SizedBox(height: 12),
          _actionButton('🏢 إنشاء كود الجمعية', Icons.business_center_rounded,
              _generateCharityCode,
              color: const Color(0xFF3679C8)),
        ],
      );
    }

    // 4. في الطريق - عرض كود الجمعية
    if (_status == 'in_transit' && _isClaimed) {
      return Column(
        children: [
          _notice(
            Icons.directions_run_rounded,
            '🚗 التبرع في الطريق للجمعية',
            _charityCode.isNotEmpty
                ? 'كود الجمعية جاهز - قدمه للجمعية'
                : 'جاري إنشاء الكود...',
            const Color(0xFFB7791F),
          ),
          if (_charityCode.isNotEmpty) ...[
            const SizedBox(height: 12),
            _actionButton(
                '📋 عرض كود الجمعية', Icons.qr_code_rounded, _showCharityCode,
                color: _orange),
          ],
        ],
      );
    }

    // 5. اكتمل
    if (_status == 'completed') {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFE3F7EC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFBFE7CE)),
        ),
        child: Row(children: [
          const Icon(Icons.celebration_rounded, color: _green, size: 30),
          const SizedBox(width: 12),
          const Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('🎉 تم التوصيل بنجاح!',
                  style: TextStyle(
                      color: _green,
                      fontWeight: FontWeight.w900,
                      fontSize: 15)),
              SizedBox(height: 2),
              Text('شكرًا لمجهودك في إيصال هذا التبرع',
                  style: TextStyle(color: Color(0xFF396653), fontSize: 12)),
            ]),
          ),
        ]),
      );
    }

    // محجوز من متطوع آخر
    if (_isClaimed == false && _status != 'accepted') {
      return _notice(Icons.lock_outline_rounded, '🔒 تم حجز التبرع',
          'تم حجزه من متطوع آخر قبلك', Colors.grey.shade600);
    }

    return _notice(Icons.info_outline_rounded, _statusLabel(_status),
        'في انتظار تحديث الحالة', Colors.grey.shade600);
  }

  Widget _actionButton(String label, IconData icon, VoidCallback action,
          {Color color = _green}) =>
      SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: _isLoading ? null : action,
          icon: _isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : Icon(icon),
          label: Text(label,
              style:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
          style: FilledButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
      );

  Widget _notice(IconData icon, String title, String subtitle, Color color) =>
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withAlpha(20),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withAlpha(60)),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: color.withAlpha(30), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  style: TextStyle(
                      color: color, fontSize: 13, fontWeight: FontWeight.w900)),
              const SizedBox(height: 2),
              Text(subtitle,
                  style: TextStyle(
                      color: color.withAlpha(210),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600)),
            ]),
          ),
        ]),
      );

  Widget _card(
          {required String title,
          required IconData icon,
          required Widget child}) =>
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2EEE8)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, color: _green, size: 19),
            const SizedBox(width: 8),
            Text(title,
                style: const TextStyle(
                    color: _darkGreen,
                    fontSize: 16,
                    fontWeight: FontWeight.w900)),
          ]),
          const SizedBox(height: 12),
          child,
        ]),
      );

  Widget _row(String label, dynamic value) => Padding(
        padding: const EdgeInsets.only(bottom: 9),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            width: 85,
            child: Text(label,
                style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
          ),
          Expanded(
            child: value is Widget
                ? value
                : Text(value.toString(),
                    style: const TextStyle(
                        color: _darkGreen,
                        fontWeight: FontWeight.w700,
                        fontSize: 13)),
          ),
        ]),
      );

  Widget _infoChip(IconData icon, String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withAlpha(20),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withAlpha(50)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 12, fontWeight: FontWeight.w700)),
        ]),
      );

  Widget _statusPill(String status) {
    final data = _statusData(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
          color: data.$2, borderRadius: BorderRadius.circular(20)),
      child: Text(data.$1,
          style: TextStyle(
              color: data.$3, fontSize: 10, fontWeight: FontWeight.w900)),
    );
  }

  (String, Color, Color) _statusData(String status) =>
      {
        'accepted': (
          'بانتظار متطوع',
          const Color(0xFFFFF1D8),
          const Color(0xFF9A6711)
        ),
        'volunteer_assigned': (
          'معك أنت',
          const Color(0xFFECE8FF),
          const Color(0xFF6651B5)
        ),
        'picked_up_from_donor': (
          'استلمت من المتبرع',
          const Color(0xFFE5F2FF),
          const Color(0xFF2F6DA5)
        ),
        'in_transit': (
          'في الطريق للجمعية',
          const Color(0xFFFFF3E0),
          const Color(0xFFE28B00)
        ),
        'completed': ('تم التوصيل', const Color(0xFFE3F7EC), _green),
      }[status] ??
      ('قيد المتابعة', const Color(0xFFF0F1F0), Colors.black54);

  String _statusLabel(String status) => _statusData(status).$1;

  Widget _timeline() {
    const stages = [
      'accepted',
      'volunteer_assigned',
      'picked_up_from_donor',
      'in_transit',
      'completed'
    ];
    final current = stages.indexOf(_status);
    // ✅ إذا كانت الحالة غير موجودة في القائمة، استخدم 0
    final activeIndex = current >= 0 ? current : 0;

    return _card(
      title: 'خط سير التبرع',
      icon: Icons.route_rounded,
      child: Column(
        children: List.generate(stages.length, (index) {
          final isPast = index < activeIndex;
          final isCurrent = index == activeIndex;

          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(
              width: 30,
              child: Column(children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: isPast
                        ? _green
                        : (isCurrent ? _mint : Colors.grey.shade200),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isCurrent
                          ? _green
                          : (isPast ? _green : Colors.transparent),
                      width: isCurrent ? 3 : 1,
                    ),
                  ),
                  child: Icon(
                    isPast
                        ? Icons.check_rounded
                        : (isCurrent ? Icons.circle : Icons.circle),
                    size: isPast ? 14 : (isCurrent ? 10 : 8),
                    color: isPast
                        ? Colors.white
                        : (isCurrent ? _green : Colors.grey.shade400),
                  ),
                ),
                if (index < stages.length - 1)
                  Container(
                    width: 2,
                    height: 28,
                    color: isPast ? _green : Colors.grey.shade200,
                  ),
              ]),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 2, bottom: 12),
                child: Text(
                  _stageLabel(stages[index]),
                  style: TextStyle(
                    color:
                        isPast || isCurrent ? _darkGreen : Colors.grey.shade400,
                    fontWeight:
                        isPast || isCurrent ? FontWeight.w800 : FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ]);
        }),
      ),
    );
  }

  String _stageLabel(String stage) =>
      {
        'accepted': 'الجمعية قبلت التبرع',
        'volunteer_assigned': 'تم حجزك كمندوب',
        'picked_up_from_donor': 'استلمت التبرع من المتبرع',
        'in_transit': 'في الطريق للجمعية',
        'completed': 'وصل التبرع للجمعية 🎉',
      }[stage] ??
      stage;
}
