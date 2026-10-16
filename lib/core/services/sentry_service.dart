import 'package:sentry_flutter/sentry_flutter.dart';

/// Privacy-safe Sentry helpers. The SDK itself is disabled when no DSN is
/// supplied (and the app never enables it in debug builds).
class LoqmaSentry {
  static bool enabled = false;

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
