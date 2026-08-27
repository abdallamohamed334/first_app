part of 'charity_bloc.dart';

abstract class CharityEvent {
  const CharityEvent();
}

class CharityStarted extends CharityEvent {
  const CharityStarted();
}
