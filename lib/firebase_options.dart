import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class DefaultFirebaseOptions {
  static Map<String, String> _runtimeOverrides = const {};

  static void setRuntimeOverrides(Map<String, String> values) {
    _runtimeOverrides = Map.unmodifiable(values);
  }

  static String? _optionalEnv(String name) {
    final value = _runtimeOverrides[name] ??
        dotenv.env[name] ??
        String.fromEnvironment(name);
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static String _env(String name) {
    final value = _runtimeOverrides[name] ??
        dotenv.env[name] ??
        String.fromEnvironment(name);
    if (value.trim().isEmpty) {
      throw StateError('$name is missing from the environment');
    }
    return value.trim();
  }

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  // Android: Firebase app registered for com.jood.app.
  static FirebaseOptions get android => FirebaseOptions(
        // Firebase is optional at startup. If the key is not injected, main()
        // skips Firebase/FCM without blocking Supabase or the auth UI.
        apiKey: _env('FIREBASE_ANDROID_API_KEY'),
        appId: '1:898976071862:android:2dc21f643a0c8a3c4ae617',
        messagingSenderId: '898976071862',
        projectId: 'flutter-app-45f07',
        storageBucket: 'flutter-app-45f07.firebasestorage.app',
      );

  // iOS: values from GoogleService-Info.plist for com.jood.app.
  static FirebaseOptions get ios => FirebaseOptions(
        // Firebase API keys are public client identifiers and are also present
        // in GoogleService-Info.plist bundled with the iOS target.
        apiKey: _optionalEnv('FIREBASE_IOS_API_KEY') ??
            'AIzaSyD4NwdnUQ_NkhrkjDxWRZQgauW4NEyipc',
        appId: '1:898976071862:ios:0d0c6c27d8fc9eed4ae617',
        messagingSenderId: '898976071862',
        projectId: 'flutter-app-45f07',
        storageBucket: 'flutter-app-45f07.firebasestorage.app',
        iosBundleId: 'com.jood.app',
      );

  // Web: keep the existing Web Firebase app unchanged.
  static FirebaseOptions get web => FirebaseOptions(
        apiKey: _env('FIREBASE_WEB_API_KEY'),
        appId: '1:898976071862:web:8572454f3a6cb2004ae617',
        messagingSenderId: '898976071862',
        projectId: 'flutter-app-45f07',
        authDomain: 'flutter-app-45f07.firebaseapp.com',
        storageBucket: 'flutter-app-45f07.firebasestorage.app',
        measurementId: _optionalEnv('FIREBASE_WEB_MEASUREMENT_ID'),
      );

  // macOS compatibility configuration.
  // Register a separate macOS Firebase app before using Firebase on macOS.
  static FirebaseOptions get macos => FirebaseOptions(
        apiKey: _env('FIREBASE_MACOS_API_KEY'),
        appId: '1:898976071862:ios:0d0c6c27d8fc9eed4ae617',
        messagingSenderId: '898976071862',
        projectId: 'flutter-app-45f07',
        storageBucket: 'flutter-app-45f07.firebasestorage.app',
        iosBundleId: 'com.jood.app',
      );
}
