import Flutter
import UIKit
import FirebaseCore

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions:
      [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Appetize / iOS Simulator قد تُبنى بدون GoogleService-Info.plist.
    // لا نسمح لـ Firebase بإغلاق التطبيق قبل تشغيل Flutter.
    if FirebaseApp.app() == nil {
      if Bundle.main.path(
        forResource: "GoogleService-Info",
        ofType: "plist"
      ) != nil {
        FirebaseApp.configure()
        print("✅ Firebase configured from GoogleService-Info.plist")
      } else {
        print("⚠️ GoogleService-Info.plist not found; Firebase native startup skipped")
      }
    }

    GeneratedPluginRegistrant.register(with: self)

    return super.application(
      application,
      didFinishLaunchingWithOptions: launchOptions
    )
  }

  func didInitializeImplicitFlutterEngine(
    _ engineBridge: FlutterImplicitEngineBridge
  ) {
    GeneratedPluginRegistrant.register(
      with: engineBridge.pluginRegistry
    )
  }
}
