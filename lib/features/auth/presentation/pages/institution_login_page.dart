// lib/features/auth/presentation/pages/institution_login_page.dart
//
// ✅ صفحة تسجيل دخول مخصصة للمؤسسات فقط. مفيش أي رابط "إنشاء حساب"
// هنا لأن حسابات المؤسسات بتتضاف يدويًا من فريق لقمة. بعد نجاح
// الدخول بيتم التأكد إن الحساب ده فعلاً حساب مؤسسة/شريك، ولو حساب
// مستخدم عادي غلط بيدخل من هنا، بيتسجل خروجه تلقائيًا وتظهر رسالة
// واضحة توجهه لصفحة الدخول الصح.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:loqma/routes/app_router.dart';

class InstitutionLoginPage extends StatefulWidget {
  const InstitutionLoginPage({super.key});

  @override
  State<InstitutionLoginPage> createState() => _InstitutionLoginPageState();
}

class _InstitutionLoginPageState extends State<InstitutionLoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _loading = false;
  String? _errorMessage;

  // ───────── نفس هوية السبلاش ─────────
  static const _bg = Color(0xFFF4EEE5);
  static const _bgDark = Color(0xFFE6D9C8);
  static const _ink = Color(0xFF244536);
  static const _inkSoft = Color(0xFF315A45);
  static const _gold = Color(0xFFC78950);
  static const _cardBg = Color(0xFFFFFBF5);
  static const _red = Color(0xFFB54747);

  static const _businessUserTypes = {
    'restaurant',
    'business',
    'hotel',
    'supermarket',
    'bakery',
    'cafe',
  };

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════
  // LOGIN
  // ═══════════════════════════════════════════════════════════

  Future<void> _login() async {
    if (!_formKey.currentState!.validate() || _loading) return;

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    final client = Supabase.instance.client;

    try {
      final response = await client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      final user = response.user;
      if (user == null) {
        throw const AuthException('تعذر تسجيل الدخول');
      }

      final userData = await client
          .from('users')
          .select('user_type')
          .eq('id', user.id)
          .maybeSingle();

      final type = userData?['user_type']?.toString().toLowerCase() ?? '';

      if (!mounted) return;

      // ✅ صفحة واحدة لكل اللي مش "مستخدم عادي": مطاعم، مؤسسات،
      // جمعيات، وأي نوع تجاري تاني — كل واحد يروح لصفحته حسب نوعه،
      // بنفس التصنيف اللي السبلاش بيستخدمه بالظبط.
      if (type == 'charity') {
        context.go(AppRouter.charityHome);
        return;
      }

      if (type == 'institution') {
        context.go(AppRouter.institutionsHome);
        return;
      }

      if (_businessUserTypes.contains(type)) {
        context.go(AppRouter.restaurantHome);
        return;
      }

      // ✅ الحساب ده حساب مستخدم عادي (أو نوع غير معروف) —
      // سجّله خروج ووريه رسالة واضحة توجهه للمكان الصح
      await client.auth.signOut();
      if (!mounted) return;
      setState(() {
        _errorMessage = type == 'user'
            ? 'الحساب ده حساب مستخدم عادي. ادخل من صفحة تسجيل الدخول التانية.'
            : 'تعذر التعرف على نوع الحساب. تواصل مع فريق لقمة.';
      });
    } on AuthException catch (_) {
      if (!mounted) return;
      setState(
          () => _errorMessage = 'البريد الإلكتروني أو كلمة المرور غير صحيحة');
    } catch (e) {
      debugPrint('❌ institution login error: $e');
      if (!mounted) return;
      setState(() => _errorMessage = 'حصلت مشكلة، حاول مرة أخرى');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ═══════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════

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
              child: GestureDetector(
                onTap: () => FocusScope.of(context).unfocus(),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        alignment: Alignment.centerRight,
                        child: IconButton(
                          onPressed: () =>
                              context.go(AppRouter.userTypeSelection),
                          icon: const Icon(Icons.arrow_forward_rounded,
                              color: _ink),
                          tooltip: 'رجوع',
                        ),
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: Container(
                          width: 68,
                          height: 68,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _cardBg,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: _gold.withValues(alpha: 0.18),
                                blurRadius: 22,
                                spreadRadius: 3,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.storefront_rounded,
                            color: _gold,
                            size: 32,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'تسجيل دخول المؤسسات',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _ink,
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'ادخل ببيانات حسابك اللي اتعمل لمؤسستك من فريق لقمة',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _inkSoft.withValues(alpha: 0.75),
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 28),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: _cardBg,
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: [
                            BoxShadow(
                              color: _inkSoft.withValues(alpha: 0.06),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (_errorMessage != null) ...[
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: _red.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                        color: _red.withValues(alpha: 0.25)),
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Icon(Icons.error_outline_rounded,
                                          color: _red, size: 18),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _errorMessage!,
                                          style: const TextStyle(
                                            color: _red,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            height: 1.4,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],
                              _buildLabel('البريد الإلكتروني'),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                textDirection: TextDirection.ltr,
                                decoration: _inputDecoration(
                                  hint: 'institution@example.com',
                                  icon: Icons.mail_outline_rounded,
                                ),
                                validator: (value) {
                                  final v = value?.trim() ?? '';
                                  if (v.isEmpty) {
                                    return 'اكتب البريد الإلكتروني';
                                  }
                                  if (!v.contains('@') || !v.contains('.')) {
                                    return 'البريد الإلكتروني غير صحيح';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              _buildLabel('كلمة المرور'),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                textDirection: TextDirection.ltr,
                                decoration: _inputDecoration(
                                  hint: '••••••••',
                                  icon: Icons.lock_outline_rounded,
                                  suffix: IconButton(
                                    onPressed: () => setState(() =>
                                        _obscurePassword = !_obscurePassword),
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_off_rounded
                                          : Icons.visibility_rounded,
                                      color: _inkSoft.withValues(alpha: 0.6),
                                      size: 20,
                                    ),
                                  ),
                                ),
                                validator: (value) {
                                  if ((value ?? '').isEmpty) {
                                    return 'اكتب كلمة المرور';
                                  }
                                  return null;
                                },
                                onFieldSubmitted: (_) => _login(),
                              ),
                              const SizedBox(height: 22),
                              SizedBox(
                                height: 52,
                                child: FilledButton(
                                  onPressed: _loading ? null : _login,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: _inkSoft,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  child: _loading
                                      ? const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.4,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Text(
                                          'تسجيل الدخول',
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _inkSoft.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.info_outline_rounded,
                                color: _inkSoft.withValues(alpha: 0.6),
                                size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'حسابات المؤسسات بتتعمل من فريق لقمة مباشرة. لو لسه معندكش حساب، تواصل معانا.',
                                style: TextStyle(
                                  color: _inkSoft.withValues(alpha: 0.65),
                                  fontSize: 11.5,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
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

  Widget _buildLabel(String text) => Text(
        text,
        style: const TextStyle(
          color: _ink,
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
        ),
      );

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: _inkSoft.withValues(alpha: 0.35)),
      prefixIcon: Icon(icon, color: _inkSoft.withValues(alpha: 0.6), size: 20),
      suffixIcon: suffix,
      filled: true,
      fillColor: _bg.withValues(alpha: 0.5),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _inkSoft.withValues(alpha: 0.12)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _inkSoft.withValues(alpha: 0.12)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _gold, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _red.withValues(alpha: 0.6)),
      ),
    );
  }
}
