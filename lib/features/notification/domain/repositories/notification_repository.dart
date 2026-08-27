// lib/features/notification/domain/repositories/notification_repository.dart

import 'package:dartz/dartz.dart';
import '../entities/notification.dart';

abstract class NotificationRepository {
  Future<Either<String, List<AppNotification>>> getNotifications(String userId);
  Future<Either<String, bool>> markAsRead(String notificationId);
  Future<Either<String, bool>> markAllAsRead(String userId);
  Future<Either<String, int>> getUnreadCount(String userId);
  Stream<List<AppNotification>> watchNotifications(String userId);
}
