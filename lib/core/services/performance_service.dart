import 'package:firebase_performance/firebase_performance.dart';
import 'package:flutter/foundation.dart';

/// Small wrapper around Firebase Performance Monitoring.
///
/// A failed trace must never fail the business operation being measured.
class loqmaPerformance {
  loqmaPerformance({FirebasePerformance? performance})
      : _performance = performance ?? FirebasePerformance.instance;

  final FirebasePerformance _performance;

  /// Measures an async operation and always returns the operation's result.
  /// Performance setup or upload failures are intentionally swallowed.
  Future<T> measure<T>(
    String traceName,
    Future<T> Function() operation, {
    Map<String, String>? attributes,
  }) async {
    Trace? trace;

    try {
      trace = _performance.newTrace(_normalizeTraceName(traceName));
      final safeAttributes = _safeAttributes(attributes);
      for (final entry in safeAttributes.entries) {
        trace.putAttribute(entry.key, entry.value);
      }
      await trace.start();
    } catch (error, stack) {
      debugPrint(
        '[Performance] trace start skipped name=$traceName error=$error',
      );
      debugPrintStack(stackTrace: stack);
      trace = null;
    }

    try {
      return await operation();
    } finally {
      if (trace != null) {
        try {
          await trace.stop();
          debugPrint('[Performance] trace stopped name=$traceName');
        } catch (error, stack) {
          debugPrint(
              '[Performance] trace stop failed name=$traceName error=$error');
          debugPrintStack(stackTrace: stack);
        }
      }
    }
  }

  Future<Trace?> startTrace(
    String traceName, {
    Map<String, String>? attributes,
  }) async {
    try {
      final trace = _performance.newTrace(_normalizeTraceName(traceName));
      final safeAttributes = _safeAttributes(attributes);
      for (final entry in safeAttributes.entries) {
        trace.putAttribute(entry.key, entry.value);
      }
      await trace.start();
      return trace;
    } catch (error, stack) {
      debugPrint(
        '[Performance] manual trace start skipped name=$traceName error=$error',
      );
      debugPrintStack(stackTrace: stack);
      return null;
    }
  }

  Future<void> stopTrace(Trace? trace, {String? traceName}) async {
    if (trace == null) return;

    try {
      await trace.stop();
      if (traceName != null) {
        debugPrint('[Performance] manual trace stopped name=$traceName');
      }
    } catch (error, stack) {
      debugPrint('[Performance] manual trace stop failed error=$error');
      debugPrintStack(stackTrace: stack);
    }
  }

  String _normalizeTraceName(String value) {
    final cleaned = value.trim().toLowerCase().replaceAll(
          RegExp(r'[^a-z0-9_]'),
          '_',
        );
    final withoutRepeatedUnderscores = cleaned.replaceAll(RegExp(r'_+'), '_');
    final normalized = withoutRepeatedUnderscores.replaceAll(
      RegExp(r'^_+|_+$'),
      '',
    );
    if (normalized.isEmpty) return 'loqma_operation';
    return normalized.length <= 100 ? normalized : normalized.substring(0, 100);
  }

  Map<String, String> _safeAttributes(Map<String, String>? attributes) {
    if (attributes == null || attributes.isEmpty) return const {};

    final result = <String, String>{};
    for (final entry in attributes.entries) {
      final key = entry.key.trim().toLowerCase();
      final value = entry.value.trim().toLowerCase();
      if (key.isEmpty ||
          value.isEmpty ||
          key.length > 40 ||
          value.length > 40) {
        continue;
      }
      if (value.contains('@') ||
          value.contains('password') ||
          value.contains('token') ||
          value.contains('http://') ||
          value.contains('https://')) {
        continue;
      }
      result[key] = value;
    }
    return result;
  }
}
