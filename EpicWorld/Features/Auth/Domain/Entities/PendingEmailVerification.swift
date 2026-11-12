// Port of lib/features/auth/domain/entities/pending_email_verification.dart
import Foundation

/// The temporary session returned by `authSignup` before email ownership is
/// confirmed. It is deliberately kept only in memory until OTP verification
/// succeeds, so an unverified account cannot restore an app session.
struct PendingEmailVerification: Equatable {
    let user: AuthUser
    let refreshToken: String
    let sessionId: String

    init(user: AuthUser, refreshToken: String, sessionId: String) {
        self.user = user
        self.refreshToken = refreshToken
        self.sessionId = sessionId
    }
}
