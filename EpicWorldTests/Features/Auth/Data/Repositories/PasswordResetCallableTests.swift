import XCTest
@testable import EpicWorld

/// Ports test/features/auth/data/repositories/password_reset_callable_test.dart.
final class PasswordResetCallableTests: XCTestCase {
    private static let ok: JSON = ["result": ["ok": true] as JSON]

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

    // MARK: - callable contracts

    func testRequestPasswordOtpPostsOnlyTheEmail() async throws {
        let functions = FakeAuthFunctions(response: PasswordResetCallableTests.ok)
        let service = AuthCallableService(functions)

        let sent = try await service.requestPasswordOtp(email: "traveller@example.com")

        XCTAssertTrue(functions.url?.hasSuffix("/authRequestPasswordOtp") ?? false)
        XCTAssertEqual(functions.requests.count, 1)
        XCTAssertEqual(functions.request(0), ["email": "traveller@example.com"])
        XCTAssertTrue(sent)
    }

    func testResetPasswordWithOtpPostsTheEmailCodeAndNewPassword() async throws {
        let functions = FakeAuthFunctions(response: PasswordResetCallableTests.ok)
        let service = AuthCallableService(functions)

        let reset = try await service.resetPasswordWithOtp(
            email: "traveller@example.com",
            code: "123456",
            newPassword: "not-stored-in-source"
        )

        XCTAssertTrue(functions.url?.hasSuffix("/authResetPasswordWithOtp") ?? false)
        XCTAssertEqual(functions.requests.count, 1)
        XCTAssertEqual(functions.request(0), [
            "email": "traveller@example.com",
            "code": "123456",
            "newPassword": "not-stored-in-source",
        ])
        XCTAssertTrue(reset)
    }

    // MARK: - repository

    func testAResetTheBackendAcceptsIsReportedAsDone() async {
        let functions = FakeAuthFunctions(response: PasswordResetCallableTests.ok)

        let result = await AuthTestSupport.repository(functions).resetPasswordWithOtp(
            email: "traveller@example.com",
            code: "123456",
            newPassword: "not-stored-in-source"
        )

        XCTAssertTrue(result.isSuccess)
    }

    func testARejectedCodeSurfacesTheBackendWording() async {
        let functions = FakeAuthFunctions(response: [
            "result": ["ok": false, "message": "Invalid or expired code."] as JSON,
        ] as JSON)

        let result = await AuthTestSupport.repository(functions).resetPasswordWithOtp(
            email: "traveller@example.com",
            code: "000000",
            newPassword: "not-stored-in-source"
        )

        switch result {
        case .success:
            XCTFail("a rejected code must not succeed")
        case .failure(let failure):
            XCTAssertFalse(failure.isNetwork, "unexpected connection failure")
            XCTAssertEqual(failure.message, "Invalid or expired code.")
        }
    }

    func testAnUnknownAddressSurfacesTheBackendWording() async {
        let functions = FakeAuthFunctions()
        functions.error = FunctionsException(
            code: "not-found",
            message: "No account uses that email."
        )

        let result = await AuthTestSupport.repository(functions).requestPasswordOtp(email: "nobody@example.com")

        switch result {
        case .success:
            XCTFail("an unknown address must not succeed")
        case .failure(let failure):
            XCTAssertFalse(failure.isNetwork, "unexpected connection failure")
            XCTAssertEqual(failure.message, "No account uses that email.")
        }
    }
}
