// lib/core/config/app_config.dart

import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Application-level configuration loaded from compile-time values and `.env`.
class AppConfig {
  AppConfig._();

  // ═══════════════════════════════════════════════════════════
  // 🏢 معلومات التطبيق
  // ═══════════════════════════════════════════════════════════
  static const String appName = 'جُود';
  static const String appVersion = '1.0.0';

  // ═══════════════════════════════════════════════════════════
  // 🔐 Supabase
  // ═══════════════════════════════════════════════════════════
  static String get supabaseUrl => _requiredEnv('SUPABASE_URL');
  static String get supabaseAnonKey => _requiredEnv('SUPABASE_ANON_KEY');

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
    final value = dotenv.env[key]?.trim();
    if (value == null || value.isEmpty) {
      throw StateError(
        'Missing required environment variable: $key. '
        'Load the .env file before reading AppConfig.',
      );
    }
    return value;
  }
}
