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

class _OnboardingPageState extends State<OnboardingPage> {
  static const _background = Color(0xFFF7F8FA);
  static const _primary = Color(0xFFFF2E3B);
  static const _ink = Color(0xFF1B1D22);
  static const _muted = Color(0xFF68707C);
  static const _border = Color(0xFFE2E6EC);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<OnboardingBloc>().add(const OnboardingStarted());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: BlocConsumer<OnboardingBloc, OnboardingState>(
        listener: (context, state) {
          if (state is OnboardingCompleted && mounted) {
            context.go(AppRouter.userTypeSelection);
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
    return Scaffold(
      backgroundColor: _background,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [Color(0xFFFFF8F8), _background],
          ),
        ),
        child: const Center(
          child: SizedBox(
            width: 30,
            height: 30,
            child: CircularProgressIndicator(
              color: _primary,
              strokeWidth: 2.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _errorView(BuildContext context, String message) {
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEEF0),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.wifi_off_rounded,
                    color: _primary,
                    size: 30,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'تعذر تحميل التطبيق',
                  style: TextStyle(
                    color: _ink,
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 14,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 22),
                FilledButton.icon(
                  onPressed: () => context
                      .read<OnboardingBloc>()
                      .add(const OnboardingStarted()),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('إعادة المحاولة'),
                  style: FilledButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _loadedView(BuildContext context, OnboardingLoaded state) {
    final page = state.pages[state.currentIndex];

    return Scaffold(
      backgroundColor: _background,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [Color(0xFFFFFAFA), _background],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 10, 22, 14),
            child: Column(
              children: [
                _buildTopBar(context),
                const SizedBox(height: 8),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.only(top: 8, bottom: 12),
                    child: Column(
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 320),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          child: _FeaturePreview(
                            key: ValueKey(state.currentIndex),
                            index: state.currentIndex,
                          ),
                        ),
                        const SizedBox(height: 24),
                        _buildIndicators(state),
                        const SizedBox(height: 17),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          child: Text(
                            page.title,
                            key: ValueKey('${state.currentIndex}-title'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: _ink,
                              fontSize: 25,
                              height: 1.3,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(height: 9),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          child: Text(
                            page.subtitle,
                            key: ValueKey('${state.currentIndex}-subtitle'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: _muted,
                              fontSize: 14.5,
                              height: 1.65,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                _buildContinueButton(context, state),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.asset(
            'assets/images/khedma_icon.png',
            width: 34,
            height: 34,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(width: 9),
        const Text(
          'Khedma',
          style: TextStyle(
            color: _ink,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const Spacer(),
        TextButton(
          onPressed: () => context
              .read<OnboardingBloc>()
              .add(const OnboardingComplete()),
          style: TextButton.styleFrom(
            foregroundColor: _muted,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          ),
          child: const Text(
            'تخطي',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _buildIndicators(OnboardingLoaded state) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(state.pages.length, (index) {
        final isActive = index == state.currentIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          width: isActive ? 26 : 7,
          height: 7,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            color: isActive ? _primary : const Color(0xFFD5D9DF),
            borderRadius: BorderRadius.circular(10),
          ),
        );
      }),
    );
  }

  Widget _buildContinueButton(BuildContext context, OnboardingLoaded state) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: FilledButton(
        onPressed: () {
          if (state.isLastPage) {
            context.read<OnboardingBloc>().add(const OnboardingComplete());
          } else {
            context.read<OnboardingBloc>().add(const OnboardingNextPage());
          }
        },
        style: FilledButton.styleFrom(
          backgroundColor: _primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              state.isLastPage ? 'اختيار نوع الحساب' : 'التالي',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              state.isLastPage
                  ? Icons.check_rounded
                  : Icons.arrow_back_rounded,
              size: 19,
            ),
          ],
        ),
      ),
    );
  }
}

class _FeaturePreview extends StatelessWidget {
  const _FeaturePreview({super.key, required this.index});

  final int index;

  static const _primary = Color(0xFFFF2E3B);
  static const _ink = Color(0xFF1B1D22);
  static const _muted = Color(0xFF68707C);
  static const _border = Color(0xFFE7E9ED);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 272,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFFFFF0F1), Color(0xFFF1F2F5)],
        ),
        borderRadius: BorderRadius.circular(25),
      ),
      child: Center(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(19),
            border: Border.all(color: _border),
            boxShadow: const [
              BoxShadow(
                color: Color(0x120F172A),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset(
                      'assets/images/khedma_icon.png',
                      width: 28,
                      height: 28,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Khedma',
                    style: TextStyle(
                      color: _ink,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4F5F7),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'من التطبيق',
                      style: TextStyle(
                        color: _muted,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _previewHeader,
              const SizedBox(height: 12),
              _previewContent,
            ],
          ),
        ),
      ),
    );
  }

  Widget get _previewHeader {
    final data = switch (index) {
      0 => ('خدمات قريبة منك', Icons.handyman_rounded),
      1 => ('مقدمو الخدمات', Icons.handyman_rounded),
      _ => ('احتياجات الخدمات', Icons.assignment_rounded),
    };

    return Row(
      children: [
        Expanded(
          child: Text(
            data.$1,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _ink,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Icon(data.$2, color: _primary, size: 19),
      ],
    );
  }

  Widget get _previewContent {
    switch (index) {
      case 0:
        return Column(
          children: [
            _InfoTile(
              icon: Icons.content_cut_rounded,
              title: 'خياط محترف قريب منك',
              subtitle: 'تصفّح التخصص والتقييمات',
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _smallChip('خياطة'),
                const SizedBox(width: 6),
                _smallChip('صيانة'),
                const SizedBox(width: 6),
                _smallChip('خدمات منزلية'),
              ],
            ),
          ],
        );
      case 1:
        return Column(
          children: [
            _InfoTile(
              icon: Icons.build_rounded,
              title: 'مزوّد خدمة في محافظتك',
              subtitle: 'تصفّح التخصص والتفاصيل',
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.place_outlined, color: _muted, size: 16),
                const SizedBox(width: 5),
                const Text(
                  'اختيار حسب الموقع',
                  style: TextStyle(
                    color: _muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Container(
                  width: 62,
                  height: 6,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFDADD),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      width: 34,
                      decoration: BoxDecoration(
                        color: _primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      default:
        return Column(
          children: [
            _InfoTile(
              icon: Icons.assignment_rounded,
              title: 'اطلب خدمة تحتاجها',
              subtitle: 'وصّل احتياجك لمقدمي الخدمات',
            ),
            const SizedBox(height: 9),
            Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: _primary, size: 16),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    'تابع احتياجاتك المنشورة بسهولة',
                    style: TextStyle(
                      color: _muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Icon(Icons.chevron_left_rounded, color: _muted, size: 19),
              ],
            ),
          ],
        );
    }
  }

  Widget _smallChip(String label) {
    return Flexible(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F6F8),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: _muted,
            fontSize: 9.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  static const _primary = Color(0xFFFF2E3B);
  static const _ink = Color(0xFF1B1D22);
  static const _muted = Color(0xFF68707C);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE7E9ED)),
      ),
      child: Row(
        children: [
          Container(
            width: 39,
            height: 39,
            decoration: BoxDecoration(
              color: const Color(0xFFFFE8EA),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: _primary, size: 21),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          const Icon(Icons.chevron_left_rounded, color: _muted, size: 19),
        ],
      ),
    );
  }
}
