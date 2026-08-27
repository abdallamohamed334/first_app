import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:loqma/features/auth/presentation/pages/login_page.dart';

import '../bloc/onboarding_bloc.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage>
    with SingleTickerProviderStateMixin {
  static const _images = [
    'assets/images/onboarding_donate.png',
    'assets/images/onboarding_food.png',
    'assets/images/onboarding_impact.png',
  ];

  static const _green = Color(0xFF0B7650);
  static const _mint = Color(0xFFBFEBD7);
  static const _cream = Color(0xFFF7FBF8);
  static const _ink = Color(0xFF123F31);

  late final AnimationController _controller;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<OnboardingBloc>().add(const OnboardingStarted());
      _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: BlocConsumer<OnboardingBloc, OnboardingState>(
        listener: (context, state) {
          if (state is OnboardingCompleted && mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const LoginPage()),
            );
          }
          if (state is OnboardingLoaded && mounted) {
            _controller
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

  Widget _loadingView() {
    return const Scaffold(
      backgroundColor: _cream,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _LogoMark(size: 82),
            SizedBox(height: 22),
            CircularProgressIndicator(color: _green, strokeWidth: 3),
            SizedBox(height: 14),
            Text(
              'جاري تجهيز تجربتك...',
              style: TextStyle(color: _ink, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

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
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFE8E4),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(
                  Icons.cloud_off_rounded,
                  size: 52,
                  color: Color(0xFFD64545),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'تعذر تحميل التطبيق',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: _ink,
                ),
              ),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 22),
              FilledButton.icon(
                onPressed: () => context
                    .read<OnboardingBloc>()
                    .add(const OnboardingStarted()),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('إعادة المحاولة'),
                style: FilledButton.styleFrom(
                  backgroundColor: _green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 14,
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

  Widget _loadedView(BuildContext context, OnboardingLoaded state) {
    final page = state.pages[state.currentIndex];
    final image = _images[state.currentIndex % _images.length];

    return Scaffold(
      backgroundColor: _cream,
      body: SafeArea(
        bottom: false,
        child: FadeTransition(
          opacity: _fade,
          child: Column(
            children: [
              Expanded(
                flex: 58,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(30),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 450),
                          child: Image.asset(
                            image,
                            key: ValueKey(image),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: _mint,
                              child: const Center(
                                child: Icon(
                                  Icons.volunteer_activism_rounded,
                                  color: _green,
                                  size: 100,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(30),
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black.withValues(alpha: 0.15),
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.22),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 16,
                        right: 16,
                        left: 16,
                        child: _buildTopBar(context),
                      ),
                    ],
                  ),
                ),
              ),
              _buildBottomContent(context, state, page),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            const _LogoMark(size: 40),
            const SizedBox(width: 9),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Text(
                'Loqma',
                style: TextStyle(
                  color: _ink,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
        TextButton(
          onPressed: () => _goToLogin(context),
          style: TextButton.styleFrom(
            foregroundColor: _ink,
            backgroundColor: Colors.white.withValues(alpha: 0.88),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          child: const Text(
            'تخطي',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomContent(
    BuildContext context,
    OnboardingLoaded state,
    dynamic page,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(34)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildIndicators(state),
          const SizedBox(height: 18),
          Text(
            page.title,
            style: const TextStyle(
              color: _ink,
              fontSize: 27,
              height: 1.2,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 9),
          Text(
            page.subtitle,
            style: const TextStyle(
              color: Color(0xFF61756D),
              fontSize: 14,
              height: 1.65,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton(
              onPressed: () {
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
              style: FilledButton.styleFrom(
                backgroundColor: _green,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(17),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    state.isLastPage ? 'ابدأ رحلتك' : 'اكتشف المزيد',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Icon(Icons.arrow_back_rounded),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              '${state.currentIndex + 1} / ${state.pages.length}',
              style: const TextStyle(
                color: Color(0xFF8BA097),
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIndicators(OnboardingLoaded state) {
    return Row(
      children: List.generate(state.pages.length, (index) {
        final active = index == state.currentIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          width: active ? 32 : 8,
          height: 7,
          margin: const EdgeInsets.only(left: 6),
          decoration: BoxDecoration(
            color: active ? _green : const Color(0xFFD8E9E1),
            borderRadius: BorderRadius.circular(20),
          ),
        );
      }),
    );
  }

  void _goToLogin(BuildContext context) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
  }
}

class _LogoMark extends StatelessWidget {
  final double size;

  const _LogoMark({this.size = 76});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _OnboardingPageState._green,
        borderRadius: BorderRadius.circular(size * .30),
        boxShadow: [
          BoxShadow(
            color: _OnboardingPageState._green.withValues(alpha: 0.20),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Icon(
        Icons.volunteer_activism_rounded,
        color: Colors.white,
        size: size * .46,
      ),
    );
  }
}


