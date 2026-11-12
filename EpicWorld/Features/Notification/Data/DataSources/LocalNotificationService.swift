// Port of lib/features/notification/data/datasources/local_notification_service.dart

import UIKit
import UserNotifications

/// One instance per isolate. Background setup must not replace the UI's tap
/// callback on iOS, where Firebase uses the main isolate for both handlers.
///
/// Not `final`: tests replace it with a hand-written fake, as the Dart tests do.
@MainActor
class LocalNotificationService {
    init(plugin: LocalNotificationsPlugin? = nil) {
        self.plugin = plugin ?? UserNotificationsPlugin()
    }

    static let instance = LocalNotificationService()

    /// The Android notification channel. iOS has no channels; the values are
    /// kept so both platforms describe the same alert stream.
    static let channel = AndroidNotificationChannel(
        id: "epic_world_updates",
        name: "Epic World updates",
        description: "Booking updates and notifications from Epic World."
    )

    private let plugin: LocalNotificationsPlugin
    private var initialization: Task<Void, Error>?
    var onTap: ((PushMessage) -> Void)?

    func initialize() async throws {
        let task: Task<Void, Error>
        if let initialization {
            task = initialization
        } else {
            task = Task { [unowned self] in try await self.runInitialize() }
            initialization = task
        }
        try await task.value
    }

    /// Dart `_initialize`.
    private func runInitialize() async throws {
        do {
            // DarwinInitializationSettings(requestAlertPermission: false,
            // requestBadgePermission: false, requestSoundPermission: false):
            // permission is asked by `PushNotificationService` instead.
            _ = try await plugin.initialize(onDidReceiveNotificationResponse: { [weak self] payload in
                guard let message = PushMessage.fromPayload(payload) else { return }
                self?.onTap?(message)
            })
            // `createNotificationChannel(channel)` resolves to the Android
            // implementation only; on iOS it is a no-op.
        } catch {
            initialization = nil
            throw error
        }
    }

    func getInitialMessage() async -> PushMessage? {
        let details = await plugin.getNotificationAppLaunchDetails()
        if details?.didNotificationLaunchApp != true { return nil }
        return PushMessage.fromPayload(details?.notificationResponse?.payload)
    }

    func show(_ message: PushMessage) async throws {
        if !message.hasContent { return }
        try await initialize()
        // Android details (channel, icon, importance, big-text style) have no
        // iOS counterpart; the Darwin details below are what iOS uses.
        try await plugin.show(
            id: message.localId,
            title: message.title,
            body: message.body,
            payload: message.toPayload(),
            notificationDetails: DarwinNotificationDetails(
                presentAlert: true,
                presentBanner: true,
                presentList: true,
                presentSound: true,
                presentBadge: false
            )
        )
    }

    func openSettings() async {
        await plugin.openAppNotificationSettings()
    }
}

// MARK: - flutter_local_notifications on iOS

/// flutter_local_notifications' `AndroidNotificationChannel` (metadata only).
struct AndroidNotificationChannel {
    let id: String
    let name: String
    let description: String
}

/// flutter_local_notifications' `DarwinNotificationDetails` — how iOS shows a
/// local alert while the app is in the foreground.
struct DarwinNotificationDetails {
    var presentAlert: Bool
    var presentBanner: Bool
    var presentList: Bool
    var presentSound: Bool
    var presentBadge: Bool
}

/// flutter_local_notifications' `NotificationResponse` (the tapped payload).
struct NotificationResponse {
    let payload: String?
}

/// flutter_local_notifications' `NotificationAppLaunchDetails`.
struct NotificationAppLaunchDetails {
    let didNotificationLaunchApp: Bool
    let notificationResponse: NotificationResponse?
}

/// The slice of `FlutterLocalNotificationsPlugin` the service uses —
/// `UNUserNotificationCenter` in the app, a fake in tests.
protocol LocalNotificationsPlugin: AnyObject {
    /// `plugin.initialize(settings:, onDidReceiveNotificationResponse:)`.
    func initialize(onDidReceiveNotificationResponse: @escaping (_ payload: String?) -> Void) async throws -> Bool
    /// `plugin.getNotificationAppLaunchDetails()`.
    func getNotificationAppLaunchDetails() async -> NotificationAppLaunchDetails?
    /// `plugin.show(id:, title:, body:, payload:, notificationDetails:)`.
    func show(
        id: Int,
        title: String?,
        body: String?,
        payload: String?,
        notificationDetails: DarwinNotificationDetails
    ) async throws
    /// `plugin.openAppNotificationSettings()`.
    func openAppNotificationSettings() async
}

/// The iOS implementation of flutter_local_notifications over
/// `UNUserNotificationCenter`.
///
/// Like the plugin, it tags its own alerts in `userInfo` (payload and
/// foreground presentation), so `AppDelegate`'s callbacks can tell them apart
/// from FCM deliveries — see `PushNotificationHooks`.
final class UserNotificationsPlugin: LocalNotificationsPlugin {
    /// `userInfo` keys flutter_local_notifications writes on iOS.
    static let payloadKey = "payload"
    static let presentAlertKey = "presentAlert"
    static let presentBannerKey = "presentBanner"
    static let presentListKey = "presentList"
    static let presentSoundKey = "presentSound"
    static let presentBadgeKey = "presentBadge"
    /// Marks a request this plugin created (`isAFlutterLocalNotification`).
    static let notificationIdKey = "NotificationId"

    /// The tap callback registered by the latest `initialize` (the plugin
    /// keeps one per isolate).
    private static var onDidReceiveNotificationResponse: ((String?) -> Void)?

    init() {}

    func initialize(onDidReceiveNotificationResponse: @escaping (String?) -> Void) async throws -> Bool {
        Self.onDidReceiveNotificationResponse = onDidReceiveNotificationResponse
        return true
    }

    func getNotificationAppLaunchDetails() async -> NotificationAppLaunchDetails? {
        // A tap that arrived before the notification feature installed its
        // hooks is what launched the app.
        guard let response = AppDelegate.Hooks.pendingResponse,
              Self.isLocalNotification(response.notification) else {
            return NotificationAppLaunchDetails(didNotificationLaunchApp: false, notificationResponse: nil)
        }
        return NotificationAppLaunchDetails(
            didNotificationLaunchApp: true,
            notificationResponse: NotificationResponse(payload: Self.payload(of: response.notification))
        )
    }

    func show(
        id: Int,
        title: String?,
        body: String?,
        payload: String?,
        notificationDetails: DarwinNotificationDetails
    ) async throws {
        let content = UNMutableNotificationContent()
        content.title = title ?? ""
        content.body = body ?? ""
        if notificationDetails.presentSound { content.sound = .default }
        var userInfo: [AnyHashable: Any] = [
            Self.notificationIdKey: id,
            Self.presentAlertKey: notificationDetails.presentAlert,
            Self.presentBannerKey: notificationDetails.presentBanner,
            Self.presentListKey: notificationDetails.presentList,
            Self.presentSoundKey: notificationDetails.presentSound,
            Self.presentBadgeKey: notificationDetails.presentBadge,
        ]
        if let payload { userInfo[Self.payloadKey] = payload }
        content.userInfo = userInfo
        let request = UNNotificationRequest(identifier: String(id), content: content, trigger: nil)
        try await UNUserNotificationCenter.current().add(request)
    }

    func openAppNotificationSettings() async {
        let link = await MainActor.run { UIApplication.openNotificationSettingsURLString }
        await ContactLauncher.open(URL(string: link))
    }

    // MARK: - Delegate glue (used by `PushNotificationHooks`)

    /// Whether `notification` is one of this plugin's alerts.
    static func isLocalNotification(_ notification: UNNotification) -> Bool {
        notification.request.content.userInfo[notificationIdKey] != nil
    }

    static func payload(of notification: UNNotification) -> String? {
        notification.request.content.userInfo[payloadKey] as? String
    }

    /// Foreground presentation for one of this plugin's alerts, from the
    /// Darwin details it was shown with.
    static func presentationOptions(for notification: UNNotification) -> UNNotificationPresentationOptions {
        let userInfo = notification.request.content.userInfo
        func flag(_ key: String) -> Bool { (userInfo[key] as? Bool) ?? false }
        var options: UNNotificationPresentationOptions = []
        if flag(presentAlertKey) || flag(presentBannerKey) { options.insert(.banner) }
        if flag(presentListKey) { options.insert(.list) }
        if flag(presentSoundKey) { options.insert(.sound) }
        if flag(presentBadgeKey) { options.insert(.badge) }
        return options
    }

    /// `onDidReceiveNotificationResponse` for a tapped local alert.
    static func didReceive(_ response: UNNotificationResponse) {
        onDidReceiveNotificationResponse?(payload(of: response.notification))
    }
}
