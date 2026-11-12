import XCTest
@testable import EpicWorld

/// Ports test/features/auth/presentation/providers/auth_notifier_session_test.dart.
private final class SessionRepository: UnimplementedAuthRepository {
    let session: AuthUser?
    var loggedOut = false

    init(_ session: AuthUser?) {
        self.session = session
    }

    override func restoreSession() -> AuthUser? { session }

    override func logout() async { loggedOut = true }
}

final class AuthNotifierSessionTests: XCTestCase {
    @MainActor
    func testRestoresThePersistedSessionBeforeTheFirstAuthStateIsRead() {
        let user = AuthUser(
            id: "user-1",
            username: "epic",
            email: "epic@example.com",
            displayName: "Epic User",
            token: "saved-token"
        )

        let notifier = AuthTestSupport.authNotifierFor(SessionRepository(user))

        XCTAssertTrue(notifier.state.isAuthenticated)
        XCTAssertEqual(notifier.state.user, user)
    }

    @MainActor
    func testLogoutClearsTheInMemorySession() async {
        let user = AuthUser(
            id: "user-1",
            username: "epic",
            email: "epic@example.com",
            displayName: "Epic User"
        )
        let repository = SessionRepository(user)
        let notifier = AuthTestSupport.authNotifierFor(repository)

        await notifier.logout()

        XCTAssertTrue(repository.loggedOut)
        XCTAssertFalse(notifier.state.isAuthenticated)
    }
}
