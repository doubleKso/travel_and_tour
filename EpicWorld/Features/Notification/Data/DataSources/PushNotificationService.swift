// Port of lib/features/notification/data/datasources/push_notification_service.dart

import Foundation
import Observation
import UIKit
import UserNotifications
import FirebaseMessaging

/// Owns mobile push subscriptions, permission state, and pending notification
/// taps. The backend's device-registration API can observe `token`; the token
/// is not an authentication credential and is never logged or sent to dcExec.
///
/// Dart's `ChangeNotifier` becomes `@Observable`: every published property
/// change reaches observers by itself, so the Dart `_notify()` calls have no
/// Swift counterpart.
@MainActor
@Observable
final class PushNotificationService {
    init(
        messaging: PushMessaging? = nil,
        notifications: LocalNotificationService? = nil,
        foregroundMessages: PushEventStream<RemoteMessage>? = nil,
        openedMessages: PushEventStream<RemoteMessage>? = nil,
        onMessageReceived: (() -> Void)? = nil
    ) {
        providedMessaging = messaging
        self.notifications = notifications ?? LocalNotificationService.instance
        self.foregroundMessages = foregroundMessages ?? FirebaseMessagingStreams.onMessage
        self.openedMessages = openedMessages ?? FirebaseMessagingStreams.onMessageOpenedApp
        self.onMessageReceived = onMessageReceived
    }

    /// Dart: `!kIsWeb && (android || iOS)` — always true in the iOS app.
    static var supportsCurrentPlatform: Bool { true }

    private static let permissionRequestedKey = "push_permission_requested"
    private let providedMessaging: PushMessaging?
    private var messaging: PushMessaging { providedMessaging ?? FirebasePushMessaging.instance }
    private let notifications: LocalNotificationService
    private let foregroundMessages: PushEventStream<RemoteMessage>
    private let openedMessages: PushEventStream<RemoteMessage>
    let onMessageReceived: (() -> Void)?
    @ObservationIgnored private var subscriptions: [PushEventSubscription] = []
    /// Insertion-ordered, like Dart's default `LinkedHashSet`.
    @ObservationIgnored private var openedIds: [String] = []
    @ObservationIgnored private var receivedIds: [String] = []
    @ObservationIgnored private var initialization: Task<Void, Never>?
    @ObservationIgnored private var disposed = false

    private(set) var isInitialized = false
    private(set) var isRequestingPermission = false
    private(set) var hasError = false
    private(set) var googlePlayServicesUnavailable = false
    private var authorization: AuthorizationStatus = .notDetermined
    private(set) var token: String?
    private(set) var pendingOpen: PushMessage?

    var isSupported: Bool { Self.supportsCurrentPlatform }
    var permissionDenied: Bool { authorization == .denied }
    var hasPermission: Bool { authorization == .authorized || authorization == .provisional }

    func initialize() async {
        if !isSupported || disposed { return }
        let task: Task<Void, Never>
        if let initialization {
            task = initialization
        } else {
            task = Task { [unowned self] in await self.runInitialize() }
            initialization = task
        }
        await task.value
    }

    /// Dart `_initialize`.
    private func runInitialize() async {
        let succeeded = await self.guard {
            try await self.notifications.initialize()
            if self.disposed { return }
            self.notifications.onTap = { [weak self] message in self?.handleOpen(message) }
            // Local notifications own foreground presentation on both platforms.
            try await self.messaging.setForegroundNotificationPresentationOptions(
                alert: false,
                badge: false,
                sound: false
            )
            if self.disposed { return }
            if self.subscriptions.isEmpty {
                self.subscriptions.append(contentsOf: [
                    self.foregroundMessages.listen(
                        { [weak self] message in
                            // `unawaited(_handleForeground(message))`.
                            Task { await self?.handleForeground(message) }
                        },
                        onError: { [weak self] error in self?.streamError(error) }
                    ),
                    self.openedMessages.listen(
                        { [weak self] message in self?.handleRemoteOpen(message) },
                        onError: { [weak self] error in self?.streamError(error) }
                    ),
                    self.messaging.onTokenRefresh.listen(
                        { [weak self] token in
                            guard let self else { return }
                            if self.disposed || !self.hasPermission || self.googlePlayServicesUnavailable {
                                return
                            }
                            self.token = token
                        },
                        onError: { [weak self] error in self?.streamError(error) }
                    ),
                ])
                // FlutterFire / flutter_local_notifications register their
                // UIKit callbacks here; installing them only now means a tap
                // before this point waits in `AppDelegate.Hooks.pendingResponse`
                // and is replayed by the initial-message reads below.
                PushNotificationHooks.install()
            }
            // Listen before reading cold-start messages, so a warm tap cannot be lost.
            if let localMessage = await self.notifications.getInitialMessage() {
                self.handleOpen(localMessage)
            }
            if let remoteMessage = try await self.messaging.getInitialMessage() {
                self.handleRemoteOpen(remoteMessage)
            }
            if !self.disposed { self.isInitialized = true }
        }
        if !succeeded {
            initialization = nil
        } else {
            // Token registration can fail offline; it must not block notification
            // taps or tear down the listeners that are already installed.
            await refreshPermission()
        }
    }

    /// Called after the first frame. Track the request because Android 13 reports
    /// both an unasked permission and a rejection as `denied`.
    func requestPermissionIfNeeded() async {
        if !isSupported || disposed || hasPermission || googlePlayServicesUnavailable {
            return
        }
        AppPrefs.initialize()
        if !AppPrefs.getBool(Self.permissionRequestedKey) { await requestPermission() }
    }

    func requestPermission() async {
        if !isSupported || disposed || isRequestingPermission { return }
        isRequestingPermission = true
        await initialize()
        if !isInitialized || disposed || googlePlayServicesUnavailable {
            isRequestingPermission = false
            return
        }
        _ = await self.guard {
            AppPrefs.initialize()
            AppPrefs.setBool(Self.permissionRequestedKey, true)
            let settings = try await self.messaging.requestPermission(alert: true, badge: true, sound: true)
            self.authorization = settings.authorizationStatus
            if self.hasPermission { try await self.readToken() }
        }
        isRequestingPermission = false
    }

    /// Rechecks system settings and retries token retrieval when the app resumes.
    func refreshPermission() async {
        if !isSupported || disposed { return }
        _ = await self.guard { try await self.loadPermission() }
    }

    private func loadPermission() async throws {
        // Dart: `defaultTargetPlatform == TargetPlatform.android &&
        // !await _checkGooglePlayServices()`. The Play services check is
        // Android-only; on iOS the condition is false.
        googlePlayServicesUnavailable = false
        let settings = try await messaging.getNotificationSettings()
        authorization = settings.authorizationStatus
        if hasPermission && !googlePlayServicesUnavailable {
            try await readToken()
        } else {
            token = nil
        }
    }

    private func readToken() async throws {
        // APNs registration may finish after startup. onTokenRefresh picks up that
        // result; resume also retries, without blocking the UI with a polling loop.
        // (Dart checks `defaultTargetPlatform == TargetPlatform.iOS` first.)
        if try await messaging.getAPNSToken() == nil {
            return
        }
        let token = try await messaging.getToken()
        if !disposed { self.token = token }
    }

    func openSettings() async {
        if !isSupported || disposed { return }
        _ = await self.guard { await self.notifications.openSettings() }
    }

    private func handleForeground(_ remote: RemoteMessage) async {
        if disposed { return }
        let message = PushMessage.fromRemoteMessage(remote)
        if !Self.remember(&receivedIds, message.deliveryId) { return }
        onMessageReceived?()
        if hasPermission && message.hasContent {
            _ = await self.guard { try await self.notifications.show(message) }
        }
    }

    private func handleRemoteOpen(_ remote: RemoteMessage) {
        handleOpen(PushMessage.fromRemoteMessage(remote))
    }

    private func handleOpen(_ message: PushMessage) {
        if disposed || !Self.remember(&openedIds, message.deliveryId) { return }
        pendingOpen = message
    }

    /// The app consumes this only when its router and signed-in session are ready.
    func takePendingOpen() -> PushMessage? {
        let message = pendingOpen
        pendingOpen = nil
        return message
    }

    private static func remember(_ ids: inout [String], _ id: String?) -> Bool {
        guard let id else { return true }
        if ids.contains(id) { return false }
        ids.append(id)
        if ids.count > 100 { ids.removeFirst() }
        return true
    }

    private func `guard`(_ action: () async throws -> Void) async -> Bool {
        do {
            try await action()
            hasError = false
            return true
        } catch {
            hasError = true
            superPrint("Push notification operation failed; retry on resume.")
            return false
        }
    }

    private func streamError(_ error: Error) {
        if disposed || googlePlayServicesUnavailable { return }
        hasError = true
    }

    func dispose() {
        disposed = true
        notifications.onTap = nil
        for subscription in subscriptions {
            subscription.cancel()
        }
    }
}

// MARK: - firebase_messaging

/// firebase_messaging's `AuthorizationStatus`.
enum AuthorizationStatus: String, CaseIterable, DartEnum {
    case authorized, denied, notDetermined, provisional
}

/// firebase_messaging's `NotificationSettings` (the field this app reads).
struct NotificationSettings {
    let authorizationStatus: AuthorizationStatus
}

/// The `FirebaseMessaging` surface the service uses — FCM + APNs in the app,
/// a hand-written fake in tests (the Dart tests fake `FirebaseMessaging` too).
protocol PushMessaging: AnyObject {
    var onTokenRefresh: PushEventStream<String> { get }
    func setForegroundNotificationPresentationOptions(alert: Bool, badge: Bool, sound: Bool) async throws
    func getInitialMessage() async throws -> RemoteMessage?
    func requestPermission(alert: Bool, badge: Bool, sound: Bool) async throws -> NotificationSettings
    func getNotificationSettings() async throws -> NotificationSettings
    func getAPNSToken() async throws -> String?
    func getToken() async throws -> String?
}

/// `FirebaseMessaging.instance` on iOS: FirebaseMessaging for the FCM token,
/// `UNUserNotificationCenter` for permission, and `AppDelegate.Hooks` for
/// deliveries — what FlutterFire's iOS plugin does natively.
final class FirebasePushMessaging: NSObject, PushMessaging, MessagingDelegate {
    static let instance = FirebasePushMessaging()

    let onTokenRefresh = PushEventStream<String>()

    override init() {
        super.init()
        Messaging.messaging().delegate = self
        // FlutterFire registers with APNs as soon as the plugin is attached.
        Task { @MainActor in UIApplication.shared.registerForRemoteNotifications() }
    }

    func setForegroundNotificationPresentationOptions(alert: Bool, badge: Bool, sound: Bool) async throws {
        var options: UNNotificationPresentationOptions = []
        if alert { options.formUnion([.banner, .list]) }
        if badge { options.insert(.badge) }
        if sound { options.insert(.sound) }
        PushNotificationHooks.foregroundPresentationOptions = options
    }

    /// The FCM tap that launched the app, consumed on read (FlutterFire's
    /// `getInitialMessage`).
    func getInitialMessage() async throws -> RemoteMessage? {
        guard let response = AppDelegate.Hooks.pendingResponse,
              PushNotificationHooks.isFirebaseMessage(response.notification.request.content.userInfo) else {
            return nil
        }
        AppDelegate.Hooks.pendingResponse = nil
        return RemoteMessage.fromUserInfo(response.notification.request.content.userInfo)
    }

    func requestPermission(alert: Bool, badge: Bool, sound: Bool) async throws -> NotificationSettings {
        var options: UNAuthorizationOptions = []
        if alert { options.insert(.alert) }
        if badge { options.insert(.badge) }
        if sound { options.insert(.sound) }
        _ = try await UNUserNotificationCenter.current().requestAuthorization(options: options)
        return try await getNotificationSettings()
    }

    func getNotificationSettings() async throws -> NotificationSettings {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return NotificationSettings(authorizationStatus: Self.status(settings.authorizationStatus))
    }

    func getAPNSToken() async throws -> String? {
        guard let token = Messaging.messaging().apnsToken else { return nil }
        return token.map { String(format: "%02x", $0) }.joined()
    }

    func getToken() async throws -> String? {
        try await Messaging.messaging().token()
    }

    // MARK: MessagingDelegate — `onTokenRefresh`

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken else { return }
        Task { @MainActor [weak self] in self?.onTokenRefresh.add(fcmToken) }
    }

    /// FlutterFire's `NSNumberForUNAuthorizationStatus` (ephemeral and any
    /// future status read as not determined).
    private static func status(_ status: UNAuthorizationStatus) -> AuthorizationStatus {
        switch status {
        case .authorized: return .authorized
        case .denied: return .denied
        case .provisional: return .provisional
        case .notDetermined: return .notDetermined
        default: return .notDetermined
        }
    }
}

/// firebase_messaging's static `FirebaseMessaging.onMessage` /
/// `onMessageOpenedApp` streams, fed by `PushNotificationHooks`.
@MainActor
enum FirebaseMessagingStreams {
    static let onMessage = PushEventStream<RemoteMessage>()
    static let onMessageOpenedApp = PushEventStream<RemoteMessage>()
}

/// The UIKit side of FlutterFire and flutter_local_notifications: routes
/// `AppDelegate`'s notification callbacks to the streams and callbacks the
/// service listens to.
enum PushNotificationHooks {
    /// `setForegroundNotificationPresentationOptions` for FCM deliveries.
    static var foregroundPresentationOptions: UNNotificationPresentationOptions = []

    /// FlutterFire only handles deliveries that carry an FCM message id.
    static func isFirebaseMessage(_ userInfo: [AnyHashable: Any]) -> Bool {
        userInfo["gcm.message_id"] != nil
    }

    static func install() {
        AppDelegate.Hooks.willPresent = { notification in
            let userInfo = notification.request.content.userInfo
            if PushNotificationHooks.isFirebaseMessage(userInfo) {
                // FlutterFire: `Messaging#onMessage`, presented with the
                // foreground options (none — the local alert shows instead).
                let message = RemoteMessage.fromUserInfo(userInfo)
                Task { @MainActor in FirebaseMessagingStreams.onMessage.add(message) }
                return PushNotificationHooks.foregroundPresentationOptions
            }
            if UserNotificationsPlugin.isLocalNotification(notification) {
                return UserNotificationsPlugin.presentationOptions(for: notification)
            }
            return []
        }
        AppDelegate.Hooks.didReceiveResponse = { response in
            let notification = response.notification
            let userInfo = notification.request.content.userInfo
            if PushNotificationHooks.isFirebaseMessage(userInfo) {
                // FlutterFire: `Messaging#onMessageOpenedApp`.
                let message = RemoteMessage.fromUserInfo(userInfo)
                Task { @MainActor in FirebaseMessagingStreams.onMessageOpenedApp.add(message) }
            } else if UserNotificationsPlugin.isLocalNotification(notification) {
                // flutter_local_notifications: `onDidReceiveNotificationResponse`.
                Task { @MainActor in UserNotificationsPlugin.didReceive(response) }
            }
        }
        AppDelegate.Hooks.didReceiveRemoteNotification = { userInfo in
            guard PushNotificationHooks.isFirebaseMessage(userInfo) else { return .noData }
            let message = RemoteMessage.fromUserInfo(userInfo)
            let state = await MainActor.run { UIApplication.shared.applicationState }
            if state == .background {
                // `FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler)`.
                await firebaseMessagingBackgroundHandler(message)
                return .newData
            }
            await MainActor.run { FirebaseMessagingStreams.onMessage.add(message) }
            return .noData
        }
    }
}

// MARK: - Dart broadcast streams

/// A Dart broadcast `StreamController` in miniature: listeners get each event
/// synchronously, errors do not cancel a subscription, and events added while
/// nobody listens are dropped.
final class PushEventStream<T> {
    private var listeners: [(id: UUID, onData: (T) -> Void, onError: ((Error) -> Void)?)] = []

    init() {}

    func listen(_ onData: @escaping (T) -> Void, onError: ((Error) -> Void)? = nil) -> PushEventSubscription {
        let id = UUID()
        listeners.append((id: id, onData: onData, onError: onError))
        return PushEventSubscription { [weak self] in
            self?.listeners.removeAll { $0.id == id }
        }
    }

    func add(_ event: T) {
        for listener in listeners { listener.onData(event) }
    }

    func addError(_ error: Error) {
        for listener in listeners { listener.onError?(error) }
    }
}

/// Dart `StreamSubscription`.
final class PushEventSubscription {
    private var onCancel: (() -> Void)?

    init(_ onCancel: @escaping () -> Void) {
        self.onCancel = onCancel
    }

    func cancel() {
        onCancel?()
        onCancel = nil
    }
}
