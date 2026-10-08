import 'package:get_it/get_it.dart';
import 'package:loqma/core/services/supabase_service.dart';
import 'package:loqma/features/notification/data/datasources/notification_remote_datasource.dart';
import 'package:loqma/features/notification/data/repositories/notification_repository_impl.dart';
import 'package:loqma/features/notification/domain/repositories/notification_repository.dart';
import 'package:loqma/features/notification/presentation/bloc/notification_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'domain/usecases/get_notifications.dart';
import 'domain/usecases/mark_as_read.dart';
import 'domain/usecases/mark_all_as_read.dart';
import 'domain/usecases/watch_notifications.dart';

final sl = GetIt.instance;

void initNotificationInjection() {
  // ✅ 1️⃣ تسجيل SupabaseClient
  sl.registerLazySingleton<SupabaseClient>(() => Supabase.instance.client);

  // ✅ 2️⃣ تسجيل SupabaseService
  sl.registerLazySingleton<SupabaseService>(() => SupabaseService());

  // ✅ 3️⃣ تسجيل NotificationRemoteDataSource
  sl.registerLazySingleton<NotificationRemoteDataSource>(
    () => NotificationRemoteDataSourceImpl(sl<SupabaseClient>()),
  );

  // ✅ 4️⃣ تسجيل NotificationRepository
  sl.registerLazySingleton<NotificationRepository>(
    () => NotificationRepositoryImpl(
      remoteDataSource: sl<NotificationRemoteDataSource>(),
      supabaseService: sl<SupabaseService>(),
    ),
  );

  // ✅ 5️⃣ تسجيل UseCases
  sl.registerLazySingleton(
      () => GetNotifications(sl<NotificationRepository>()));
  sl.registerLazySingleton(() => MarkAsRead(sl<NotificationRepository>()));
  sl.registerLazySingleton(() => MarkAllAsRead(sl<NotificationRepository>()));
  sl.registerLazySingleton(
      () => WatchNotifications(sl<NotificationRepository>()));

  // ✅ 6️⃣ تسجيل NotificationBloc
  sl.registerFactory(
    () => NotificationBloc(
      getNotifications: sl<GetNotifications>(),
      markAsRead: sl<MarkAsRead>(),
      markAllAsRead: sl<MarkAllAsRead>(),
      watchNotifications: sl<WatchNotifications>(),
    ),
  );
}
