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
  Uri? _probeUri;

  bool get isOffline => _isOffline;
  bool get isInitialized => _initialized;

  Future<bool> initialize({String? probeUrl}) async {
    final parsedProbeUrl = Uri.tryParse(probeUrl?.trim() ?? '');
    if (parsedProbeUrl != null && parsedProbeUrl.host.isNotEmpty) {
      _probeUri = parsedProbeUrl;
    }
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
    // Probe the actual backend host so cached DNS cannot make an offline
    // device pass the startup check.
    try {
      if (generation != _checkGeneration) return;
      final reachable = await _probeBackend();
      if (generation != _checkGeneration) return;
      _setOffline(!reachable);
    } catch (error) {
      if (generation != _checkGeneration) return;
      debugPrint('[Connectivity] internet probe failed: $error');
      _setOffline(true);
    }
  }

  Future<bool> _probeBackend() async {
    final uri = _probeUri;
    if (uri == null || uri.host.isEmpty) {
      try {
        final addresses = await InternetAddress.lookup('example.com')
            .timeout(const Duration(seconds: 3));
        return addresses.isNotEmpty;
      } catch (_) {
        return false;
      }
    }

    final httpClient = HttpClient()
      ..connectionTimeout = const Duration(seconds: 3)
      ..idleTimeout = const Duration(seconds: 3);
    try {
      final request = await httpClient.headUrl(uri).timeout(
            const Duration(seconds: 3),
          );
      final response = await request.close().timeout(
            const Duration(seconds: 3),
          );
      // 401/404/405 still prove that the backend is reachable.
      return response.statusCode < 500;
    } catch (_) {
      return false;
    } finally {
      httpClient.close(force: true);
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
