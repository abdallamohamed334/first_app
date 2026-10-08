// lib/features/community/presentation/pages/community_charity_donation_details_page.dart

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
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
  bool _updatingStatus = false;
  String? _localStatus;

  // ─────────────── الألوان ───────────────
  static const _green = Color(0xFF0B7650);
  static const _darkGreen = Color(0xFF0F2E23);
  static const _background = Color(0xFFF5F9F7);
  static const _orange = Color(0xFFE28B00);
  static const _blue = Color(0xFF3679C8);
  static const _red = Color(0xFFB54747);
  static const _purple = Color(0xFF6651B5);

  Map<String, dynamic> get donation => widget.donation;
  String get status =>
      _localStatus ?? donation['status']?.toString() ?? 'pending';

  /// ✅ نوع التوصيل
  String get _deliveryType =>
      donation['delivery_type']?.toString() ?? 'charity_volunteer';

  bool get _isIndependentVolunteer => _deliveryType == 'independent_volunteer';

  /// ✅ بيانات المندوب
  String get _volunteerName =>
      donation['volunteer_name']?.toString().trim() ?? '';
  String get _volunteerPhone =>
      donation['volunteer_phone']?.toString().trim() ?? '';
  bool get _hasVolunteer =>
      _volunteerName.isNotEmpty || _volunteerPhone.isNotEmpty;

  // ═══════════════════════════════════════════════════════════
  // ACTIONS
  // ═══════════════════════════════════════════════════════════

  /// ✅ المتبرع يعلن جاهزيته (ويعتبر موافقة على المسار)
  Future<void> _markReady() async {
    if (_markingReady) return;
    setState(() => _markingReady = true);
    try {
      await _repository.markDonorReady(donation['id'].toString());
      if (mounted) {
        setState(() => _localStatus = 'donor_ready');
        _message(
          'تم تسجيل جاهزيتك وموافقتك على المسار. سيتم إشعارك عند تعيين مندوب.',
          success: true,
        );
      }
    } catch (error) {
      if (mounted) _message('تعذر تسجيل الجاهزية: $error');
    } finally {
      if (mounted) setState(() => _markingReady = false);
    }
  }

  /// ✅ المتبرع يقول "أنا في الطريق للجمعية" (fallback)
  Future<void> _markInTransit() async {
    if (_updatingStatus) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Row(
          children: [
            Icon(Icons.local_shipping_rounded, color: _orange),
            SizedBox(width: 8),
            Text('أنا في الطريق للجمعية'),
          ],
        ),
        content: const Text(
          'هل أنت متأكد أن التبرع في طريقه للجمعية الآن؟\n'
          'هيتم إشعار الجمعية، وهي اللي هتأكد الاستلام بالكود.',
          style: TextStyle(fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _orange),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('نعم، في الطريق'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _updatingStatus = true);
    try {
      // ✅ الدالة الجديدة المخصصة للمتبرع
      await _repository.donorMarkInTransit(donation['id'].toString());
      if (!mounted) return;
      setState(() => _localStatus = 'in_transit');
      _message('🚚 تم تسجيل أن التبرع في الطريق للجمعية', success: true);
    } catch (error) {
      if (mounted) {
        final msg = error.toString().replaceFirst('Exception: ', '');
        _message(msg.isNotEmpty ? msg : 'تعذر تحديث الحالة');
      }
    } finally {
      if (mounted) setState(() => _updatingStatus = false);
    }
  }

  /// ✅ عرض كود التسليم
  Future<void> _showCode() async {
    if (_loadingCode) return;
    setState(() => _loadingCode = true);
    try {
      final code = await _repository.getPickupCode(donation['id'].toString());
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Row(
            children: [
              Icon(Icons.qr_code_2_rounded, color: _green),
              SizedBox(width: 8),
              Text('كود تسليم التبرع'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'اعرض الكود للمندوب فقط عند استلام التبرع.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 18,
                ),
                decoration: BoxDecoration(
                  color: _green.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _green.withValues(alpha: 0.25),
                    width: 1.5,
                  ),
                ),
                child: SelectableText(
                  code,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _green,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.access_time_rounded,
                    size: 14,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'الكود صالح لمدة 7 أيام',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                style: FilledButton.styleFrom(
                  backgroundColor: _green,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'تم',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      );
    } catch (error) {
      if (mounted) _message('تعذر عرض الكود: $error');
    } finally {
      if (mounted) setState(() => _loadingCode = false);
    }
  }

  /// ✅ اتصال بالمندوب
  Future<void> _callVolunteer() async {
    if (_volunteerPhone.isEmpty) {
      _message('رقم الهاتف غير متاح');
      return;
    }
    try {
      final uri = Uri.parse('tel:$_volunteerPhone');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        _message('تعذر فتح تطبيق الاتصال');
      }
    } catch (_) {
      _message('تعذر الاتصال بالمندوب');
    }
  }

  /// ✅ واتساب
  Future<void> _whatsappVolunteer() async {
    if (_volunteerPhone.isEmpty) {
      _message('رقم الواتساب غير متاح');
      return;
    }
    try {
      final cleanPhone = _volunteerPhone.replaceAll(RegExp(r'[^0-9]'), '');
      final uri = Uri.parse('https://wa.me/$cleanPhone');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        _message('تعذر فتح واتساب');
      }
    } catch (_) {
      _message('تعذر فتح واتساب');
    }
  }

  // ═══════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final charity = donation['charities'] is Map
        ? Map<String, dynamic>.from(donation['charities'] as Map)
        : <String, dynamic>{};
    final title = donation['title']?.toString() ?? 'تبرع مباشر';
    final address =
        donation['pickup_address']?.toString() ?? 'العنوان غير مضاف';

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _background,
        appBar: AppBar(
          title: const Text(
            'تفاصيل التبرع',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          backgroundColor: _background,
          foregroundColor: _darkGreen,
          elevation: 0,
          centerTitle: true,
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
          children: [
            // Hero Card
            _buildHeroCard(title),

            // Images
            if (_imageUrls().isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildImagesSection(),
            ],

            const SizedBox(height: 16),

            // Info Cards
            _buildInfoCard(
              icon: Icons.volunteer_activism_outlined,
              label: 'الجمعية المستفيدة',
              value: charity['name']?.toString() ?? 'جمعية موثقة',
              sub: charity['address']?.toString() ?? 'العنوان غير متاح',
              color: _green,
            ),
            const SizedBox(height: 10),
            _buildInfoCard(
              icon: Icons.location_on_outlined,
              label: 'مكان استلام التبرع',
              value: address,
              sub: 'الكمية: ${donation['quantity'] ?? 1}',
              color: _blue,
            ),

            // ✅ بيانات المندوب (بطاقة مميزة مع أزرار)
            if (_hasVolunteer) ...[
              const SizedBox(height: 10),
              _buildVolunteerCard(),
            ],

            const SizedBox(height: 24),

            // Timeline
            const Text(
              'خط سير التبرع',
              style: TextStyle(
                color: _darkGreen,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            _buildTimeline(),

            // Actions
            _buildActions(),

            // Completed Box
            if (status == 'completed') ...[
              const SizedBox(height: 16),
              _buildSuccessBox(),
            ],

            // Rejected Box
            if (status == 'rejected') ...[
              const SizedBox(height: 16),
              _buildRejectedBox(),
            ],
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // VOLUNTEER CARD
  // ═══════════════════════════════════════════════════════════

  Widget _buildVolunteerCard() {
    final color = _isIndependentVolunteer ? _purple : _orange;
    final roleLabel =
        _isIndependentVolunteer ? 'المتطوع المستقل' : 'مندوب الجمعية';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
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
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isIndependentVolunteer
                      ? Icons.person_rounded
                      : Icons.badge_outlined,
                  color: color,
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      roleLabel,
                      style: TextStyle(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _volunteerName.isNotEmpty
                          ? _volunteerName
                          : 'الاسم غير مسجل',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _darkGreen,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _volunteerPhone.isNotEmpty
                          ? _volunteerPhone
                          : 'الرقم غير متاح',
                      style: const TextStyle(
                        color: Color(0xFF71837C),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_volunteerPhone.isNotEmpty) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _callVolunteer,
                    icon: const Icon(Icons.phone_rounded, size: 18),
                    label: const Text(
                      'اتصال',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _green,
                      side: const BorderSide(color: _green, width: 1.4),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _whatsappVolunteer,
                    icon: const Icon(Icons.chat_rounded, size: 18),
                    label: const Text(
                      'واتساب',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // ACTIONS
  // ═══════════════════════════════════════════════════════════

  Widget _buildActions() {
    // ✅ accepted أو volunteer_needed → بطاقة المسار + زر "أنا جاهز"
    if (status == 'accepted' || status == 'volunteer_needed') {
      return Padding(
        padding: const EdgeInsets.only(top: 20),
        child: Column(
          children: [
            // ✅ بطاقة الموافقة على المسار
            _buildRouteApprovalCard(),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _markingReady ? null : _markReady,
                icon: _markingReady
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_circle_rounded, size: 20),
                label: Text(
                  _markingReady
                      ? 'جارٍ تسجيل الموافقة...'
                      : '✅ أوافق على المسار وأنا جاهز',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: _green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // ✅ donor_ready أو volunteer_assigned → زر "عرض الكود"
    if (status == 'donor_ready' || status == 'volunteer_assigned') {
      return Padding(
        padding: const EdgeInsets.only(top: 20),
        child: Column(
          children: [
            _buildInstructionBox(
              status == 'donor_ready'
                  ? 'أنت جاهز للتسليم. سيتم إشعارك عند وصول المندوب.'
                  : 'المندوب في الطريق. عند وصوله، اعرض الكود للمندوب.',
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _loadingCode ? null : _showCode,
                icon: _loadingCode
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.qr_code_2_rounded, size: 20),
                label: Text(
                  _loadingCode
                      ? 'جارٍ تجهيز الكود...'
                      : 'عرض كود التسليم للمندوب',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: _green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // ✅ picked_up_from_donor → banner + زر "أنا في الطريق" (fallback)
    if (status == 'picked_up_from_donor') {
      return Padding(
        padding: const EdgeInsets.only(top: 20),
        child: Column(
          children: [
            _buildInfoBanner(
              icon: Icons.verified_user_rounded,
              color: _blue,
              title: 'تم استلام تبرعك',
              subtitle:
                  'المندوب استلم تبرعك. لو مش قادر يعلّمها من عنده، دوس الزرار ده.',
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _updatingStatus ? null : _markInTransit,
                icon: _updatingStatus
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.local_shipping_rounded, size: 20),
                label: Text(
                  _updatingStatus
                      ? 'جارٍ التحديث...'
                      : '🚚 التبرع في الطريق للجمعية',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: _orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // ✅ in_transit → "التبرع في الطريق"
    if (status == 'in_transit') {
      return Padding(
        padding: const EdgeInsets.only(top: 20),
        child: _buildInfoBanner(
          icon: Icons.local_shipping_rounded,
          color: _orange,
          title: 'التبرع في الطريق',
          subtitle: 'التبرع في طريقه للجمعية. شكراً لصبرك!',
        ),
      );
    }

    // ✅ pending → "في انتظار الجمعية"
    if (status == 'pending') {
      return Padding(
        padding: const EdgeInsets.only(top: 20),
        child: _buildInfoBanner(
          icon: Icons.hourglass_top_rounded,
          color: _orange,
          title: 'في انتظار مراجعة الجمعية',
          subtitle: 'الجمعية هتراجع التبرع وهترد عليك قريب.',
        ),
      );
    }

    return const SizedBox.shrink();
  }

  // ═══════════════════════════════════════════════════════════
  // ROUTE APPROVAL CARD
  // ═══════════════════════════════════════════════════════════

  Widget _buildRouteApprovalCard() {
    final isIndependent = _deliveryType == 'independent_volunteer';
    final routeLabel = isIndependent
        ? '🤝 توصيل عبر متطوع مستقل'
        : '🚚 توصيل عبر مندوب الجمعية';
    final routeDesc = isIndependent
        ? 'الجمعية فتحت التبرع للمتطوعين المستقلين. أول متطوع يقبله هيوصله.'
        : 'الجمعية هتوصّل التبرع مندوبها من عندها.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _green.withValues(alpha: 0.25),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: _green.withValues(alpha: 0.06),
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
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _green.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.route_rounded,
                  color: _green,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'مسار التوصيل',
                  style: TextStyle(
                    color: _darkGreen,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _green.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _green.withValues(alpha: 0.15)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  routeLabel,
                  style: const TextStyle(
                    color: _darkGreen,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  routeDesc,
                  style: const TextStyle(
                    color: Color(0xFF4A6B5C),
                    fontSize: 12.5,
                    height: 1.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: _orange.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _orange.withValues(alpha: 0.2)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: _orange,
                  size: 18,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'بالموافقة، أنت تسمح للجمعية تختار الطريقة الأنسب لتوصيل تبرعك.',
                    style: TextStyle(
                      color: Color(0xFF805B1B),
                      fontSize: 11.5,
                      height: 1.5,
                      fontWeight: FontWeight.w700,
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
  // HERO CARD
  // ═══════════════════════════════════════════════════════════

  Widget _buildHeroCard(String title) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_darkGreen, _green],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _darkGreen.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                  _isIndependentVolunteer
                      ? Icons.people_alt_rounded
                      : Icons.lock_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isIndependentVolunteer
                          ? 'تبرع مفتوح للمتطوعين'
                          : 'تبرع خاص وآمن',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildStatusBadge(status),
              if (_isIndependentVolunteer) ...[
                const SizedBox(width: 8),
                _buildDeliveryBadge(),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _statusLabel(status),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: _purple.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
        ),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.people_alt_rounded,
            color: Colors.white,
            size: 12,
          ),
          SizedBox(width: 4),
          Text(
            'متطوعين',
            style: TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // IMAGES
  // ═══════════════════════════════════════════════════════════

  List<String> _imageUrls() {
    final raw = donation['images'];
    if (raw is! List) return const [];
    return raw
        .map((value) => value.toString())
        .where((url) => url.startsWith('http'))
        .toList();
  }

  Widget _buildImagesSection() {
    final images = _imageUrls();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE8F1EC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.photo_library_outlined,
                  color: _green,
                  size: 17,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'صور التبرع',
                style: TextStyle(
                  color: _darkGreen,
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
              const Spacer(),
              Text(
                '${images.length}',
                style: const TextStyle(
                  color: _green,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 140,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: images.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, index) => ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.network(
                  images[index],
                  width: 160,
                  height: 140,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 160,
                    height: 140,
                    color: _green.withValues(alpha: 0.08),
                    child: const Icon(
                      Icons.broken_image_outlined,
                      color: _green,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // INFO CARD
  // ═══════════════════════════════════════════════════════════

  Widget _buildInfoCard({
    required IconData icon,
    required String label,
    required String value,
    required String sub,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8F1EC)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF71837C),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _darkGreen,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  sub,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF71837C),
                    fontSize: 11,
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
  // TIMELINE
  // ═══════════════════════════════════════════════════════════

  Widget _buildTimeline() {
    final steps = <(String, String, IconData)>[
      ('pending', 'أرسلت التبرع', Icons.send_rounded),
      if (_isIndependentVolunteer) ...[
        ('volunteer_needed', 'مفتوح للمتطوعين', Icons.people_alt_rounded),
      ] else ...[
        ('accepted', 'وافقت الجمعية', Icons.fact_check_outlined),
      ],
      ('donor_ready', 'أعلنت جاهزيتك', Icons.front_hand_rounded),
      ('volunteer_assigned', 'تم تعيين المندوب', Icons.badge_outlined),
      ('picked_up_from_donor', 'استلم المندوب', Icons.verified_user_outlined),
      ('in_transit', 'في الطريق', Icons.local_shipping_rounded),
      ('completed', 'وصل للجمعية', Icons.done_all_rounded),
    ];

    int current;
    if (_isIndependentVolunteer) {
      current = switch (status) {
        'pending' => 0,
        'volunteer_needed' => 1,
        'donor_ready' => 2,
        'volunteer_assigned' => 3,
        'picked_up_from_donor' => 4,
        'in_transit' => 5,
        'completed' => 6,
        _ => 0,
      };
    } else {
      current = switch (status) {
        'pending' => 0,
        'accepted' => 1,
        'donor_ready' => 2,
        'volunteer_assigned' => 3,
        'picked_up_from_donor' => 4,
        'in_transit' => 5,
        'completed' => 6,
        _ => 0,
      };
    }

    final activeColor = _statusColor(status);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE8F1EC)),
      ),
      child: Column(
        children: List.generate(steps.length, (i) {
          final active = i <= current;
          final last = i == steps.length - 1;

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: active ? activeColor : const Color(0xFFE5EEE9),
                      shape: BoxShape.circle,
                      boxShadow: active
                          ? [
                              BoxShadow(
                                color: activeColor.withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ]
                          : null,
                    ),
                    child: Icon(
                      steps[i].$3,
                      color: active ? Colors.white : const Color(0xFF9AACA3),
                      size: 17,
                    ),
                  ),
                  if (!last)
                    Container(
                      width: 3,
                      height: 32,
                      color:
                          i < current ? activeColor : const Color(0xFFE5EEE9),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  steps[i].$2,
                  style: TextStyle(
                    color: active ? _darkGreen : const Color(0xFF98A9A1),
                    fontSize: 13,
                    fontWeight: active ? FontWeight.w900 : FontWeight.w500,
                  ),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // BOXES
  // ═══════════════════════════════════════════════════════════

  Widget _buildSuccessBox() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE5F7EC), Color(0xFFD1F0DE)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFBFE3CE)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _green.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.verified_rounded,
              color: _green,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '🎉 تم وصول التبرع',
                  style: TextStyle(
                    color: _darkGreen,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'شكراً لك! تمت إضافة نقاط الأثر لحسابك.',
                  style: TextStyle(
                    color: Color(0xFF4A6B5C),
                    fontSize: 12,
                    height: 1.4,
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

  Widget _buildRejectedBox() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _red.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _red.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _red.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.cancel_rounded,
              color: _red,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'تم رفض التبرع',
                  style: TextStyle(
                    color: _darkGreen,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'الجمعية مش قادرة تستقبل التبرع حاليًا. جرّب جمعية تانية.',
                  style: TextStyle(
                    color: Color(0xFF7B4747),
                    fontSize: 12,
                    height: 1.4,
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

  Widget _buildInfoBanner({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: color.withValues(alpha: 0.85),
                    fontSize: 12,
                    height: 1.4,
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

  Widget _buildInstructionBox(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _orange.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
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
            child: Text(
              text,
              style: TextStyle(
                color: _orange.withValues(alpha: 0.95),
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════

  String _statusLabel(String value) =>
      <String, String>{
        'pending': 'في انتظار الجمعية',
        'accepted': 'وافقت الجمعية — أعلن جاهزيتك',
        'volunteer_needed': 'مفتوح للمتطوعين',
        'donor_ready': 'جاهز للتسليم',
        'volunteer_assigned': 'في انتظار المندوب',
        'picked_up_from_donor': 'تم استلام التبرع',
        'in_transit': 'في الطريق للجمعية',
        'completed': 'وصل للجمعية',
        'rejected': 'مرفوض',
        'cancelled': 'ملغي',
        'expired': 'منتهي',
      }[value] ??
      'جارٍ تحديث الحالة';

  Color _statusColor(String status) {
    if (status == 'rejected' || status == 'cancelled' || status == 'expired') {
      return _red;
    }
    if (status == 'completed') return _green;
    if (status == 'volunteer_needed') return _purple;
    if (status == 'volunteer_assigned') return _orange;
    if (status == 'accepted') return _blue;
    if (status == 'donor_ready') return _blue;
    if (status == 'picked_up_from_donor' || status == 'in_transit') {
      return _orange;
    }
    return _green;
  }

  void _message(String text, {bool success = false}) =>
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
