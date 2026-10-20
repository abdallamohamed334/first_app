// lib/features/auth/presentation/pages/login_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dartz/dartz.dart' as dartz;
import 'package:go_router/go_router.dart';
import 'package:loqma/core/repositories/auth_repository.dart';
import 'package:loqma/core/models/user_model.dart';
import 'package:loqma/core/services/auth_state_notifier.dart';
import 'package:loqma/core/services/supabase_service.dart';
import 'package:loqma/routes/app_router.dart';

import 'package:loqma/core/services/firebase_messaging_service.dart';

import '../widgets/auth_button.dart';
import '../widgets/auth_text_field.dart';
import 'otp_verify_page.dart';
import 'user_profile_setup_flow.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, this.initialMessage});

  final String? initialMessage;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  final _phoneController = TextEditingController();
  final AuthRepository _authRepo = AuthRepository(SupabaseService());

  final FirebaseMessagingService _fcmService =
      FirebaseMessagingService.instance;
  late final AnimationController _animationController;
  late final Animation<double> _fadeAnimation;
  // ✅ أنيميشن دخول إضافي للوجو (Scale) — بيستخدم نفس الـ controller
  late final Animation<double> _logoScaleAnimation;

  bool _isLoading = false;
  bool _isCheckingAutoLogin = true;

  // ألوان Khedma: أحمر العلامة التجارية مع درجات محايدة.
  static const _bg = Color(0xFFF7F8FA);
  static const _primary = Color(0xFFFF2E3B);
  static const _darkGreen = Color(0xFF1B1D22);
  static const _red = Color(0xFFE53946);
  static const _cardBorder = Color(0xFFE2E6EC);

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );

    _logoScaleAnimation = Tween<double>(begin: 0.85, end: 1).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutBack,
      ),
    );

    _animationController.forward();
    _checkAutoLogin();
    if (widget.initialMessage != null && widget.initialMessage!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showError(widget.initialMessage!);
      });
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingAutoLogin) return _buildCheckingScreen();

    final colors = Theme.of(context).colorScheme;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: colors.surface,
        body: AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.dark,
          child: Stack(
            children: [
              _buildBackground(),
              SafeArea(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Column(
                      children: [
                        _buildTopBar(),
                        const SizedBox(height: 22),
                        _buildBrand(),
                        const SizedBox(height: 22),
                        _buildLoginCard(),
                        const SizedBox(height: 22),
                        _buildBackLink(),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // Checking Screen
  // ═══════════════════════════════════════════════════════════
  Widget _buildCheckingScreen() {
    final colors = Theme.of(context).colorScheme;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: colors.surface,
        body: Stack(
          children: [
            _buildBackground(),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _LoginLogo(size: 68),
                  SizedBox(height: 26),
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      color: _primary,
                      strokeWidth: 2.6,
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'جاري التحقق من الجلسة...',
                    style: TextStyle(
                      color: colors.onSurface,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // خلفية هادئة لا تنافس النموذج أو الشعار.
  Widget _buildBackground() {
    final colors = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [colors.surfaceContainerLow, colors.surface],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // Top Bar
  // ═══════════════════════════════════════════════════════════
  Widget _buildTopBar() {
    final colors = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          onPressed: _isLoading
              ? null
              : () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go(AppRouter.userTypeSelection);
                  }
                },
          icon: const Icon(Icons.arrow_forward_rounded),
          style: IconButton.styleFrom(
            backgroundColor: colors.surfaceContainerHighest,
            foregroundColor: colors.onSurface,
            padding: const EdgeInsets.all(12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            elevation: 0,
          ).copyWith(
            shadowColor: WidgetStateProperty.all(Colors.transparent),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: _cardBorder),
          ),
          child: const Text(
            'Khedma',
            style: TextStyle(
              color: _primary,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 46),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  // Brand
  // ═══════════════════════════════════════════════════════════
  Widget _buildBrand() {
    return Column(
      children: [
        ScaleTransition(
          scale: _logoScaleAnimation,
          child: const _LoginLogo(size: 62),
        ),
        const SizedBox(height: 14),
        const Text(
          'تسجيل دخول المستخدم',
          style: TextStyle(
            color: _darkGreen,
            fontSize: 25,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'اكتب رقم الموبايل المرتبط بحسابك.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _darkGreen.withValues(alpha: 0.62),
            fontSize: 13,
            height: 1.55,
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  // Login Card
  // ═══════════════════════════════════════════════════════════
  Widget _buildLoginCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(19, 21, 19, 19),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _cardBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x080F172A),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ادخل رقم الموبايل المسجّل في حسابك',
            style: TextStyle(
              color: _darkGreen,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 15),
          AuthTextField(
            controller: _phoneController,
            label: 'رقم الموبايل',
            hint: '01012345678',
            prefixIcon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9٠-٩+ ]')),
              LengthLimitingTextInputFormatter(16),
            ],
          ),
          const SizedBox(height: 13),
          _buildWhatsAppNotice(),
          const SizedBox(height: 18),
          AuthButton(
            text: 'إرسال كود التحقق',
            isLoading: _isLoading,
            onPressed: _handleLogin,
            icon: Icons.chat_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildWhatsAppNotice() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7F6),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFF128C7E).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.chat_rounded,
              color: Color(0xFF128C7E),
              size: 17,
            ),
          ),
          const SizedBox(width: 9),
          const Expanded(
            child: Text(
              'كود التحقق هيوصلك على واتساب.',
              style: TextStyle(
                color: Color(0xFF41464F),
                fontSize: 12,
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // ✅ روابط التسجيل وتغيير نوع الحساب
  // ═══════════════════════════════════════════════════════════
  Widget _buildBackLink() {
    return Column(
      children: [
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Text(
              'أول مرة تستخدم Khedma؟',
              style: TextStyle(color: _darkGreen, fontSize: 12.5),
            ),
            TextButton(
              onPressed: _isLoading
                  ? null
                  : () => context.push('${AppRouter.register}?role=user'),
              style: TextButton.styleFrom(
                foregroundColor: _primary,
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'إنشاء حساب جديد',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Text(
              'حسابك من نوع تاني؟',
              style: TextStyle(color: _darkGreen, fontSize: 12.5),
            ),
            TextButton(
              onPressed: _isLoading
                  ? null
                  : () => context.push(AppRouter.userTypeSelection),
              style: TextButton.styleFrom(
                foregroundColor: _primary,
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'اختار نوع الحساب',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<Map<String, dynamic>?> _findProviderByUserId(String userId) async {
    final row = await SupabaseService()
        .client
        .from('service_providers')
        .select('id, user_id, verification_status, is_active, display_name')
        .eq('user_id', userId)
        .maybeSingle()
        .timeout(const Duration(seconds: 4));
    return row == null ? null : Map<String, dynamic>.from(row);
  }

  Future<void> _showProviderBlockedMessage({
    required Map<String, dynamic> provider,
    bool offerProviderLogin = true,
  }) async {
    final status =
        provider['verification_status']?.toString().trim().toLowerCase();
    final isActive = provider['is_active'] as bool? ?? true;
    final isRejected = status == 'rejected';
    final isSuspended = !isActive || status == 'suspended';
    final title = isRejected
        ? 'تم رفض حساب مزود الخدمة'
        : isSuspended
            ? 'تم إيقاف حساب مزود الخدمة'
            : 'الرقم مسجل كمزود خدمة';
    final message = isRejected
        ? 'لا يمكن الدخول بهذا الرقم كمستخدم عادي لأن طلب مزود الخدمة تم رفضه. تواصل مع الدعم لمعرفة السبب.'
        : isSuspended
            ? 'تم إيقاف حساب مزود الخدمة. لا يمكن استخدام الرقم كمستخدم عادي. تواصل مع الدعم.'
            : 'هذا الرقم مرتبط بحساب مزود خدمة. استخدم دخول مزود الخدمة بدلًا من دخول المستخدم.';

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(title, textAlign: TextAlign.right),
        content: Text(message, textAlign: TextAlign.right),
        actions: [
          if (offerProviderLogin && !isRejected && !isSuspended)
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                context.push(AppRouter.providerAuth);
              },
              child: const Text('دخول مزود الخدمة'),
            ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('حسنًا'),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // Auto Login Check
  // ═══════════════════════════════════════════════════════════
  Future<void> _checkAutoLogin() async {
    try {
      // A stale/offline Supabase session must not keep the login page on the
      // loading screen. Keep this short because this is an optional restore;
      // the user must be able to start a fresh OTP flow immediately.
      final result = await _authRepo.getSessionWithUserType().timeout(
            const Duration(seconds: 3),
            onTimeout: () => const dartz.Left('انتهت مهلة فحص الجلسة'),
          );
      await result.fold(
        (error) async {
          debugPrint('ℹ️ No auto-login: $error');
          if (mounted) {
            setState(() => _isCheckingAutoLogin = false);
            if (error.contains('تم حذف حسابك')) _showError(error);
          }
        },
        (data) async {
          final user = data['user'] as UserModel;
          Map<String, dynamic>? provider;
          try {
            provider = await _findProviderByUserId(user.id);
          } catch (error) {
            debugPrint('ℹ️ Provider auto-check skipped: $error');
          }
          if (provider != null) {
            await SupabaseService().signOut();
            if (!mounted) return;
            await _showProviderBlockedMessage(provider: provider);
            return;
          }
          if (!mounted) return;
          await _navigateToHome(user);
        },
      );
    } catch (e) {
      debugPrint('❌ Auto-login error: $e');
      if (mounted) setState(() => _isCheckingAutoLogin = false);
    } finally {
      if (mounted && _isCheckingAutoLogin) {
        setState(() => _isCheckingAutoLogin = false);
      }
    }
  }

  // ═══════════════════════════════════════════════════════════
  // Handle Login — Send OTP
  // ═══════════════════════════════════════════════════════════
  Future<void> _handleLogin() async {
    final phone = _normalizeEgyptianPhone(_phoneController.text);

    if (!RegExp(r'^01[0125]\d{8}$').hasMatch(phone)) {
      _showError('أدخل رقم هاتف مصري صحيح (11 رقم يبدأ بـ 010/011/012/015)');
      return;
    }

    setState(() => _isLoading = true);

    try {
      debugPrint('[Login] sending OTP request');

      final result = await _authRepo.sendOtp(phone: phone);

      if (!mounted) return;

      await result.fold(
        (error) async {
          setState(() => _isLoading = false);
          _showError(error);
        },
        (returnedPhone) async {
          // ✅ نروح لصفحة OTP
          final verified = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) => OtpVerifyPage(
                phone: returnedPhone,
                profile: {
                  'role': 'user',
                  'isLogin': true,
                },
              ),
            ),
          );

          if (!mounted) return;
          setState(() => _isLoading = false);

          // ✅ لو رجع true (مستخدم قديم) → نروح Home
          // ⚠️ لو مستخدم جديد → OtpVerifyPage راحت CompleteProfile مباشرة
          if (verified == true) {
            final userResult = await _authRepo.getCurrentUserFromDb();
            await userResult.fold(
              (error) async {
                _showError(error);
              },
              (user) async {
                try {
                  await _fcmService.initialize();
                } catch (e) {
                  debugPrint('⚠️ FCM init skipped: ${e.runtimeType}');
                }

                await _registerDevice();
                if (mounted) {
                  await _navigateToHome(user);
                }
              },
            );
          }
        },
      );
    } catch (e, stackTrace) {
      debugPrint('❌ [Login] type=${e.runtimeType}');
      debugPrint('❌ [Login] error=$e');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        setState(() => _isLoading = false);
        _showError('تعذر تسجيل الدخول، حاول تاني');
      }
    }
  }

  // ═══════════════════════════════════════════════════════════
  // Register Device
  // ═══════════════════════════════════════════════════════════
  Future<void> _registerDevice() async {
    try {
      final supabase = SupabaseService();
      await supabase.registerCurrentDevice();
      debugPrint('✅ Device registered');
    } catch (e) {
      debugPrint('❌ Error registering device: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════
  // Navigation — 3 roles
  // ═══════════════════════════════════════════════════════════
  Future<void> _navigateToHome(UserModel user) async {
    if (!mounted) return;

    final auth = AuthStateNotifier.instance;
    if (!auth.isLoggedIn || auth.isSyncing || !auth.isResolved) {
      _showError('تعذر تأكيد نوع الحساب. حاول تسجيل الدخول مرة أخرى.');
      return;
    }

    final role = auth.role ?? 'unknown';
    debugPrint('🔴 [Login] navigating for resolved role: $role');

    if (role == 'user') {
      await UserProfileSetupFlow.open(
        context,
        user,
        role: role,
      );
      return;
    }

    if (role == 'provider') {
      _showError('هذا الرقم مسجل كمزود خدمة. استخدم دخول مزود الخدمة.');
      return;
    }

    final route = auth.homeRoute;
    if (route != null) {
      context.go(route);
      return;
    }

    debugPrint('❌ Unknown role: $role');
    _showError('نوع الحساب غير معروف');
  }

  // ═══════════════════════════════════════════════════════════
  // Helpers
  // ═══════════════════════════════════════════════════════════
  String _normalizeEgyptianPhone(String value) {
    var phone = value
        .trim()
        .replaceAll('٠', '0')
        .replaceAll('١', '1')
        .replaceAll('٢', '2')
        .replaceAll('٣', '3')
        .replaceAll('٤', '4')
        .replaceAll('٥', '5')
        .replaceAll('٦', '6')
        .replaceAll('٧', '7')
        .replaceAll('٨', '8')
        .replaceAll('٩', '9')
        .replaceAll(RegExp(r'[\s().-]'), '');

    if (phone.startsWith('+20')) phone = phone.substring(3);
    if (phone.startsWith('0020')) phone = phone.substring(4);
    if (phone.startsWith('20') && phone.length == 12) {
      phone = phone.substring(2);
    }
    if (phone.length == 10) phone = '0$phone';
    return phone;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: _red,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Logo
// ═══════════════════════════════════════════════════════════
class _LoginLogo extends StatelessWidget {
  final double size;

  const _LoginLogo({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.24),
        border: Border.all(color: const Color(0xFFE2E6EC)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.24),
        child: Image.asset(
          'assets/images/khedma_icon.png',
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(
            color: const Color(0xFFFFE8EA),
            alignment: Alignment.center,
            child: Icon(
              Icons.person_rounded,
              size: size * 0.48,
              color: const Color(0xFFFF2E3B),
            ),
          ),
        ),
      ),
    );
  }
}
