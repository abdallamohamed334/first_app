part of 'onboarding_bloc.dart';

abstract class OnboardingEvent {
  const OnboardingEvent();
}

class OnboardingStarted extends OnboardingEvent {
  const OnboardingStarted();
}

class OnboardingNextPage extends OnboardingEvent {
  const OnboardingNextPage();
}

class OnboardingPreviousPage extends OnboardingEvent {
  const OnboardingPreviousPage();
}

class OnboardingComplete extends OnboardingEvent {
  const OnboardingComplete();
}

class OnboardingPageChanged extends OnboardingEvent {
  final int index;
  const OnboardingPageChanged(this.index);
}
