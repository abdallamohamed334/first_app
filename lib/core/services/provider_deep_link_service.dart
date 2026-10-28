import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';

/// Converts incoming custom-scheme and HTTPS App Links into app routes.
class ProviderDeepLinkService {
  ProviderDeepLinkService({AppLinks? appLinks})
      : _appLinks = appLinks ?? AppLinks();

  final AppLinks _appLinks;
  StreamSubscription<Uri>? _subscription;

  Future<void> start({required ValueChanged<String> onProviderPath}) async {
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        _handle(initialUri, onProviderPath);
      }
    } catch (error) {
      debugPrint('[DeepLink] initial link unavailable: $error');
    }

    await _subscription?.cancel();
    _subscription = _appLinks.uriLinkStream.listen(
      (uri) => _handle(uri, onProviderPath),
      onError: (Object error, StackTrace stack) {
        debugPrint('[DeepLink] stream error: $error');
      },
    );
  }

  void _handle(Uri uri, ValueChanged<String> onProviderPath) {
    final pathSegments = uri.pathSegments;
    final usesCustomHost = uri.scheme == 'khedma' &&
        uri.host == 'service-provider' &&
        pathSegments.length == 1;
    final usesPath = pathSegments.length == 2 &&
        pathSegments.first == 'service-provider';
    if (!usesCustomHost && !usesPath) return;

    final providerId = Uri.decodeComponent(
      usesCustomHost ? pathSegments.first : pathSegments.last,
    ).trim();
    if (providerId.isEmpty) return;

    final isCustomScheme = uri.scheme == 'khedma';
    final isPublicWebLink = uri.scheme == 'https' && uri.host == 'khedma.app';
    if (isCustomScheme || isPublicWebLink) {
      onProviderPath('/service-provider/$providerId');
    }
  }

  Future<void> dispose() async => _subscription?.cancel();
}
