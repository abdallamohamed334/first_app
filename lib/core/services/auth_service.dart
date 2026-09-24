// lib/features/auth/data/auth_service.dart

import 'package:flutter/foundation.dart';
import 'package:loqma/core/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final _client = SupabaseService().client;

  // ═══════════════════════════════════════════════════════════
  // 📤 إرسال OTP على واتساب
  // ═══════════════════════════════════════════════════════════
  Future<Map<String, dynamic>> sendOtp({required String phone}) async {
    try {
      final res = await _client.functions.invoke(
        'send-otp',
        body: {'phone': phone},
      );

      final data = res.data;
      if (data is Map && data['success'] == true) {
        return {
          'success': true,
          'phone': data['phone'],
        };
      }
      return {
        'success': false,
        'error': data is Map ? data['error'] : 'تعذر إرسال الكود',
      };
    } catch (e) {
      debugPrint('❌ sendOtp error: $e');
      return {'success': false, 'error': 'تعذر الاتصال بالسيرفر'};
    }
  }

  // ═══════════════════════════════════════════════════════════
  // ✅ التحقق + إنشاء الحساب
  // ═══════════════════════════════════════════════════════════
  Future<Map<String, dynamic>> verifyAndCreate({
    required String phone,
    required String code,
    required Map<String, dynamic> profile,
  }) async {
    try {
      final res = await _client.functions.invoke(
        'verify-and-create',
        body: {
          'phone': phone,
          'code': code,
          'profile': profile,
        },
      );

      final data = res.data;
      if (data is! Map || data['success'] != true) {
        return {
          'success': false,
          'error': data is Map ? data['error'] : 'تعذر التحقق',
        };
      }

      // ✅ نثبّت الجلسة
      await _client.auth.setSession(data['refresh_token']);

      debugPrint('✅ Session set for ${data['user']['name']}');
      return {
        'success': true,
        'isNewUser': data['isNewUser'] ?? false,
        'user': data['user'],
      };
    } catch (e) {
      debugPrint('❌ verifyAndCreate error: $e');
      return {'success': false, 'error': 'تعذر الاتصال بالسيرفر'};
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🚪 تسجيل خروج
  // ═══════════════════════════════════════════════════════════
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  // ═══════════════════════════════════════════════════════════
  // 👤 المستخدم الحالي
  // ═══════════════════════════════════════════════════════════
  User? get currentUser => _client.auth.currentUser;
  bool get isLoggedIn => currentUser != null;
}
