import 'package:flutter/foundation.dart';
import 'package:loqma/core/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final _client = SupabaseService().client;

  // ═══════════════════════════════════════════════════════════
  // 🛡️ التحقق من أن الرقم ليس مزود خدمة
  // ═══════════════════════════════════════════════════════════
  String _normalizePhone(String phone) {
    var value = phone.replaceAll(RegExp(r'[^\d]'), '');
    if (value.startsWith('0') && value.length == 11) {
      value = '20${value.substring(1)}';
    } else if (value.length == 10) {
      value = '20$value';
    }
    return value;
  }

  Future<Map<String, dynamic>?> _findProviderByPhone(String phone) async {
    final intl = _normalizePhone(phone);
    final variants = <String>{intl};

    if (intl.startsWith('20') && intl.length == 12) {
      variants.add('0${intl.substring(2)}');
      variants.add('+$intl');
    }

    final filters = <String>[];
    for (final value in variants) {
      filters.add('phone.eq.$value');
      filters.add('whatsapp.eq.$value');
    }

    final rows = await _client
        .from('service_providers')
        .select('id, verification_status, is_active, display_name')
        .or(filters.join(','))
        .limit(1);

    if (rows is List && rows.isNotEmpty && rows.first is Map) {
      return Map<String, dynamic>.from(rows.first as Map);
    }
    return null;
  }

  String _providerMessage(Map<String, dynamic> provider) {
    final status = provider['verification_status']?.toString().trim();
    final normalizedStatus =
        status == null || status.isEmpty ? 'غير محددة' : status;
    final isActive = provider['is_active'] as bool? ?? true;

    if (normalizedStatus == 'rejected') {
      return 'تم رفض حساب مزود الخدمة. تواصل مع الدعم لمعرفة السبب.';
    }
    if (normalizedStatus == 'suspended' || !isActive) {
      return 'تم إيقاف حساب مزود الخدمة. تواصل مع الدعم لإعادة تفعيله.';
    }
    return 'الرقم مسجل كمزود خدمة وحالته "$normalizedStatus". استخدم دخول مقدم الخدمة.';
  }

  // ═══════════════════════════════════════════════════════════
  // 📤 إرسال OTP على واتساب لمسار المستخدم العادي
  // ═══════════════════════════════════════════════════════════
  Future<Map<String, dynamic>> sendOtp({required String phone}) async {
    try {
      final provider = await _findProviderByPhone(phone);
      if (provider != null) {
        final message = _providerMessage(provider);
        debugPrint('🚫 [AuthService] provider blocked from ordinary OTP');
        return {'success': false, 'error': message};
      }

      final res = await _client.functions.invoke(
        'send-otp',
        body: {'phone': _normalizePhone(phone)},
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
  // ✅ التحقق + إنشاء الحساب لمسار المستخدم العادي
  // ═══════════════════════════════════════════════════════════
  Future<Map<String, dynamic>> verifyAndCreate({
    required String phone,
    required String code,
    required Map<String, dynamic> profile,
  }) async {
    try {
      final requestedRole =
          (profile['role'] ?? 'user').toString().trim().toLowerCase();

      if (requestedRole == 'user') {
        final provider = await _findProviderByPhone(phone);
        if (provider != null) {
          final message = _providerMessage(provider);
          debugPrint('🚫 [AuthService] provider blocked during verification');
          return {'success': false, 'error': message};
        }
      }

      final res = await _client.functions.invoke(
        'verify-and-create',
        body: {
          'phone': _normalizePhone(phone),
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

      final refreshToken = data['refresh_token']?.toString();
      if (refreshToken == null || refreshToken.isEmpty) {
        return {'success': false, 'error': 'جلسة الدخول غير صالحة'};
      }

      // ✅ نثبّت الجلسة بعد نجاح التحقق فقط
      await _client.auth.setSession(refreshToken);

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
