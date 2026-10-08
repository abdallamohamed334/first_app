// lib/core/services/whatsapp_service.dart

import 'package:flutter/foundation.dart';
import 'package:loqma/core/services/supabase_service.dart';

class WhatsAppService {
  final _client = SupabaseService().client;

  /// 📤 إرسال رسالة واتساب
  Future<bool> sendMessage({
    required String phone,
    required String message,
  }) async {
    try {
      final cleanPhone = _cleanPhone(phone);
      if (cleanPhone.isEmpty) {
        debugPrint('❌ رقم غير صحيح');
        return false;
      }

      debugPrint('📤 Sending WhatsApp to $cleanPhone');

      final response = await _client.functions.invoke(
        'send-whatsapp',
        body: {
          'to': cleanPhone,
          'message': message,
        },
      );

      final data = response.data;
      if (data is Map && data['success'] == true) {
        debugPrint('✅ WhatsApp sent');
        return true;
      } else {
        debugPrint('❌ WhatsApp failed: $data');
        return false;
      }
    } catch (e) {
      debugPrint('❌ sendMessage error: $e');
      return false;
    }
  }

  /// 📷 إرسال صورة
  Future<bool> sendImage({
    required String phone,
    required String imageUrl,
    String? caption,
  }) async {
    try {
      final cleanPhone = _cleanPhone(phone);

      final response = await _client.functions.invoke(
        'send-whatsapp',
        body: {
          'to': cleanPhone,
          'imageUrl': imageUrl,
          'caption': caption,
        },
      );

      return response.data?['success'] == true;
    } catch (e) {
      debugPrint('❌ sendImage error: $e');
      return false;
    }
  }

  /// 🧹 تنظيف الرقم
  String _cleanPhone(String phone) {
    var cleaned = phone.replaceAll(RegExp(r'[^\d]'), '');

    if (cleaned.startsWith('0')) {
      cleaned = '20${cleaned.substring(1)}';
    } else if (cleaned.length == 10) {
      cleaned = '20$cleaned';
    }

    return cleaned;
  }
}
