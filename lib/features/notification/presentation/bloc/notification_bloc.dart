// ============================================================
// 3️⃣ notification_bloc.dart
// ============================================================
import 'dart:async';
import 'package:bloc/bloc.dart';

import '../../domain/entities/notification.dart';
import '../../domain/usecases/get_notifications.dart';
import '../../domain/usecases/mark_as_read.dart';
import '../../domain/usecases/mark_all_as_read.dart';
import '../../domain/usecases/watch_notifications.dart';
import 'notification_event.dart';
import 'notification_state.dart';

class NotificationBloc extends Bloc<NotificationEvent, NotificationState> {
  final GetNotifications getNotifications;
  final MarkAsRead markAsRead;
  final MarkAllAsRead markAllAsRead;
  final WatchNotifications watchNotifications;

  StreamSubscription<List<AppNotification>>? _subscription;

  NotificationBloc({
    required this.getNotifications,
    required this.markAsRead,
    required this.markAllAsRead,
    required this.watchNotifications,
  }) : super(NotificationInitial()) {
    on<LoadNotifications>(_onLoadNotifications);
    on<SubscribeToNotifications>(_onSubscribeToNotifications);
    on<NotificationsUpdated>(_onNotificationsUpdated);
    on<MarkNotificationAsRead>(_onMarkAsRead);
    on<MarkAllNotificationsAsRead>(_onMarkAllAsRead);
  }

  Future<void> _onLoadNotifications(
    LoadNotifications event,
    Emitter<NotificationState> emit,
  ) async {
    emit(NotificationLoading());
    try {
      print('📌 BLoC: Loading notifications for user: ${event.userId}');

      final result = await getNotifications(event.userId);

      result.fold(
        (error) {
          print('❌ BLoC: Error loading notifications: $error');
          emit(NotificationError(error));
        },
        (notifications) {
          print('✅ BLoC: Loaded ${notifications.length} notifications');
          emit(NotificationLoaded(notifications));
        },
      );
    } catch (e) {
      print('❌ BLoC: Exception: $e');
      emit(NotificationError('حصل خطأ أثناء تحميل الإشعارات: $e'));
    }
  }

  Future<void> _onSubscribeToNotifications(
    SubscribeToNotifications event,
    Emitter<NotificationState> emit,
  ) async {
    await _subscription?.cancel();
    _subscription = watchNotifications(event.userId).listen(
      (notifications) {
        print(
            '📩 BLoC: New notification via Realtime: ${notifications.length}');
        add(NotificationsUpdated(notifications));
      },
      onError: (error) {
        print('❌ BLoC: Realtime error: $error');
        add(const NotificationsUpdated([]));
      },
    );
  }

  void _onNotificationsUpdated(
    NotificationsUpdated event,
    Emitter<NotificationState> emit,
  ) {
    print('📩 BLoC: Notifications updated: ${event.notifications.length}');
    emit(NotificationLoaded(event.notifications));
  }

  Future<void> _onMarkAsRead(
    MarkNotificationAsRead event,
    Emitter<NotificationState> emit,
  ) async {
    final current = state;
    if (current is! NotificationLoaded) return;

    final updated = current.notifications.map((n) {
      if (n.id == event.notificationId) {
        return n.copyWith(isRead: true);
      }
      return n;
    }).toList();

    emit(NotificationLoaded(updated));

    try {
      await markAsRead(event.notificationId);
      print('✅ BLoC: Mark as read success');
    } catch (e) {
      print('❌ BLoC: Mark as read exception: $e');
      emit(current);
    }
  }

  Future<void> _onMarkAllAsRead(
    MarkAllNotificationsAsRead event,
    Emitter<NotificationState> emit,
  ) async {
    final current = state;
    if (current is! NotificationLoaded) return;

    final updated =
        current.notifications.map((n) => n.copyWith(isRead: true)).toList();
    emit(NotificationLoaded(updated));

    try {
      await markAllAsRead(event.userId);
      print('✅ BLoC: Mark all as read success');
    } catch (e) {
      print('❌ BLoC: Mark all as read exception: $e');
      emit(current);
    }
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
