import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    emit(OnboardingLoaded(pages: _getPages(), currentIndex: 0));
  }

  void _onNextPage(
    OnboardingNextPage event,
    Emitter<OnboardingState> emit,
  ) {
    final current = state;
    if (current is OnboardingLoaded && !current.isLastPage) {
      emit(OnboardingLoaded(
        pages: current.pages,
        currentIndex: current.currentIndex + 1,
      ));
    }
  }

  void _onPreviousPage(
    OnboardingPreviousPage event,
    Emitter<OnboardingState> emit,
  ) {
    final current = state;
    if (current is OnboardingLoaded && !current.isFirstPage) {
      emit(OnboardingLoaded(
        pages: current.pages,
        currentIndex: current.currentIndex - 1,
      ));
    }
  }

  void _onPageChanged(
    OnboardingPageChanged event,
    Emitter<OnboardingState> emit,
  ) {
    final current = state;
    if (current is OnboardingLoaded &&
        event.index >= 0 &&
        event.index < current.pages.length) {
      emit(OnboardingLoaded(pages: current.pages, currentIndex: event.index));
    }
  }

  Future<void> _onComplete(
    OnboardingComplete event,
    Emitter<OnboardingState> emit,
  ) async {
    emit(const OnboardingLoading());
    await Future<void>.delayed(const Duration(milliseconds: 250));
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool('onboarding_seen', true);
    } catch (error) {
      debugPrint('[Onboarding] Could not persist completion: $error');
    }
    emit(const OnboardingCompleted());
  }

  List<OnboardingPageData> _getPages() {
    return const [
      OnboardingPageData(
        title: 'كل الخدمات في مكان واحد',
        subtitle:
            'اكتشف مقدمي خدمات قريبين منك، من الخياطين وفنيي صيانة الكمبيوتر إلى الخدمات المنزلية.',
        imageUrl: 'assets/images/khedma_icon.png',
        icon: Icons.handyman_rounded,
      ),
      OnboardingPageData(
        title: 'اختَر مقدم الخدمة الأنسب',
        subtitle:
            'قارن التخصصات والتقييمات والموقع، واطّلع على تفاصيل مقدم الخدمة قبل التواصل.',
        imageUrl: 'assets/images/khedma_icon.png',
        icon: Icons.location_searching_rounded,
      ),
      OnboardingPageData(
        title: 'انشر احتياجك للخدمة',
        subtitle:
            'اكتب الخدمة التي تحتاجها، واستقبل تواصل مقدمي الخدمات وتابع احتياجك بسهولة.',
        imageUrl: 'assets/images/khedma_icon.png',
        icon: Icons.assignment_rounded,
      ),
    ];
  }
}
