import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    UNUserNotificationCenter.current().delegate = self
    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "SafeUgNotifications") else { return }
    let channel = FlutterMethodChannel(name: "safeug/notifications", binaryMessenger: registrar.messenger())
    channel.setMethodCallHandler { call, result in
      let center = UNUserNotificationCenter.current()
      switch call.method {
      case "permission":
        center.getNotificationSettings { settings in
          DispatchQueue.main.async { result(settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional ? "granted" : "denied") }
        }
      case "requestPermission":
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
          DispatchQueue.main.async { result(granted ? "granted" : "denied") }
        }
      case "show":
        let args = call.arguments as? [String: Any] ?? [:]
        let content = UNMutableNotificationContent()
        content.title = args["title"] as? String ?? "SafeUG"
        content.body = args["body"] as? String ?? "Emergency update"
        content.sound = .default
        center.add(UNNotificationRequest(identifier: args["id"] as? String ?? "safeug", content: content, trigger: nil)) { error in
          DispatchQueue.main.async { result(error == nil ? nil : FlutterError(code: "notification", message: error?.localizedDescription, details: nil)) }
        }
      case "clear":
        center.removeAllDeliveredNotifications()
        result(nil)
      default: result(FlutterMethodNotImplemented)
      }
    }
  }

  override func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
    if #available(iOS 14.0, *) { completionHandler([.banner, .sound, .list]) }
    else { completionHandler([.alert, .sound]) }
  }
}
