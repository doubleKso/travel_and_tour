// Port of lib/features/auth/domain/usecases/register_use_case.dart
import Foundation

/// Starts registration. No session is kept until the emailed code is verified.
final class RegisterUseCase: UseCase {
    private let repository: AuthRepository

    init(_ repository: AuthRepository) {
        self.repository = repository
    }

    func callAsFunction(_ params: RegisterParams) async -> AppResult<PendingEmailVerification> {
        await repository.register(
            fullName: params.fullName,
            username: params.username,
            email: params.email,
            password: params.password
        )
    }
}

typealias RegisterParams = (fullName: String, username: String, email: String, password: String)
