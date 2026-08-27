// lib/features/booking/presentation/bloc/booking_event.dart

part of 'booking_bloc.dart';

abstract class BookingEvent extends Equatable {
  const BookingEvent();

  @override
  List<Object?> get props => [];
}

class LoadBookings extends BookingEvent {
  final String userId;
  const LoadBookings(this.userId);

  @override
  List<Object?> get props => [userId];
}

class RefreshBookings extends BookingEvent {
  final String userId;
  const RefreshBookings(this.userId);

  @override
  List<Object?> get props => [userId];
}

class CancelBooking extends BookingEvent {
  final String bookingId;
  const CancelBooking(this.bookingId);

  @override
  List<Object?> get props => [bookingId];
}
