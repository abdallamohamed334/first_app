import 'package:supabase_flutter/supabase_flutter.dart';

/// Resolves the application role from the authenticated user's database row.
///
/// `users.user_type` is the only source of truth. Rows in businesses,
/// restaurants, charities, and organizations are relationship data only; they
/// must never promote a normal user into an institution session.
class AuthIdentityResolver {
  static const Set<String> _businessTypes = {
    'restaurant',
    'business',
    'hotel',
    'supermarket',
    'bakery',
    'cafe',
  };

  /// Returns `user`, `restaurant`, `charity`, or `unknown`.
  static Future<String> resolve(
    SupabaseClient client,
    String authUserId,
  ) async {
    final cleanId = authUserId.trim();
    if (cleanId.isEmpty) return 'unknown';

    final row = await client
        .from('users')
        .select('user_type')
        .eq('id', cleanId)
        .maybeSingle();

    if (row == null) return 'unknown';
    return normalizeRole(row['user_type']);
  }

  static String normalizeRole(dynamic value) {
    final normalized = value?.toString().trim().toLowerCase();
    if (normalized == 'user') return 'user';
    if (normalized == 'charity') return 'charity';
    if (_businessTypes.contains(normalized)) return 'restaurant';
    return 'unknown';
  }

  static bool isUser(String? role) => normalizeRole(role) == 'user';
  static bool isRestaurant(String? role) => normalizeRole(role) == 'restaurant';
  static bool isCharity(String? role) => normalizeRole(role) == 'charity';
}
