import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Centralized network reachability state for startup and runtime gating.
class ConnectivityService extends ChangeNotifier {
  ConnectivityService._();

  static final ConnectivityService instance = ConnectivityService._();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _isOffline = false;
  bool _initialized = false;
  int _checkGeneration = 0;

  bool get isOffline => _isOffline;
  bool get isInitialized => _initialized;

  Future<bool> initialize() async {
    if (_subscription == null) {
      _subscription = _connectivity.onConnectivityChanged.listen(
        (results) => unawaited(_refresh(results)),
        onError: (Object error, StackTrace stack) {
          debugPrint('[Connectivity] listener error: $error');
        },
      );
    }

    try {
      final results = await _connectivity
          .checkConnectivity()
          .timeout(const Duration(seconds: 3));
      await _refresh(results);
    } catch (error) {
      debugPrint('[Connectivity] initial check failed: $error');
      _setOffline(true);
    }

    _initialized = true;
    return !_isOffline;
  }

  Future<void> retry() async {
    try {
      final results = await _connectivity
          .checkConnectivity()
          .timeout(const Duration(seconds: 3));
      await _refresh(results);
    } catch (error) {
      debugPrint('[Connectivity] retry failed: $error');
      _setOffline(true);
    }
  }

  Future<void> _refresh(List<ConnectivityResult> results) async {
    final generation = ++_checkGeneration;
    final hasLink = results.isNotEmpty &&
        results.any((result) => result != ConnectivityResult.none);

    if (!hasLink) {
      _setOffline(true);
      return;
    }

    // connectivity_plus reports a network link, not guaranteed internet.
    // A short DNS lookup catches Wi-Fi/mobile networks without internet.
    try {
      final addresses = await InternetAddress.lookup('example.com')
          .timeout(const Duration(seconds: 4));
      if (generation != _checkGeneration) return;
      _setOffline(addresses.isEmpty);
    } catch (error) {
      if (generation != _checkGeneration) return;
      debugPrint('[Connectivity] internet probe failed: $error');
      _setOffline(true);
    }
  }

  void _setOffline(bool value) {
    if (_isOffline == value) return;
    _isOffline = value;
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    _subscription = null;
    super.dispose();
  }
}
