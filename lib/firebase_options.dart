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

  // ✅ Android
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAOBaBnVB74mm41dfffhDU7MB5CRHqTFV0',
    appId: '1:898976071862:android:8572454f3a6cb2004ae617',
    messagingSenderId: '898976071862',
    projectId: 'flutter-app-45f07',
    storageBucket: 'flutter-app-45f07.firebasestorage.app',
  );

  // ✅ iOS (للتوافق)
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAOBaBnVB74mm41dfffhDU7MB5CRHqTFV0',
    appId: '1:898976071862:ios:8572454f3a6cb2004ae617',
    messagingSenderId: '898976071862',
    projectId: 'flutter-app-45f07',
    storageBucket: 'flutter-app-45f07.firebasestorage.app',
    iosClientId: '898976071862-xxxxxxxx.apps.googleusercontent.com',
    iosBundleId: 'com.example.first_app',
  );

  // ✅ Web (للتوافق)
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAOBaBnVB74mm41dfffhDU7MB5CRHqTFV0',
    appId: '1:898976071862:web:8572454f3a6cb2004ae617',
    messagingSenderId: '898976071862',
    projectId: 'flutter-app-45f07',
    authDomain: 'flutter-app-45f07.firebaseapp.com',
    storageBucket: 'flutter-app-45f07.firebasestorage.app',
    measurementId: 'G-XXXXXXXX',
  );

  // ✅ macOS (للتوافق)
  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyAOBaBnVB74mm41dfffhDU7MB5CRHqTFV0',
    appId: '1:898976071862:ios:8572454f3a6cb2004ae617',
    messagingSenderId: '898976071862',
    projectId: 'flutter-app-45f07',
    storageBucket: 'flutter-app-45f07.firebasestorage.app',
    iosClientId: '898976071862-xxxxxxxx.apps.googleusercontent.com',
    iosBundleId: 'com.example.first_app',
  );
}
