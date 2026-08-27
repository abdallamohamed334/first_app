import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'splash_event.dart';
part 'splash_state.dart';

class SplashBloc extends Bloc<SplashEvent, SplashState> {
  SplashBloc() : super(const SplashInitial()) {
    on<SplashStarted>(_onSplashStarted);
    on<SplashAnimationComplete>(_onAnimationComplete);
  }

  Future<void> _onSplashStarted(
    SplashStarted event,
    Emitter<SplashState> emit,
  ) async {
    emit(const SplashAnimating());

    // Simulate checking auth (will be replaced later)
    await Future.delayed(const Duration(milliseconds: 3200));

    // TODO: Replace with actual auth check later
    const isAuthenticated = false;

    if (isAuthenticated) {
      emit(const SplashAuthenticated());
    } else {
      emit(const SplashUnauthenticated());
    }
  }

  void _onAnimationComplete(
    SplashAnimationComplete event,
    Emitter<SplashState> emit,
  ) {
    // Handle animation complete if needed
  }
}
