// lib/features/provider/presentation/pages/provider_auth_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProviderAuthPage extends StatefulWidget {
  const ProviderAuthPage({super.key});

  @override
  State<ProviderAuthPage> createState() => _ProviderAuthPageState();
}

class _ProviderAuthPageState extends State<ProviderAuthPage>
    with SingleTickerProviderStateMixin {
  // ── ألوان جُود
  static const _bg = Color(0xFFF4F8F6);
  static const _bgDark = Color(0xFFE6F0EA);
  static const _primary = Color(0xFF0B7650);
  static const _primaryLight = Color(0xFF25B77C);
  static const _ink = Color(0xFF123F31);
  static const _inkSoft = Color(0xFF315A45);
  static const _cardBg = Colors.white;
  static const _error = Color(0xFFD64545);

  late final TabController _tabController;

  // ── Login
  final _loginEmail = TextEditingController();
  final _loginPassword = TextEditingController();

  // ── Register (الخطوة 1 فقط)
  final _regDisplayName = TextEditingController();
  final _regPhone = TextEditingController();
  final _regEmail = TextEditingController();
  final _regPassword = TextEditingController();
  final _regConfirmPassword = TextEditingController();

  String? _regProviderType; // individual | company
  String? _selectedCategoryId;

  // ── States
  bool _loginObscure = true;
  bool _registerObscure = true;
  bool _confirmObscure = true;
  bool _isLoading = false;
  String? _errorMessage;

  // ── Categories من DB
  List<Map<String, dynamic>> _categories = [];
  bool _isLoadingCategories = false;

  final _loginFormKey = GlobalKey<FormState>();
  final _registerFormKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadCategories();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _loginEmail.dispose();
    _loginPassword.dispose();
    _regDisplayName.dispose();
    _regPhone.dispose();
    _regEmail.dispose();
    _regPassword.dispose();
    _regConfirmPassword.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════════════════════
  // Load categories
  // ══════════════════════════════════════════════════════
  Future<void> _loadCategories() async {
    if (mounted) setState(() => _isLoadingCategories = true);
    try {
      // ⚠️ عدّل اسم الجدول لو مختلف (مثلاً: categories)
      final rows = await Supabase.instance.client
          .from('service_categories')
          .select('id, name_ar, slug')
          .eq('is_active', true)
          .order('sort_order', ascending: true);

      if (!mounted) return;
      setState(() {
        _categories = List<Map<String, dynamic>>.from(rows);
        _isLoadingCategories = false;
      });
    } catch (e) {
      debugPrint('⚠️ Failed to load categories: $e');
      if (!mounted) return;
      setState(() {
        _isLoadingCategories = false;
        // لو الجدول مش موجود، منكسرش الصفحة
        _categories = [];
      });
    }
  }

  // ══════════════════════════════════════════════════════
  // Validators
  // ══════════════════════════════════════════════════════
  bool _isValidEgyptianPhone(String phone) {
    final cleaned = phone.replaceAll(RegExp(r'[^\d]'), '');
    return cleaned.length == 11 && cleaned.startsWith('01');
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[\w\.-]+@[\w\.-]+\.\w+$').hasMatch(email.trim());
  }

  // ══════════════════════════════════════════════════════
  // LOGIN
  // ══════════════════════════════════════════════════════
  Future<void> _handleLogin() async {
    FocusScope.of(context).unfocus();
    if (!_loginFormKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final email = _loginEmail.text.trim().toLowerCase();
      final password = _loginPassword.text;

      final response = await Supabase.instance.client.auth
          .signInWithPassword(email: email, password: password);

      if (response.user == null) {
        throw Exception('فشل تسجيل الدخول.');
      }

      // ✅ تحقق إنه مقدم خدمة فعلاً
      final providerRow = await Supabase.instance.client
          .from('service_providers')
          .select('id, verification_status, is_active')
          .eq('user_id', response.user!.id)
          .maybeSingle();

      if (!mounted) return;

      if (providerRow == null) {
        await Supabase.instance.client.auth.signOut();
        throw Exception(
          'الحساب ده مش مسجل كمقدم خدمة. سجّل حساب جديد من التاب التاني.',
        );
      }

      final status =
          providerRow['verification_status']?.toString() ?? 'pending';
      final isActive = providerRow['is_active'] as bool? ?? true;

      if (!isActive || status == 'rejected' || status == 'suspended') {
        await Supabase.instance.client.auth.signOut();
        throw Exception('حسابك غير مفعّل. تواصل مع الدعم الفني.');
      }

      if (!mounted) return;
      _showSuccess('أهلاً بيك 👋');

      // ✅ TODO: ربط مع GoRouter
      // context.go(status == 'approved'
      //   ? AppRouter.providerHome
      //   : AppRouter.providerPending);
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = _friendlyError(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ══════════════════════════════════════════════════════
  // REGISTER — الخطوة 1
  // ══════════════════════════════════════════════════════
  Future<void> _handleRegister() async {
    FocusScope.of(context).unfocus();
    if (!_registerFormKey.currentState!.validate()) return;

    if (_regProviderType == null) {
      setState(() => _errorMessage = 'اختار نوع الحساب');
      return;
    }
    if (_selectedCategoryId == null) {
      setState(() => _errorMessage = 'اختار التصنيف');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final email = _regEmail.text.trim().toLowerCase();
      final phone = _regPhone.text.trim();
      final displayName = _regDisplayName.text.trim();
      final password = _regPassword.text;

      // 1) إنشاء حساب في Supabase Auth
      final authResponse = await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
        data: {
          'display_name': displayName,
          'phone': phone,
          'role': 'provider',
        },
      );

      final user = authResponse.user;
      if (user == null) {
        throw Exception('فشل إنشاء الحساب. حاول مرة أخرى.');
      }

      // 2) إدخال صف في service_providers — بأسماء الأعمدة الصح
      await Supabase.instance.client.from('service_providers').insert({
        'user_id': user.id,
        'category_id': _selectedCategoryId,
        'provider_type': _regProviderType, // individual | company
        'display_name': displayName,
        'phone': phone,
        'whatsapp': phone, // نسخة افتراضية
        'email': email,
        'verification_status': 'pending',
        'is_active': true,
        'is_available': true,
        'price_currency': 'EGP',
        'accepts_installments': false,
        'skills': <String>[],
        'service_areas': <String>[],
        'branches': '[]',
      });

      if (!mounted) return;

      _showSuccess('تم إنشاء حسابك 🎉');

      // ✅ TODO: نروح لصفحة استكمال الملف
      // context.go(AppRouter.providerCompleteProfile);
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = _friendlyError(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ══════════════════════════════════════════════════════
  // Helpers
  // ══════════════════════════════════════════════════════
  String _friendlyError(Object error) {
    final msg = error.toString().toLowerCase();
    if (msg.contains('invalid login') || msg.contains('invalid credentials')) {
      return 'الإيميل أو كلمة السر غير صحيحة.';
    }
    if (msg.contains('already registered') ||
        msg.contains('user already exists') ||
        msg.contains('duplicate')) {
      return 'الإيميل أو الموبايل مسجل بالفعل.';
    }
    if (msg.contains('weak password')) {
      return 'كلمة السر ضعيفة. استخدم 6 أحرف على الأقل.';
    }
    if (msg.contains('network') || msg.contains('socket')) {
      return 'تعذر الاتصال. تحقق من الإنترنت.';
    }
    if (msg.contains('row-level security') || msg.contains('permission')) {
      return 'ليس لديك صلاحية. تواصل مع الدعم.';
    }
    return error.toString().replaceFirst('Exception: ', '');
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message, textDirection: TextDirection.rtl),
          backgroundColor: _primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
  }

  // ══════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
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
                padding: const EdgeInsets.fromLTRB(22, 16, 22, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        onPressed: () => Navigator.maybePop(context),
                        icon: const Icon(
                          Icons.arrow_forward_rounded,
                          color: _ink,
                        ),
                      ),
                    ),
                    // Header icon
                    Center(
                      child: Container(
                        width: 82,
                        height: 82,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _cardBg,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: _primary.withValues(alpha: 0.18),
                              blurRadius: 26,
                              spreadRadius: 3,
                            ),
                          ],
                        ),
                        child: Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [_primary, _primaryLight],
                              begin: Alignment.topRight,
                              end: Alignment.bottomLeft,
                            ),
                            borderRadius: BorderRadius.all(Radius.circular(18)),
                          ),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.handyman_rounded,
                            size: 36,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'بوابة مقدمي الخدمة',
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
                        fontSize: 13.5,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 22),

                    // Card with tabs
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
                                color: _primary,
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: [
                                  BoxShadow(
                                    color: _primary.withValues(alpha: 0.3),
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
                                fontSize: 13.5,
                              ),
                              unselectedLabelStyle: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13.5,
                              ),
                              tabs: const [
                                Tab(height: 46, text: 'تسجيل دخول'),
                                Tab(height: 46, text: 'حساب جديد'),
                              ],
                              onTap: (_) =>
                                  setState(() => _errorMessage = null),
                            ),
                          ),
                          const SizedBox(height: 18),

                          if (_errorMessage != null)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                              child: _errorBanner(_errorMessage!),
                            ),

                          TabBarView(
                            controller: _tabController,
                            physics: const NeverScrollableScrollPhysics(),
                            children: [
                              _buildLoginForm(),
                              _buildRegisterForm(),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.shield_rounded,
                          size: 14,
                          color: _inkSoft.withValues(alpha: 0.6),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'بياناتك محمية ومشفرة',
                          style: TextStyle(
                            color: _inkSoft.withValues(alpha: 0.6),
                            fontSize: 11.5,
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
    );
  }

  // ══════════════════════════════════════════════════════
  // Login Form
  // ══════════════════════════════════════════════════════
  Widget _buildLoginForm() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
      child: Form(
        key: _loginFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _field(
              controller: _loginEmail,
              label: 'الإيميل',
              hint: 'example@mail.com',
              icon: Icons.alternate_email_rounded,
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'أدخل الإيميل';
                if (!_isValidEmail(v.trim())) return 'إيميل غير صحيح';
                return null;
              },
            ),
            const SizedBox(height: 14),
            _field(
              controller: _loginPassword,
              label: 'كلمة السر',
              hint: '••••••••',
              icon: Icons.lock_outline_rounded,
              obscure: _loginObscure,
              suffix: IconButton(
                onPressed: () => setState(() => _loginObscure = !_loginObscure),
                icon: Icon(
                  _loginObscure
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  color: _inkSoft.withValues(alpha: 0.6),
                  size: 20,
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'أدخل كلمة السر';
                return null;
              },
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () {
                  // TODO: forgot password
                },
                child: const Text(
                  'نسيت كلمة السر؟',
                  style: TextStyle(
                    color: _primary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            _submitButton(
              label: 'تسجيل الدخول',
              icon: Icons.login_rounded,
              onPressed: _isLoading ? null : _handleLogin,
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // Register Form — الخطوة 1
  // ══════════════════════════════════════════════════════
  Widget _buildRegisterForm() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
      child: Form(
        key: _registerFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Provider Type (فرد / شركة)
            _providerTypeSelector(),
            const SizedBox(height: 14),

            _field(
              controller: _regDisplayName,
              label: 'الاسم الكامل',
              hint: 'مثال: محمود النجار',
              icon: Icons.person_outline_rounded,
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
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'أدخل رقم الموبايل';
                }
                if (!_isValidEgyptianPhone(v.trim())) {
                  return 'رقم غير صحيح (مثال: 01012345678)';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),

            _field(
              controller: _regEmail,
              label: 'الإيميل',
              hint: 'example@mail.com',
              icon: Icons.alternate_email_rounded,
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'أدخل الإيميل';
                if (!_isValidEmail(v.trim())) return 'إيميل غير صحيح';
                return null;
              },
            ),
            const SizedBox(height: 14),

            _categoryDropdown(),
            const SizedBox(height: 14),

            _field(
              controller: _regPassword,
              label: 'كلمة السر',
              hint: '••••••••',
              icon: Icons.lock_outline_rounded,
              obscure: _registerObscure,
              suffix: IconButton(
                onPressed: () =>
                    setState(() => _registerObscure = !_registerObscure),
                icon: Icon(
                  _registerObscure
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  color: _inkSoft.withValues(alpha: 0.6),
                  size: 20,
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'أدخل كلمة السر';
                if (v.length < 6) return 'كلمة السر 6 أحرف على الأقل';
                return null;
              },
            ),
            const SizedBox(height: 14),

            _field(
              controller: _regConfirmPassword,
              label: 'تأكيد كلمة السر',
              hint: '••••••••',
              icon: Icons.lock_reset_rounded,
              obscure: _confirmObscure,
              suffix: IconButton(
                onPressed: () =>
                    setState(() => _confirmObscure = !_confirmObscure),
                icon: Icon(
                  _confirmObscure
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  color: _inkSoft.withValues(alpha: 0.6),
                  size: 20,
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'أكّد كلمة السر';
                if (v != _regPassword.text) return 'كلمتا السر غير متطابقتين';
                return null;
              },
            ),
            const SizedBox(height: 10),

            Text(
              'بالمتابعة، أنت توافق على شروط الاستخدام وسياسة الخصوصية.',
              style: TextStyle(
                color: _inkSoft.withValues(alpha: 0.65),
                fontSize: 11.5,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),

            _submitButton(
              label: 'إنشاء الحساب',
              icon: Icons.person_add_alt_1_rounded,
              onPressed: _isLoading ? null : _handleRegister,
            ),
            const SizedBox(height: 10),
            Text(
              'بعد التسجيل هتكمل ملفك الشخصي (نبذة، خبرة، مهارات، صور).',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _inkSoft.withValues(alpha: 0.6),
                fontSize: 11,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // Provider Type Selector
  // ══════════════════════════════════════════════════════
  Widget _providerTypeSelector() {
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
                selected: _regProviderType == 'individual',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _typePill(
                label: 'شركة',
                icon: Icons.business_rounded,
                value: 'company',
                selected: _regProviderType == 'company',
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
    required bool selected,
  }) {
    return InkWell(
      onTap: () => setState(() => _regProviderType = value),
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected ? _primary.withValues(alpha: 0.1) : _bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? _primary : _inkSoft.withValues(alpha: 0.15),
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 20,
              color: selected ? _primary : _inkSoft.withValues(alpha: 0.7),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: selected ? _primary : _inkSoft,
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // Category Dropdown (من DB)
  // ══════════════════════════════════════════════════════
  Widget _categoryDropdown() {
    if (_isLoadingCategories) {
      return InputDecorator(
        decoration: _inputDecoration(
          label: 'التصنيف',
          hint: 'جاري التحميل...',
          icon: Icons.category_outlined,
        ),
        child: const SizedBox(
          height: 20,
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
        decoration: _inputDecoration(
          label: 'التصنيف',
          hint: '',
          icon: Icons.category_outlined,
        ),
        child: Text(
          'لا توجد تصنيفات متاحة',
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
      decoration: _inputDecoration(
        label: 'التصنيف',
        hint: 'اختار مجال شغلك',
        icon: Icons.category_outlined,
      ),
      items: _categories.map((cat) {
        final id = cat['id']?.toString() ?? '';
        final name =
            cat['name_ar']?.toString() ?? cat['slug']?.toString() ?? '';
        return DropdownMenuItem<String>(
          value: id,
          child: Text(
            name,
            style: const TextStyle(
              color: _ink,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      }).toList(),
      onChanged: (value) => setState(() => _selectedCategoryId = value),
      validator: (v) => v == null ? 'اختار التصنيف' : null,
    );
  }

  // ══════════════════════════════════════════════════════
  // Shared Widgets
  // ══════════════════════════════════════════════════════
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

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    bool obscure = false,
    Widget? suffix,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      obscureText: obscure,
      style: const TextStyle(
        color: _ink,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      decoration: _inputDecoration(
        label: label,
        hint: hint,
        icon: icon,
        suffix: suffix,
      ),
      validator: validator,
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) {
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
      prefixIcon: Icon(icon, color: _primary, size: 20),
      suffixIcon: suffix,
      filled: true,
      fillColor: _bg,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 16,
      ),
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
        borderSide: const BorderSide(color: _primary, width: 1.6),
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

  Widget _submitButton({
    required String label,
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      height: 54,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: _isLoading
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
          _isLoading ? 'جاري التحميل...' : label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.2,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: _primary,
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
