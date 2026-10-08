import 'package:dartz/dartz.dart';
import 'package:loqma/features/notification/domain/repositories/notification_repository.dart';

import '../entities/notification.dart';

class GetNotifications {
  final NotificationRepository repository;

  GetNotifications(this.repository);

  Future<Either<String, List<AppNotification>>> call(String userId) {
    return repository.getNotifications(userId);
  }
}
