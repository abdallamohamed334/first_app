import 'package:sentry_flutter/sentry_flutter.dart';

enum SentryFilterResult { drop, report }

/// Privacy-safe Sentry helpers. The SDK itself is disabled when no DSN is
/// supplied (and the app never enables it in debug builds).
class LoqmaSentry {
  static bool enabled = false;

  /// Shared classification logic used by production filtering and the hidden
  /// debug verification screen. It deliberately keeps server/RLS failures.
  static SentryFilterResult classify({
    required String type,
    required String message,
  }) {
    final normalizedType = type.toLowerCase();
    final normalized = '$normalizedType ${message.toLowerCase()}';
    final isPostgrest = normalizedType.contains('postgrestexception');
    final isStorage = normalizedType.contains('storageexception');

    if (normalizedType.contains('cachednetworkimage') &&
        RegExp(r'404|not found|missing|deleted|image provider')
            .hasMatch(normalized)) {
      return SentryFilterResult.drop;
    }

    if (!isPostgrest &&
        (normalizedType.contains('socketexception') ||
            normalizedType.contains('clientexception') ||
            normalizedType.contains('timeoutexception') ||
            normalizedType.contains('handshakeexception') ||
            RegExp(r'connection closed|network is unreachable|failed host lookup')
                .hasMatch(normalized))) {
      return SentryFilterResult.drop;
    }

    if (isStorage) {
      final isNetworkStorageFailure = RegExp(
        r'network|socket|timeout|connection|unreachable|failed host',
      ).hasMatch(normalized);
      return isNetworkStorageFailure
          ? SentryFilterResult.drop
          : SentryFilterResult.report;
    }

    if (RegExp(
      r'invalid login credentials|invalid credentials|email already registered|'
      r'weak password|otp wrong|wrong otp|otp expired|expired otp|'
      r'permission denied by user|user denied|cancelled|canceled|dismissed',
    ).hasMatch(normalized)) {
      return SentryFilterResult.drop;
    }

    if (RegExp(
      r'sold out|sold_out|reservation limit|limit reached|offer expired|'
      r'انتهى العرض|العرض منتهي|نفدت|الحد الأقصى للحجز',
    ).hasMatch(normalized)) {
      return SentryFilterResult.drop;
    }

    // PostgrestException is intentionally not filtered: 5xx and RLS failures
    // are actionable backend problems even when their text contains "network".
    return SentryFilterResult.report;
  }

  static Future<void> setAnonymousUser(String? userId) async {
    if (!enabled) return;
    try {
      final id = userId?.trim();
      await Sentry.configureScope((scope) {
        scope.setUser(id == null || id.isEmpty ? null : SentryUser(id: id));
      });
    } catch (_) {
      // Monitoring must never block auth/session recovery.
    }
  }

  static Future<void> breadcrumb(
    String flow, {
    String? action,
    String? outcome,
  }) async {
    if (!enabled) return;
    try {
      await Sentry.addBreadcrumb(
        Breadcrumb(
          category: 'flow',
          message: action == null ? flow : '$flow: $action',
          data: {
            'flow': flow,
            if (outcome != null) 'outcome': outcome,
          },
        ),
      );
    } catch (_) {
      // Monitoring must never block auth/session recovery.
    }
  }

  static Future<void> capture(
    Object error,
    StackTrace stackTrace, {
    required String flow,
  }) async {
    if (!enabled) return;
    try {
      await breadcrumb(flow, action: 'error');
      await Sentry.captureException(error, stackTrace: stackTrace);
    } catch (_) {
      // Monitoring must never mask the original application error.
    }
  }

  static Future<void> testException() async {
    if (!enabled) return;
    try {
      await Sentry.captureException(
        StateError('Khedma Sentry test exception'),
        stackTrace: StackTrace.current,
      );
    } catch (_) {
      // The test control must not crash the app if Sentry is unavailable.
    }
  }
}
