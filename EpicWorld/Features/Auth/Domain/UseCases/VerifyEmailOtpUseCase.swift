// Port of lib/features/auth/domain/usecases/verify_email_otp_use_case.dart
import Foundation

/// Verifies the sign-up code and activates the pending session.
final class VerifyEmailOtpUseCase: UseCase {
    private let repository: AuthRepository

    init(_ repository: AuthRepository) {
        self.repository = repository
    }

    func callAsFunction(_ params: VerifyEmailOtpParams) async -> AppResult<AuthUser> {
        await repository.verifyEmailOtp(pending: params.pending, code: params.code)
    }
}

typealias VerifyEmailOtpParams = (pending: PendingEmailVerification, code: String)
