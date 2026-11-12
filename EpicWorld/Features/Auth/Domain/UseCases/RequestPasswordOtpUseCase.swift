// Port of lib/features/auth/domain/usecases/request_password_otp_use_case.dart
import Foundation

/// Emails a password reset code to a signed-out user.
final class RequestPasswordOtpUseCase: UseCase {
    private let repository: AuthRepository

    init(_ repository: AuthRepository) {
        self.repository = repository
    }

    func callAsFunction(_ params: RequestPasswordOtpParams) async -> AppResult<Bool> {
        await repository.requestPasswordOtp(email: params.email)
    }
}

/// Dart record `({String email})` — a struct, as Swift has no single-element
/// labelled tuple.
struct RequestPasswordOtpParams {
    let email: String
}
