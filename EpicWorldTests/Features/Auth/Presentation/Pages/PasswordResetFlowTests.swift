import XCTest
@testable import EpicWorld

/// Ports the logic assertions of
/// test/features/auth/presentation/pages/password_reset_flow_test.dart.
///
/// The Dart test walks the screens with a widget tester; the rules it checks —
/// the form validators and the notifier calls the screens make — are asserted
/// directly here.
private final class ResetRepository: UnimplementedAuthRepository {
    var codeRequests: [String] = []
    var resets: [(email: String, code: String, newPassword: String)] = []

    override func restoreSession() -> AuthUser? { nil }

    override func requestPasswordOtp(email: String) async -> AppResult<Bool> {
        codeRequests.append(email)
        return .success(true)
    }

    override func resetPasswordWithOtp(email: String, code: String, newPassword: String) async -> AppResult<Bool> {
        resets.append((email: email, code: code, newPassword: newPassword))
        return code == "123456"
            ? .success(true)
            : .failure(.server(message: "Invalid or expired code."))
    }
}

final class PasswordResetFlowTests: XCTestCase {
    private let email = "traveller@example.com"

    // MARK: - Forgot password form

    @MainActor
    func testAnEmptyAddressNeverReachesTheApi() {
        XCTAssertEqual(ForgotPasswordPage.validateEmail(""), "Enter your email")
        XCTAssertEqual(ForgotPasswordPage.validateEmail("   "), "Enter your email")
    }

    @MainActor
    func testAnAddressWithoutAtOrDotIsRejected() {
        XCTAssertEqual(ForgotPasswordPage.validateEmail("traveller"), "Enter a valid email")
        XCTAssertEqual(ForgotPasswordPage.validateEmail("traveller@example"), "Enter a valid email")
    }

    @MainActor
    func testAPaddedAddressIsAccepted() {
        XCTAssertNil(ForgotPasswordPage.validateEmail("  \(email) "))
    }

    // MARK: - Reset password form

    @MainActor
    func testMismatchedPasswordsAreCaughtBeforeTheApiIsCalled() {
        XCTAssertEqual(
            ResetPasswordPage.validateConfirm("new-password-2", password: "new-password-1"),
            "Passwords do not match"
        )
        XCTAssertNil(ResetPasswordPage.validateConfirm("new-password-1", password: "new-password-1"))
    }

    @MainActor
    func testTheResetCodeMustBeSixDigits() {
        XCTAssertEqual(ResetPasswordPage.validateCode("123"), "Enter the 6-digit code we emailed you")
        XCTAssertNil(ResetPasswordPage.validateCode("123456"))
    }

    @MainActor
    func testTheNewPasswordNeedsEightCharacters() {
        XCTAssertEqual(ResetPasswordPage.validatePassword("short"), "Use at least 8 characters")
        XCTAssertNil(ResetPasswordPage.validatePassword("new-password-1"))
    }

    // MARK: - Notifier flow

    @MainActor
    func testSendResendRejectAndResetFollowTheBackend() async {
        let repository = ResetRepository()
        let notifier = AuthTestSupport.authNotifierFor(repository)

        // Forgot password: the trimmed address is the one sent.
        let sent = await notifier.requestPasswordReset(email: email)
        XCTAssertTrue(sent)
        XCTAssertEqual(repository.codeRequests, [email])

        // Resending asks for a new code for the same address.
        let resent = await notifier.requestPasswordReset(email: email)
        XCTAssertTrue(resent)
        XCTAssertEqual(repository.codeRequests, [email, email])

        // A rejected code shows the backend's wording.
        let rejected = await notifier.resetPassword(
            email: email,
            code: "000000",
            newPassword: "new-password-1"
        )
        XCTAssertFalse(rejected)
        XCTAssertEqual(notifier.state.error, "Invalid or expired code.")
        XCTAssertFalse(notifier.state.isLoading)

        // The right code resets the password; the user stays signed out.
        let reset = await notifier.resetPassword(
            email: email,
            code: "123456",
            newPassword: "new-password-1"
        )
        XCTAssertTrue(reset)
        XCTAssertNil(notifier.state.error)
        XCTAssertEqual(repository.resets.last?.email, email)
        XCTAssertEqual(repository.resets.last?.code, "123456")
        XCTAssertEqual(repository.resets.last?.newPassword, "new-password-1")
        XCTAssertFalse(notifier.state.isAuthenticated)
    }
}
