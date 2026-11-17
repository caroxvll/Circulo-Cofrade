import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var screenGuard: FlutterMethodChannel?
  private var screenshotObserver: NSObjectProtocol?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    let ok = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: "cofradeo/screen_guard",
        binaryMessenger: controller.binaryMessenger
      )
      screenGuard = channel
      channel.setMethodCallHandler { [weak self] call, result in
        switch call.method {
        case "protect":
          self?.startWatchingScreenshots()
          result(nil)
        case "unprotect":
          self?.stopWatchingScreenshots()
          result(nil)
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }
    return ok
  }

  private func startWatchingScreenshots() {
    guard screenshotObserver == nil else { return }
    screenshotObserver = NotificationCenter.default.addObserver(
      forName: UIApplication.userDidTakeScreenshotNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      self?.screenGuard?.invokeMethod("screenshot", arguments: nil)
    }
  }

  private func stopWatchingScreenshots() {
    if let screenshotObserver {
      NotificationCenter.default.removeObserver(screenshotObserver)
      self.screenshotObserver = nil
    }
  }
}
