import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Centralized Crashlytics reporting for loqma.
///
/// The helper accepts only short, non-sensitive context. Do not pass user
/// names, email addresses, phone numbers, passwords, auth tokens, full
/// addresses, or database identifiers.
class loqmaCrashlytics {
  loqmaCrashlytics({FirebaseCrashlytics? crashlytics})
      : _crashlytics = crashlytics ?? FirebaseCrashlytics.instance;

  final FirebaseCrashlytics _crashlytics;

  Future<void> setContext({
    String? currentScreen,
    String? userRole,
    String? appVersion,
  }) async {
    await _setSafeKey('current_screen', currentScreen);
    await _setSafeKey('user_role', userRole);
    await _setSafeKey('app_version', appVersion);
  }

  Future<void> setCurrentScreen(String screen) async {
    await _setSafeKey('current_screen', screen);
  }

  Future<void> setUserRole(String role) async {
    await _setSafeKey('user_role', role);
  }

  Future<void> log(String message) async {
    final safeMessage = _safeValue(message);
    if (safeMessage == null) return;

    try {
      await _crashlytics.log(safeMessage);
    } catch (error) {
      debugPrint('[Crashlytics] log failed: $error');
    }
  }

  Future<void> recordNonFatal(
    Object error,
    StackTrace stackTrace, {
    String? reason,
    Iterable<Object> information = const <Object>[],
    bool fatal = false,
  }) async {
    try {
      await _crashlytics.recordError(
        error,
        stackTrace,
        reason: _safeValue(reason),
        information: information
            .map(_safeInformation)
            .whereType<String>()
            .toList(growable: false),
        fatal: fatal,
      );
    } catch (reportingError, reportingStack) {
      debugPrint('[Crashlytics] recordError failed: $reportingError');
      debugPrintStack(stackTrace: reportingStack);
    }
  }

  Future<void> recordFlutterError(FlutterErrorDetails details) async {
    try {
      await _crashlytics.recordFlutterError(details);
    } catch (error, stack) {
      debugPrint('[Crashlytics] Flutter error report failed: $error');
      debugPrintStack(stackTrace: stack);
    }
  }

  Future<void> _setSafeKey(String key, String? value) async {
    final safeValue = _safeValue(value);
    if (safeValue == null) return;

    try {
      await _crashlytics.setCustomKey(key, safeValue);
    } catch (error) {
      debugPrint('[Crashlytics] custom key failed key=$key error=$error');
    }
  }

  String? _safeInformation(Object value) {
    return _safeValue(value.toString());
  }

  String? _safeValue(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) return null;
    if (normalized.length > 120) return null;

    final lower = normalized.toLowerCase();
    if (lower.contains('@') ||
        lower.contains('password') ||
        lower.contains('token') ||
        lower.contains('secret') ||
        lower.contains('authorization') ||
        lower.contains('bearer ') ||
        lower.contains('http://') ||
        lower.contains('https://')) {
      return null;
    }

    return normalized;
  }
}
