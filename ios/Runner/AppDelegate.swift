import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Standard Flutter initialization - super.application() handles plugin registration
    // Firebase initialization is managed in Dart (main.dart)
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  // Handle push notifications registration
  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    // Forward to plugins (Firebase Messaging)
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }
  
  // Handle push notifications registration failure
  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    print("⚠️ Failed to register for remote notifications: \(error.localizedDescription)")
  }
  
  // Handle notification tap when app is terminated or in background
  override func application(
    _ application: UIApplication,
    didReceiveRemoteNotification userInfo: [AnyHashable: Any],
    fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
  ) {
    super.application(application, didReceiveRemoteNotification: userInfo, fetchCompletionHandler: completionHandler)
  }
}
