// Port of lib/features/auth/domain/usecases/reset_password_with_otp_use_case.dart
import Foundation

/// Sets a new password with the emailed reset code. No session is issued.
final class ResetPasswordWithOtpUseCase: UseCase {
    private let repository: AuthRepository

    init(_ repository: AuthRepository) {
        self.repository = repository
    }

    func callAsFunction(_ params: ResetPasswordWithOtpParams) async -> AppResult<Bool> {
        await repository.resetPasswordWithOtp(
            email: params.email,
            code: params.code,
            newPassword: params.newPassword
        )
    }
}

typealias ResetPasswordWithOtpParams = (email: String, code: String, newPassword: String)
