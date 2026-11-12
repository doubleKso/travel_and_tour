// Port of lib/features/auth/data/repositories/auth_repository_impl.dart
import Foundation

/// Decides where data comes from and converts failures into `AppResult`s.
///
/// While `F.apiBaseUrl` is empty the mock service answers; the moment a host is
/// configured the same methods hit the API. Nothing above this class changes.
final class AuthRepositoryImpl: AuthRepository {
    private let remote: AuthRemoteService
    private let mock: AuthMockService
    private let callable: AuthCallableService

    init(_ remote: AuthRemoteService, _ mock: AuthMockService, _ callable: AuthCallableService) {
        self.remote = remote
        self.mock = mock
        self.callable = callable
    }

    private var offlineMode: Bool { F.apiBaseUrl.isEmpty }

    func restoreSession() -> AuthUser? {
        if !AppPrefs.isReady { return nil }
        let token = SecureSessionStore.accessToken
        if token.isEmpty { return nil }

        let profile = SecureSessionStore.profile
        if !profile.isEmpty {
            var json = profile
            json["token"] = token
            return AuthUserDto.fromJson(json).toDomain()
        }
        return restoreLegacySession(token)
    }

    /// Rebuilds a session saved by a build that kept the profile in preferences;
    /// its next save moves the profile into `SecureSessionStore`.
    ///
    /// After an iOS reinstall the preferences are gone while the Keychain tokens
    /// are not, so this comes back with an empty `AuthUser.id` —
    /// `AuthNotifier.restoreSessionFromApi` refetches or signs out such a
    /// session.
    private func restoreLegacySession(_ token: String) -> AuthUser {
        let email = AppPrefs.getString(AppConsts.keyUserEmail)
        let username = AppPrefs.getString(
            AppConsts.keyUserName,
            defaultValue: !email.isEmpty ? (email.components(separatedBy: "@").first ?? email) : "User"
        )
        return AuthUser(
            id: AppPrefs.getString(AppConsts.keyUserId, defaultValue: email),
            username: username,
            email: email,
            displayName: AppPrefs.getString(
                AppConsts.keyUserDisplayName,
                defaultValue: username
            ),
            phone: AppPrefs.getString(AppConsts.keyUserPhone),
            avatarUrl: AppPrefs.getString(AppConsts.keyUserAvatarUrl),
            role: AppPrefs.getString(AppConsts.keyUserRole, defaultValue: "user"),
            points: AppPrefs.getInt(AppConsts.keyUserPoints),
            token: token
        )
    }

    func getCurrentUser(accessToken: String) async -> AppResult<AuthUser> {
        await `guard` {
            let user = try await self.callable.me(accessToken: accessToken)
            self.persist(user)
            return .success(user.toDomain())
        }
    }

    func refreshSession() async -> AppResult<AuthUser> {
        await `guard` {
            let refreshToken = SecureSessionStore.refreshToken
            let sessionId = SecureSessionStore.sessionId
            let current = self.restoreSession()
            guard !refreshToken.isEmpty, !sessionId.isEmpty, let current else {
                return .failure(.cache("No refreshable session is available."))
            }
            let response = try await self.callable.refresh(
                refreshToken: refreshToken,
                sessionId: sessionId
            )
            if response.accessToken.isEmpty {
                return .failure(.server(message: "Token refresh did not return an access token."))
            }
            let user = AuthUserDto(
                id: current.id,
                userName: current.username,
                email: current.email,
                displayName: current.displayName,
                phone: current.phone,
                avatarUrl: current.avatarUrl,
                role: current.role,
                points: current.points,
                token: response.accessToken
            )
            self.persist(
                user,
                // Some deployments return only the rotated access token when the
                // refresh token/session ID are unchanged. Never replace a reusable
                // credential with an omitted (parsed as empty) field.
                refreshToken: response.refreshToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? refreshToken
                    : response.refreshToken,
                sessionId: response.sessionId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? sessionId
                    : response.sessionId
            )
            return .success(user.toDomain())
        }
    }

    func login(username: String, password: String) async -> AppResult<SignInOutcome> {
        await `guard` {
            let response = try await self.callable.signIn(
                email: username,
                password: password
            )
            // Two-factor account: the password was accepted but the session is held
            // back until the emailed code is verified, so nothing is persisted here.
            if response.requiresTwoFactor {
                return .success(
                    .twoFactorRequired(
                        PendingTwoFactorSignIn(
                            userId: response.twoFactorUserId,
                            email: !response.user.email.isEmpty ? response.user.email : username
                        )
                    )
                )
            }
            let user = response.toAuthUserDto()
            if user.token?.isEmpty ?? true {
                return .failure(.server(message: "Sign-in did not return an access token."))
            }
            self.persist(
                user,
                refreshToken: response.refreshToken,
                sessionId: response.sessionId
            )
            return .success(.signedIn(user.toDomain()))
        }
    }

    func verifyLoginOtp(userId: String, code: String) async -> AppResult<AuthUser> {
        await `guard` {
            let response = try await self.callable.verifyLoginOtp(
                userId: userId,
                code: code
            )
            let user = response.toAuthUserDto()
            if user.token?.isEmpty ?? true {
                return .failure(.server(message: "The verification code is not valid."))
            }
            self.persist(
                user,
                refreshToken: response.refreshToken,
                sessionId: response.sessionId
            )
            return .success(user.toDomain())
        }
    }

    func resendLoginOtp(userId: String) async -> AppResult<Bool> {
        await `guard` {
            let resent = try await self.callable.resendLoginOtp(userId: userId)
            return resent
                ? .success(true)
                : .failure(.server(message: "Unable to resend the verification code."))
        }
    }

    func signInWithGoogle(idToken: String) async -> AppResult<AuthUser> {
        await `guard` {
            let response = try await self.callable.googleSignIn(idToken: idToken)
            let user = response.toAuthUserDto()
            if user.token?.isEmpty ?? true {
                return .failure(.server(message: "Google sign-in did not return an access token."))
            }
            self.persist(
                user,
                refreshToken: response.refreshToken,
                sessionId: response.sessionId
            )
            return .success(user.toDomain())
        }
    }

    func register(
        fullName: String,
        username: String,
        email: String,
        password: String
    ) async -> AppResult<PendingEmailVerification> {
        await `guard` {
            let response = try await self.callable.signUp(
                fullName: fullName,
                username: username,
                email: email,
                password: password
            )
            let user = response.toAuthUserDto(username: username).toDomain()
            if !user.token.isEmpty {
                return .success(
                    PendingEmailVerification(
                        user: user,
                        refreshToken: response.refreshToken,
                        sessionId: response.sessionId
                    )
                )
            }
            return .failure(.server(message: "Sign-up did not return an access token."))
        }
    }

    func verifyEmailOtp(pending: PendingEmailVerification, code: String) async -> AppResult<AuthUser> {
        await `guard` {
            let verified = try await self.callable.verifyEmailOtp(
                userId: pending.user.id,
                code: code
            )
            if !verified {
                return .failure(.server(message: "The verification code is not valid."))
            }
            self.persist(
                self.toDto(pending.user),
                refreshToken: pending.refreshToken,
                sessionId: pending.sessionId
            )
            return .success(pending.user)
        }
    }

    func resendEmailOtp(userId: String, email: String) async -> AppResult<Bool> {
        await `guard` {
            let resent = try await self.callable.resendEmailOtp(userId: userId, email: email)
            return resent
                ? .success(true)
                : .failure(.server(message: "Unable to resend the verification code."))
        }
    }

    func requestOtp(_ phone: String) async -> AppResult<Bool> {
        await `guard` {
            if self.offlineMode {
                let sent = try await self.mock.requestOtp(phone)
                return .success(sent)
            }
            let response = try await self.remote.requestOtp(phone)
            return response.success
                ? .success(response.data ?? true)
                : .failure(.server(message: response.message))
        }
    }

    func requestPasswordOtp(email: String) async -> AppResult<Bool> {
        await `guard` {
            let sent = try await self.callable.requestPasswordOtp(email: email)
            return sent
                ? .success(true)
                : .failure(.server(message: "Unable to send a reset code."))
        }
    }

    func resetPasswordWithOtp(email: String, code: String, newPassword: String) async -> AppResult<Bool> {
        await `guard` {
            let reset = try await self.callable.resetPasswordWithOtp(
                email: email,
                code: code,
                newPassword: newPassword
            )
            return reset
                ? .success(true)
                : .failure(.server(message: "Your password could not be reset."))
        }
    }

    func changePassword(accessToken: String, current: String, next: String) async -> AppResult<Bool> {
        await `guard` {
            let ok = try await self.callable.changePassword(
                accessToken: accessToken,
                currentPassword: current,
                newPassword: next
            )
            return ok
                ? .success(true)
                : .failure(.server(message: "Password change was not accepted."))
        }
    }

    func uploadAvatar(accessToken: String, data: String, contentType: String) async -> AppResult<String> {
        await `guard` {
            let url = try await self.callable.uploadAvatar(
                accessToken: accessToken,
                data: data,
                contentType: contentType
            )
            return .success(url)
        }
    }

    func updateProfile(
        accessToken: String,
        id: String,
        name: String,
        avatarUrl: String
    ) async -> AppResult<AuthUser> {
        await `guard` {
            let updated = try await self.callable.updateMyProfile(
                accessToken: accessToken,
                id: id,
                name: name,
                avatarUrl: avatarUrl
            )
            if !updated {
                return .failure(.server(message: "Profile update was not accepted."))
            }
            guard let current = self.restoreSession() else {
                return .failure(.cache("No active session is available."))
            }
            let user = current.copyWith(displayName: name, avatarUrl: avatarUrl)
            self.persist(
                AuthUserDto(
                    id: user.id,
                    userName: user.username,
                    email: user.email,
                    displayName: user.displayName,
                    phone: user.phone,
                    avatarUrl: user.avatarUrl,
                    role: user.role,
                    points: user.points,
                    token: user.token
                )
            )
            return .success(user)
        }
    }

    func logout() async {
        // Best effort: a failed revoke must never strand the user in a session
        // they asked to leave, so the local clear-down runs either way.
        let accessToken = SecureSessionStore.accessToken
        do {
            _ = try await callable.signOut(accessToken: accessToken)
        } catch {
            // Already logged by the callable service.
        }
        SecureSessionStore.clear()
        removeLegacyProfile()
    }

    private func persist(_ dto: AuthUserDto, refreshToken: String? = nil, sessionId: String? = nil) {
        if !AppPrefs.isReady { return }
        // The token is stored under its own key; the profile is the rest.
        var profile = dto.toJson()
        profile.removeValue(forKey: "token")
        SecureSessionStore.save(
            accessToken: dto.token,
            refreshToken: refreshToken,
            sessionId: sessionId,
            profile: profile
        )
        removeLegacyProfile()
    }

    /// Profile fields older builds kept in preferences, where they did not
    /// share the tokens' lifetime. Read only by `restoreLegacySession`.
    private static let legacyProfileKeys = [
        AppConsts.keyUserName,
        AppConsts.keyUserEmail,
        AppConsts.keyUserPhone,
        AppConsts.keyUserId,
        AppConsts.keyUserDisplayName,
        AppConsts.keyUserAvatarUrl,
        AppConsts.keyUserPoints,
        AppConsts.keyUserRole,
    ]

    private func removeLegacyProfile() {
        for key in AuthRepositoryImpl.legacyProfileKeys {
            AppPrefs.remove(key)
        }
    }

    private func toDto(_ user: AuthUser) -> AuthUserDto {
        AuthUserDto(
            id: user.id,
            userName: user.username,
            email: user.email,
            displayName: user.displayName,
            phone: user.phone,
            avatarUrl: user.avatarUrl,
            role: user.role,
            points: user.points,
            token: user.token
        )
    }

    /// One place where errors become `AppResult`s — every method funnels
    /// through it so no `HTTPException` / `FunctionsException` can escape the
    /// infrastructure layer.
    private func `guard`<T>(_ body: () async throws -> AppResult<T>) async -> AppResult<T> {
        do {
            return try await body()
        } catch {
            return .failure(FailureMapper.from(error))
        }
    }
}
