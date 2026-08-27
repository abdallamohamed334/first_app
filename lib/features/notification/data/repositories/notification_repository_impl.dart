// ============================================================
// 6️⃣ notification_repository_impl.dart
// ============================================================
import 'package:dartz/dartz.dart';
import 'package:loqma/core/services/supabase_service.dart';
import 'package:loqma/features/notification/data/datasources/notification_remote_datasource.dart';
import 'package:loqma/features/notification/domain/entities/notification.dart';
import 'package:loqma/features/notification/domain/repositories/notification_repository.dart';

class NotificationRepositoryImpl implements NotificationRepository {
  final NotificationRemoteDataSource remoteDataSource;
  final SupabaseService supabaseService;

  NotificationRepositoryImpl({
    required this.remoteDataSource,
    required this.supabaseService,
  });

  @override
  Future<Either<String, List<AppNotification>>> getNotifications(
      String userId) async {
    try {
      print('📌 Repository getNotifications - userId: $userId');

      final response = await supabaseService.client
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      print('📌 Repository response: $response');

      final notifications = (response as List?)?.map((json) {
            final typeString = json['type'] as String? ?? 'system';
            final notificationType = NotificationType.fromString(typeString);

            return AppNotification(
              id: json['id'] as String,
              userId: json['user_id'] as String,
              title: json['title'] as String,
              body: json['body'] as String,
              type: notificationType,
              referenceId: json['reference_id'] as String?,
              referenceType: json['reference_type'] as String?,
              isRead: json['is_read'] as bool? ?? false,
              createdAt: DateTime.parse(json['created_at'] as String),
            );
          }).toList() ??
          [];

      print('✅ Repository success - ${notifications.length} notifications');
      return Right(notifications);
    } catch (e) {
      print('❌ Repository error: $e');
      return Left('Failed to get notifications: $e');
    }
  }

  @override
  Future<Either<String, bool>> markAsRead(String notificationId) async {
    try {
      await supabaseService.client
          .from('notifications')
          .update({'is_read': true}).eq('id', notificationId);

      return const Right(true);
    } catch (e) {
      return Left('Failed to mark as read: $e');
    }
  }

  @override
  Future<Either<String, bool>> markAllAsRead(String userId) async {
    try {
      await supabaseService.client
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', userId)
          .eq('is_read', false);

      return const Right(true);
    } catch (e) {
      return Left('Failed to mark all as read: $e');
    }
  }

  @override
  Future<Either<String, int>> getUnreadCount(String userId) async {
    try {
      final response = await supabaseService.client
          .from('notifications')
          .select('id')
          .eq('user_id', userId)
          .eq('is_read', false);

      return Right(response.length ?? 0);
    } catch (e) {
      return Left('Failed to get unread count: $e');
    }
  }

  @override
  Stream<List<AppNotification>> watchNotifications(String userId) {
    try {
      return supabaseService.client
          .from('notifications')
          .stream(primaryKey: ['id'])
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .map((event) {
            return (event as List?)?.map((json) {
                  final typeString = json['type'] as String? ?? 'system';
                  final notificationType =
                      NotificationType.fromString(typeString);

                  return AppNotification(
                    id: json['id'] as String,
                    userId: json['user_id'] as String,
                    title: json['title'] as String,
                    body: json['body'] as String,
                    type: notificationType,
                    referenceId: json['reference_id'] as String?,
                    referenceType: json['reference_type'] as String?,
                    isRead: json['is_read'] as bool? ?? false,
                    createdAt: DateTime.parse(json['created_at'] as String),
                  );
                }).toList() ??
                [];
          });
    } catch (e) {
      return Stream.value([]);
    }
  }
}
