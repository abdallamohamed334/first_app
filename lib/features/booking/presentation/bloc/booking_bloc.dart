import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import '../../data/repositories/booking_repository.dart';
import '../../domain/entities/booking.dart';

part 'booking_event.dart';
part 'booking_state.dart';

class BookingBloc extends Bloc<BookingEvent, BookingState> {
  final BookingRepository _repository;

  BookingBloc(this._repository) : super(BookingInitial()) {
    on<LoadBookings>(_onLoadBookings);
    on<RefreshBookings>(_onRefreshBookings);
    on<CancelBooking>(_onCancelBooking);
  }

  Future<void> _onLoadBookings(
    LoadBookings event,
    Emitter<BookingState> emit,
  ) async {
    final userId = event.userId.trim();
    if (userId.isEmpty) {
      emit(const BookingError('لم يتم العثور على المستخدم الحالي'));
      return;
    }

    emit(BookingLoading());
    try {
      final bookings = await _repository.getMyBookings(userId);
      emit(BookingLoaded(bookings));
    } catch (_) {
      emit(const BookingError('تعذر تحميل الحجوزات حاليًا'));
    }
  }

  Future<void> _onRefreshBookings(
    RefreshBookings event,
    Emitter<BookingState> emit,
  ) async {
    final userId = event.userId.trim();
    if (userId.isEmpty) {
      emit(const BookingError('لم يتم العثور على المستخدم الحالي'));
      return;
    }

    try {
      final bookings = await _repository.getMyBookings(userId);
      emit(BookingLoaded(bookings));
    } catch (_) {
      emit(const BookingError('تعذر تحديث الحجوزات حاليًا'));
    }
  }

  Future<void> _onCancelBooking(
    CancelBooking event,
    Emitter<BookingState> emit,
  ) async {
    final currentState = state;
    if (currentState is! BookingLoaded) {
      emit(const BookingError('انتظر حتى يتم تحميل الحجوزات أولًا'));
      return;
    }

    final booking = currentState.bookings.cast<Booking?>().firstWhere(
          (item) => item?.id == event.bookingId,
          orElse: () => null,
        );

    if (booking == null) {
      emit(const BookingError('الحجز غير موجود في القائمة الحالية'));
      return;
    }

    final userId = booking.userId.trim();
    if (userId.isEmpty) {
      emit(const BookingError('لا يوجد مستخدم مرتبط بهذا الحجز'));
      return;
    }

    try {
      final success = await _repository.cancelBooking(
        event.bookingId,
        userId: userId,
      );

      if (!success) {
        emit(const BookingError(
          'تعذر إلغاء الحجز. قد يكون تغيّر حالته أو تم إلغاؤه بالفعل.',
        ));
        return;
      }

      // نعيد القراءة من Supabase بدل تعديل العنصر محليًا فقط.
      // هذا يضمن أن الشاشة تعكس الحالة الحقيقية في قاعدة البيانات.
      final updatedBookings = await _repository.getMyBookings(userId);
      emit(BookingLoaded(updatedBookings));
    } catch (_) {
      emit(const BookingError('تعذر إلغاء الحجز حاليًا'));
    }
  }
}
// lib/features/booking/presentation/bloc/booking_event.dart
