import 'package:loqma/features/notification/data/models/notification_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract class NotificationRemoteDataSource {
  Future<List<NotificationModel>> getNotifications(String userId);
  Future<void> markAsRead(String notificationId);
  Future<void> markAllAsRead(String userId);
  Stream<List<NotificationModel>> watchNotifications(String userId);
}

class NotificationRemoteDataSourceImpl implements NotificationRemoteDataSource {
  final SupabaseClient client;

  NotificationRemoteDataSourceImpl(this.client);

  static const String _table = 'notifications';

  @override
  Future<List<NotificationModel>> getNotifications(String userId) async {
    final response = await client
        .from(_table)
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    return (response as List)
        .map((json) => NotificationModel.fromJson(json))
        .toList();
  }

  @override
  Future<void> markAsRead(String notificationId) async {
    await client
        .from(_table)
        .update({'is_read': true}).eq('id', notificationId);
  }

  @override
  Future<void> markAllAsRead(String userId) async {
    await client
        .from(_table)
        .update({'is_read': true})
        .eq('user_id', userId)
        .eq('is_read', false);
  }

  @override
  Stream<List<NotificationModel>> watchNotifications(String userId) {
    return client
        .from(_table)
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .map((rows) =>
            rows.map((json) => NotificationModel.fromJson(json)).toList());
  }
}
