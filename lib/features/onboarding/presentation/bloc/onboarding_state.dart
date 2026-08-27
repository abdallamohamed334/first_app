part of 'onboarding_bloc.dart';

abstract class OnboardingState {
  const OnboardingState();
}

class OnboardingInitial extends OnboardingState {
  const OnboardingInitial();
}

class OnboardingLoading extends OnboardingState {
  const OnboardingLoading();
}

class OnboardingLoaded extends OnboardingState {
  final List<OnboardingPageData> pages;
  final int currentIndex;

  const OnboardingLoaded({
    required this.pages,
    required this.currentIndex,
  });

  bool get isFirstPage => currentIndex == 0;
  bool get isLastPage => currentIndex == pages.length - 1;
}

class OnboardingCompleted extends OnboardingState {
  const OnboardingCompleted();
}

class OnboardingError extends OnboardingState {
  final String message;
  const OnboardingError(this.message);
}
