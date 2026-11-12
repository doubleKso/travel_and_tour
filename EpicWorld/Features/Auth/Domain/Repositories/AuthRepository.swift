// Port of lib/features/auth/domain/repositories/auth_repository.dart
import Foundation

/// The contract the application layer codes against.
///
/// Notifiers depend on this interface, never on the implementation — which is
/// what lets a test swap in a fake by overriding `authRepository`
/// (`container.override("authRepository", with: fake)`).
protocol AuthRepository: AnyObject {
    /// Rebuilds the local user from the persisted session, if one exists.
    func restoreSession() -> AuthUser?

    /// Uses the persisted access token to update the signed-in user's profile.
    func getCurrentUser(accessToken: String) async -> AppResult<AuthUser>

    /// Exchanges the persisted refresh token for a fresh authenticated user.
    func refreshSession() async -> AppResult<AuthUser>

    /// Signs in with email and password. An account with two-factor
    /// authentication on comes back as a challenge instead of a session — see
    /// `SignInOutcome`.
    func login(username: String, password: String) async -> AppResult<SignInOutcome>

    /// Answers the two-step checkpoint and persists the session it returns.
    func verifyLoginOtp(userId: String, code: String) async -> AppResult<AuthUser>

    /// Emails a replacement two-step sign-in code.
    func resendLoginOtp(userId: String) async -> AppResult<Bool>

    /// Exchanges a Google-issued ID token for an app session.
    func signInWithGoogle(idToken: String) async -> AppResult<AuthUser>

    /// Starts registration but does not persist a session until the email OTP is
    /// verified.
    func register(
        fullName: String,
        username: String,
        email: String,
        password: String
    ) async -> AppResult<PendingEmailVerification>

    func verifyEmailOtp(pending: PendingEmailVerification, code: String) async -> AppResult<AuthUser>

    func resendEmailOtp(userId: String, email: String) async -> AppResult<Bool>

    func requestOtp(_ phone: String) async -> AppResult<Bool>

    /// Emails a password reset code to a signed-out user.
    func requestPasswordOtp(email: String) async -> AppResult<Bool>

    /// Sets a new password with the emailed reset code. No session is issued;
    /// the user signs in again afterwards.
    func resetPasswordWithOtp(email: String, code: String, newPassword: String) async -> AppResult<Bool>

    func changePassword(accessToken: String, current: String, next: String) async -> AppResult<Bool>

    func uploadAvatar(accessToken: String, data: String, contentType: String) async -> AppResult<String>

    func updateProfile(
        accessToken: String,
        id: String,
        name: String,
        avatarUrl: String
    ) async -> AppResult<AuthUser>

    func logout() async
}
