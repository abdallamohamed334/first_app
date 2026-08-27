import 'package:supabase_flutter/supabase_flutter.dart';

/// Central Supabase access and table-name constants.
class SupabaseConfig {
  SupabaseConfig._();

  static SupabaseClient? _client;

  /// Returns the explicitly injected client or the client created by
  /// `Supabase.initialize`.
  static SupabaseClient get client {
    final injectedClient = _client;
    if (injectedClient != null) {
      return injectedClient;
    }

    try {
      return Supabase.instance.client;
    } on Object catch (error) {
      throw StateError(
        'Supabase is not initialized. Call Supabase.initialize() before '
        'reading SupabaseConfig.client. Original error: $error',
      );
    }
  }

  /// Optional compatibility hook for tests or dependency injection.
  static void setClient(SupabaseClient client) {
    _client = client;
  }

  static const String tableUsers = 'users';
  static const String tableOtpCodes = 'otp_codes';
  static const String tableDonations = 'donations';
  static const String tablePickups = 'pickups';
  static const String tableNotifications = 'notifications';
}
