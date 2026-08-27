import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Application-level configuration loaded from compile-time values and `.env`.
class AppConfig {
  AppConfig._();

  static const String appName = 'لقمة';
  static const String appVersion = '1.0.0';

  static String get supabaseUrl => _requiredEnv('SUPABASE_URL');

  static String get supabaseAnonKey => _requiredEnv('SUPABASE_ANON_KEY');

  static bool get isProduction => const bool.fromEnvironment('dart.vm.product');

  static bool get isDevelopment => !isProduction;

  static String get environment => isProduction ? 'production' : 'development';

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
