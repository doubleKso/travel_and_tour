// Port of lib/features/auth/presentation/providers/auth_notifier.dart
import Foundation
import Observation

/// Immutable snapshot of everything the UI knows about the session.
///
/// Views read fields off this; they never reach into the repository.
struct AuthState: Equatable {
    let user: AuthUser?
    let isLoading: Bool
    let error: String?

    /// Locally picked avatar bytes, not yet uploaded. Nil falls back to the
    /// bundled placeholder asset. (Dart `Uint8List`.)
    let avatarBytes: Data?

    init(
        user: AuthUser? = nil,
        isLoading: Bool = false,
        error: String? = nil,
        avatarBytes: Data? = nil
    ) {
        self.user = user
        self.isLoading = isLoading
        self.error = error
        self.avatarBytes = avatarBytes
    }

    var isAuthenticated: Bool { user != nil }

    /// True when the signed-in account uses the redesigned "Version 2" home.
    var isVersion2: Bool { user?.isVersion2 ?? false }

    var username: String? { user?.username }
    var email: String? { user?.email }

    /// Display name shown across the app, falling back to the username.
    var displayName: String {
        if let user, !user.displayName.isEmpty { return user.displayName }
        return user?.username ?? "Guest"
    }

    /// Loyalty points for the signed-in member; 0 while signed out.
    var points: Int { user?.points ?? 0 }

    func copyWith(
        user: AuthUser? = nil,
        isLoading: Bool? = nil,
        error: String? = nil,
        avatarBytes: Data? = nil,
        clearError: Bool = false,
        clearUser: Bool = false
    ) -> AuthState {
        AuthState(
            user: clearUser ? nil : (user ?? self.user),
            isLoading: isLoading ?? self.isLoading,
            error: clearError ? nil : (error ?? self.error),
            avatarBytes: clearUser ? nil : (avatarBytes ?? self.avatarBytes)
        )
    }
}

/// Owns the session. The only place that runs the auth use cases.
///
/// Every action follows the same shape: flag loading, await the use case,
/// fold the `AppResult` into a new state, return a value the page can branch on.
@MainActor
@Observable
final class AuthNotifier {
    private(set) var state: AuthState

    // Dart's `_login`, `_logout` … — the leading underscore keeps them apart
    // from the public actions of the same name.
    private let _getCurrentUser: GetCurrentUserUseCase
    private let _refreshSession: RefreshSessionUseCase
    private let _login: LoginUseCase
    private let _verifyLoginOtp: VerifyLoginOtpUseCase
    private let _resendLoginOtp: ResendLoginOtpUseCase
    private let _signInWithGoogle: SignInWithGoogleUseCase
    private let _register: RegisterUseCase
    private let _verifyEmailOtp: VerifyEmailOtpUseCase
    private let _resendEmailOtp: ResendEmailOtpUseCase
    private let _requestOtp: RequestOtpUseCase
    private let _requestPasswordOtp: RequestPasswordOtpUseCase
    private let _resetPasswordWithOtp: ResetPasswordWithOtpUseCase
    private let _changePassword: ChangePasswordUseCase
    private let _uploadAvatar: UploadAvatarUseCase
    private let _updateProfile: UpdateProfileUseCase
    private let _logout: LogoutUseCase

    @ObservationIgnored private var pendingEmailVerification: PendingEmailVerification?

    /// The sign-in waiting on an emailed code, if one is in flight.
    @ObservationIgnored private(set) var pendingTwoFactor: PendingTwoFactorSignIn?

    /// The renewal currently on the wire, so a burst of authenticated calls
    /// spends the refresh token once instead of racing each other.
    @ObservationIgnored private var renewal: Task<String, Never>?

    /// When the session was last renewed. Only consulted for tokens whose expiry
    /// the client cannot read — see `shouldRenew`.
    @ObservationIgnored private var lastRenewal: DateTime?

    /// How long an unreadable token is trusted after a renewal.
    private static let opaqueTokenLifetime = Duration(minutes: 10)

    /// `restoreSession` runs once, here, to seed the state from the session
    /// persisted on this device.
    init(
        restoreSession: RestoreSessionUseCase,
        getCurrentUser: GetCurrentUserUseCase,
        refreshSession: RefreshSessionUseCase,
        login: LoginUseCase,
        verifyLoginOtp: VerifyLoginOtpUseCase,
        resendLoginOtp: ResendLoginOtpUseCase,
        signInWithGoogle: SignInWithGoogleUseCase,
        register: RegisterUseCase,
        verifyEmailOtp: VerifyEmailOtpUseCase,
        resendEmailOtp: ResendEmailOtpUseCase,
        requestOtp: RequestOtpUseCase,
        requestPasswordOtp: RequestPasswordOtpUseCase,
        resetPasswordWithOtp: ResetPasswordWithOtpUseCase,
        changePassword: ChangePasswordUseCase,
        uploadAvatar: UploadAvatarUseCase,
        updateProfile: UpdateProfileUseCase,
        logout: LogoutUseCase
    ) {
        _getCurrentUser = getCurrentUser
        _refreshSession = refreshSession
        _login = login
        _verifyLoginOtp = verifyLoginOtp
        _resendLoginOtp = resendLoginOtp
        _signInWithGoogle = signInWithGoogle
        _register = register
        _verifyEmailOtp = verifyEmailOtp
        _resendEmailOtp = resendEmailOtp
        _requestOtp = requestOtp
        _requestPasswordOtp = requestPasswordOtp
        _resetPasswordWithOtp = resetPasswordWithOtp
        _changePassword = changePassword
        _uploadAvatar = uploadAvatar
        _updateProfile = updateProfile
        _logout = logout
        let restored: AuthUser? = restoreSession(NoParams()).dataOrNull ?? nil
        state = AuthState(user: restored)
    }

    /// Validates the stored session after app launch. A transient API error keeps
    /// the locally restored session intact; only explicit logout clears it.
    ///
    /// The exception is a session restored without its account: tokens an older
    /// build left in the iOS Keychain, which outlives an uninstall, after the
    /// profile was wiped with the app's preferences. Renewal refetches the
    /// profile through `authMe`; when it cannot, the session is signed out
    /// rather than shown as a nameless account.
    func restoreSessionFromApi() async {
        guard let current = state.user, !current.token.isEmpty else { return }
        await ensureValidAccessToken(force: true)
        if state.user?.id.isEmpty ?? false { await logout() }
    }

    /// Re-fetches the signed-in profile without clearing usable local data when
    /// the request fails. Used by pull-to-refresh on account-facing screens.
    @discardableResult
    func refreshCurrentUser() async -> Bool {
        guard let current = state.user, !current.token.isEmpty else { return false }
        let result = await withValidAccessTokenResult { (token: String) async -> AppResult<AuthUser> in
            await self._getCurrentUser(GetCurrentUserParams(accessToken: token))
        }
        switch result {
        case .failure(let failure):
            state = state.copyWith(error: failure.message)
            return false
        case .success(let user):
            state = state.copyWith(user: user, clearError: true)
            return true
        }
    }

    /// Returns an access token the backend will still accept, renewing the
    /// session first when the current one has expired or is about to.
    ///
    /// Every authenticated call should get its token from here rather than from
    /// `state.user!.token`: a token read straight off the state can already be
    /// dead — the customer may have left the app sitting on SmartPay's hosted
    /// checkout for longer than one lives. Returns "" while signed out, so guest
    /// flows keep working unchanged.
    ///
    /// Pass `force` to renew regardless of the token's own expiry — used when the
    /// backend has just rejected a call with "Access token expired".
    @discardableResult
    func ensureValidAccessToken(force: Bool = false) async -> String {
        let token = state.user?.token ?? ""
        if token.isEmpty { return "" }
        if !force && !shouldRenew(token) { return token }
        // `_renewal ??= _renewSession().whenComplete(() => _renewal = null)`.
        if let renewal { return await renewal.value }
        let task = Task<String, Never> {
            let renewed = await self.renewSession()
            self.renewal = nil
            return renewed
        }
        renewal = task
        return await task.value
    }

    /// Runs one backend request with a live access token.
    ///
    /// A readable JWT is refreshed before it expires. If the server rejects a
    /// token sooner than its local `exp` claim (or the token is opaque), the
    /// first expiry response stays internal: `authRefresh` rotates the session,
    /// `authMe` verifies the new token, and the original request is retried once.
    func withValidAccessToken<T>(_ request: (String) async throws -> T) async throws -> T {
        let accessToken = await ensureValidAccessToken()
        do {
            return try await request(accessToken)
        } catch {
            if !ApiException.isSessionExpired(error) || accessToken.isEmpty {
                throw error
            }
            let renewedToken = await ensureValidAccessToken(force: true)
            if renewedToken.isEmpty {
                throw ApiException("Your session could not be renewed. Please try again.")
            }
            do {
                return try await request(renewedToken)
            } catch let retryError {
                if !ApiException.isSessionExpired(retryError) { throw retryError }
                throw ApiException("Your session could not be renewed. Please try again.")
            }
        }
    }

    /// Result-returning repository counterpart to `withValidAccessToken`.
    /// Repositories intentionally convert errors into an `AppFailure`, so the
    /// expiry signal is lifted back into the retry path here and converted to a
    /// display-safe result only after renewal has been attempted.
    func withValidAccessTokenResult<T>(_ request: (String) async -> AppResult<T>) async -> AppResult<T> {
        do {
            return try await withValidAccessToken { (token: String) async throws -> AppResult<T> in
                let result = await request(token)
                if let failure = result.failureOrNull,
                   !failure.isNetwork,
                   ApiException.isSessionExpired(failure.message) {
                    throw ApiException(failure.message)
                }
                return result
            }
        } catch let error as ApiException {
            return .failure(.server(message: error.message))
        } catch {
            // Unreachable: the request above only ever throws `ApiException`.
            // Dart would rethrow; a non-throwing signature maps it instead.
            return .failure(FailureMapper.from(error))
        }
    }

    /// Whether `token` is worth renewing before the next call.
    ///
    /// A JWT answers for itself. A token whose expiry the client cannot read
    /// cannot, and treating every one of those as stale would turn each
    /// authenticated screen into an extra `authRefresh` + `authMe` round trip —
    /// so an opaque token is instead trusted for `opaqueTokenLifetime` after
    /// the session was last renewed.
    private func shouldRenew(_ token: String) -> Bool {
        if AccessToken.expiryOf(token) != nil {
            return AccessToken.needsRefresh(token)
        }
        guard let last = lastRenewal else { return true }
        return DateTime.now().difference(last) >= AuthNotifier.opaqueTokenLifetime
    }

    /// Exchanges the refresh token for a new access token, then confirms it with
    /// `authMe` — which also brings the profile (points, tier, avatar) up to
    /// date. Failures are swallowed: a renewal that could not reach the server
    /// must not sign the customer out mid-booking.
    private func renewSession() async -> String {
        var accessToken = state.user?.token ?? ""
        var refreshed = false
        let refreshResult = await _refreshSession(NoParams())
        if case .success(let user) = refreshResult {
            state = state.copyWith(user: user)
            accessToken = user.token
            refreshed = true
        }
        // `authMe` cannot rescue the expired token when `authRefresh` itself did
        // not produce a new one. Keep the local sign-in state, but let the caller
        // decide whether and when to try the renewal again.
        if !refreshed || accessToken.isEmpty { return accessToken }
        let result = await _getCurrentUser(GetCurrentUserParams(accessToken: accessToken))
        if case .success(let user) = result {
            state = state.copyWith(user: user)
            accessToken = user.token
            // Only `authMe` accepting the token proves it is live, which is what
            // `shouldRenew` leans on for tokens it cannot read.
            lastRenewal = DateTime.now()
        }
        return accessToken
    }

    /// Signs in with email and password.
    ///
    /// Returns the outcome rather than a bool because a correct password does
    /// not always end in a session: an account with two-factor authentication on
    /// comes back as a challenge the caller sends to the verification screen.
    /// Nil means the attempt failed — read `AuthState.error` for why.
    func login(username: String, password: String) async -> SignInOutcome? {
        state = state.copyWith(isLoading: true, clearError: true)
        let result = await _login((username: username, password: password))
        switch result {
        case .failure(let failure):
            state = state.copyWith(isLoading: false, error: failure.message)
            return nil
        case .success(let outcome):
            if outcome.requiresTwoFactor {
                pendingTwoFactor = outcome.twoFactor
                state = state.copyWith(isLoading: false, clearError: true)
                return outcome
            }
            pendingTwoFactor = nil
            state = state.copyWith(
                user: outcome.user,
                isLoading: false,
                clearError: true
            )
            lastRenewal = DateTime.now()
            return outcome
        }
    }

    /// Abandons a two-step challenge — the user went back to the sign-in form.
    func cancelTwoFactorSignIn() {
        pendingTwoFactor = nil
    }

    /// Finishes a two-step sign-in with the emailed code.
    func verifyLoginOtp(userId: String, code: String) async -> Bool {
        state = state.copyWith(isLoading: true, clearError: true)
        let result = await _verifyLoginOtp((userId: userId, code: code))
        switch result {
        case .failure(let failure):
            state = state.copyWith(isLoading: false, error: failure.message)
            return false
        case .success(let user):
            pendingTwoFactor = nil
            state = state.copyWith(user: user, isLoading: false, clearError: true)
            lastRenewal = DateTime.now()
            return true
        }
    }

    /// Emails a replacement two-step sign-in code.
    func resendLoginOtp(userId: String) async -> Bool {
        state = state.copyWith(isLoading: true, clearError: true)
        let result = await _resendLoginOtp(ResendLoginOtpParams(userId: userId))
        switch result {
        case .failure(let failure):
            state = state.copyWith(isLoading: false, error: failure.message)
            return false
        case .success:
            state = state.copyWith(isLoading: false, clearError: true)
            return true
        }
    }

    /// Opens the Google account picker, then exchanges its Google ID token for
    /// an Epic World session. Nil means the picker was dismissed by the user.
    func signInWithGoogle() async -> Bool? {
        state = state.copyWith(isLoading: true, clearError: true)
        do {
            let idToken = try await GoogleAuthService.getFirebaseIdToken()
            guard let idToken else {
                state = state.copyWith(isLoading: false)
                return nil
            }
            let result = await _signInWithGoogle(SignInWithGoogleParams(idToken: idToken))
            switch result {
            case .failure(let failure):
                state = state.copyWith(isLoading: false, error: failure.message)
                return false
            case .success(let user):
                state = state.copyWith(
                    user: user,
                    isLoading: false,
                    clearError: true
                )
                lastRenewal = DateTime.now()
                return true
            }
        } catch {
            state = state.copyWith(
                isLoading: false,
                error: ApiException.messageFrom(error)
            )
            return false
        }
    }

    /// Starts account registration and keeps its session in memory until the
    /// supplied email OTP has been verified.
    func register(
        fullName: String,
        username: String,
        email: String,
        password: String
    ) async -> AuthUser? {
        state = state.copyWith(isLoading: true, clearError: true)
        let result = await _register((
            fullName: fullName,
            username: username,
            email: email,
            password: password
        ))
        switch result {
        case .failure(let failure):
            state = state.copyWith(isLoading: false, error: failure.message)
            return nil
        case .success(let pending):
            pendingEmailVerification = pending
            state = state.copyWith(isLoading: false, clearError: true)
            return pending.user
        }
    }

    /// Validates the new user's email code and activates their saved session.
    func verifyEmailOtp(userId: String, code: String) async -> Bool {
        guard let pending = pendingEmailVerification, pending.user.id == userId else {
            state = state.copyWith(
                error: "Your sign-up session has expired. Please sign up again."
            )
            return false
        }
        state = state.copyWith(isLoading: true, clearError: true)
        let result = await _verifyEmailOtp((pending: pending, code: code))
        switch result {
        case .failure(let failure):
            state = state.copyWith(isLoading: false, error: failure.message)
            return false
        case .success(let user):
            pendingEmailVerification = nil
            state = state.copyWith(user: user, isLoading: false, clearError: true)
            lastRenewal = DateTime.now()
            return true
        }
    }

    func resendEmailOtp(userId: String, email: String) async -> Bool {
        state = state.copyWith(isLoading: true, clearError: true)
        let result = await _resendEmailOtp((userId: userId, email: email))
        switch result {
        case .failure(let failure):
            state = state.copyWith(isLoading: false, error: failure.message)
            return false
        case .success:
            state = state.copyWith(isLoading: false, clearError: true)
            return true
        }
    }

    /// Kicks off the mobile OTP login flow. True once a code has been sent.
    func requestOtp(phone: String = "") async -> Bool {
        state = state.copyWith(isLoading: true, clearError: true)
        let result = await _requestOtp(RequestOtpParams(phone: phone))
        switch result {
        case .failure(let failure):
            state = state.copyWith(isLoading: false, error: failure.message)
            return false
        case .success(let sent):
            state = state.copyWith(isLoading: false)
            return sent
        }
    }

    /// Emails a password reset code. True once the backend has sent it.
    func requestPasswordReset(email: String) async -> Bool {
        state = state.copyWith(isLoading: true, clearError: true)
        let result = await _requestPasswordOtp(RequestPasswordOtpParams(email: email))
        switch result {
        case .failure(let failure):
            state = state.copyWith(isLoading: false, error: failure.message)
            return false
        case .success:
            state = state.copyWith(isLoading: false, clearError: true)
            return true
        }
    }

    /// Sets a new password with the emailed reset code. The user is still
    /// signed out afterwards and signs in with the new password.
    func resetPassword(email: String, code: String, newPassword: String) async -> Bool {
        state = state.copyWith(isLoading: true, clearError: true)
        let result = await _resetPasswordWithOtp((
            email: email,
            code: code,
            newPassword: newPassword
        ))
        switch result {
        case .failure(let failure):
            state = state.copyWith(isLoading: false, error: failure.message)
            return false
        case .success:
            state = state.copyWith(isLoading: false, clearError: true)
            return true
        }
    }

    func changePassword(current: String, next: String) async -> Bool {
        if state.user?.token.isEmpty ?? true {
            state = state.copyWith(error: "Please sign in again to change password.")
            return false
        }
        state = state.copyWith(isLoading: true, clearError: true)
        let result = await withValidAccessTokenResult { (token: String) async -> AppResult<Bool> in
            await self._changePassword((accessToken: token, current: current, next: next))
        }
        switch result {
        case .failure(let failure):
            state = state.copyWith(isLoading: false, error: failure.message)
            return false
        case .success(let ok):
            state = state.copyWith(isLoading: false)
            return ok
        }
    }

    /// Uploads any newly selected avatar, then persists the name/avatar profile.
    func saveProfile(
        name: String,
        avatarBytes: Data? = nil,
        contentType: String = "image/jpeg"
    ) async -> Bool {
        guard let current = state.user, !current.token.isEmpty else {
            state = state.copyWith(
                error: "Please sign in again to update your profile."
            )
            return false
        }
        state = state.copyWith(isLoading: true, clearError: true)
        var avatarUrl = current.avatarUrl
        if let avatarBytes {
            let upload = await withValidAccessTokenResult { (token: String) async -> AppResult<String> in
                await self._uploadAvatar((
                    accessToken: token,
                    data: avatarBytes.base64EncodedString(),
                    contentType: contentType
                ))
            }
            switch upload {
            case .failure(let failure):
                state = state.copyWith(isLoading: false, error: failure.message)
                return false
            case .success(let url):
                avatarUrl = url
            }
        }
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let profileAvatarUrl = avatarUrl
        let result = await withValidAccessTokenResult { (token: String) async -> AppResult<AuthUser> in
            await self._updateProfile((
                accessToken: token,
                id: current.id,
                name: trimmedName,
                avatarUrl: profileAvatarUrl
            ))
        }
        switch result {
        case .failure(let failure):
            state = state.copyWith(isLoading: false, error: failure.message)
            return false
        case .success(let user):
            state = state.copyWith(
                user: user,
                isLoading: false,
                avatarBytes: avatarBytes,
                clearError: true
            )
            return true
        }
    }

    /// Replaces the avatar with newly picked image bytes.
    func setAvatar(_ bytes: Data) {
        state = state.copyWith(avatarBytes: bytes)
    }

    func logout() async {
        _ = await _logout(NoParams())
        pendingEmailVerification = nil
        pendingTwoFactor = nil
        lastRenewal = nil
        do {
            try await GoogleAuthService.signOut()
        } catch {
            // The local app session has already been cleared; a provider sign-out
            // failure must not keep the user signed in to the app.
        }
        state = AuthState()
    }
}
