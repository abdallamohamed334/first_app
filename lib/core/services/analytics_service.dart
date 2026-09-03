import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

/// Centralized Firebase Analytics events for Loqma.
///
/// Only allowlisted, non-sensitive dimensions are accepted. Never pass email,
/// phone numbers, passwords, auth tokens, full addresses, names, or database
/// identifiers to this service.
class LoqmaAnalytics {
  LoqmaAnalytics({FirebaseAnalytics? analytics})
      : _analytics = analytics ?? FirebaseAnalytics.instance;

  final FirebaseAnalytics _analytics;

  Future<void> appOpen() => _log('app_open');

  Future<void> userLogin({required String userRole}) => _log(
        'user_login',
        parameters: _params(userRole: userRole),
      );

  Future<void> userSignup({required String userRole}) => _log(
        'user_signup',
        parameters: _params(userRole: userRole),
      );

  Future<void> donationCreated({
    required String donationType,
    String? userRole,
    String? city,
    String? foodCategory,
  }) =>
      _log(
        'donation_created',
        parameters: _params(
          donationType: donationType,
          userRole: userRole,
          city: city,
          foodCategory: foodCategory,
        ),
      );

  Future<void> donationViewed({
    required String donationType,
    String? city,
    String? foodCategory,
  }) =>
      _log(
        'donation_viewed',
        parameters: _params(
          donationType: donationType,
          city: city,
          foodCategory: foodCategory,
        ),
      );

  Future<void> donationAccepted({
    required String donationType,
    String? userRole,
    String? city,
  }) =>
      _log(
        'donation_accepted',
        parameters: _params(
          donationType: donationType,
          userRole: userRole,
          city: city,
        ),
      );

  Future<void> donationCancelled({
    required String donationType,
    String? userRole,
  }) =>
      _log(
        'donation_cancelled',
        parameters: _params(
          donationType: donationType,
          userRole: userRole,
        ),
      );

  Future<void> donationExpired({
    required String donationType,
    String? city,
  }) =>
      _log(
        'donation_expired',
        parameters: _params(
          donationType: donationType,
          city: city,
        ),
      );

  Future<void> pickupStarted({
    required String donationType,
    String? userRole,
  }) =>
      _log(
        'pickup_started',
        parameters: _params(
          donationType: donationType,
          userRole: userRole,
        ),
      );

  Future<void> pickupCompleted({
    required String donationType,
    String? userRole,
  }) =>
      _log(
        'pickup_completed',
        parameters: _params(
          donationType: donationType,
          userRole: userRole,
        ),
      );

  Future<void> charityRegistered({String? city}) => _log(
        'charity_registered',
        parameters: _params(city: city, userRole: 'charity'),
      );

  Future<void> restaurantRegistered({String? city}) => _log(
        'restaurant_registered',
        parameters: _params(city: city, userRole: 'restaurant'),
      );

  Future<void> qrScanned({
    required String donationType,
    String? userRole,
  }) =>
      _log(
        'qr_scanned',
        parameters: _params(
          donationType: donationType,
          userRole: userRole,
        ),
      );

  Future<void> notificationOpened({required String notificationType}) => _log(
        'notification_opened',
        parameters: _params(notificationType: notificationType),
      );

  Future<void> searchPerformed({
    String? foodCategory,
    String? city,
  }) =>
      _log(
        'search_performed',
        parameters: _params(
          foodCategory: foodCategory,
          city: city,
        ),
      );

  Future<void> locationPermissionGranted() =>
      _log('location_permission_granted');

  Future<void> locationPermissionDenied() => _log('location_permission_denied');

  Future<void> _log(
    String name, {
    Map<String, Object>? parameters,
  }) async {
    try {
      await _analytics.logEvent(
        name: name,
        parameters: parameters,
      );
      debugPrint('[Analytics] event=$name');
    } catch (error, stack) {
      // Analytics must never interrupt a user action.
      debugPrint('[Analytics] event failed name=$name error=$error');
      debugPrintStack(stackTrace: stack);
    }
  }

  Map<String, Object> _params({
    String? donationType,
    String? userRole,
    String? city,
    String? foodCategory,
    String? notificationType,
  }) {
    final result = <String, Object>{};
    _put(result, 'donation_type', donationType);
    _put(result, 'user_role', userRole);
    _put(result, 'city', city);
    _put(result, 'food_category', foodCategory);
    _put(result, 'notification_type', notificationType);
    return result;
  }

  void _put(Map<String, Object> target, String key, String? value) {
    final normalized = _safeDimension(value);
    if (normalized != null) target[key] = normalized;
  }

  String? _safeDimension(String? value) {
    final normalized = value?.trim().toLowerCase();
    if (normalized == null || normalized.isEmpty) return null;

    // Keep dimensions short and categorical. This blocks accidental logging
    // of long free-text values that might contain personal information.
    if (normalized.length > 40) return null;
    if (normalized.contains('@') ||
        normalized.contains('password') ||
        normalized.contains('token') ||
        normalized.contains('http://') ||
        normalized.contains('https://')) {
      return null;
    }

    return normalized;
  }
}
