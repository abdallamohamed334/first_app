import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Session helper. Supabase Auth proves the session; the public users row
/// determines the application role. SharedPreferences is cache only and never
/// decides whether a session is a user, restaurant, or charity.
class AuthService {
  static const String _keyToken = 'auth_token';
  static const String _keyUserId = 'user_id';
  static const String _keyUserEmail = 'user_email';
  static const String _keyUserType = 'user_type';
  static const String _keyBusinessId = 'business_id';
  static const String _keyBusinessType = 'business_type';

  SupabaseClient get _supabase => Supabase.instance.client;

  Future<void> saveUserSession({
    required String userId,
    required String email,
    required String userType,
    String? businessId,
    String? businessType,
  }) async {
    final normalizedType = _normalizeRole(userType);
    final cleanId = userId.trim();
    if (normalizedType == null || cleanId.isEmpty) {
      await clearSession();
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setString(_keyToken, 'supabase_session'),
      prefs.setString(_keyUserId, cleanId),
      prefs.setString(_keyUserEmail, email.trim().toLowerCase()),
      prefs.setString(_keyUserType, normalizedType),
    ]);

    if (normalizedType == 'restaurant' &&
        businessId != null &&
        businessId.trim().isNotEmpty) {
      await prefs.setString(_keyBusinessId, businessId.trim());
      await prefs.setString(_keyBusinessType,
          (businessType ?? 'restaurant').trim().toLowerCase());
    } else {
      await prefs.remove(_keyBusinessId);
      await prefs.remove(_keyBusinessType);
    }
  }

  /// Restores only a session whose current users row exists and has a known
  /// role. Cached user_type/business_id values are deliberately ignored.
  Future<Map<String, String>?> getUserSession() async {
    final authUser = _supabase.auth.currentUser;
    if (authUser == null) return null;

    final row = await _supabase
        .from('users')
        .select('id, email, user_type')
        .eq('id', authUser.id)
        .maybeSingle();
    if (row == null) return null;

    final role = _normalizeRole(row['user_type']?.toString());
    if (role == null) return null;

    final prefs = await SharedPreferences.getInstance();
    final email = (row['email']?.toString().trim().isNotEmpty == true
            ? row['email']?.toString()
            : authUser.email) ??
        '';

    // Clear institution cache immediately for normal users and charities.
    if (role != 'restaurant') {
      await Future.wait([
        prefs.remove(_keyBusinessId),
        prefs.remove(_keyBusinessType),
      ]);
    }

    await Future.wait([
      prefs.setString(_keyUserId, authUser.id),
      prefs.setString(_keyUserEmail, email.trim().toLowerCase()),
      prefs.setString(_keyUserType, role),
    ]);

    return {
      'userId': authUser.id,
      'email': email,
      'userType': role,
      'businessId':
          role == 'restaurant' ? (prefs.getString(_keyBusinessId) ?? '') : '',
      'businessType':
          role == 'restaurant' ? (prefs.getString(_keyBusinessType) ?? '') : '',
    };
  }

  Future<String> getUserType() async {
    final session = await getUserSession();
    return session?['userType'] ?? 'unknown';
  }

  Future<String?> getBusinessId() async {
    final session = await getUserSession();
    if (session?['userType'] != 'restaurant') return null;
    final value = session?['businessId'];
    return value == null || value.isEmpty ? null : value;
  }

  Future<String?> getBusinessType() async {
    final session = await getUserSession();
    if (session?['userType'] != 'restaurant') return null;
    final value = session?['businessType'];
    return value == null || value.isEmpty ? null : value;
  }

  Future<bool> isUserLoggedIn() async => _supabase.auth.currentSession != null;

  Future<bool> isBusinessUser() async => (await getUserType()) == 'restaurant';

  Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();
    } finally {
      await clearSession();
    }
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.remove(_keyToken),
      prefs.remove(_keyUserId),
      prefs.remove(_keyUserEmail),
      prefs.remove(_keyUserType),
      prefs.remove(_keyBusinessId),
      prefs.remove(_keyBusinessType),
    ]);
  }

  /// Role changes must be performed by an authorized server/admin operation.
  /// This method intentionally does not mutate the local role cache.
  Future<void> updateUserType(String userType) async {
    // Intentionally ignored. The next session restore reads users.user_type.
  }

  Future<void> updateBusinessId(String businessId) async {
    final value = businessId.trim();
    if (value.isEmpty || (await getUserType()) != 'restaurant') return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyBusinessId, value);
  }

  static String? _normalizeRole(String? value) {
    switch (value?.trim().toLowerCase()) {
      case 'user':
        return 'user';
      case 'restaurant':
      case 'business':
      case 'hotel':
      case 'supermarket':
      case 'bakery':
      case 'cafe':
        return 'restaurant';
      case 'charity':
        return 'charity';
      default:
        return null;
    }
  }
}
