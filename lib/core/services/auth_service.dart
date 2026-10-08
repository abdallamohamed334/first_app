import 'package:flutter/foundation.dart';
import 'package:loqma/core/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _client = SupabaseService().client;

  /// إرسال OTP حسب نوع الدخول.
  /// loginMode يجب أن تكون user أو provider.
  Future<Map<String, dynamic>> sendOtp({
    required String phone,
    required String loginMode,
  }) async {
    if (loginMode != 'user' && loginMode != 'provider') {
      return {
        'success': false,
        'error': 'نوع الدخول غير صحيح',
        'reason': 'invalid_login_mode',
      };
    }

    try {
      final response = await _client.functions.invoke(
        'send-otp',
        body: {
          'phone': phone,
          'loginMode': loginMode,
        },
      );

      final data = response.data;

      if (data is Map && data['success'] == true) {
        return {
          'success': true,
          'phone': data['phone'],
        };
      }

      final error = data is Map ? data['error'] : null;
      final reason = data is Map ? data['reason'] : null;

      debugPrint(
        '🚫 OTP rejected: mode=$loginMode reason=$reason error=$error',
      );

      return {
        'success': false,
        'error': error is String && error.isNotEmpty
            ? error
            : 'لا يمكن إرسال كود التحقق لهذا الرقم',
        'reason': reason,
      };
    } on FunctionException catch (error) {
      final details = error.details;
      final data = details is Map ? details : null;

      return {
        'success': false,
        'error': data?['error'] ?? 'لا يمكن إرسال كود التحقق لهذا الرقم',
        'reason': data?['reason'],
      };
    } catch (error) {
      debugPrint('❌ sendOtp error: $error');
      return {
        'success': false,
        'error': 'تعذر الاتصال بالسيرفر',
      };
    }
  }

  /// التحقق من OTP وإنشاء/إرجاع الحساب.
  Future<Map<String, dynamic>> verifyAndCreate({
    required String phone,
    required String code,
    required Map<String, dynamic> profile,
  }) async {
    try {
      final response = await _client.functions.invoke(
        'verify-and-create',
        body: {
          'phone': phone,
          'code': code,
          'profile': profile,
        },
      );

      final data = response.data;

      if (data is! Map || data['success'] != true) {
        return {
          'success': false,
          'error': data is Map ? data['error'] ?? 'تعذر التحقق' : 'تعذر التحقق',
          'reason': data is Map ? data['reason'] : null,
        };
      }

      final refreshToken = data['refresh_token'];
      if (refreshToken is String && refreshToken.isNotEmpty) {
        await _client.auth.setSession(refreshToken);
      }

      debugPrint('✅ Session set for ${data['user']?['name']}');

      return {
        'success': true,
        'isNewUser': data['isNewUser'] ?? false,
        'user': data['user'],
      };
    } on FunctionException catch (error) {
      final details = error.details;
      final data = details is Map ? details : null;

      return {
        'success': false,
        'error': data?['error'] ?? 'تعذر التحقق',
        'reason': data?['reason'],
      };
    } catch (error) {
      debugPrint('❌ verifyAndCreate error: $error');
      return {
        'success': false,
        'error': 'تعذر الاتصال بالسيرفر',
      };
    }
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  User? get currentUser => _client.auth.currentUser;

  bool get isLoggedIn => currentUser != null;
}
