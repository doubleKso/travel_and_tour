import XCTest
@testable import EpicWorld

/// Ports test/features/auth/data/repositories/auth_login_response_test.dart.
final class AuthLoginResponseTests: XCTestCase {
    func testParsesAndExposesTheBearerTokenFromTheLiveLoginResponse() throws {
        let response = AppResponse.fromRawJson(
            [
                "success": true,
                "data": [
                    "accessToken": "access-token",
                    "refreshToken": "refresh-token",
                    "sessionId": "session-1",
                    "expiresIn": 3600,
                    "user": [
                        "id": "admin-1",
                        "firstName": "Platform",
                        "lastName": "Admin",
                        "email": "admin@example.com",
                        "roles": ["SUPER_ADMIN"],
                        "customRoleCodes": [String](),
                        "permissionOverrides": [String](),
                        "permissions": ["admin.airports.read"],
                        "status": "active",
                        "note": "",
                        "decisionReason": "",
                        "avatarUrl": "",
                        "createdAt": "2026-01-01T00:00:00Z",
                        "lastLoginAt": "2026-01-02T00:00:00Z",
                    ] as JSON,
                ] as JSON,
                "message": "Signed in.",
            ] as JSON
        ) { data in
            AuthLoginResponse.fromJson(Dart.map(data) ?? [:])
        }

        let login = try XCTUnwrap(response.data)
        let user = login.toAuthUserDto()
        XCTAssertTrue(response.success)
        XCTAssertEqual(user.token, "access-token")
        XCTAssertEqual(login.refreshToken, "refresh-token")
        XCTAssertEqual(user.displayName, "Platform Admin")
        XCTAssertNotNil(AuthRemoteService.self)
        XCTAssertNotNil(AuthRepositoryImpl.self)
    }

    func testMapsTheAuthSigninCallableResultProfileAndTokens() {
        let response = AuthLoginResponse.fromJson([
            "accessToken": "callable-access-token",
            "refreshToken": "callable-refresh-token",
            "sessionId": "session-1",
            "expiresIn": 900,
            "user": [
                "id": "usr_bootstrap_admin",
                "uid": "usr_bootstrap_admin",
                "email": "admin@epic-world.com",
                "name": "Platform Admin",
                "role": "admin",
                "status": "active",
                "tier": "Explorer",
                "points": 0,
            ] as JSON,
        ])

        let user = response.toAuthUserDto()
        XCTAssertEqual(user.id, "usr_bootstrap_admin")
        XCTAssertEqual(user.email, "admin@epic-world.com")
        XCTAssertEqual(user.displayName, "Platform Admin")
        XCTAssertEqual(user.token, "callable-access-token")
        XCTAssertEqual(response.refreshToken, "callable-refresh-token")
    }

    func testMapsTheAvatarUrlReturnedByAuthMeForLocalProfileReuse() {
        let user = AuthLoginResponse.userFromJson([
            "id": "customer-1",
            "email": "traveller@example.com",
            "avatarUrl": "https://cdn.example.com/avatars/customer-1.jpg",
        ] as JSON)

        XCTAssertEqual(user.avatarUrl, "https://cdn.example.com/avatars/customer-1.jpg")
    }

    func testMapsTheAuthSignupCallableSessionResponse() {
        let response = AuthLoginResponse.fromJson([
            "accessToken": "signup-access-token",
            "refreshToken": "signup-refresh-token",
            "sessionId": "signup-session-1",
            "expiresIn": 3600,
            "user": [
                "id": "customer-1",
                "uid": "customer-1",
                "email": "traveller@example.com",
                "name": "Traveller One",
                "phoneNumber": "+959123456789",
                "role": "customer",
                "tier": "bronze",
                "points": 0,
                "lifetimePoints": 0,
                "avatarUrl": "",
                "twoFactorEnabled": false,
                "emailVerified": false,
                "emailNotifications": true,
                "smsAlerts": true,
                "promoOffers": true,
                "adminRoles": [String](),
                "permissions": [String](),
            ] as JSON,
        ])

        let user = response.toAuthUserDto()
        XCTAssertEqual(response.sessionId, "signup-session-1")
        XCTAssertEqual(response.expiresIn, 3600)
        XCTAssertEqual(user.role, "customer")
        XCTAssertEqual(user.displayName, "Traveller One")
        XCTAssertEqual(user.phone, "+959123456789")
        XCTAssertEqual(user.token, "signup-access-token")
    }

    func testMapsTheAuthRefreshCallableSessionResponse() {
        let response = AuthRefreshResponse.fromJson([
            "accessToken": "refreshed-access-token",
            "refreshToken": "rotated-refresh-token",
            "sessionId": "rotated-session-id",
            "expiresIn": 3600,
        ])

        XCTAssertEqual(response.accessToken, "refreshed-access-token")
        XCTAssertEqual(response.refreshToken, "rotated-refresh-token")
        XCTAssertEqual(response.sessionId, "rotated-session-id")
        XCTAssertEqual(response.expiresIn, 3600)
    }
}
