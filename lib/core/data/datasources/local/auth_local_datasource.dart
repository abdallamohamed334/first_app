import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Small compatibility cache for legacy local-session consumers.
///
/// Supabase Auth remains the source of truth for authentication. This class
/// must not be used to decide whether a user is a restaurant or charity unless
/// the role is also confirmed from the authenticated database record.
class AuthLocalDataSource {
  AuthLocalDataSource();

  static const String _tokenKey = 'auth_token';
  static const String _userIdKey = 'user_id';
  static const String _userTypeKey = 'user_type';

  static const Set<String> supportedUserTypes = <String>{
    'user',
    'restaurant',
    'business',
    'charity',
  };

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  String? normalizeUserType(String? value) {
    final normalized = value?.trim().toLowerCase();
    if (normalized == null || !supportedUserTypes.contains(normalized)) {
      return null;
    }
    return normalized;
  }

  Future<String?> getToken() async {
    try {
      return (await _prefs).getString(_tokenKey);
    } catch (error) {
      _log('Error getting token', error);
      return null;
    }
  }

  Future<void> saveToken(String token) async {
    final normalized = token.trim();
    if (normalized.isEmpty) {
      await _remove(_tokenKey);
      return;
    }

    try {
      await (await _prefs).setString(_tokenKey, normalized);
    } catch (error) {
      _log('Error saving token', error);
    }
  }

  Future<String?> getUserId() async {
    try {
      return (await _prefs).getString(_userIdKey);
    } catch (error) {
      _log('Error getting user id', error);
      return null;
    }
  }

  Future<void> saveUserId(String userId) async {
    final normalized = userId.trim();
    if (normalized.isEmpty) {
      await _remove(_userIdKey);
      return;
    }

    try {
      await (await _prefs).setString(_userIdKey, normalized);
    } catch (error) {
      _log('Error saving user id', error);
    }
  }

  Future<String?> getUserType() async {
    try {
      return normalizeUserType((await _prefs).getString(_userTypeKey));
    } catch (error) {
      _log('Error getting user type', error);
      return null;
    }
  }

  Future<void> saveUserType(String userType) async {
    final normalized = normalizeUserType(userType);
    if (normalized == null) {
      await _remove(_userTypeKey);
      return;
    }

    try {
      await (await _prefs).setString(_userTypeKey, normalized);
    } catch (error) {
      _log('Error saving user type', error);
    }
  }

  /// Saves all legacy fields together. Invalid roles are not persisted.
  Future<void> saveSession({
    required String token,
    required String userId,
    required String userType,
  }) async {
    final normalizedToken = token.trim();
    final normalizedUserId = userId.trim();
    final normalizedUserType = normalizeUserType(userType);

    if (normalizedToken.isEmpty ||
        normalizedUserId.isEmpty ||
        normalizedUserType == null) {
      await clearSession();
      return;
    }

    try {
      final prefs = await _prefs;
      await Future.wait(<Future<bool>>[
        prefs.setString(_tokenKey, normalizedToken),
        prefs.setString(_userIdKey, normalizedUserId),
        prefs.setString(_userTypeKey, normalizedUserType),
      ]);
    } catch (error) {
      _log('Error saving session', error);
      await clearSession();
    }
  }

  Future<void> clearSession() async {
    try {
      final prefs = await _prefs;
      await Future.wait(<Future<bool>>[
        prefs.remove(_tokenKey),
        prefs.remove(_userIdKey),
        prefs.remove(_userTypeKey),
      ]);
    } catch (error) {
      _log('Error clearing session', error);
    }
  }

  Future<bool> isAuthenticated() async {
    final token = await getToken();
    final userId = await getUserId();
    return token != null &&
        token.isNotEmpty &&
        userId != null &&
        userId.isNotEmpty;
  }

  Future<void> _remove(String key) async {
    try {
      await (await _prefs).remove(key);
    } catch (error) {
      _log('Error removing $key', error);
    }
  }

  void _log(String message, Object error) {
    if (kDebugMode) {
      debugPrint('$message: $error');
    }
  }
}
