import UIKit
import UserNotifications
import FirebaseCore
import FirebaseMessaging

/// UIKit callbacks SwiftUI does not surface: APNs registration, background
/// pushes and notification presentation/taps.
///
/// The notification feature (`PushNotificationService`) installs the hooks
/// below in its `initialize()`, so this file holds no feature logic — the
/// counterpart of Flutter's `AppDelegate` plus `firebase_messaging`'s
/// background handler registration in `bootstrap()`.
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    /// Hooks installed by the notification feature.
    enum Hooks {
        /// Foreground presentation (`FirebaseMessaging.onMessage` + local notification).
        static var willPresent: ((UNNotification) -> UNNotificationPresentationOptions)?
        /// A notification was tapped (`onMessageOpenedApp` / `getInitialMessage`).
        static var didReceiveResponse: ((UNNotificationResponse) -> Void)?
        /// Silent / background push (`firebaseMessagingBackgroundHandler`).
        static var didReceiveRemoteNotification: (([AnyHashable: Any]) async -> UIBackgroundFetchResult)?
        /// A tap that arrived before the feature installed its hooks.
        static var pendingResponse: UNNotificationResponse?
    }

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        if FirebaseApp.app() == nil { FirebaseApp.configure() }
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any]
    ) async -> UIBackgroundFetchResult {
        Messaging.messaging().appDidReceiveMessage(userInfo)
        return await Hooks.didReceiveRemoteNotification?(userInfo) ?? .noData
    }

    // MARK: - UNUserNotificationCenterDelegate

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        Hooks.willPresent?(notification) ?? [.banner, .list, .sound]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        if let hook = Hooks.didReceiveResponse {
            hook(response)
        } else {
            Hooks.pendingResponse = response
        }
    }
}
