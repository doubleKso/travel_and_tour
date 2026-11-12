import XCTest
@testable import EpicWorld

/// Ports test/features/notification/data/datasources/notification_remote_service_test.dart.
final class NotificationRemoteServiceTests: XCTestCase {
    private var savedFlavor: Flavor = .prod

    override func setUp() {
        super.setUp()
        savedFlavor = F.appFlavor
        F.appFlavor = .uat
    }

    override func tearDown() {
        F.appFlavor = savedFlavor
        super.tearDown()
    }

    func testGetMyNotificationsSendsUserIdAndRoleAsDcExecVariables() async throws {
        let functions = FakeFunctions()
        let service = NotificationRemoteService(functions)
        let notifications = try await service.getMyNotifications(
            accessToken: "session-token",
            userId: "user-123",
            role: "agent"
        )
        XCTAssertTrue(functions.url?.hasSuffix("/dcExec") ?? false)
        XCTAssertEqual(functions.parameters as? NSDictionary, [
            "operation": "GetMyNotifications",
            "variables": ["userId": "user-123", "role": "agent"],
            "accessToken": "session-token",
        ] as NSDictionary)
        XCTAssertEqual(notifications.count, 1)
        XCTAssertEqual(notifications.first?.id, "notification-1")
        XCTAssertEqual(notifications.first?.title, "Booking update")
        XCTAssertEqual(notifications.first?.sentAt, DateTime.utc(2026, 9, 3, 2, 30, 1, 348))
    }

    func testInsertNotificationReadSendsOnlyTheOpenedNotificationId() async throws {
        let functions = FakeFunctions()
        functions.response = ["notificationRead_insert": "notification-read-1"]
        let service = NotificationRemoteService(functions)

        try await service.insertNotificationRead(
            accessToken: "session-token",
            notificationId: "notification-1"
        )

        XCTAssertTrue(functions.url?.hasSuffix("/dcExec") ?? false)
        XCTAssertEqual(functions.parameters as? NSDictionary, [
            "operation": "InsertNotificationRead",
            "variables": ["notificationId": "notification-1"],
            "accessToken": "session-token",
        ] as NSDictionary)
    }

    func testSetMyTwoFactorSendsTheMemberIdAndStringToggleValue() async throws {
        let functions = FakeFunctions()
        functions.response = ["appUser_update": "user-123"]
        let service = NotificationRemoteService(functions)

        try await service.setMyTwoFactor(
            accessToken: "session-token",
            userId: "user-123",
            twoFactorEnabled: true
        )

        XCTAssertTrue(functions.url?.hasSuffix("/dcExec") ?? false)
        XCTAssertEqual(functions.parameters as? NSDictionary, [
            "operation": "SetMyTwoFactor",
            "variables": ["id": "user-123", "twoFactorEnabled": "true"],
            "accessToken": "session-token",
        ] as NSDictionary)
    }

    func testSetMyTwoFactorRetriesAsABooleanWhenTheStringIsRejected() async throws {
        let functions = FakeFunctions()
        // A schema that declares a real Boolean answers the string form with a
        // body that confirms nothing, which used to leave the setting unchanged
        // with no way to tell from the app.
        functions.queuedResponses = [
            ["errors": "twoFactorEnabled must be a boolean"],
            ["appUser_update": "user-123"],
        ]
        let service = NotificationRemoteService(functions)

        try await service.setMyTwoFactor(
            accessToken: "session-token",
            userId: "user-123",
            twoFactorEnabled: true
        )

        XCTAssertEqual(functions.requests.count, 2)
        // The documented string contract is still tried first.
        XCTAssertEqual(
            variables(functions.requests.first ?? nil),
            ["id": "user-123", "twoFactorEnabled": "true"] as NSDictionary
        )
        let last = variables(functions.requests.last ?? nil)
        XCTAssertEqual(last?["id"] as? String, "user-123")
        XCTAssertTrue(Dart.isBool(last?["twoFactorEnabled"]))
        XCTAssertEqual(Dart.bool(last?["twoFactorEnabled"]), true)
    }

    private func variables(_ request: Any?) -> NSDictionary? {
        guard let body = Dart.map(request) else { return nil }
        return Dart.map(body["variables"]).map { $0 as NSDictionary }
    }
}

/// The Dart test's `_Functions` + `_Callable` fakes.
private final class FakeFunctions: CallableInvoking {
    var url: String?
    var parameters: Any?
    var response: Any?

    /// Every request this callable received, oldest first.
    var requests: [Any?] = []

    /// Responses handed out one per call, ahead of `response`.
    var queuedResponses: [Any?] = []

    func call(_ url: String, _ data: Any?, timeout: TimeInterval?) async throws -> Any? {
        self.url = url
        parameters = data
        requests.append(data)
        if !queuedResponses.isEmpty {
            return queuedResponses.removeFirst()
        }
        return response ?? [
            "notifications": [
                [
                    "id": "notification-1",
                    "type": "booking",
                    "title": "Booking update",
                    "body": "Flight confirmed",
                    "sentAt": "2026-09-03T02:30:01.348Z",
                    "createdAt": "2026-09-03T02:30:01.348Z",
                ],
            ],
        ]
    }
}
