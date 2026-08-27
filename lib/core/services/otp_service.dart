import 'dart:math';

import '../services/supabase_service.dart';

class OtpService {
  OtpService({SupabaseService? supabase})
      : _supabase = supabase ?? SupabaseService();

  final SupabaseService _supabase;

  Future<void> saveOtp(String email, String code) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanCode = code.trim();
    if (cleanEmail.isEmpty || cleanCode.length != 6) {
      throw const FormatException('بيانات كود التحقق غير صالحة');
    }

    await _supabase.client.from('otp_codes').insert({
      'email': cleanEmail,
      'code': cleanCode,
      'is_used': false,
      'expires_at': DateTime.now()
          .toUtc()
          .add(const Duration(minutes: 5))
          .toIso8601String(),
    });
  }

  Future<bool> verifyOtp(String email, String code) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanCode = code.trim();
    if (cleanEmail.isEmpty || !RegExp(r'^\d{6}$').hasMatch(cleanCode)) {
      return false;
    }

    try {
      final response = await _supabase.client
          .from('otp_codes')
          .select('id, expires_at')
          .eq('email', cleanEmail)
          .eq('code', cleanCode)
          .eq('is_used', false)
          .maybeSingle();

      if (response == null) return false;
      final expiresAt = _parseDate(response['expires_at']);
      if (expiresAt == null ||
          !DateTime.now().toUtc().isBefore(expiresAt.toUtc())) {
        await _supabase.client
            .from('otp_codes')
            .delete()
            .eq('id', response['id']);
        return false;
      }

      await _supabase.client
          .from('otp_codes')
          .update({'is_used': true}).eq('id', response['id']);
      return true;
    } catch (_) {
      return false;
    }
  }

  String generateOtp() {
    final random = Random.secure();
    return List.generate(6, (_) => random.nextInt(10)).join();
  }

  static DateTime? _parseDate(dynamic value) {
    if (value is DateTime) return value.toUtc();
    if (value == null) return null;
    return DateTime.tryParse(value.toString())?.toUtc();
  }
}
