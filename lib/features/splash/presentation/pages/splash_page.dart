import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:loqma/core/models/user_model.dart';
import 'package:loqma/core/repositories/auth_repository.dart';
import 'package:loqma/core/services/supabase_service.dart';
import 'package:loqma/routes/app_router.dart';
import 'package:loqma/core/services/auth_identity_resolver.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with TickerProviderStateMixin {
  late final AnimationController _scaleController;
  late final AnimationController _fadeController;
  late final AnimationController _progressController;
  late final AnimationController _glowController;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _progressAnimation;
  late final Animation<double> _glowAnimation;
  Timer? _progressTimer;
  bool _isNavigating = false;

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
      CurvedAnimation(
        parent: _glowController,
        curve: Curves.easeInOut,
      ),
    );
    _glowController.repeat(reverse: true);
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

    // استخدم GoRouter بدل Navigator حتى لا تبقى Route قديمة
    // تعيد فتح Onboarding أو Login بعد الانتقال.
    // Never default an existing session to Home or the public charities list.
    // A session is routed only after its authoritative identity is resolved.
    String nextLocation = AppRouter.login;
    final client = Supabase.instance.client;

    // Supabase may still be restoring the persisted session when the splash
    // timer fires. Wait for the initial auth event before deciding whether to
    // show onboarding/login; otherwise users see a brief login flash.
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
        final resolved =
            await AuthIdentityResolver.resolve(client, session.user.id);
        if (resolved == 'user') {
          nextLocation = AppRouter.home;
        } else if (resolved == 'charity')
          nextLocation = AppRouter.charityHome;
        else if (resolved == 'restaurant')
          nextLocation = AppRouter.restaurantHome;
        else
          nextLocation = AppRouter.login;
      } catch (error) {
        debugPrint('⚠️ Could not resolve session identity: $error');
        nextLocation = AppRouter.login;
      }
    } else {
      final prefs = await SharedPreferences.getInstance();
      final onboardingSeen = prefs.getBool('onboarding_seen') ??
          prefs.getBool('onboarding_completed') ??
          prefs.getBool('has_seen_onboarding') ??
          false;

      nextLocation = onboardingSeen ? AppRouter.login : AppRouter.onboarding;
    }

    if (!mounted) return;
    context.go(nextLocation);
  }

  // Resolver moved to AuthIdentityResolver to avoid duplicated logic.

  @override
  void dispose() {
    _scaleController.dispose();
    _fadeController.dispose();
    _progressController.dispose();
    _glowController.dispose();
    _progressTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFFF4EEE5),
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
            // ✅ خلفية مع تدرج
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFFF4EEE5),
                    const Color(0xFFE6D9C8),
                  ],
                ),
              ),
            ),
            // ✅ نمط الخلفية
            _buildFoodPattern(context),
            // ✅ محتوى وسطي
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // ✅ شعار مع glow - تمرير colorScheme
                  _buildLogo(colorScheme),
                  const SizedBox(height: 30),
                  // ✅ اسم التطبيق مع حركة
                  _buildAppInfo(context),
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

  // ============ LOGO ============
  Widget _buildLogo(ColorScheme colorScheme) {
    final rotationAnimation = Tween<double>(
      begin: -0.012,
      end: 0,
    ).animate(
      CurvedAnimation(
        parent: _scaleController,
        curve: Curves.easeOutBack,
      ),
    );

    return ScaleTransition(
      scale: _scaleAnimation,
      child: RotationTransition(
        turns: rotationAnimation,
        child: Stack(
          alignment: Alignment.center,
          children: [
            AnimatedBuilder(
              animation: _glowAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _glowAnimation.value,
                  child: Container(
                    width: 210,
                    height: 210,
                    decoration: BoxDecoration(
                      color: const Color(0xFF315A45).withValues(alpha: 0.07),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color:
                              const Color(0xFFC78950).withValues(alpha: 0.16),
                          blurRadius: 64,
                          spreadRadius: 28,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            Container(
              width: 142,
              height: 142,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBF5),
                borderRadius: BorderRadius.circular(38),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFC78950).withValues(alpha: 0.18),
                    blurRadius: 42,
                    spreadRadius: 10,
                  ),
                  BoxShadow(
                    color: const Color(0xFF315A45).withValues(alpha: 0.14),
                    blurRadius: 28,
                    offset: const Offset(0, 16),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: Image.asset(
                  'assets/images/loqma_launcher_icon.png',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: colorScheme.primary,
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.restaurant_rounded,
                      size: 64,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============ APP INFO ============
  Widget _buildAppInfo(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Column(
        children: [
          Text(
            'Loqma',
            style: TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF244536),
              height: 1.1,
              letterSpacing: -0.5,
              shadows: [
                BoxShadow(
                  color: const Color(0xFF315A45).withValues(alpha: 0.12),
                  blurRadius: 20,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'كل وجبة تصنع فرقًا',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF315A45).withValues(alpha: 0.78),
              letterSpacing: 0.5,
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
            color: const Color(0xFF315A45).withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(4),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: _progressAnimation.value,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFC78950),
                borderRadius: BorderRadius.circular(4),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF315A45).withValues(alpha: 0.58),
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
            'استدامة . عطاء . لقمة',
            style: TextStyle(
              color: const Color(0xFF315A45).withValues(alpha: 0.58),
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
              color: const Color(0xFF315A45).withValues(alpha: 0.36),
              fontSize: 11,
              fontWeight: FontWeight.w400,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ============ FOOD PATTERN ============
  Widget _buildFoodPattern(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: double.infinity,
      child: CustomPaint(
        painter: _FoodPatternPainter(),
      ),
    );
  }
}

// ============ PATTERN PAINTER ============
class _FoodPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF315A45).withValues(alpha: 0.06)
      ..style = PaintingStyle.fill;

    const spacing = 60.0;
    const dotSize = 6.0;

    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(
          Offset(x, y),
          dotSize / 2,
          paint,
        );
      }
    }

    final paint2 = Paint()
      ..color = const Color(0xFFC78950).withValues(alpha: 0.05)
      ..style = PaintingStyle.fill;

    for (double x = spacing / 2; x < size.width; x += spacing) {
      for (double y = spacing / 2; y < size.height; y += spacing) {
        canvas.drawCircle(
          Offset(x, y),
          dotSize / 2.5,
          paint2,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
