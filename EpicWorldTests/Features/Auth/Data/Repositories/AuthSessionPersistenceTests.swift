import XCTest
@testable import EpicWorld

/// Ports test/features/auth/data/repositories/auth_session_persistence_test.dart.
///
/// Preferences and the Keychain are swapped for a throwaway suite and service
/// per test (Dart's `setMockInitialValues({})`).
final class AuthSessionPersistenceTests: XCTestCase {
    /// `authSignin`, trimmed to the fields the client reads.
    private static let signIn: JSON = [
        "result": [
            "accessToken": "access-token",
            "refreshToken": "refresh-token",
            "sessionId": "session-1",
            "user": [
                "id": "user-1",
                "email": "traveller@example.com",
                "name": "Epic Traveller",
                "role": "customer",
                "points": 1200,
            ] as JSON,
        ] as JSON,
    ]

    private var savedFlavor: Flavor!
    private var savedKeychain: KeychainStore!
    private var savedStore: UserDefaults!
    private var suiteName = ""

    override func setUp() {
        super.setUp()
        savedFlavor = F.appFlavor
        F.appFlavor = .uat
        savedKeychain = SecureSessionStore.keychain
        SecureSessionStore.keychain = KeychainStore(service: "epicworld.tests.\(UUID().uuidString)")
        savedStore = AppPrefs.store
        suiteName = "epicworld.tests.\(UUID().uuidString)"
        AppPrefs.store = UserDefaults(suiteName: suiteName) ?? .standard
        AppPrefs.clear()
        SecureSessionStore.initialize()
    }

    override func tearDown() {
        SecureSessionStore.clear()
        SecureSessionStore.keychain = savedKeychain
        SecureSessionStore.initialize()
        AppPrefs.store.removePersistentDomain(forName: suiteName)
        AppPrefs.store = savedStore
        F.appFlavor = savedFlavor
        super.tearDown()
    }

    private func repository() -> AuthRepositoryImpl {
        let functions = FakeAuthFunctions()
        functions.responder = { url in
            url.hasSuffix("/authSignin") ? AuthSessionPersistenceTests.signIn : ["result": ["ok": true]] as JSON
        }
        return AuthTestSupport.repository(functions)
    }

    func testASignedInSessionSurvivesItsPreferencesBeingWiped() async {
        let repository = repository()
        _ = await repository.login(
            username: "traveller@example.com",
            password: "not-stored-in-source"
        )

        // An iOS reinstall: preferences are wiped, the Keychain is not.
        AppPrefs.clear()
        SecureSessionStore.initialize()

        let restored = repository.restoreSession()
        XCTAssertEqual(restored?.id, "user-1")
        XCTAssertEqual(restored?.email, "traveller@example.com")
        XCTAssertEqual(restored?.displayName, "Epic Traveller")
        XCTAssertEqual(restored?.points, 1200)
        XCTAssertEqual(restored?.token, "access-token")
    }

    func testASessionSavedByAnOlderBuildStillRestores() {
        // Older builds kept only the tokens in secure storage.
        SecureSessionStore.keychain.write("auth_token", "old-token")
        SecureSessionStore.initialize()
        AppPrefs.setString(AppConsts.keyUserId, "user-1")
        AppPrefs.setString(AppConsts.keyUserEmail, "traveller@example.com")
        AppPrefs.setString(AppConsts.keyUserDisplayName, "Epic Traveller")

        let restored = repository().restoreSession()
        XCTAssertEqual(restored?.id, "user-1")
        XCTAssertEqual(restored?.displayName, "Epic Traveller")
        XCTAssertEqual(restored?.token, "old-token")
    }

    func testLogoutClearsTheProfileWithTheTokens() async {
        let repository = repository()
        _ = await repository.login(
            username: "traveller@example.com",
            password: "not-stored-in-source"
        )

        await repository.logout()
        SecureSessionStore.initialize()

        XCTAssertTrue(SecureSessionStore.profile.isEmpty)
        XCTAssertNil(repository.restoreSession())
    }
}
