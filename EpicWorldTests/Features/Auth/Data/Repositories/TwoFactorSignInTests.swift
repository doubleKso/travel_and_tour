import XCTest
@testable import EpicWorld

/// Ports test/features/auth/data/repositories/two_factor_sign_in_test.dart.
final class TwoFactorSignInTests: XCTestCase {
    /// The session `authVerifyLoginOtp` answers with, trimmed to the fields the
    /// client reads.
    private static let sessionResult: JSON = [
        "accessToken": "access-token",
        "refreshToken": "refresh-token",
        "sessionId": "bc5d26c7-d10f-4a7d-8114-2a6dda4d4867",
        "expiresIn": 900,
        "user": [
            "id": "45284181-4449-429e-8f99-d2d0b39c8841",
            "uid": "45284181-4449-429e-8f99-d2d0b39c8841",
            "email": "traveller@example.com",
            "name": "Ko KHANT SBS",
            "role": "customer",
            "tier": "DIA",
            "points": 1002000,
            "twoFactorEnabled": true,
            "emailVerified": true,
        ] as JSON,
    ]

    private static let session: JSON = ["result": TwoFactorSignInTests.sessionResult]

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

    // MARK: - authSignin outcome

    func testAPayloadNamingAUserButIssuingNoTokenIsAChallenge() {
        let response = AuthLoginResponse.fromJson(["userId": "user-1"])

        XCTAssertTrue(response.requiresTwoFactor)
        XCTAssertEqual(response.twoFactorUserId, "user-1")
        XCTAssertTrue(response.accessToken.isEmpty)
    }

    func testTheChallengeIdCanArriveNestedUnderUser() {
        let response = AuthLoginResponse.fromJson([
            "twoFactorRequired": true,
            "user": ["id": "user-2", "email": "traveller@example.com"] as JSON,
        ])

        XCTAssertTrue(response.requiresTwoFactor)
        XCTAssertEqual(response.twoFactorUserId, "user-2")
        XCTAssertEqual(response.user.email, "traveller@example.com")
    }

    func testACompletedSignInIsNeverMistakenForAChallenge() {
        let response = AuthLoginResponse.fromJson(TwoFactorSignInTests.sessionResult)

        XCTAssertFalse(response.requiresTwoFactor)
        XCTAssertEqual(response.accessToken, "access-token")
        XCTAssertEqual(response.refreshToken, "refresh-token")
        XCTAssertEqual(response.sessionId, "bc5d26c7-d10f-4a7d-8114-2a6dda4d4867")
        XCTAssertEqual(response.user.id, "45284181-4449-429e-8f99-d2d0b39c8841")
        XCTAssertEqual(response.user.points, 1002000)
    }

    func testAnEmptyPayloadIsNeitherASessionNorAChallenge() {
        let response = AuthLoginResponse.fromJson([:])

        XCTAssertFalse(response.requiresTwoFactor)
        XCTAssertTrue(response.twoFactorUserId.isEmpty)
    }

    // MARK: - callable contracts

    func testVerifyLoginOtpPostsTheUserIdAndCodeAndReturnsASession() async throws {
        let functions = FakeAuthFunctions(response: TwoFactorSignInTests.session)
        let service = AuthCallableService(functions)

        let response = try await service.verifyLoginOtp(userId: "user-1", code: "123456")

        XCTAssertTrue(functions.url?.hasSuffix("/authVerifyLoginOtp") ?? false)
        XCTAssertEqual(functions.requests.count, 1)
        XCTAssertEqual(functions.request(0), ["userId": "user-1", "code": "123456"])
        XCTAssertEqual(response.accessToken, "access-token")
        XCTAssertFalse(response.requiresTwoFactor)
    }

    func testResendLoginOtpPostsOnlyTheUserId() async throws {
        let functions = FakeAuthFunctions(response: ["result": ["ok": true] as JSON] as JSON)
        let service = AuthCallableService(functions)

        let resent = try await service.resendLoginOtp(userId: "user-1")

        XCTAssertTrue(functions.url?.hasSuffix("/authResendLoginOtp") ?? false)
        XCTAssertEqual(functions.requests.count, 1)
        XCTAssertEqual(functions.request(0), ["userId": "user-1"])
        XCTAssertTrue(resent)
    }

    func testSignOutSendsTheAccessTokenRetryingWithAnEmptyBody() async throws {
        let functions = FakeAuthFunctions(response: ["result": ["ok": true] as JSON] as JSON)
        // A deployment that rejects the extra field must still end the
        // session, so the documented empty payload is the fallback.
        functions.failFirst = true
        let service = AuthCallableService(functions)

        let ok = try await service.signOut(accessToken: "session-token")

        XCTAssertTrue(functions.url?.hasSuffix("/authSignout") ?? false)
        XCTAssertEqual(functions.requests.count, 2)
        XCTAssertEqual(functions.request(0), ["accessToken": "session-token"])
        XCTAssertEqual(functions.request(1), [:])
        XCTAssertTrue(ok)
    }

    // MARK: - sign-in routing

    func testAChallengeStopsShortOfASessionAndNamesTheAccount() async throws {
        let functions = FakeAuthFunctions(response: ["result": ["userId": "user-1"] as JSON] as JSON)
        let repository = AuthTestSupport.repository(functions)

        let result = await repository.login(
            username: "traveller@example.com",
            password: "not-stored-in-source"
        )

        let outcome: SignInOutcome
        switch result {
        case .failure(let failure):
            XCTAssertFalse(failure.isNetwork, "unexpected connection failure")
            XCTFail("unexpected error: \(failure.message)")
            return
        case .success(let value):
            outcome = value
        }
        XCTAssertTrue(outcome.requiresTwoFactor)
        XCTAssertNil(outcome.user)
        XCTAssertEqual(outcome.twoFactor?.userId, "user-1")
        // The response carried no email, so the address typed into the form is
        // what the verification screen shows.
        XCTAssertEqual(outcome.twoFactor?.email, "traveller@example.com")
    }
}
