import 'package:loqma/features/notification/domain/repositories/notification_repository.dart';

import '../entities/notification.dart';

class WatchNotifications {
  final NotificationRepository repository;

  WatchNotifications(this.repository);

  Stream<List<AppNotification>> call(String userId) {
    return repository.watchNotifications(userId);
  }
}
