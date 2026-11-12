// Port of lib/features/auth/domain/usecases/resend_login_otp_use_case.dart
import Foundation

/// Emails a replacement two-step sign-in code.
final class ResendLoginOtpUseCase: UseCase {
    private let repository: AuthRepository

    init(_ repository: AuthRepository) {
        self.repository = repository
    }

    func callAsFunction(_ params: ResendLoginOtpParams) async -> AppResult<Bool> {
        await repository.resendLoginOtp(userId: params.userId)
    }
}

/// Dart record `({String userId})` — a struct, as Swift has no single-element
/// labelled tuple.
struct ResendLoginOtpParams {
    let userId: String
}
