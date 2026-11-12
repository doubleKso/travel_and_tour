// Port of lib/features/auth/domain/usecases/request_otp_use_case.dart
import Foundation

/// Starts the mobile OTP sign-in flow.
final class RequestOtpUseCase: UseCase {
    private let repository: AuthRepository

    init(_ repository: AuthRepository) {
        self.repository = repository
    }

    func callAsFunction(_ params: RequestOtpParams) async -> AppResult<Bool> {
        await repository.requestOtp(params.phone)
    }
}

/// Dart record `({String phone})` — a struct, as Swift has no single-element
/// labelled tuple.
struct RequestOtpParams {
    let phone: String
}
