import 'dart:async';
import 'dart:convert';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Handles Firebase Cloud Messaging without coupling notifications to a page
/// or to the Supabase repository layer.
///
/// The service only receives and routes notification data. The secure delivery
/// of notifications must happen on a backend, never from this Flutter client.
class FcmNotificationService {
  FcmNotificationService({
    FirebaseMessaging? messaging,
    FlutterLocalNotificationsPlugin? localNotifications,
    FirebaseAnalytics? analytics,
  })  : _messaging = messaging ?? FirebaseMessaging.instance,
        _localNotifications =
            localNotifications ?? FlutterLocalNotificationsPlugin(),
        _analytics = analytics ?? FirebaseAnalytics.instance;

  final FirebaseMessaging _messaging;
  final FlutterLocalNotificationsPlugin _localNotifications;
  final FirebaseAnalytics _analytics;

  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<RemoteMessage>? _openedAppSubscription;
  StreamSubscription<String>? _tokenRefreshSubscription;

  FutureOr<void> Function(Map<String, dynamic> data)? _onNotificationTap;
  bool _initialized = false;

  static const AndroidNotificationChannel _defaultChannel =
      AndroidNotificationChannel(
    'loqma_general_notifications',
    'إشعارات لقمة',
    description: 'إشعارات الطلبات والتبرعات والاستلام في تطبيق لقمة',
    importance: Importance.high,
  );

  /// Must be called after Firebase.initializeApp().
  ///
  /// [onTokenChanged] should persist the token in the Supabase
  /// `user_devices` table for the currently authenticated user.
  /// [onNotificationTap] receives only notification data and can navigate
  /// through the app router from a page-level coordinator.
  Future<void> initialize({
    required FutureOr<void> Function(String token) onTokenChanged,
    FutureOr<void> Function(Map<String, dynamic> data)? onNotificationTap,
    String? webVapidKey,
  }) async {
    if (_initialized) return;

    _onNotificationTap = onNotificationTap;

    await _requestPermission();
    await _configureLocalNotifications();

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    _foregroundSubscription = FirebaseMessaging.onMessage.listen(
      (message) => _handleForegroundMessage(message),
    );

    _openedAppSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
      (message) => _handleNotificationTap(message),
    );

    _tokenRefreshSubscription = _messaging.onTokenRefresh.listen(
      (token) => _safeTokenCallback(token, onTokenChanged),
    );

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      await _handleNotificationTap(initialMessage);
    }

    final token = await _readToken(webVapidKey: webVapidKey);
    if (token != null && token.isNotEmpty) {
      await _safeTokenCallback(token, onTokenChanged);
    }

    _initialized = true;
  }

  Future<NotificationSettings> _requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    debugPrint(
      '[FCM] notification authorization=${settings.authorizationStatus.name}',
    );

    if (!kIsWeb) {
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    }

    return settings;
  }

  Future<void> _configureLocalNotifications() async {
    if (kIsWeb) return;

    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
      macOS: DarwinInitializationSettings(),
    );

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload == null || payload.isEmpty) return;

        try {
          final data = Map<String, dynamic>.from(
            jsonDecode(payload) as Map,
          );
          unawaited(_invokeTapCallback(data));
        } catch (error, stack) {
          debugPrint('[FCM] invalid local notification payload: $error');
          debugPrintStack(stackTrace: stack);
        }
      },
    );

    final androidPlugin =
        _localNotifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(_defaultChannel);

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final iosPlugin =
          _localNotifications.resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>();
      await iosPlugin?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
    }
  }

  Future<String?> _readToken({String? webVapidKey}) async {
    try {
      if (kIsWeb) {
        final vapidKey = webVapidKey?.trim();
        if (vapidKey == null || vapidKey.isEmpty) {
          debugPrint(
            '[FCM] web token skipped: provide the Firebase Web VAPID public key',
          );
          return null;
        }
        return await _messaging.getToken(vapidKey: vapidKey);
      }

      return await _messaging.getToken();
    } catch (error, stack) {
      debugPrint('[FCM] token read failed: $error');
      debugPrintStack(stackTrace: stack);
      return null;
    }
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    debugPrint('[FCM] foreground message id=${message.messageId}');

    await _logNotificationOpened(message, foreground: true);

    final notification = message.notification;
    if (notification == null || kIsWeb) return;

    final title = notification.title?.trim();
    final body = notification.body?.trim();
    if ((title == null || title.isEmpty) && (body == null || body.isEmpty)) {
      return;
    }

    final payload = jsonEncode(message.data);
    await _localNotifications.show(
      message.hashCode,
      title ?? 'إشعار جديد من لقمة',
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'loqma_general_notifications',
          'إشعارات لقمة',
          channelDescription:
              'إشعارات الطلبات والتبرعات والاستلام في تطبيق لقمة',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(),
        macOS: DarwinNotificationDetails(),
      ),
      payload: payload,
    );
  }

  Future<void> _handleNotificationTap(RemoteMessage message) async {
    await _logNotificationOpened(message, foreground: false);
    await _invokeTapCallback(message.data);
  }

  Future<void> _logNotificationOpened(
    RemoteMessage message, {
    required bool foreground,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'notification_received',
        parameters: <String, Object>{
          'delivery_state': foreground ? 'foreground' : 'background_or_tap',
          if (message.data['type'] != null)
            'notification_type': message.data['type'].toString(),
        },
      );
    } catch (error) {
      debugPrint('[FCM] analytics event failed: $error');
    }
  }

  Future<void> _invokeTapCallback(Map<String, dynamic> data) async {
    final callback = _onNotificationTap;
    if (callback == null) return;

    try {
      await callback(Map<String, dynamic>.from(data));
    } catch (error, stack) {
      debugPrint('[FCM] notification tap callback failed: $error');
      debugPrintStack(stackTrace: stack);
    }
  }

  Future<void> _safeTokenCallback(
    String token,
    FutureOr<void> Function(String token) callback,
  ) async {
    try {
      await callback(token);
      debugPrint('[FCM] device token synchronized');
    } catch (error, stack) {
      debugPrint('[FCM] device token synchronization failed: $error');
      debugPrintStack(stackTrace: stack);
    }
  }

  /// Reads the current token without initializing the notification listeners.
  Future<String?> currentToken() async {
    try {
      return await _messaging.getToken();
    } catch (error, stack) {
      debugPrint('[FCM] current token read failed: $error');
      debugPrintStack(stackTrace: stack);
      return null;
    }
  }

  /// Marks the current Firebase token for removal from the backend and clears
  /// the local Firebase token. Call this before Supabase local sign-out.
  Future<void> unregister() async {
    try {
      await _messaging.deleteToken();
    } catch (error, stack) {
      debugPrint('[FCM] token deletion failed: $error');
      debugPrintStack(stackTrace: stack);
    }
  }

  Future<void> dispose() async {
    await _foregroundSubscription?.cancel();
    await _openedAppSubscription?.cancel();
    await _tokenRefreshSubscription?.cancel();
    _foregroundSubscription = null;
    _openedAppSubscription = null;
    _tokenRefreshSubscription = null;
    _initialized = false;
  }
}

/// Must stay top-level so Firebase can invoke it in a background isolate.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
    debugPrint('[FCM] background message id=${message.messageId}');
  } catch (error, stack) {
    debugPrint('[FCM] background handler initialization failed: $error');
    debugPrintStack(stackTrace: stack);
  }
}
