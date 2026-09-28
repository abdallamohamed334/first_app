import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
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
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAOBaBnVB74mm41dfffhDU7MB5CRHqTFV0',
    appId: '1:898976071862:android:2dc21f643a0c8a3c4ae617',
    messagingSenderId: '898976071862',
    projectId: 'flutter-app-45f07',
    storageBucket: 'flutter-app-45f07.firebasestorage.app',
  );

  // iOS: values from GoogleService-Info.plist for com.jood.app.
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyD4NwdnUQ_NkhrkjDxWRZQgauW4NEyipc',
    appId: '1:898976071862:ios:0d0c6c27d8fc9eed4ae617',
    messagingSenderId: '898976071862',
    projectId: 'flutter-app-45f07',
    storageBucket: 'flutter-app-45f07.firebasestorage.app',
    iosBundleId: 'com.jood.app',
  );

  // Web: keep the existing Web Firebase app unchanged.
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAOBaBnVB74mm41dfffhDU7MB5CRHqTFV0',
    appId: '1:898976071862:web:8572454f3a6cb2004ae617',
    messagingSenderId: '898976071862',
    projectId: 'flutter-app-45f07',
    authDomain: 'flutter-app-45f07.firebaseapp.com',
    storageBucket: 'flutter-app-45f07.firebasestorage.app',
    measurementId: 'G-XXXXXXXX',
  );

  // macOS compatibility configuration.
  // Register a separate macOS Firebase app before using Firebase on macOS.
  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyD4NwdnUQ_NkhrkjDxWRZQgauuW4NEyipc',
    appId: '1:898976071862:ios:0d0c6c27d8fc9eed4ae617',
    messagingSenderId: '898976071862',
    projectId: 'flutter-app-45f07',
    storageBucket: 'flutter-app-45f07.firebasestorage.app',
    iosBundleId: 'com.jood.app',
  );
}
