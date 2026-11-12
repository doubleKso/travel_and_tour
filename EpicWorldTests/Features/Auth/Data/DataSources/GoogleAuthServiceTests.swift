import XCTest
@testable import EpicWorld

/// Ports test/features/auth/data/datasources/google_auth_service_test.dart.
final class GoogleAuthServiceTests: XCTestCase {
    private let now = DateTime.utc(2026, 8, 27, 12)

    private var nowSeconds: Int { now.millisecondsSinceEpoch / 1000 }

    private func message(_ error: Error) -> String {
        (error as? StateError)?.message ?? ""
    }

    func testAcceptsACurrentGoogleIdTokenForTheConfiguredWebClient() {
        let token = AuthTestSupport.jwt([
            "iss": "https://accounts.google.com",
            "aud": Env.googleWebClientId,
            "exp": nowSeconds + 3600,
        ])

        XCTAssertNoThrow(try GoogleAuthService.validateIdTokenConfiguration(token, now: now))
    }

    func testRejectsAGoogleIdTokenMintedForAnotherOAuthClient() {
        let token = AuthTestSupport.jwt([
            "iss": "https://accounts.google.com",
            "aud": "different-client.apps.googleusercontent.com",
            "exp": nowSeconds + 3600,
        ])

        XCTAssertThrowsError(try GoogleAuthService.validateIdTokenConfiguration(token, now: now)) { error in
            XCTAssertTrue(error is StateError)
            XCTAssertTrue(self.message(error).contains("audience"))
        }
    }

    func testRejectsAnExpiredGoogleIdToken() {
        let token = AuthTestSupport.jwt([
            "iss": "accounts.google.com",
            "aud": Env.googleWebClientId,
            "exp": nowSeconds - 1,
        ])

        XCTAssertThrowsError(try GoogleAuthService.validateIdTokenConfiguration(token, now: now)) { error in
            XCTAssertTrue(error is StateError)
            XCTAssertTrue(self.message(error).contains("expired"))
        }
    }

    func testAcceptsAFirebaseIdTokenForTheConfiguredProject() {
        let token = AuthTestSupport.jwt([
            "iss": "https://securetoken.google.com/epicworld-fad26",
            "aud": "epicworld-fad26",
            "exp": nowSeconds + 3600,
        ])

        XCTAssertNoThrow(try GoogleAuthService.validateFirebaseIdTokenConfiguration(
            token,
            projectId: "epicworld-fad26",
            now: now
        ))
    }

    func testRejectsAFirebaseIdTokenMintedForAnotherProject() {
        let token = AuthTestSupport.jwt([
            "iss": "https://securetoken.google.com/another-project",
            "aud": "another-project",
            "exp": nowSeconds + 3600,
        ])

        XCTAssertThrowsError(try GoogleAuthService.validateFirebaseIdTokenConfiguration(
            token,
            projectId: "epicworld-fad26",
            now: now
        )) { error in
            XCTAssertTrue(error is StateError)
            XCTAssertTrue(self.message(error).contains("issuer"))
        }
    }
}
