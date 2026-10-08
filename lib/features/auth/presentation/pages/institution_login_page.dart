// lib/features/auth/presentation/pages/institution_login_page.dart
//
// ✅ صفحة تسجيل دخول مخصصة للمؤسسات/الشركاء فقط.
// مفيش أي رابط "إنشاء حساب" هنا لأن الحسابات بتتضاف يدويًا من فريق وِصلة.
//
// القاعدة:
//   • جمعية (charity)     → /charity-home
//   • مطعم (restaurant)   → /restaurant-home
//   • أي نوع تاني         → /institutions-home
//   • user / admin / provider → ❌ يترفض + signOut + رسالة

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:loqma/core/config/app_config.dart';
import 'package:loqma/core/services/auth_state_notifier.dart';
import 'package:loqma/features/auth/presentation/pages/institution_otp_verify_page.dart';
import 'package:loqma/features/institutions/domain/entities/institution.dart';
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
  bool _isCharity = false;
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

  /// الأنواع المرفوضة من بوابة المؤسسات
  static const _blockedTypes = {'user', 'admin', 'provider'};

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  SupabaseClient _createTemporaryAuthClient() => SupabaseClient(
        AppConfig.supabaseUrl,
        AppConfig.supabaseAnonKey,
        authOptions: const AuthClientOptions(
          autoRefreshToken: false,
        ),
      );

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
    final temporaryClient = _createTemporaryAuthClient();
    final email = _emailController.text.trim().toLowerCase();
    final passwordOrCode = _passwordController.text;

    try {
      // الجمعية: افحص الكود الثابت من public.charities أولًا.
      // لا تستخدم signInWithPassword قبل الفحص، لأن الكود محفوظ كـ hash
      // في قاعدة البيانات وليس كنص عادي في التطبيق.
      if (_isCharity) {
        await _loginAsCharity(
          client,
          temporaryClient,
          email,
          passwordOrCode,
        );
        return;
      }

      // لا تحفظ الجلسة التشغيلية على العميل الدائم قبل اجتياز العامل الثاني.
      AuthStateNotifier.instance.beginInstitutionOtp();
      final response = await temporaryClient.auth.signInWithPassword(
        email: email,
        password: passwordOrCode,
      );

      final authUser = response.user;
      if (authUser == null) {
        throw const AuthException('تعذر تسجيل الدخول');
      }

      final institution = await temporaryClient
          .from('institutions')
          .select('id')
          .eq('user_id', authUser.id)
          .maybeSingle();
      final refreshToken = response.session?.refreshToken;
      if (institution == null || refreshToken == null || refreshToken.isEmpty) {
        await temporaryClient.auth.signOut(scope: SignOutScope.local);
        AuthStateNotifier.instance.finishInstitutionOtp();
        if (!mounted) return;
        setState(() {
          _errorMessage = institution == null
              ? 'هذا الحساب غير مربوط بمؤسسة.'
              : 'تعذر تجهيز خطوة التحقق، حاول مرة أخرى';
        });
        return;
      }

      if (!mounted) {
        await temporaryClient.auth.signOut(scope: SignOutScope.local);
        return;
      }
      final otpResponse = await temporaryClient.functions.invoke(
        'send-partner-login-otp',
        body: {'partnerType': 'institution'},
      );
      if (otpResponse.data is! Map || otpResponse.data['success'] != true) {
        throw const AuthException('تعذر إرسال رمز التحقق إلى الرقم المسجل');
      }
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => InstitutionOtpVerifyPage(
            verifyCode: (code) async {
              final verification = await temporaryClient.rpc(
                'verify_partner_login_otp',
                params: {
                  'p_partner_type': 'institution',
                  'p_partner_id': institution['id'].toString(),
                  'p_otp': code,
                },
              );
              return verification is Map && verification['allowed'] == true;
            },
            onVerified: () async {
              try {
                await client.auth.setSession(refreshToken);
                await temporaryClient.auth.signOut(scope: SignOutScope.local);
                await _loginAsInstitution(client, authUser.id);
                if (client.auth.currentSession == null && mounted) {
                  Navigator.of(context).pop();
                }
              } catch (_) {
                await client.auth.signOut(scope: SignOutScope.local);
                await temporaryClient.auth.signOut(scope: SignOutScope.local);
                AuthStateNotifier.instance.finishInstitutionOtp();
                rethrow;
              }
            },
            onCancelled: () async {
              await temporaryClient.auth.signOut(scope: SignOutScope.local);
              AuthStateNotifier.instance.finishInstitutionOtp();
            },
          ),
        ),
      );
    } on AuthException catch (error) {
      debugPrint('❌ Partner login auth error: ${error.message}');
      await temporaryClient.auth.signOut(scope: SignOutScope.local);
      AuthStateNotifier.instance.finishInstitutionOtp();
      if (!mounted) return;
      setState(() {
        _errorMessage = _isCharity
            ? 'البريد الإلكتروني أو كود الجمعية غير صحيح'
            : 'البريد الإلكتروني أو كلمة المرور غير صحيحة';
      });
    } catch (error) {
      debugPrint('❌ Partner login error: $error');
      await temporaryClient.auth.signOut(scope: SignOutScope.local);
      AuthStateNotifier.instance.finishInstitutionOtp();
      if (!mounted) return;
      setState(() {
        _errorMessage = 'حصلت مشكلة أثناء تسجيل الدخول، حاول مرة أخرى';
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _loginAsCharity(
    SupabaseClient client,
    SupabaseClient temporaryClient,
    String email,
    String accessCode,
  ) async {
    final rpcResult = await client.rpc(
      'check_charity_fixed_code_by_email',
      params: {
        'p_email': email,
        'p_access_code': accessCode,
      },
    );

    final result = rpcResult is Map
        ? Map<String, dynamic>.from(rpcResult)
        : <String, dynamic>{};

    if (result['allowed'] != true) {
      if (!mounted) return;
      setState(() {
        _errorMessage = result['message']?.toString() ??
            'البريد الإلكتروني أو كود الجمعية غير صحيح';
      });
      return;
    }

    // الـ RPC يتحقق من كود الجمعية، لكن Flutter يحتاج Session حقيقية.
    // لذلك يجب أن يكون accessCode هو كلمة مرور حساب Auth للجمعية أيضًا.
    AuthStateNotifier.instance.beginInstitutionOtp();
    final response = await temporaryClient.auth.signInWithPassword(
      email: email,
      password: accessCode,
    );

    final authUser = response.user;
    if (authUser == null) {
      throw const AuthException(
          'تم التحقق من الكود ولكن تعذر إنشاء جلسة الجمعية');
    }

    // الـ RPC فحص السجل وأعاد user_id بالفعل.
    // لا نعيد استعلام charities هنا؛ قد تمنعه RLS رغم نجاح الـ RPC.
    final rpcUserId = result['user_id']?.toString();
    final rpcCharityId = result['charity_id']?.toString();

    if (rpcUserId == null || rpcCharityId == null || rpcUserId != authUser.id) {
      await _rejectSession(
        'بيانات الجمعية لا تتطابق مع حساب الدخول. تواصل مع الدعم.',
        authClient: temporaryClient,
      );
      return;
    }

    final status = result['status']?.toString().toLowerCase() ?? 'pending';

    final accountRow = await temporaryClient
        .from('users')
        .select('account_status, suspension_until')
        .eq('id', authUser.id)
        .maybeSingle();
    final accountStatus =
        accountRow?['account_status']?.toString().trim().toLowerCase() ??
            'active';
    if (accountStatus != 'active') {
      await _rejectSession(
        'حساب الجمعية موقوف أو قيد المراجعة. تواصل مع الدعم.',
        authClient: temporaryClient,
      );
      return;
    }

    if (status == 'rejected') {
      await _rejectSession(
        'تم رفض طلب الجمعية. برجاء التواصل مع إدارة وِصلة.',
        authClient: temporaryClient,
      );
      return;
    }

    if (status == 'suspended' || status == 'inactive') {
      await _rejectSession(
        'تم إيقاف حساب الجمعية. تواصل مع الدعم.',
        authClient: temporaryClient,
      );
      return;
    }

    if (status == 'pending') {
      await _rejectSession(
        'حساب الجمعية ما زال تحت المراجعة.',
        authClient: temporaryClient,
      );
      return;
    }

    if (status != 'approved' && status != 'active') {
      await _rejectSession(
        'لا يمكن الدخول بحساب الجمعية حاليًا.',
        authClient: temporaryClient,
      );
      return;
    }

    if (!mounted) return;
    final charityId = rpcCharityId;
    final refreshToken = response.session?.refreshToken;
    if (charityId == null || refreshToken == null || refreshToken.isEmpty) {
      await _rejectSession(
        'تعذر تجهيز خطوة التحقق، حاول مرة أخرى.',
        authClient: temporaryClient,
      );
      return;
    }

    final otpResponse = await temporaryClient.functions.invoke(
      'send-partner-login-otp',
      body: {'partnerType': 'charity'},
    );
    if (otpResponse.data is! Map || otpResponse.data['success'] != true) {
      throw const AuthException('تعذر إرسال رمز التحقق إلى الرقم المسجل');
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => InstitutionOtpVerifyPage(
          verifyCode: (code) async {
            final verification = await temporaryClient.rpc(
              'verify_partner_login_otp',
              params: {
                'p_partner_type': 'charity',
                'p_partner_id': charityId,
                'p_otp': code,
              },
            );
            return verification is Map && verification['allowed'] == true;
          },
          onVerified: () async {
            try {
              await client.auth.setSession(refreshToken);
              await temporaryClient.auth.signOut(scope: SignOutScope.local);
              AuthStateNotifier.instance.finishInstitutionOtp();
              AuthStateNotifier.instance.setLoggedIn(
                isLoggedIn: true,
                role: 'charity',
                accountStatus: accountStatus,
                suspensionUntil: accountRow?['suspension_until'] is String
                    ? DateTime.tryParse(
                        accountRow!['suspension_until'] as String,
                      )
                    : null,
                isActive: true,
                authResolved: true,
              );
              if (mounted) context.go(AppRouter.charityHome);
            } catch (_) {
              await client.auth.signOut(scope: SignOutScope.local);
              await temporaryClient.auth.signOut(scope: SignOutScope.local);
              AuthStateNotifier.instance.finishInstitutionOtp();
              rethrow;
            }
          },
          onCancelled: () async {
            await temporaryClient.auth.signOut(scope: SignOutScope.local);
            AuthStateNotifier.instance.finishInstitutionOtp();
          },
        ),
      ),
    );
  }

  Future<void> _loginAsInstitution(
    SupabaseClient client,
    String authUserId,
  ) async {
    final institution = await client
        .from('institutions')
        .select('id, user_id, name, institution_type, status')
        .eq('user_id', authUserId)
        .maybeSingle();

    if (institution == null) {
      await client.auth.signOut();
      if (!mounted) return;
      setState(() {
        _errorMessage =
            'هذا الحساب غير مربوط بمؤسسة. لو أنت جمعية اختَر تبويب الجمعيات.';
      });
      return;
    }

    final status = institution['status']?.toString().toLowerCase() ?? 'pending';

    final accountRow = await client
        .from('users')
        .select('account_status, suspension_until')
        .eq('id', authUserId)
        .maybeSingle();
    final accountStatus =
        accountRow?['account_status']?.toString().trim().toLowerCase() ??
            'active';
    if (accountStatus != 'active') {
      await _rejectSession(
          'حساب المؤسسة موقوف أو قيد المراجعة. تواصل مع الدعم.');
      return;
    }

    if (status == 'rejected') {
      await _rejectSession(
        'تم رفض طلب المؤسسة. برجاء التواصل مع إدارة وِصلة.',
      );
      return;
    }

    if (status == 'suspended' || status == 'inactive') {
      await _rejectSession(
        'تم إيقاف حساب المؤسسة. برجاء التواصل مع الدعم.',
      );
      return;
    }

    if (status == 'pending') {
      await _rejectSession('حساب المؤسسة ما زال تحت المراجعة.');
      return;
    }

    if (!Institution.isAllowedStatus(status)) {
      await _rejectSession('لا يمكن الدخول بحساب المؤسسة حاليًا.');
      return;
    }

    final institutionType =
        institution['institution_type']?.toString().toLowerCase() ??
            'institution';

    AuthStateNotifier.instance.finishInstitutionOtp();
    AuthStateNotifier.instance.setLoggedIn(
      isLoggedIn: true,
      role: institutionType,
      institutionStatus: status,
      accountStatus: accountStatus,
      suspensionUntil: accountRow?['suspension_until'] is String
          ? DateTime.tryParse(accountRow!['suspension_until'] as String)
          : null,
      isActive: true,
      authResolved: true,
    );

    if (!mounted) return;

    if (institutionType == 'restaurant') {
      context.go(AppRouter.restaurantHome);
    } else {
      context.go(AppRouter.institutionsHome);
    }
  }

  Future<void> _rejectSession(
    String message, {
    SupabaseClient? authClient,
  }) async {
    await (authClient ?? Supabase.instance.client)
        .auth
        .signOut(scope: SignOutScope.local);
    if (!mounted) return;
    setState(() => _errorMessage = message);
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
                      Text(
                        _isCharity
                            ? 'تسجيل دخول الجمعيات'
                            : 'تسجيل دخول المؤسسات',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: _ink,
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _isCharity
                            ? 'ادخل ببريد الجمعية والكود الثابت المخصص لها'
                            : 'ادخل ببيانات المؤسسة التي أنشأها لك فريق وِصلة',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _inkSoft.withValues(alpha: 0.75),
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 28),
                      _buildModeSelector(),
                      const SizedBox(height: 16),
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
                              _buildLabel(_isCharity
                                  ? 'الكود الثابت للجمعية'
                                  : 'كلمة المرور'),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                textDirection: TextDirection.ltr,
                                decoration: _inputDecoration(
                                  hint: _isCharity
                                      ? 'أدخل كود الجمعية'
                                      : '••••••••',
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
                                _isCharity
                                    ? 'حسابات الجمعيات بتتراجع وتتعتمد من فريق وِصلة. لا يتم إرسال OTP.'
                                    : 'حسابات المؤسسات بتتعمل من فريق وِصلة مباشرة. لو لسه معندكش حساب، تواصل معانا.',
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

  Widget _buildModeSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _inkSoft.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _modeButton(
              label: 'مؤسسة / محل',
              icon: Icons.storefront_rounded,
              selected: !_isCharity,
              onTap: () => setState(() {
                _isCharity = false;
                _errorMessage = null;
              }),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _modeButton(
              label: 'جمعية',
              icon: Icons.volunteer_activism_rounded,
              selected: _isCharity,
              onTap: () => setState(() {
                _isCharity = true;
                _errorMessage = null;
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _modeButton({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: _loading ? null : onTap,
      borderRadius: BorderRadius.circular(11),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
        decoration: BoxDecoration(
          color: selected ? _inkSoft : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: selected ? Colors.white : _inkSoft,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: selected ? Colors.white : _inkSoft,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
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
