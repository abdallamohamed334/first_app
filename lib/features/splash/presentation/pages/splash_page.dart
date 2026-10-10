// lib/features/splash/presentation/pages/splash_page.dart
//
// ✅ سبلاش شاشة تطبيق "وصلة" — المنصة اللي بتوصّل الناس ببعض:
// بيع منتجات، البحث عن خدمة، والتبرع للجمعيات.
// نفس جودة ومستوى الأنيميشن بتاع سبلاش "جُود" (scale/fade/glow + نمط
// خلفية + progress bar) لكن الشعار واللوجو اتبنوا من الصفر بما إنه
// معندناش asset صورة جاهزة للتطبيق الجديد لسه — الشعار هنا متصمم
// بالكود (CustomPaint + أيقونات) فمفيش احتياج لأي ملف صورة خارجي،
// وهيفضل شغال برضو لو حبيت تستبدله بـ Image.asset لاحقًا بسهولة.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:loqma/routes/app_router.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with TickerProviderStateMixin {
  late final AnimationController _scaleController;
  late final AnimationController _fadeController;
  late final AnimationController _progressController;
  late final AnimationController _glowController;
  late final AnimationController _orbitController;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _progressAnimation;
  late final Animation<double> _glowAnimation;

  Timer? _progressTimer;
  bool _isNavigating = false;

  // ✅ نفس أنواع الحسابات التجارية المستخدمة فى باقى التطبيق
  static const _businessUserTypes = {
    'restaurant',
    'business',
    'hotel',
    'supermarket',
    'bakery',
    'cafe',
  };

  // ✅ الألوان الأساسية — نفس هوية "جُود" (كريمي/دهبي/أخضر غامق) لأنها
  // الهوية المعتمدة آخر حاجة. سيبت الثوابت هنا عشان لو حبيت تغيّرها
  // لاحقًا لهوية "وصلة" المستقلة يبقى سهل تبدّلها فى مكان واحد.
  static const _bgTop = Color(0xFFF4EEE5);
  static const _bgBottom = Color(0xFFE6D9C8);
  static const _ink = Color(0xFF244536);
  static const _inkSoft = Color(0xFF315A45);
  static const _gold = Color(0xFFC78950);
  static const _cardBg = Color(0xFFFFFBF5);

  // ✅ الأربع ركائز بتاعة التطبيق — كل واحدة بأيقونة ولون مميز، وبتدور
  // حوالين الشعار فى حركة مدارية هادية (orbit).
  static const _pillars = <_Pillar>[
    _Pillar(icon: Icons.storefront_rounded, color: Color(0xFFC78950)), // بيع
    _Pillar(icon: Icons.handyman_rounded, color: Color(0xFF6651B5)), // خدمات
    _Pillar(icon: Icons.volunteer_activism_rounded, color: Color(0xFFB54747)), // تبرع
  ];

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _startSplashSequence();
  }

  void _initAnimations() {
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _scaleAnimation = CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    );

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );

    _progressController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    );
    _progressAnimation = CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeInOut,
    );

    _glowController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _glowAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
    _glowController.repeat(reverse: true);

    // ✅ دوران هادي جدًا للأيقونات الأربعة حوالين الشعار
    _orbitController = AnimationController(
      duration: const Duration(seconds: 14),
      vsync: this,
    )..repeat();
  }

  void _startSplashSequence() {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _scaleController.forward();
    });

    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) _fadeController.forward();
    });

    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) _progressController.forward();
    });

    _progressTimer = Timer(const Duration(milliseconds: 4000), () {
      _navigateToNext();
    });
  }

  Future<void> _navigateToNext() async {
    if (_isNavigating || !mounted) return;
    _isNavigating = true;

    String nextLocation = AppRouter.login;
    final client = Supabase.instance.client;

    // ✅ انتظر استعادة الجلسة
    Session? session = client.auth.currentSession;
    if (session == null) {
      try {
        final restored = await client.auth.onAuthStateChange.first
            .timeout(const Duration(seconds: 2));
        session = restored.session;
      } catch (_) {
        session = client.auth.currentSession;
      }
    }

    if (session != null) {
      try {
        final userData = await client
            .from('users')
            .select('user_type')
            .eq('id', session.user.id)
            .maybeSingle();

        final type = userData?['user_type']?.toString().toLowerCase() ?? '';

        if (type == 'user') {
          nextLocation = AppRouter.map;
        } else if (type == 'charity') {
          nextLocation = AppRouter.charityHome;
        } else if (type == 'institution') {
          nextLocation = AppRouter.institutionsHome;
        } else if (_businessUserTypes.contains(type)) {
          nextLocation = AppRouter.restaurantHome;
        } else {
          nextLocation = AppRouter.login;
        }
      } catch (error) {
        debugPrint('⚠️ Could not resolve user type: $error');
        nextLocation = AppRouter.login;
      }
    } else {
      final prefs = await SharedPreferences.getInstance();
      final onboardingSeen = prefs.getBool('onboarding_seen') ??
          prefs.getBool('onboarding_completed') ??
          prefs.getBool('has_seen_onboarding') ??
          false;

      nextLocation =
          onboardingSeen ? AppRouter.userTypeSelection : AppRouter.onboarding;
    }

    if (!mounted) return;
    context.go(nextLocation);
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _fadeController.dispose();
    _progressController.dispose();
    _glowController.dispose();
    _orbitController.dispose();
    _progressTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgTop,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
        child: Stack(
          children: [
            // ✅ خلفية متدرجة
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [_bgTop, _bgBottom],
                ),
              ),
            ),
            // ✅ نمط خلفية هادي
            _buildPattern(),
            // ✅ المحتوى الأساسي فى النص
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildLogo(),
                  const SizedBox(height: 34),
                  _buildAppInfo(),
                ],
              ),
            ),
            // ✅ شريط التقدم
            Positioned(
              bottom: MediaQuery.of(context).size.height * 0.12,
              left: 40,
              right: 40,
              child: _buildProgress(),
            ),
            // ✅ النص السفلي
            Positioned(
              bottom: MediaQuery.of(context).viewPadding.bottom + 20,
              left: 0,
              right: 0,
              child: _buildBranding(),
            ),
          ],
        ),
      ),
    );
  }

  // ============ LOGO (شعار + أيقونات مدارية) ============
  Widget _buildLogo() {
    final rotationAnimation = Tween<double>(begin: -0.012, end: 0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeOutBack),
    );

    return ScaleTransition(
      scale: _scaleAnimation,
      child: RotationTransition(
        turns: rotationAnimation,
        child: SizedBox(
          width: 230,
          height: 230,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // ✅ توهج خلفي نابض
              AnimatedBuilder(
                animation: _glowAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _glowAnimation.value,
                    child: Container(
                      width: 210,
                      height: 210,
                      decoration: BoxDecoration(
                        color: _inkSoft.withValues(alpha: 0.07),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: _gold.withValues(alpha: 0.16),
                            blurRadius: 64,
                            spreadRadius: 28,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              // ✅ الأيقونات الأربع بتدور حوالين الشعار (الركائز الأربعة)
              AnimatedBuilder(
                animation: _orbitController,
                builder: (context, child) {
                  return Stack(
                    alignment: Alignment.center,
                    children: List.generate(_pillars.length, (index) {
                      final baseAngle =
                          (2 * math.pi / _pillars.length) * index;
                      final angle =
                          baseAngle + (_orbitController.value * 2 * math.pi);
                      const radius = 98.0;
                      final dx = radius * math.cos(angle);
                      final dy = radius * math.sin(angle);
                      final pillar = _pillars[index];

                      return Transform.translate(
                        offset: Offset(dx, dy),
                        child: FadeTransition(
                          opacity: _fadeAnimation,
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: _cardBg,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: pillar.color.withValues(alpha: 0.25),
                                width: 1.4,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: pillar.color.withValues(alpha: 0.22),
                                  blurRadius: 14,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Icon(
                              pillar.icon,
                              size: 19,
                              color: pillar.color,
                            ),
                          ),
                        ),
                      );
                    }),
                  );
                },
              ),
              // ✅ الشعار المركزي: علامة "وصلة" مرسومة بالكود — حلقتين
              // متشابكتين (رمز الوصل/الربط بين الناس وبين الاحتياج
              // والحل)، بدل ما نعتمد على صورة أيقونة غير موجودة.
              Container(
                width: 142,
                height: 142,
                decoration: BoxDecoration(
                  color: _cardBg,
                  borderRadius: BorderRadius.circular(38),
                  boxShadow: [
                    BoxShadow(
                      color: _gold.withValues(alpha: 0.18),
                      blurRadius: 42,
                      spreadRadius: 10,
                    ),
                    BoxShadow(
                      color: _inkSoft.withValues(alpha: 0.14),
                      blurRadius: 28,
                      offset: const Offset(0, 16),
                    ),
                  ],
                ),
                child: CustomPaint(
                  painter: _LinkMarkPainter(
                    ringColor: _ink,
                    accentColor: _gold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============ APP INFO ============
  Widget _buildAppInfo() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Column(
        children: [
          const Text(
            'وصلة',
            style: TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.bold,
              color: _ink,
              height: 1.1,
              letterSpacing: -0.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'وصلة بين اللي عندك واللي محتاجه',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w500,
              color: _inkSoft.withValues(alpha: 0.78),
              letterSpacing: 0.3,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ============ PROGRESS ============
  Widget _buildProgress() {
    return AnimatedBuilder(
      animation: _progressAnimation,
      builder: (context, child) {
        return Container(
          height: 4,
          decoration: BoxDecoration(
            color: _inkSoft.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(4),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: _progressAnimation.value,
            child: Container(
              decoration: BoxDecoration(
                color: _gold,
                borderRadius: BorderRadius.circular(4),
                boxShadow: [
                  BoxShadow(
                    color: _inkSoft.withValues(alpha: 0.58),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ============ BRANDING ============
  Widget _buildBranding() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Column(
        children: [
          Text(
            'بيع . خدمات . تبرّع',
            style: TextStyle(
              color: _inkSoft.withValues(alpha: 0.58),
              fontSize: 14,
              fontWeight: FontWeight.w500,
              letterSpacing: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            'v1.0.0',
            style: TextStyle(
              color: _inkSoft.withValues(alpha: 0.36),
              fontSize: 11,
              fontWeight: FontWeight.w400,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ============ BACKGROUND PATTERN ============
  Widget _buildPattern() {
    return SizedBox(
      width: double.infinity,
      height: double.infinity,
      child: CustomPaint(painter: _DotPatternPainter()),
    );
  }
}

class _Pillar {
  final IconData icon;
  final Color color;
  const _Pillar({required this.icon, required this.color});
}

// ============ شعار "وصلة" المرسوم بالكود ============
//
// حلقتين متشابكتين (زى رمز "link" لكن مرسومة بخط ناعم ومتدرج) ترمز
// للوصل بين طرفين — البائع والمشترى، صاحب الخدمة والي محتاجها،
// المتبرع والمحتاج. لو حبيت تستبدلها بصورة لوجو جاهزة فى أى وقت، يكفي
// تستبدل الـ CustomPaint دي بـ Image.asset زى ما كان موجود فى نسخة
// "جُود".
class _LinkMarkPainter extends CustomPainter {
  final Color ringColor;
  final Color accentColor;

  _LinkMarkPainter({required this.ringColor, required this.accentColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final strokeWidth = size.width * 0.11;

    final leftCenter = Offset(center.dx - size.width * 0.14, center.dy);
    final rightCenter = Offset(center.dx + size.width * 0.14, center.dy);
    final ringRadius = size.width * 0.22;

    final leftPaint = Paint()
      ..color = ringColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final rightPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // الحلقة اليمنى (خلف) بلون الذهبي
    canvas.drawCircle(rightCenter, ringRadius, rightPaint);
    // الحلقة اليسرى (قدام) باللون الأخضر الغامق
    canvas.drawCircle(leftCenter, ringRadius, leftPaint);
  }

  @override
  bool shouldRepaint(covariant _LinkMarkPainter oldDelegate) =>
      oldDelegate.ringColor != ringColor ||
      oldDelegate.accentColor != accentColor;
}

// ============ نمط خلفية منقّط هادي ============
class _DotPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF315A45).withValues(alpha: 0.06)
      ..style = PaintingStyle.fill;

    const spacing = 60.0;
    const dotSize = 6.0;

    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), dotSize / 2, paint);
      }
    }

    final paint2 = Paint()
      ..color = const Color(0xFFC78950).withValues(alpha: 0.05)
      ..style = PaintingStyle.fill;

    for (double x = spacing / 2; x < size.width; x += spacing) {
      for (double y = spacing / 2; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), dotSize / 2.5, paint2);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}