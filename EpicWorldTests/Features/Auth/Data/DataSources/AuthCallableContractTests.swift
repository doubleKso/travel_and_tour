import XCTest
@testable import EpicWorld

/// Ports test/features/auth/data/datasources/auth_callable_contract_test.dart.
///
/// The Dart test documents the request maps each authentication callable
/// sends; here the same contracts are asserted against what
/// `AuthCallableService` actually puts on the wire.
final class AuthCallableContractTests: XCTestCase {
    private var savedFlavor: Flavor!

    override func setUp() {
        super.setUp()
        savedFlavor = F.appFlavor
        F.appFlavor = .uat
    }

    override func tearDown() {
        F.appFlavor = savedFlavor
        super.tearDown()
    }

    private func makeFunctions() -> FakeAuthFunctions {
        FakeAuthFunctions(response: [
            "result": [
                "ok": true,
                "url": "https://example.com/avatar.jpg",
                "appUser_update": ["id": "user-1"],
            ],
        ])
    }

    /// The most recent request body as a JSON map.
    private func lastRequest(_ functions: FakeAuthFunctions) -> JSON? {
        guard let last = functions.requests.last else { return nil }
        return Dart.map(last)
    }

    private func keys(_ map: JSON?) -> Set<String> {
        Set(map?.keys.map { $0 } ?? [])
    }

    func testDocumentsTheFirebaseCallableAuthenticationContracts() async throws {
        let functions = makeFunctions()
        let service = AuthCallableService(functions)

        // `HttpsCallable.call` wraps the arguments in the callable protocol
        // envelope `{data: {idToken: …}}`; the service hands over the inner map.
        _ = try await service.googleSignIn(idToken: "google-id-token")
        XCTAssertEqual(functions.request(0), ["idToken": "google-id-token"])

        _ = try await service.signIn(email: "traveller@example.com", password: "not-stored-in-source")
        XCTAssertEqual(keys(lastRequest(functions)), ["email", "password"])

        _ = try await service.verifyEmailOtp(userId: "user-1", code: "123456")
        XCTAssertEqual(functions.request(functions.requests.count - 1), ["userId": "user-1", "code": "123456"])

        _ = try await service.resendEmailOtp(userId: "user-1", email: "traveller@example.com")
        XCTAssertEqual(keys(lastRequest(functions)), ["userId", "email"])

        _ = try await service.signUp(
            fullName: "Traveller One",
            username: "traveller",
            email: "traveller@example.com",
            password: "not-stored-in-source"
        )
        XCTAssertEqual(keys(lastRequest(functions)), ["name", "username", "email", "password"])

        _ = try await service.changePassword(
            accessToken: "current-session-token",
            currentPassword: "not-stored-in-source",
            newPassword: "not-stored-in-source"
        )
        XCTAssertEqual(keys(lastRequest(functions)), ["accessToken", "currentPassword", "newPassword"])

        _ = try await service.refresh(refreshToken: "persisted-refresh-token", sessionId: "persisted-session-id")
        XCTAssertEqual(keys(lastRequest(functions)), ["refreshToken", "sessionId"])

        _ = try await service.uploadAvatar(
            accessToken: "current-session-token",
            data: "base64-encoded-image-data",
            contentType: "image/jpeg"
        )
        XCTAssertEqual(keys(lastRequest(functions)), ["accessToken", "data", "contentType"])

        let updated = try await service.updateMyProfile(
            accessToken: "current-session-token",
            id: "user-1",
            name: "Traveller One",
            avatarUrl: "https://example.com/avatar.jpg"
        )
        let body = lastRequest(functions)
        XCTAssertEqual(Dart.str(body?["operation"]), "UpdateMyProfile")
        XCTAssertEqual(keys(Dart.map(body?["variables"])), ["id", "name", "avatarUrl"])
        XCTAssertTrue(updated)
    }

    func testCallsResolveAgainstTheFlavorFunctionsHost() async throws {
        let functions = makeFunctions()
        _ = try await AuthCallableService(functions).requestPasswordOtp(email: "traveller@example.com")
        XCTAssertEqual(functions.url, F.functionsUrl(Endpoints.authRequestPasswordOtp))
    }
}
