// Port of lib/features/auth/domain/entities/two_factor_sign_in.dart
import Foundation

/// A sign-in that stopped at the two-step checkpoint.
///
/// `authSignin` issues no tokens for an account with two-factor
/// authentication switched on: it emails a six-digit code and returns the ID
/// the code belongs to. The challenge is kept in memory only — until
/// `authVerifyLoginOtp` answers it there is no session to persist.
struct PendingTwoFactorSignIn: Equatable {
    let userId: String

    /// Address the code was emailed to, shown on the verification screen.
    let email: String

    init(userId: String, email: String) {
        self.userId = userId
        self.email = email
    }
}

/// What a sign-in attempt produced: a live session, or the challenge above.
struct SignInOutcome: Equatable {
    let user: AuthUser?
    let twoFactor: PendingTwoFactorSignIn?

    private init(user: AuthUser?, twoFactor: PendingTwoFactorSignIn?) {
        self.user = user
        self.twoFactor = twoFactor
    }

    /// Dart `SignInOutcome.signedIn(user)`.
    static func signedIn(_ user: AuthUser) -> SignInOutcome {
        SignInOutcome(user: user, twoFactor: nil)
    }

    /// Dart `SignInOutcome.twoFactorRequired(twoFactor)`.
    static func twoFactorRequired(_ twoFactor: PendingTwoFactorSignIn) -> SignInOutcome {
        SignInOutcome(user: nil, twoFactor: twoFactor)
    }

    var requiresTwoFactor: Bool { twoFactor != nil }
}
