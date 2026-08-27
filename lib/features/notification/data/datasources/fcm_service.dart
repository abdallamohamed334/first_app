import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:loqma/core/services/supabase_service.dart';

class FcmService {
  final SupabaseClient client;
  static FirebaseMessaging? _messaging;

  FcmService(this.client);

  Future<void> initialize() async {
    try {
      print('📌 Initializing FCM Service...');

      _messaging = FirebaseMessaging.instance;

      // ✅ طلب الإذن
      NotificationSettings settings = await _messaging!.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      print('✅ Permission status: ${settings.authorizationStatus}');

      if (settings.authorizationStatus != AuthorizationStatus.authorized) {
        print('⚠️ Permission not granted');
        return;
      }

      // ✅ جلب الـ Token
      final token = await _messaging!.getToken();
      if (token != null) {
        print('✅ FCM Token: $token');
        await _saveToken(token);
      } else {
        print('⚠️ FCM Token is null');
      }

      // ✅ الاستماع للإشعارات
      _setupListeners();

      print('✅ FCM Service initialized successfully');
    } catch (e) {
      print('❌ FCM initialization error: $e');
    }
  }

  Future<void> _saveToken(String token) async {
    try {
      final user = client.auth.currentUser;
      if (user == null) {
        print('⚠️ No user logged in, cannot save token');
        return;
      }

      print('📌 Saving FCM token for user: ${user.id}');

      final supabaseService = SupabaseService();
      final adminClient = supabaseService.adminClient;

      await adminClient
          .from('users')
          .update({'fcm_token': token}).eq('id', user.id);

      print('✅ FCM token saved successfully');
    } catch (e) {
      print('❌ Save token error: $e');
    }
  }

  void _setupListeners() {
    // ✅ ✅ ✅ إشعار في المقدمة - نحفظه في قاعدة البيانات
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      print('📩 FCM Message received (foreground):');
      print('  Title: ${message.notification?.title}');
      print('  Body: ${message.notification?.body}');
      print('  Data: ${message.data}');

      // ✅ حفظ الإشعار في قاعدة البيانات
      await _saveNotificationToDatabase(message);

      // ✅ عرض SnackBar
      _showInAppNotification(message);
    });

    // ✅ ✅ ✅ المستخدم ضغط على الإشعار - نحفظه في قاعدة البيانات
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) async {
      print('📩 User tapped notification:');
      print('  Data: ${message.data}');

      // ✅ حفظ الإشعار في قاعدة البيانات
      await _saveNotificationToDatabase(message);

      // ✅ التنقل حسب البيانات
      _handleNotificationTap(message.data);
    });
  }

  // ✅ ✅ ✅ دالة حفظ الإشعار في قاعدة البيانات
  Future<void> _saveNotificationToDatabase(RemoteMessage message) async {
    try {
      final user = client.auth.currentUser;
      if (user == null) {
        print('⚠️ No user logged in, cannot save notification');
        return;
      }

      final title = message.notification?.title ?? 'إشعار جديد';
      final body = message.notification?.body ?? '';
      final type = message.data['type'] ?? 'system';
      final referenceId = message.data['reference_id'];
      final referenceType = message.data['reference_type'];

      print('📌 Saving notification to database...');
      print('  User: ${user.id}');
      print('  Title: $title');
      print('  Type: $type');

      // ✅ إضافة الإشعار في قاعدة البيانات
      await client.from('notifications').insert({
        'user_id': user.id,
        'title': title,
        'body': body,
        'type': type,
        'reference_id': referenceId,
        'reference_type': referenceType,
        'is_read': false,
      });

      print('✅ Notification saved to database');

      // ✅ تحديث الـ Bloc (إذا كان التطبيق مفتوح)
      try {
        final context = FcmService.navigatorKey.currentContext;
        if (context != null) {
          // لا يمكننا الوصول للـ Bloc مباشرة، لكن Realtime هيتعامل معها
          print('📌 Notification saved, Realtime will update the UI');
        }
      } catch (e) {
        print('❌ Error updating UI: $e');
      }
    } catch (e) {
      print('❌ Error saving notification to database: $e');
    }
  }

  void _showInAppNotification(RemoteMessage message) {
    final context = FcmService.navigatorKey.currentContext;
    if (context == null) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '🔔 ${message.notification?.title ?? 'إشعار جديد'}\n${message.notification?.body ?? ''}',
        ),
        backgroundColor: Colors.blue,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        action: SnackBarAction(
          label: 'عرض',
          textColor: Colors.white,
          onPressed: () {
            _handleNotificationTap(message.data);
          },
        ),
      ),
    );
  }

  void _handleNotificationTap(Map<String, dynamic> data) {
    final context = FcmService.navigatorKey.currentContext;
    if (context == null) {
      print('⚠️ No context available for navigation');
      return;
    }

    final type = data['type'] ?? data['reference_type'] ?? 'home';
    final referenceId = data['reference_id'] ?? data['id'];

    print('📌 Handling notification tap: type=$type, referenceId=$referenceId');

    // ✅ التنقل حسب نوع الإشعار
    switch (type) {
      case 'offer':
      case 'new_offer':
        if (referenceId != null) {
          print('📌 Navigate to offer details: $referenceId');
          // TODO: التنقل لصفحة تفاصيل العرض
          // Navigator.push(
          //   context,
          //   MaterialPageRoute(
          //     builder: (_) => OfferDetailsPage(offerId: referenceId),
          //   ),
          // );
        }
        break;
      default:
        print('📌 Navigate to HomePage');
        // Navigator.pushReplacement(
        //   context,
        //   MaterialPageRoute(builder: (_) => const HomePage()),
        // );
        break;
    }
  }

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();
}
