import XCTest
@testable import EpicWorld

/// Ports test/features/auth/presentation/providers/auth_session_renewal_test.dart.

/// An unsigned JWT expiring `inn` from now. The client only reads `exp`.
private func token(_ id: String, _ inn: Duration) -> String {
    let exp = DateTime.now().toUtc().add(inn).millisecondsSinceEpoch / 1000
    return AuthTestSupport.jwt(["jti": id, "exp": exp], header: ["alg": "HS256"], signature: "sig")
}

private func user(_ token: String) -> AuthUser {
    AuthUser(
        id: "user-1",
        username: "epic",
        email: "epic@example.com",
        displayName: "Epic User",
        token: token
    )
}

private final class RenewalRepository: UnimplementedAuthRepository {
    let session: AuthUser

    /// Token handed back by `authRefresh`; nil makes the refresh fail.
    let refreshedToken: String?

    /// Whether `authMe` accepts the token it is handed.
    let meSucceeds: Bool
    let currentUser: AuthUser?

    var refreshCalls = 0
    var meCalls = 0
    var loggedOut = false
    var meTokens: [String] = []

    init(
        _ session: AuthUser,
        refreshedToken: String? = nil,
        meSucceeds: Bool = true,
        currentUser: AuthUser? = nil
    ) {
        self.session = session
        self.refreshedToken = refreshedToken
        self.meSucceeds = meSucceeds
        self.currentUser = currentUser
    }

    override func restoreSession() -> AuthUser? { session }

    override func refreshSession() async -> AppResult<AuthUser> {
        refreshCalls += 1
        // A real round trip suspends; give concurrent callers the chance to
        // pile onto the renewal in flight, as they do in the app.
        await Task.yield()
        guard let token = refreshedToken else {
            return .failure(.server(message: "No refreshable session."))
        }
        // As the real repository does: the restored profile, with the new token.
        return .success(session.copyWith(token: token))
    }

    override func getCurrentUser(accessToken: String) async -> AppResult<AuthUser> {
        meCalls += 1
        meTokens.append(accessToken)
        if !meSucceeds {
            return .failure(.server(message: "Access token expired"))
        }
        return .success(currentUser ?? user(accessToken))
    }

    override func logout() async { loggedOut = true }
}

final class AuthSessionRenewalTests: XCTestCase {
    @MainActor
    func testATokenWithTimeLeftIsHandedBackWithoutTouchingTheApi() async {
        let live = token("live", Duration(hours: 1))
        let repository = RenewalRepository(user(live), refreshedToken: "unused")
        let notifier = AuthTestSupport.authNotifierFor(repository)

        let handed = await notifier.ensureValidAccessToken()
        XCTAssertEqual(handed, live)
        XCTAssertEqual(repository.refreshCalls, 0)
        XCTAssertEqual(repository.meCalls, 0)
    }

    @MainActor
    func testProfileRefreshCallsAuthMeAndReplacesStaleAccountData() async {
        let live = token("live-profile", Duration(hours: 1))
        let updated = user(live).copyWith(displayName: "Updated Member", points: 4321)
        let repository = RenewalRepository(user(live), currentUser: updated)
        let notifier = AuthTestSupport.authNotifierFor(repository)

        let refreshed = await notifier.refreshCurrentUser()
        XCTAssertTrue(refreshed)
        XCTAssertEqual(repository.meTokens, [live])
        XCTAssertEqual(notifier.state.displayName, "Updated Member")
        XCTAssertEqual(notifier.state.points, 4321)
    }

    @MainActor
    func testAnExpiredTokenIsRenewedAndConfirmedWithAuthMe() async {
        let dead = token("dead", Duration(minutes: -5))
        let fresh = token("fresh", Duration(hours: 1))
        let repository = RenewalRepository(user(dead), refreshedToken: fresh)
        let notifier = AuthTestSupport.authNotifierFor(repository)

        let handed = await notifier.ensureValidAccessToken()
        XCTAssertEqual(handed, fresh)
        XCTAssertEqual(repository.refreshCalls, 1)
        // authMe validates the *new* token, not the one that just expired.
        XCTAssertEqual(repository.meTokens, [fresh])
        XCTAssertEqual(notifier.state.user?.token, fresh)
    }

    @MainActor
    func testForceRenewsATokenThatHasNotExpiredYet() async {
        let live = token("live", Duration(hours: 1))
        let fresh = token("fresh", Duration(hours: 2))
        let repository = RenewalRepository(user(live), refreshedToken: fresh)
        let notifier = AuthTestSupport.authNotifierFor(repository)

        let handed = await notifier.ensureValidAccessToken(force: true)
        XCTAssertEqual(handed, fresh)
        XCTAssertEqual(repository.refreshCalls, 1)
    }

    @MainActor
    func testConcurrentCallersShareOneRenewal() async {
        let dead = token("dead", Duration(minutes: -5))
        let fresh = token("fresh", Duration(hours: 1))
        let repository = RenewalRepository(user(dead), refreshedToken: fresh)
        let notifier = AuthTestSupport.authNotifierFor(repository)

        // Future.wait([...]) — three callers in flight at once.
        let tokens = await withTaskGroup(of: (Int, String).self) { group -> [String] in
            for index in 0..<3 {
                group.addTask { @MainActor in
                    let value = await notifier.ensureValidAccessToken()
                    return (index, value)
                }
            }
            var collected = [String](repeating: "", count: 3)
            for await (index, value) in group {
                collected[index] = value
            }
            return collected
        }

        XCTAssertEqual(tokens, [fresh, fresh, fresh])
        XCTAssertEqual(repository.refreshCalls, 1)
        XCTAssertEqual(repository.meCalls, 1)
    }

    @MainActor
    func testARenewalTheServerRefusesKeepsTheSessionSignedIn() async {
        let dead = token("dead", Duration(minutes: -5))
        let repository = RenewalRepository(user(dead))
        let notifier = AuthTestSupport.authNotifierFor(repository)

        // The old token comes back rather than "": the caller still has
        // something to send, and only an explicit logout ends the session.
        let handed = await notifier.ensureValidAccessToken()
        XCTAssertEqual(handed, dead)
        XCTAssertTrue(notifier.state.isAuthenticated)
    }

    // MARK: - a session restored without its profile

    // Tokens an older build left in the iOS Keychain after the app was
    // deleted, with the profile gone along with the app's preferences.
    private func orphan(_ token: String) -> AuthUser {
        AuthUser(
            id: "",
            username: "User",
            email: "",
            displayName: "User",
            token: token
        )
    }

    @MainActor
    func testOrphanSessionGetsItsProfileBackFromAuthMeOnLaunch() async {
        let fresh = token("fresh", Duration(hours: 1))
        let repository = RenewalRepository(
            orphan(token("kept", Duration(hours: 1))),
            refreshedToken: fresh,
            currentUser: user(fresh)
        )
        let notifier = AuthTestSupport.authNotifierFor(repository)

        await notifier.restoreSessionFromApi()

        XCTAssertEqual(notifier.state.user, user(fresh))
        XCTAssertFalse(repository.loggedOut)
    }

    @MainActor
    func testOrphanSessionIsSignedOutWhenAuthMeCannotRestoreIt() async {
        let repository = RenewalRepository(
            orphan(token("kept", Duration(hours: 1))),
            refreshedToken: token("fresh", Duration(hours: 1)),
            meSucceeds: false
        )
        let notifier = AuthTestSupport.authNotifierFor(repository)

        await notifier.restoreSessionFromApi()

        XCTAssertFalse(notifier.state.isAuthenticated)
        XCTAssertTrue(repository.loggedOut)
    }

    @MainActor
    func testOrphanSessionIsSignedOutWhenItsRefreshTokenIsRefused() async {
        let repository = RenewalRepository(orphan(token("kept", Duration(hours: 1))))
        let notifier = AuthTestSupport.authNotifierFor(repository)

        await notifier.restoreSessionFromApi()

        XCTAssertFalse(notifier.state.isAuthenticated)
        XCTAssertTrue(repository.loggedOut)
    }

    @MainActor
    func testALaunchRenewalTheServerRefusesKeepsAFullSession() async {
        let repository = RenewalRepository(user(token("kept", Duration(hours: 1))))
        let notifier = AuthTestSupport.authNotifierFor(repository)

        await notifier.restoreSessionFromApi()

        XCTAssertTrue(notifier.state.isAuthenticated)
        XCTAssertFalse(repository.loggedOut)
    }

    @MainActor
    func testASignedOutAppRenewsNothing() async {
        let repository = RenewalRepository(user(""), refreshedToken: "unused")
        let notifier = AuthTestSupport.authNotifierFor(repository)

        let handed = await notifier.ensureValidAccessToken(force: true)
        XCTAssertEqual(handed, "")
        XCTAssertEqual(repository.refreshCalls, 0)
    }

    @MainActor
    func testAnOpaqueTokenIsRenewedOnceNotBeforeEveryCall() async {
        // No readable `exp`, so the client cannot judge it on its own.
        let opaque = "opaque-session-token"
        let repository = RenewalRepository(user(opaque), refreshedToken: "opaque-renewed")
        let notifier = AuthTestSupport.authNotifierFor(repository)

        let first = await notifier.ensureValidAccessToken()
        XCTAssertEqual(first, "opaque-renewed")
        XCTAssertEqual(repository.refreshCalls, 1)

        // The screens that follow reuse it rather than renewing again, which is
        // what keeps history, enquiries and payment from each costing a round trip.
        for _ in 0..<3 {
            let next = await notifier.ensureValidAccessToken()
            XCTAssertEqual(next, "opaque-renewed")
        }
        XCTAssertEqual(repository.refreshCalls, 1)
        XCTAssertEqual(repository.meCalls, 1)
    }

    @MainActor
    func testAnOpaqueTokenAuthMeRejectedIsRetriedNotSettledOn() async {
        // Nothing proved this token is live, so the next caller must try again
        // rather than trust it for the next ten minutes.
        let repository = RenewalRepository(
            user("opaque-session-token"),
            refreshedToken: "opaque-renewed",
            meSucceeds: false
        )
        let notifier = AuthTestSupport.authNotifierFor(repository)

        await notifier.ensureValidAccessToken()
        await notifier.ensureValidAccessToken()

        XCTAssertEqual(repository.refreshCalls, 2)
    }

    @MainActor
    func testARejectedRequestRenewsTheSessionAndRetriesTransparently() async throws {
        let live = token("rejected-early", Duration(hours: 1))
        let fresh = token("fresh", Duration(hours: 2))
        let repository = RenewalRepository(user(live), refreshedToken: fresh)
        let notifier = AuthTestSupport.authNotifierFor(repository)
        var requestTokens: [String] = []

        let result: String = try await notifier.withValidAccessToken { token in
            requestTokens.append(token)
            if token == live { throw ApiException("Access Token Expired") }
            return "loaded"
        }

        XCTAssertEqual(result, "loaded")
        XCTAssertEqual(requestTokens, [live, fresh])
        XCTAssertEqual(repository.refreshCalls, 1)
        XCTAssertEqual(repository.meTokens, [fresh])
    }

    @MainActor
    func testDoesNotExposeTheBackendTokenExpiredTextAfterRetryFails() async {
        let live = token("rejected-early", Duration(hours: 1))
        let fresh = token("also-rejected", Duration(hours: 2))
        let repository = RenewalRepository(user(live), refreshedToken: fresh)
        let notifier = AuthTestSupport.authNotifierFor(repository)

        do {
            let _: Void = try await notifier.withValidAccessToken { _ in
                throw ApiException("Access Token Expired")
            }
            XCTFail("expected the request to fail")
        } catch {
            XCTAssertEqual(
                (error as? ApiException)?.message,
                "Your session could not be renewed. Please try again."
            )
        }
    }
}
