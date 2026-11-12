import XCTest
@testable import EpicWorld

/// Ports test/features/notification/data/datasources/local_notification_service_test.dart.
///
/// The Dart test drives flutter_local_notifications' Android method channel;
/// here the plugin seam (`LocalNotificationsPlugin`) is faked instead. The
/// Android-only assertions (notification channel id, `createNotificationChannel`
/// called once) have no iOS counterpart.
@MainActor
final class LocalNotificationServiceTests: XCTestCase {
    private static let message = PushMessage(
        messageId: "delivery",
        notificationId: "inbox-item",
        title: "Booking update",
        body: "Flight confirmed"
    )

    func testNativeAlertShowsThePayloadAndRestoresColdStartPayload() async throws {
        let plugin = FakeLocalNotificationsPlugin()
        plugin.launchPayload = Self.message.toPayload()
        let service = LocalNotificationService(plugin: plugin)
        async let first: Void = service.initialize()
        async let second: Void = service.initialize()
        _ = try await (first, second)
        try await service.show(Self.message)
        XCTAssertEqual(plugin.shown.count, 1)
        XCTAssertEqual(plugin.shown.first?.title, "Booking update")
        XCTAssertEqual(plugin.shown.first?.payload, Self.message.toPayload())
        XCTAssertEqual(plugin.shown.first?.id, Self.message.localId)
        XCTAssertEqual(plugin.initializeCalls, 1)
        let initial = await service.getInitialMessage()
        XCTAssertEqual(initial?.notificationId, "inbox-item")
    }

    func testRepeatedSetupPreservesTheWarmNotificationTapCallback() async throws {
        let plugin = FakeLocalNotificationsPlugin()
        let service = LocalNotificationService(plugin: plugin)
        var tapped: PushMessage?
        service.onTap = { message in tapped = message }
        try await service.initialize()
        try await service.initialize()
        plugin.onDidReceiveNotificationResponse?(Self.message.toPayload())
        XCTAssertEqual(tapped?.notificationId, "inbox-item")
    }
}

/// Stands in for flutter_local_notifications' platform implementation.
private final class FakeLocalNotificationsPlugin: LocalNotificationsPlugin {
    var initializeCalls = 0
    var launchPayload: String?
    var onDidReceiveNotificationResponse: ((String?) -> Void)?
    var shown: [(id: Int, title: String?, body: String?, payload: String?)] = []

    func initialize(onDidReceiveNotificationResponse: @escaping (String?) -> Void) async throws -> Bool {
        initializeCalls += 1
        self.onDidReceiveNotificationResponse = onDidReceiveNotificationResponse
        return true
    }

    func getNotificationAppLaunchDetails() async -> NotificationAppLaunchDetails? {
        NotificationAppLaunchDetails(
            didNotificationLaunchApp: true,
            notificationResponse: NotificationResponse(payload: launchPayload)
        )
    }

    func show(
        id: Int,
        title: String?,
        body: String?,
        payload: String?,
        notificationDetails: DarwinNotificationDetails
    ) async throws {
        shown.append((id: id, title: title, body: body, payload: payload))
    }

    func openAppNotificationSettings() async {}
}
