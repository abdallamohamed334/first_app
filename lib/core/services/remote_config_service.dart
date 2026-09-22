import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

/// Centralized, typed access to loqma Remote Config values.
///
/// Remote Config changes presentation and rollout behavior only. It must not
/// be used as a security boundary; Supabase RLS and server-side RPCs remain the
/// source of truth for permissions, inventory, and status transitions.
class loqmaRemoteConfig {
  loqmaRemoteConfig({FirebaseRemoteConfig? remoteConfig})
      : _remoteConfig = remoteConfig ?? FirebaseRemoteConfig.instance;

  final FirebaseRemoteConfig _remoteConfig;

  static const Map<String, dynamic> safeDefaults = <String, dynamic>{
    'maintenance_mode': false,
    'show_new_donation_flow': false,
    'show_new_home_banner': false,
    'donation_expiry_warning_minutes': 30,
    'max_donation_images': 5,
    'enable_qr_pickup': true,
    'enable_charity_notifications': true,
    'enable_restaurant_features': true,
  };

  Future<void> initialize() async {
    try {
      await _remoteConfig.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 10),
          minimumFetchInterval: kDebugMode
              ? const Duration(minutes: 5)
              : const Duration(hours: 1),
        ),
      );

      await _remoteConfig.setDefaults(safeDefaults);
      await _remoteConfig.fetchAndActivate();
      debugPrint('[RemoteConfig] defaults loaded and values activated');
    } catch (error, stack) {
      // The SDK keeps the defaults when Firebase or the network is unavailable.
      debugPrint(
          '[RemoteConfig] activation skipped; defaults retained: $error');
      debugPrintStack(stackTrace: stack);
    }
  }

  bool get maintenanceMode => _remoteConfig.getBool('maintenance_mode');

  bool get showNewDonationFlow =>
      _remoteConfig.getBool('show_new_donation_flow');

  bool get showNewHomeBanner => _remoteConfig.getBool('show_new_home_banner');

  int get donationExpiryWarningMinutes => _boundedInt(
        _remoteConfig.getInt('donation_expiry_warning_minutes'),
        fallback: 30,
        min: 1,
        max: 24 * 60,
      );

  int get maxDonationImages => _boundedInt(
        _remoteConfig.getInt('max_donation_images'),
        fallback: 5,
        min: 1,
        max: 20,
      );

  bool get enableQrPickup => _remoteConfig.getBool('enable_qr_pickup');

  bool get enableCharityNotifications =>
      _remoteConfig.getBool('enable_charity_notifications');

  bool get enableRestaurantFeatures =>
      _remoteConfig.getBool('enable_restaurant_features');

  String getString(String key, {String fallback = ''}) {
    final value = _remoteConfig.getString(key).trim();
    return value.isEmpty ? fallback : value;
  }

  bool getBool(String key, {bool fallback = false}) {
    try {
      return _remoteConfig.getBool(key);
    } catch (_) {
      return fallback;
    }
  }

  int getInt(String key, {int fallback = 0}) {
    try {
      return _remoteConfig.getInt(key);
    } catch (_) {
      return fallback;
    }
  }

  int _boundedInt(
    int value, {
    required int fallback,
    required int min,
    required int max,
  }) {
    if (value < min || value > max) return fallback;
    return value;
  }
}
