import XCTest
@testable import EpicWorld

/// Ports test/features/notification/data/datasources/push_notification_service_test.dart.
///
/// The service is the iOS branch of the Dart class, so the Dart tests that
/// override the platform to Android (Google Play services availability:
/// "missing Play services skips token requests…", "availability is rechecked…",
/// "losing Play services clears the token…") or to Windows ("unsupported
/// platforms do not invoke native notification plugins") have no iOS
/// counterpart and are not ported. Every other case runs as written.
@MainActor
final class PushNotificationServiceTests: XCTestCase {
    private static let remote = RemoteMessage(
        messageId: "delivery-1",
        data: ["notificationId": "inbox-1"],
        notification: RemoteNotification(title: "Flight update", body: "New time")
    )

    /// `await Future<void>.delayed(Duration.zero)`: let the spawned
    /// main-actor tasks run.
    private func settle() async {
        for _ in 0..<20 { await Task.yield() }
    }

    func testForegroundDisplaysOnceRefreshesInboxAndKeepsTapSeparate() async {
        let f = PushFixture()
        defer { f.tearDown() }
        let service = f.service
        async let first: Void = service.initialize()
        async let second: Void = service.initialize()
        _ = await (first, second)
        f.foreground.add(Self.remote)
        f.foreground.add(Self.remote)
        await settle()
        XCTAssertEqual(f.notifications.initializations, 1)
        XCTAssertFalse(f.messaging.nativeForegroundAlerts)
        XCTAssertEqual(f.notifications.shown.count, 1)
        XCTAssertEqual(f.received, 1)
        XCTAssertNil(f.service.pendingOpen)
        guard let shown = f.notifications.shown.first else { return XCTFail("nothing shown") }
        f.notifications.onTap?(shown)
        XCTAssertEqual(f.service.takePendingOpen()?.notificationId, "inbox-1")
        XCTAssertNil(f.service.pendingOpen)
    }

    func testColdAndWarmRemoteTapsSurviveUntilConsumedAndDeduplicate() async {
        let f = PushFixture()
        defer { f.tearDown() }
        f.messaging.initialMessage = Self.remote
        await f.service.initialize()
        XCTAssertEqual(f.service.pendingOpen?.notificationId, "inbox-1")
        XCTAssertEqual(f.service.takePendingOpen()?.messageId, "delivery-1")
        f.opened.add(Self.remote)
        XCTAssertNil(f.service.pendingOpen)
        f.opened.add(RemoteMessage(messageId: "delivery-2"))
        XCTAssertEqual(f.service.takePendingOpen()?.messageId, "delivery-2")
    }

    func testALocalNotificationCanLaunchTheTerminatedApp() async {
        let f = PushFixture()
        defer { f.tearDown() }
        f.notifications.initialMessage = PushMessage.fromRemoteMessage(Self.remote)
        await f.service.initialize()
        XCTAssertEqual(f.service.takePendingOpen()?.notificationId, "inbox-1")
    }

    func testBackgroundNotificationPayloadIsDisplayedByTheOSOnly() async throws {
        let f = PushFixture()
        defer { f.tearDown() }
        try await displayBackgroundNotification(Self.remote, notifications: f.notifications)
        XCTAssertTrue(f.notifications.shown.isEmpty)
        XCTAssertEqual(f.notifications.initializations, 0)
    }

    func testBackgroundDataAlertsDisplayWhileSilentDataStaysSilent() async throws {
        let f = PushFixture()
        defer { f.tearDown() }
        try await displayBackgroundNotification(
            RemoteMessage(data: ["title": "Update", "body": "Details"]),
            notifications: f.notifications
        )
        try await displayBackgroundNotification(
            RemoteMessage(data: ["notificationId": "silent-update"]),
            notifications: f.notifications
        )
        XCTAssertEqual(f.notifications.shown.count, 1)
        XCTAssertEqual(f.notifications.shown.first?.title, "Update")
    }

    func testPermissionRejectionSuppressesForegroundAlertsAndPromptsOnce() async {
        let f = PushFixture()
        defer { f.tearDown() }
        f.messaging.status = .denied
        await f.service.initialize()
        await f.service.requestPermissionIfNeeded()
        await f.service.requestPermissionIfNeeded()
        f.foreground.add(Self.remote)
        await settle()
        XCTAssertEqual(f.messaging.permissionRequests, 1)
        XCTAssertEqual(f.messaging.tokenReads, 0)
        XCTAssertTrue(f.service.permissionDenied)
        XCTAssertTrue(f.notifications.shown.isEmpty)
        XCTAssertEqual(f.received, 1)
    }

    func testPermissionChangesOnResumeRefreshTheTokenAndExposedState() async {
        let f = PushFixture()
        defer { f.tearDown() }
        f.messaging.status = .denied
        await f.service.initialize()
        f.messaging.status = .authorized
        await f.service.refreshPermission()
        XCTAssertTrue(f.service.hasPermission)
        XCTAssertEqual(f.service.token, "token-1")
        f.messaging.onTokenRefresh.add("token-2")
        XCTAssertEqual(f.service.token, "token-2")
        f.messaging.status = .denied
        await f.service.refreshPermission()
        XCTAssertNil(f.service.token)
        f.messaging.onTokenRefresh.add("token-after-denial")
        XCTAssertNil(f.service.token)
    }

    func testIOSWaitsForAPNsBeforeRequestingAnFCMToken() async {
        let f = PushFixture()
        defer { f.tearDown() }
        f.messaging.apnsToken = nil
        await f.service.initialize()
        XCTAssertEqual(f.messaging.tokenReads, 0)
        f.messaging.apnsToken = "apns-ready"
        await f.service.refreshPermission()
        XCTAssertEqual(f.service.token, "token-1")
    }

    func testSetupErrorsAreContainedAndRetryDoesNotDuplicateListeners() async {
        let f = PushFixture()
        defer { f.tearDown() }
        f.notifications.setupFailure = true
        await f.service.initialize()
        XCTAssertTrue(f.service.hasError)
        XCTAssertFalse(f.service.isInitialized)
        f.notifications.setupFailure = false
        await f.service.initialize()
        f.foreground.add(Self.remote)
        await settle()
        XCTAssertFalse(f.service.hasError)
        XCTAssertTrue(f.service.isInitialized)
        XCTAssertEqual(f.received, 1)
        XCTAssertEqual(f.notifications.shown.count, 1)
    }

    func testOfflinePermissionLookupCannotLoseAColdStartNotificationTap() async {
        let f = PushFixture()
        defer { f.tearDown() }
        f.messaging.initialMessage = Self.remote
        f.messaging.settingsFailure = true
        await f.service.initialize()
        XCTAssertTrue(f.service.isInitialized)
        XCTAssertTrue(f.service.hasError)
        XCTAssertEqual(f.service.takePendingOpen()?.notificationId, "inbox-1")
        f.messaging.settingsFailure = false
        await f.service.refreshPermission()
        XCTAssertFalse(f.service.hasError)
        XCTAssertEqual(f.service.token, "token-1")
    }

    func testPayloadDecodingToleratesMalformedInputAndRetainsNoBody() {
        let push = PushMessage.fromRemoteMessage(Self.remote)
        XCTAssertFalse(push.toPayload().contains("New time"))
        XCTAssertEqual(PushMessage.fromPayload(push.toPayload())?.notificationId, "inbox-1")
        XCTAssertEqual(PushMessage.fromPayload(push.toPayload())?.localId, push.localId)
        XCTAssertNil(PushMessage.fromPayload("{broken"))
        XCTAssertNil(PushMessage.fromPayload("[]"))
        XCTAssertNil(PushMessage.fromPayload(nil))
        XCTAssertNil(PushMessage.fromPayload(#"{"notificationId":[]}"#)?.notificationId)
        let data = PushMessage.fromRemoteMessage(
            RemoteMessage(data: ["title": "  ", "body": [String: Any](), "route": "/payment"])
        )
        XCTAssertFalse(data.hasContent)
    }
}

/// The Dart test's `setUp`: fakes, sync broadcast streams, and a service
/// wired to them. Preferences go to a throwaway suite (`AppPrefs.clear()`).
@MainActor
private final class PushFixture {
    let messaging = FakeMessaging()
    let notifications = FakeNotifications()
    let foreground = PushEventStream<RemoteMessage>()
    let opened = PushEventStream<RemoteMessage>()
    var received = 0
    private(set) var service: PushNotificationService!

    private static let suiteName = "PushNotificationServiceTests"
    private let savedStore: UserDefaults

    init() {
        savedStore = AppPrefs.store
        let defaults = UserDefaults(suiteName: Self.suiteName) ?? .standard
        defaults.removePersistentDomain(forName: Self.suiteName)
        AppPrefs.store = defaults
        service = PushNotificationService(
            messaging: messaging,
            notifications: notifications,
            foregroundMessages: foreground,
            openedMessages: opened,
            onMessageReceived: { [weak self] in self?.received += 1 }
        )
    }

    func tearDown() {
        service.dispose()
        AppPrefs.store.removePersistentDomain(forName: Self.suiteName)
        AppPrefs.store = savedStore
    }
}

/// The Dart test's `_Notifications` fake.
@MainActor
private final class FakeNotifications: LocalNotificationService {
    var initializations = 0
    var setupFailure = false
    var shown: [PushMessage] = []
    var initialMessage: PushMessage?

    init() {
        super.init(plugin: nil)
    }

    override func initialize() async throws {
        initializations += 1
        if setupFailure { throw StateError("Notification plugin unavailable") }
    }

    override func getInitialMessage() async -> PushMessage? { initialMessage }

    override func show(_ message: PushMessage) async throws {
        shown.append(message)
    }
}

/// The Dart test's `_Messaging` fake.
private final class FakeMessaging: PushMessaging {
    var status: AuthorizationStatus = .authorized
    let onTokenRefresh = PushEventStream<String>()
    var initialMessage: RemoteMessage?
    var apnsToken: String? = "apns-1"
    var settingsFailure = false
    var nativeForegroundAlerts = true
    var permissionRequests = 0
    var tokenReads = 0

    func setForegroundNotificationPresentationOptions(alert: Bool, badge: Bool, sound: Bool) async throws {
        nativeForegroundAlerts = alert || badge || sound
    }

    func getInitialMessage() async throws -> RemoteMessage? { initialMessage }

    func requestPermission(alert: Bool, badge: Bool, sound: Bool) async throws -> NotificationSettings {
        permissionRequests += 1
        return NotificationSettings(authorizationStatus: status)
    }

    func getNotificationSettings() async throws -> NotificationSettings {
        if settingsFailure { throw StateError("Native setup failed") }
        return NotificationSettings(authorizationStatus: status)
    }

    func getAPNSToken() async throws -> String? { apnsToken }

    func getToken() async throws -> String? {
        tokenReads += 1
        return "token-1"
    }
}
