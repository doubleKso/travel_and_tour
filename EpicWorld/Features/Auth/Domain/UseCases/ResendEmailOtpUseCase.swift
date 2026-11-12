// Port of lib/features/auth/domain/usecases/resend_email_otp_use_case.dart
import Foundation

/// Emails a replacement sign-up verification code.
final class ResendEmailOtpUseCase: UseCase {
    private let repository: AuthRepository

    init(_ repository: AuthRepository) {
        self.repository = repository
    }

    func callAsFunction(_ params: ResendEmailOtpParams) async -> AppResult<Bool> {
        await repository.resendEmailOtp(userId: params.userId, email: params.email)
    }
}

typealias ResendEmailOtpParams = (userId: String, email: String)
