import XCTest
@testable import EpicWorld

/// Ports the logic assertions of
/// test/features/auth/presentation/pages/two_step_verification_page_test.dart.
///
/// The Dart test walks the screen with a widget tester; the code check and
/// the notifier calls behind each step are asserted directly here.
private let signedInUser = AuthUser(
    id: "user-1",
    username: "traveller",
    email: "traveller@example.com",
    displayName: "Traveller One",
    token: "access-token"
)

/// Accepts one code and nothing else, so the success and failure paths can
/// both be walked in a single test.
private final class TwoFactorRepository: UnimplementedAuthRepository {
    var resendCalls = 0
    var codes: [String] = []

    override func restoreSession() -> AuthUser? { nil }

    override func login(username: String, password: String) async -> AppResult<SignInOutcome> {
        .success(.twoFactorRequired(PendingTwoFactorSignIn(userId: "user-1", email: username)))
    }

    override func verifyLoginOtp(userId: String, code: String) async -> AppResult<AuthUser> {
        codes.append(code)
        return code == "123456"
            ? .success(signedInUser)
            : .failure(.server(message: "That code did not match."))
    }

    override func resendLoginOtp(userId: String) async -> AppResult<Bool> {
        resendCalls += 1
        return .success(true)
    }
}

final class TwoStepVerificationPageTests: XCTestCase {
    @MainActor
    func testAShortCodeNeverReachesTheApi() {
        XCTAssertEqual(TwoStepVerificationPage.codeError("123"), "Enter the 6-digit code we emailed you.")
        XCTAssertNil(TwoStepVerificationPage.codeError("123456"))
    }

    @MainActor
    func testTheSignUpCodeCheckUsesItsOwnWording() {
        XCTAssertEqual(EmailVerificationPage.codeError("12"), "Enter the 6-digit verification code.")
        XCTAssertNil(EmailVerificationPage.codeError("654321"))
    }

    @MainActor
    func testVerifiesTheEmailedCodeAndHandsASessionBackToSignIn() async {
        let repository = TwoFactorRepository()
        let notifier = AuthTestSupport.authNotifierFor(repository)

        // The password is accepted but held back behind the challenge.
        let outcome = await notifier.login(username: "traveller@example.com", password: "not-stored-in-source")
        XCTAssertEqual(outcome?.requiresTwoFactor, true)
        XCTAssertEqual(notifier.pendingTwoFactor?.userId, "user-1")
        XCTAssertFalse(notifier.state.isAuthenticated)

        // A rejected code surfaces the backend's wording and no session.
        let rejected = await notifier.verifyLoginOtp(userId: "user-1", code: "000000")
        XCTAssertFalse(rejected)
        XCTAssertEqual(repository.codes, ["000000"])
        XCTAssertEqual(notifier.state.error, "That code did not match.")
        XCTAssertFalse(notifier.state.isAuthenticated)

        // Resending asks for a new code.
        let resent = await notifier.resendLoginOtp(userId: "user-1")
        XCTAssertTrue(resent)
        XCTAssertEqual(repository.resendCalls, 1)
        XCTAssertNil(notifier.state.error)

        // The right code completes sign-in.
        let verified = await notifier.verifyLoginOtp(userId: "user-1", code: "123456")
        XCTAssertTrue(verified)
        XCTAssertEqual(repository.codes, ["000000", "123456"])
        XCTAssertEqual(notifier.state.user, signedInUser)
        XCTAssertNil(notifier.pendingTwoFactor)
    }

    @MainActor
    func testBackingOutDropsTheChallenge() async {
        let notifier = AuthTestSupport.authNotifierFor(TwoFactorRepository())

        _ = await notifier.login(username: "traveller@example.com", password: "not-stored-in-source")
        XCTAssertNotNil(notifier.pendingTwoFactor)

        notifier.cancelTwoFactorSignIn()

        XCTAssertNil(notifier.pendingTwoFactor)
        XCTAssertFalse(notifier.state.isAuthenticated)
    }
}
