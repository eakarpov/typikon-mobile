import UIKit
import Flutter

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    let launched = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(name: "su.typikon.typikon/utils",
        binaryMessenger: controller.binaryMessenger)
      channel.setMethodCallHandler { call, result in
        if call.method == "setKeepScreenOn", let enabled = call.arguments as? Bool {
          UIApplication.shared.isIdleTimerDisabled = enabled
          result(nil)
        } else {
          result(FlutterMethodNotImplemented)
        }
      }
    }
    return launched
  }
}
