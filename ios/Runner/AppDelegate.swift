import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // CRITICAL FIX: Call super.application() FIRST to initialize Flutter engine
    // This prevents path_provider_foundation crash during plugin registration
    let result = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    
    // Now register plugins after Flutter engine is ready
    GeneratedPluginRegistrant.register(with: self)
    
    // Note: FirebaseAppDelegateProxyEnabled is set to false in Info.plist, 
    // so we manage Firebase initialization in Dart (main.dart)
    return result
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
