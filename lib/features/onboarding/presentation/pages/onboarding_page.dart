// lib/features/onboarding/presentation/pages/onboarding_page.dart

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:loqma/routes/app_router.dart';

import '../bloc/onboarding_bloc.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage>
    with TickerProviderStateMixin {
  // ─── ألوان جُود ───
  static const _green = Color(0xFF0B7650);
  static const _greenLight = Color(0xFF25B77C);
  static const _greenDark = Color(0xFF064D34);
  static const _mint = Color(0xFFBFEBD7);
  static const _cream = Color(0xFFF7FBF8);
  static const _ink = Color(0xFF123F31);
  static const _inkSoft = Color(0xFF61756D);
  static const _gold = Color(0xFFE0A24C);

  // ─── Animations ───
  late final AnimationController _fadeController;
  late final AnimationController _staggerController;
  late final AnimationController _floatController;

  late final Animation<double> _fade;
  late final Animation<double> _float;

  int _lastIndex = 0;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );
    _fade = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);

    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
    _float = CurvedAnimation(
      parent: _floatController,
      curve: Curves.easeInOutSine,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<OnboardingBloc>().add(const OnboardingStarted());
      _fadeController.forward();
      _staggerController.forward();
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _staggerController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: BlocConsumer<OnboardingBloc, OnboardingState>(
        listener: (context, state) {
          if (state is OnboardingCompleted && mounted) {
            context.go(AppRouter.userTypeSelection);
          }
          if (state is OnboardingLoaded && mounted) {
            if (state.currentIndex != _lastIndex) {
              _lastIndex = state.currentIndex;
              _staggerController
                ..reset()
                ..forward();
            }
            _fadeController
              ..reset()
              ..forward();
          }
        },
        builder: (context, state) {
          if (state is OnboardingLoading || state is OnboardingInitial) {
            return _loadingView();
          }
          if (state is OnboardingError) {
            return _errorView(context, state.message);
          }
          if (state is OnboardingLoaded) {
            return _loadedView(context, state);
          }
          return _loadingView();
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // LOADING
  // ═══════════════════════════════════════════════════════════

  Widget _loadingView() {
    return Scaffold(
      backgroundColor: _cream,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [_cream, Color(0xFFE7F3EC)],
          ),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LogoMark(size: 90),
              SizedBox(height: 26),
              SizedBox(
                width: 34,
                height: 34,
                child: CircularProgressIndicator(
                  color: _green,
                  strokeWidth: 3,
                  backgroundColor: Color(0xFFD4E8DE),
                ),
              ),
              SizedBox(height: 16),
              Text(
                'جاري تجهيز تجربتك...',
                style: TextStyle(
                  color: _ink,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // ERROR
  // ═══════════════════════════════════════════════════════════

  Widget _errorView(BuildContext context, String message) {
    return Scaffold(
      backgroundColor: _cream,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFE8E4), Color(0xFFFFF3E8)],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFD64545).withValues(alpha: 0.15),
                      blurRadius: 22,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.cloud_off_rounded,
                  size: 58,
                  color: Color(0xFFD64545),
                ),
              ),
              const SizedBox(height: 22),
              const Text(
                'تعذر تحميل التطبيق',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: _ink,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _inkSoft,
                  fontSize: 13.5,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 26),
              FilledButton.icon(
                onPressed: () => context
                    .read<OnboardingBloc>()
                    .add(const OnboardingStarted()),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text(
                  'إعادة المحاولة',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: _green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 26,
                    vertical: 15,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
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
  // LOADED VIEW
  // ═══════════════════════════════════════════════════════════

  Widget _loadedView(BuildContext context, OnboardingLoaded state) {
    final page = state.pages[state.currentIndex];

    return Scaffold(
      backgroundColor: _cream,
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeInOut,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [_cream, Color(0xFFEBF5EF)],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // ── الشريط العلوي
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
                child: _buildTopBar(context),
              ),

              // ── الرسمة المدمجة
              Expanded(
                flex: 6,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
                  child: FadeTransition(
                    opacity: _fade,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 550),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (child, animation) {
                        return FadeTransition(
                          opacity: animation,
                          child: ScaleTransition(
                            scale: Tween<double>(begin: 1.06, end: 1.0).animate(
                              CurvedAnimation(
                                parent: animation,
                                curve: Curves.easeOutCubic,
                              ),
                            ),
                            child: child,
                          ),
                        );
                      },
                      child: _OnboardingIllustration(
                        key: ValueKey(state.currentIndex),
                        index: state.currentIndex,
                        float: _float,
                      ),
                    ),
                  ),
                ),
              ),

              // ── المحتوى السفلي
              _buildBottomContent(context, state, page),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // TOP BAR
  // ═══════════════════════════════════════════════════════════

  Widget _buildTopBar(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            const _LogoMark(size: 40),
            const SizedBox(width: 9),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: _greenDark.withValues(alpha: 0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Text(
                'جُود',
                style: TextStyle(
                  color: _ink,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ],
        ),
        _SkipButton(
          onTap: () => _goToUserTypeSelection(context),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  // BOTTOM CONTENT
  // ═══════════════════════════════════════════════════════════

  Widget _buildBottomContent(
    BuildContext context,
    OnboardingLoaded state,
    dynamic page,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: _greenDark.withValues(alpha: 0.07),
            blurRadius: 24,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildIndicators(state),
          const SizedBox(height: 20),
          _staggeredEntry(
            index: 0,
            child: Text(
              page.title,
              style: const TextStyle(
                color: _ink,
                fontSize: 26,
                height: 1.25,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.3,
              ),
            ),
          ),
          const SizedBox(height: 10),
          _staggeredEntry(
            index: 1,
            child: Text(
              page.subtitle,
              style: const TextStyle(
                color: _inkSoft,
                fontSize: 13.5,
                height: 1.65,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 20),
          _staggeredEntry(
            index: 2,
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: _PrimaryButton(
                isLast: state.isLastPage,
                onTap: () {
                  if (state.isLastPage) {
                    context
                        .read<OnboardingBloc>()
                        .add(const OnboardingComplete());
                  } else {
                    context
                        .read<OnboardingBloc>()
                        .add(const OnboardingNextPage());
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          _staggeredEntry(
            index: 3,
            child: Center(
              child: Text(
                '${state.currentIndex + 1} / ${state.pages.length}',
                style: const TextStyle(
                  color: Color(0xFF8BA097),
                  fontWeight: FontWeight.w700,
                  fontSize: 11.5,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // STAGGERED ENTRY
  // ═══════════════════════════════════════════════════════════

  Widget _staggeredEntry({required int index, required Widget child}) {
    final start = index * 0.12;
    final end = (start + 0.4).clamp(0.0, 1.0);

    final curve = CurvedAnimation(
      parent: _staggerController,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );

    return AnimatedBuilder(
      animation: curve,
      builder: (context, _) {
        return Opacity(
          opacity: curve.value.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, (1 - curve.value) * 22),
            child: child,
          ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════
  // INDICATORS
  // ═══════════════════════════════════════════════════════════

  Widget _buildIndicators(OnboardingLoaded state) {
    return Row(
      children: List.generate(state.pages.length, (index) {
        final active = index == state.currentIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
          width: active ? 34 : 9,
          height: 8,
          margin: const EdgeInsets.only(left: 7),
          decoration: BoxDecoration(
            gradient: active
                ? const LinearGradient(colors: [_green, _greenLight])
                : null,
            color: active ? null : const Color(0xFFD8E9E1),
            borderRadius: BorderRadius.circular(20),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: _green.withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
        );
      }),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // NAVIGATION
  // ═══════════════════════════════════════════════════════════

  void _goToUserTypeSelection(BuildContext context) {
    context.go(AppRouter.userTypeSelection);
  }
}

// ═══════════════════════════════════════════════════════════════
// ONBOARDING ILLUSTRATION — رسومات مدمجة بـ Flutter
// ═══════════════════════════════════════════════════════════════

class _OnboardingIllustration extends StatelessWidget {
  final int index;
  final Animation<double> float;

  const _OnboardingIllustration({
    super.key,
    required this.index,
    required this.float,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: _OnboardingPageState._greenDark.withValues(alpha: 0.14),
            blurRadius: 32,
            offset: const Offset(0, 14),
          ),
          BoxShadow(
            color: _OnboardingPageState._greenDark.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── الخلفية المتدرجة حسب الصفحة
            _buildBackground(),
            // ── الزخارف العائمة
            _buildDecorative(),
            // ── المشهد الرئيسي
            Center(
              child: AnimatedBuilder(
                animation: float,
                builder: (context, _) {
                  return Transform.translate(
                    offset: Offset(0, float.value * -8),
                    child: _buildScene(),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // BACKGROUND
  // ═══════════════════════════════════════════════════════════

  Widget _buildBackground() {
    switch (index % 3) {
      case 0:
        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [Color(0xFFE5F5EC), Color(0xFFC7EBD8)],
            ),
          ),
        );
      case 1:
        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [Color(0xFFFFF4E0), Color(0xFFFDE6BC)],
            ),
          ),
        );
      default:
        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [Color(0xFFEDE8FB), Color(0xFFD7CCF2)],
            ),
          ),
        );
    }
  }

  // ═══════════════════════════════════════════════════════════
  // DECORATIVE SHAPES
  // ═══════════════════════════════════════════════════════════

  Widget _buildDecorative() {
    final color = _accentColor();
    return IgnorePointer(
      child: Stack(
        children: [
          // دائرة علوية
          Positioned(
            top: -30,
            right: -20,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
          ),
          // دائرة سفلية
          Positioned(
            bottom: -40,
            left: -30,
            child: Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.4),
              ),
            ),
          ),
          // نقاط مبعثرة
          Positioned(
            top: 40,
            left: 30,
            child: _dot(color.withValues(alpha: 0.4), 8),
          ),
          Positioned(
            top: 80,
            left: 60,
            child: _dot(color.withValues(alpha: 0.25), 5),
          ),
          Positioned(
            bottom: 50,
            right: 40,
            child: _dot(color.withValues(alpha: 0.35), 6),
          ),
          Positioned(
            bottom: 90,
            right: 70,
            child: _dot(color.withValues(alpha: 0.2), 4),
          ),
          // نجوم صغيرة
          Positioned(
            top: 55,
            right: 55,
            child: Icon(
              Icons.star_rounded,
              color: Colors.white.withValues(alpha: 0.7),
              size: 18,
            ),
          ),
          Positioned(
            bottom: 70,
            left: 55,
            child: Icon(
              Icons.star_rounded,
              color: Colors.white.withValues(alpha: 0.5),
              size: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _dot(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // SCENES
  // ═══════════════════════════════════════════════════════════

  Widget _buildScene() {
    switch (index % 3) {
      case 0:
        return _buildDonationScene();
      case 1:
        return _buildFoodScene();
      default:
        return _buildCommunityScene();
    }
  }

  // ─────────────────────────────────────────────
  // Scene 1: التبرع (قلب + أيادي + هدية)
  // ─────────────────────────────────────────────
  Widget _buildDonationScene() {
    return SizedBox(
      width: 200,
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // دائرة خلفية كبيرة
          Container(
            width: 170,
            height: 170,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.55),
            ),
          ),
          // قلب كبير في المنتصف
          Icon(
            Icons.favorite_rounded,
            color: _OnboardingPageState._green,
            size: 110,
          ),
          // أيقونة يد فوق القلب
          Positioned(
            top: 34,
            child: Icon(
              Icons.volunteer_activism_rounded,
              color: Colors.white,
              size: 46,
            ),
          ),
          // شرارة يسار
          Positioned(
            top: 30,
            left: 24,
            child: Icon(
              Icons.auto_awesome_rounded,
              color: _OnboardingPageState._gold,
              size: 26,
            ),
          ),
          // شرارة يمين
          Positioned(
            bottom: 34,
            right: 22,
            child: Icon(
              Icons.auto_awesome_rounded,
              color: _OnboardingPageState._gold,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Scene 2: الطعام (طبق + أدوات)
  // ─────────────────────────────────────────────
  Widget _buildFoodScene() {
    return SizedBox(
      width: 200,
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // دائرة خلفية
          Container(
            width: 170,
            height: 170,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.55),
            ),
          ),
          // الأيقونة الرئيسية (طبق / مطعم)
          Icon(
            Icons.restaurant_rounded,
            color: const Color(0xFFB57A2E),
            size: 110,
          ),
          // أيقونة يد فوق
          Positioned(
            top: 34,
            child: Icon(
              Icons.volunteer_activism_rounded,
              color: Colors.white,
              size: 46,
            ),
          ),
          // شوكة يسار
          Positioned(
            top: 30,
            left: 20,
            child: Icon(
              Icons.eco_rounded,
              color: _OnboardingPageState._green,
              size: 26,
            ),
          ),
          // شوكة يمين
          Positioned(
            bottom: 34,
            right: 20,
            child: Icon(
              Icons.local_dining_rounded,
              color: _OnboardingPageState._green,
              size: 22,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Scene 3: المجتمع (مجموعة ناس + نجوم)
  // ─────────────────────────────────────────────
  Widget _buildCommunityScene() {
    return SizedBox(
      width: 200,
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // دائرة خلفية
          Container(
            width: 170,
            height: 170,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.55),
            ),
          ),
          // الأيقونة الرئيسية
          Icon(
            Icons.groups_rounded,
            color: const Color(0xFF6B4FBF),
            size: 110,
          ),
          // أيقونة يد فوق
          Positioned(
            top: 30,
            child: Icon(
              Icons.handshake_rounded,
              color: Colors.white,
              size: 46,
            ),
          ),
          // نجوم
          Positioned(
            top: 30,
            left: 24,
            child: Icon(
              Icons.star_rounded,
              color: _OnboardingPageState._gold,
              size: 26,
            ),
          ),
          Positioned(
            bottom: 34,
            right: 22,
            child: Icon(
              Icons.auto_awesome_rounded,
              color: _OnboardingPageState._gold,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════

  Color _accentColor() {
    switch (index % 3) {
      case 0:
        return _OnboardingPageState._green;
      case 1:
        return const Color(0xFFB57A2E);
      default:
        return const Color(0xFF6B4FBF);
    }
  }
}

// ═══════════════════════════════════════════════════════════════
// SKIP BUTTON
// ═══════════════════════════════════════════════════════════════

class _SkipButton extends StatefulWidget {
  final VoidCallback onTap;
  const _SkipButton({required this.onTap});

  @override
  State<_SkipButton> createState() => _SkipButtonState();
}

class _SkipButtonState extends State<_SkipButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            color: _OnboardingPageState._ink.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: _OnboardingPageState._ink.withValues(alpha: 0.06),
            ),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'تخطي',
                style: TextStyle(
                  color: _OnboardingPageState._ink,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
              SizedBox(width: 4),
              Icon(
                Icons.keyboard_double_arrow_left_rounded,
                color: _OnboardingPageState._ink,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// PRIMARY BUTTON
// ═══════════════════════════════════════════════════════════════

class _PrimaryButton extends StatefulWidget {
  final bool isLast;
  final VoidCallback onTap;

  const _PrimaryButton({required this.isLast, required this.onTap});

  @override
  State<_PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<_PrimaryButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                _OnboardingPageState._green,
                _OnboardingPageState._greenLight,
              ],
              begin: Alignment.centerRight,
              end: Alignment.centerLeft,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: _OnboardingPageState._green.withValues(alpha: 0.35),
                blurRadius: _pressed ? 10 : 20,
                offset: Offset(0, _pressed ? 4 : 8),
              ),
            ],
          ),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  widget.isLast ? 'ابدأ رحلتك' : 'اكتشف المزيد',
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(width: 10),
                Icon(
                  widget.isLast
                      ? Icons.rocket_launch_rounded
                      : Icons.arrow_back_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// LOGO MARK
// ═══════════════════════════════════════════════════════════════

class _LogoMark extends StatelessWidget {
  final double size;

  const _LogoMark({this.size = 76});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            _OnboardingPageState._green,
            _OnboardingPageState._greenLight,
          ],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(size * .30),
        boxShadow: [
          BoxShadow(
            color: _OnboardingPageState._green.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: size * 0.14,
            right: size * 0.14,
            child: Container(
              width: size * 0.18,
              height: size * 0.18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.35),
              ),
            ),
          ),
          Icon(
            Icons.volunteer_activism_rounded,
            color: Colors.white,
            size: size * .46,
          ),
        ],
      ),
    );
  }
}
