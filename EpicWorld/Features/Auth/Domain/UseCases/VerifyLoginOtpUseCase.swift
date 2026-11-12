// Port of lib/features/auth/domain/usecases/verify_login_otp_use_case.dart
import Foundation

/// Answers the two-step sign-in challenge with the emailed code.
final class VerifyLoginOtpUseCase: UseCase {
    private let repository: AuthRepository

    init(_ repository: AuthRepository) {
        self.repository = repository
    }

    func callAsFunction(_ params: VerifyLoginOtpParams) async -> AppResult<AuthUser> {
        await repository.verifyLoginOtp(userId: params.userId, code: params.code)
    }
}

typealias VerifyLoginOtpParams = (userId: String, code: String)
