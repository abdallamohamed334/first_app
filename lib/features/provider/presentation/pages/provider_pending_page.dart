// lib/features/provider/presentation/pages/provider_pending_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:loqma/core/services/auth_state_notifier.dart';
import 'package:loqma/features/provider/data/repositories/service_provider_repository.dart';
import 'package:loqma/routes/app_router.dart';

class ProviderPendingPage extends StatefulWidget {
  final Map<String, dynamic>? provider;

  const ProviderPendingPage({super.key, this.provider});

  @override
  State<ProviderPendingPage> createState() => _ProviderPendingPageState();
}

class _ProviderPendingPageState extends State<ProviderPendingPage> {
  static const _bg = Color(0xFFF4F8F6);
  static const _bgDark = Color(0xFFE6F0EA);
  static const _primary = Color(0xFF0B7650);
  static const _blue = Color(0xFF3679C8);
  static const _ink = Color(0xFF123F31);
  static const _inkSoft = Color(0xFF315A45);
  static const _cardBg = Colors.white;
  static const _orange = Color(0xFFE28B00);
  static const _red = Color(0xFFD64545);
  static const _whatsapp = Color(0xFF25D366);

  static const _supportPhoneLocal = '01040652783';
  static const _supportPhoneIntl = '201040652783';

  final _repo = ServiceProviderRepository();

  Map<String, dynamic>? _provider;
  bool _refreshing = false;
  String _status = 'pending';
  bool _isActive = true;

  @override
  void initState() {
    super.initState();
    _provider = widget.provider;
    _status = _provider?['verification_status']?.toString() ?? 'pending';
    _isActive = _provider?['is_active'] as bool? ?? true;

    // ✅ بس لما يكون في auth session (يعني المستخدم فاتح من جوه التطبيق)
    // مش هنعمل refresh لو جاي من extra
  }

  Future<void> _refresh() async {
    setState(() => _refreshing = true);
    final result = await _repo.getCurrentProvider();

    if (!mounted) return;

    result.fold(
      (err) {
        setState(() => _refreshing = false);
      },
      (data) {
        final newStatus = data['verification_status']?.toString() ?? 'pending';
        final newIsActive = data['is_active'] as bool? ?? true;

        setState(() {
          _provider = data;
          _status = newStatus;
          _isActive = newIsActive;
          _refreshing = false;
        });

        AuthStateNotifier.instance.setLoggedIn(
          isLoggedIn: true,
          role: 'provider',
          providerStatus: newStatus,
          isActive: newIsActive,
        );

        if (newStatus == 'approved' && newIsActive) {
          _snack('تم قبول حسابك 🎉');
          Future.delayed(const Duration(milliseconds: 600), () {
            if (mounted) context.go(AppRouter.providerHome);
          });
        }
      },
    );
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(msg, textDirection: TextDirection.rtl),
          backgroundColor: error ? _red : _primary,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'تسجيل الخروج',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          content: const Text('متأكد إنك عايز تسجل خروج؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: FilledButton.styleFrom(backgroundColor: _red),
              child: const Text('خروج'),
            ),
          ],
        ),
      ),
    );

    if (confirm != true) return;

    try {
      await _repo.logout();
    } catch (_) {}

    AuthStateNotifier.instance.clear();
    if (!mounted) return;
    context.go(AppRouter.providerAuth);
  }

  Future<void> _openSupportWhatsApp() async {
    final name = _provider?['display_name']?.toString() ?? 'مزود خدمة';

    final message = 'مرحباً فريق جُود 👋\n\n'
        'أنا مزود خدمة (${name})\n'
        'حسابي $_statusLabel، وعايز أعرف السبب وأحل المشكلة.';

    final url = Uri.parse(
      'https://wa.me/$_supportPhoneIntl?text=${Uri.encodeComponent(message)}',
    );

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        _copySupportNumber();
      }
    } catch (e) {
      debugPrint('❌ whatsapp error: $e');
      _copySupportNumber();
    }
  }

  void _copySupportNumber() {
    Clipboard.setData(const ClipboardData(text: _supportPhoneLocal));
    _snack('تم نسخ رقم الدعم: $_supportPhoneLocal');
  }

  String get _statusLabel {
    if (!_isActive) return 'موقوف';
    switch (_status) {
      case 'suspended':
        return 'موقوف';
      case 'rejected':
        return 'مرفوض';
      case 'pending':
        return 'قيد المراجعة';
      case 'approved':
        return 'معتمد';
      default:
        return _status;
    }
  }

  bool get _needsSupport =>
      !_isActive || _status == 'suspended' || _status == 'rejected';

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _bg,
        body: AnnotatedRegion(
          value: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
          ),
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [_bg, _bgDark],
              ),
            ),
            child: SafeArea(
              child: RefreshIndicator(
                onRefresh: _refresh,
                color: _blue,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: _logout,
                          icon: const Icon(Icons.logout_rounded,
                              size: 16, color: _inkSoft),
                          label: const Text(
                            'تسجيل خروج',
                            style: TextStyle(
                              color: _inkSoft,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Center(child: _statusIcon()),
                      const SizedBox(height: 24),
                      Text(
                        _titleText,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: _ink,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _subtitleText,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _inkSoft.withValues(alpha: 0.75),
                          fontSize: 13.5,
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: 28),
                      if (_provider != null) _providerInfoCard(),
                      const SizedBox(height: 18),
                      _statusCard(),
                      if (_needsSupport) ...[
                        const SizedBox(height: 16),
                        _supportCard(),
                      ],
                      const SizedBox(height: 20),
                      if (!_needsSupport) ...[
                        SizedBox(
                          height: 52,
                          child: OutlinedButton.icon(
                            onPressed: _refreshing ? null : _refresh,
                            icon: _refreshing
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: _blue,
                                    ),
                                  )
                                : const Icon(Icons.refresh_rounded),
                            label: const Text(
                              'تحديث الحالة',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _blue,
                              side: BorderSide(
                                color: _blue.withValues(alpha: 0.4),
                                width: 1.5,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                      if (!_needsSupport) _supportInfoBox(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _statusIcon() {
    IconData icon;
    Color color;

    if (!_isActive) {
      icon = Icons.block_rounded;
      color = _red;
    } else {
      switch (_status) {
        case 'approved':
          icon = Icons.check_circle_rounded;
          color = _primary;
          break;
        case 'rejected':
          icon = Icons.cancel_rounded;
          color = _red;
          break;
        case 'suspended':
          icon = Icons.block_rounded;
          color = _red;
          break;
        default:
          icon = Icons.hourglass_top_rounded;
          color = _orange;
      }
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 140,
          height: 140,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 0.08),
          ),
        ),
        Container(
          width: 110,
          height: 110,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 0.15),
          ),
        ),
        Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color.withValues(alpha: 0.8), color],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.35),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 42),
        ),
        if (_status == 'pending' && _isActive)
          Positioned(
            bottom: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _orange,
                borderRadius: BorderRadius.circular(100),
                boxShadow: [
                  BoxShadow(
                    color: _orange.withValues(alpha: 0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Text(
                'قيد المراجعة',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
      ],
    );
  }

  String get _titleText {
    if (!_isActive) return 'حسابك موقوف';
    switch (_status) {
      case 'approved':
        return 'تم قبول حسابك 🎉';
      case 'rejected':
        return 'تم رفض حسابك';
      case 'suspended':
        return 'حسابك موقوف';
      default:
        return 'طلبك قيد المراجعة';
    }
  }

  String get _subtitleText {
    if (!_isActive) {
      return 'حسابك موقوف حالياً. تواصل مع فريق الدعم على الواتساب لحل المشكلة.';
    }
    switch (_status) {
      case 'approved':
        return 'أهلاً بيك في جُود! يمكنك الآن استقبال الطلبات.';
      case 'rejected':
        return 'للأسف، لم يتم قبول طلبك. تواصل مع فريق الدعم على الواتساب لمعرفة السبب.';
      case 'suspended':
        return 'حسابك موقوف مؤقتاً. تواصل مع فريق الدعم على الواتساب.';
      default:
        return 'فريق جُود بيراجع بياناتك حالياً.\n'
            'هيتم إشعارك أول ما يتم القبول.\n'
            'ده بياخد عادة 24-48 ساعة.';
    }
  }

  Widget _providerInfoCard() {
    final name = _provider?['display_name']?.toString() ?? '';
    final phone = _provider?['phone']?.toString() ?? '';
    final type = _provider?['provider_type']?.toString() ?? '';
    final cat = _provider?['categories'];
    final catName = cat is Map ? cat['name_ar']?.toString() ?? '' : '';

    if (name.isEmpty && phone.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _inkSoft.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: _inkSoft.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          if (name.isNotEmpty) _row('الاسم', name),
          if (catName.isNotEmpty) _row('التصنيف', catName),
          if (phone.isNotEmpty) _row('الهاتف', phone),
          if (type.isNotEmpty)
            _row('النوع', type == 'individual' ? 'فرد' : 'شركة'),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              color: _inkSoft.withValues(alpha: 0.7),
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              color: _ink,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusCard() {
    final color = _needsSupport ? _red : _orange;

    String text;
    if (!_isActive) {
      text = 'مش هتقدر تستخدم التطبيق لحد ما يتم حل المشكلة. '
          'كلّم الدعم على الواتساب.';
    } else if (_status == 'rejected') {
      text = 'طلبك اترفض. ممكن تعرف السبب من فريق الدعم.';
    } else if (_status == 'suspended') {
      text = 'حسابك موقوف مؤقتاً. تواصل مع الدعم لمعرفة السبب.';
    } else {
      text = 'مش هتقدر تستقبل طلبات لحد ما يتم القبول. '
          'هيتم إشعارك بمجرد الموافقة.';
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: _inkSoft.withValues(alpha: 0.9),
                fontSize: 12,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _supportCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _whatsapp.withValues(alpha: 0.95),
            const Color(0xFF128C7E),
          ],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _whatsapp.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.headset_mic_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'تواصل مع الدعم',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'فريق جُود جاهز يساعدك',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _openSupportWhatsApp,
              icon: const Icon(Icons.chat_rounded, size: 20),
              label: const Text(
                'كلّمنا على واتساب',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: _whatsapp,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: _copySupportNumber,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.copy_rounded, color: Colors.white, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    _supportPhoneLocal,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
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

  Widget _supportInfoBox() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _blue.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.headset_mic_rounded, color: _blue, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'محتاج مساعدة؟',
                  style: TextStyle(
                    color: _ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'تواصل مع فريق جُود على الرقم $_supportPhoneLocal',
                  style: TextStyle(
                    color: _inkSoft.withValues(alpha: 0.8),
                    fontSize: 11.5,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
