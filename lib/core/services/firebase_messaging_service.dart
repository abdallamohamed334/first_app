import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:loqma/core/services/supabase_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('[FCM] background notification received');
}

class FirebaseMessagingService {
  FirebaseMessagingService._();

  static final FirebaseMessagingService instance = FirebaseMessagingService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  StreamSubscription<String>? _tokenSubscription;
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;
  StreamSubscription<dynamic>? _authSubscription;
  Future<void> Function(Map<String, dynamic> data)? _onNotificationTap;
  bool _initialized = false;

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'loqma_high_importance',
    'إشعارات لقمة',
    description: 'إشعارات التبرعات والحجوزات وتحديثات الاستلام',
    importance: Importance.high,
  );

  Future<void> initialize({
    Future<void> Function(Map<String, dynamic> data)? onNotificationTap,
  }) async {
    _onNotificationTap = onNotificationTap ?? _onNotificationTap;
    if (_initialized) {
      await saveTokenForCurrentUser();
      return;
    }

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    await _requestPermission();
    await _initializeLocalNotifications();
    await saveTokenForCurrentUser();

    _tokenSubscription = _messaging.onTokenRefresh.listen((token) {
      unawaited(_saveToken(token));
    });
    _foregroundSubscription = FirebaseMessaging.onMessage.listen((message) {
      unawaited(_showForegroundNotification(message));
    });
    _openedSubscription =
        FirebaseMessaging.onMessageOpenedApp.listen((message) {
      unawaited(_handleNotificationTap(message.data));
    });

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      await _handleNotificationTap(initialMessage.data);
    }

    _authSubscription =
        SupabaseService().client.auth.onAuthStateChange.listen((state) {
      if (state.session != null) {
        unawaited(saveTokenForCurrentUser());
      }
    });
    _initialized = true;
  }

  void setNotificationTapHandler(
    Future<void> Function(Map<String, dynamic> data) handler,
  ) {
    _onNotificationTap = handler;
  }

  Future<void> _handleNotificationTap(Map<String, dynamic> data) async {
    final handler = _onNotificationTap;
    if (handler == null || data.isEmpty) return;
    try {
      await handler(Map<String, dynamic>.from(data));
    } catch (error) {
      debugPrint('[FCM] notification navigation failed: ${error.runtimeType}');
    }
  }

  Future<void> _requestPermission() async {
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  Future<void> _initializeLocalNotifications() async {
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    await _localNotifications.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload == null || payload.isEmpty) return;
        unawaited(_handleNotificationTap({'reference_id': payload}));
      },
    );

    final android = _localNotifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(_channel);
    await android?.requestNotificationsPermission();
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    final title = notification?.title ?? message.data['title']?.toString();
    final body = notification?.body ?? message.data['body']?.toString();
    if (title == null || title.isEmpty || body == null || body.isEmpty) return;

    await _localNotifications.show(
      message.hashCode,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'loqma_high_importance',
          'إشعارات لقمة',
          channelDescription: 'إشعارات التبرعات والحجوزات وتحديثات الاستلام',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: message.data['reference_id']?.toString(),
    );
  }

  Future<void> saveTokenForCurrentUser() async {
    try {
      if (SupabaseService().client.auth.currentUser == null) return;
      final token = await _messaging.getToken();
      if (token == null || token.isEmpty) return;
      await _saveToken(token);
    } catch (error) {
      debugPrint('[FCM] token unavailable: ${error.runtimeType}');
    }
  }

  Future<void> _saveToken(String token) async {
    final client = SupabaseService().client;
    final userId = client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty || token.isEmpty) return;

    try {
      final profile = await client
          .from('users')
          .select('user_type, notifications_enabled')
          .eq('id', userId)
          .maybeSingle();
      final type = profile?['user_type']?.toString().trim().toLowerCase();
      final enabled = profile?['notifications_enabled'] != false;
      if (!enabled || !{'user', 'restaurant', 'charity'}.contains(type)) return;
      await client.from('users').update({'fcm_token': token}).eq('id', userId);
    } catch (error) {
      debugPrint('[FCM] token save failed: ${error.runtimeType}');
    }
  }

  Future<void> removeTokenForCurrentUser() async {
    final client = SupabaseService().client;
    final userId = client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) return;
    try {
      await client.from('users').update({'fcm_token': null}).eq('id', userId);
    } catch (error) {
      debugPrint('[FCM] token removal failed: ${error.runtimeType}');
    }
  }

  Future<void> dispose() async {
    await _tokenSubscription?.cancel();
    await _foregroundSubscription?.cancel();
    await _openedSubscription?.cancel();
    await _authSubscription?.cancel();
    _tokenSubscription = null;
    _foregroundSubscription = null;
    _openedSubscription = null;
    _authSubscription = null;
    _onNotificationTap = null;
    _initialized = false;
  }
}
