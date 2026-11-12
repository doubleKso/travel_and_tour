// Port of lib/features/notification/data/datasources/background_notification_service.dart

import Foundation
import FirebaseCore

/// Registered before runApp. Android invokes this in a separate isolate, so it
/// must not read Riverpod, navigate, or depend on main() having initialized data.
///
/// On iOS FlutterFire runs it for an FCM delivery that arrives while the app is
/// in the background; `PushNotificationHooks` calls it from
/// `AppDelegate.Hooks.didReceiveRemoteNotification`.
@MainActor
func firebaseMessagingBackgroundHandler(_ message: RemoteMessage) async {
    do {
        // Load the active flavor's native Firebase configuration.
        if FirebaseApp.app() == nil { FirebaseApp.configure() }
        try await displayBackgroundNotification(message)
    } catch {
        // Do not log private notification bodies or device tokens.
        superPrint("Background notification handling failed.")
    }
}

@MainActor
func displayBackgroundNotification(
    _ message: RemoteMessage,
    notifications: LocalNotificationService? = nil
) async throws {
    // FCM/APNs already displays notification payloads while backgrounded. Only
    // data-only messages with explicit title/body need a local notification.
    if message.notification != nil { return }
    let push = PushMessage.fromRemoteMessage(message)
    if !push.hasContent { return }
    try await (notifications ?? LocalNotificationService.instance).show(push)
}
