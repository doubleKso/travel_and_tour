import XCTest
@testable import EpicWorld

/// Ports test/features/auth/data/models/auth_register_response_test.dart.
final class AuthRegisterResponseTests: XCTestCase {
    func testParsesTheAuthRegisterResponseAndDerivesTheSessionUser() throws {
        let response = AppResponse.fromRawJson(
            [
                "success": true,
                "data": [
                    "id": "user-1",
                    "firstName": "Ada",
                    "lastName": "Lovelace",
                    "email": "ada@example.com",
                    "roles": ["AGENT"],
                    "customRoleCodes": ["travel-agent"],
                    "permissionOverrides": [
                        ["permission": "booking.read", "effect": "grant"],
                    ],
                    "permissions": ["booking.read"],
                    "status": "active",
                    "note": "Welcome",
                    "decisionReason": "Approved",
                    "avatarUrl": "https://example.com/ada.png",
                    "createdAt": "2026-01-01T00:00:00Z",
                    "lastLoginAt": "",
                ] as JSON,
                "message": "Registration successful.",
            ] as JSON
        ) { data in
            AuthRegisterResponse.fromJson(Dart.map(data) ?? [:])
        }

        let registered = try XCTUnwrap(response.data)
        let user = registered.toAuthUserDto(username: "ada")
        XCTAssertTrue(response.success)
        XCTAssertEqual(registered.fullName, "Ada Lovelace")
        XCTAssertEqual(registered.permissionOverrides.count, 1)
        XCTAssertEqual(registered.permissionOverrides.first?.effect, "grant")
        XCTAssertEqual(user.userName, "ada")
        XCTAssertEqual(user.displayName, "Ada Lovelace")
    }
}
