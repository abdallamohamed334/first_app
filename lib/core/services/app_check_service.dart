import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

/// Configures Firebase App Check without breaking local development.
///
/// App Check protects Firebase-backed services. Supabase RLS, RPC ownership,
/// and server-side authorization remain responsible for loqma business data.
class loqmaAppCheck {
  loqmaAppCheck({FirebaseAppCheck? appCheck})
      : _appCheck = appCheck ?? FirebaseAppCheck.instance;

  final FirebaseAppCheck _appCheck;

  Future<void> activate({String? webRecaptchaSiteKey}) async {
    try {
      if (kIsWeb) {
        final siteKey = webRecaptchaSiteKey?.trim();
        if (siteKey == null || siteKey.isEmpty) {
          debugPrint(
            '[AppCheck] web activation skipped: configure the reCAPTCHA v3 site key',
          );
          return;
        }

        await _appCheck.activate(
          webProvider: ReCaptchaV3Provider(siteKey),
        );
        debugPrint('[AppCheck] web reCAPTCHA provider activated');
        return;
      }

      await _appCheck.activate(
        androidProvider:
            kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
        appleProvider:
            kDebugMode ? AppleProvider.debug : AppleProvider.appAttest,
      );

      debugPrint(
        '[AppCheck] activated with mode=${kDebugMode ? 'debug' : 'production'}',
      );
    } catch (error, stack) {
      // App Check must not prevent the application shell from starting.
      debugPrint('[AppCheck] activation failed: $error');
      debugPrintStack(stackTrace: stack);
    }
  }
}
