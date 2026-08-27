import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'onboarding_event.dart';
part 'onboarding_state.dart';

class OnboardingPageData {
  final String title;
  final String subtitle;
  final String imageUrl;
  final IconData icon;

  const OnboardingPageData({
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.icon,
  });
}

class OnboardingBloc extends Bloc<OnboardingEvent, OnboardingState> {
  OnboardingBloc() : super(const OnboardingInitial()) {
    on<OnboardingStarted>(_onStarted);
    on<OnboardingNextPage>(_onNextPage);
    on<OnboardingPreviousPage>(_onPreviousPage);
    on<OnboardingPageChanged>(_onPageChanged);
    on<OnboardingComplete>(_onComplete);
  }

  void _onStarted(
    OnboardingStarted event,
    Emitter<OnboardingState> emit,
  ) {
    final pages = _getPages();
    emit(OnboardingLoaded(
      pages: pages,
      currentIndex: 0,
    ));
  }

  void _onNextPage(
    OnboardingNextPage event,
    Emitter<OnboardingState> emit,
  ) {
    final state = this.state;
    if (state is OnboardingLoaded) {
      if (!state.isLastPage) {
        emit(OnboardingLoaded(
          pages: state.pages,
          currentIndex: state.currentIndex + 1,
        ));
      }
    }
  }

  void _onPreviousPage(
    OnboardingPreviousPage event,
    Emitter<OnboardingState> emit,
  ) {
    final state = this.state;
    if (state is OnboardingLoaded) {
      if (!state.isFirstPage) {
        emit(OnboardingLoaded(
          pages: state.pages,
          currentIndex: state.currentIndex - 1,
        ));
      }
    }
  }

  void _onPageChanged(
    OnboardingPageChanged event,
    Emitter<OnboardingState> emit,
  ) {
    final state = this.state;
    if (state is OnboardingLoaded) {
      if (event.index >= 0 && event.index < state.pages.length) {
        emit(OnboardingLoaded(
          pages: state.pages,
          currentIndex: event.index,
        ));
      }
    }
  }

  Future<void> _onComplete(
    OnboardingComplete event,
    Emitter<OnboardingState> emit,
  ) async {
    emit(const OnboardingLoading());
    await Future.delayed(const Duration(milliseconds: 300));
    emit(const OnboardingCompleted());
  }

  List<OnboardingPageData> _getPages() {
    return const [
      // ✅ الصفحة 1: الترحيب
      OnboardingPageData(
        title: 'مرحباً بك في لقمة',
        subtitle:
            'تطبيق يهدف إلى تقليل هدر الطعام وربط المتبرعين بالجمعيات الخيرية',
        imageUrl: 'assets/images/onboarding_1.png',
        icon: Icons.volunteer_activism,
      ),
      // ✅ الصفحة 2: فكرة التطبيق
      OnboardingPageData(
        title: 'أنقذ الطعام... واصنع أثرًا',
        subtitle:
            'ساهم في تقليل هدر الطعام وربط المتبرعين بالجمعيات الخيرية بطريقة ذكية وسريعة',
        imageUrl: 'assets/images/onboarding_2.png',
        icon: Icons.restaurant,
      ),
      // ✅ الصفحة 3: كيف يعمل
      OnboardingPageData(
        title: 'كيف يعمل التطبيق؟',
        subtitle:
            'المطاعم تعلن عن فائض الطعام، المتطوعون ينقلونه للجمعيات الخيرية',
        imageUrl: 'assets/images/onboarding_3.png',
        icon: Icons.settings_overscan,
      ),
      // ✅ الصفحة 4: دورك كمتطوع
      OnboardingPageData(
        title: 'دورك كمتطوع',
        subtitle:
            'استلم الطعام من المطعم، قم بتوصيله للجمعية، واحصل على نقاط وشارات تقديراً لمجهودك',
        imageUrl: 'assets/images/onboarding_4.png',
        icon: Icons.emoji_events,
      ),
      // ✅ الصفحة 5: التأثير الإيجابي
      OnboardingPageData(
        title: 'أثرك يبدأ من هنا',
        subtitle:
            'كل وجبة تنقذها تصنع فرقاً في حياة الآخرين وتحمي البيئة من الهدر',
        imageUrl: 'assets/images/onboarding_5.png',
        icon: Icons.eco,
      ),
    ];
  }
}
