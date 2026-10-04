// lib/core/config/app_config.dart

import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Application-level configuration loaded from compile-time values and `.env`.
class AppConfig {
  AppConfig._();

  static String? _configuredSupabaseUrl;
  static String? _configuredSupabaseAnonKey;

  /// Supplies the values already resolved during app startup. This keeps
  /// later services (for example storage image URL builders) independent from
  /// whether the optional `.env` asset was bundled.
  static void configure({
    required String supabaseUrl,
    required String supabaseAnonKey,
  }) {
    _configuredSupabaseUrl =
        supabaseUrl.trim().isEmpty ? null : supabaseUrl.trim();
    _configuredSupabaseAnonKey =
        supabaseAnonKey.trim().isEmpty ? null : supabaseAnonKey.trim();
  }

  // ═══════════════════════════════════════════════════════════
  // 🏢 معلومات التطبيق
  // ═══════════════════════════════════════════════════════════
  static const String appName = 'وِصلة';
  static const String appVersion = '1.0.0';

  // ═══════════════════════════════════════════════════════════
  // 🔐 Supabase
  // ═══════════════════════════════════════════════════════════
  static String get supabaseUrl =>
      _configuredSupabaseUrl ?? _requiredEnv('SUPABASE_URL');
  static String get supabaseAnonKey =>
      _configuredSupabaseAnonKey ?? _requiredEnv('SUPABASE_ANON_KEY');

  static String storagePublicUrl(String bucket, String path) =>
      '${supabaseUrl}/storage/v1/object/public/$bucket/$path';

  // ═══════════════════════════════════════════════════════════
  // 🌍 البيئة
  // ═══════════════════════════════════════════════════════════
  static bool get isProduction => const bool.fromEnvironment('dart.vm.product');
  static bool get isDevelopment => !isProduction;
  static String get environment => isProduction ? 'production' : 'development';

  // ═══════════════════════════════════════════════════════════
  // 📍 المدينة الافتراضية (التطبيق مقفول على طنطا حاليًا)
  // ═══════════════════════════════════════════════════════════
  static const String defaultCity = 'طنطا';
  static const String defaultCityEn = 'Tanta';

  /// إحداثيات طنطا
  static const double defaultLat = 30.7865;
  static const double defaultLng = 31.0004;

  /// نطاق البحث الافتراضي بالكيلومتر
  static const int defaultRadiusKm = 30;

  /// هل التطبيق محصور على مدينة واحدة دلوقتي؟
  static const bool isCityLocked = true;

  // ═══════════════════════════════════════════════════════════
  // 📞 معلومات التواصل
  // ═══════════════════════════════════════════════════════════
  static const String supportEmail = 'support@good-app.com';
  static const String supportPhone = '0403333333';

  // ═══════════════════════════════════════════════════════════
  // ⚙️ إعدادات عامة
  // ═══════════════════════════════════════════════════════════
  static const int pageSize = 20;
  static const Duration cacheDuration = Duration(minutes: 15);

  // ═══════════════════════════════════════════════════════════
  // 🔐 Environment Variables
  // ═══════════════════════════════════════════════════════════
  static String _requiredEnv(String key) {
    final value = (dotenv.env[key] ?? String.fromEnvironment(key)).trim();
    if (value.isEmpty) {
      throw StateError(
        'Missing required environment variable: $key. '
        'Load the .env file before reading AppConfig.',
      );
    }
    return value;
  }
}
