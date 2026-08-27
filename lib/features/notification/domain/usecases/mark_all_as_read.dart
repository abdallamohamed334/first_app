import 'package:loqma/features/notification/domain/repositories/notification_repository.dart';

class MarkAllAsRead {
  final NotificationRepository repository;

  MarkAllAsRead(this.repository);

  Future<void> call(String userId) {
    return repository.markAllAsRead(userId);
  }
}
