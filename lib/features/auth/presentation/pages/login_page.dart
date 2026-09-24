// lib/features/auth/presentation/pages/login_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:loqma/core/repositories/auth_repository.dart';
import 'package:loqma/core/models/user_model.dart';
import 'package:loqma/core/services/supabase_service.dart';
import 'package:loqma/routes/app_router.dart';

import 'package:loqma/core/services/firebase_messaging_service.dart';

import '../widgets/auth_button.dart';
import '../widgets/auth_text_field.dart';
import 'otp_verify_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

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

  // ── ألوان (هوية "جُود" الخضراء)
  static const _bg = Color(0xFFF4F8F6);
  static const _primary = Color(0xFF0B7650);
  static const _primaryLight = Color(0xFF25B77C);
  static const _darkGreen = Color(0xFF123F31);
  static const _red = Color(0xFFD64545);
  static const _cardBorder = Color(0xFFE1ECE7);

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

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _bg,
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
                        const SizedBox(height: 32),
                        _buildBrand(),
                        const SizedBox(height: 30),
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
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _bg,
        body: Stack(
          children: [
            _buildBackground(),
            const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _LoginLogo(size: 88),
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
                      color: _darkGreen,
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

  // ═══════════════════════════════════════════════════════════
  // ✅ Background — تدرج + دوائر توهج + نقش خفيف (نفس روح السبلاش)
  // ═══════════════════════════════════════════════════════════
  Widget _buildBackground() {
    return IgnorePointer(
      child: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFF4F8F6), Color(0xFFE9F5EF)],
              ),
            ),
          ),
          Positioned.fill(
            child: CustomPaint(painter: _DotPatternPainter()),
          ),
          Positioned(
            top: -90,
            right: -70,
            child: _glowCircle(220, const Color(0xFF8DD6B4)),
          ),
          Positioned(
            bottom: -100,
            left: -60,
            child: _glowCircle(250, const Color(0xFFC9EBDD)),
          ),
        ],
      ),
    );
  }

  Widget _glowCircle(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.3),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.22),
            blurRadius: 80,
            spreadRadius: 20,
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // Top Bar
  // ═══════════════════════════════════════════════════════════
  Widget _buildTopBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_forward_rounded),
          style: IconButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: _darkGreen,
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
            color: Colors.white,
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: _cardBorder),
          ),
          child: const Text(
            'جُود',
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
          child: const _LoginLogo(size: 92),
        ),
        const SizedBox(height: 20),
        const Text(
          'مرحبًا بعودتك 👋',
          style: TextStyle(
            color: _darkGreen,
            fontSize: 29,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'سجّل دخولك برقم هاتفك عشان تكمّل رحلتك معانا',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.black.withValues(alpha: 0.5),
            fontSize: 13.5,
            height: 1.5,
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
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: _cardBorder),
        boxShadow: [
          BoxShadow(
            color: _primary.withValues(alpha: 0.08),
            blurRadius: 34,
            offset: const Offset(0, 16),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
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
                  color: _primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.lock_outline_rounded,
                  color: _primary,
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'تسجيل الدخول',
                      style: TextStyle(
                        color: Color(0xFF153F31),
                        fontSize: 18.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'هيوصلك كود تحقق على واتساب',
                      style: TextStyle(color: Colors.black45, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildWhatsAppNotice(),
          const SizedBox(height: 20),
          AuthTextField(
            controller: _phoneController,
            label: 'رقم الهاتف',
            hint: '01012345678',
            prefixIcon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9٠-٩+ ]')),
              LengthLimitingTextInputFormatter(16),
            ],
          ),
          const SizedBox(height: 20),
          AuthButton(
            text: 'إرسال كود التحقق',
            isLoading: _isLoading,
            onPressed: _handleLogin,
            icon: Icons.send_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildWhatsAppNotice() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF0F8F3), Color(0xFFE7F5EE)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD7EADF)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF25D366), Color(0xFF128C7E)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF25D366).withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child:
                const Icon(Icons.chat_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'هنبعتلك كود تحقق على واتساب 📲',
              style: TextStyle(
                color: Color(0xFF315A49),
                fontSize: 12.5,
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
  // ✅ Back Link (بدل Register Link)
  // ═══════════════════════════════════════════════════════════
  Widget _buildBackLink() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.storefront_outlined,
            size: 15,
            color: Colors.black45,
          ),
          const SizedBox(width: 6),
          const Text(
            'عايز تسجل كمقدم خدمة أو مؤسسة؟',
            style: TextStyle(color: Colors.black54, fontSize: 12.5),
          ),
          TextButton(
            onPressed: _isLoading
                ? null
                : () => context.push(AppRouter.userTypeSelection),
            style: TextButton.styleFrom(
              foregroundColor: _primary,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'اختار نوع تاني',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
            ),
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
      final result = await _authRepo.getSessionWithUserType();
      await result.fold(
        (error) async {
          debugPrint('ℹ️ No auto-login: $error');
          if (mounted) setState(() => _isCheckingAutoLogin = false);
        },
        (data) async {
          final user = data['user'] as UserModel;
          if (!mounted) return;
          setState(() => _isCheckingAutoLogin = false);
          await _navigateToHome(user);
        },
      );
    } catch (e) {
      debugPrint('❌ Auto-login error: $e');
      if (mounted) setState(() => _isCheckingAutoLogin = false);
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
      debugPrint('📌 [Login] sending OTP to $phone');

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
                if (mounted) await _navigateToHome(user);
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

    final type = user.type.value.trim().toLowerCase();
    debugPrint('🔴 [Login] navigating for role: $type');

    if (type.isEmpty) {
      _showError('نوع الحساب غير معروف');
      return;
    }

    if (type == 'user') {
      context.go(AppRouter.home);
      return;
    }

    if (type == 'provider') {
      context.go(AppRouter.home);
      return;
    }

    if (type == 'institution') {
      context.go(AppRouter.institutionsHome);
      return;
    }

    if (type == 'charity') {
      context.go(AppRouter.charityHome);
      return;
    }

    if (type == 'admin') {
      context.go(AppRouter.home);
      return;
    }

    debugPrint('❌ Unknown role: $type');
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
        gradient: const LinearGradient(
          colors: [Color(0xFF0B7650), Color(0xFF25B77C)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(size * 0.32),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0B7650).withValues(alpha: 0.35),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Icon(
        Icons.volunteer_activism_rounded,
        size: size * 0.48,
        color: Colors.white,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// ✅ Dot Pattern Painter — نقش خلفية خفيف يضيف عمق من غير ما يزاحم
// ═══════════════════════════════════════════════════════════
class _DotPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF0B7650).withValues(alpha: 0.045)
      ..style = PaintingStyle.fill;

    const spacing = 46.0;
    const dotSize = 3.0;

    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), dotSize / 2, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
