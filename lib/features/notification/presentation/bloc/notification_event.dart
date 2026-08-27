// ============================================================
// 1️⃣ notification_event.dart
// ============================================================
import 'package:equatable/equatable.dart';
import '../../domain/entities/notification.dart';

abstract class NotificationEvent extends Equatable {
  const NotificationEvent();

  @override
  List<Object?> get props => [];
}

/// يُستدعى أول ما نفتح صفحة الإشعارات
class LoadNotifications extends NotificationEvent {
  final String userId;

  const LoadNotifications(this.userId);

  @override
  List<Object?> get props => [userId];
}

/// يبدأ الاشتراك في الـ Realtime Stream
class SubscribeToNotifications extends NotificationEvent {
  final String userId;

  const SubscribeToNotifications(this.userId);

  @override
  List<Object?> get props => [userId];
}

/// حدث داخلي بيتحرك كل ما يوصل تحديث من الـ Stream
class NotificationsUpdated extends NotificationEvent {
  final List<AppNotification> notifications;

  const NotificationsUpdated(this.notifications);

  @override
  List<Object?> get props => [notifications];
}

class MarkNotificationAsRead extends NotificationEvent {
  final String notificationId;

  const MarkNotificationAsRead(this.notificationId);

  @override
  List<Object?> get props => [notificationId];
}

class MarkAllNotificationsAsRead extends NotificationEvent {
  final String userId;

  const MarkAllNotificationsAsRead(this.userId);

  @override
  List<Object?> get props => [userId];
}
