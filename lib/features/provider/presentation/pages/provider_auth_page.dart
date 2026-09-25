// lib/features/provider/presentation/pages/provider_auth_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:loqma/core/services/auth_state_notifier.dart';
import 'package:loqma/features/provider/data/repositories/service_provider_repository.dart';
import 'package:loqma/features/provider/presentation/utils/service_category_icons.dart';
import 'package:loqma/routes/app_router.dart';

class ProviderAuthPage extends StatefulWidget {
  const ProviderAuthPage({super.key});

  @override
  State<ProviderAuthPage> createState() => _ProviderAuthPageState();
}

class _ProviderAuthPageState extends State<ProviderAuthPage>
    with SingleTickerProviderStateMixin {
  // ── ألوان
  static const _bg = Color(0xFFF4F8F6);
  static const _bgDark = Color(0xFFE6F0EA);
  static const _primary = Color(0xFF0B7650);
  static const _blue = Color(0xFF3679C8);
  static const _ink = Color(0xFF123F31);
  static const _inkSoft = Color(0xFF315A45);
  static const _cardBg = Colors.white;
  static const _error = Color(0xFFD64545);
  static const _whatsapp = Color(0xFF25D366);

  static const _supportPhoneLocal = '01040652783';
  static const _supportPhoneIntl = '201040652783';

  late final TabController _tabController;
  final _repo = ServiceProviderRepository();

  // Login
  final _loginPhone = TextEditingController();

  // Register
  final _regName = TextEditingController();
  final _regPhone = TextEditingController();

  String? _regProviderType = 'individual';
  String? _selectedCategoryId;

  // Categories
  List<Map<String, dynamic>> _categories = [];
  bool _loadingCategories = false;

  // States
  bool _loading = false;
  String? _errorMessage;

  bool _showSwitchToRegister = false;
  bool _showSwitchToLogin = false;
  bool _showSupportButton = false;

  final _loginKey = GlobalKey<FormState>();
  final _registerKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _loadCategories();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _loginPhone.dispose();
    _regName.dispose();
    _regPhone.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════════════════════════
  // Helpers
  // ══════════════════════════════════════════════════════════
  void _clearError() {
    if (_errorMessage == null &&
        !_showSwitchToRegister &&
        !_showSwitchToLogin &&
        !_showSupportButton) {
      return;
    }
    setState(() {
      _errorMessage = null;
      _showSwitchToRegister = false;
      _showSwitchToLogin = false;
      _showSupportButton = false;
    });
  }

  void _safeBack() {
    if (_loading) return;
    FocusScope.of(context).unfocus();
    context.go(AppRouter.userTypeSelection);
  }

  void _switchTab(int index) {
    FocusScope.of(context).unfocus();
    setState(() {
      _errorMessage = null;
      _showSwitchToRegister = false;
      _showSwitchToLogin = false;
      _showSupportButton = false;
    });
    _tabController.animateTo(index);
  }

  /// ✅ يروح لصفحة Pending
  void _goToPendingPage(Map<String, dynamic> provider) {
    final status = provider['verification_status']?.toString() ?? 'pending';
    final isActive = provider['is_active'] as bool? ?? true;

    debugPrint(
      '🚫 [Provider] → PendingPage (status=$status, active=$isActive)',
    );

    // ✅ نحدّث الـ notifier
    AuthStateNotifier.instance.setLoggedIn(
      isLoggedIn: true,
      role: 'provider',
      providerStatus: status,
      isActive: isActive,
    );

    if (!mounted) return;
    setState(() => _loading = false);

    context.go(AppRouter.providerPending, extra: provider);
  }

  // ══════════════════════════════════════════════════════════
  // Support WhatsApp
  // ══════════════════════════════════════════════════════════
  Future<void> _openSupportWhatsApp() async {
    final phoneInput = _tabController.index == 0
        ? _loginPhone.text.trim()
        : _regPhone.text.trim();

    final msg = 'مرحباً فريق جُود 👋\n\n'
        'أنا مزود خدمة، رقمي: $phoneInput\n'
        'حسابي موقوف/مرفوض وعايز أعرف السبب وأحل المشكلة.';

    final url = Uri.parse(
      'https://wa.me/$_supportPhoneIntl?text=${Uri.encodeComponent(msg)}',
    );

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        _copySupportNumber();
      }
    } catch (_) {
      _copySupportNumber();
    }
  }

  void _copySupportNumber() {
    Clipboard.setData(const ClipboardData(text: _supportPhoneLocal));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            'تم نسخ رقم الدعم: $_supportPhoneLocal',
            textDirection: TextDirection.rtl,
          ),
          backgroundColor: _primary,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
  }

  // ══════════════════════════════════════════════════════════
  // تحميل التصنيفات
  // ══════════════════════════════════════════════════════════
  Future<void> _loadCategories() async {
    setState(() => _loadingCategories = true);
    final result = await _repo.getCategories(
      providerType: _regProviderType,
    );
    result.fold(
      (err) {
        debugPrint('⚠️ categories error: $err');
        if (mounted) setState(() => _loadingCategories = false);
      },
      (cats) {
        if (!mounted) return;
        setState(() {
          _categories = cats;
          _loadingCategories = false;
          if (_selectedCategoryId != null &&
              !cats.any((c) => c['id'] == _selectedCategoryId)) {
            _selectedCategoryId = null;
          }
        });
      },
    );
  }

  // ══════════════════════════════════════════════════════════
  // LOGIN — يفحص الحالة قبل OTP
  // ══════════════════════════════════════════════════════════
  Future<void> _handleLoginOtp() async {
    FocusScope.of(context).unfocus();
    if (!_loginKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _errorMessage = null;
      _showSwitchToRegister = false;
      _showSwitchToLogin = false;
      _showSupportButton = false;
    });

    final phone = _loginPhone.text.trim();

    // 1️⃣ هل الرقم مسجل؟
    final checkResult = await _repo.checkProviderByPhone(phone: phone);
    if (!mounted) return;

    Map<String, dynamic>? existingProvider;
    bool hasError = false;
    String? errorText;

    checkResult.fold(
      (err) {
        hasError = true;
        errorText = err;
      },
      (provider) => existingProvider = provider,
    );

    if (hasError) {
      setState(() {
        _loading = false;
        _errorMessage = errorText;
      });
      return;
    }

    // 2️⃣ الرقم مش مسجل
    if (existingProvider == null) {
      setState(() {
        _loading = false;
        _errorMessage = 'الرقم ده مش مسجل كمزود خدمة. اعمل حساب جديد الأول.';
        _showSwitchToRegister = true;
      });
      return;
    }

    // ══════════════════════════════════════════════════════════
    // 3️⃣ ✅ لو مش approved أو مش active → روح PendingPage فوراً
    // ══════════════════════════════════════════════════════════
    final status =
        existingProvider!['verification_status']?.toString() ?? 'pending';
    final isActive = existingProvider!['is_active'] as bool? ?? true;

    if (status != 'approved' || !isActive) {
      // ✅ روح PendingPage بدون إرسال OTP
      _goToPendingPage(existingProvider!);
      return;
    }

    // 4️⃣ approved + active → أرسل OTP
    final result = await _repo.sendProviderOtp(phone: phone);
    if (!mounted) return;

    result.fold(
      (err) {
        setState(() {
          _loading = false;
          _errorMessage = err;
        });
      },
      (returnedPhone) {
        setState(() => _loading = false);
        context.push(
          '${AppRouter.providerOtpVerify}'
          '?phone=${Uri.encodeComponent(returnedPhone)}'
          '&name='
          '&categoryId='
          '&providerType=',
        );
      },
    );
  }

  // ══════════════════════════════════════════════════════════
  // REGISTER — يفحص الحالة قبل OTP
  // ══════════════════════════════════════════════════════════
  Future<void> _handleRegisterOtp() async {
    FocusScope.of(context).unfocus();
    if (!_registerKey.currentState!.validate()) return;

    if (_selectedCategoryId == null || _selectedCategoryId!.isEmpty) {
      setState(() => _errorMessage = 'اختار التصنيف');
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
      _showSwitchToRegister = false;
      _showSwitchToLogin = false;
      _showSupportButton = false;
    });

    final phone = _regPhone.text.trim();

    // 1️⃣ هل الرقم مسجل؟
    final checkResult = await _repo.checkProviderByPhone(phone: phone);
    if (!mounted) return;

    Map<String, dynamic>? existingProvider;
    bool hasError = false;
    String? errorText;

    checkResult.fold(
      (err) {
        hasError = true;
        errorText = err;
      },
      (provider) => existingProvider = provider,
    );

    if (hasError) {
      setState(() {
        _loading = false;
        _errorMessage = errorText;
      });
      return;
    }

    // ══════════════════════════════════════════════════════════
    // 2️⃣ ✅ لو الرقم مسجل بالفعل → روح PendingPage فوراً
    // ══════════════════════════════════════════════════════════
    if (existingProvider != null) {
      _goToPendingPage(existingProvider!);
      return;
    }

    // 3️⃣ الرقم جديد → أرسل OTP
    final result = await _repo.sendProviderOtp(phone: phone);
    if (!mounted) return;

    result.fold(
      (err) {
        setState(() {
          _loading = false;
          _errorMessage = err;
        });
      },
      (returnedPhone) {
        setState(() => _loading = false);
        context.push(
          '${AppRouter.providerOtpVerify}'
          '?phone=${Uri.encodeComponent(returnedPhone)}'
          '&name=${Uri.encodeComponent(_regName.text.trim())}'
          '&categoryId=${Uri.encodeComponent(_selectedCategoryId!)}'
          '&providerType=${Uri.encodeComponent(_regProviderType ?? 'individual')}',
        );
      },
    );
  }

  // ══════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: PopScope(
        canPop: !_loading,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          _safeBack();
        },
        child: Scaffold(
          backgroundColor: _bg,
          body: AnnotatedRegion<SystemUiOverlayStyle>(
            value: const SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: Brightness.dark,
              statusBarBrightness: Brightness.light,
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
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        alignment: Alignment.centerRight,
                        child: IconButton(
                          onPressed: _loading ? null : _safeBack,
                          icon: const Icon(
                            Icons.arrow_forward_rounded,
                            color: _ink,
                          ),
                        ),
                      ),

                      // Icon
                      Center(
                        child: Container(
                          width: 78,
                          height: 78,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _cardBg,
                            borderRadius: BorderRadius.circular(22),
                            boxShadow: [
                              BoxShadow(
                                color: _blue.withValues(alpha: 0.2),
                                blurRadius: 24,
                                spreadRadius: 3,
                              ),
                            ],
                          ),
                          child: Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Color(0xFF5BA3E8), _blue],
                                begin: Alignment.topRight,
                                end: Alignment.bottomLeft,
                              ),
                              borderRadius:
                                  BorderRadius.all(Radius.circular(16)),
                            ),
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.handyman_rounded,
                              size: 34,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'بوابة مزودي الخدمة',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _ink,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'سجّل حسابك وابدأ استقبال طلبات الشغل',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _inkSoft.withValues(alpha: 0.75),
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Card
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: _cardBg,
                          borderRadius: BorderRadius.circular(26),
                          border: Border.all(
                            color: _inkSoft.withValues(alpha: 0.08),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: _inkSoft.withValues(alpha: 0.08),
                              blurRadius: 22,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            // TabBar
                            Container(
                              decoration: BoxDecoration(
                                color: _bg,
                                borderRadius: BorderRadius.circular(22),
                              ),
                              padding: const EdgeInsets.all(4),
                              child: TabBar(
                                controller: _tabController,
                                indicator: BoxDecoration(
                                  color: _blue,
                                  borderRadius: BorderRadius.circular(18),
                                  boxShadow: [
                                    BoxShadow(
                                      color: _blue.withValues(alpha: 0.3),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                indicatorSize: TabBarIndicatorSize.tab,
                                dividerColor: Colors.transparent,
                                labelColor: Colors.white,
                                unselectedLabelColor: _inkSoft,
                                labelStyle: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 13,
                                ),
                                tabs: const [
                                  Tab(height: 46, text: 'تسجيل دخول'),
                                  Tab(height: 46, text: 'حساب جديد'),
                                ],
                                onTap: (_) => _clearError(),
                              ),
                            ),
                            const SizedBox(height: 16),

                            if (_errorMessage != null)
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 0, 16, 12),
                                child: _errorBanner(_errorMessage!),
                              ),

                            // Switcher
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 250),
                              transitionBuilder: (child, animation) {
                                return FadeTransition(
                                  opacity: animation,
                                  child: SlideTransition(
                                    position: Tween<Offset>(
                                      begin: const Offset(0.05, 0),
                                      end: Offset.zero,
                                    ).animate(animation),
                                    child: child,
                                  ),
                                );
                              },
                              child: _tabController.index == 0
                                  ? KeyedSubtree(
                                      key: const ValueKey('login'),
                                      child: _buildLoginForm(),
                                    )
                                  : KeyedSubtree(
                                      key: const ValueKey('register'),
                                      child: _buildRegisterForm(),
                                    ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 18),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.shield_rounded,
                            size: 13,
                            color: _inkSoft.withValues(alpha: 0.6),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'بياناتك محمية ومشفرة',
                            style: TextStyle(
                              color: _inkSoft.withValues(alpha: 0.6),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
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

  // ── Login Form
  Widget _buildLoginForm() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
      child: Form(
        key: _loginKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _field(
              controller: _loginPhone,
              label: 'رقم الموبايل',
              hint: '01XXXXXXXXX',
              icon: Icons.phone_rounded,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(11),
              ],
              onChanged: (_) => _clearError(),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'أدخل رقم الموبايل';
                }
                final c = v.replaceAll(RegExp(r'[^\d]'), '');
                if (c.length != 11 || !c.startsWith('01')) {
                  return 'رقم غير صحيح (01012345678)';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _blue.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _blue.withValues(alpha: 0.15),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.chat_rounded, color: _blue, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'هيبعتلك كود تحقق على الواتساب عشان تسجل دخول.',
                      style: TextStyle(
                        color: _inkSoft.withValues(alpha: 0.9),
                        fontSize: 11.5,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _submitBtn(
              label: 'أرسل الكود',
              icon: Icons.sms_rounded,
              onPressed: _loading ? null : _handleLoginOtp,
            ),
            if (_showSwitchToRegister) ...[
              const SizedBox(height: 14),
              _buildSwitchTabButton(
                label: 'افتح حساب جديد',
                icon: Icons.person_add_alt_1_rounded,
                color: _primary,
                onTap: () => _switchTab(1),
              ),
            ],
            if (_showSupportButton) ...[
              const SizedBox(height: 14),
              _buildSupportButton(),
            ],
          ],
        ),
      ),
    );
  }

  // ── Register Form
  Widget _buildRegisterForm() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
      child: Form(
        key: _registerKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _typeSelector(),
            const SizedBox(height: 14),
            _field(
              controller: _regName,
              label: 'الاسم الكامل',
              hint: 'مثال: محمود النجار',
              icon: Icons.person_outline_rounded,
              onChanged: (_) => _clearError(),
              validator: (v) {
                if (v == null || v.trim().length < 3) {
                  return 'أدخل اسمك الكامل';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            _field(
              controller: _regPhone,
              label: 'رقم الموبايل',
              hint: '01XXXXXXXXX',
              icon: Icons.phone_rounded,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(11),
              ],
              onChanged: (_) => _clearError(),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'أدخل رقم الموبايل';
                }
                final c = v.replaceAll(RegExp(r'[^\d]'), '');
                if (c.length != 11 || !c.startsWith('01')) {
                  return 'رقم غير صحيح (01012345678)';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            _categoryDropdown(),
            if (_selectedCategoryId != null) ...[
              const SizedBox(height: 10),
              _selectedCategoryPreview(),
            ],
            const SizedBox(height: 16),
            Text(
              'بالمتابعة، أنت توافق على شروط الاستخدام وسياسة الخصوصية.',
              style: TextStyle(
                color: _inkSoft.withValues(alpha: 0.65),
                fontSize: 11,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 14),
            _submitBtn(
              label: 'أرسل كود التحقق',
              icon: Icons.sms_rounded,
              onPressed: _loading ? null : _handleRegisterOtp,
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.amber.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    color: Color(0xFFE28B00),
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'هيبعتلك كود على الواتساب. بعد التحقق، طلبك هيتحول لفريق جُود للمراجعة.',
                      style: TextStyle(
                        color: _inkSoft.withValues(alpha: 0.9),
                        fontSize: 11,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_showSwitchToLogin) ...[
              const SizedBox(height: 14),
              _buildSwitchTabButton(
                label: 'سجّل دخول',
                icon: Icons.login_rounded,
                color: _blue,
                onTap: () => _switchTab(0),
              ),
            ],
            if (_showSupportButton) ...[
              const SizedBox(height: 14),
              _buildSupportButton(),
            ],
          ],
        ),
      ),
    );
  }

  // ── Switch Tab Button
  Widget _buildSwitchTabButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      height: 48,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(
          label,
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w900,
          ),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color.withValues(alpha: 0.4), width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  // ── Support Button
  Widget _buildSupportButton() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _whatsapp.withValues(alpha: 0.95),
            const Color(0xFF128C7E),
          ],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _whatsapp.withValues(alpha: 0.3),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          SizedBox(
            height: 50,
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _openSupportWhatsApp,
              icon: const Icon(Icons.chat_rounded, size: 20),
              label: const Text(
                'كلّم الدعم على واتساب',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 6, top: 2),
            child: GestureDetector(
              onTap: _copySupportNumber,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.copy_rounded,
                      color: Colors.white70, size: 12),
                  const SizedBox(width: 5),
                  Text(
                    _supportPhoneLocal,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
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

  // ── Type selector
  Widget _typeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(right: 4, bottom: 8),
          child: Text(
            'نوع الحساب',
            style: TextStyle(
              color: _inkSoft,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: _typePill(
                label: 'فرد',
                icon: Icons.person_rounded,
                value: 'individual',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _typePill(
                label: 'شركة',
                icon: Icons.business_rounded,
                value: 'company',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _typePill({
    required String label,
    required IconData icon,
    required String value,
  }) {
    final selected = _regProviderType == value;
    return InkWell(
      onTap: () {
        if (_regProviderType == value) return;
        setState(() {
          _regProviderType = value;
          _selectedCategoryId = null;
          _errorMessage = null;
        });
        _loadCategories();
      },
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected ? _blue.withValues(alpha: 0.1) : _bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? _blue : _inkSoft.withValues(alpha: 0.15),
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 20,
              color: selected ? _blue : _inkSoft.withValues(alpha: 0.7),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: selected ? _blue : _inkSoft,
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Category Dropdown
  Widget _categoryDropdown() {
    if (_loadingCategories) {
      return InputDecorator(
        decoration: _decoration(
          'التصنيف',
          'جاري التحميل...',
          Icons.category_outlined,
        ),
        child: const SizedBox(
          height: 18,
          child: Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      );
    }

    if (_categories.isEmpty) {
      return InputDecorator(
        decoration: _decoration('التصنيف', '', Icons.category_outlined),
        child: Text(
          _regProviderType == 'company'
              ? 'لا توجد تصنيفات تدعم الشركات'
              : 'لا توجد تصنيفات متاحة',
          style: TextStyle(
            color: _inkSoft.withValues(alpha: 0.6),
            fontSize: 13,
          ),
        ),
      );
    }

    return DropdownButtonFormField<String>(
      initialValue: _selectedCategoryId,
      isExpanded: true,
      decoration: _decoration(
        'التصنيف',
        'اختار مجال شغلك',
        Icons.category_outlined,
      ),
      items: _categories.map((cat) {
        final id = cat['id']?.toString() ?? '';
        final name =
            cat['name_ar']?.toString() ?? cat['slug']?.toString() ?? '';
        final iconName = cat['icon']?.toString() ?? '';
        final iconData = ServiceCategoryIcons.getIcon(iconName);
        final iconColor = ServiceCategoryIcons.getColor(iconName);

        return DropdownMenuItem<String>(
          value: id,
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(iconData, color: iconColor, size: 17),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    color: _ink,
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
      onChanged: (v) {
        setState(() => _selectedCategoryId = v);
        _clearError();
      },
      validator: (v) => v == null ? 'اختار التصنيف' : null,
    );
  }

  // ── Category Preview
  Widget _selectedCategoryPreview() {
    final cat = _categories.firstWhere(
      (c) => c['id'] == _selectedCategoryId,
      orElse: () => <String, dynamic>{},
    );
    if (cat.isEmpty) return const SizedBox.shrink();

    final name = cat['name_ar']?.toString() ?? '';
    final desc = cat['description']?.toString() ?? '';
    final iconName = cat['icon']?.toString() ?? '';
    final iconData = ServiceCategoryIcons.getIcon(iconName);
    final iconColor = ServiceCategoryIcons.getColor(iconName);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: iconColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: iconColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(iconData, color: iconColor, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (desc.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    desc,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _inkSoft.withValues(alpha: 0.7),
                      fontSize: 11,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Icon(Icons.check_circle_rounded, color: iconColor, size: 20),
        ],
      ),
    );
  }

  // ── Error Banner
  Widget _errorBanner(String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _error.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, color: _error, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: _error,
                fontSize: 12.5,
                height: 1.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Field
  Widget _field({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    ValueChanged<String>? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      onChanged: onChanged,
      style: const TextStyle(
        color: _ink,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      decoration: _decoration(label, hint, icon),
      validator: validator,
    );
  }

  InputDecoration _decoration(
    String label,
    String hint,
    IconData icon,
  ) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      hintStyle: TextStyle(
        color: _inkSoft.withValues(alpha: 0.4),
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
      labelStyle: const TextStyle(
        color: _inkSoft,
        fontSize: 13,
        fontWeight: FontWeight.w700,
      ),
      prefixIcon: Icon(icon, color: _blue, size: 20),
      filled: true,
      fillColor: _bg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: _inkSoft.withValues(alpha: 0.12)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: _inkSoft.withValues(alpha: 0.12)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _blue, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _error, width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _error, width: 1.6),
      ),
      errorStyle: const TextStyle(
        color: _error,
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _submitBtn({
    required String label,
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      height: 54,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: _loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: Colors.white,
                ),
              )
            : Icon(icon, size: 20),
        label: Text(
          _loading ? 'جاري الإرسال...' : label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w900,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: _blue,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}
