import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:loqma/core/services/supabase_service.dart';

part 'charity_event.dart';
part 'charity_state.dart';

class CharityBloc extends Bloc<CharityEvent, CharityState> {
  CharityBloc() : super(const CharityInitial()) {
    on<CharityStarted>(_onStarted);
  }

  Future<void> _onStarted(
    CharityStarted event,
    Emitter<CharityState> emit,
  ) async {
    emit(const CharityLoading());

    try {
      final charities = await SupabaseService().getCharities();
      emit(CharityLoaded(charities: charities));
    } catch (e) {
      emit(CharityError(e.toString()));
    }
  }
}
